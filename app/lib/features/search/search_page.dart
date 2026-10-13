import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_database.dart';
import '../../data/repo/queries.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../category/category_page.dart' show DimensionChips, dimensionCountsProvider;
import '../content/detail_slot.dart';
import '../home/cards.dart';
import 'search_state.dart';

// 搜索台（§5.3）+ 搜索结果（§5.4 书级）：关键词 + 六维筛选 chips + 历史（点击复现条件）
// + 联想 + 热门书名；FTS/LIKE 兜底见 Queries.searchBooks（§7.3）。

/// 维度短标签（chips 用）。
const Map<CategoryDim, String> kDimShortTitles = <CategoryDim, String>{
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

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, this.initialParams});

  /// 路由 queryParameters（书名点击/分类页「查看全部结果」携条件进入，§5.6/§5.12）。
  final Map<String, String>? initialParams;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _appliedSignature;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() => _focused = _focusNode.hasFocus));
    _syncFromParams();
  }

  @override
  void didUpdateWidget(SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFromParams();
  }

  /// URI 条件 → 草稿预填并自动提交（同一签名只应用一次，防循环）。
  ///
  /// 本方法由 initState / didUpdateWidget 调用，而 Riverpod **禁止在 build 期改 provider**
  /// （"Tried to modify a provider while the widget tree was building"），故把 applyFilter
  /// 推到帧后回调执行。
  void _syncFromParams() {
    final Map<String, String>? params = widget.initialParams;
    if (params == null || params.isEmpty) {
      return;
    }
    final String signature = params.entries.map((MapEntry<String, String> e) => '${e.key}=${e.value}').join('&');
    if (signature == _appliedSignature) {
      return;
    }
    _appliedSignature = signature;
    final SearchFilter f = SearchFilter.fromUriParams(params);
    _controller.text = f.query;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(searchDraftProvider.notifier).applyFilter(f, submit: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _focusNode.unfocus();
    await ref.read(searchDraftProvider.notifier).submit();
  }

  void _searchFor(String name) {
    _controller.text = name;
    ref.read(searchDraftProvider.notifier).setQuery(name);
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    // 外部改词（历史点击/联想）同步回输入框。
    ref.listen(searchDraftProvider, (SearchDraft? prev, SearchDraft next) {
      if (next.filter.query != _controller.text) {
        _controller.text = next.filter.query;
      }
    });
    final SearchDraft draft = ref.watch(searchDraftProvider);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.of(context).space3,
        title: _searchField(context),
      ),
      body: Column(
        children: <Widget>[
          _FilterChipsRow(filter: draft.filter),
          const Divider(height: 1),
          Expanded(child: draft.submitted ? _ResultsView(draft: draft) : _ConsoleView(onSearch: _searchFor)),
        ],
      ),
    );
  }

  Widget _searchField(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppMotionTheme motion = AppMotionTheme.of(context);
    return AnimatedContainer(
      duration: motion.fast,
      curve: motion.standard,
      height: AppMetrics.inputHeight,
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.of(context).space4),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: AppRadius.xlBorder,
        border: Border.all(color: _focused ? c.accent : c.borderStrong, width: AppMetrics.hairline),
        // focus = 3px accent 18% ring（设计系统 §4 输入框）。
        boxShadow: _focused
            ? <BoxShadow>[BoxShadow(color: c.accent.withValues(alpha: 0.18), spreadRadius: 3)]
            : const <BoxShadow>[],
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.search_rounded, size: 20, color: _focused ? c.accentStrong : c.textMuted),
          SizedBox(width: AppSpacing.of(context).space2),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (String v) {
                ref.read(searchDraftProvider.notifier).setQuery(v);
                _submit();
              },
              onChanged: (String v) => ref.read(searchDraftProvider.notifier).setQuery(v),
              style: t.body.copyWith(color: c.text),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '搜索书名/作者/关键词…',
                hintStyle: t.body.copyWith(color: c.textMuted),
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close_rounded, size: 18, color: c.textMuted),
              visualDensity: VisualDensity.compact,
              tooltip: '清空并回搜索台',
              onPressed: () {
                _controller.clear();
                ref.read(searchDraftProvider.notifier).setQuery('');
                ref.read(searchDraftProvider.notifier).backToConsole();
              },
            ),
        ],
      ),
    );
  }
}

/// 六维筛选 chips（当前非默认值高亮；「分类·排雷」红染，设计系统 §3 #02）。
class _FilterChipsRow extends ConsumerWidget {
  const _FilterChipsRow({required this.filter});

  final SearchFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSpacing s = AppSpacing.of(context);
    final SearchDraftNotifier notifier = ref.read(searchDraftProvider.notifier);
    return Padding(
      padding: EdgeInsets.fromLTRB(s.pagePadding, s.space3, s.pagePadding, s.space3),
      child: Wrap(
        spacing: s.space2,
        runSpacing: s.space2,
        children: <Widget>[
          for (final CategoryDim dim in CategoryDim.values)
            _dimChip(context, ref, dim, notifier),
          CountChip(
            label: filter.sort == SearchSort.timeDesc ? '时间↓' : '时间↑',
            selected: filter.sort != SearchSort.timeDesc,
            onTap: notifier.toggleSort,
          ),
          if (!filter.isDefault)
            CountChip(
              label: '清空筛选',
              selected: false,
              onTap: notifier.clearDimensions,
            ),
        ],
      ),
    );
  }

  Widget _dimChip(BuildContext context, WidgetRef ref, CategoryDim dim, SearchDraftNotifier notifier) {
    final String? value = filterValueOf(filter, dim);
    final String summary = switch (dim) {
      CategoryDim.year => value == null ? '全部' : yearLabel(value),
      CategoryDim.month => value == null ? '全部' : '$value月',
      CategoryDim.tenDay => value == null ? '全部' : tenDayLabel(value),
      CategoryDim.channel => value == null ? '全部' : channelLabel(value),
      CategoryDim.category => value ?? '全部',
    };
    return CountChip(
      label: '${kDimShortTitles[dim]}·$summary',
      selected: value != null,
      dangerTint: dim == CategoryDim.category && value == CategoryKind.avoid,
      onTap: () => _pickDimension(context, ref, dim, notifier, value),
    );
  }
}

/// 维度取值浮层（值 chips 带真实命中计数，复用分类页值域）。
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
          final CategoryCounts? counts = ref.watch(dimensionCountsProvider).value;
          final List<DimCount> values = DimensionChips.valuesOf(dim, counts);
          return Padding(
            padding: EdgeInsets.fromLTRB(s.pagePadding, 0, s.pagePadding, s.space6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(kDimShortTitles[dim]!, style: t.headline.copyWith(color: c.text)),
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

/// 搜索台（未提交）：联想 + 历史 + 热门书名（§5.3）。
class _ConsoleView extends ConsumerWidget {
  const _ConsoleView({required this.onSearch});

  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final String suggestInput = ref.watch(suggestInputProvider);
    final List<String> suggests =
        suggestInput.isEmpty ? const <String>[] : (ref.watch(suggestProvider(suggestInput)).value ?? const <String>[]);
    final List<SearchHistoryEntry> history = ref.watch(searchHistoryProvider).value ?? const <SearchHistoryEntry>[];
    final List<HotBook> hot = ref.watch(hotBooksProvider).value ?? const <HotBook>[];
    return ListView(
      padding: EdgeInsets.fromLTRB(s.pagePadding, 0, s.pagePadding, s.space8),
      children: <Widget>[
        if (suggests.isNotEmpty) ...<Widget>[
          SectionTitle(label: '联想'),
          for (final String name in suggests)
            SizedBox(
              height: AppMetrics.suggestionRowHeight,
              child: InkWell(
                onTap: () => onSearch(name),
                borderRadius: AppRadius.mdBorder,
                child: Row(
                  children: <Widget>[
                    Icon(Icons.search_rounded, size: 16, color: c.textMuted),
                    SizedBox(width: s.space3),
                    Expanded(
                      child: Text('《$name》', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: t.body.copyWith(color: c.bookname)),
                    ),
                  ],
                ),
              ),
            ),
        ],
        SectionTitle(
          label: '搜索历史',
          trailing: history.isEmpty
              ? null
              : TextButton(
                  onPressed: () => ref.read(queriesProvider).clearHistory(),
                  child: Text('清空', style: t.caption.copyWith(color: c.textMuted)),
                ),
        ),
        if (history.isEmpty)
          Text('暂无历史；点击下方热门书名开始', style: t.secondary.copyWith(color: c.textMuted)),
        for (final SearchHistoryEntry h in history) _HistoryRow(entry: h),
        if (hot.isNotEmpty) ...<Widget>[
          SectionTitle(label: '热门书名'),
          Wrap(
            spacing: s.chipGap,
            runSpacing: s.space2,
            children: <Widget>[
              for (final HotBook b in hot) BookNameChip(name: b.name, onTap: () => onSearch(b.name)),
            ],
          ),
        ],
      ],
    );
  }
}

/// 历史行：完整条件摘要 + 日期；点击=复现六维直接出结果；左滑删除；长按复制关键词（§5.3）。
class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({required this.entry});

  final SearchHistoryEntry entry;

  String _summary() {
    final List<String> parts = <String>[
      if (entry.query.isNotEmpty) entry.query,
      if (entry.year != null) yearLabel(entry.year!),
      if (entry.month != null) '${entry.month}月',
      if (entry.tenDay != null) tenDayLabel(entry.tenDay!),
      if (entry.channel != null) channelLabel(entry.channel!),
      if (entry.category != null) entry.category!,
    ];
    return parts.isEmpty ? '全部' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final DateTime when = entry.searchedAt;
    final String dateLabel =
        '${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')}';
    return Dismissible(
      key: ValueKey<int>(entry.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => ref.read(queriesProvider).deleteHistory(entry.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: s.space5),
        color: c.dangerSoft,
        child: Icon(Icons.delete_outline_rounded, color: c.danger),
      ),
      child: SizedBox(
        height: AppMetrics.listRowHeight,
        child: InkWell(
          onTap: () => ref.read(searchDraftProvider.notifier).applyHistory(entry),
          onLongPress: () {
            Clipboard.setData(ClipboardData(text: entry.query));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('关键词已复制到剪贴板')));
          },
          borderRadius: AppRadius.mdBorder,
          child: Row(
            children: <Widget>[
              Icon(Icons.history_rounded, size: 16, color: c.textMuted),
              SizedBox(width: s.space3),
              Expanded(
                child: Text(_summary(), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: t.body.copyWith(color: c.text)),
              ),
              SizedBox(width: s.space2),
              Text(dateLabel, style: AppTypography.tabular(t.caption.copyWith(color: c.textMuted))),
            ],
          ),
        ),
      ),
    );
  }
}

/// 结果视图（§5.4 书级）：命中总数 + 书级卡列表 + 无限分页（每页 40）。
class _ResultsView extends ConsumerWidget {
  const _ResultsView({required this.draft});

  final SearchDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final AppMotionTheme motion = AppMotionTheme.of(context);
    final int pages = ref.watch(resultPageProvider);
    final SearchFilter effective = draft.filter.copyWith(limit: 40 * pages, offset: 0);
    final AsyncValue<SearchOutcome> async = ref.watch(searchResultProvider(effective));
    final SearchOutcome? outcome = async.value;

    // FTS 异常降级 → SnackBar「已降级为慢速搜索」（§5.3 错误态；MI-4）。
    ref.listen<AsyncValue<SearchOutcome>>(searchResultProvider(effective),
        (AsyncValue<SearchOutcome>? prev, AsyncValue<SearchOutcome> next) {
      if (next.value?.degraded == true && prev?.value?.degraded != true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已降级为慢速搜索')));
      }
    });

    return ListView(
      padding: EdgeInsets.fromLTRB(s.pagePadding, s.space3, s.pagePadding, s.space8),
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Text(
                draft.filter.query.isEmpty ? '条件浏览' : '"${draft.filter.query}"',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.headline.copyWith(color: c.text),
              ),
            ),
            // 命中总数原位切换（motion.switch + tabular，§6.4）；>5000 显示 5000+。
            AnimatedSwitcher(
              duration: motion.switch_.duration,
              switchInCurve: motion.switch_.curve,
              child: Text(
                outcome == null ? '…' : '${outcome.page.total > 5000 ? '5000+' : outcome.page.total} 结果',
                key: ValueKey<int>(outcome?.page.total ?? -1),
                style: AppTypography.tabular(t.secondary.copyWith(color: c.textMuted)),
              ),
            ),
            if (outcome?.usedFts ?? false)
              Padding(
                padding: EdgeInsets.only(left: s.space2),
                child: Text('FTS', style: t.label.copyWith(color: c.textMuted, letterSpacing: 0)),
              ),
          ],
        ),
        SizedBox(height: s.space3),
        if (outcome == null && async.isLoading) ...<Widget>[
          for (int i = 0; i < 5; i++)
            Padding(
              padding: EdgeInsets.only(bottom: s.cardGap),
              child: SkeletonBlock(height: 110),
            ),
        ],
        if (outcome == null && async.hasError)
          AppEmptyState(
            title: '查询失败',
            icon: Icons.error_outline_rounded,
            action: AppButton(
              label: '重试',
              kind: AppButtonKind.outline,
              onPressed: () => ref.invalidate(searchResultProvider(effective)),
            ),
          ),
        if (outcome != null && outcome.page.items.isEmpty)
          AppEmptyState(
            title: draft.filter.query.isEmpty ? '没有符合条件的条目' : '没有找到与 "${draft.filter.query}" 相关的书',
            message: '检查错别字 / 减少筛选条件 / 试试 2 字简称',
            icon: Icons.search_off_rounded,
          ),
        if (outcome != null && outcome.page.items.isNotEmpty) ...<Widget>[
          StaggerPanel(
            spacing: s.cardGap,
            switchKey: ValueKey<SearchFilter>(effective),
            children: <Widget>[
              for (final GroupHit hit in outcome.page.items) _GroupHitCard(hit: hit, draft: draft),
            ],
          ),
          if (outcome.page.hasMore) ...<Widget>[
            SizedBox(height: s.space5),
            Center(
              child: AppButton(
                label: '加载更多',
                kind: AppButtonKind.outline,
                onPressed: () => ref.read(resultPageProvider.notifier).state = pages + 1,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// 书级结果卡（§5.4：书名+作者+推荐/排雷计数+最近日期+摘要高亮+渠道徽标集合）。
class _GroupHitCard extends StatelessWidget {
  const _GroupHitCard({required this.hit, required this.draft});

  final GroupHit hit;
  final SearchDraft draft;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final SemanticTone tone = toneOf(flag: hit.bestFlag, category: null);
    return AccentCard(
      tone: tone,
      onTap: () {
        if (hit.groupId != null) {
          openBookDetail(
            context,
            hit.groupId!,
            snapshot: draft.filter,
            highlight: draft.filter.query,
          );
        } else {
          context.go('/search?q=${Uri.encodeComponent(hit.nameNorm)}');
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '《${BookNameChip.stripBrackets(hit.name)}》',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.cardTitle.copyWith(color: c.bookname),
                ),
              ),
              if ((hit.author ?? '').isNotEmpty)
                Text(hit.author!, maxLines: 1, style: t.secondary.copyWith(color: c.textSecondary)),
            ],
          ),
          SizedBox(height: s.space2),
          Row(
            children: <Widget>[
              Icon(Icons.circle, size: 8, color: c.recommend),
              SizedBox(width: s.space1),
              Text('${hit.recommendCount} 推荐',
                  style: AppTypography.tabular(t.caption.copyWith(color: c.recommend))),
              if (hit.avoidCount > 0) ...<Widget>[
                SizedBox(width: s.space3),
                Icon(Icons.circle, size: 8, color: c.danger),
                SizedBox(width: s.space1),
                // 点排雷计数 = 进书聚合页并置「仅排雷」（§5.4，P0-13）。
                GestureDetector(
                  onTap: hit.groupId == null
                      ? null
                      : () => openBookDetail(
                            context,
                            hit.groupId!,
                            snapshot: draft.filter,
                            highlight: draft.filter.query,
                            initialFilter: SemanticFilter.avoid,
                          ),
                  child: Text('${hit.avoidCount} 排雷',
                      style: AppTypography.tabular(
                          t.caption.copyWith(color: c.danger, fontWeight: FontWeight.w600))),
                ),
              ],
              if (hit.hitCount > 1) ...<Widget>[
                SizedBox(width: s.space3),
                Text('${hit.hitCount}条', style: AppTypography.tabular(t.caption.copyWith(color: c.textMuted))),
              ],
              const Spacer(),
              if (hit.latestDate != null)
                Text(hit.latestDate!, style: AppTypography.tabular(t.caption.copyWith(color: c.textMuted))),
            ],
          ),
          if ((hit.snippet ?? '').isNotEmpty) ...<Widget>[
            SizedBox(height: s.space2),
            HighlightText(
              text: hit.snippet!,
              maxLines: 2,
              style: t.secondary.copyWith(color: c.textSecondary),
            ),
          ],
          if (hit.channels.isNotEmpty) ...<Widget>[
            SizedBox(height: s.space3),
            Wrap(
              spacing: s.space2,
              runSpacing: s.space1,
              children: <Widget>[for (final String ch in hit.channels) MetaChip(label: ch)],
            ),
          ],
        ],
      ),
    );
  }
}
