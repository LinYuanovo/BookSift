import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 自绘标题栏的几何常量 + 窗口控制桥（用户口径：Windows 顶部走 design token 而非系统标题栏）。
///
/// runner 侧（`windows/runner/flutter_window.cpp`）用**同一组逻辑 px 常量**做
/// WM_NCHITTEST 命中判定（按窗口 DPI 换算成物理 px）——两边必须一致，
/// 不一致的症状 = 拖动区/按钮点击区与画面错位。
abstract final class WindowFrameMetrics {
  /// 标题栏高度（逻辑 px）= runner `kTitleBarLogicalHeight`。
  static const double titleBarHeight = 36;

  /// 单颗窗口按钮宽（逻辑 px，最小化/最大化/关闭各一颗）= runner `kCaptionButtonLogicalWidth`。
  static const double captionButtonWidth = 46;

  /// 右侧按钮簇总宽（3 × [captionButtonWidth]）= runner `kCaptionButtonsLogicalWidth`。
  static const double captionButtonsWidth = captionButtonWidth * 3;

  /// 是否需要自绘标题栏：只做 Windows（Android 走系统栏，其余平台保持原样）。
  static bool get enabled => !kIsWeb && Platform.isWindows;
}

/// 窗口控制桥（channel `booksift/window`，实现见 windows/runner/flutter_window.cpp）。
///
/// 顶部条的**拖动/双击最大化/右键系统菜单**由 runner 的 HTCAPTION 命中交给系统，
/// 这里只承担右侧三颗按钮的动作与「最大化态」回读/推送。
class WindowFrame {
  const WindowFrame._();

  static const MethodChannel _channel = MethodChannel('booksift/window');

  /// 当前是否最大化（runner 在 WM_SIZE 后推 `maximizedChanged`）。
  static final ValueNotifier<bool> maximized = ValueNotifier<bool>(false);

  static bool _bound = false;

  /// 绑定 runner 推送并回读一次初始态（幂等；非 Windows / 非 runner 宿主静默）。
  static Future<void> bind() async {
    if (_bound || !WindowFrameMetrics.enabled) {
      return;
    }
    _bound = true;
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'maximizedChanged' && call.arguments is bool) {
        maximized.value = call.arguments as bool;
      }
      return null;
    });
    // 初次回读：Dart 侧入口可能早于 runner 注册通道（首帧前）→ 超时即放弃，
    // 之后任何 WM_SIZE 都会把真实态推过来，不会卡住启动。
    final dynamic value =
        await _invoke('isMaximized').timeout(const Duration(seconds: 1), onTimeout: () => null);
    if (value is bool) {
      maximized.value = value;
    }
  }

  static Future<void> minimize() => _invoke('minimize');

  static Future<void> toggleMaximize() => _invoke('toggleMaximize');

  static Future<void> close() => _invoke('close');

  /// 平台通道调用（宿主没实现该通道时静默：widget 测试 / 非 Windows 平台）。
  static Future<dynamic> _invoke(String method) async {
    if (!WindowFrameMetrics.enabled) {
      return null;
    }
    try {
      return await _channel.invokeMethod<dynamic>(method);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
