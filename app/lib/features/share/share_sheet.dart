import 'package:flutter/material.dart';

import '../../core/icons.dart';
import '../../core/widgets/app_toast.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../home/cards.dart';
import 'share_card.dart';
import 'share_service.dart';

/// 文字转图分享弹层（原型 §5.11 · M3 P1-4）。
///
/// 形态说明（与线框的一处偏差，已核对）：§5.11 线框把卡片、按钮、设置面板画在同一屏，
/// 标题栏另有 [预览|设置] 分段。本实现取「同屏」而不做分段切换——导出锚点
/// （[RepaintBoundary]）必须在点「保存/分享」的那一帧**已绘制**，一旦被 tab 切出树
/// （或 Offstage/Opacity 停绘）就会栅格化失败或导出旧参数图。
///
/// 控件全部复用 cards.dart 既有原子：[SectionTitle]（分区头）/ [MetaChip]（A−/A+、L−/L+）/
/// [AppButton]（保存、分享）；配色为 4 枚 swatch（§5.11 线框「⬜白 ⬛黑 🟩绿 🟨米」）。
Future<void> showShareSheet(
  BuildContext context,
  ShareCardSpec spec, {
  bool freeMode = false,
  ShareService service = const ShareService(),
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    // 容器样式吃主题 bottomSheetTheme（raised 底 + 顶部 r24），不另传 backgroundColor。
    builder: (BuildContext sheetContext) =>
        ShareSheet(spec: spec, freeMode: freeMode, service: service),
  );
}

/// 分享弹层本体（实时预览 + 参数面板 + 导出动作）。
class ShareSheet extends StatefulWidget {
  const ShareSheet({
    super.key,
    required this.spec,
    this.freeMode = false,
    this.service = const ShareService(),
  });

  /// 入口带入的载荷（帖子正文 / 书聚合多条推荐语 / 自由模式空壳）。
  final ShareCardSpec spec;

  /// 自由模式（我的→工具）：额外给出书名/作者/正文输入框。
  final bool freeMode;

  /// 导出服务（测试注入 fake sink，见 test/share/）。
  final ShareService service;

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  /// 导出锚点：RepaintBoundary 必须常驻且当帧已绘制（见文件头说明）。
  final GlobalKey _boundaryKey = GlobalKey(debugLabel: 'share-card-boundary');

  /// 「分享…」按钮的屏幕矩形（iPad popover 锚点，share_plus 要求）。
  final GlobalKey _shareButtonKey = GlobalKey(debugLabel: 'share-card-share-button');

  late final TextEditingController _watermark =
      TextEditingController(text: widget.spec.effectiveWatermark);
  late final TextEditingController _bookName = TextEditingController(text: widget.spec.bookName ?? '');
  late final TextEditingController _author = TextEditingController(text: widget.spec.author ?? '');
  late final TextEditingController _quote = TextEditingController(text: widget.spec.quote);

  late ShareCardSpec _spec = widget.spec;
  bool _busy = false;

  @override
  void dispose() {
    _watermark.dispose();
    _bookName.dispose();
    _author.dispose();
    _quote.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final ShareOutcome outcome = await widget.service.save(_boundaryKey);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    _report(outcome);
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    final ShareOutcome outcome = await widget.service.share(
      _boundaryKey,
      text: _shareText(),
      origin: _shareOrigin(),
    );
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    _report(outcome);
  }

  /// 随图一起交出去的文案（标题 + 水印）。
  String _shareText() {
    final String? headline = _spec.headline;
    return <String>[?headline, _spec.effectiveWatermark].join(' · ');
  }

  Rect? _shareOrigin() {
    final RenderObject? object = _shareButtonKey.currentContext?.findRenderObject();
    if (object is! RenderBox || !object.hasSize) {
      return null;
    }
    return object.localToGlobal(Offset.zero) & object.size;
  }

  void _report(ShareOutcome outcome) {
    final String text = switch (outcome.kind) {
      ShareOutcomeKind.saved =>
        '${outcome.message ?? '已保存'}${outcome.path == null ? '' : '\n${outcome.path}'}',
      ShareOutcomeKind.shared => '已交给系统分享面板',
      ShareOutcomeKind.cancelled => outcome.message ?? '已取消',
      ShareOutcomeKind.unsupported => outcome.message ?? '当前平台不支持该操作',
      ShareOutcomeKind.failed => outcome.message ?? '导出失败',
    };
    showAppToast(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final double sheetHeight = (MediaQuery.sizeOf(context).height * 0.92).clamp(420.0, 980.0);
    return SizedBox(
      height: sheetHeight,
      child: Column(
        children: <Widget>[
          _header(),
          if (_spec.isTruncated) _truncationNotice(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(s.pagePadding, 0, s.pagePadding, s.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _preview(s),
                  if (widget.freeMode) ...<Widget>[
                    const SectionTitle(label: '内容'),
                    _contentFields(c, s),
                  ],
                  const SectionTitle(label: '参数'),
                  _stepper(
                    label: '字号',
                    value: _spec.fontSize.toStringAsFixed(0),
                    minusLabel: 'A-',
                    plusLabel: 'A+',
                    onMinus: () => setState(
                        () => _spec = _spec.stepFontSize(-ShareCardSpec.fontSizeStep)),
                    onPlus: () =>
                        setState(() => _spec = _spec.stepFontSize(ShareCardSpec.fontSizeStep)),
                    hint: '${ShareCardSpec.minFontSize.toStringAsFixed(0)}–'
                        '${ShareCardSpec.maxFontSize.toStringAsFixed(0)}',
                  ),
                  _stepper(
                    label: '行距',
                    value: _spec.lineHeight.toStringAsFixed(1),
                    minusLabel: 'L-',
                    plusLabel: 'L+',
                    onMinus: () => setState(
                        () => _spec = _spec.stepLineHeight(-ShareCardSpec.lineHeightStep)),
                    onPlus: () =>
                        setState(() => _spec = _spec.stepLineHeight(ShareCardSpec.lineHeightStep)),
                    hint: '${ShareCardSpec.minLineHeight.toStringAsFixed(1)}–'
                        '${ShareCardSpec.maxLineHeight.toStringAsFixed(1)}',
                  ),
                  _paletteRow(c, s),
                  _watermarkField(c, s),
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
                Text('生成图片', style: t.headline.copyWith(color: c.text)),
                Text(
                  widget.freeMode ? '自由模式 · 手动输入或粘贴文本' : '实时预览 · 导出 PNG（2.5×）',
                  style: t.caption.copyWith(color: c.textMuted),
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

  /// §5.11 错误态：>8000 字 → 明确告知截断口径（不静默丢内容）。
  Widget _truncationNotice() {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    return Container(
      margin: EdgeInsets.fromLTRB(s.pagePadding, 0, s.pagePadding, s.space3),
      padding: EdgeInsets.symmetric(horizontal: s.space3, vertical: s.space2),
      decoration: BoxDecoration(color: c.dangerSoft, borderRadius: AppRadius.smBorder),
      child: Row(
        children: <Widget>[
          AppIcon('alert', size: 13, color: c.danger),
          SizedBox(width: s.space2),
          Expanded(
            child: Text(
              '正文 ${_spec.quote.length} 字，超过 ${ShareCardSpec.maxQuoteChars} 字上限：'
              '卡片只渲染前 ${ShareCardSpec.maxQuoteChars} 字'
              '（末尾加「${ShareCardSpec.truncatedSuffix}」）',
              style: t.caption.copyWith(color: c.danger),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview(AppSpacing s) {
    final AppColors c = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.only(top: s.space2),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = (constraints.maxWidth - s.space4 * 2).clamp(240.0, 420.0);
          return Center(
            child: DecoratedBox(
              // 阴影画在 boundary 之外 → 不进导出 PNG。
              decoration: BoxDecoration(
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: c.shadowOverlay,
                    blurRadius: AppMetrics.shadowOverlayBlur,
                    offset: const Offset(0, AppMetrics.shadowOverlayOffsetY),
                  ),
                ],
              ),
              child: RepaintBoundary(
                key: _boundaryKey,
                child: ShareCard(spec: _spec, width: width),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 步进控件行（MetaChip 当 −/+ 按钮，中间 tabular 读数 + 值域提示）。
  Widget _stepper({
    required String label,
    required String value,
    required String minusLabel,
    required String plusLabel,
    required String hint,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: s.space3),
      child: Row(
        children: <Widget>[
          Text(label, style: t.secondary.copyWith(color: c.textSecondary)),
          SizedBox(width: s.space3),
          MetaChip(label: minusLabel, onTap: onMinus),
          SizedBox(width: s.space2),
          SizedBox(
            width: 40,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: AppTypography.tabular(t.bodyStrong.copyWith(color: c.text)),
            ),
          ),
          SizedBox(width: s.space2),
          MetaChip(label: plusLabel, onTap: onPlus),
          SizedBox(width: s.space3),
          Text(hint, style: AppTypography.tabular(t.caption.copyWith(color: c.textMuted))),
        ],
      ),
    );
  }

  Widget _paletteRow(AppColors c, AppSpacing s) {
    final AppTypography t = AppTypography.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: s.space4),
      child: Row(
        children: <Widget>[
          Text('配色', style: t.secondary.copyWith(color: c.textSecondary)),
          SizedBox(width: s.space3),
          for (final ShareCardPalette palette in ShareCardPalette.values)
            Padding(
              padding: EdgeInsets.only(right: s.chipGap),
              child: _swatch(palette, c, t),
            ),
        ],
      ),
    );
  }

  Widget _swatch(ShareCardPalette palette, AppColors c, AppTypography t) {
    final bool selected = palette == _spec.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: '配色 ${palette.label}',
      child: InkWell(
        onTap: () => setState(() => _spec = _spec.copyWith(palette: palette)),
        customBorder: const CircleBorder(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: AppMetrics.minTouchTarget,
              height: AppMetrics.minTouchTarget,
              decoration: BoxDecoration(
                color: palette.background,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? c.accent : palette.border,
                  width: selected ? 2 : AppMetrics.hairline,
                ),
              ),
              child: selected
                  ? Center(child: AppIcon('check', size: 13, color: palette.foreground))
                  : null,
            ),
            const SizedBox(height: 2),
            Text(
              palette.label,
              style: t.caption.copyWith(color: selected ? c.text : c.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _watermarkField(AppColors c, AppSpacing s) {
    final AppTypography t = AppTypography.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _fieldBox(
          c,
          TextField(
            controller: _watermark,
            maxLength: 60,
            onChanged: (String v) => setState(() => _spec = _spec.copyWith(watermark: v)),
            style: t.body.copyWith(color: c.text),
            decoration: InputDecoration(
              isDense: true,
              counterText: '',
              border: InputBorder.none,
              labelText: '水印文字',
              labelStyle: t.caption.copyWith(color: c.textMuted),
            ),
          ),
        ),
        SizedBox(height: s.space1),
        Text(
          '默认「${_spec.defaultWatermark}」；清空即回到默认',
          style: t.caption.copyWith(color: c.textMuted),
        ),
      ],
    );
  }

  Widget _contentFields(AppColors c, AppSpacing s) {
    final AppTypography t = AppTypography.of(context);
    Widget field({
      required TextEditingController controller,
      required String label,
      ValueChanged<String>? onChanged,
      int? maxLines,
      int minLines = 1,
      int? maxLength,
    }) {
      return Padding(
        padding: EdgeInsets.only(bottom: s.space3),
        child: _fieldBox(
          c,
          TextField(
            controller: controller,
            onChanged: onChanged,
            maxLines: maxLines,
            minLines: minLines,
            maxLength: maxLength,
            style: t.body.copyWith(color: c.text),
            decoration: InputDecoration(
              isDense: true,
              counterText: '',
              border: InputBorder.none,
              labelText: label,
              labelStyle: t.caption.copyWith(color: c.textMuted),
            ),
          ),
        ),
      );
    }

    return Column(
      children: <Widget>[
        field(
          controller: _bookName,
          label: '书名（选填，渲染为《书名》）',
          maxLength: 60,
          onChanged: (String v) => setState(() => _spec = _spec.copyWith(bookName: v)),
        ),
        field(
          controller: _author,
          label: '作者（选填）',
          maxLength: 40,
          onChanged: (String v) => setState(() => _spec = _spec.copyWith(author: v)),
        ),
        field(
          controller: _quote,
          label: '正文（粘贴推荐语 / 排雷文）',
          maxLines: null,
          minLines: 4,
          onChanged: (String v) => setState(() => _spec = _spec.copyWith(quote: v)),
        ),
      ],
    );
  }

  /// 输入框容器（house style：raised 底 + 1px border-strong，同搜索台字段）。
  Widget _fieldBox(AppColors c, Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: AppRadius.smBorder,
        border: Border.all(color: c.borderStrong, width: AppMetrics.hairline),
      ),
      child: child,
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
                  : (isMobileShareTarget ? '保存到相册' : '保存图片'),
              kind: AppButtonKind.outline,
              onPressed: _busy ? null : _save,
            ),
          ),
          SizedBox(width: s.space3),
          Expanded(
            child: AppButton(
              key: _shareButtonKey,
              label: '分享…',
              onPressed: _busy ? null : _share,
            ),
          ),
        ],
      ),
    );
  }
}
