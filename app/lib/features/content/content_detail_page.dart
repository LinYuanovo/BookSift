import 'package:cached_network_image/cached_network_image.dart';
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
import '../home/cards.dart';
import 'detail_slot.dart';
import 'rich_text.dart';

/// 帖子详情（§5.6 富文本阅读，完整继承扫书 §2.4 管线）。
///
/// expanded 双栏时由 _DetailSlot 以 [embedded] 形态接入右槽（设计系统 §9.3 W4）；
/// compact/medium 走 /post/:id push（app_router SharedAxis horizontal）。
final postDetailProvider = FutureProvider.autoDispose.family<PostDetailData?, int>(
  (Ref ref, int postId) => ref.watch(queriesProvider).postDetail(postId),
);

class ContentDetailPage extends ConsumerStatefulWidget {
  const ContentDetailPage({super.key, required this.selection, this.embedded = false});

  final PostSelection selection;
  final bool embedded;

  @override
  ConsumerState<ContentDetailPage> createState() => _ContentDetailPageState();
}

class _ContentDetailPageState extends ConsumerState<ContentDetailPage> {
  late int _index = widget.selection.initialIndex;
  late PageController _pageController = PageController(initialPage: _index);

  @override
  void didUpdateWidget(ContentDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // expanded 右槽切换选中帖：重建 pager 到新帖。
    if (widget.selection.postId != oldWidget.selection.postId) {
      _index = widget.selection.initialIndex;
      _pageController.dispose();
      _pageController = PageController(initialPage: _index);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<int> ids = widget.selection.ids;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        leading: widget.embedded
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: '关闭详情槽',
                onPressed: () => ref.read(detailSelectionProvider.notifier).state = null,
              )
            : null,
        title: Text(ids.length > 1 ? '帖子详情 ${_index + 1}/${ids.length}' : '帖子详情'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: ids.length,
        onPageChanged: (int i) => setState(() => _index = i),
        itemBuilder: (BuildContext context, int i) => _PostBody(
          key: ValueKey<int>(ids[i]),
          postId: ids[i],
          // 书签快照要记「结果列表位置」（§5.6）：以进入时的 position 为基准，按 pager 偏移换算。
          // siblings 即结果 id 序列时 position == initialIndex，结果就是 i；
          // 单帖进入（无 siblings）则原样保留调用方给的 position。
          position: widget.selection.position + (i - widget.selection.initialIndex),
          snapshot: widget.selection.snapshot,
          highlight: widget.selection.highlight,
        ),
      ),
    );
  }
}

/// 单帖正文（头部元信息 + 楼层流 + 底部操作条）。
class _PostBody extends ConsumerStatefulWidget {
  const _PostBody({
    super.key,
    required this.postId,
    required this.position,
    this.snapshot,
    this.highlight,
  });

  final int postId;
  final int position;
  final SearchFilter? snapshot;
  final String? highlight;

  @override
  ConsumerState<_PostBody> createState() => _PostBodyState();
}

class _PostBodyState extends ConsumerState<_PostBody> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _floorKeys = <int, GlobalKey>{};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<String> get _highlightWords => tokenizeQuery(widget.highlight ?? '');

  GlobalKey _keyFor(int seq) => _floorKeys.putIfAbsent(seq, GlobalKey.new);

  Future<void> _toggleBookmark(PostDetailData data) async {
    final bool added = await ref.read(queriesProvider).togglePostBookmark(
      postRef: widget.postId,
      title: data.post.title?.isNotEmpty == true ? data.post.title! : '帖子 #${widget.postId}',
      author: data.post.author,
      channel: data.post.channel,
      position: widget.position,
      snapshot: widget.snapshot,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(added ? '已加入书签（含搜索条件快照）' : '已移除书签')));
  }

  Future<void> _toggleFavorite(PostDetailData data) async {
    final bool added = await ref.read(queriesProvider).toggleFavorite(
      targetType: FavoriteTarget.post,
      targetId: widget.postId,
      title: data.post.title?.isNotEmpty == true ? data.post.title! : '帖子 #${widget.postId}',
      subtitle: '${data.post.channel}${data.post.date == null ? '' : ' · ${data.post.date}'}',
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(added ? '已收藏' : '已取消收藏')));
  }

  Future<void> _copyAll(PostDetailData data) async {
    final StringBuffer sb = StringBuffer();
    if ((data.post.title ?? '').isNotEmpty) {
      sb.writeln(data.post.title);
    }
    for (final FloorData f in data.floors) {
      sb.writeln('${f.floor.seq}楼');
      sb.writeln(f.floor.content);
    }
    await Clipboard.setData(ClipboardData(text: sb.toString()));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('全文已复制到剪贴板')));
  }

  void _showToc(PostDetailData data) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (int i = 0; i < data.floors.length; i++)
              ListTile(
                dense: true,
                leading: Text('${data.floors[i].floor.seq}楼', style: AppTypography.of(context).caption),
                title: Text(
                  data.floors[i].floor.content.replaceAll('\n', ' '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.of(context).secondary,
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _scrollToFloor(data.floors[i].floor.seq, i, data.floors.length);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 目录跳转：楼层已构建 → ensureVisible；未构建 → 比例估算落点后二次定位。
  void _scrollToFloor(int seq, int index, int floorCount) {
    final BuildContext? target = _floorKeys[seq]?.currentContext;
    final AppMotionTheme motion = AppMotionTheme.of(context);
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: motion.transition.duration,
        curve: motion.transition.curve,
        alignment: 0.05,
      );
      return;
    }
    if (!_scrollController.hasClients) {
      return;
    }
    final double max = _scrollController.position.maxScrollExtent;
    _scrollController
        .animateTo(
      (max * ((index + 1) / (floorCount + 2))).clamp(0.0, max),
      duration: motion.transition.duration,
      curve: motion.transition.curve,
    )
        .then((_) {
      final BuildContext? target = _floorKeys[seq]?.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(target, alignment: 0.05);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<PostDetailData?> async = ref.watch(postDetailProvider(widget.postId));
    final PostDetailData? data = async.value;
    return Column(
      children: <Widget>[
        Expanded(child: _body(async)),
        if (data != null) _actionBar(data),
      ],
    );
  }

  Widget _body(AsyncValue<PostDetailData?> async) {
    final PostDetailData? data = async.value;
    if (data != null) {
      return _content(data);
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
          onPressed: () => ref.invalidate(postDetailProvider(widget.postId)),
        ),
      );
    }
    return const AppEmptyState(title: '原帖内容已不可用', message: '帖子不存在或已被删除');
  }

  Widget _content(PostDetailData data) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final Post post = data.post;
    final SemanticTone tone = toneOf(flag: post.recommendFlag, category: post.postKind);
    final String? tidUrl = post.tid == null ? null : 'https://tieba.baidu.com/p/${post.tid}';
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(postDetailProvider(widget.postId)),
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(s.pagePadding, s.space4, s.pagePadding, s.space8),
        children: <Widget>[
          // 头部：衬线标题 + 元信息 + 类型徽标 + 推荐/排雷计数对比（设计系统 §3 #03）。
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SemanticBadge(tone: tone, animate: false),
              SizedBox(width: s.space2),
              Expanded(
                child: Text(
                  (post.title ?? '').isNotEmpty ? post.title! : '无题',
                  style: t.title.copyWith(color: c.text),
                ),
              ),
            ],
          ),
          SizedBox(height: s.space3),
          Wrap(
            spacing: s.space2,
            runSpacing: s.space1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if ((post.author ?? '').isNotEmpty)
                Text(post.author!, style: t.caption.copyWith(color: c.textMuted)),
              MetaChip(label: post.channel),
              if ((post.subChannel ?? '').isNotEmpty) MetaChip(label: post.subChannel!),
              OriginBadge(origin: post.origin),
              Text(post.date ?? '', style: AppTypography.tabular(t.caption.copyWith(color: c.textMuted))),
              Text('${data.floors.length}楼', style: t.caption.copyWith(color: c.textMuted)),
              if (tidUrl != null)
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: tidUrl));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('原帖链接已复制到剪贴板')));
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('原帖', style: t.caption.copyWith(color: c.info)),
                      Icon(Icons.north_east_rounded, size: 13, color: c.info),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: s.space3),
          CountDuo(recommend: data.recommendCount, avoid: data.avoidCount),
          if (post.postKind == CategoryKind.avoid) ...<Widget>[
            SizedBox(height: s.space3),
            // 排雷帖风险提示（§5.6：进入排雷帖先提示风险）。
            Container(
              padding: EdgeInsets.symmetric(horizontal: s.space3, vertical: s.space2),
              decoration: BoxDecoration(color: c.dangerSoft, borderRadius: AppRadius.mdBorder),
              child: Row(
                children: <Widget>[
                  Icon(Icons.warning_amber_rounded, size: 16, color: c.danger),
                  SizedBox(width: s.space2),
                  Expanded(
                    child: Text('排雷帖：内容为负评/避雷向，请注意甄别', style: t.caption.copyWith(color: c.danger)),
                  ),
                ],
              ),
            ),
          ],
          Divider(height: s.space6),
          if (data.floors.isEmpty)
            const AppEmptyState(title: '原帖内容已不可用', message: '楼层已全部被删'),
          for (final FloorData f in data.floors) ...<Widget>[
            FloorHeader(seq: f.floor.seq),
            Padding(
              key: _keyFor(f.floor.seq),
              padding: EdgeInsets.only(left: s.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  FloorRichText(
                    text: f.floor.content,
                    highlightWords: _highlightWords,
                    onBookTap: (String name) => context.go('/search?q=${Uri.encodeComponent(name)}'),
                  ),
                  if (f.images.isNotEmpty) ...<Widget>[
                    SizedBox(height: s.space2),
                    FloorImages(images: f.images),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _skeleton() {
    final AppSpacing s = AppSpacing.of(context);
    return ListView(
      padding: EdgeInsets.all(s.pagePadding),
      children: <Widget>[
        for (int i = 0; i < 4; i++)
          Padding(
            padding: EdgeInsets.only(bottom: s.space4),
            child: SkeletonBlock(height: i == 0 ? 32 : 72),
          ),
      ],
    );
  }

  /// 底部操作条：书签/收藏/复制/目录（触控 ≥44px，设计系统 §3 #03）。
  Widget _actionBar(PostDetailData data) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final List<Bookmark> bookmarks = ref.watch(bookmarksProvider).value ?? const <Bookmark>[];
    final List<Favorite> favorites = ref.watch(favoritesProvider).value ?? const <Favorite>[];
    final bool bookmarked = bookmarks.any((Bookmark b) => b.postRef == widget.postId);
    final bool favorited =
        favorites.any((Favorite f) => f.targetType == FavoriteTarget.post && f.targetId == widget.postId);
    Widget action(IconData icon, String label, VoidCallback onTap, {bool active = false}) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: AppMetrics.minTouchTarget + 12,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 20, color: active ? c.accentStrong : c.textSecondary),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: t.label.copyWith(letterSpacing: 0, color: active ? c.accentStrong : c.textMuted),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border, width: AppMetrics.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            action(
              bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              '书签',
              () => _toggleBookmark(data),
              active: bookmarked,
            ),
            action(
              favorited ? Icons.star_rounded : Icons.star_border_rounded,
              '收藏',
              () => _toggleFavorite(data),
              active: favorited,
            ),
            action(Icons.content_copy_rounded, '复制', () => _copyAll(data)),
            action(Icons.toc_rounded, '目录', () => _showToc(data)),
          ],
        ),
      ),
    );
  }
}

/// 内联图片缩略（120dp · r14 · Referer 防盗链，§5.6/§9.4；点击进查看器）。
class FloorImages extends StatelessWidget {
  const FloorImages({super.key, required this.images});

  final List<FloorImage> images;

  /// 百度图床防盗链请求头（§9.4 三保险之二）。
  static const Map<String, String> refererHeaders = <String, String>{'Referer': 'https://imgsrc.baidu.com'};

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    return Wrap(
      spacing: AppSpacing.of(context).space2,
      runSpacing: AppSpacing.of(context).space2,
      children: <Widget>[
        for (final FloorImage img in images)
          ClipRRect(
            borderRadius: AppRadius.mdBorder,
            child: GestureDetector(
              onTap: () => showImageViewer(context, img),
              child: CachedNetworkImage(
                imageUrl: img.urlPermanent ?? img.urlOriginal ?? '',
                httpHeaders: refererHeaders,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                placeholder: (BuildContext context, String url) => Container(width: 120, height: 120, color: c.surfaceSunken),
                errorWidget: (BuildContext context, String url, Object error) => Container(
                  width: 120,
                  height: 120,
                  color: c.surfaceSunken,
                  child: Icon(Icons.broken_image_outlined, color: c.textMuted),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 图片查看器（§5.7 最小实现：全屏 + 双指缩放；保存到相册/翻页属 M2+）。
void showImageViewer(BuildContext context, FloorImage img) {
  final AppColors c = AppColors.of(context);
  showDialog<void>(
    context: context,
    builder: (BuildContext context) => Dialog(
      backgroundColor: c.canvas,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: <Widget>[
          InteractiveViewer(
            child: Center(
              child: CachedNetworkImage(
                imageUrl: img.urlPermanent ?? img.urlOriginal ?? '',
                httpHeaders: FloorImages.refererHeaders,
                errorWidget: (BuildContext context, String url, Object error) =>
                    const AppEmptyState(title: '图片已失效', icon: Icons.broken_image_outlined),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    ),
  );
}
