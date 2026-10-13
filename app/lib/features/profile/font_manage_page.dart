import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fonts/font_registry.dart';
import '../../core/fonts/font_service.dart';
import '../../core/fonts/font_tokens.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 字体管理页（设计系统 v1.4 §2.2）：十角色字体槽下拉 + Aa 样张预览行 +
/// 导入字体（ttf/otf）/ 删除（引用角色自动回退 system）/ 恢复默认。
class FontManagePage extends ConsumerStatefulWidget {
  const FontManagePage({super.key});

  @override
  ConsumerState<FontManagePage> createState() => _FontManagePageState();
}

class _FontManagePageState extends ConsumerState<FontManagePage> {
  bool _busy = false;

  /// 样张文本（每角色预览行以此排版，Aa 打头便于辨认家族特征）。
  static const String _sample = 'Aa 扫书汇 ·《十日终焉》2026';

  static const Map<FontRole, ({String label, String usage})> _roleInfo =
      <FontRole, ({String label, String usage})>{
        FontRole.display: (label: 'Display · 大字', usage: '书聚合页书名、启动大字'),
        FontRole.title: (label: 'Title · 页面标题', usage: '页面大标题'),
        FontRole.headline: (label: 'Headline · 栏目标题', usage: 'AppBar 标题、分区标题'),
        FontRole.cardTitle: (label: 'CardTitle · 卡片标题', usage: '卡片书名 / 帖名'),
        FontRole.body: (label: 'Body · 正文', usage: '正文 / 列表主文字 / 按钮'),
        FontRole.bodyRich: (label: 'BodyRich · 富文本', usage: '楼层富文本正文'),
        FontRole.secondary: (label: 'Secondary · 次级', usage: '摘要 / 次级信息'),
        FontRole.caption: (label: 'Caption · 元信息', usage: '元信息 / 日期'),
        FontRole.label: (label: 'Label · 徽标', usage: '徽标 / 导航 / 大写分区'),
        FontRole.mono: (label: 'Mono · 等宽', usage: '日志流 / 水位'),
      };

  static TextStyle _styleOf(AppTypography t, FontRole role) => switch (role) {
    FontRole.display => t.display,
    FontRole.title => t.title,
    FontRole.headline => t.headline,
    FontRole.cardTitle => t.cardTitle,
    FontRole.body => t.body,
    FontRole.bodyRich => t.bodyRich,
    FontRole.secondary => t.secondary,
    FontRole.caption => t.caption,
    FontRole.label => t.label,
    FontRole.mono => t.mono,
  };

  Future<void> _import(FontService service) async {
    setState(() => _busy = true);
    final String? error = await service.importPickedFont();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      _snack(error);
    } else if (service.registry.isNotEmpty) {
      _snack('已导入「${service.registry.last.familyName}」，可在上方为角色选用');
    }
  }

  Future<void> _confirmDelete(FontService service, ImportedFont font) async {
    final AppColors colors = AppColors.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('删除字体'),
        content: Text('删除「${font.familyName}」？引用它的角色将恢复系统字体。'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final String? error = await service.deleteFont(font.fontId);
    if (error != null) _snack(error);
  }

  Future<void> _resetRoles(FontService service) async {
    final String? error = await service.resetRoles();
    _snack(error ?? '已恢复系统默认字体');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final FontService service = ref.watch(fontServiceProvider);
    final AppTypography t = AppTypography.of(context);
    final AppColors colors = AppColors.of(context);
    final AppSpacing space = AppSpacing.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('字体管理'),
        actions: <Widget>[
          TextButton(onPressed: _busy ? null : () => _resetRoles(service), child: const Text('恢复默认')),
          SizedBox(width: space.space2),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(space.pagePadding, space.space4, space.pagePadding, space.space8),
        children: <Widget>[
          Text(
            '默认使用系统字体；层级美观由字号 / 字重 / 字距 token 保证。'
            '可为每个角色指定导入字体，删除字体后引用它的角色自动恢复系统字体。',
            style: t.secondary.copyWith(color: colors.textMuted),
          ),
          SizedBox(height: space.space6),
          _previewCard(t, colors, space),
          _sectionHeader('角色字体', t, colors, space),
          Card(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: space.cardPadding, vertical: space.space2),
              child: Column(
                children: <Widget>[
                  for (final FontRole role in FontRole.values) ...<Widget>[
                    if (role != FontRole.values.first) const Divider(height: 1),
                    _roleRow(role, service, t, colors, space),
                  ],
                ],
              ),
            ),
          ),
          _sectionHeader('我的字体', t, colors, space),
          Card(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: space.cardPadding, vertical: space.space2),
              child: service.registry.isEmpty
                  ? Padding(
                      padding: EdgeInsets.symmetric(vertical: space.space3),
                      child: Text('暂无导入字体（ttf / otf）', style: t.caption.copyWith(color: colors.textMuted)),
                    )
                  : Column(
                      children: <Widget>[
                        for (final ImportedFont font in service.registry) ...<Widget>[
                          if (font != service.registry.first) const Divider(height: 1),
                          _fontRow(font, service, t, colors, space),
                        ],
                      ],
                    ),
            ),
          ),
          SizedBox(height: space.space6),
          FilledButton.icon(
            onPressed: _busy ? null : () => _import(service),
            icon: const Icon(Icons.add),
            label: Text(_busy ? '导入中…' : '导入字体'),
            style: FilledButton.styleFrom(
              minimumSize: Size.fromHeight(AppMetrics.buttonHeight),
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
            ),
          ),
        ],
      ),
    );
  }

  /// Aa 样张卡：display 大字 + 富文本正文 + 等宽行，随槽位实时换家族。
  Widget _previewCard(AppTypography t, AppColors colors, AppSpacing space) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(space.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(_sample, style: t.display.copyWith(color: colors.text), maxLines: 1, overflow: TextOverflow.ellipsis),
            SizedBox(height: space.space2),
            Text(
              '齐夏坐在桌前，翻开那本泛黄的书册——推荐语与楼层正文按 BodyRich 行高 27 排版。',
              style: t.bodyRich.copyWith(color: colors.text),
            ),
            SizedBox(height: space.space2),
            Text(
              'tid 11097754039 · 推荐 9 · 排雷 2 · 41,305 条',
              style: AppTypography.tabular(t.mono).copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text, AppTypography t, AppColors colors, AppSpacing space) {
    return Padding(
      padding: EdgeInsets.only(top: space.space6, bottom: space.space3),
      child: Text(text, style: t.label.copyWith(color: colors.textMuted)),
    );
  }

  /// 角色行：名称/用途 + Aa 样张（按该角色解析后的 style 排版）+ 槽位下拉。
  Widget _roleRow(FontRole role, FontService service, AppTypography t, AppColors colors, AppSpacing space) {
    final ({String label, String usage}) info = _roleInfo[role]!;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: space.space3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(info.label, style: t.label.copyWith(color: colors.textSecondary)),
                Text(info.usage, style: t.caption.copyWith(color: colors.textMuted)),
                SizedBox(height: space.space1),
                Text(
                  _sample,
                  style: _styleOf(t, role).copyWith(color: colors.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: space.space3),
          _SlotDropdown(role: role, service: service),
        ],
      ),
    );
  }

  Widget _fontRow(ImportedFont font, FontService service, AppTypography t, AppColors colors, AppSpacing space) {
    final DateTime d = font.importedAt;
    final String date = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return Padding(
      padding: EdgeInsets.symmetric(vertical: space.space2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(font.familyName, style: t.bodyStrong.copyWith(color: colors.text)),
                Text('${font.fileName} · 导入于 $date', style: t.caption.copyWith(color: colors.textMuted)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: colors.danger),
            tooltip: '删除',
            onPressed: _busy ? null : () => _confirmDelete(service, font),
          ),
        ],
      ),
    );
  }
}

/// 单角色槽位下拉：system 或任一已导入字体。
class _SlotDropdown extends StatelessWidget {
  const _SlotDropdown({required this.role, required this.service});

  final FontRole role;
  final FontService service;

  @override
  Widget build(BuildContext context) {
    final AppTypography t = AppTypography.of(context);
    final AppColors colors = AppColors.of(context);
    final FontSlot slot = service.slotOf(role);
    // 防御：槽指向已被删除的字体时按 system 展示（服务层删除时已自动回退）。
    final bool known = slot.isSystem || service.registry.any((ImportedFont f) => f.fontId == slot.fontId);
    final FontSlot value = known ? slot : const FontSlot.system();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: DropdownButton<FontSlot>(
        value: value,
        isDense: true,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        borderRadius: AppRadius.mdBorder,
        style: t.caption.copyWith(color: colors.text),
        items: <DropdownMenuItem<FontSlot>>[
          DropdownMenuItem<FontSlot>(value: const FontSlot.system(), child: const Text('系统默认')),
          for (final ImportedFont font in service.registry)
            DropdownMenuItem<FontSlot>(
              value: FontSlot.imported(font.fontId),
              child: Text(font.familyName, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (FontSlot? next) async {
          if (next == null || next == value) return;
          final String? error = await service.setRoleSlot(role, next);
          if (error != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
          }
        },
      ),
    );
  }
}
