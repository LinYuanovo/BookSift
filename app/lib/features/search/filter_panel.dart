import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nav/overlay_motion.dart';
import '../../data/repo/queries.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../home/cards.dart';
import 'dimension_chips.dart';
import 'search_state.dart';

// 搜索页六维筛选 chips（§5.3）：**单一 Wrap 按容器宽度自适应**——放得下单行、放不下
// 按容器宽度换行（行数不固定），顺序恒为 年 月 旬 来源 类别 时间↓；
// 点某维 chip → 值域浮层选值（带联动命中计数）。
// 「清除 / 确认」在 Tab 行（与目录同排，见搜索页 _SearchTabs），本面板只管维度。
//
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
    // 单一 Wrap：chips 取固有宽、不拉伸；宽度够 → 单行，不够 → 按容器宽度换行。
    // 清除 / 确认在 Tab 行（与目录同排），见 SearchPage。
    return Padding(
      padding: EdgeInsets.fromLTRB(s.pagePadding, s.space3, s.pagePadding, s.space2),
      child: Wrap(
        spacing: s.chipGap,
        runSpacing: s.space2,
        children: <Widget>[
          for (final CategoryDim dim in const <CategoryDim>[
            CategoryDim.year,
            CategoryDim.month,
            CategoryDim.tenDay,
            CategoryDim.channel,
            CategoryDim.category,
          ])
            _dimChip(context, ref, dim, notifier),
          // 排序 chip（「时间↓/↑」）恒在末尾，随 Wrap 一起换行。
          _sortChip(context, notifier),
        ],
      ),
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
    sheetAnimationStyle: overlayAnimationStyle(context),
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
