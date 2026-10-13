import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/window_size.dart';
import '../../data/repo/queries.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../content/detail_slot.dart';
import '../home/cards.dart';

// 分类页（§5.12 · P0-14）：五维手风琴独占展开（MI-8）+ 真实命中计数 chips +
// 选中即时 AND 过滤预览 + 「查看全部结果」携条件跳搜索。
// 宽屏（medium+）手风琴退化为五维常驻面板（设计系统 v1.3 §9.4）。

/// 五维当前选中（单选含「全部」）。
final StateProvider<CategorySelection> categorySelectionProvider =
    StateProvider<CategorySelection>((Ref ref) => CategorySelection.empty);

/// 独占展开：同时至多一组 open（§6.6 ExpansionController；默认第一组「年份」展开）。
final StateProvider<CategoryDim?> accordionOpenProvider =
    StateProvider<CategoryDim?>((Ref ref) => CategoryDim.year);

/// 五维真实命中计数（一次聚合查询缓存，drift watch 语义由刷新承担）。
final FutureProvider<CategoryCounts> dimensionCountsProvider =
    FutureProvider<CategoryCounts>((Ref ref) => ref.watch(queriesProvider).dimensionCounts());

/// 选中即时过滤：交集真实条数 + 预览前 5 条书级卡。
final categoryPreviewProvider = FutureProvider.family<CategoryPreview, CategorySelection>(
  (Ref ref, CategorySelection sel) => ref.watch(queriesProvider).categoryPreview(sel),
);

/// 维度静态值域（计数由 dimensionCountsProvider 填充；年份为数据驱动）。
const Map<CategoryDim, String> _dimTitles = <CategoryDim, String>{
  CategoryDim.year: '年份',
  CategoryDim.month: '月份',
  CategoryDim.tenDay: '旬',
  CategoryDim.channel: '来源',
  CategoryDim.category: '类别',
};

String dimSummary(CategoryDim dim, String? value) {
  if (value == null) {
    return '全部';
  }
  return switch (dim) {
    CategoryDim.year => yearLabel(value),
    CategoryDim.month => '$value月',
    CategoryDim.tenDay => tenDayLabel(value),
    CategoryDim.channel => channelLabel(value),
    CategoryDim.category => value,
  };
}

class CategoryPage extends ConsumerWidget {
  const CategoryPage({super.key});

  void _reset(WidgetRef ref) => ref.read(categorySelectionProvider.notifier).state = CategorySelection.empty;

  void _viewAllResults(BuildContext context, CategorySelection sel) {
    final Map<String, String> params = <String, String>{
      ...sel.toFilter().toUriParams(),
      'browse': '1', // 关键词空 = 纯条件浏览（§5.12 → §5.4）
    };
    context.go(Uri(path: '/search', queryParameters: params).toString());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CategorySelection selection = ref.watch(categorySelectionProvider);
    final AsyncValue<CategoryCounts> counts = ref.watch(dimensionCountsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('分类'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: '搜索',
            onPressed: () => context.go('/search'),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final WindowSizeClass size = WindowSize.fromWidth(constraints.maxWidth);
          if (size == WindowSizeClass.compact) {
            return _compact(context, ref, selection, counts);
          }
          return _wide(context, ref, selection, counts, size);
        },
      ),
    );
  }

  Widget _subtitle(BuildContext context, AsyncValue<CategoryCounts> counts) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final int? total = counts.value?.total;
    return Text(
      total == null ? '按维度浏览' : '按维度浏览 · 全库 $total 条',
      style: AppTypography.tabular(t.secondary.copyWith(color: c.textMuted)),
    );
  }

  Widget _resetButton(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    return TextButton(
      onPressed: () => _reset(ref),
      child: Text('重置', style: t.bodyStrong.copyWith(color: c.accentStrong)),
    );
  }

  /// compact：手风琴 + 结果（纵向单列，MI-8）。
  Widget _compact(
    BuildContext context,
    WidgetRef ref,
    CategorySelection selection,
    AsyncValue<CategoryCounts> counts,
  ) {
    final AppSpacing s = AppSpacing.of(context);
    final CategoryDim? open = ref.watch(accordionOpenProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dimensionCountsProvider);
        ref.invalidate(categoryPreviewProvider(selection));
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(s.pagePadding, s.space4, s.pagePadding, s.space8),
        children: <Widget>[
          _subtitle(context, counts),
          SectionTitle(label: '维度', trailing: _resetButton(context, ref)),
          for (final CategoryDim dim in CategoryDim.values) ...<Widget>[
            _DimensionGroup(
              dim: dim,
              open: open == dim,
              counts: counts,
              selection: selection,
              onToggle: () {
                // 独占展开：展开本组同时其余已开组收起（先收后开并行，MI-8）。
                ref.read(accordionOpenProvider.notifier).state = open == dim ? null : dim;
              },
            ),
            SizedBox(height: s.space3),
          ],
          _ResultSection(selection: selection, onViewAll: () => _viewAllResults(context, selection)),
        ],
      ),
    );
  }

  /// medium/expanded：五维常驻面板 280（独立滚动）+ 结果列 ≤720（§9.3 W2/§9.4）。
  Widget _wide(
    BuildContext context,
    WidgetRef ref,
    CategorySelection selection,
    AsyncValue<CategoryCounts> counts,
    WindowSizeClass size,
  ) {
    final AppColors c = AppColors.of(context);
    final AppSpacing s = AppSpacing.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          width: 280,
          child: ListView(
            padding: EdgeInsets.fromLTRB(s.space5, s.space5, s.space5, s.space8),
            children: <Widget>[
              _subtitle(context, counts),
              SectionTitle(label: '维度', trailing: _resetButton(context, ref)),
              for (final CategoryDim dim in CategoryDim.values) ...<Widget>[
                _DimensionResident(dim: dim, counts: counts, selection: selection),
                SizedBox(height: s.space5),
              ],
            ],
          ),
        ),
        VerticalDivider(width: AppMetrics.hairline, thickness: AppMetrics.hairline, color: c.border),
        Expanded(
          child: ConstrainedContent(
            child: ListView(
              padding: EdgeInsets.fromLTRB(s.pagePadding, s.space5, s.pagePadding, s.space8),
              children: <Widget>[
                _ResultSection(selection: selection, onViewAll: () => _viewAllResults(context, selection)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 手风琴组（MI-8）：组头 min-h60（维度名 + 选中摘要 + chevron 200ms decelerate），
/// 面板展开 300ms emphasize / 收起 200ms accelerate（exit-faster-than-enter），
/// 组内值 chips stagger 40ms×i 上限 8。高度动画=单面板局部豁免（§6.8）。
class _DimensionGroup extends ConsumerWidget {
  const _DimensionGroup({
    required this.dim,
    required this.open,
    required this.counts,
    required this.selection,
    required this.onToggle,
  });

  final CategoryDim dim;
  final bool open;
  final AsyncValue<CategoryCounts> counts;
  final CategorySelection selection;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final AppMotionTheme motion = AppMotionTheme.of(context);
    final String? selected = selection.valueOf(dim);
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: AppRadius.lgBorder,
          border: Border.all(color: open ? c.borderStrong : c.border, width: AppMetrics.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: <Widget>[
            InkWell(
              onTap: onToggle,
              child: Container(
                constraints: const BoxConstraints(minHeight: AppMetrics.accordionHeaderHeight),
                padding: EdgeInsets.symmetric(horizontal: s.space5),
                child: Row(
                  children: <Widget>[
                    Text(_dimTitles[dim]!, style: t.bodyStrong.copyWith(color: c.text)),
                    const Spacer(),
                    Text(
                      dimSummary(dim, selected),
                      style: t.caption.copyWith(
                        color: selected == null ? c.textMuted : c.accentStrong,
                        fontWeight: selected == null ? FontWeight.w400 : FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: s.space2),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: motion.fast,
                      curve: motion.decelerate,
                      child: Icon(Icons.expand_more_rounded, size: 20, color: c.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: open ? motion.enter.duration : motion.exit.duration,
              curve: open ? motion.enter.curve : motion.exit.curve,
              alignment: Alignment.topCenter,
              child: open
                  ? Padding(
                      padding: EdgeInsets.fromLTRB(s.space4, 0, s.space4, s.space4),
                      child: DimensionChips(dim: dim, counts: counts, selection: selection),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// 宽屏常驻维度小节（dim-sec：组头 32 无 chevron 无折叠，§9.5）。
class _DimensionResident extends ConsumerWidget {
  const _DimensionResident({required this.dim, required this.counts, required this.selection});

  final CategoryDim dim;
  final AsyncValue<CategoryCounts> counts;
  final CategorySelection selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final String? selected = selection.valueOf(dim);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 32,
          child: Row(
            children: <Widget>[
              Text(_dimTitles[dim]!, style: t.bodyStrong.copyWith(color: c.text)),
              const Spacer(),
              Text(
                dimSummary(dim, selected),
                style: t.caption.copyWith(
                  color: selected == null ? c.textMuted : c.accentStrong,
                  fontWeight: selected == null ? FontWeight.w400 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.of(context).space2),
        DimensionChips(dim: dim, counts: counts, selection: selection),
      ],
    );
  }
}

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

/// 结果区：命中计数（AnimatedSwitcher）+ 预览前 5 书级卡 + 查看全部结果。
class _ResultSection extends ConsumerWidget {
  const _ResultSection({required this.selection, required this.onViewAll});

  final CategorySelection selection;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final AppMotionTheme motion = AppMotionTheme.of(context);
    final AsyncValue<CategoryPreview> async = ref.watch(categoryPreviewProvider(selection));
    final CategoryPreview? preview = async.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionTitle(label: '结果'),
        if (preview == null && async.isLoading) ...<Widget>[
          const SkeletonBlock(height: 20, width: 160),
          SizedBox(height: s.space3),
          const SkeletonBlock(height: 96),
        ],
        if (preview == null && async.hasError)
          AppEmptyState(
            title: '查询失败',
            icon: Icons.error_outline_rounded,
            action: AppButton(
              label: '重试',
              kind: AppButtonKind.outline,
              onPressed: () => ref.invalidate(categoryPreviewProvider(selection)),
            ),
          ),
        if (preview != null && preview.count == 0)
          AppEmptyState(
            title: '当前组合下没有条目',
            message: '机器分类，可能有误差；试着放宽维度',
            action: AppButton(
              label: '清空筛选',
              kind: AppButtonKind.outline,
              onPressed: () =>
                  ref.read(categorySelectionProvider.notifier).state = CategorySelection.empty,
            ),
          ),
        if (preview != null && preview.count > 0) ...<Widget>[
          // 命中计数即时刷新（motion.switch + tabular 防跳动，§6.4）。
          AnimatedSwitcher(
            duration: motion.switch_.duration,
            switchInCurve: motion.switch_.curve,
            switchOutCurve: motion.exit.curve,
            child: Text(
              '命中 ${preview.count} 条 · 预览前 ${preview.entries.length}',
              key: ValueKey<int>(preview.count),
              style: AppTypography.tabular(t.secondary.copyWith(color: c.textSecondary)),
            ),
          ),
          SizedBox(height: s.space3),
          StaggerPanel(
            spacing: s.cardGap,
            switchKey: ValueKey<CategorySelection>(selection),
            children: <Widget>[
              for (final EntryRow e in preview.entries)
                BookEntryCard(
                  key: ValueKey<int>(e.id),
                  entry: e,
                  onTap: e.bookGroupId == null
                      ? null
                      : () => openBookDetail(context, e.bookGroupId!, snapshot: selection.toFilter()),
                  onBookTap: (String n) => context.go('/search?q=${Uri.encodeComponent(n)}'),
                ),
            ],
          ),
          SizedBox(height: s.space5),
          SizedBox(width: double.infinity, child: AppButton(label: '查看全部结果  →', onPressed: onViewAll)),
        ],
      ],
    );
  }
}
