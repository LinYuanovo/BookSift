import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../data/repo/queries.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../content/detail_slot.dart';
import 'cards.dart';

// 首页（§5.2 时间线 + §5.13 热门榜入口 + 随机书荒）。

/// 时间线分页：页数 ×40（本地库瞬时查询，滚动触底加页）。
final StateProvider<int> homePageCountProvider = StateProvider<int>((Ref ref) => 1);

final FutureProvider<List<PostCardData>> homeFeedProvider = FutureProvider<List<PostCardData>>((Ref ref) {
  final int pages = ref.watch(homePageCountProvider);
  return ref.watch(queriesProvider).timelinePosts(limit: pages * 40);
});

/// 热门榜时段（§5.13 分段控件）。
final StateProvider<RankWindow> rankWindowProvider = StateProvider<RankWindow>((Ref ref) => RankWindow.allTime);

/// 榜单锚点「今天」：生产 = 设备当天；测试注入固定日期保证时段窗口确定。
final Provider<DateTime> rankTodayProvider = Provider<DateTime>((Ref ref) => DateTime.now());

final StateProvider<bool> rankExpandedProvider = StateProvider<bool>((Ref ref) => false);

final rankRowsProvider = FutureProvider.family<List<RankRow>, RankWindow>(
  (Ref ref, RankWindow w) => ref.watch(queriesProvider).rankRows(w, today: ref.watch(rankTodayProvider)),
);

final FutureProvider<String?> rankCutoffProvider =
    FutureProvider<String?>((Ref ref) => ref.watch(queriesProvider).dataCutoff());

final FutureProvider<List<EntryRow>> randomBooksProvider =
    FutureProvider<List<EntryRow>>((Ref ref) => ref.watch(queriesProvider).randomBooks(10));

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final ScrollPosition p = _scrollController.position;
    if (p.pixels <= p.maxScrollExtent - 600) {
      return;
    }
    // 触底加载下一页（FutureProvider 以更大 limit 重查，本地库毫秒级）；到底/加载中不重复触发。
    final AsyncValue<List<PostCardData>> feed = ref.read(homeFeedProvider);
    final int pages = ref.read(homePageCountProvider);
    if (feed.isLoading) {
      return;
    }
    final List<PostCardData>? current = feed.value;
    if (current != null && current.length < pages * 40) {
      return;
    }
    ref.read(homePageCountProvider.notifier).state = pages + 1;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openSearch([String? query]) {
    context.go(query == null ? '/search' : '/search?q=${Uri.encodeComponent(query)}');
  }

  @override
  Widget build(BuildContext context) {
    final AppSpacing s = AppSpacing.of(context);
    final AsyncValue<List<PostCardData>> feed = ref.watch(homeFeedProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫书汇'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(homePageCountProvider.notifier).state = 1;
          ref.invalidate(homeFeedProvider);
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: <Widget>[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(s.pagePadding, s.space4, s.pagePadding, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate(<Widget>[
                  _SearchFieldStub(onTap: () => _openSearch()),
                  const _NewContentCard(),
                  SizedBox(height: s.space4),
                  const _FeatureGrid(),
                  const _RankBoard(),
                ]),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: s.pagePadding),
              sliver: SliverToBoxAdapter(
                child: SectionTitle(label: '最新扫书'),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(s.pagePadding, 0, s.pagePadding, s.space8),
              sliver: _feedSliver(feed),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feedSliver(AsyncValue<List<PostCardData>> feed) {
    final List<PostCardData>? cards = feed.value;
    if (cards != null) {
      return _timeline(cards);
    }
    if (feed.isLoading) {
      return SliverToBoxAdapter(child: _feedSkeleton());
    }
    return SliverToBoxAdapter(
      child: AppEmptyState(
        title: '加载失败',
        message: '数据库读取异常，可在 设置 → 数据包管理 中重建',
        icon: Icons.error_outline_rounded,
        action: AppButton(
          label: '重试',
          kind: AppButtonKind.outline,
          onPressed: () => ref.invalidate(homeFeedProvider),
        ),
      ),
    );
  }

  Widget _timeline(List<PostCardData> cards) {
    if (cards.isEmpty) {
      return SliverToBoxAdapter(
        child: AppEmptyState(
          title: '书库为空',
          message: '尚未导入种子数据包；导入后这里会显示最新扫书时间线',
        ),
      );
    }
    final List<TimelineGroup> groups = Queries.groupByDate(cards);
    final AppSpacing s = AppSpacing.of(context);
    final List<int> siblingIds = cards.map((PostCardData d) => d.post.id).toList();
    // 展平：group header + 卡片（懒构建，ListView 语义由 SliverList 承担）。
    final List<Widget> children = <Widget>[];
    int flatIndex = 0;
    for (final TimelineGroup group in groups) {
      children.add(_GroupHeader(date: group.date));
      for (final PostCardData card in group.posts) {
        final int index = flatIndex++;
        children.add(Padding(
          padding: EdgeInsets.only(bottom: s.cardGap),
          child: StaggerItem(
            index: index,
            child: PostCard(
              data: card,
              onTap: () => openPostDetail(
                context,
                ref,
                PostSelection(postId: card.post.id, siblings: siblingIds, position: index),
              ),
              onBookTap: _openSearch,
              onChannelTap: (String channel) => _openSearchWithChannel(channel),
              onLongPress: () => _showPostMenu(card),
            ),
          ),
        ));
      }
    }
    return SliverList(delegate: SliverChildBuilderDelegate((BuildContext context, int i) => children[i], childCount: children.length));
  }

  void _openSearchWithChannel(String channel) {
    if (ChannelFilter.named.contains(channel)) {
      context.go('/search?channel=${Uri.encodeComponent(channel)}');
    } else {
      _openSearch();
    }
  }

  void _showPostMenu(PostCardData card) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.content_copy_rounded),
              title: const Text('复制标题'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: card.post.title ?? ''));
                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('标题已复制到剪贴板')));
              },
            ),
            if (card.books.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.star_border_rounded),
              title: Text('收藏《${BookNameChip.stripBrackets(card.books.first.name)}》'),
              onTap: () async {
                final BookChip chip = card.books.first;
                final NavigatorState navigator = Navigator.of(sheetContext);
                final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
                if (chip.bookGroupId != null) {
                  await ref.read(queriesProvider).toggleFavorite(
                    targetType: FavoriteTarget.bookGroup,
                    targetId: chip.bookGroupId!,
                    title: '《${BookNameChip.stripBrackets(chip.name)}》',
                  );
                }
                navigator.pop();
                messenger.showSnackBar(const SnackBar(content: Text('已收藏')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('查看原帖'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                openPostDetail(context, ref, PostSelection(postId: card.post.id));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _feedSkeleton() {
    final AppSpacing s = AppSpacing.of(context);
    return Column(
      children: <Widget>[
        for (int i = 0; i < 3; i++)
          Padding(
            padding: EdgeInsets.only(bottom: s.cardGap),
            child: SkeletonBlock(height: 120),
          ),
      ],
    );
  }
}

/// 日期分组头（衬线大日期 + 发丝延伸线，设计系统 §3 #01；上 24 下 12）。
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.date});

  final String date;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    return Padding(
      // 测试/无障碍锚点：一天一个组头（§5.2 日期分组流）。
      key: ValueKey<String>('timeline-group-$date'),
      padding: EdgeInsets.only(top: s.groupHeaderTop, bottom: s.groupHeaderBottom),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            date.isEmpty ? '未知日期' : date,
            style: AppTypography.tabular(t.title.copyWith(color: c.text)),
          ),
          SizedBox(width: s.space3),
          Expanded(child: Container(height: AppMetrics.hairline, color: c.border)),
        ],
      ),
    );
  }
}

/// 顶部搜索框（点击跳搜索台，§5.2）。
class _SearchFieldStub extends StatelessWidget {
  const _SearchFieldStub({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.xlBorder,
      child: Container(
        height: AppMetrics.inputHeight,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.of(context).inputPaddingH),
        decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: AppRadius.xlBorder),
        child: Row(
          children: <Widget>[
            Icon(Icons.search_rounded, size: 20, color: c.textMuted),
            SizedBox(width: AppSpacing.of(context).space2),
            Text('搜索书名/作者/关键词…', style: t.body.copyWith(color: c.textMuted)),
          ],
        ),
      ),
    );
  }
}

/// 采集提示卡数据源（collection_state.new_since_visit 之和，drift watch 自动刷新）。
final StreamProvider<int> newContentCountProvider =
    StreamProvider<int>((Ref ref) => ref.watch(queriesProvider).watchNewContentCount());

/// 采集提示卡（有新内容时显示，§5.2；accent-soft 染底，motion.pop 弹现）。
class _NewContentCard extends ConsumerWidget {
  const _NewContentCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int n = ref.watch(newContentCountProvider).value ?? 0;
    if (n <= 0) {
      return const SizedBox.shrink();
    }
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final AppMotionTheme motion = AppMotionTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: s.space4),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.8, end: 1),
        duration: motion.pop.duration,
        curve: motion.pop.curve,
        // pop.curve 为 spring 近似曲线，值会过冲到 >1：opacity 必须 clamp（Opacity 断言 0..1）。
        builder: (BuildContext context, double v, Widget? child) => Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.9 + 0.1 * v, child: child),
        ),
        child: InkWell(
          onTap: () => context.go('/collect'),
          borderRadius: AppRadius.lgBorder,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: s.space4, vertical: s.space3),
            decoration: BoxDecoration(color: c.accentSoft, borderRadius: AppRadius.lgBorder),
            child: Row(
              children: <Widget>[
                Icon(Icons.bolt_rounded, size: 20, color: c.accentStrong),
                SizedBox(width: s.space2),
                Expanded(
                  child: Text(
                    '自采新内容 +$n 条',
                    style: AppTypography.tabular(t.secondary.copyWith(color: c.accentStrong, fontWeight: FontWeight.w600)),
                  ),
                ),
                Text('查看', style: t.bodyStrong.copyWith(color: c.accentStrong)),
                Icon(Icons.chevron_right_rounded, size: 18, color: c.accentStrong),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 功能宫格：热门榜 / 随机书荒 两入口（§5.2，交付后显示）。
class _FeatureGrid extends ConsumerWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSpacing s = AppSpacing.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: _GridEntry(
            icon: Icons.local_fire_department_outlined,
            label: '热门榜',
            onTap: () {
              final StateController<bool> n = ref.read(rankExpandedProvider.notifier);
              n.state = !n.state;
            },
          ),
        ),
        SizedBox(width: s.space3),
        Expanded(
          child: _GridEntry(
            icon: Icons.casino_outlined,
            label: '随机书荒',
            onTap: () => _showRandomSheet(context, ref),
          ),
        ),
      ],
    );
  }
}

class _GridEntry extends StatelessWidget {
  const _GridEntry({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.lgBorder,
      child: Container(
        height: AppMetrics.minTouchTarget + 20,
        padding: EdgeInsets.symmetric(horizontal: s.space4),
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: AppRadius.lgBorder,
          border: Border.all(color: c.border, width: AppMetrics.hairline),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 24, color: c.accent),
            SizedBox(width: s.space3),
            Text(label, style: t.bodyStrong.copyWith(color: c.text)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, size: 20, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

void _showRandomSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      builder: (BuildContext context, ScrollController controller) => _RandomBooksSheet(controller: controller),
    ),
  );
}

/// 随机书荒面板（P1-3：换一批 = invalidate 重抽）。
class _RandomBooksSheet extends ConsumerWidget {
  const _RandomBooksSheet({required this.controller});

  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSpacing s = AppSpacing.of(context);
    final AsyncValue<List<EntryRow>> async = ref.watch(randomBooksProvider);
    final List<EntryRow> books = async.value ?? const <EntryRow>[];
    return ListView(
      controller: controller,
      padding: EdgeInsets.fromLTRB(s.pagePadding, 0, s.pagePadding, s.space8),
      children: <Widget>[
        SectionTitle(
          label: '随机书荒',
          trailing: AppButton(
            label: '换一批',
            kind: AppButtonKind.outline,
            onPressed: () => ref.invalidate(randomBooksProvider),
          ),
        ),
        if (books.isEmpty && async.isLoading) const SkeletonBlock(height: 96),
        if (books.isEmpty && !async.isLoading)
          const AppEmptyState(title: '书库为空', message: '导入种子数据包后即可随机抽书'),
        StaggerPanel(
          spacing: s.cardGap,
          switchKey: ValueKey<int>(books.isEmpty ? 0 : books.first.id),
          children: <Widget>[
            for (final EntryRow e in books)
              BookEntryCard(
                entry: e,
                onTap: e.bookGroupId == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        openBookDetail(context, e.bookGroupId!);
                      },
                onBookTap: (String n) {
                  Navigator.of(context).pop();
                  context.go('/search?q=${Uri.encodeComponent(n)}');
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// 热门榜面板（§5.13：分段时段切换=按范围内推荐次数重排，stagger 重放）。
class _RankBoard extends ConsumerWidget {
  const _RankBoard();

  static const Map<RankWindow, String> _labels = <RankWindow, String>{
    RankWindow.allTime: '全时段',
    RankWindow.thisYear: '本年',
    RankWindow.thisMonth: '本月',
    RankWindow.last30: '近30天',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final AppMotionTheme motion = AppMotionTheme.of(context);
    final bool expanded = ref.watch(rankExpandedProvider);
    final RankWindow window = ref.watch(rankWindowProvider);
    final List<RankRow> rows = ref.watch(rankRowsProvider(window)).value ?? const <RankRow>[];
    final String? cutoff = ref.watch(rankCutoffProvider).value;
    return AnimatedSize(
      duration: expanded ? motion.enter.duration : motion.exit.duration,
      curve: expanded ? motion.enter.curve : motion.exit.curve,
      alignment: Alignment.topCenter,
      child: expanded
          ? Padding(
              padding: EdgeInsets.only(top: s.space4),
              child: Container(
                key: const Key('rank-board'),
                padding: EdgeInsets.all(s.cardPadding),
                decoration: BoxDecoration(
                  color: c.surfaceRaised,
                  borderRadius: AppRadius.lgBorder,
                  border: Border.all(color: c.border, width: AppMetrics.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text('推荐次数榜 · Top10', style: t.headline.copyWith(color: c.text)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          visualDensity: VisualDensity.compact,
                          tooltip: '收起',
                          onPressed: () => ref.read(rankExpandedProvider.notifier).state = false,
                        ),
                      ],
                    ),
                    SizedBox(height: s.space3),
                    SegmentedPill<RankWindow>(
                      options: RankWindow.values.map((RankWindow w) => (w, _labels[w]!)).toList(),
                      selected: window,
                      onChanged: (RankWindow w) => ref.read(rankWindowProvider.notifier).state = w,
                    ),
                    SizedBox(height: s.space4),
                    if (rows.isEmpty && ref.watch(rankRowsProvider(window)).isLoading)
                      const SkeletonBlock(height: 64),
                    if (rows.isEmpty && !ref.watch(rankRowsProvider(window)).isLoading)
                      AppEmptyState(
                        title: '该时段暂无推荐',
                        message: '自采入库后会实时更新本月/近30天榜单',
                        action: AppButton(
                          label: '看看全时段',
                          kind: AppButtonKind.outline,
                          onPressed: () => ref.read(rankWindowProvider.notifier).state = RankWindow.allTime,
                        ),
                      ),
                    // 切时段 = 榜单重排（AnimatedSwitcher crossfade + stagger 重放，§6.4）。
                    AnimatedSwitcher(
                      duration: motion.switch_.duration,
                      switchInCurve: motion.switch_.curve,
                      switchOutCurve: motion.exit.curve,
                      child: StaggerPanel(
                        key: ValueKey<RankWindow>(window),
                        spacing: s.space2,
                        children: <Widget>[
                          for (int i = 0; i < rows.length; i++) _RankRow(row: rows[i], rank: i),
                        ],
                      ),
                    ),
                    if (cutoff != null) ...<Widget>[
                      SizedBox(height: s.space3),
                      Text(
                        '数据截至 $cutoff · 内置库',
                        style: AppTypography.tabular(t.caption.copyWith(color: c.textMuted)),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

/// 榜单行（rank-row：r20 · min-h64 · 前 3 名衬线序号珊瑚强调 · 计数徽标 tabular，设计系统 §4）。
class _RankRow extends StatelessWidget {
  const _RankRow({required this.row, required this.rank});

  final RankRow row;

  /// 0-based 名次。
  final int rank;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final bool top3 = rank < 3;
    return InkWell(
      onTap: () {
        if (row.bookGroupId != null) {
          openBookDetail(context, row.bookGroupId!);
        } else {
          context.go('/search?q=${Uri.encodeComponent(row.nameNorm)}');
        }
      },
      borderRadius: AppRadius.lgBorder,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppMetrics.rankRowMinHeight),
        padding: EdgeInsets.symmetric(horizontal: s.space3, vertical: s.space2),
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: AppRadius.lgBorder,
          border: Border.all(color: c.border, width: AppMetrics.hairline),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 36,
              child: Text(
                '${rank + 1}',
                textAlign: TextAlign.center,
                style: AppTypography.tabular(
                  top3
                      ? t.title.copyWith(fontSize: 23, fontWeight: FontWeight.w700, color: c.accent)
                      : t.headline.copyWith(fontSize: 17, color: c.textMuted),
                ),
              ),
            ),
            SizedBox(width: s.space2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('《${row.name}》', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.cardTitle.copyWith(color: c.text)),
                  if ((row.author ?? '').isNotEmpty)
                    Text(row.author!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption.copyWith(color: c.textMuted)),
                ],
              ),
            ),
            SizedBox(width: s.space2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: c.accentSoft, borderRadius: AppRadius.pillBorder),
              child: Text(
                '${row.count}',
                style: AppTypography.tabular(
                  t.secondary.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: c.accentStrong),
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}
