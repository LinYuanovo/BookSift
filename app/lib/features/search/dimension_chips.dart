import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repo/queries.dart';
import '../../data/repo/queries_providers.dart';
import '../../theme/app_spacing.dart';
import '../home/cards.dart';

// 维度值 chips（原分类页 §5.12 迁入）：值域 + 真实命中计数；
// 搜索台维度取值浮层复用 DimensionChips.valuesOf 与 dimensionCountsProvider。

/// 五维当前选中（单选含「全部」）。
final StateProvider<CategorySelection> categorySelectionProvider =
    StateProvider<CategorySelection>((Ref ref) => CategorySelection.empty);

/// 五维真实命中计数（一次聚合查询缓存，drift watch 语义由刷新承担）。
final FutureProvider<CategoryCounts> dimensionCountsProvider =
    FutureProvider<CategoryCounts>((Ref ref) => ref.watch(queriesProvider).dimensionCounts());

/// 维度值 chips（全部 + 值域；带真实命中计数，选中即时过滤）。
class DimensionChips extends ConsumerWidget {
  const DimensionChips({super.key, required this.dim, required this.counts, required this.selection});

  final CategoryDim dim;
  final AsyncValue<CategoryCounts> counts;
  final CategorySelection selection;

  /// 静态值域（月份/旬/来源/类别）；年份数据驱动。
  static List<DimCount> valuesOf(CategoryDim dim, CategoryCounts? counts) {
    if (counts == null) {
      return switch (dim) {
        CategoryDim.year => const <DimCount>[],
        CategoryDim.month => <DimCount>[
            for (int m = 1; m <= 12; m++) DimCount(value: '$m', label: '$m月', count: 0),
          ],
        CategoryDim.tenDay => const <DimCount>[
            DimCount(value: TenDayFilter.upper, label: '上旬', count: 0),
            DimCount(value: TenDayFilter.middle, label: '中旬', count: 0),
            DimCount(value: TenDayFilter.lower, label: '下旬', count: 0),
          ],
        CategoryDim.channel => <DimCount>[
            for (final String ch in ChannelFilter.categoryNamed) DimCount(value: ch, label: ch, count: 0),
            const DimCount(value: ChannelFilter.otherBig, label: '其他', count: 0),
          ],
        CategoryDim.category => <DimCount>[
            for (final String k in CategoryKind.all) DimCount(value: k, label: k, count: 0),
          ],
      };
    }
    return counts.of(dim);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSpacing s = AppSpacing.of(context);
    final CategoryCounts? data = counts.value;
    final List<DimCount> values = valuesOf(dim, data);
    final String? selected = selection.valueOf(dim);
    return StaggerPanel(
      wrap: true,
      spacing: s.chipGap,
      runSpacing: s.space2,
      switchKey: ValueKey<CategoryDim>(dim),
      children: <Widget>[
        CountChip(
          label: '全部',
          count: data?.total,
          selected: selected == null,
          onTap: () => ref.read(categorySelectionProvider.notifier).state =
              _withDim(selection, dim, null),
        ),
        for (final DimCount v in values)
          CountChip(
            label: v.label,
            count: data == null ? null : v.count,
            selected: selected == v.value,
            dangerTint: dim == CategoryDim.category && v.value == CategoryKind.avoid,
            onTap: () {
              // 单选；再次点已选值 = 取消回「全部」（toggled 语义）。
              final String? next = selected == v.value ? null : v.value;
              ref.read(categorySelectionProvider.notifier).state = _withDim(selection, dim, next);
            },
          ),
        if (dim == CategoryDim.year && data == null) const SkeletonBlock(height: 36, width: 200),
      ],
    );
  }

  static CategorySelection _withDim(CategorySelection sel, CategoryDim dim, String? value) {
    return switch (dim) {
      CategoryDim.year => CategorySelection(year: value, month: sel.month, tenDay: sel.tenDay, channel: sel.channel, category: sel.category),
      CategoryDim.month => CategorySelection(year: sel.year, month: value, tenDay: sel.tenDay, channel: sel.channel, category: sel.category),
      CategoryDim.tenDay => CategorySelection(year: sel.year, month: sel.month, tenDay: value, channel: sel.channel, category: sel.category),
      CategoryDim.channel => CategorySelection(year: sel.year, month: sel.month, tenDay: sel.tenDay, channel: value, category: sel.category),
      CategoryDim.category => CategorySelection(year: sel.year, month: sel.month, tenDay: sel.tenDay, channel: sel.channel, category: value),
    };
  }
}
