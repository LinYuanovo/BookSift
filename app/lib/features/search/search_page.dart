import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../collector/tieba_search.dart';
import '../../core/external_launch.dart';
import '../../core/icons.dart';
import '../../core/widgets/scroll_chrome.dart';
import '../../data/db/app_database.dart';
import '../../data/repo/collect_repository.dart' show kDefaultForums;
import '../../data/repo/queries.dart';
import '../../data/repo/queries_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../content/detail_slot.dart';
import '../export/booklist_export.dart';
import '../export/export_sheet.dart';
import '../home/cards.dart';
import 'filter_panel.dart';
import 'search_state.dart';

// 搜索台（§5.3）+ 搜索结果（§5.4 书级）：关键词 + 六维筛选 chips + 历史（点击复现条件）
// + 联想 + 热门书名；FTS/LIKE 兜底见 Queries.searchBooks（§7.3）。
// P2-2：本地/贴吧在线双 Tab——在线走 c/s/searchpost 匿名接口（§8.2/§8.4），
// 单请求手动触发；整卡点击进在线帖子页（/online/{tid}），卡片右上角按钮直接打开原帖外链。
// 全页零 Material Icon（本地 + 在线 + 历史/联想，结构图标一律 AppIcon SVG；守卫见 test/search）。
// 图标语义对齐设计 02 搜索台屏（index.html id=scr-search:1268–1352）：
// 字段/联想行 = search·16（.ic sm，:1281/:1289）、历史行 = clock·16（:1311）、清除 = close。
// P2-4：结果区「导出书单」→ 当前搜索结果构造 BooklistDoc，复用 export 库弹层（只 import 不改）。
// P2-5：Tab 行右端「目录」= 已加载结果行弹层 → 精确跳转对应结果卡（_ResultsTocJump）；
//       在线结果排序（相关度/时间）纯客户端重排，口径见 search_state.onlineSortProvider。

/// Unix 秒 → 'YYYY-MM-DD'（在线结果行时间列）。
String formatOnlineDate(int unixSeconds) {
  final DateTime d = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// `[高亮]` 标记剥离（Queries snippet 的 `[词]` 标记约定，queries.dart:394；导出取纯文本）。
String stripHighlightMarkers(String text) =>
    text.replaceAllMapped(RegExp(r'\[([^\[\]]*)\]'), (Match m) => m.group(1)!);

/// 当前搜索结果 → 导出文档（P2-4；复用 export 库模型 [BooklistDoc]/[ExportBook]）。
///
/// 口径（字段来源诚实，缺省留空不造假）：
///  - books = 当前结果页的 [GroupHit] 行（分页所及，非全量命中）；
///  - title/author/channels ← hit.name（去书名号）/hit.author/hit.channels；
///  - dateRange ← hit.latestDate（结果行只有最近日期，单日期不谎称跨度）；
///  - entryCount ← hit.recommendCount（渲染器标签「共 N 条推荐」）；avoidCount ← hit.avoidCount；
///  - 摘要 ← hit.preview 去 `[高亮]` 标记后过 [summarizeComment]；排雷 ← hit.bestFlag < 0；
///  - 推荐人/单条日期/单条渠道不在 GroupHit 投影内 → null，渲染器自动省略该行。
BooklistDoc buildSearchResultDoc(SearchOutcome outcome, {String query = '', DateTime? now}) {
  final String q = query.trim();
  return BooklistDoc(
    kind: BooklistDocKind.favorites,
    heading: q.isEmpty ? '搜索结果书单' : '「$q」搜索结果书单',
    generatedAt: now ?? DateTime.now(),
    books: <ExportBook>[
      for (final GroupHit hit in outcome.page.items)
        ExportBook(
          title: BookNameChip.stripBrackets(hit.name),
          author: (hit.author ?? '').trim().isEmpty ? null : hit.author,
          channels: hit.channels,
          dateRange: hit.latestDate,
          entryCount: hit.recommendCount,
          avoidCount: hit.avoidCount,
          recommendations: <ExportRecommendation>[
            ExportRecommendation(
              comment: summarizeComment(
                hit.preview == null ? null : stripHighlightMarkers(hit.preview!),
              ),
              avoid: hit.bestFlag < 0,
            ),
          ],
        ),
    ],
  );
}

/// 搜索结果导出的服务注入点：生产 = [PlatformTextFileSink]；测试
/// `overrideWithValue(BooklistExportService(FakeTextFileSink()))`（零真实 IO，TESTING.md §1）。
final Provider<BooklistExportService> searchExportServiceProvider =
    Provider<BooklistExportService>((Ref ref) => const BooklistExportService());

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, this.initialParams});

  /// 路由 queryParameters（书名点击携条件进入，§5.6）。
  final Map<String, String>? initialParams;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// 结果列表滚动控制器：同一实例传给 _ResultsView 的 ListView 与 ScrollChrome，
  /// 并承担「下滑收起筛选行」的方向监听。
  final ScrollController _resultsController = ScrollController();

  /// 结果目录句柄（本地/在线各一）：结果子视图在 build 时登记「已加载行 + 按 index 精确跳转」，
  /// Tab 行「目录」钮读取当前 Tab 的那一份（P2-5）。
  final _ResultsToc _localToc = _ResultsToc();
  final _ResultsToc _onlineToc = _ResultsToc();

  String? _appliedSignature;
  bool _focused = false;

  /// 筛选行当前是否收起（只在已提交且展示本地结果时有意义；其余场景恒为展开）。
  bool _filtersCollapsed = false;

  /// 目录跳转在途（程序化滚动）：期间挂起 [_onResultsScroll] 的方向启发式。
  bool _tocJumping = false;

  /// 最近一次收起/展开切换（或反向滚动）时的滚动偏移锚点，供累计位移判定。
  double _scrollAnchor = 0;

  // ── 浏览位置记忆（C）：settings KV，键 = 条件签名，值 = 结果列表偏移 ──

  /// 位置存储（build 期惰性取；widget 测试挂具下为 null = 记忆停用）。
  SearchPositionStore? _positionStore;

  /// 目录弹层位置存储（独立 settings 键；同上为 null 时停用）。
  SearchPositionStore? _tocPositionStore;

  /// 当前结果列表对应的条件签名（null = 还没出过本地结果）。
  String? _positionSignature;

  /// 本签名是否已尝试过恢复（分页「加载更多」不重复恢复，避免把用户又拽回去）。
  bool _positionRestoreTried = false;

  /// 位置恢复在途（程序化 jumpTo）：期间既不跑方向启发式也不写回位置。
  bool _restoringPosition = false;

  /// 滚动写回防抖（输入时序常量，口径同 SearchDraftNotifier.suggestDebounce）。
  Timer? _saveDebounce;

  /// 滚动停止后多久写回一次位置（防抖：滚动通知每帧多次，不能每次都写库）。
  static const Duration _positionSaveDebounce = Duration(milliseconds: 400);

  // 收起/展开触发阈值（滚动行为常量，单位 px，非间距/动效 token；
  // 口径同 ScrollChrome._idleHide / SearchDraftNotifier.suggestDebounce）。
  /// 收起还需先滚离顶部超过该偏移，避免顶部轻微滚动即收起。
  static const double _collapseMinOffset = 96;

  /// 展开态：自锚点下滑累计超过该值 → 收起。
  static const double _collapseDelta = 32;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusNode.addListener(() => setState(() => _focused = _focusNode.hasFocus));
    _resultsController.addListener(_onResultsScroll);
    // 关 App 重开：先恢复上次草稿（词 + 六维 + 提交态），带路由条件进入时再由 _syncFromParams 覆盖。
    ref.read(searchDraftProvider.notifier).restore();
    _syncFromParams();
  }

  /// 生命周期兜底：App 退后台/被划掉前，把防抖窗口内的位置立即写回。
  /// 否则「滚动完立刻杀 App」会丢掉最后一段位置（400ms 防抖未到点）。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _saveDebounce?.cancel();
      _flushPositionSave();
    }
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
    WidgetsBinding.instance.removeObserver(this);
    // 离页前把防抖窗口内的最后位置写回（best-effort：不 await，页面已经在拆）。
    _saveDebounce?.cancel();
    _flushPositionSave();
    _controller.dispose();
    _focusNode.dispose();
    _resultsController.dispose();
    _localToc.dispose();
    _onlineToc.dispose();
    super.dispose();
  }

  /// 结果列表滚动方向监听：下滑累计超阈值收起筛选面板；**只有回到最顶端**才展开
  /// （用户口径：上滑不展开，滑到最顶端才展开）。锚点跟随「非触发方向」的滚动，防漂移误触。
  ///
  /// 目录跳转（程序化滚动）期间整段挂起：一路越过收起阈值会先收起筛选面板，视口随之变高、
  /// offset 被夹小，再被本启发式误判成「上滑」而重新展开 —— 收起/展开来回抖动且落点偏移。
  /// 位置恢复（[_restorePosition]）的 jumpTo 同理挂起，且恢复后锚点直接对齐新偏移。
  void _onResultsScroll() {
    if (_tocJumping ||
        _restoringPosition ||
        !_resultsController.hasClients ||
        _resultsController.positions.length != 1) {
      return;
    }
    // 用户真实滚动 → 防抖写回浏览位置（C）。滚动结束另有 ScrollEndNotification
    // 立即写回（见 _ResultsView.onScrollEnd），「滚完立刻切页/杀 App」不丢最后一段位置。
    _schedulePositionSave();
    final double pixels = _resultsController.position.pixels;
    if (_filtersCollapsed) {
      // 仅回顶（offset ≤ 0）才展开；中途上滑不展开。
      if (pixels <= 0) {
        setState(() {
          _filtersCollapsed = false;
          _scrollAnchor = pixels;
        });
      } else if (pixels > _scrollAnchor) {
        _scrollAnchor = pixels;
      }
    } else {
      if (pixels >= _collapseMinOffset && pixels - _scrollAnchor >= _collapseDelta) {
        setState(() {
          _filtersCollapsed = true;
          _scrollAnchor = pixels;
        });
      } else if (pixels < _scrollAnchor) {
        _scrollAnchor = pixels;
      }
    }
  }

  /// 收起状态复位（重新提交 / 切换 Tab 后筛选行回到展开；锚点对齐当前偏移）。
  void _resetFilterCollapse() {
    _filtersCollapsed = false;
    _tocJumping = false;
    _scrollAnchor = _currentOffset();
    // 切 Tab / 重新提交都会销毁重建结果列表（offset 归零），故允许再恢复一次位置。
    _positionRestoreTried = false;
  }

  /// 「确认筛选」钮：收起面板并**主动移除搜索框焦点**（不弹输入法）。
  /// 结果已随条件即时刷新（_resultsView watch 草稿），此处只负责视觉收起。
  void _collapseFilters() {
    _focusNode.unfocus();
    setState(() {
      _filtersCollapsed = true;
      _scrollAnchor = _currentOffset();
    });
  }

  /// 结果列表当前偏移（无 client / 多 client 时按 0 处理）。
  double _currentOffset() => _resultsController.hasClients && _resultsController.positions.length == 1
      ? _resultsController.position.pixels
      : 0;

  // ── 浏览位置记忆（C：settings KV，键 = 条件签名） ──

  /// 结果视图每帧回报「当前生效条件 + 结果是否已就绪」：条件签名变了就换记忆槽，
  /// 结果首帧后恢复该条件上次浏览到的位置。
  ///
  /// 「只筛选不搜索」「不搜索不筛选的条件浏览」同样走这里——签名由六维 + 排序构成，
  /// 空条件也是一个稳定签名。
  void _noteResults(SearchFilter effective, bool loaded) {
    final String signature = searchPositionSignature(effective);
    if (signature != _positionSignature) {
      // 旧条件的待写回作废：此刻列表偏移已属于新条件（或加载态的 0），写回去会污染旧记忆。
      _saveDebounce?.cancel();
      _positionSignature = signature;
      _positionRestoreTried = false;
      // 条件变更 = 换了一批结果 → 目录浏览位置作废（回顶），不把旧条件的目录位置带过来。
      _localToc.scrollOffset = 0;
    }
    if (loaded && !_positionRestoreTried) {
      _positionRestoreTried = true;
      _restorePosition(signature);
    }
  }

  /// 恢复：读到偏移 → 结果首帧后**无动画** jumpTo（夹到当前 maxScrollExtent，
  /// 上次与这次加载的页数不同也不会跳到越界位置）。无记忆（新条件首次浏览）→ 回顶，
  /// 否则换关键词后列表会停在上一条件的旧偏移、把结果头部（命中数）滚出可视区。
  Future<void> _restorePosition(String signature) async {
    final SearchPositionStore? store = _positionStore;
    final double? saved = store == null ? null : await store.read(signature);
    if (!mounted) {
      return;
    }
    // 等到帧末再跳：本条件的列表已布局完成，maxScrollExtent 才是真值。
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_resultsController.hasClients || _resultsController.positions.length != 1) {
      return;
    }
    final ScrollPosition position = _resultsController.position;
    final double target = (saved == null || saved <= 0)
        ? 0
        : math.min(saved, position.maxScrollExtent);
    if (target == position.pixels) {
      _scrollAnchor = position.pixels;
      return;
    }
    _restoringPosition = true;
    position.jumpTo(target);
    // 锚点对齐：否则恢复出的偏移会被方向启发式当成「一次大幅下滑」而立刻收起筛选面板。
    _scrollAnchor = position.pixels;
    _restoringPosition = false;
  }

  /// 滚动结束（手势/惯性停止）→ 立即写回，不等防抖。
  /// 用户「滚完立刻切页/杀 App」时防抖窗口内的位置不会丢。
  void _flushPositionSaveNow() {
    _saveDebounce?.cancel();
    _flushPositionSave();
  }

  /// 用户滚动 → 防抖写回（目录跳转 / 位置恢复这类程序化滚动不写）。
  void _schedulePositionSave() {
    if (_positionStore == null || _positionSignature == null) {
      return;
    }
    _saveDebounce?.cancel();
    _saveDebounce = Timer(_positionSaveDebounce, _flushPositionSave);
  }

  /// 立即写回当前位置（防抖到点 / 离页 dispose / 滚动结束 / 退后台时调用；best-effort，不 await）。
  void _flushPositionSave() {
    final SearchPositionStore? store = _positionStore;
    final String? signature = _positionSignature;
    if (store == null || signature == null || _tocJumping || _restoringPosition) {
      return;
    }
    // 列表已不在树上（回搜索台 / 切在线 Tab）时偏移读不到真值，
    // 写个 0 进去反而抹掉真实记忆 → 直接跳过。
    if (!_resultsController.hasClients || _resultsController.positions.length != 1) {
      return;
    }
    store.save(signature, _resultsController.position.pixels);
  }

  /// 目录跳转：挂起滚动方向启发式 → 交给结果视图定位 → 结束后锚点对齐新偏移。
  void _runTocJump(_ResultsToc toc, int index) {
    final Future<void> Function(int index)? jump = toc.jumpTo;
    if (jump == null) {
      return;
    }
    _tocJumping = true;
    jump(index).whenComplete(() {
      if (!mounted) {
        return;
      }
      _tocJumping = false;
      _scrollAnchor = _currentOffset();
    });
  }

  Future<void> _submit() async {
    _focusNode.unfocus();
    await ref.read(searchDraftProvider.notifier).submit();
    if (!mounted) {
      return;
    }
    setState(_resetFilterCollapse);
    // 在线 Tab 激活时，键盘搜索 = 手动触发一次在线搜索（单请求，无自动批量）。
    if (ref.read(searchTabProvider) == SearchTab.online) {
      await ref.read(onlineSearchProvider.notifier).search(ref.read(searchDraftProvider).filter.query);
    }
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
    final SearchTab tab = ref.watch(searchTabProvider);
    final bool online = draft.submitted && tab == SearchTab.online;
    final AppMotionTheme motion = AppMotionTheme.of(context);
    // 浏览位置记忆的存储（widget 测试挂具下为 null = 停用，见 searchPositionStoreProvider）。
    _positionStore ??= ref.read(searchPositionStoreProvider);
    _tocPositionStore ??= ref.read(searchTocPositionStoreProvider);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.of(context).space3,
        title: _searchField(context),
      ),
      body: Column(
        children: <Widget>[
          if (draft.submitted)
            _SearchTabs(
              tab: tab,
              onChanged: (SearchTab v) {
                ref.read(searchTabProvider.notifier).state = v;
                setState(_resetFilterCollapse);
              },
              // 目录只列**当前 Tab 已加载**的结果行（未加载页不进目录）；
              // 跳转经 _runTocJump 挂起滚动方向启发式，保证落点精确不抖动。
              onToc: () {
                final _ResultsToc toc = tab == SearchTab.online ? _onlineToc : _localToc;
                // 目录位置持久化：本地 Tab 按当前条件签名存取（在线 Tab 无签名 → 仅内存句柄）。
                _showResultsToc(
                  context,
                  toc,
                  (int index) => _runTocJump(toc, index),
                  store: tab == SearchTab.online ? null : _tocPositionStore,
                  signature: tab == SearchTab.online ? null : _positionSignature,
                );
              },
            ),
          // 六维筛选只对本地库有意义；在线 Tab 隐藏（口径见 _OnlineResultsView 头部徽标）。
          // 已提交且展示本地结果时，结果列表下滑超阈值 → 收起（高度 0 + 透明）；上滑/回顶展开。
          // 时长/曲线全走 motion token：收起 = exit、展开 = enter（exit-faster-than-enter，§6.2）。
          if (!online)
            AnimatedCrossFade(
              key: const ValueKey<String>('search-filter-collapse'),
              firstChild: SearchFilterPanel(
                filter: draft.filter,
                onConfirm: _collapseFilters,
              ),
              secondChild: const SizedBox(width: double.infinity, height: 0),
              crossFadeState: _filtersCollapsed ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: motion.exit.duration,
              reverseDuration: motion.enter.duration,
              firstCurve: motion.standard,
              secondCurve: motion.standard,
              sizeCurve: motion.standard,
            ),
          const Divider(height: AppMetrics.hairline),
          Expanded(
            child: !draft.submitted
                ? _ConsoleView(onSearch: _searchFor)
                : online
                    ? _OnlineResultsView(key: const ValueKey<String>('online-results-view'), toc: _onlineToc)
                    : _ResultsView(
                        draft: draft,
                        controller: _resultsController,
                        toc: _localToc,
                        onResults: _noteResults,
                        onScrollEnd: _flushPositionSaveNow,
                      ),
          ),
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
          // 设计 02 屏字段图标 `.ic sm` i-search（index.html:1281）；聚焦染 accentStrong。
          AppIcon('search', size: 16, color: _focused ? c.accentStrong : c.textMuted),
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
              icon: AppIcon('close', size: 16, color: c.textMuted),
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
                    // 设计 02 屏联想行 `.ic sm` i-search（index.html:1289）。
                    AppIcon('search', size: 16, color: c.textMuted),
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
        // 无 trash 资产；破坏性动作 = close 染 danger（24 导航档）。
        child: AppIcon('close', size: 24, color: c.danger),
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
              // 设计 02 屏历史行 `.ic sm` i-clock（index.html:1311）。
              AppIcon('clock', size: 16, color: c.textMuted),
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

// ── 结果目录（Tab 行右端「目录」钮 → 弹层列已加载行 → 精确跳转对应结果卡） ──────

/// 目录跳转对齐比例（滚动落点常量：目标卡顶落在视口 8% 处，非间距 token；
/// 口径同 content_detail_page._scrollToFloor 的 0.05 / home_page._scrollToGroup）。
const double _kTocAlignment = 0.08;

/// 目录跳转兜底 cacheExtent（拿不到 ScrollPosition 时的足够大值；滚动行为常量，非间距 token）。
const double _kTocCacheExtentFallback = 1e5;

/// 目录一行（title = 书名/帖标题；subtitle = 最近日期，缺省不显示）。
class _TocEntry {
  const _TocEntry({required this.title, this.subtitle, this.rec = 0, this.avoid = 0});

  final String title;
  final String? subtitle;

  /// 推荐 / 排雷计数：目录行按「推荐多 / 排雷多」染色——几十行的长目录里，
  /// 一眼能挑出风险条目，不必逐行点进结果卡看计数。
  final int rec;
  final int avoid;

  /// 标题色（推荐多 = recommend 绿，排雷多 = danger 红，持平/中性 = 常规文本色）。
  Color titleColor(AppColors c) =>
      rec > avoid ? c.recommend : avoid > rec ? c.danger : c.text;
}

/// 结果目录句柄：结果子视图在 build 时登记「**已加载**行」与「按 index 精确跳转」闭包，
/// Tab 行「目录」按钮据此弹层（未加载页不进目录）。实例由页面 State 持有，子视图重建不丢登记。
class _ResultsToc {
  List<_TocEntry> entries = const <_TocEntry>[];
  Future<void> Function(int index)? jumpTo;

  /// 是否还有下一页（结果视图每帧登记）——目录触底自动加载更多的闸门。
  bool hasMore = false;

  /// 加载下一页（与结果列表「加载更多」按钮同一口径：递增 resultPageProvider）。
  /// null = 当前 Tab 不参与自动加载（在线 Tab 维持手动单请求口径）。
  VoidCallback? loadMore;

  /// 目录弹层自身的滚动偏移（用户口径：不变更搜索词时，关掉目录再打开要回到上次浏览位置）。
  /// 句柄由页面 State 持有 → 弹层关闭不丢；搜索条件变更时由结果视图重置为 0。
  double scrollOffset = 0;

  /// 登记版本号：结果视图每次重建后于**帧后** +1，弹层据此感知追加进来的新行
  /// （build 期 notify 会触发「构建中修改其它 element」错误，故必须推到帧后）。
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void bump() => revision.value++;

  void dispose() => revision.dispose();
}

/// 弹目录层（home_page._showDateToc / content_detail_page._showToc 同款形态）：
/// 一行一条已加载结果，点条目 = pop + 由 [onPick] 精确跳转到结果列表对应卡片。
/// isScrollControlled：目录行可达数十行（分页累积），默认的 9/16 高度上限会把末几行藏进
/// 没有视觉提示的滚动里；高度上限由弹层内部按 [AppMetrics.tocSheetHeightFactor] 收口。
void _showResultsToc(
  BuildContext context,
  _ResultsToc toc,
  ValueChanged<int> onPick, {
  SearchPositionStore? store,
  String? signature,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) =>
        _ResultsTocSheet(toc: toc, onPick: onPick, store: store, signature: signature),
  );
}

/// 目录弹层内容（StatefulWidget：自持滚动控制器，承担「触底自动加载更多」与高度收口）。
///
/// 高度上限 = 屏幕可用高度 × [AppMetrics.tocSheetHeightFactor]：isScrollControlled 的弹层
/// 不设限就会铺满全屏（真机反馈的现象）——顶到状态栏、丢掉「这是一层浮层」的视觉线索；
/// 短目录仍按内容收缩（ConstrainedBox + shrinkWrap ListView）。
class _ResultsTocSheet extends StatefulWidget {
  const _ResultsTocSheet({
    required this.toc,
    required this.onPick,
    this.store,
    this.signature,
  });

  final _ResultsToc toc;
  final ValueChanged<int> onPick;

  /// 目录位置的持久化存储 + 条件签名（null = 停用，如 widget 测试挂具）。
  final SearchPositionStore? store;
  final String? signature;

  @override
  State<_ResultsTocSheet> createState() => _ResultsTocSheetState();
}

class _ResultsTocSheetState extends State<_ResultsTocSheet> {
  final ScrollController _controller = ScrollController();

  /// 上次触底触发加载的时刻（节流：滚动通知一帧可达数次，防一次触底连发多页）。
  DateTime _lastLoadMore = DateTime.fromMillisecondsSinceEpoch(0);

  /// 触底节流间隔（输入时序常量，口径同 SearchDraftNotifier.suggestDebounce）。
  static const Duration _loadMoreThrottle = Duration(milliseconds: 600);

  /// 距底部多少 px 内算「到底」（滚动行为常量，口径同 SearchPage._collapseMinOffset）。
  static const double _loadMoreEdge = 24;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    // 恢复上次目录浏览位置（用户口径：不变更搜索词时关掉再开、关 App 重开都要回到原处）。
    // 内存句柄优先（本次会话内已滚过）；无则读持久化 KV。
    // 推到帧末：此刻列表已布局完成，maxScrollExtent 才是真值（行数可能变化）。
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_controller.hasClients) {
        return;
      }
      double saved = widget.toc.scrollOffset;
      final SearchPositionStore? store = widget.store;
      final String? signature = widget.signature;
      if (saved <= 0 && store != null && signature != null) {
        saved = await store.read(signature) ?? 0;
        if (!mounted || !_controller.hasClients) {
          return;
        }
      }
      if (saved > 0) {
        _controller.jumpTo(saved.clamp(0.0, _controller.position.maxScrollExtent));
      }
    });
  }

  @override
  void dispose() {
    // 关闭弹层时写回滚动位置（内存句柄跨弹层生命周期；KV 跨 App 重启）。
    if (_controller.hasClients && _controller.positions.length == 1) {
      final double px = _controller.position.pixels;
      widget.toc.scrollOffset = px;
      final SearchPositionStore? store = widget.store;
      final String? signature = widget.signature;
      if (store != null && signature != null) {
        store.save(signature, px);
      }
    }
    _controller.dispose();
    super.dispose();
  }

  /// 目录滚到底 → 加载下一页（新行随结果视图重建追加进目录，弹层经 revision 感知）。
  /// 同时把当前偏移写回句柄 + 持久化 KV（目录浏览位置记忆；关弹层/关 App 都不丢）。
  void _onScroll() {
    if (!_controller.hasClients || _controller.positions.length != 1) {
      return;
    }
    final double px = _controller.position.pixels;
    widget.toc.scrollOffset = px;
    final SearchPositionStore? store = widget.store;
    final String? signature = widget.signature;
    if (store != null && signature != null) {
      store.save(signature, px);
    }
    final ScrollPosition position = _controller.position;
    // maxScrollExtent > 0：目录不足一屏时不触发（否则 pixels == maxScrollExtent == 0 恒成立）。
    if (position.maxScrollExtent <= 0 || position.extentAfter > _loadMoreEdge) {
      return;
    }
    final VoidCallback? loadMore = widget.toc.loadMore;
    // hasMore 由结果视图登记：加载在途时结果未就绪 → false，天然挡住重复触发。
    if (loadMore == null || !widget.toc.hasMore) {
      return;
    }
    final DateTime now = DateTime.now();
    if (now.difference(_lastLoadMore) < _loadMoreThrottle) {
      return;
    }
    _lastLoadMore = now;
    loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final MediaQueryData mq = MediaQuery.of(context);
    // 可用高度 = 屏高扣掉状态栏 / home indicator（viewPadding 不受键盘影响）。
    final double available = mq.size.height - mq.viewPadding.top - mq.viewPadding.bottom;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: available * AppMetrics.tocSheetHeightFactor),
        child: ValueListenableBuilder<int>(
          valueListenable: widget.toc.revision,
          builder: (BuildContext context, int revision, Widget? child) {
            final List<_TocEntry> entries = widget.toc.entries;
            if (entries.isEmpty) {
              return Padding(
                padding: EdgeInsets.all(AppSpacing.of(context).pagePadding),
                child: Text('尚无已加载的结果行', style: t.secondary.copyWith(color: c.textMuted)),
              );
            }
            return ListView(
              controller: _controller,
              shrinkWrap: true,
              children: <Widget>[
                for (int i = 0; i < entries.length; i++)
                  ListTile(
                    dense: true,
                    title: Text(
                      entries[i].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.secondary.copyWith(color: entries[i].titleColor(c)),
                    ),
                    trailing: entries[i].subtitle == null
                        ? null
                        : Text(
                            entries[i].subtitle!,
                            style: AppTypography.tabular(t.caption.copyWith(color: c.textMuted)),
                          ),
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onPick(i);
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 结果目录跳转能力（本地/在线结果视图共用）。
///
/// 结果卡高度不定（摘要行数 / 渠道 chips 可变），比例估算落点不可靠，故按 index 键控
/// [GlobalKey] 精确定位：
///  · 目标卡已构建 → 直接 [Scrollable.ensureVisible]（alignment [_kTocAlignment]）；
///  · 目标卡未构建（已加载但落在 ListView cacheExtent 之外）→ 临时把 cacheExtent 撑到
///    列表全高（[tocCacheExtent] 交给 ListView 的 cacheExtent 参数），帧后 ensureVisible，
///    滚动动画结束再恢复默认值。
mixin _ResultsTocJump<W extends ConsumerStatefulWidget> on ConsumerState<W> {
  final Map<int, GlobalKey> _tocKeys = <int, GlobalKey>{};
  double? _tocCacheExtent;

  /// 结果列表滚动控制器（与 ScrollChrome 共享的同一实例）。
  ScrollController get resultsController;

  /// 交给 ListView 的 cacheExtent（null = 框架默认；仅目录跳转期间临时放大）。
  double? get tocCacheExtent => _tocCacheExtent;

  /// index → 结果卡 key（稳定复用：同一 index 恒定同一 key；列表变短时残留 key 不挂载）。
  GlobalKey tocKeyAt(int index) => _tocKeys.putIfAbsent(index, GlobalKey.new);

  /// 目录第 [index] 行 → 结果列表对应卡片（Future 在定位动画结束后完成，
  /// 供页面在跳转期间挂起「下滑收起筛选行」的方向启发式）。
  Future<void> jumpToTocEntry(int index) async {
    final GlobalKey key = tocKeyAt(index);
    final BuildContext? built = key.currentContext;
    if (built != null) {
      await _reveal(built);
      return;
    }
    setState(() => _tocCacheExtent = _fullExtent());
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }
    final BuildContext? target = key.currentContext;
    if (target == null || !target.mounted) {
      setState(() => _tocCacheExtent = null);
      return;
    }
    try {
      await _reveal(target);
    } finally {
      if (mounted) {
        setState(() => _tocCacheExtent = null);
      }
    }
    // 真机帧时序下复原 cacheExtent 后落点可能漂移：下一帧按 key 再补一次对齐定位
    //（已对齐时 ensureVisible 为空操作；widget 测试帧确定，此路径为真机兜底）。
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }
    final BuildContext? settle = key.currentContext;
    if (settle != null && settle.mounted) {
      await _reveal(settle);
    }
  }

  /// 二段定位：结果列表滚动会联动「下滑收起筛选行」（_SearchPageState._onResultsScroll，
  /// exit 200ms），视口高度在滚动动画（transition 300ms）途中变化 → 首段落点会偏；
  /// 动画结束后按最终几何再定位一次（与 content_detail_page._scrollToFloor 的两段式同构）。
  Future<void> _reveal(BuildContext target) async {
    final AppMotionTheme motion = AppMotionTheme.of(context);
    Future<void> once() => Scrollable.ensureVisible(
          target,
          alignment: _kTocAlignment,
          duration: motion.transition.duration,
          curve: motion.transition.curve,
        );
    await once();
    if (!mounted || !target.mounted) {
      return;
    }
    await once();
  }

  /// 「cacheExtent 撑到列表全高」的取值 = maxScrollExtent + 视口高。
  double _fullExtent() {
    final ScrollController controller = resultsController;
    if (!controller.hasClients || controller.positions.length != 1) {
      return _kTocCacheExtentFallback;
    }
    final ScrollPosition position = controller.position;
    return position.maxScrollExtent + position.viewportDimension;
  }
}

/// 头行/Tab 行的图标钮槽：固定 44dp 方形（触控下限 [AppMetrics.minTouchTarget]）+
/// IconButton 去内边距、图标光学居中 —— 与同行 caption 文本共用 Row 的 center 对齐时，
/// 20dp 图标与文本落在同一中线上（IconButton 默认 8dp 内边距会把图标压到文本中线之下）。
class _IconSlotButton extends StatelessWidget {
  const _IconSlotButton({required this.tooltip, required this.svgIcon, required this.onPressed});

  final String tooltip;

  /// 设计稿 SVG symbol 名（AppIcon 单一出口）。
  final String svgIcon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppMetrics.minTouchTarget,
      height: AppMetrics.minTouchTarget,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        alignment: Alignment.center,
        style: IconButton.styleFrom(
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: AppIcon(svgIcon, size: 20, color: AppColors.of(context).textSecondary),
        onPressed: onPressed,
      ),
    );
  }
}

/// 结果视图（§5.4 书级）：命中总数 + 书级卡列表 + 无限分页（每页 40）。
/// ListView 接 ScrollChrome（常驻细滚动条 + 悬浮跳顶/跳底），controller 与调用方共享
/// （_SearchPageState 持有，兼作「下滑收起筛选行」的方向监听）。
/// 目录跳转（P2-5）：结果卡按 index 键控 GlobalKey，能力经 [_ResultsTocJump] 登记到 [toc]。
class _ResultsView extends ConsumerStatefulWidget {
  const _ResultsView({
    required this.draft,
    required this.controller,
    required this.toc,
    required this.onResults,
    required this.onScrollEnd,
  });

  final SearchDraft draft;

  /// 与 ScrollChrome 共享的滚动控制器（同一实例）。
  final ScrollController controller;

  /// 目录句柄（Tab 行「目录」钮读取；页面 State 持有）。
  final _ResultsToc toc;

  /// 结果回报（浏览位置记忆）：每帧把「当前生效条件 + 结果是否就绪」交回页面 State，
  /// 由页面决定恢复/写回滚动位置（页面才持有 controller 与方向启发式的状态）。
  final void Function(SearchFilter effective, bool loaded) onResults;

  /// 滚动结束回调：页面据此立即写回浏览位置（不等防抖）。
  final VoidCallback onScrollEnd;

  @override
  ConsumerState<_ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends ConsumerState<_ResultsView> with _ResultsTocJump<_ResultsView> {
  @override
  ScrollController get resultsController => widget.controller;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final AppMotionTheme motion = AppMotionTheme.of(context);
    final int pages = ref.watch(resultPageProvider);
    final SearchFilter effective = widget.draft.filter.copyWith(limit: 40 * pages, offset: 0);
    final AsyncValue<SearchOutcome> async = ref.watch(searchResultProvider(effective));
    final SearchOutcome? outcome = async.value;
    final List<GroupHit> items = outcome?.page.items ?? const <GroupHit>[];

    // 目录登记（P2-5）：只列**已加载**行（分页所及），顺序与列表一致；jumpTo 走 index 键控
    // GlobalKey 精确定位。build 期写入句柄（页面 State 持有的普通对象，不触发重建），
    // 「目录」按钮在点击时才读，故弹层拿到的恒为最近一帧的已加载行。
    // 加载更多期间 outcome 暂为 null（新 limit = 新的 provider 键）：此时**保留**上一帧
    // 登记，否则弹层会闪一下「尚无已加载的结果行」再回填。
    if (outcome != null) {
      widget.toc.entries = <_TocEntry>[
        for (final GroupHit hit in items)
          _TocEntry(
            title: '《${BookNameChip.stripBrackets(hit.name)}》',
            subtitle: hit.latestDate,
            rec: hit.recommendCount,
            avoid: hit.avoidCount,
          ),
      ];
    }
    widget.toc
      ..jumpTo = jumpToTocEntry
      // 目录触底自动加载更多（B）：与列表「加载更多」按钮完全同口径（递增 resultPageProvider）。
      ..hasMore = outcome?.page.hasMore ?? false
      ..loadMore = () => ref.read(resultPageProvider.notifier).state = pages + 1;
    // 帧后再通知弹层（build 期 notify 会在构建中改别的 element）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.toc.bump();
      }
    });

    // 浏览位置记忆（C）：条件签名 + 是否就绪交回页面（恢复/写回都在页面侧做）。
    widget.onResults(effective, outcome != null);

    // FTS 异常降级 → SnackBar「已降级为慢速搜索」（§5.3 错误态；MI-4）。
    ref.listen<AsyncValue<SearchOutcome>>(searchResultProvider(effective),
        (AsyncValue<SearchOutcome>? prev, AsyncValue<SearchOutcome> next) {
      if (next.value?.degraded == true && prev?.value?.degraded != true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已降级为慢速搜索')));
      }
    });

    return ScrollChrome(
      controller: widget.controller,
      child: NotificationListener<ScrollEndNotification>(
        // 滚动结束 → 立即写回位置（不等防抖；滚完立刻切页/杀 App 也不丢）。
        onNotification: (ScrollEndNotification n) {
          widget.onScrollEnd();
          return false;
        },
        child: ListView(
          controller: widget.controller,
          // 目录跳转兜底期间临时撑到列表全高（见 _ResultsTocJump），常态 null = 框架默认。
          cacheExtent: tocCacheExtent,
          padding: EdgeInsets.fromLTRB(s.pagePadding, s.space3, s.pagePadding, s.space8),
        children: <Widget>[
          Row(
            // 同一行「标题 + 命中数 + 图标钮」一律 center 对齐：图标走固定 44dp 方形槽
            // （_IconSlotButton）做光学居中，20dp 图标与 caption 命中数落在同一中线；
            // 间距一律 AppSpacing 令牌（原 end 对齐 + IconButton 内边距 → 图标看着低于文本）。
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.draft.filter.query.isEmpty ? '条件浏览' : '"${widget.draft.filter.query}"',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.headline.copyWith(color: c.text),
                ),
              ),
              SizedBox(width: s.space2),
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
              if (outcome?.usedFts ?? false) ...<Widget>[
                SizedBox(width: s.space1),
                Text('FTS', style: t.label.copyWith(color: c.textMuted, letterSpacing: 0)),
              ],
              // P2-4：导出当前搜索结果（分页所及的书目行）；空结果隐藏入口。
              if (items.isNotEmpty) ...<Widget>[
                SizedBox(width: s.space2),
                _IconSlotButton(
                  tooltip: '导出书单',
                  svgIcon: 'external',
                  onPressed: () => showBooklistExportSheet(
                    context,
                    buildSearchResultDoc(outcome!, query: widget.draft.filter.query),
                    service: ref.read(searchExportServiceProvider),
                  ),
                ),
              ],
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
              svgIcon: 'alert',
              action: AppButton(
                label: '重试',
                kind: AppButtonKind.outline,
                onPressed: () => ref.invalidate(searchResultProvider(effective)),
              ),
            ),
          if (outcome != null && outcome.page.items.isEmpty)
            AppEmptyState(
              title: widget.draft.filter.query.isEmpty
                  ? '没有符合条件的条目'
                  : '没有找到与 "${widget.draft.filter.query}" 相关的书',
              message: '检查错别字 / 减少筛选条件 / 试试 2 字简称',
              svgIcon: 'search',
              // §5.3（行 393）：空态给「贴吧在线搜索」入口（P2-2）→ 切在线 Tab 并手动触发一次。
              action: widget.draft.filter.query.trim().isEmpty
                  ? null
                  : AppButton(
                      label: '贴吧在线搜索',
                      kind: AppButtonKind.outline,
                      onPressed: () {
                        ref.read(searchTabProvider.notifier).state = SearchTab.online;
                        ref.read(onlineSearchProvider.notifier).search(widget.draft.filter.query);
                      },
                    ),
            ),
          if (outcome != null && outcome.page.items.isNotEmpty) ...<Widget>[
            StaggerPanel(
              spacing: s.cardGap,
              switchKey: ValueKey<SearchFilter>(effective),
              children: <Widget>[
                for (int i = 0; i < items.length; i++)
                  _GroupHitCard(key: tocKeyAt(i), hit: items[i], draft: widget.draft),
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
        ),
      ),
    );
  }
}

/// 计数列彩色圆点（设计 dot-sep 的 CSS 圆点语汇，index.html:669；装饰色块非结构图标，
/// 不走 SVG 资产——线稿 stroke 图标染不出实心 8px 点）。
class _CountDot extends StatelessWidget {
  const _CountDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// 书级结果卡（§5.4：书名+作者+推荐/排雷计数+最近日期+摘要高亮+渠道徽标集合）。
class _GroupHitCard extends StatelessWidget {
  const _GroupHitCard({super.key, required this.hit, required this.draft});

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
              _CountDot(color: c.recommend),
              SizedBox(width: s.space1),
              Text('${hit.recommendCount} 推荐',
                  style: AppTypography.tabular(t.caption.copyWith(color: c.recommend))),
              if (hit.avoidCount > 0) ...<Widget>[
                SizedBox(width: s.space3),
                _CountDot(color: c.danger),
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
            // 命中高亮摘要（snippet 带 `[词]` 标记）。
            HighlightText(
              text: hit.snippet!,
              maxLines: 3,
              style: t.secondary.copyWith(color: c.textSecondary),
            ),
          ] else if ((hit.preview ?? '').isNotEmpty) ...<Widget>[
            SizedBox(height: s.space2),
            // 无命中高亮（书名级命中/条件浏览）→ 展示正文预览（100 字截断，用户口径）。
            Text(
              hit.preview!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
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

/// 本地/在线双 Tab（提交后出现；SegmentedPill 复用分段控件规格 §4）。
/// 同一行最右端为「目录」图标钮（P2-5，list·20 = 帖子详情底部操作条目录同款语义）。
class _SearchTabs extends StatelessWidget {
  const _SearchTabs({required this.tab, required this.onChanged, required this.onToc});

  final SearchTab tab;
  final ValueChanged<SearchTab> onChanged;

  /// 「目录」钮点击（弹已加载结果行目录）。
  final VoidCallback onToc;

  @override
  Widget build(BuildContext context) {
    final AppSpacing s = AppSpacing.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(s.pagePadding, s.space3, s.pagePadding, 0),
      child: Row(
        children: <Widget>[
          SegmentedPill<SearchTab>(
            options: const <(SearchTab, String)>[
              (SearchTab.local, '本地库'),
              (SearchTab.online, '贴吧在线'),
            ],
            selected: tab,
            onChanged: onChanged,
          ),
          const Spacer(),
          _IconSlotButton(tooltip: '目录', svgIcon: 'list', onPressed: onToc),
        ],
      ),
    );
  }
}

/// 「实时联网·匿名」徽标（在线模式明示口径：匿名 searchpost，无需登录，§8.2）。
class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge();

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    return Container(
      height: AppMetrics.badgeHeight,
      // 徽标水平 padding 10（badge 规格 index.html:277，与榜单页 _KindBadge 同源；间距体系无此档）。
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: c.infoSoft, borderRadius: AppRadius.pillBorder),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppIcon('wifi', size: 13, color: c.info),
          SizedBox(width: s.space1),
          Text('实时联网·匿名',
              style: t.label.copyWith(fontWeight: FontWeight.w600, color: c.info, letterSpacing: 0)),
        ],
      ),
    );
  }
}

/// 打开原帖（外链单一出口 core/external_launch.dart）：Android 先定向贴吧 App，
/// 未安装/非 Android 落系统浏览器，都没有则 SnackBar 如实告知——与帖子详情页
/// 「原帖 ↗」同一口径（旧行为是复制链接到剪贴板，用户还得自己切浏览器粘贴）。
void openThreadLink(BuildContext context, OnlineThread thread) =>
    openThreadExternallyWithFeedback(context, thread.url);

/// 贴吧在线结果视图（P2-2）：手动触发搜索 → 结果行列表（标题/吧名/作者/回复数/时间），
/// 整卡点击进在线帖子页（/online/{tid}）、卡片右上角按钮打开原帖外链；
/// 加载/空/错误三态齐备，错误含 §8.12「贴吧接口似乎已变更」降级文案。
/// ListView 接 ScrollChrome（常驻细滚动条 + 悬浮跳顶/跳底）。
/// 本子树零 Material Icon（结构图标一律 AppIcon SVG，测试守卫见 test/search）。
/// P2-5：排序行（相关度/时间，客户端重排已加载结果）+ 目录跳转（[_ResultsTocJump]）。
class _OnlineResultsView extends ConsumerStatefulWidget {
  const _OnlineResultsView({super.key, required this.toc});

  /// 目录句柄（Tab 行「目录」钮读取；页面 State 持有）。
  final _ResultsToc toc;

  @override
  ConsumerState<_OnlineResultsView> createState() => _OnlineResultsViewState();
}

class _OnlineResultsViewState extends ConsumerState<_OnlineResultsView>
    with _ResultsTocJump<_OnlineResultsView> {
  /// 与 ScrollChrome 共享的滚动控制器（同一实例）。
  final ScrollController _controller = ScrollController();

  @override
  ScrollController get resultsController => _controller;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final OnlineSearchState online = ref.watch(onlineSearchProvider);
    final String query = ref.watch(searchDraftProvider).filter.query.trim();
    final OnlineSearchNotifier notifier = ref.read(onlineSearchProvider.notifier);
    // 输入词已变（结果过期）→ 回手动触发入口，不拿旧词结果冒充新词。
    final bool stale = online.query != query;
    // 排序 = 客户端重排**已加载**结果（切换不重新发请求；口径见 onlineSortProvider 注释）。
    final List<OnlineThread> rows =
        sortOnlineThreads(online.threads, ref.watch(onlineSortProvider));

    // 目录登记（P2-5）：只列已加载帖子行，顺序与列表一致（随排序档变化）。
    // 在线 Tab 不登记 hasMore/loadMore：在线是「单请求手动触发」口径（§8.11 匿名通道频控），
    // 目录触底不代替用户发请求。
    widget.toc.entries = <_TocEntry>[
      for (final OnlineThread th in rows)
        _TocEntry(title: th.title.isEmpty ? '（无标题）' : th.title),
    ];
    widget.toc.jumpTo = jumpToTocEntry;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.toc.bump();
      }
    });

    return ScrollChrome(
      controller: _controller,
      child: ListView(
        controller: _controller,
        // 目录跳转兜底期间临时撑到列表全高（见 _ResultsTocJump），常态 null = 框架默认。
        cacheExtent: tocCacheExtent,
        padding: EdgeInsets.fromLTRB(s.pagePadding, s.space3, s.pagePadding, s.space8),
        children: <Widget>[
          Row(
            children: <Widget>[
              const _OnlineBadge(),
              const Spacer(),
              if (online.status == OnlineStatus.ready && !stale)
                Text('${rows.length} 条',
                    style: AppTypography.tabular(t.secondary.copyWith(color: c.textMuted))),
            ],
          ),
          SizedBox(height: s.space3),
          if (online.status == OnlineStatus.loading && online.page == 0 && !stale)
            // 加载态：骨架卡 ×5（§5.4 同规格）。
            for (int i = 0; i < 5; i++)
              Padding(
                padding: EdgeInsets.only(bottom: s.cardGap),
                child: SkeletonBlock(height: 96),
              )
          else if (online.status == OnlineStatus.error && !stale)
            _OnlineErrorState(online: online, query: query, notifier: notifier)
          else if ((online.status == OnlineStatus.ready || online.isAppending) && !stale)
            if (online.threads.isEmpty && !online.isAppending)
              AppEmptyState(
                title: '贴吧里没有搜到与 "$query" 相关的帖子',
                message: '试试更短的关键词，或切回「本地库」检索离线数据',
                svgIcon: 'search',
              )
            else ...<Widget>[
              // 排序行只在有已加载结果时出现（无结果可排）。
              const _OnlineSortRow(),
              SizedBox(height: s.space3),
              StaggerPanel(
                spacing: s.cardGap,
                switchKey: ValueKey<String>('${online.query}#${online.page}'),
                children: <Widget>[
                  for (int i = 0; i < rows.length; i++)
                    _OnlineThreadCard(key: tocKeyAt(i), thread: rows[i]),
                ],
              ),
              SizedBox(height: s.space5),
              Center(child: _OnlineFooter(online: online, notifier: notifier)),
            ]
          else
            // idle / 过期：手动触发入口（单请求口径，不做自动搜索）。
            AppEmptyState(
              svgIcon: 'wifi',
              title: '贴吧在线搜索',
              message: query.isEmpty
                  ? '输入关键词后实时搜索贴吧（匿名接口，无需登录）'
                  : '在「${kDefaultForums.first}」内实时搜索 "$query"\n匿名接口 · 单请求手动触发 · ≥1.5s 节流',
              action: AppButton(
                label: query.isEmpty ? '请先输入关键词' : '搜索贴吧',
                kind: AppButtonKind.accent,
                onPressed: query.isEmpty ? null : () => notifier.search(query),
              ),
            ),
        ],
      ),
    );
  }
}

/// 在线结果排序行（P2-5）：相关度 = 接口返回原序 / 时间 = 客户端按 createTime 倒序稳定重排。
/// 样式复用本地筛选 chip 令牌（[CountChip] 选中态 accent），切换**不重新发请求**
/// ——取数固定 sm=0，口径见 search_state.dart 的 onlineSortProvider 段注释。
class _OnlineSortRow extends ConsumerWidget {
  const _OnlineSortRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSpacing s = AppSpacing.of(context);
    final OnlineSort sort = ref.watch(onlineSortProvider);
    void pick(OnlineSort v) => ref.read(onlineSortProvider.notifier).state = v;
    return Row(
      children: <Widget>[
        CountChip(
          label: onlineSortLabel(OnlineSort.relevance),
          selected: sort == OnlineSort.relevance,
          onTap: () => pick(OnlineSort.relevance),
        ),
        SizedBox(width: s.space2),
        CountChip(
          label: onlineSortLabel(OnlineSort.time),
          selected: sort == OnlineSort.time,
          onTap: () => pick(OnlineSort.time),
        ),
      ],
    );
  }
}

/// 在线错误态（分类文案；format → §8.12 降级矩阵「接口签名/协议变更」行）。
class _OnlineErrorState extends StatelessWidget {
  const _OnlineErrorState({required this.online, required this.query, required this.notifier});

  final OnlineSearchState online;
  final String query;
  final OnlineSearchNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final (String title, String message, String svgIcon) = switch (online.errorKind) {
      // §8.12：接口变更 → 「贴吧接口似乎已变更」+ 检查更新引导（离线核心不受影响）。
      OnlineErrorKind.format => (
          '贴吧接口似乎已变更',
          '在线接口返回结构与归档口径不符（${online.errorDetail}）。离线库检索不受影响；请检查 App 更新，或稍后再试。',
          'alert'
        ),
      OnlineErrorKind.rateLimited => (
          '触发贴吧风控',
          '匿名通道被限流（${online.errorDetail}）。请稍后再试，无需登录。',
          'clock'
        ),
      OnlineErrorKind.server => (
          '贴吧服务异常',
          online.errorDetail.isEmpty ? '请稍后再试' : online.errorDetail,
          'alert'
        ),
      _ => ('网络异常', '请检查网络连接后重试。', 'wifi'),
    };
    return AppEmptyState(
      title: title,
      message: message,
      svgIcon: svgIcon,
      action: AppButton(
        label: '重试',
        kind: AppButtonKind.outline,
        onPressed: () => notifier.search(query),
      ),
    );
  }
}

/// 在线列表页脚：加载更多（手动单请求）/ 加载中 / 追加失败重试；无后继页则隐藏。
class _OnlineFooter extends StatelessWidget {
  const _OnlineFooter({required this.online, required this.notifier});

  final OnlineSearchState online;
  final OnlineSearchNotifier notifier;

  @override
  Widget build(BuildContext context) {
    if (online.isAppending) {
      return const AppButton(label: '加载中…', kind: AppButtonKind.outline);
    }
    if (online.errorKind != OnlineErrorKind.none) {
      return AppButton(
        label: '加载失败，点击重试',
        kind: AppButtonKind.outline,
        onPressed: notifier.loadMore,
      );
    }
    if (online.hasMore) {
      return AppButton(
        label: '加载更多',
        kind: AppButtonKind.outline,
        onPressed: notifier.loadMore,
      );
    }
    return const SizedBox.shrink();
  }
}

/// 在线结果行（标题 + 吧名/作者/回复数/时间；整卡点击 = 进在线帖子页 /online/{tid}，
/// 右上角按钮 = 打开原帖外链，无可用应用时 SnackBar 告知）。
class _OnlineThreadCard extends StatelessWidget {
  const _OnlineThreadCard({super.key, required this.thread});

  final OnlineThread thread;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final String title = thread.title.isEmpty ? '（无标题）' : thread.title;
    return AccentCard(
      tone: SemanticTone.neutral,
      onTap: () => context.push('/online/${thread.tid}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(title,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: t.cardTitle.copyWith(color: c.text)),
              ),
              // 整卡点击已让位给进在线帖子页，「打开原帖」收敛到此显式按钮（避免功能丢失）。
              IconButton(
                tooltip: '打开原帖',
                visualDensity: VisualDensity.compact,
                icon: AppIcon('external', size: 16, color: c.textMuted),
                onPressed: () => openThreadLink(context, thread),
              ),
            ],
          ),
          SizedBox(height: s.space2),
          Row(
            children: <Widget>[
              if (thread.forumName.isNotEmpty) ...<Widget>[
                MetaChip(label: thread.forumName),
                SizedBox(width: s.space2),
              ],
              if (thread.author.isNotEmpty) ...<Widget>[
                Flexible(
                  child: Text(thread.author,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption.copyWith(color: c.textMuted)),
                ),
                SizedBox(width: s.space2),
              ],
              if (thread.replyNum > 0) ...<Widget>[
                Text('${thread.replyNum} 回复',
                    style: AppTypography.tabular(t.caption.copyWith(color: c.textMuted))),
                SizedBox(width: s.space2),
              ],
              const Spacer(),
              if (thread.createTime > 0)
                Text(formatOnlineDate(thread.createTime),
                    style: AppTypography.tabular(t.caption.copyWith(color: c.textMuted))),
            ],
          ),
        ],
      ),
    );
  }
}
