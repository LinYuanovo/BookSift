import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 分享导出服务（原型 §5.11「文字转图分享」· M3 P1-4）。
///
/// 三段职责：
///  1. [renderPng]：RepaintBoundary → `toImage(pixelRatio: 2.5)` → PNG 字节（纯内存，零平台通道）；
///  2. [ShareSink]：平台落盘 / 系统分享端口（依赖倒置，仿 core/fonts/font_ports.dart，
///     测试注入 fake，见 test/share/）；
///  3. [ShareService]：门面，把 1 的字节交给 2，并统一成 [ShareOutcome]。
///
/// 桌面/移动差异（诚实口径，不假装「保存到相册」在桌面成立）：
///  - 桌面（Windows）：保存 = file_picker 保存对话框（用户挑路径，file_picker 自己写字节）；
///    对话框不可用时兜底写「文档目录/booksift_share/」，路径回传 SnackBar。
///  - 移动（Android/iOS）：本仓无相册插件（不为此新增依赖）→ 保存 = 写应用文档目录，
///    再由「分享…」交系统面板完成「保存到相册/文件」。
///  - 分享：share_plus `SharePlus.instance.share(ShareParams(files: [XFile…]))`；
///    Windows 分享契约不可用 / Linux 不支持文件时抛异常 → 自动降级为保存并回报路径。

/// §5.11 给定导出倍率。
const double kSharePixelRatio = 2.5;

/// 移动端判定（无桌面保存对话框；相册写入须经系统分享面板）。
bool get isMobileShareTarget => Platform.isAndroid || Platform.isIOS;

/// 导出文件名：`booksift_share_20261013_142530.png`（纯 ASCII，跨平台无转义坑）。
String defaultShareFileName({DateTime? now}) {
  final DateTime t = now ?? DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return 'booksift_share_${t.year}${two(t.month)}${two(t.day)}_${two(t.hour)}${two(t.minute)}${two(t.second)}.png';
}

/// 栅格化失败（可操作提示，UI 直接展示 message）。
final class ShareRenderException implements Exception {
  const ShareRenderException(this.message);

  final String message;

  @override
  String toString() => 'ShareRenderException: $message';
}

/// RepaintBoundary（[GlobalKey] 定位）→ PNG 字节。
///
/// 只碰渲染层，不触文件系统/平台通道；但在 testWidgets 里属**真实异步**，
/// 必须包在 `tester.runAsync(...)` 内（app/test/TESTING.md §3.4）。
Future<Uint8List> renderPng(GlobalKey boundaryKey, {double pixelRatio = kSharePixelRatio}) async {
  final BuildContext? context = boundaryKey.currentContext;
  if (context == null) {
    throw const ShareRenderException('卡片不在当前界面，请确认预览已显示后再导出');
  }
  final RenderObject? object = context.findRenderObject();
  if (object is! RenderRepaintBoundary) {
    throw const ShareRenderException('导出锚点未指向 RepaintBoundary');
  }
  try {
    final ui.Image image = await object.toImage(pixelRatio: pixelRatio);
    try {
      final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw const ShareRenderException('栅格化返回空字节');
      }
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
    }
  } on ShareRenderException {
    rethrow;
  } on Object catch (error) {
    // 未完成绘制（layer 未生成）等：转成可操作提示，不把裸断言抛给 UI。
    throw ShareRenderException('卡片栅格化失败：$error');
  }
}

/// 导出结果形态。
enum ShareOutcomeKind {
  /// 已写盘（[ShareOutcome.path] 为落盘路径）。
  saved,

  /// 已交系统分享面板且用户未取消。
  shared,

  /// 用户取消（保存对话框 / 分享面板）。
  cancelled,

  /// 平台不支持且兜底也没成。
  unsupported,

  /// 失败（渲染或 IO 异常）。
  failed,
}

/// 导出结果（成功/取消/失败 + 路径 + 给 SnackBar 的人话）。
@immutable
class ShareOutcome {
  const ShareOutcome(this.kind, {this.path, this.message});

  final ShareOutcomeKind kind;
  final String? path;
  final String? message;

  bool get isSuccess => kind == ShareOutcomeKind.saved || kind == ShareOutcomeKind.shared;
}

/// 平台导出端口（保存 / 分享）；测试用 fake 实现，零真实 IO。
abstract interface class ShareSink {
  /// 保存 PNG；返回落盘路径或取消/不支持。
  Future<ShareOutcome> save(Uint8List png, String fileName);

  /// 交系统分享面板；[origin] 供 iPad popover 锚定（§share_plus iPad 注意事项）。
  Future<ShareOutcome> share(Uint8List png, String fileName, {String? text, Rect? origin});
}

/// share_plus + file_picker + path_provider 实现。
final class PlatformShareSink implements ShareSink {
  const PlatformShareSink();

  /// 应用文档目录下的导出子目录名。
  static const String exportDirName = 'booksift_share';

  Future<String> _writeTo(Directory dir, String fileName, Uint8List png) async {
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final File file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(png, flush: true);
    return file.path;
  }

  Future<String> _writeDocuments(String fileName, Uint8List png) =>
      getApplicationDocumentsDirectory().then((Directory d) => _writeTo(d, fileName, png));

  Future<String> _writeTemp(String fileName, Uint8List png) =>
      getTemporaryDirectory().then((Directory d) => _writeTo(d, fileName, png));

  @override
  Future<ShareOutcome> save(Uint8List png, String fileName) async {
    if (isMobileShareTarget) {
      // 移动端无相册插件：落应用文档目录，「保存到相册」由分享面板承担。
      final String path = await _writeDocuments(fileName, png);
      return ShareOutcome(
        ShareOutcomeKind.saved,
        path: path,
        message: '已存到应用目录；点「分享…」可在系统面板保存到相册',
      );
    }
    try {
      final Uri? uri = await FilePicker.saveFile(
        dialogTitle: '保存分享卡片',
        fileName: fileName,
        bytes: png,
        mimeType: 'image/png',
        type: FileType.custom,
        allowedExtensions: const <String>['png'],
      );
      if (uri == null) {
        return const ShareOutcome(ShareOutcomeKind.cancelled, message: '已取消保存');
      }
      return ShareOutcome(
        ShareOutcomeKind.saved,
        path: uri.isScheme('file') ? uri.toFilePath() : uri.toString(),
      );
    } on Object catch (error) {
      // 平台没有保存对话框（Linux / 老 Windows）→ 文档目录兜底。
      final String path = await _writeDocuments(fileName, png);
      return ShareOutcome(
        ShareOutcomeKind.saved,
        path: path,
        message: '保存对话框不可用（$error），已写入应用文档目录',
      );
    }
  }

  @override
  Future<ShareOutcome> share(Uint8List png, String fileName, {String? text, Rect? origin}) async {
    try {
      final String path = await _writeTemp(fileName, png);
      final ShareResult result = await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(path, mimeType: 'image/png')],
          text: text,
          sharePositionOrigin: origin,
        ),
      );
      if (result.status == ShareResultStatus.dismissed) {
        return ShareOutcome(ShareOutcomeKind.cancelled, path: path, message: '已取消分享');
      }
      // unavailable = 平台不回传用户动作（Windows/Android 部分场景），视作已分享。
      return ShareOutcome(ShareOutcomeKind.shared, path: path);
    } on Object catch (error) {
      final ShareOutcome fallback = await save(png, fileName);
      if (fallback.kind == ShareOutcomeKind.cancelled) {
        return ShareOutcome(
          ShareOutcomeKind.unsupported,
          message: '系统分享不可用（$error），保存对话框也已取消',
        );
      }
      return ShareOutcome(
        fallback.kind,
        path: fallback.path,
        message: '系统分享不可用（$error），已改为保存到：${fallback.path}',
      );
    }
  }
}

/// 栅格化函数签名（[ShareService] 的可替换渲染端口；测试注入纯内存 fake，
/// 避开 testWidgets 假时钟区里的真实 `toImage` 异步，见 app/test/TESTING.md §1）。
typedef SharePngRenderer = Future<Uint8List> Function(GlobalKey boundaryKey, {double pixelRatio});

/// 门面：渲染 + 导出（弹层持有；测试可注入 fake sink / fake renderer）。
class ShareService {
  const ShareService([this.sink = const PlatformShareSink(), this.render = renderPng]);

  final ShareSink sink;
  final SharePngRenderer render;

  /// 渲染并保存；异常统一收敛成 [ShareOutcome]（UI 不需要 try/catch）。
  Future<ShareOutcome> save(
    GlobalKey boundaryKey, {
    String? fileName,
    double pixelRatio = kSharePixelRatio,
    DateTime? now,
  }) async {
    final Uint8List png;
    try {
      png = await render(boundaryKey, pixelRatio: pixelRatio);
    } on ShareRenderException catch (error) {
      return ShareOutcome(ShareOutcomeKind.failed, message: error.message);
    }
    try {
      return await sink.save(png, fileName ?? defaultShareFileName(now: now));
    } on Object catch (error) {
      return ShareOutcome(ShareOutcomeKind.failed, message: '保存失败：$error');
    }
  }

  /// 渲染并交系统分享面板；失败自动降级保存（见 [PlatformShareSink.share]）。
  Future<ShareOutcome> share(
    GlobalKey boundaryKey, {
    String? text,
    String? fileName,
    Rect? origin,
    double pixelRatio = kSharePixelRatio,
    DateTime? now,
  }) async {
    final Uint8List png;
    try {
      png = await render(boundaryKey, pixelRatio: pixelRatio);
    } on ShareRenderException catch (error) {
      return ShareOutcome(ShareOutcomeKind.failed, message: error.message);
    }
    try {
      return await sink.share(png, fileName ?? defaultShareFileName(now: now), text: text, origin: origin);
    } on Object catch (error) {
      return ShareOutcome(ShareOutcomeKind.failed, message: '分享失败：$error');
    }
  }
}
