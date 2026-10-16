import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/external_launch.dart';
import '../../core/icons.dart';
import '../../core/widgets/scroll_chrome.dart';
import '../../data/db/app_database.dart';
import '../../data/repo/queries.dart';
import '../../data/repo/queries_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../export/booklist_export.dart';
import '../export/export_sheet.dart';
import '../home/cards.dart';
import '../share/share_card.dart';
import '../share/share_sheet.dart';
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

  /// 列表滚动控制器（ScrollChrome 常驻滚动条/跳顶跳底共用）。
  final ScrollController _scrollController = ScrollController();

  /// 目录跳转锚点（entry.id → 卡片外包容器的 GlobalKey）。键按「筛选×排序」分槽：
  /// AnimatedSwitcher 交叉淡入时新旧两树共存，同 id 若共用同一 GlobalKey 会触发
  /// duplicate-key 断言；分槽后新树独立取键，互不冲突。
  final Map<_SemanticSortKey, Map<int, GlobalKey>> _entryKeys = <_SemanticSortKey, Map<int, GlobalKey>>{};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
          // 条目是从某一楼摘出来的 → 进帖直接落到那一楼，不用读者自己翻。
          // 优先用 floor_ref（floors.id，库内唯一）：多书帖同 seq 下按 seq 会落到别的书那楼。
          initialFloorId: e.floorRef,
          initialFloorSeq: e.floorSeq,
        ),
      );
      return;
    }
    final String? url = e.srcUrl;
    if (url != null && url.isNotEmpty) {
      // 无帖溯源 → 交系统外链（Android 先定向贴吧 App，未装回落浏览器）；失败由封装内如实提示。
      // 不再复制剪贴板兜底：口径与帖头「原帖 ↗」统一（core/external_launch.dart）。
      openThreadExternallyWithFeedback(context, url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('原帖已不可溯源')));
    }
  }

  /// ⋮「导出该书推荐」（原型 §5.11）：把当前筛选下的多条推荐语拼成一张分享卡。
  /// 拼接口径：每条 `「推荐语」—— 推荐人 · 日期 · 排雷`（无推荐语的条目显式标注，不静默丢）。
  void _exportRecommendations(BookDetailData data, List<EntryRow> entries) {
    final BookGroup g = data.group;
    final List<EntryRow> withComment =
        entries.where((EntryRow e) => (e.comment ?? '').trim().isNotEmpty).toList();
    final List<EntryRow> used = withComment.isEmpty ? entries : withComment;
    final String quote = used.map((EntryRow e) {
      final String body = (e.comment ?? '').trim();
      final List<String> tail = <String>[
        if ((e.recommender ?? '').trim().isNotEmpty) '推荐人 ${e.recommender!.trim()}',
        if ((e.date ?? '').trim().isNotEmpty) e.date!.trim(),
        if (e.recommendFlag < 0) CategoryKind.avoid,
      ];
      final String line = body.isEmpty ? '（该条无推荐语）' : '「$body」';
      return tail.isEmpty ? line : '$line\n—— ${tail.join(' · ')}';
    }).join('\n\n');
    showShareSheet(
      context,
      ShareCardSpec(
        bookName: g.nameDisplay ?? g.nameNorm,
        author: g.authorDisplay,
        recommender: used.isEmpty ? null : used.first.recommender,
        quote: quote.isEmpty ? '（当前筛选下没有可导出的评价）' : quote,
      ),
    );
  }

  /// 目录弹层（与帖子详情 _showToc 同款：drag handle + 点行跳转）：每行
  /// 「推荐人 · 日期 · 评论首行」，行数 = 当前筛选下的条目数。
  ///
  /// 高度上限 = 屏幕可用高 × [AppMetrics.tocSheetHeightFactor]（口径同搜索结果目录）：
  /// isScrollControlled 的弹层不设限就铺满全屏、丢掉「这是一层浮层」的视觉线索；
  /// 短目录仍按内容收缩（ConstrainedBox + shrinkWrap）。
  void _showToc(List<EntryRow> entries) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final MediaQueryData mq = MediaQuery.of(context);
    // 可用高度 = 屏高扣掉状态栏 / home indicator（viewPadding 不受键盘影响）。
    final double available = mq.size.height - mq.viewPadding.top - mq.viewPadding.bottom;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: available * AppMetrics.tocSheetHeightFactor),
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              for (int i = 0; i < entries.length; i++)
                ListTile(
                  dense: true,
                  title: Text(
                    _tocLabel(entries[i]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // 行色随条目语义（推荐绿 / 排雷红 / 其余常规文本色，口径同搜索结果目录）：
                    // 扫一眼目录就能看出这本书的评价倾向分布。
                    style: t.secondary.copyWith(color: _tocColorOf(c, entries[i].recommendFlag)),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _scrollToEntry(entries[i].id, i, entries.length);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 目录行语义色（flag → token；中性档用 c.text 而非 textMuted，保证正文可读）。
  Color _tocColorOf(AppColors c, int flag) => switch (flag) {
    1 => c.recommend,
    -1 => c.danger,
    _ => c.text,
  };

  /// 目录行文案：「推荐人 · 日期 · 评论首行」。推荐人/日期缺省段直接省略
  ///（与 BookEntryCard 对缺省字段不渲染同口径）；评论只取第一行。
  String _tocLabel(EntryRow e) {
    final String firstLine = (e.comment ?? '').trim().split('\n').first.trim();
    return <String>[
      if ((e.recommender ?? '').trim().isNotEmpty) e.recommender!.trim(),
      if ((e.date ?? '').trim().isNotEmpty) e.date!.trim(),
      if (firstLine.isNotEmpty) firstLine,
    ].join(' · ');
  }

  GlobalKey _keyFor(int id) =>
      _entryKeys.putIfAbsent(_SemanticSortKey(_filter, _sort), () => <int, GlobalKey>{}).putIfAbsent(id, GlobalKey.new);

  /// 目录跳转：卡片已构建 → ensureVisible 直定位；未构建（远屏未上屏）→ 比例估算落点
  /// 后二次定位（与 content_detail_page._scrollToFloor 同款两段式）。
  void _scrollToEntry(int id, int index, int count) {
    final AppMotionTheme motion = AppMotionTheme.of(context);
    final BuildContext? target = _entryKeys[_SemanticSortKey(_filter, _sort)]?[id]?.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        alignment: 0.05,
        duration: motion.transition.duration,
        curve: motion.transition.curve,
      );
      return;
    }
    if (!_scrollController.hasClients) {
      return;
    }
    final double max = _scrollController.position.maxScrollExtent;
    _scrollController
        .animateTo(
      (max * ((index + 1) / (count + 2))).clamp(0.0, max),
      duration: motion.transition.duration,
      curve: motion.transition.curve,
    )
        .then((_) {
      final BuildContext? target = _entryKeys[_SemanticSortKey(_filter, _sort)]?[id]?.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(target, alignment: 0.05);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AsyncValue<BookDetailData?> async = ref.watch(bookDetailProvider(widget.bookGroupId));
    final List<EntryRow> entries =
        ref.watch(bookEntriesProvider(BookEntryQuery(widget.bookGroupId, _filter, _sort))).value ?? const <EntryRow>[];
    return Scaffold(
      appBar: AppBar(
        // 设计 04 appbar（index.html:1435–1440）：返回 + spacer + star + more，无中间标题；
        // 「书聚合」语义移至 body eyebrow。图标全走设计 SVG（.ic 20px / .icon-btn textSecondary）。
        automaticallyImplyLeading: false,
        leading: (ModalRoute.of(context)?.canPop ?? false)
            ? IconButton(
                tooltip: '返回',
                icon: AppIcon('back', size: 20, color: c.textSecondary),
                onPressed: () => Navigator.maybePop(context),
              )
            : null,
        actions: <Widget>[
          // 目录入口（评价条目跳转目录，§5.5 同款帖子目录语义；仅条目非空时显示）。
          if (entries.isNotEmpty)
            IconButton(
              tooltip: '目录',
              icon: AppIcon('list', size: 20, color: c.textSecondary),
              onPressed: () => _showToc(entries),
            ),
          if (async.value != null)
            Consumer(
              builder: (BuildContext context, WidgetRef ref, Widget? child) {
                final List<Favorite> favorites = ref.watch(favoritesProvider).value ?? const <Favorite>[];
                final bool fav = favorites.any(
                    (Favorite f) => f.targetType == FavoriteTarget.bookGroup && f.targetId == widget.bookGroupId);
                // 设计 .icon-btn.marked（index.html:619–620）：已收藏 = accentStrong 染色，未收藏 = textSecondary。
                return IconButton(
                  tooltip: fav ? '已收藏' : '收藏',
                  icon: AppIcon('star', size: 20, color: fav ? c.accentStrong : c.textSecondary),
                  onPressed: () => _toggleFavorite(async.value!),
                );
              },
            ),
          PopupMenuButton<String>(
            // 菜单容器 = r14 圆角（popupMenuTheme），条目墨渍默认直角会外溢：
            // PopupMenuButton.clipBehavior 默认 Clip.none，须显式裁到菜单形状。
            clipBehavior: Clip.antiAlias,
            tooltip: '更多',
            icon: AppIcon('more', size: 20, color: c.textSecondary),
            itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'copy', child: Text('复制书名')),
              PopupMenuItem<String>(value: 'share', child: Text('导出该书推荐')),
              PopupMenuItem<String>(value: 'export', child: Text('导出书单(MD/TXT)')),
              PopupMenuItem<String>(value: 'author', child: Text('搜索作者')),
            ],
            onSelected: (String v) {
              final BookDetailData? data = async.value;
              if (data == null) {
                return;
              }
              switch (v) {
                case 'copy':
                  Clipboard.setData(ClipboardData(text: data.group.nameDisplay ?? data.group.nameNorm));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('书名已复制到剪贴板')));
                case 'share':
                  _exportRecommendations(data, entries);
                case 'export':
                  // 导出书单文件（P2-4）：与分享同口径，取当前筛选/排序下的条目。
                  showBooklistExportSheet(context, buildBookDoc(data: data, entries: entries));
                default:
                  if ((data.group.authorDisplay ?? '').isNotEmpty) {
                    context.go('/search?q=${Uri.encodeComponent(data.group.authorDisplay!)}');
                  }
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
        svgIcon: 'alert',
        action: AppButton(
          label: '重试',
          kind: AppButtonKind.outline,
          onPressed: () => ref.invalidate(bookDetailProvider(widget.bookGroupId)),
        ),
      );
    }
    return const AppEmptyState(title: '书目不存在', message: '聚合组已被移除', svgIcon: 'db');
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
      child: ScrollChrome(
        controller: _scrollController,
        child: ListView(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(s.pagePadding, s.space4, s.pagePadding, s.space8),
          children: <Widget>[
            // eyebrow（index.html:1444：label 字阶 · accentStrong · letterSpacing .16em = 1.76px）。
            Text('BOOK · 书聚合', style: t.label.copyWith(color: c.accentStrong, letterSpacing: 1.76)),
            SizedBox(height: s.space1),
            // 书名大标题（衬线 display，设计系统 §3 #04）。
            Text('《$name》', style: t.display.copyWith(color: c.text)),
            SizedBox(height: s.space2),
            // 副行（index.html:1446）：作者 · 字数 · N 条独立评价；word_count_max 缺省不拼、
            // 连载状态无字段 —— 不造假。
            Text(
              <String>[
                if ((g.authorDisplay ?? '').isNotEmpty) g.authorDisplay!,
                if (g.wordCountMax != null) _wordCountLabel(g.wordCountMax!),
                '${g.entryTotal} 条独立评价',
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
            // Align 让胶囊裹内容靠左（设计 count-duo = inline-flex）；ListView 直通全宽约束下需要。
            Align(
              alignment: Alignment.centerLeft,
              child: CountTrio(
                scan: data.scanCount,
                recommend: data.recommendCount,
                avoid: data.avoidCount,
                onScanTap: () => setState(() => _filter = SemanticFilter.scan),
                onRecommendTap: () => setState(() => _filter = SemanticFilter.recommend),
                onAvoidTap: () => setState(() => _filter = SemanticFilter.avoid),
              ),
            ),
            SizedBox(height: s.space4),
            // 四档语义筛选 + 右侧排序触发器：390dp 下合计宽度贴临界（Ahem 测试字宽 ≈1em/字，
            // 静态推定 344~352 vs 可用 350），Row+Spacer 溢出一像素即抛 RenderFlex overflow。
            // 改 Wrap（spacing 0 = 不预设槽距）：ListView 十字轴紧约束 → 放得下时 spaceBetween
            // 与 Spacer 视效逐像素一致（贴两端）；放不下才换行，不截断档位标签、不报溢出。
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: s.space2,
              children: <Widget>[
                SegmentedPill<SemanticFilter>(
                  options: const <(SemanticFilter, String)>[
                    (SemanticFilter.all, '全部'),
                    (SemanticFilter.scan, '仅扫书'),
                    (SemanticFilter.recommend, '仅推荐'),
                    (SemanticFilter.avoid, '仅排雷'),
                  ],
                  selected: _filter,
                  onChanged: (SemanticFilter v) => setState(() => _filter = v),
                ),
                PopupMenuButton<EntrySort>(
                  // 同上：选中项 accent-soft 染底/悬停墨渍是直角，须裁进 r14 菜单。
                  clipBehavior: Clip.antiAlias,
                  tooltip: '排序',
                  onSelected: (EntrySort v) => setState(() => _sort = v),
                  // 菜单容器样式走主题 popupMenuTheme（raised 底/发丝描边/r14）；
                  // 项内标记当前排序（accent-soft 染底 + check + accent-strong 600）。
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<EntrySort>>[
                    for (final (EntrySort v, String label) in const <(EntrySort, String)>[
                      (EntrySort.qualityDesc, '质量 ↓'),
                      (EntrySort.timeDesc, '时间 ↓'),
                      (EntrySort.timeAsc, '时间 ↑'),
                      (EntrySort.wordDesc, '字数 ↓'),
                    ])
                      PopupMenuItem<EntrySort>(
                        value: v,
                        height: AppMetrics.minTouchTarget,
                        padding: EdgeInsets.zero,
                        child: Container(
                          height: AppMetrics.minTouchTarget,
                          padding: EdgeInsets.symmetric(horizontal: s.space4),
                          color: v == _sort ? c.accentSoft : null,
                          child: Row(
                            children: <Widget>[
                              SizedBox(
                                width: 18,
                                child: v == _sort ? AppIcon('check', size: 13, color: c.accentStrong) : null,
                              ),
                              Text(
                                label,
                                style: t.body.copyWith(
                                  color: v == _sort ? c.accentStrong : c.text,
                                  fontWeight: v == _sort ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  // 触发器 = chip compact（设计 04 行 1459：sunken 底 pill + 当前值 + chev 13px）。
                  child: Container(
                    height: AppMetrics.chipHeightCompact,
                    padding: EdgeInsets.symmetric(horizontal: s.space3),
                    decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: AppRadius.pillBorder),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(switch (_sort) {
                          EntrySort.qualityDesc => '质量 ↓',
                          EntrySort.timeDesc => '时间 ↓',
                          EntrySort.timeAsc => '时间 ↑',
                          EntrySort.wordDesc => '字数 ↓',
                        }, style: t.secondary.copyWith(color: c.textSecondary)),
                        SizedBox(width: s.space1),
                        AppIcon('chev', size: 13, color: c.textSecondary),
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
                message: '这本书在当前筛选下还没有评价，换个筛选或看全部',
                svgIcon: 'book',
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
                    Container(
                      // 目录跳转锚点（ensureVisible 目标，见 _scrollToEntry）。
                      key: _keyFor(e.id),
                      child: BookEntryCard(
                        key: ValueKey<int>(e.id),
                        entry: e,
                        showRecommender: true,
                        expandableComment: true,
                        commentMaxCollapsed: 100,
                        // 整页同书、书名已在页头大标题 → 卡内不再重复一遍。
                        hideBookName: true,
                        // 点卡片本体直达原帖（与「原帖 ↗」同语义，§5.5）。
                        onTap: () => _openEntrySource(e),
                        onBookTap: (String n) => context.go('/search?q=${Uri.encodeComponent(n)}'),
                        onRecommenderTap: (String r) => context.go('/search?q=${Uri.encodeComponent(r)}'),
                        onSourceTap: () => _openEntrySource(e),
                      ),
                    ),
                ],
              ),
            ),
            // 页脚 hint（index.html:1492，居中 caption muted）。诚实口径：设计稿的
            // 「长按卡片 → 收藏 / 复制书名」未实装，只列已实装交互（§8.9）。
            if (entries.isNotEmpty) ...<Widget>[
              SizedBox(height: s.space5),
              Text(
                '点推荐人 → 以其为关键词搜索 · 点星标 → 收藏本书 · 点更多 → 复制书名 / 导出该书推荐',
                textAlign: TextAlign.center,
                style: t.caption.copyWith(color: c.textMuted),
              ),
            ],
          ],
        ),
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

/// 副行字数文案（设计 04 行 1446「200w 字」；仅 word_count_max 在场时显示）。
String _wordCountLabel(int wc) => wc >= 10000 ? '${(wc / 10000).round()}w 字' : '$wc 字';

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

