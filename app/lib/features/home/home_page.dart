import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/icons.dart';
import '../../core/widgets/scroll_chrome.dart';
import '../../data/repo/queries.dart';
import '../../data/repo/queries_providers.dart';
import '../../data/seed_import.dart';
import '../../data/seed_import_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../core/nav/center_slot.dart';
import '../content/detail_slot.dart';
import '../profile/settings_page.dart';
import '../rank/rank_page.dart';
import 'cards.dart';

// 首页（§5.2 时间线 + §5.13 热门榜入口 + 随机书荒）。

/// 时间线分页：页数 ×40（本地库瞬时查询，滚动触底加页）。
final StateProvider<int> homePageCountProvider = StateProvider<int>((Ref ref) => 1);

final FutureProvider<List<PostCardData>> homeFeedProvider = FutureProvider<List<PostCardData>>((Ref ref) {
  final int pages = ref.watch(homePageCountProvider);
  return ref.watch(queriesProvider).timelinePosts(limit: pages * 40);
});

/// 榜单锚点「今天」：生产 = 设备当天；测试注入固定日期保证时段窗口确定。
/// 定义留驻本文件（test/support/harness.dart 按此 import 路径注入锚点），
/// /rank 独立页（features/rank/rank_page.dart）跨文件消费同一 Provider 对象。
final Provider<DateTime> rankTodayProvider = Provider<DateTime>((Ref ref) => DateTime.now());

/// 首页「热门榜」tile 副标题预览（设计稿 01 entry-tile：全时段推荐次数榜 Top1 书名）。
final FutureProvider<RankRow?> rankTileTopProvider = FutureProvider<RankRow?>((Ref ref) async {
  final List<RankRow> rows = await ref
      .watch(queriesProvider)
      .rankRows(RankWindow.allTime, today: ref.watch(rankTodayProvider), limit: 1);
  return rows.isEmpty ? null : rows.first;
});

final FutureProvider<List<EntryRow>> randomBooksProvider =
    FutureProvider<List<EntryRow>>((Ref ref) => ref.watch(queriesProvider).randomBooks(10));

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final ScrollController _scrollController = ScrollController();

  /// 日期目录定位锚点：date → 组头外容器 key（SliverList 懒构建，
  /// 未构建组的 currentContext 为 null，走比例估算分支）。
  final Map<String, GlobalKey> _groupKeys = <String, GlobalKey>{};

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

  /// 日期目录弹层：每行 日期 + 当日帖数，倒序与页面一致（§5.2 时间线分组跳转）。
  /// 日期取原始 YYYY-MM-DD（跨年不歧义；页面组头仍按设计稿 M月D日 格式）。
  void _showDateToc(List<TimelineGroup> groups) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final TimelineGroup group in groups)
              ListTile(
                dense: true,
                title: Text(group.date, style: AppTypography.tabular(AppTypography.of(context).secondary)),
                trailing: Text(
                  '${group.posts.length} 帖',
                  style: AppTypography.tabular(
                    AppTypography.of(context).caption.copyWith(color: AppColors.of(context).textMuted),
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _scrollToGroup(group.date);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 目录跳转：组头已构建 → ensureVisible；未构建（懒构建屏外）→ 按展平序比例
  /// 估算落点 animateTo，帧后再 ensureVisible 二次定位（两段式与
  /// content_detail_page._scrollToFloor 同构）。
  void _scrollToGroup(String date) {
    final BuildContext? built = _groupKeys[date]?.currentContext;
    final AppMotionTheme motion = AppMotionTheme.of(context);
    if (built != null) {
      Scrollable.ensureVisible(
        built,
        duration: motion.transition.duration,
        curve: motion.transition.curve,
        alignment: 0.05,
      );
      return;
    }
    final List<PostCardData>? cards = ref.read(homeFeedProvider).value;
    if (cards == null || !_scrollController.hasClients) {
      return;
    }
    // 展平序列：每组 = 1 组头 + N 卡片；目标组起始 index / 总条数 ≈ 纵向比例落点。
    final List<TimelineGroup> groups = Queries.groupByDate(cards);
    int start = 0;
    for (final TimelineGroup group in groups) {
      if (group.date == date) {
        break;
      }
      start += 1 + group.posts.length;
    }
    final int total = cards.length + groups.length;
    final double max = _scrollController.position.maxScrollExtent;
    _scrollController
        .animateTo(
      (max * (start / total)).clamp(0.0, max),
      duration: motion.transition.duration,
      curve: motion.transition.curve,
    )
        .then((_) {
      final BuildContext? target = _groupKeys[date]?.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(target, alignment: 0.05);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppSpacing s = AppSpacing.of(context);
    final AsyncValue<List<PostCardData>> feed = ref.watch(homeFeedProvider);
    // 日期分组（appbar 目录入口的显隐判定；_timeline 内另算一次展平，O(n) 量级不合并）。
    final List<TimelineGroup> feedGroups =
        feed.value == null ? const <TimelineGroup>[] : Queries.groupByDate(feed.value!);
    // P0-1 首启种子导入状态（§9.2）：导入中 feed 区显示进度面板，失败可原地重试；
    // done 迁移 → 级联失效 queriesProvider（homeFeed/分类/榜单/随机书荒全部随之重建）。
    final SeedImportState seed = ref.watch(seedBootstrapProvider);
    ref.listen<SeedImportState>(seedBootstrapProvider, (SeedImportState? prev, SeedImportState next) {
      if (next.phase == SeedImportPhase.done && prev?.phase != SeedImportPhase.done) {
        ref.invalidate(queriesProvider);
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫书汇'),
        actions: <Widget>[
          // 日期目录入口（§5.2 时间线分组跳转）：feed 有数据且 ≥2 个日期组才显示。
          if (feedGroups.length >= 2)
            IconButton(
              icon: AppIcon('list', size: 20, color: AppColors.of(context).textSecondary),
              tooltip: '目录',
              onPressed: () => _showDateToc(feedGroups),
            ),
          IconButton(
            // 设计 01 首页 appbar 设置 = i-gear（index.html:1148）。
            icon: AppIcon('gear', size: 20, color: AppColors.of(context).textSecondary),
            tooltip: '设置',
            // 宽屏（expanded）在中间功能区原位显示，窄屏仍是全窗页（core/nav/center_slot.dart）。
            onPressed: () => openCenterPage(context, const SettingsPage()),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(homePageCountProvider.notifier).state = 1;
          ref.invalidate(homeFeedProvider);
        },
        child: ScrollChrome(
          controller: _scrollController,
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
                sliver: _feedSliver(feed, seed),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _feedSliver(AsyncValue<List<PostCardData>> feed, SeedImportState seed) {
    // 导入进行中优先于 feed 各态：库还没就绪时骨架屏/空态都是误导。
    if (seed.isImporting) {
      return SliverToBoxAdapter(child: _SeedImportProgress(seedState: seed));
    }
    if (seed.phase == SeedImportPhase.error) {
      return SliverToBoxAdapter(
        child: AppEmptyState(
          title: '种子包导入失败',
          message: seed.message.isEmpty ? '请检查存储空间后重试' : seed.message,
          svgIcon: 'alert',
          action: AppButton(
            label: '重试导入',
            kind: AppButtonKind.outline,
            onPressed: () => ref.read(seedBootstrapProvider.notifier).ensureStarted(),
          ),
        ),
      );
    }
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
        message: '数据库读取异常，请重试；若持续异常，可清除应用数据后重新导入种子包',
        svgIcon: 'alert',
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
          svgIcon: 'book',
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
      // 组头外包带 key 容器：日期目录跳转的 ensureVisible 锚点（同 date 唯一）。
      children.add(Container(
        key: _groupKeys.putIfAbsent(group.date, GlobalKey.new),
        child: _GroupHeader(
          date: group.date,
          hasCollected: group.posts.any((PostCardData d) => d.post.origin == Origin.collected),
        ),
      ));
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
              leading: AppIcon('copy', size: 20, color: AppColors.of(context).textSecondary),
              title: const Text('复制标题'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: card.post.title ?? ''));
                Navigator.of(sheetContext).pop();
                showAppToast(context, '标题已复制到剪贴板');
              },
            ),
            if (card.books.isNotEmpty)
            ListTile(
              leading: AppIcon('star', size: 20, color: AppColors.of(context).textSecondary),
              title: Text('收藏《${BookNameChip.stripBrackets(card.books.first.name)}》'),
              onTap: () async {
                final BookChip chip = card.books.first;
                final NavigatorState navigator = Navigator.of(sheetContext);
                final BuildContext rootContext = context;
                if (chip.bookGroupId != null) {
                  await ref.read(queriesProvider).toggleFavorite(
                    targetType: FavoriteTarget.bookGroup,
                    targetId: chip.bookGroupId!,
                    title: '《${BookNameChip.stripBrackets(chip.name)}》',
                  );
                }
                navigator.pop();
                if (rootContext.mounted) {
                  showAppToast(rootContext, '已收藏');
                }
              },
            ),
            ListTile(
              // 查看原帖 = 进帖子详情（楼层流）；article → 设计稿 i-list（楼层/目录语义）。
              leading: AppIcon('list', size: 20, color: AppColors.of(context).textSecondary),
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

/// 首启种子导入进度面板（P0-1 精简接线版：阶段文案 + 线性进度 + 百分比）。
/// 完整首启导入页（原型 §5.1：Logo/免责勾选）为后续项，见路线图 Phase 5 遗留。
class _SeedImportProgress extends StatelessWidget {
  const _SeedImportProgress({required this.seedState});

  final SeedImportState seedState;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final bool determinate = seedState.progress > 0;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: s.space8, horizontal: s.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('首次启动 · 正在导入内置书库', style: t.bodyStrong.copyWith(color: c.text)),
              ),
              if (determinate)
                Text(
                  '${(seedState.progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                  style: AppTypography.tabular(t.label.copyWith(color: c.textMuted)),
                ),
            ],
          ),
          SizedBox(height: s.space3),
          LinearProgressIndicator(
            value: determinate ? seedState.progress : null,
            minHeight: 6,
            color: c.accent,
            backgroundColor: c.border,
          ),
          if (seedState.message.isNotEmpty) ...<Widget>[
            SizedBox(height: s.space3),
            Text(seedState.message, style: t.caption.copyWith(color: c.textMuted)),
          ],
          SizedBox(height: s.space1),
          Text(
            '导入完成即可离线浏览；全文索引将在后台继续构建，期间搜索自动降级并如实提示。',
            style: t.caption.copyWith(color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

/// 日期分组头（设计 01 `.day-head` index.html:1154 + CSS :517–520：
/// 衬线 600 15px「M月D日」+ hint「今天 · 自采」（label 字阶 accentStrong）+ 发丝延伸线；
/// 基线对齐；margin 上 space-6 下 space-3，左右 space-1）。
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.date, this.hasCollected = false});

  final String date;

  /// 组内含自采条目 → hint 追加「自采」（数据驱动，不造假）。
  final bool hasCollected;

  /// 'YYYY-MM-DD' → 'M月D日'（设计 .day-head .d 格式）；非法/空日期原样回退。
  static String formatDateLabel(String date) {
    if (date.isEmpty) {
      return '未知日期';
    }
    final List<String> parts = date.split('-');
    if (parts.length != 3) {
      return date;
    }
    final int? month = int.tryParse(parts[1]);
    final int? day = int.tryParse(parts[2]);
    if (month == null || day == null || month < 1 || month > 12 || day < 1 || day > 31) {
      return date;
    }
    return '$month月$day日';
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final DateTime now = DateTime.now();
    final String today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final List<String> hints = <String>[
      if (date == today) '今天',
      if (hasCollected) '自采',
    ];
    return Padding(
      // 测试/无障碍锚点：一天一个组头（§5.2 日期分组流）。
      key: ValueKey<String>('timeline-group-$date'),
      padding: EdgeInsets.only(top: s.groupHeaderTop, bottom: s.groupHeaderBottom),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: s.space1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            // Dynamic Type：日期可收缩省略（textScaler 放大时让位给发丝线，1.0 缩放视觉不变）。
            Flexible(
              child: Text(
                formatDateLabel(date),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.tabular(
                  t.headline.copyWith(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: c.text),
                ),
              ),
            ),
            if (hints.isNotEmpty) ...<Widget>[
              SizedBox(width: s.space3),
              Text(hints.join(' · '), style: t.label.copyWith(color: c.accentStrong)),
            ],
            SizedBox(width: s.space3),
            Expanded(child: Container(height: AppMetrics.hairline, color: c.border)),
          ],
        ),
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
            AppIcon('search', size: 20, color: c.textMuted),
            SizedBox(width: AppSpacing.of(context).space2),
            // Dynamic Type：占位文案可收缩省略（1.0 缩放视觉不变）。
            Expanded(
              child: Text(
                '搜索书名/作者/关键词…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.body.copyWith(color: c.textMuted),
              ),
            ),
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
                // 自采新内容提示卡 = 设计稿 i-collect（notice-card，index.html:1150）。
                AppIcon('collect', size: 20, color: c.accentStrong),
                SizedBox(width: s.space2),
                Expanded(
                  child: Text(
                    '自采新内容 +$n 条',
                    style: AppTypography.tabular(t.secondary.copyWith(color: c.accentStrong, fontWeight: FontWeight.w600)),
                  ),
                ),
                Text('查看', style: t.bodyStrong.copyWith(color: c.accentStrong)),
                // 行尾引导 chev = .ic sm 16 档（图标档位 24/20/16/13，设计无此 18 值）。
                RotatedBox(quarterTurns: 3, child: AppIcon('chev', size: 16, color: c.accentStrong)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 功能宫格：热门榜 / 随机书荒 两入口（设计稿 01 entry-tile，index.html:1156–1159）。
/// 热门榜 = push /rank 独立页（M2-②），副标题为 rank-mini 预览（全时段 Top1 书名）。
class _FeatureGrid extends ConsumerWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSpacing s = AppSpacing.of(context);
    final RankRow? top = ref.watch(rankTileTopProvider).value;
    // 两卡等高（真机反馈问题A）：IntrinsicHeight + stretch 取两卡固有高最大值，
    // 副标题已单行截断，Dynamic Type 放大时也不会一卡高一卡矮。
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _GridEntry(
              iconName: 'flame',
              label: '热门榜',
              subtitle: top == null ? '推荐次数 Top' : '推荐次数 Top · ${top.name}',
              onTap: () => openCenterPage(context, const RankPage()),
            ),
          ),
          SizedBox(width: s.space3),
          Expanded(
            child: _GridEntry(
              iconName: 'shuffle',
              label: '随机书荒',
              onTap: () => _showRandomSheet(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}

/// 入口 tile（.entry-tile：min-h68 · r20 · 图标 20 accent-strong · b 14 / small label muted，
/// index.html:646–656）。
class _GridEntry extends StatelessWidget {
  const _GridEntry({required this.iconName, required this.label, this.subtitle, required this.onTap});

  final String iconName;
  final String label;
  final String? subtitle;
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
        // index.html:647 min-height:68px（组件级几何常量）。
        constraints: const BoxConstraints(minHeight: 68),
        padding: EdgeInsets.symmetric(horizontal: s.space5, vertical: s.space3),
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: AppRadius.lgBorder,
          border: Border.all(color: c.border, width: AppMetrics.hairline),
        ),
        child: Row(
          children: <Widget>[
            AppIcon(iconName, size: 20, color: c.accentStrong),
            SizedBox(width: s.space3),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // index.html:655 b = body-strong 14px。
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyStrong.copyWith(fontSize: 14, color: c.text)),
                  // small 单行截断（真机反馈问题A：书名换行会撑高本卡、与右卡不等高；
                  // 完整书名进 /rank 页可见，此处只做预览）。
                  if (subtitle != null)
                    Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.label.copyWith(color: c.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 随机书荒面板 key（固定高度断言用；面板高度不随内容/滑动变化）。
const ValueKey<String> kRandomBooksSheetKey = ValueKey<String>('random-books-sheet');

void _showRandomSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // 固定高度面板（用户口径：70% 高、不随滑动改变）：不要拖拽手柄、禁用拖动，
    // 点遮罩 / 系统返回仍可关闭；无手柄时面板总高 = SizedBox 高度（有手柄会再叠加 48dp）。
    showDragHandle: false,
    enableDrag: false,
    builder: (BuildContext sheetContext) {
      final MediaQueryData mq = MediaQuery.of(sheetContext);
      final double height =
          (mq.size.height - mq.viewPadding.top - mq.viewPadding.bottom) * AppMetrics.randomSheetHeightFactor;
      return SizedBox(
        key: kRandomBooksSheetKey,
        height: height,
        child: const _RandomBooksSheet(),
      );
    },
  );
}

/// 随机书荒面板（P1-3：换一批 = invalidate 重抽）。
class _RandomBooksSheet extends ConsumerWidget {
  const _RandomBooksSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSpacing s = AppSpacing.of(context);
    final AsyncValue<List<EntryRow>> async = ref.watch(randomBooksProvider);
    final List<EntryRow> books = async.value ?? const <EntryRow>[];
    return ListView(
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
          const AppEmptyState(title: '书库为空', message: '导入种子数据包后即可随机抽书', svgIcon: 'book'),
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

