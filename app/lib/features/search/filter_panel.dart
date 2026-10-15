import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons.dart';
import '../../data/repo/queries.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../home/cards.dart';
import 'dimension_chips.dart';
import 'search_state.dart';

// 搜索页六维筛选 chips（§5.3）：**多行换行**排布（年 月 旬 / 来源 类别 …），
// 点某维 chip → 值域浮层选值（带联动命中计数）；尾部「确认筛选」图标钮收起面板。
//
// 与旧形态的唯一差异是布局：由「单行横向滚动」改为 Wrap 多行（窄屏不再需要左右滑）；
// 值仍在浮层里选（不是把候选值内联铺开）。
//
// 联动计数：浮层内候选计数取自 searchFilterCountsProvider(filter) —— 选 2026 年后
// 月份候选计数随之只反映 2026（口径见 Queries.searchDimensionCounts）。

/// 维度短标签（chips 摘要前缀）。
const Map<CategoryDim, String> kDimPanelTitles = <CategoryDim, String>{
  CategoryDim.year: '年',
  CategoryDim.month: '月',
  CategoryDim.tenDay: '旬',
  CategoryDim.channel: '来源',
  CategoryDim.category: '类别',
};

/// 维度当前值（chips 摘要）。
String? filterValueOf(SearchFilter f, CategoryDim dim) => switch (dim) {
  CategoryDim.year => f.year,
  CategoryDim.month => f.month,
  CategoryDim.tenDay => f.tenDay,
  CategoryDim.channel => f.channel,
  CategoryDim.category => f.category,
};

class SearchFilterPanel extends ConsumerWidget {
  const SearchFilterPanel({super.key, required this.filter, required this.onConfirm});

  final SearchFilter filter;

  /// 「确认筛选」钮（纯图标）：收起面板且**不**聚焦搜索框（不弹输入法）。
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSpacing s = AppSpacing.of(context);
    final SearchDraftNotifier notifier = ref.read(searchDraftProvider.notifier);
    // 固定两行布局（用户口径）：
    //   年 月 旬        [清空筛选（纯图标）]
    //   来源 类别 时间   [确认筛选（纯图标）]
    return Padding(
      padding: EdgeInsets.fromLTRB(s.pagePadding, s.space3, s.pagePadding, s.space2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _panelRow(
            context,
            ref,
            notifier,
            dims: const <CategoryDim>[CategoryDim.year, CategoryDim.month, CategoryDim.tenDay],
            trailing: _IconActionButton(
              tooltip: '清空筛选',
              svgIcon: 'refresh',
              filled: false,
              onTap: filter.isDefault ? null : notifier.clearDimensions,
            ),
          ),
          SizedBox(height: s.space2),
          _panelRow(
            context,
            ref,
            notifier,
            dims: const <CategoryDim>[CategoryDim.channel, CategoryDim.category],
            trailing: _IconActionButton(
              tooltip: '确认筛选',
              svgIcon: 'check',
              filled: true,
              onTap: onConfirm,
            ),
          ),
        ],
      ),
    );
  }

  /// 一行：维度 chips（取固有宽、可收缩省略）+ 行尾图标动作钮（贴右）。
  Widget _panelRow(
    BuildContext context,
    WidgetRef ref,
    SearchDraftNotifier notifier, {
    required List<CategoryDim> dims,
    required Widget trailing,
  }) {
    final AppSpacing s = AppSpacing.of(context);
    final List<Widget> chips = <Widget>[
      for (final CategoryDim dim in dims) _dimChip(context, ref, dim, notifier),
    ];
    // 第二行：类别之后接排序 chip（「时间↓/↑」）。
    if (dims.contains(CategoryDim.category)) {
      chips.add(_sortChip(context, notifier));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // chips 取固有宽（Wrap 不拉伸）；极窄屏/宽字阶下换行（不溢出，行高自增）。
        Expanded(
          child: Wrap(
            spacing: s.chipGap,
            runSpacing: s.space1,
            children: chips,
          ),
        ),
        SizedBox(width: s.chipGap),
        trailing,
      ],
    );
  }

  /// 排序 chip（「时间↓/↑」切换）。
  Widget _sortChip(BuildContext context, SearchDraftNotifier notifier) {
    return CountChip(
      label: filter.sort == SearchSort.timeDesc ? '时间↓' : '时间↑',
      selected: filter.sort != SearchSort.timeDesc,
      onTap: notifier.toggleSort,
    );
  }

  Widget _dimChip(
    BuildContext context,
    WidgetRef ref,
    CategoryDim dim,
    SearchDraftNotifier notifier,
  ) {
    final String? value = filterValueOf(filter, dim);
    final String summary = switch (dim) {
      CategoryDim.year => value == null ? '全部' : yearLabel(value),
      CategoryDim.month => value == null ? '全部' : '$value月',
      CategoryDim.tenDay => value == null ? '全部' : tenDayLabel(value),
      CategoryDim.channel => value == null ? '全部' : channelLabel(value),
      CategoryDim.category => value ?? '全部',
    };
    return CountChip(
      label: '${kDimPanelTitles[dim]}·$summary',
      selected: value != null,
      dangerTint: dim == CategoryDim.category && value == CategoryKind.avoid,
      showChev: true, // 下拉触发器（点开值域浮层）才带 chev
      onTap: () => _pickDimension(context, ref, dim, notifier, value),
    );
  }
}

/// 行尾图标动作钮（纯图标，无文本）：36dp 圆形；[filled]=true 用 accent 实底（确认），
/// false 用 sunken 底（清空/次要动作）；[onTap]=null 时降透明度（不可用态）。
class _IconActionButton extends StatelessWidget {
  const _IconActionButton({
    required this.tooltip,
    required this.svgIcon,
    required this.filled,
    required this.onTap,
  });

  final String tooltip;
  final String svgIcon;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final bool enabled = onTap != null;
    final Color bg = filled ? c.accent : c.surfaceSunken;
    final Color fg = filled ? c.onAccent : c.textSecondary;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: bg,
        borderRadius: AppRadius.pillBorder,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.pillBorder,
          child: Tooltip(
            message: tooltip,
            child: SizedBox(
              width: AppMetrics.chipHeightCompact,
              height: AppMetrics.chipHeightCompact,
              child: Center(child: AppIcon(svgIcon, size: 18, color: fg)),
            ),
          ),
        ),
      ),
    );
  }
}

/// 维度取值浮层（值 chips 带**联动**命中计数：受其它维已选条件约束，见文件头注释）。
void _pickDimension(
  BuildContext context,
  WidgetRef ref,
  CategoryDim dim,
  SearchDraftNotifier notifier,
  String? current,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => SafeArea(
      child: Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? child) {
          final AppColors c = AppColors.of(context);
          final AppTypography t = AppTypography.of(context);
          final AppSpacing s = AppSpacing.of(context);
          final SearchFilter filter = ref.watch(searchDraftProvider).filter;
          final CategoryCounts? counts = ref.watch(searchFilterCountsProvider(filter)).value;
          final List<DimCount> values = DimensionChips.valuesOf(dim, counts);
          return Padding(
            padding: EdgeInsets.fromLTRB(s.pagePadding, 0, s.pagePadding, s.space6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(kDimPanelTitles[dim]!, style: t.headline.copyWith(color: c.text)),
                SizedBox(height: s.space4),
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: s.chipGap,
                      runSpacing: s.space2,
                      children: <Widget>[
                        CountChip(
                          label: '全部',
                          selected: current == null,
                          compact: false,
                          onTap: () {
                            notifier.setDimension(dim, null);
                            Navigator.of(sheetContext).pop();
                          },
                        ),
                        for (final DimCount v in values)
                          CountChip(
                            label: v.label,
                            count: counts == null ? null : v.count,
                            selected: current == v.value,
                            compact: false,
                            dangerTint: dim == CategoryDim.category && v.value == CategoryKind.avoid,
                            onTap: () {
                              notifier.setDimension(dim, v.value);
                              Navigator.of(sheetContext).pop();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
