import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'font_tokens.dart';

/// Windows 系统默认 UI 字体探测 + 注入（需求 4b：跟随系统默认字体）。
///
/// 现状：FontFamilySet 的 system 槽解析为 `null` 时由引擎默认字体渲染，Windows 上
/// 中文观感与系统其它程序不一致。本文件用 `user32!SystemParametersInfoW
/// (SPI_GETICONTITLELOGFONT)` 读系统默认 UI 字体族名（本机 zh-CN 实测为
/// “Microsoft YaHei UI”，与 HKCU\Control Panel\Desktop\WindowMetrics
/// 的 MessageFont 一致），并在角色仍走 system 槽（family == null）时注入，
/// 使 App 跟随系统默认 UI 字体；用户显式导入/指定字体的角色不受影响（非 null 保留）。
///
/// 失败静默回落（try/catch → null → 维持现状），不阻塞启动；
/// 测试环境（flutter_tester 无 user32 语义）经 [WindowsSystemUiFont.debugOverrideFamily]
/// 或 FLUTTER_TEST 环境变量旁路，不触发真实平台调用。
abstract final class WindowsSystemUiFont {
  /// SPI_GETICONTITLELOGFONT：读图标标题字体 LOGFONTW（v1 平台 API，无分配回调）。
  static const int _spiGetIconTitleLogFont = 0x001F;

  /// LOGFONTW 固定 92 字节；lfFaceName（WCHAR[32]）位于偏移 28。
  static const int _logFontSize = 92;
  static const int _faceNameOffset = 28;
  static const int _faceNameChars = 32;

  /// LMEM_FIXED：LocalAlloc 直接返回指针（无需加锁/句柄解引用）。
  static const int _lmemFixed = 0x0000;

  /// 测试旁路/注入点：非 null 时不做任何真实平台调用，直接返回该值。
  @visibleForTesting
  static String? debugOverrideFamily;

  static bool _probed = false;
  static String? _family;

  /// 系统默认 UI 字体族名；不可用（非 Windows / 测试环境 / 调用失败）→ null。
  static String? defaultFamily() {
    if (debugOverrideFamily != null) {
      return debugOverrideFamily;
    }
    if (!_probed) {
      _probed = true;
      _family = _probe();
    }
    return _family;
  }

  static String? _probe() {
    try {
      if (!Platform.isWindows || _underTest) {
        return null;
      }
      final _SpiDart systemParametersInfo =
          DynamicLibrary.open('user32.dll').lookupFunction<_SpiNative, _SpiDart>('SystemParametersInfoW');
      final DynamicLibrary kernel32 = DynamicLibrary.open('kernel32.dll');
      final _LocalAllocDart localAlloc = kernel32.lookupFunction<_LocalAllocNative, _LocalAllocDart>('LocalAlloc');
      final _LocalFreeDart localFree = kernel32.lookupFunction<_LocalFreeNative, _LocalFreeDart>('LocalFree');
      final Pointer<Uint8> buffer = localAlloc(_lmemFixed, _logFontSize);
      if (buffer == nullptr) {
        return null;
      }
      try {
        // uiParam 必须为结构体字节数；fWinIni 仅写入路径使用，此处传 0。
        if (systemParametersInfo(_spiGetIconTitleLogFont, _logFontSize, buffer, 0) == 0) {
          return null;
        }
        final Pointer<Uint16> face = (buffer + _faceNameOffset).cast<Uint16>();
        final List<int> units = <int>[];
        for (int i = 0; i < _faceNameChars; i++) {
          final int unit = face[i];
          if (unit == 0) {
            break;
          }
          units.add(unit);
        }
        final String name = String.fromCharCodes(units).trim();
        return name.isEmpty ? null : name;
      } finally {
        localFree(buffer);
      }
    } catch (_) {
      return null;
    }
  }

  /// flutter test / flutter_tester 环境下旁路真实平台调用。
  static bool get _underTest => Platform.environment.containsKey('FLUTTER_TEST');
}

// FFI 函数签名（user32!SystemParametersInfoW / kernel32!LocalAlloc / LocalFree；
// 用 LocalAlloc 而非 package:ffi 的 calloc，避免为一次固定 92 字节调用新增依赖）。
typedef _SpiNative = Int32 Function(Uint32 uiAction, Uint32 uiParam, Pointer<Uint8> pvParam, Uint32 fWinIni);
typedef _SpiDart = int Function(int uiAction, int uiParam, Pointer<Uint8> pvParam, int fWinIni);
typedef _LocalAllocNative = Pointer<Uint8> Function(Uint32 uFlags, IntPtr uBytes);
typedef _LocalAllocDart = Pointer<Uint8> Function(int uFlags, int uBytes);
typedef _LocalFreeNative = Pointer<Uint8> Function(Pointer<Uint8> hMem);
typedef _LocalFreeDart = Pointer<Uint8> Function(Pointer<Uint8> hMem);

/// 把系统默认 UI 字体注入仍走 system 槽（family == null）的角色。
///
/// 用户显式导入/指定字体的角色（family != null，含 mono 的 `monospace`）保持原值；
/// 探测不可用（非 Windows / 失败）时原样返回 → 行为同改造前（引擎默认字体）。
FontFamilySet applySystemDefaultFont(FontFamilySet families) {
  final String? family = WindowsSystemUiFont.defaultFamily();
  if (family == null) {
    return families;
  }
  return FontFamilySet.fromFamilyOf((FontRole role) => families.familyOf(role) ?? family);
}
