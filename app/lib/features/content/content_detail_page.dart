import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../collector/collect_providers.dart';
import '../../collector/post_refresh.dart';
import '../../core/external_launch.dart';
import '../../core/icons.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/scroll_chrome.dart';
import '../../data/db/app_database.dart';
import '../../data/repo/database_provider.dart';
import '../../data/repo/queries.dart';
import '../../data/repo/queries_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../home/cards.dart';
import '../share/share_card.dart';
import '../share/share_sheet.dart';
import 'detail_slot.dart';
import 'rich_text.dart';

/// 帖子详情（§5.6 富文本阅读，完整继承扫书 §2.4 管线）。
///
/// expanded 双栏时由 _DetailSlot 以 [embedded] 形态接入右槽（设计系统 §9.3 W4）；
/// compact/medium 走 /post/:id push（app_router SharedAxis horizontal）。
final postDetailProvider = FutureProvider.autoDispose
    .family<PostDetailData?, int>(
      (Ref ref, int postId) => ref.watch(queriesProvider).postDetail(postId),
    );

/// 图片签名刷新防重（任务 2）：会话级「每帖至多一次」，ProviderScope 生命周期内有效。
final postImageRefreshGuardProvider = Provider<Set<int>>((Ref ref) => <int>{});

/// 页内搜索命中（任务 4）：所在楼层 id + 该楼层内出现序（0 起）。
typedef _SearchHit = ({int floorId, int indexInFloor});

/// [word] 在 [data] 全部楼层正文的命中集（按楼层序、楼层内出现序展平）。
/// 口径 = rich_text.countSearchHits（只数纯文本段，书名/URL span 不参与），
/// 保证搜索条「当前/总数」与楼层流里可见高亮一一对应、索引两端一致。
List<_SearchHit> _searchHitsOf(PostDetailData? data, String word) {
  if (data == null || word.isEmpty) {
    return const <_SearchHit>[];
  }
  final List<_SearchHit> hits = <_SearchHit>[];
  for (final FloorData f in data.floors) {
    final int n = countSearchHits(f.floor.content, word);
    for (int i = 0; i < n; i++) {
      hits.add((floorId: f.floor.id, indexInFloor: i));
    }
  }
  return hits;
}

class ContentDetailPage extends ConsumerStatefulWidget {
  const ContentDetailPage({
    super.key,
    required this.selection,
    this.embedded = false,
  });

  final PostSelection selection;
  final bool embedded;

  @override
  ConsumerState<ContentDetailPage> createState() => _ContentDetailPageState();
}

class _ContentDetailPageState extends ConsumerState<ContentDetailPage> {
  late int _index = widget.selection.initialIndex;
  late PageController _pageController = PageController(initialPage: _index);

  /// P1-6 自由复制选择模式（页面级：AppBar 开关与楼层长按两个入口共用；
  /// embedded 右槽与独立路由两形态同走本 State，行为一致）。
  bool _selectMode = false;

  /// 任务 4 页内搜索：⋮「页内搜索」在 AppBar 下方展开搜索条（VSCode 风格）。
  /// 搜索词 = controller 当前值（输入即搜）；命中集按当前帖现算（[_searchHitsOf]），
  /// [_searchCurrent] 为环形游标（上/下一个循环，翻页/换词后归零）。
  final TextEditingController _searchController = TextEditingController();
  bool _searchOpen = false;
  int _searchCurrent = 0;

  @override
  void didUpdateWidget(ContentDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // expanded 右槽切换选中帖：重建 pager 到新帖。
    if (widget.selection.postId != oldWidget.selection.postId) {
      _index = widget.selection.initialIndex;
      _searchCurrent = 0; // 命中游标属于「当前帖」，换帖归零。
      _pageController.dispose();
      _pageController = PageController(initialPage: _index);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// P1-6 选择模式统一进出（任务 3，真机：仅图标态切换无感知）：AppBar 开关与
  /// 楼层长按两入口同走这里，进出各给一条 toast 说明（需求 6：不再常驻提示条）。
  /// showAppToast 同一时刻只保留一条，连点不会排队多条提示、也不残留待决 timer。
  void _setSelectMode(bool on) {
    if (_selectMode == on) {
      return;
    }
    setState(() => _selectMode = on);
    showAppToast(context, on ? '自由复制：长按楼层正文选择文字' : '已退出自由复制');
  }

  /// 上/下一个命中（环形循环，任务 4）；0 命中时按钮已置灰，count 兜底防模零。
  void _stepSearch(int delta, int count) {
    if (count <= 0) {
      return;
    }
    setState(() => _searchCurrent = (_searchCurrent + delta) % count);
  }

  /// 关闭搜索条（任务 4）：收起 + 清空输入；高亮随 searchWord 传空而消失。
  void _closeSearch() {
    setState(() {
      _searchOpen = false;
      _searchCurrent = 0;
      _searchController.clear();
    });
  }

  /// ⋮「分享扫书」（原型 §5.11）：带当前帖标题 + 全部楼层正文进文字转图弹层。
  /// 帖子无书名语义 → 走 title 行（不套《》），推荐人 = 发帖人。
  void _sharePost(PostDetailData data) {
    final Post post = data.post;
    final String quote = data.floors
        .map((FloorData f) => f.floor.content.trim())
        .where((String s) => s.isNotEmpty)
        .join('\n\n')
        .trim();
    showShareSheet(
      context,
      ShareCardSpec(
        title: (post.title ?? '').trim().isEmpty ? null : post.title!.trim(),
        author: post.author,
        recommender: post.author,
        quote: quote.isEmpty ? '（原帖楼层已不可用）' : quote,
      ),
    );
  }

  /// 任务 4：页内搜索条（AppBar 下方，VSCode 风格：输入即搜 + 当前/总数计数 +
  /// 上/下循环 + 清除 + 关闭；图标全走 AppIcon）。
  ///
  /// 窄槽防线（expanded 右槽 ≈304dp 起步）：输入段用 Expanded 吸收全部剩余宽，
  /// 固定段（前导图标 + 计数 + 四枚 compact 按钮）总宽 ≈250dp < 槽宽，Row 不溢出。
  Widget _searchBar({required List<_SearchHit> hits, required int currentHit}) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final bool none = hits.isEmpty;

    Widget button({
      required String symbol,
      required String tooltip,
      required VoidCallback? onPressed,
      int quarterTurns = 0,
      double size = 16,
    }) {
      return IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        // AppIcon 显式染色不走 IconTheme 的禁用态淡化，禁用时手动落 textMuted。
        icon: RotatedBox(
          quarterTurns: quarterTurns,
          child: AppIcon(
            symbol,
            size: size,
            color: onPressed == null ? c.textMuted : c.textSecondary,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          bottom: BorderSide(color: c.border, width: AppMetrics.hairline),
        ),
      ),
      padding: EdgeInsets.fromLTRB(s.space3, s.space1, s.space2, s.space1),
      child: Row(
        children: <Widget>[
          AppIcon('search', size: 16, color: c.textMuted),
          SizedBox(width: s.space2),
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (String v) => setState(() => _searchCurrent = 0),
              // 软键盘「搜索」= 下一个命中（VSCode Enter 语义）。
              onSubmitted: (String v) {
                if (!none) {
                  _stepSearch(1, hits.length);
                }
              },
              style: t.secondary.copyWith(color: c.text),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '页内搜索',
                hintStyle: t.secondary.copyWith(color: c.textMuted),
              ),
            ),
          ),
          SizedBox(width: s.space1),
          // 计数：当前/总数；0 命中 = 「0/0」且上/下禁用（任务 4 口径）；
          // tabular 数字防翻页宽度跳动（§2.2）。
          Text(
            none ? '0/0' : '${currentHit + 1}/${hits.length}',
            style: AppTypography.tabular(t.caption.copyWith(color: c.textMuted)),
          ),
          SizedBox(width: s.space1),
          // chev 原生朝下：旋 1/3 圈得左/右箭头（scroll_chrome 跳顶/跳底同款手法）。
          button(
            symbol: 'chev',
            tooltip: '上一个命中',
            quarterTurns: 1,
            onPressed: none ? null : () => _stepSearch(-1, hits.length),
          ),
          button(
            symbol: 'chev',
            tooltip: '下一个命中',
            quarterTurns: 3,
            onPressed: none ? null : () => _stepSearch(1, hits.length),
          ),
          // 清除 = 清空输入、搜索条保留；无输入时置灰。
          button(
            symbol: 'close',
            tooltip: '清除搜索词',
            size: 16,
            onPressed: _searchController.text.isEmpty
                ? null
                : () {
                    _searchController.clear();
                    setState(() => _searchCurrent = 0);
                  },
          ),
          // 关闭 = 收起搜索条并清除高亮。
          button(
            symbol: 'close',
            tooltip: '关闭页内搜索',
            size: 20,
            onPressed: _closeSearch,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<int> ids = widget.selection.ids;
    // ⋮「分享扫书」要当前帖的标题/作者/正文；provider 与 _PostBody 共用同一 family 缓存。
    final PostDetailData? current = ids.isEmpty
        ? null
        : ref.watch(postDetailProvider(ids[_index])).value;
    // 任务 4：页内搜索命中集与当前焦点（只对正在浏览的帖生效；邻页只染琥珀不标焦点）。
    final String searchWord = _searchOpen ? _searchController.text : '';
    final List<_SearchHit> hits = _searchHitsOf(current, searchWord);
    final int currentHit = hits.isEmpty
        ? 0
        : _searchCurrent.clamp(0, hits.length - 1);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        leading: widget.embedded
            ? IconButton(
                icon: AppIcon(
                  'close',
                  size: 20,
                  color: AppColors.of(context).textSecondary,
                ),
                tooltip: '关闭详情槽',
                onPressed: () =>
                    ref.read(detailSelectionProvider.notifier).state = null,
              )
            : null,
        title: Text(
          ids.length > 1 ? '帖子详情 ${_index + 1}/${ids.length}' : '帖子详情',
        ),
        actions: <Widget>[
          if (current != null) ...<Widget>[
            // P1-6 自由复制切换（原型 §3.1）：进入选择模式后切 close 语义 + accent 激活色。
            IconButton(
              tooltip: _selectMode ? '退出自由复制' : '自由复制',
              icon: AppIcon(
                _selectMode ? 'close' : 'copy',
                size: 20,
                color: _selectMode
                    ? AppColors.of(context).accentStrong
                    : AppColors.of(context).textSecondary,
              ),
              // 任务 3：统一走 _setSelectMode（toast 用法说明/退出提示）。
              onPressed: () => _setSelectMode(!_selectMode),
            ),
            PopupMenuButton<String>(
              // r14 菜单形状裁切：条目墨渍/高亮默认直角，会外溢到菜单圆角之外。
              clipBehavior: Clip.antiAlias,
              tooltip: '更多',
              icon: AppIcon(
                'more',
                size: 20,
                color: AppColors.of(context).textSecondary,
              ),
              itemBuilder: (BuildContext context) =>
                  const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(value: 'share', child: Text('分享扫书')),
                    // 任务 4：页内搜索（VSCode 风格），AppBar 下方展开搜索条。
                    PopupMenuItem<String>(value: 'find', child: Text('页内搜索')),
                  ],
              onSelected: (String v) {
                if (v == 'share') {
                  _sharePost(current);
                } else if (v == 'find') {
                  setState(() {
                    _searchOpen = true;
                    _searchCurrent = 0;
                  });
                }
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: <Widget>[
          // 任务 4：搜索条紧贴 AppBar 下方展开（收起时零占位）。
          if (_searchOpen) _searchBar(hits: hits, currentHit: currentHit),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: ids.length,
              onPageChanged: (int i) => setState(() {
                _index = i;
                _searchCurrent = 0; // 命中游标属于「当前帖」，翻页归零。
              }),
              itemBuilder: (BuildContext context, int i) => _PostBody(
                key: ValueKey<int>(ids[i]),
                postId: ids[i],
                // 书签快照要记「结果列表位置」（§5.6）：以进入时的 position 为基准，按 pager 偏移换算。
                // siblings 即结果 id 序列时 position == initialIndex，结果就是 i；
                // 单帖进入（无 siblings）则原样保留调用方给的 position。
                position:
                    widget.selection.position +
                    (i - widget.selection.initialIndex),
                snapshot: widget.selection.snapshot,
                highlight: widget.selection.highlight,
                // 楼层定位锚点只属于书签指向的那帖（任务 1）：翻页到其他帖不生效。
                initialFloorSeq: ids[i] == widget.selection.postId
                    ? widget.selection.initialFloorSeq
                    : null,
                initialFloorId: ids[i] == widget.selection.postId
                    ? widget.selection.initialFloorId
                    : null,
                selectMode: _selectMode,
                onEnterSelectMode: () => _setSelectMode(true),
                // 任务 4：搜索词全页共享（横滑中邻页也见琥珀高亮），
                // 「当前命中」只属于正在浏览的帖。
                searchWord: searchWord,
                searchFocus: i == _index && hits.isNotEmpty
                    ? hits[currentHit]
                    : null,
              ),
            ),
          ),
        ],
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
    required this.selectMode,
    required this.onEnterSelectMode,
    this.snapshot,
    this.highlight,
    this.initialFloorSeq,
    this.initialFloorId,
    this.searchWord = '',
    this.searchFocus,
  });

  final int postId;
  final int position;
  final SearchFilter? snapshot;
  final String? highlight;

  /// 书签恢复的楼层定位锚点（任务 1；null = 从头阅读）。
  final int? initialFloorSeq;

  /// 楼层精确定位锚点（floors.id，唯一）：优先于 [initialFloorSeq]，多书帖同 seq 时靠它定位。
  final int? initialFloorId;

  /// P1-6 自由复制选择模式（页面级状态，见 _ContentDetailPageState._selectMode）。
  final bool selectMode;

  /// 长按楼层正文 → 请求进入选择模式（P1-6 主入口）。
  final VoidCallback onEnterSelectMode;

  /// 任务 4 页内搜索词（空 = 未激活；着色口径见 FloorRichText.searchWord）。
  final String searchWord;

  /// 任务 4 当前命中（null = 本帖无当前命中，全部楼层高亮一律普通琥珀）。
  final _SearchHit? searchFocus;

  @override
  ConsumerState<_PostBody> createState() => _PostBodyState();
}

class _PostBodyState extends ConsumerState<_PostBody> {
  final ScrollController _scrollController = ScrollController();

  /// 楼层锚点 key，按 floor.id（库内唯一）而非 seq 键控：
  /// 种子数据存在同帖多楼层 seq 相同的情况（大佬贴吧扫书每卡片一记 seq=1），
  /// 按 seq 键控会让多个楼层共用同一 GlobalKey，构建即抛「Multiple widgets used
  /// the same GlobalKey」，release 下表现为楼层正文整层不渲染。
  final Map<int, GlobalKey> _floorKeys = <int, GlobalKey>{};

  /// 楼层 ListView 的 key：_firstVisibleFloorSeq 取视口边界用。
  final GlobalKey _listKey = GlobalKey();

  /// 书签楼层定位只跳一次（任务 1；防 refresh invalidate 后重复跳）。
  bool _didInitialFloorJump = false;

  /// 楼层 ListView 的 cacheExtent（null = 框架默认 250）：定位未构建楼层时临时抬高
  /// 到 [_kFullBuildCacheExtent] 强制全量构建，落位动画结束后复原（见 _scrollToFloor）。
  double? _cacheExtent;

  /// 全量构建窗口：种子库单帖最多 299 楼（均值 4.3），一帧内建全可接受。
  static const double _kFullBuildCacheExtent = 1e5;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_PostBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 任务 4：页内搜索焦点换楼层 → 定位到所在楼层（复用目录跳转路径）。
    // 只在楼层切换时滚动：同楼层内命中循环不重滚（楼层已在视口，避免长楼层
    // 反复被拽回层顶）；record 按值比较，焦点未动（打字未换首命中楼层）不触发。
    final _SearchHit? focus = widget.searchFocus;
    if (focus != null && focus.floorId != oldWidget.searchFocus?.floorId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToFloor(focus.floorId);
        }
      });
    }
  }

  List<String> get _highlightWords => tokenizeQuery(widget.highlight ?? '');

  GlobalKey _keyFor(int floorId) => _floorKeys.putIfAbsent(floorId, GlobalKey.new);

  /// 数据就绪后的两件事：书签楼层定位（仅一次）+ 图片签名后台刷新（每帖一次）。
  void _onData(
    AsyncValue<PostDetailData?>? prev,
    AsyncValue<PostDetailData?> next,
  ) {
    // valueOrNull：错误态的 value 会重抛（riverpod 2.6 AsyncError 语义），静默跳过。
    final PostDetailData? data = next.valueOrNull;
    if (data == null) {
      return;
    }
    _scheduleInitialFloorJump(data);
    _maybeRefreshImages(data);
  }

  /// 书签/评价卡恢复定位（任务 1）：跳到 initialFloorId（floors.id，唯一）或
  /// initialFloorSeq 指定楼层；楼层不存在静默忽略（原帖删楼/采集截断），不提示不阻断。
  ///
  /// 优先按 [initialFloorId]（多书帖同 seq 下只有 id 能唯一定位到目标书所在楼）；
  /// 无 id 时才回落到 seq（旧书签只存了楼层号）。
  void _scheduleInitialFloorJump(PostDetailData data) {
    final int? floorId = widget.initialFloorId;
    final int? seq = widget.initialFloorSeq;
    if ((floorId == null && seq == null) || _didInitialFloorJump) {
      return;
    }
    _didInitialFloorJump = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (floorId != null) {
        final int index = data.floors.indexWhere(
          (FloorData f) => f.floor.id == floorId,
        );
        if (index >= 0) {
          _scrollToFloor(data.floors[index].floor.id);
          return;
        }
      }
      if (seq == null) {
        return;
      }
      final int index = data.floors.indexWhere(
        (FloorData f) => f.floor.seq == seq,
      );
      if (index < 0) {
        return;
      }
      _scrollToFloor(data.floors[index].floor.id);
    });
  }

  /// 打开含图帖 → 后台刷新图片签名链接（任务 2：百度图床签名过期修复）。
  ///
  /// 每会话每帖至多一次（[postImageRefreshGuardProvider] 防重）；成功且有变更则
  /// invalidate 重读展示；失败静默（网络/验证码/熔断均不打断阅读、不弹窗）。
  /// 属用户打开帖子的直接后果，与在线搜索「手动触发」同口径，不设额外闸门。
  void _maybeRefreshImages(PostDetailData data) {
    final int? tid = data.post.tid;
    if (tid == null || !data.floors.any((FloorData f) => f.images.isNotEmpty)) {
      return;
    }
    // 先过防重再读 provider：无图帖绝不触碰 appDatabaseProvider（widget 测试哨兵）。
    if (!ref.read(postImageRefreshGuardProvider).add(widget.postId)) {
      return;
    }
    final PostRefreshService service = PostRefreshService(
      db: ref.read(appDatabaseProvider),
      api: ref.read(tiebaApiProvider),
    );
    unawaited(
      Future<void>(() async {
        try {
          final PostRefreshResult r = await service.refreshPostImages(
            tid: tid,
            postId: widget.postId,
          );
          if (r.changed && mounted) {
            ref.invalidate(postDetailProvider(widget.postId));
          }
        } catch (_) {
          // 静默兜底：网络/验证码/熔断均不打断阅读、不弹窗。
        }
      }),
    );
  }

  /// 当前首个可见楼层的 seq（书签记录阅读位置，任务 1）：
  /// 遍历锚点 key（按 floor.id 键控），跳过未构建/无 RenderBox 的（屏外不在树），
  /// 取全局矩形与列表视口相交的第一个；返回的 seq 供书签展示与恢复（同 seq 重复时
  /// 恢复退化为首个匹配楼层——种子「大佬贴吧扫书」卡片段同 seq 的已知取舍）。
  int? _firstVisibleFloorSeq(PostDetailData data) {
    final RenderObject? listRender = _listKey.currentContext
        ?.findRenderObject();
    if (listRender is! RenderBox || !listRender.hasSize) {
      return null;
    }
    final double viewTop = listRender.localToGlobal(Offset.zero).dy;
    final double viewBottom = viewTop + listRender.size.height;
    final Map<int, int> seqById = <int, int>{
      for (final FloorData f in data.floors) f.floor.id: f.floor.seq,
    };
    final List<int> ids = _floorKeys.keys.toList()..sort();
    for (final int id in ids) {
      final BuildContext? ctx = _floorKeys[id]?.currentContext;
      if (ctx == null) {
        continue;
      }
      final RenderObject? ro = ctx.findRenderObject();
      if (ro is! RenderBox || !ro.hasSize) {
        continue;
      }
      final double top = ro.localToGlobal(Offset.zero).dy;
      if (top + ro.size.height > viewTop && top < viewBottom) {
        return seqById[id];
      }
    }
    return null;
  }

  Future<void> _toggleBookmark(PostDetailData data) async {
    final bool added = await ref
        .read(queriesProvider)
        .togglePostBookmark(
          postRef: widget.postId,
          title: data.post.title?.isNotEmpty == true
              ? data.post.title!
              : '帖子 #${widget.postId}',
          author: data.post.author,
          channel: data.post.channel,
          position: widget.position,
          snapshot: widget.snapshot,
          floorSeq: _firstVisibleFloorSeq(data),
        );
    if (!mounted) {
      return;
    }
    showAppToast(context, added ? '已加入书签（含楼层位置）' : '已移除书签');
  }

  Future<void> _toggleFavorite(PostDetailData data) async {
    final bool added = await ref
        .read(queriesProvider)
        .toggleFavorite(
          targetType: FavoriteTarget.post,
          targetId: widget.postId,
          title: data.post.title?.isNotEmpty == true
              ? data.post.title!
              : '帖子 #${widget.postId}',
          subtitle:
              '${data.post.channel}${data.post.date == null ? '' : ' · ${data.post.date}'}',
        );
    if (!mounted) {
      return;
    }
    showAppToast(context, added ? '已收藏' : '已取消收藏');
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
    showAppToast(context, '全文已复制到剪贴板');
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
                leading: Text(
                  '${data.floors[i].floor.seq}楼',
                  style: AppTypography.of(context).caption,
                ),
                title: Text(
                  data.floors[i].floor.content.replaceAll('\n', ' '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.of(context).secondary,
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _scrollToFloor(data.floors[i].floor.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 目录跳转 / 书签恢复定位（任务 2）：
  /// 目标已构建 → ensureVisible(alignment 0.05)；未构建（ListView 懒加载屏外）→
  /// 临时抬高 cacheExtent 强制全部楼层进树，帧后 ensureVisible，动画结束再复原。
  /// 不再用「maxScrollExtent × 楼层比例」估算落点：楼层高度差异大时估算会偏，
  /// 且二次 ensureVisible 因目标仍未构建而静默失败（真机目录跳最后一楼不准的根因）。
  /// [floorId] 为 floors.id（库内唯一；seq 在同帖卡片段下会重复，见 _floorKeys 注释）。
  void _scrollToFloor(int floorId) {
    final AppMotionTheme motion = AppMotionTheme.of(context);
    final BuildContext? built = _floorKeys[floorId]?.currentContext;
    if (built != null) {
      Scrollable.ensureVisible(
        built,
        duration: motion.transition.duration,
        curve: motion.transition.curve,
        alignment: 0.05,
      );
      return;
    }
    if (!_scrollController.hasClients) {
      return;
    }
    setState(() => _cacheExtent = _kFullBuildCacheExtent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final BuildContext? target = _floorKeys[floorId]?.currentContext;
      if (target == null) {
        setState(() => _cacheExtent = null);
        return;
      }
      Scrollable.ensureVisible(
        target,
        duration: motion.transition.duration,
        curve: motion.transition.curve,
        alignment: 0.05,
      ).whenComplete(() {
        // 动画走完才复原：期间全部楼层在树，maxScrollExtent 精确、落点不漂。
        if (!mounted) {
          return;
        }
        setState(() => _cacheExtent = null);
        // 真机帧时序下复原后落点可能漂移：下一帧再补一次对齐定位（已对齐时空操作）。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          final BuildContext? settle = _floorKeys[floorId]?.currentContext;
          if (settle == null || !settle.mounted) {
            return;
          }
          Scrollable.ensureVisible(
            settle,
            duration: motion.transition.duration,
            curve: motion.transition.curve,
            alignment: 0.05,
          );
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // 数据就绪回调：书签楼层定位（任务 1，仅一次）+ 图片签名刷新（任务 2，每帖一次）。
    ref.listen(postDetailProvider(widget.postId), _onData);
    final AsyncValue<PostDetailData?> async = ref.watch(
      postDetailProvider(widget.postId),
    );
    // valueOrNull：错误态的 value 会重抛，这里要落到下方「加载失败」错误态分支。
    final PostDetailData? data = async.valueOrNull;
    // 缓存命中补跳（关键）：从帖子详情点书名进书聚合、再从聚合页点回同一帖时，
    // postDetailProvider 因原帖页仍在导航栈上而**缓存命中**——此时 ref.listen 不触发
    // （值没有变化），_onData 永不执行 → 楼层定位静默失效。这里在 build 期数据已就绪时
    // 直接补一次定位（_scheduleInitialFloorJump 内部有 _didInitialFloorJump 去重，幂等）。
    // 缓存命中补跳（关键）：从帖子详情点书名进书聚合、再从聚合页点回同一帖时，
    // postDetailProvider 因原帖页仍在导航栈上而**缓存命中**——此时 ref.listen 不触发
    // （值没有变化），_onData 永不执行 → 楼层定位静默失效。这里在 build 期数据已就绪时
    // 直接补一次定位（_scheduleInitialFloorJump 内部有 _didInitialFloorJump 去重，幂等）。
    if (data != null) {
      _scheduleInitialFloorJump(data);
    }
    return Column(
      children: <Widget>[
        Expanded(child: _body(async)),
        if (data != null) _actionBar(data),
      ],
    );
  }

  Widget _body(AsyncValue<PostDetailData?> async) {
    final PostDetailData? data = async.valueOrNull;
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
        svgIcon: 'alert',
        action: AppButton(
          label: '重试',
          kind: AppButtonKind.outline,
          onPressed: () => ref.invalidate(postDetailProvider(widget.postId)),
        ),
      );
    }
    return const AppEmptyState(
      title: '原帖内容已不可用',
      message: '帖子不存在或已被删除',
      svgIcon: 'book',
    );
  }

  Widget _content(PostDetailData data) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final Post post = data.post;
    final SemanticTone tone = postToneOf(postKind: post.postKind, title: post.title);
    final String? tidUrl = post.tid == null
        ? null
        : 'https://tieba.baidu.com/p/${post.tid}';
    // 楼层正文可否直接选中：手动选择模式（触屏）∪ 桌面默认档（需求 3）。
    final bool selectable = widget.selectMode || _desktopFreeSelect;
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(postDetailProvider(widget.postId)),
      // 任务 4：楼层流接 ScrollChrome（常驻细滚动条 + 滚动中浮出跳顶/跳底）。
      child: ScrollChrome(
        controller: _scrollController,
        child: ListView(
          key: _listKey,
          controller: _scrollController,
          // 定位未构建楼层时临时抬高（_scrollToFloor），落位后复原为框架默认。
          cacheExtent: _cacheExtent,
          padding: EdgeInsets.fromLTRB(
            s.pagePadding,
            s.space4,
            s.pagePadding,
            s.space8,
          ),
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
                  // 作者名可点击 → 以其为关键词搜索（与书聚合/评价卡「点推荐人搜索」同语义）；
                  // 选择模式下暂停（与书名/URL 手势暂停同口径，避免选词时误触）。
                  GestureDetector(
                    onTap: widget.selectMode
                        ? null
                        : () => context.go(
                            '/search?q=${Uri.encodeComponent(post.author!)}',
                          ),
                    child: Text(
                      post.author!,
                      style: t.caption.copyWith(color: c.accentStrong),
                    ),
                  ),
                MetaChip(label: post.channel),
                if ((post.subChannel ?? '').isNotEmpty)
                  MetaChip(label: post.subChannel!),
                OriginBadge(origin: post.origin),
                Text(
                  post.date ?? '',
                  style: AppTypography.tabular(
                    t.caption.copyWith(color: c.textMuted),
                  ),
                ),
                Text(
                  '${data.floors.length}楼',
                  style: t.caption.copyWith(color: c.textMuted),
                ),
                if (tidUrl != null)
                  GestureDetector(
                    // P1-6：选择模式下原帖链接点击暂停（与书名/URL 手势暂停同口径）。
                    // 任务 5：改走外链统一出口（贴吧 App 优先，未装回落浏览器，失败
                    // toast 如实告知）——真机反馈：复制链接无感知，直达才符「原帖」语义。
                    onTap: widget.selectMode
                        ? null
                        : () => openThreadExternallyWithFeedback(context, tidUrl),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text('原帖', style: t.caption.copyWith(color: c.info)),
                        // 设计 03 详情头 `原帖 + i-external`（index.html:1385，.ic.xs 13px → -s 档）。
                        AppIcon('external', size: 13, color: c.info),
                      ],
                    ),
                  ),
              ],
            ),
            if (data.books.isNotEmpty) ...<Widget>[
              SizedBox(height: s.space3),
              Wrap(
                spacing: s.space2,
                runSpacing: s.space2,
                children: <Widget>[
                  for (final PostBookCount b in data.books) PostBookChip(book: b),
                ],
              ),
            ],
            if (post.postKind == CategoryKind.avoid) ...<Widget>[
              SizedBox(height: s.space3),
              // 排雷帖风险提示（§5.6：进入排雷帖先提示风险）。
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: s.space3,
                  vertical: s.space2,
                ),
                decoration: BoxDecoration(
                  color: c.dangerSoft,
                  borderRadius: AppRadius.mdBorder,
                ),
                child: Row(
                  children: <Widget>[
                    // 排雷 = 设计稿 i-alert（与卡片徽标同源，index.html:1479）。
                    AppIcon('alert', size: 16, color: c.danger),
                    SizedBox(width: s.space2),
                    Expanded(
                      child: Text(
                        '排雷帖：内容为负评/避雷向，请注意甄别',
                        style: t.caption.copyWith(color: c.danger),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Divider(height: s.space6),
            if (data.floors.isEmpty)
              const AppEmptyState(
                title: '原帖内容已不可用',
                message: '楼层已全部被删',
                svgIcon: 'book',
              ),
            for (final (int i, FloorData f) in data.floors.indexed) ...<Widget>[
              // 任务 1：相邻楼层之间发丝分割线（首前/末后不加）。FloorHeader 自带
              // space4 上留白，这里只补线上方 space4 → 线两侧各 16，视觉不过挤。
              if (i > 0)
                Padding(
                  padding: EdgeInsets.only(top: s.space4),
                  child: Divider(
                    height: AppMetrics.hairline,
                    thickness: AppMetrics.hairline,
                    color: c.border,
                  ),
                ),
              FloorHeader(seq: f.floor.seq),
              Padding(
                key: _keyFor(f.floor.id),
                padding: EdgeInsets.only(left: s.space4),
                // P1-6：长按楼层正文进入自由复制选择模式；选择模式下置 null（不注册
                // recognizer），长按让位给 SelectionArea 的原生长按选词。书名 InkWell 的
                // 长按复制书名（MI-3）在命中区内更深处，竞技场仍优先，不受影响。
                //
                // 桌面档（鼠标/触控板，用户口径）：**默认就可自由复制**，不必先切模式；
                // 单击书名/链接仍可用（keepTapWhileSelectable），故没有功能损失。
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: selectable ? null : widget.onEnterSelectMode,
                  // 逐楼层包 SelectionArea：楼层内跨段多选（拖拽双 handle + 系统工具栏复制）。
                  // 不整流单包 —— Android 上 SelectableRegion 对水平拖拽即时取胜
                  // （eagerVictoryOnDrag，framework selectable_region.dart），整包会让上下帖
                  // PageView 横滑在正文区全面失效；逐楼层包裹时头部/楼层头/空隙仍可翻页。
                  // 桌面无「横滑翻页」手势，整层可选中不影响任何交互。
                  child: selectable
                      ? SelectionArea(child: _floorBody(f, keepTap: _desktopFreeSelect))
                      : _floorBody(f, keepTap: false),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 桌面端（Windows/Linux/macOS）：帖子详情默认「随时可自由复制」（用户口径），
  /// 不要求先进入自由复制模式；触屏仍沿用长按进模式（见 build 内注释）。
  bool get _desktopFreeSelect {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return true;
      default:
        return false;
    }
  }

  /// 单楼层正文列（富文本 + 内联图片）；可选中档 FloorRichText 并回文本流（P1-6）。
  Widget _floorBody(FloorData f, {required bool keepTap}) {
    final AppSpacing s = AppSpacing.of(context);
    final bool selectable = widget.selectMode || _desktopFreeSelect; // 同 _content 口径
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FloorRichText(
          text: f.floor.content,
          highlightWords: _highlightWords,
          // 任务 4：页内搜索词全楼层统一；「当前命中」只染焦点所在楼层的对应序号。
          searchWord: widget.searchWord,
          searchFocusIndex: widget.searchFocus?.floorId == f.floor.id
              ? widget.searchFocus!.indexInFloor
              : -1,
          selectable: selectable,
          keepTapWhileSelectable: keepTap,
          onBookTap: (String name) =>
              context.go('/search?q=${Uri.encodeComponent(name)}'),
        ),
        if (f.images.isNotEmpty) ...<Widget>[
          SizedBox(height: s.space2),
          FloorImages(images: f.images),
        ],
      ],
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
    final AppSpacing s = AppSpacing.of(context);
    final List<Bookmark> bookmarks =
        ref.watch(bookmarksProvider).value ?? const <Bookmark>[];
    final List<Favorite> favorites =
        ref.watch(favoritesProvider).value ?? const <Favorite>[];
    final bool bookmarked = bookmarks.any(
      (Bookmark b) => b.postRef == widget.postId,
    );
    final bool favorited = favorites.any(
      (Favorite f) =>
          f.targetType == FavoriteTarget.post && f.targetId == widget.postId,
    );
    Widget action(
      String svgIcon,
      String label,
      VoidCallback onTap, {
      bool active = false,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: AppMetrics.minTouchTarget + 12,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                AppIcon(
                  svgIcon,
                  size: 20,
                  color: active ? c.accentStrong : c.textSecondary,
                ),
                // 图标↔文案 gap 4（设计 .actionbar .act{gap:4px}，index.html:677）。
                SizedBox(height: s.space1),
                Text(
                  label,
                  style: t.label.copyWith(
                    letterSpacing: 0,
                    color: active ? c.accentStrong : c.textMuted,
                  ),
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
        border: Border(
          top: BorderSide(color: c.border, width: AppMetrics.hairline),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            // 书签/收藏：设计稿单一 symbol（i-bookmark / i-star），选中态以 accentStrong 染色区分
            //（与 book_detail_page 星标同款约定；无填充变体）。
            action(
              'bookmark',
              '书签',
              () => _toggleBookmark(data),
              active: bookmarked,
            ),
            action(
              'star',
              '收藏',
              () => _toggleFavorite(data),
              active: favorited,
            ),
            action('copy', '复制', () => _copyAll(data)),
            action('list', '目录', () => _showToc(data)),
          ],
        ),
      ),
    );
  }
}

/// 帖内书目 chip（书名 + 全站按帖推荐/排雷次数；点击进书聚合页）。
///
/// 计数口径 = 有多少相关帖子推荐过该书几次（一条推荐记录 = 一帖一次），
/// 不再展示「帖内书目条数」聚合（单帖列 13 本书 ≠ 13 推荐）。
class PostBookChip extends StatelessWidget {
  const PostBookChip({super.key, required this.book});

  final PostBookCount book;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    return InkWell(
      // 书聚合页：expanded 在中间功能区原位显示，窄屏全窗 push（§5.5）。
      onTap: book.groupId == null
          ? null
          : () => openBookDetail(context, book.groupId!),
      borderRadius: AppRadius.pillBorder,
      child: Container(
        height: AppMetrics.bookChipHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: c.bookname.withValues(alpha: 0.08),
          borderRadius: AppRadius.pillBorder,
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  '《${BookNameChip.stripBrackets(book.name)}》',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.cardTitle.copyWith(color: c.bookname),
                ),
              ),
              if (book.recommend > 0) ...<Widget>[
                SizedBox(width: s.space2),
                Text(
                  '${book.recommend} 推荐',
                  style: t.caption.copyWith(color: c.recommend),
                ),
              ],
              if (book.avoid > 0) ...<Widget>[
                SizedBox(width: s.space2),
                Text(
                  '${book.avoid} 排雷',
                  style: t.caption.copyWith(color: c.danger),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 内联图片缩略网格（r14 · Referer 防盗链，§5.6/§9.4；点击进查看器）。
///
/// 列数与 tile 边长按可用宽算（[gridOf]），不再用固定 120dp —— compact 屏（≈411dp）
/// 固定尺寸一行只放 2 张、右侧大片留白（真机反馈）。离线详情页与在线帖页共用。
class FloorImages extends StatelessWidget {
  const FloorImages({super.key, required this.images});

  final List<FloorImage> images;

  /// tile 边长下限（决定列数）/上限（防超宽屏与 expanded 右槽图过大）。
  static const double minTile = 100;
  static const double maxTile = 180;

  /// 百度图床防盗链请求头（§9.4 三保险之二）。
  static const Map<String, String> refererHeaders = <String, String>{
    'Referer': 'https://imgsrc.baidu.com',
  };

  /// 展示链（缩略图与查看器**必须**同口径）：优先 url_original，回落 url_permanent。
  ///
  /// 依据（2026-10-14 实测）：parse.dart `normalizeImageUrl` 产出的 url_permanent 形如
  /// `https://imgsrc.baidu.com/forum/pic/item/<hash>`——**丢了 .jpg 扩展名**，线上 404；
  /// url_original 是上游原样链（`tiebapic…/<hash>.jpg?tbpicau=…`），200。种子 lite 档
  /// url_original 全 NULL（回落到种子自带、带扩展名的 permanent，抽样 12/12 存活），
  /// full 档 url_original 为签名链（抽样 10/10 存活）。故 permanent 只作兜底：
  /// 否则刷新写库后展示会从可用链切到 404 链（真机「图片已失效」的直接成因）。
  static String displayUrl(FloorImage img) {
    final String? original = img.urlOriginal;
    if (original != null && original.isNotEmpty) {
      return original;
    }
    final String? permanent = img.urlPermanent;
    if (permanent != null && permanent.isNotEmpty) {
      return permanent;
    }
    return '';
  }

  /// 网格几何：列数 n = clamp(((w + spacing) / (minTile + spacing)).floor(), 2, 5)，
  /// tile = ⌊(w - spacing·(n-1)) / n⌋，上限 [maxTile]（超出部分由 Wrap 左对齐留白）。
  /// 取整向下：浮点误差若让 n·tile + (n-1)·spacing 略超 w，Wrap 会把末列挤到下一行。
  static ({int columns, double tile}) gridOf(double width, double spacing) {
    final int n = (((width + spacing) / (minTile + spacing)).floor()).clamp(2, 5);
    final double tile = ((width - spacing * (n - 1)) / n).floorToDouble().clamp(
      0.0,
      maxTile,
    );
    return (columns: n, tile: tile);
  }

  /// 查看器画廊归一化（任务 2；纯函数便于 plain test，与 [gridOf]/[displayUrl] 同款）：
  /// [images] 缺省/空 → 退化为被点单图 [img]（旧调用点兼容）；[initialIndex] 夹取
  /// 到合法域，防外部误传越界。
  static ({List<FloorImage> images, int index}) viewerGalleryOf(
    FloorImage img,
    List<FloorImage>? images,
    int initialIndex,
  ) {
    if (images == null || images.isEmpty) {
      return (images: <FloorImage>[img], index: 0);
    }
    return (images: images, index: initialIndex.clamp(0, images.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final double spacing = AppSpacing.of(context).space2;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final ({int columns, double tile}) g = gridOf(
          constraints.maxWidth,
          spacing,
        );
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final (int i, FloorImage img) in images.indexed)
              ClipRRect(
                borderRadius: AppRadius.mdBorder,
                child: GestureDetector(
                  // 任务 2：查看器带上整层画廊 + 点击位，弹层内可左右滑翻页。
                  onTap: () =>
                      showImageViewer(context, img, images: images, initialIndex: i),
                  child: CachedNetworkImage(
                    imageUrl: displayUrl(img),
                    httpHeaders: refererHeaders,
                    width: g.tile,
                    height: g.tile,
                    fit: BoxFit.cover,
                    placeholder: (BuildContext context, String url) => Container(
                      width: g.tile,
                      height: g.tile,
                      color: c.surfaceSunken,
                    ),
                    errorWidget: (BuildContext context, String url, Object error) =>
                        Container(
                          width: g.tile,
                          height: g.tile,
                          color: c.surfaceSunken,
                          // 图裂占位 = 设计稿 i-image（缩略图加载失败降级，index.html:1396）。
                          child: AppIcon('image', size: 20, color: c.textMuted),
                        ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 图片查看器（§5.7：全屏 + 双指缩放 + 同层左右滑翻页，任务 2；保存到相册仍属 M2+）。
///
/// [img] 为被点单图（旧调用点兼容，缺省退化为单张浏览）；[images]/[initialIndex]
/// 提供时按整层画廊 PageView 翻页并显示 i/n 计数（归一化见 [FloorImages.viewerGalleryOf]）。
void showImageViewer(
  BuildContext context,
  FloorImage img, {
  List<FloorImage>? images,
  int initialIndex = 0,
}) {
  final ({List<FloorImage> images, int index}) gallery =
      FloorImages.viewerGalleryOf(img, images, initialIndex);
  showDialog<void>(
    context: context,
    builder: (BuildContext context) => _ImageViewerDialog(
      images: gallery.images,
      initialIndex: gallery.index,
    ),
  );
}

/// 查看器弹层本体（任务 2）：PageView 每页 InteractiveViewer + CachedNetworkImage
/// （防盗链头与取链口径同 [FloorImages]）；底部 i/n 计数（tabular 数字防翻页宽度
/// 跳动，§2.2），右上角关闭钮保留。
class _ImageViewerDialog extends StatefulWidget {
  const _ImageViewerDialog({required this.images, required this.initialIndex});

  final List<FloorImage> images;
  final int initialIndex;

  @override
  State<_ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<_ImageViewerDialog> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _page = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppSpacing s = AppSpacing.of(context);
    return Dialog(
      backgroundColor: c.canvas,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: <Widget>[
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (int i) => setState(() => _page = i),
            itemBuilder: (BuildContext context, int i) => InteractiveViewer(
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: FloorImages.displayUrl(widget.images[i]),
                  httpHeaders: FloorImages.refererHeaders,
                  errorWidget: (BuildContext context, String url, Object error) =>
                      const AppEmptyState(title: '图片已失效', svgIcon: 'image'),
                ),
              ),
            ),
          ),
          // i/n 计数：弹层底色（canvas）即衬底无需遮罩；IgnorePointer 防挡住横滑。
          Positioned(
            left: 0,
            right: 0,
            bottom: s.space6,
            child: IgnorePointer(
              child: Center(
                child: Text(
                  '${_page + 1}/${widget.images.length}',
                  style: AppTypography.tabular(
                    AppTypography.of(context).caption.copyWith(color: c.textSecondary),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: s.space2,
            right: s.space2,
            child: IconButton(
              tooltip: '关闭',
              icon: AppIcon('close', size: 24, color: c.textSecondary),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

