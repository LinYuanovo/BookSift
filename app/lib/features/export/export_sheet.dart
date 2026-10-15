import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/icons.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../home/cards.dart';
import '../share/share_service.dart' show ShareOutcome, ShareOutcomeKind, isMobileShareTarget;
import 'booklist_export.dart';

/// 书单导出弹层（原型 §3.1 P2-4 · M3）：格式分段（Markdown/TXT）+ 前 20 行 mono 预览
/// + [保存文件][分享] 两条出口。渲染交给 `booklist_export.dart` 的纯函数，本文件只管
/// 弹层交互与平台落盘。
///
/// 桌面/移动差异（与 share_service 的 PNG 导出同口径，诚实标注）：
///  - 桌面（Windows）：保存 = file_picker 保存对话框（用户挑路径，file_picker 自己写字节）；
///    对话框不可用时兜底写「文档目录/booksift_export/」，路径回传 SnackBar。
///  - 移动（Android/iOS）：无保存对话框 → 保存 = 写应用文档目录，
///    再由「分享」交系统面板完成「存到文件/发送」。
///  - 分享：share_plus `SharePlus.instance.share(ShareParams(files: [XFile…]))`；
///    平台分享契约不可用时自动降级为保存并回报路径。

/// 文本文件导出端口（保存 / 分享）；测试注入 fake 实现，零真实 IO。
abstract interface class TextFileSink {
  /// 保存 UTF-8 文本；返回落盘路径或取消/不支持。
  Future<ShareOutcome> save(String content, String fileName, String mimeType);

  /// 交系统分享面板；[origin] 供 iPad popover 锚定（share_plus 要求）。
  Future<ShareOutcome> share(String content, String fileName, String mimeType, {String? text, Rect? origin});
}

/// file_picker + share_plus + path_provider 实现（仿 [PlatformShareSink] 的 PNG 链路）。
final class PlatformTextFileSink implements TextFileSink {
  const PlatformTextFileSink();

  /// 应用文档目录下的导出子目录名。
  static const String exportDirName = 'booksift_export';

  Future<String> _writeTo(Directory dir, String fileName, Uint8List bytes) async {
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final File file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<String> _writeDocuments(String fileName, Uint8List bytes) =>
      getApplicationDocumentsDirectory().then((Directory d) => _writeTo(d, fileName, bytes));

  Future<String> _writeTemp(String fileName, Uint8List bytes) =>
      getTemporaryDirectory().then((Directory d) => _writeTo(d, fileName, bytes));

  @override
  Future<ShareOutcome> save(String content, String fileName, String mimeType) async {
    final Uint8List bytes = Uint8List.fromList(utf8.encode(content));
    if (isMobileShareTarget) {
      // 移动端无保存对话框：落应用文档目录，「存到文件」由分享面板承担。
      final String path = await _writeDocuments(fileName, bytes);
      return ShareOutcome(
        ShareOutcomeKind.saved,
        path: path,
        message: '已存到应用文档目录；点「分享」可在系统面板存到文件',
      );
    }
    try {
      final String extension = p.extension(fileName).replaceFirst('.', '');
      final Uri? uri = await FilePicker.saveFile(
        dialogTitle: '保存书单',
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType,
        type: FileType.custom,
        allowedExtensions: <String>[extension],
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
      final String path = await _writeDocuments(fileName, bytes);
      return ShareOutcome(
        ShareOutcomeKind.saved,
        path: path,
        message: '保存对话框不可用（$error），已写入应用文档目录',
      );
    }
  }

  @override
  Future<ShareOutcome> share(
    String content,
    String fileName,
    String mimeType, {
    String? text,
    Rect? origin,
  }) async {
    final Uint8List bytes = Uint8List.fromList(utf8.encode(content));
    try {
      final String path = await _writeTemp(fileName, bytes);
      final ShareResult result = await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(path, mimeType: mimeType)],
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
      final ShareOutcome fallback = await save(content, fileName, mimeType);
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

/// 门面：文件名/MIME 组装 + 异常收敛（弹层持有；测试注入 fake sink）。
class BooklistExportService {
  const BooklistExportService([this.sink = const PlatformTextFileSink()]);

  final TextFileSink sink;

  Future<ShareOutcome> save(String content, BooklistFormat format, {DateTime? now}) async {
    try {
      return await sink.save(content, defaultBooklistFileName(format, now: now), format.mimeType);
    } on Object catch (error) {
      return ShareOutcome(ShareOutcomeKind.failed, message: '保存失败：$error');
    }
  }

  Future<ShareOutcome> share(
    String content,
    BooklistFormat format, {
    String? text,
    Rect? origin,
    DateTime? now,
  }) async {
    try {
      return await sink.share(
        content,
        defaultBooklistFileName(format, now: now),
        format.mimeType,
        text: text,
        origin: origin,
      );
    } on Object catch (error) {
      return ShareOutcome(ShareOutcomeKind.failed, message: '分享失败：$error');
    }
  }
}

/// 打开导出弹层。
Future<void> showBooklistExportSheet(
  BuildContext context,
  BooklistDoc doc, {
  BooklistExportService service = const BooklistExportService(),
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    // 容器样式吃主题 bottomSheetTheme（raised 底 + 顶部 r24），不另传 backgroundColor。
    builder: (BuildContext sheetContext) => BooklistExportSheet(doc: doc, service: service),
  );
}

/// 导出弹层本体（格式分段 + 预览 + 保存/分享）。
class BooklistExportSheet extends StatefulWidget {
  const BooklistExportSheet({super.key, required this.doc, this.service = const BooklistExportService()});

  final BooklistDoc doc;

  /// 导出服务（测试注入 fake sink，见 test/export/）。
  final BooklistExportService service;

  /// 预览行数上限（§P2-4：前 20 行；完整内容以导出文件为准）。
  static const int previewLineLimit = 20;

  @override
  State<BooklistExportSheet> createState() => _BooklistExportSheetState();
}

class _BooklistExportSheetState extends State<BooklistExportSheet> {
  /// 「分享」按钮的屏幕矩形（iPad popover 锚点，share_plus 要求）。
  final GlobalKey _shareButtonKey = GlobalKey(debugLabel: 'booklist-export-share-button');

  BooklistFormat _format = BooklistFormat.markdown;
  bool _busy = false;

  String get _content => renderBooklist(widget.doc, _format);

  String get _fileName =>
      defaultBooklistFileName(_format, now: widget.doc.generatedAt);

  Future<void> _save() async {
    setState(() => _busy = true);
    final ShareOutcome outcome =
        await widget.service.save(_content, _format, now: widget.doc.generatedAt);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    _report(outcome);
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    final ShareOutcome outcome = await widget.service.share(
      _content,
      _format,
      text: widget.doc.heading,
      origin: _shareOrigin(),
      now: widget.doc.generatedAt,
    );
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    _report(outcome);
  }

  Rect? _shareOrigin() {
    final RenderObject? object = _shareButtonKey.currentContext?.findRenderObject();
    if (object is! RenderBox || !object.hasSize) {
      return null;
    }
    return object.localToGlobal(Offset.zero) & object.size;
  }

  /// 结果 SnackBar（人话 + 落盘路径；与 share_sheet._report 同口径）。
  void _report(ShareOutcome outcome) {
    final String text = switch (outcome.kind) {
      ShareOutcomeKind.saved =>
        '${outcome.message ?? '已保存'}${outcome.path == null ? '' : '\n${outcome.path}'}',
      ShareOutcomeKind.shared => '已交给系统分享面板',
      ShareOutcomeKind.cancelled => outcome.message ?? '已取消',
      ShareOutcomeKind.unsupported => outcome.message ?? '当前平台不支持该操作',
      ShareOutcomeKind.failed => outcome.message ?? '导出失败',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final double sheetHeight = (MediaQuery.sizeOf(context).height * 0.85).clamp(360.0, 860.0);
    return SizedBox(
      height: sheetHeight,
      child: Column(
        children: <Widget>[
          _header(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(s.pagePadding, 0, s.pagePadding, s.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SectionTitle(label: '格式'),
                  SegmentedPill<BooklistFormat>(
                    options: <(BooklistFormat, String)>[
                      for (final BooklistFormat f in BooklistFormat.values) (f, f.label),
                    ],
                    selected: _format,
                    onChanged: (BooklistFormat v) => setState(() => _format = v),
                  ),
                  const SectionTitle(label: '预览'),
                  _preview(c, s),
                  SizedBox(height: s.space2),
                  Text(
                    '将导出: $_fileName',
                    style: AppTypography.tabular(
                      AppTypography.of(context).caption.copyWith(color: c.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _actions(c, s),
        ],
      ),
    );
  }

  Widget _header() {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(s.pagePadding, 0, s.space2, s.space2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('导出书单', style: t.headline.copyWith(color: c.text)),
                Text(
                  widget.doc.metaLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.tabular(t.caption.copyWith(color: c.textMuted)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '关闭',
            visualDensity: VisualDensity.compact,
            icon: AppIcon('close', size: 20, color: c.textSecondary),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  /// 前 [BooklistExportSheet.previewLineLimit] 行 mono 预览（sunken 底 + 1px 边框，
  /// 同弹层字段框语汇）；超出部分给出行数提示，不假装预览即全文。
  Widget _preview(AppColors c, AppSpacing s) {
    final AppTypography t = AppTypography.of(context);
    final List<String> lines = _content.split('\n');
    final bool truncated = lines.length > BooklistExportSheet.previewLineLimit;
    final String body = lines.take(BooklistExportSheet.previewLineLimit).join('\n');
    final String text = truncated
        ? '$body\n……（共 ${lines.length} 行，导出文件包含全部内容）'
        : body;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(s.space3),
      decoration: BoxDecoration(
        color: c.surfaceSunken,
        borderRadius: AppRadius.smBorder,
        border: Border.all(color: c.border, width: AppMetrics.hairline),
      ),
      child: Text(
        text,
        style: t.mono.copyWith(color: c.textSecondary, fontSize: 11, height: 1.7),
      ),
    );
  }

  Widget _actions(AppColors c, AppSpacing s) {
    return Container(
      padding: EdgeInsets.fromLTRB(s.pagePadding, s.space3, s.pagePadding, s.space3),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border, width: AppMetrics.hairline)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: AppButton(
              label: _busy
                  ? '导出中…'
                  : (isMobileShareTarget ? '存到文档目录' : '保存文件'),
              kind: AppButtonKind.outline,
              onPressed: _busy ? null : _save,
            ),
          ),
          SizedBox(width: s.space3),
          Expanded(
            child: AppButton(
              key: _shareButtonKey,
              label: '分享',
              onPressed: _busy ? null : _share,
            ),
          ),
        ],
      ),
    );
  }
}
