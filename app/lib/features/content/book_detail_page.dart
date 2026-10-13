import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_database.dart';
import '../../data/repo/queries.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../home/cards.dart';
import 'detail_slot.dart';

/// 书聚合详情页（本产品核心差异化页面，§5.5）：
/// 书名大标题 + 推荐/排雷计数对比（点击=筛选）+ 语义筛选 chips + 评价卡列表。

/// 头部与计数对比。
final bookDetailProvider = FutureProvider.autoDispose.family<BookDetailData?, int>(
  (Ref ref, int groupId) => ref.watch(queriesProvider).bookDetail(groupId),
);

/// 评价列表查询键（书 id × 语义筛选 × 排序）。
class BookEntryQuery {
  const BookEntryQuery(this.groupId, this.filter, this.sort);

  final int groupId;
  final SemanticFilter filter;
  final EntrySort sort;

  @override
  bool operator ==(Object other) =>
      other is BookEntryQuery && other.groupId == groupId && other.filter == filter && other.sort == sort;

  @override
  int get hashCode => Object.hash(groupId, filter, sort);
}

final bookEntriesProvider = FutureProvider.autoDispose.family<List<EntryRow>, BookEntryQuery>(
  (Ref ref, BookEntryQuery q) => ref.watch(queriesProvider).bookEntries(q.groupId, q.filter, sort: q.sort),
);

class BookDetailPage extends ConsumerStatefulWidget {
  const BookDetailPage({super.key, required this.bookGroupId, this.args});

  final int bookGroupId;
  final BookNavArgs? args;

  @override
  ConsumerState<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends ConsumerState<BookDetailPage> {
  late SemanticFilter _filter = widget.args?.initialFilter ?? SemanticFilter.all;
  EntrySort _sort = EntrySort.qualityDesc;

  Future<void> _toggleFavorite(BookDetailData data) async {
    final String title = data.group.nameDisplay ?? data.group.nameNorm;
    final bool added = await ref.read(queriesProvider).toggleFavorite(
      targetType: FavoriteTarget.bookGroup,
      targetId: widget.bookGroupId,
      title: '《$title》',
      subtitle: data.group.authorDisplay,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(added ? '已收藏该书' : '已取消收藏')));
  }

  void _openEntrySource(EntryRow e) {
    if (e.postRef != null) {
      openPostDetail(
        context,
        ref,
        PostSelection(
          postId: e.postRef!,
          snapshot: widget.args?.snapshot,
          highlight: widget.args?.highlight,
        ),
      );
      return;
    }
    final String? url = e.srcUrl;
    if (url != null && url.isNotEmpty) {
      // 无帖溯源 → 复制外链（url_launcher 属 M2 平台层，M1 以复制兜底，§5.5）。
      Clipboard.setData(ClipboardData(text: url));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('原帖链接已复制到剪贴板')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('原帖已不可溯源')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<BookDetailData?> async = ref.watch(bookDetailProvider(widget.bookGroupId));
    final List<EntryRow> entries =
        ref.watch(bookEntriesProvider(BookEntryQuery(widget.bookGroupId, _filter, _sort))).value ?? const <EntryRow>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('书聚合'),
        actions: <Widget>[
          if (async.value != null)
            Consumer(
              builder: (BuildContext context, WidgetRef ref, Widget? child) {
                final List<Favorite> favorites = ref.watch(favoritesProvider).value ?? const <Favorite>[];
                final bool fav = favorites.any(
                    (Favorite f) => f.targetType == FavoriteTarget.bookGroup && f.targetId == widget.bookGroupId);
                return IconButton(
                  icon: Icon(fav ? Icons.star_rounded : Icons.star_border_rounded),
                  color: fav ? AppColors.of(context).accentStrong : null,
                  tooltip: '收藏',
                  onPressed: () => _toggleFavorite(async.value!),
                );
              },
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'copy', child: Text('复制书名')),
              PopupMenuItem<String>(value: 'author', child: Text('搜索作者')),
            ],
            onSelected: (String v) {
              final BookDetailData? data = async.value;
              if (data == null) {
                return;
              }
              if (v == 'copy') {
                Clipboard.setData(ClipboardData(text: data.group.nameDisplay ?? data.group.nameNorm));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('书名已复制到剪贴板')));
              } else if ((data.group.authorDisplay ?? '').isNotEmpty) {
                context.go('/search?q=${Uri.encodeComponent(data.group.authorDisplay!)}');
              }
            },
          ),
        ],
      ),
      body: _body(async, entries),
    );
  }

  Widget _body(AsyncValue<BookDetailData?> async, List<EntryRow> entries) {
    final BookDetailData? data = async.value;
    if (data != null) {
      return _content(data, entries);
    }
    if (async.isLoading) {
      return _skeleton();
    }
    if (async.hasError) {
      return AppEmptyState(
        title: '加载失败',
        message: '数据库读取异常',
        icon: Icons.error_outline_rounded,
        action: AppButton(
          label: '重试',
          kind: AppButtonKind.outline,
          onPressed: () => ref.invalidate(bookDetailProvider(widget.bookGroupId)),
        ),
      );
    }
    return const AppEmptyState(title: '书目不存在', message: '聚合组已被移除');
  }

  Widget _content(BookDetailData data, List<EntryRow> entries) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final AppMotionTheme motion = AppMotionTheme.of(context);
    final BookGroup g = data.group;
    final String name = g.nameDisplay ?? g.nameNorm;
    List<String> channels = const <String>[];
    if ((g.channels ?? '').isNotEmpty) {
      try {
        channels = (jsonDecode(g.channels!) as List<dynamic>).whereType<String>().toList();
      } on FormatException {
        channels = g.channels!.split(',').where((String e) => e.isNotEmpty).toList();
      }
    }
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(bookDetailProvider(widget.bookGroupId));
        ref.invalidate(bookEntriesProvider(BookEntryQuery(widget.bookGroupId, _filter, _sort)));
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(s.pagePadding, s.space4, s.pagePadding, s.space8),
        children: <Widget>[
          // 书名大标题（衬线 display，设计系统 §3 #04）。
          Text('《$name》', style: t.display.copyWith(color: c.text)),
          SizedBox(height: s.space2),
          Text(
            <String>[
              if ((g.authorDisplay ?? '').isNotEmpty) g.authorDisplay!,
              '${g.entryTotal} 条独立推荐',
            ].join(' · '),
            style: AppTypography.tabular(t.secondary.copyWith(color: c.textSecondary)),
          ),
          if (channels.isNotEmpty) ...<Widget>[
            SizedBox(height: s.space2),
            Text('渠道: ${channels.join(' / ')}', style: t.caption.copyWith(color: c.textMuted)),
          ],
          if (g.dateMin != null && g.dateMax != null) ...<Widget>[
            SizedBox(height: s.space1),
            Text(
              '时间跨度: ${g.dateMin} ~ ${g.dateMax}',
              style: AppTypography.tabular(t.caption.copyWith(color: c.textMuted)),
            ),
          ],
          SizedBox(height: s.space4),
          // 计数对比：点击=按该语义筛选（§5.5，P0-13）。
          CountDuo(
            recommend: data.recommendCount,
            avoid: data.avoidCount,
            onRecommendTap: () => setState(() => _filter = SemanticFilter.recommend),
            onAvoidTap: () => setState(() => _filter = SemanticFilter.avoid),
          ),
          SizedBox(height: s.space4),
          Row(
            children: <Widget>[
              SegmentedPill<SemanticFilter>(
                options: const <(SemanticFilter, String)>[
                  (SemanticFilter.all, '全部'),
                  (SemanticFilter.recommend, '仅推荐'),
                  (SemanticFilter.avoid, '仅排雷'),
                ],
                selected: _filter,
                onChanged: (SemanticFilter v) => setState(() => _filter = v),
              ),
              const Spacer(),
              PopupMenuButton<EntrySort>(
                tooltip: '排序',
                onSelected: (EntrySort v) => setState(() => _sort = v),
                itemBuilder: (BuildContext context) => const <PopupMenuEntry<EntrySort>>[
                  PopupMenuItem<EntrySort>(value: EntrySort.qualityDesc, child: Text('质量 ↓')),
                  PopupMenuItem<EntrySort>(value: EntrySort.timeDesc, child: Text('时间 ↓')),
                  PopupMenuItem<EntrySort>(value: EntrySort.timeAsc, child: Text('时间 ↑')),
                  PopupMenuItem<EntrySort>(value: EntrySort.wordDesc, child: Text('字数 ↓')),
                ],
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: s.space2, vertical: s.space1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(switch (_sort) {
                        EntrySort.qualityDesc => '质量↓',
                        EntrySort.timeDesc => '时间↓',
                        EntrySort.timeAsc => '时间↑',
                        EntrySort.wordDesc => '字数↓',
                      }, style: t.caption.copyWith(color: c.textSecondary)),
                      Icon(Icons.expand_more_rounded, size: 16, color: c.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SectionTitle(label: '全部评价 ${entries.length}'),
          if (entries.isEmpty)
            AppEmptyState(
              title: '该筛选下暂无条目',
              message: '机器分类，可能有误差（§8.9 诚实口径）',
              action: AppButton(
                label: '看全部',
                kind: AppButtonKind.outline,
                onPressed: () => setState(() => _filter = SemanticFilter.all),
              ),
            ),
          // 语义筛选切换 → 原位 crossfade（motion.switch，§6.2）。
          AnimatedSwitcher(
            duration: motion.switch_.duration,
            switchInCurve: motion.switch_.curve,
            switchOutCurve: motion.exit.curve,
            child: StaggerPanel(
              key: ValueKey<_SemanticSortKey>(_SemanticSortKey(_filter, _sort)),
              spacing: s.cardGap,
              children: <Widget>[
                for (final EntryRow e in entries)
                  BookEntryCard(
                    key: ValueKey<int>(e.id),
                    entry: e,
                    showRecommender: true,
                    expandableComment: true,
                    onBookTap: (String n) => context.go('/search?q=${Uri.encodeComponent(n)}'),
                    onRecommenderTap: (String r) => context.go('/search?q=${Uri.encodeComponent(r)}'),
                    onSourceTap: () => _openEntrySource(e),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeleton() {
    final AppSpacing s = AppSpacing.of(context);
    return ListView(
      padding: EdgeInsets.all(s.pagePadding),
      children: <Widget>[
        const SkeletonBlock(height: 40),
        SizedBox(height: s.space4),
        for (int i = 0; i < 3; i++)
          Padding(
            padding: EdgeInsets.only(bottom: s.space4),
            child: SkeletonBlock(height: 96),
          ),
      ],
    );
  }
}

/// AnimatedSwitcher/StaggerPanel 重放键（筛选×排序组合）。
class _SemanticSortKey {
  const _SemanticSortKey(this.filter, this.sort);

  final SemanticFilter filter;
  final EntrySort sort;

  @override
  bool operator ==(Object other) => other is _SemanticSortKey && other.filter == filter && other.sort == sort;

  @override
  int get hashCode => Object.hash(filter, sort);
}
