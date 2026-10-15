import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../collector/scheduler.dart' show CollectFailureKind, CollectRequestException;
import '../../collector/tieba_search.dart';
import '../../core/constants.dart';
import '../../data/db/app_database.dart';
import '../../data/repo/collect_repository.dart' show kDefaultForums;
import '../../data/repo/queries.dart';
import '../../data/repo/queries_providers.dart';

// 搜索台状态（§5.3 六维草稿 + 联想 debounce + 历史 + 结果分页）。

/// 搜索草稿：六维条件 + 是否已提交（提交后才出结果区）。
class SearchDraft {
  const SearchDraft({this.filter = const SearchFilter(), this.submitted = false});

  final SearchFilter filter;
  final bool submitted;

  SearchDraft copyWith({SearchFilter? filter, bool? submitted}) =>
      SearchDraft(filter: filter ?? this.filter, submitted: submitted ?? this.submitted);
}

class SearchDraftNotifier extends StateNotifier<SearchDraft> {
  SearchDraftNotifier(this._ref) : super(const SearchDraft());

  final Ref _ref;
  Timer? _debounce;

  /// 草稿存储（build 期惰性取；widget 测试挂具下 FakeBookRepository 非 KV 端口 → null = 停用）。
  SearchDraftStore? _store;
  SearchDraftStore? get _draftStore =>
      _store ??= _ref.read(searchDraftStoreProvider);

  /// 是否已从 settings 恢复过（恢复只做一次）。
  bool _restored = false;

  /// 关 App 重开：从 settings 读回上次草稿（词 + 六维 + 排序 + 提交态）→ 结果区与浏览位置
  /// 记忆得以恢复。仅在有持久化端口、且尚未恢复时执行一次；无记录则保持空草稿。
  Future<void> restore() async {
    if (_restored) {
      return;
    }
    _restored = true;
    final SearchDraftStore? store = _draftStore;
    if (store == null) {
      return;
    }
    final SearchDraft? saved = await store.read();
    if (saved == null || !mounted) {
      return;
    }
    state = saved;
    if (saved.filter.query.isNotEmpty) {
      _ref.read(suggestInputProvider.notifier).state = '';
    }
  }

  /// 写回当前草稿（best-effort，不 await）。
  void _persist() {
    final SearchDraftStore? store = _draftStore;
    if (store == null) {
      return;
    }
    store.save(state);
  }

  /// 输入联想 debounce（§5.3：200ms；输入时序参数，非动效 token）。
  static const Duration suggestDebounce = Duration(milliseconds: 200);

  void setQuery(String q) {
    state = state.copyWith(filter: state.filter.copyWith(query: q));
    _persist();
    _debounce?.cancel();
    _debounce = Timer(suggestDebounce, () {
      if (mounted) {
        _ref.read(suggestInputProvider.notifier).state = q.trim();
      }
    });
  }

  /// 提交：出结果 + 写搜索历史（六维快照）。
  Future<void> submit() async {
    state = state.copyWith(submitted: true);
    _persist();
    _ref.read(suggestInputProvider.notifier).state = '';
    await _ref.read(queriesProvider).addHistory(state.filter);
  }

  void applyFilter(SearchFilter f, {bool submit = true}) {
    state = SearchDraft(filter: f, submitted: submit);
    _persist();
    if (submit) {
      _ref.read(suggestInputProvider.notifier).state = '';
      _ref.read(queriesProvider).addHistory(f);
    }
  }

  /// 点历史行 = 复现全部六维并直接出结果（§5.3）。
  void applyHistory(SearchHistoryEntry h) => applyFilter(SearchFilter.fromHistory(h));

  /// 设置单个维度值（null = 回「全部」）；已提交态即时刷新结果，不重复写历史。
  void setDimension(CategoryDim dim, String? value) {
    final SearchFilter f = state.filter;
    final SearchFilter next = switch (dim) {
      CategoryDim.year => f.copyWith(year: Value<String?>(value)),
      CategoryDim.month => f.copyWith(month: Value<String?>(value)),
      CategoryDim.tenDay => f.copyWith(tenDay: Value<String?>(value)),
      CategoryDim.channel => f.copyWith(channel: Value<String?>(value)),
      CategoryDim.category => f.copyWith(category: Value<String?>(value)),
    };
    state = SearchDraft(filter: next, submitted: state.submitted);
    _persist();
  }

  /// 清空五维（保留关键词与排序）。
  void clearDimensions() {
    final SearchFilter f = state.filter;
    state = SearchDraft(
      filter: SearchFilter(query: f.query, sort: f.sort),
      submitted: state.submitted,
    );
    _persist();
  }

  void toggleSort() {
    final SearchFilter next = state.filter.copyWith(
      sort: state.filter.sort == SearchSort.timeDesc ? SearchSort.timeAsc : SearchSort.timeDesc,
    );
    state = SearchDraft(filter: next, submitted: state.submitted);
    _persist();
  }

  /// 回到搜索台（清结果，保留草稿关键词）。
  void backToConsole() {
    state = state.copyWith(submitted: false);
    _persist();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final searchDraftProvider =
    StateNotifierProvider<SearchDraftNotifier, SearchDraft>((Ref ref) => SearchDraftNotifier(ref));

/// debounce 后的联想输入（'' = 不联想）。
final StateProvider<String> suggestInputProvider = StateProvider<String>((Ref ref) => '');

final suggestProvider = FutureProvider.autoDispose.family<List<String>, String>(
  (Ref ref, String prefix) => ref.watch(queriesProvider).suggestBooks(prefix),
);

/// 结果分页页数（每页 40，继承宝典分页默认值；本地库以更大 limit 重查即翻页）。
final StateProvider<int> resultPageProvider = StateProvider<int>((Ref ref) => 1);

final searchResultProvider = FutureProvider.autoDispose.family<SearchOutcome, SearchFilter>(
  (Ref ref, SearchFilter f) => ref.watch(queriesProvider).searchBooks(f),
);

/// 搜索页六维联动计数（§5.3）：随当前草稿条件变化，各维度候选值命中数实时联动。
final searchFilterCountsProvider = FutureProvider.autoDispose.family<CategoryCounts, SearchFilter>(
  (Ref ref, SearchFilter f) => ref.watch(queriesProvider).searchDimensionCounts(f),
);

// ── 搜索结果浏览位置记忆（C：关 App 重开仍在） ────────────────────────────────
//
// 键 = 「搜索词 + 六维筛选 + 排序」的稳定签名，值 = 结果列表滚动偏移（px）。
// 落 settings 表 KV（SettingsKeys.searchPositions，值 = JSON map，LRU 上限 32 条），
// 不新造表；读写走 Queries 的 SearchSettingsKv 端口（drift UPSERT）。

/// 条件签名。分页 limit/offset **不进**签名：同一条件翻到第几页仍是同一次浏览，
/// 恢复时由调用方把偏移夹到当前 maxScrollExtent（页数不同也不会跳飞）。
/// 分隔符用 \u0001 而非 '|'：搜索词本身可以含竖线，不能让条件串味。
String searchPositionSignature(SearchFilter f) => <String>[
      f.query,
      f.year ?? '',
      f.month ?? '',
      f.tenDay ?? '',
      f.channel ?? '',
      f.category ?? '',
      f.sort.wire,
    ].join('\u0001');

/// 浏览位置存储（纯 KV 读写 + LRU 裁剪；与 UI 解耦，plain test() 可直接断言）。
class SearchPositionStore {
  const SearchPositionStore(this._kv, {this.key = SettingsKeys.searchPositions});

  final SearchSettingsKv _kv;

  /// settings 键（结果列表位置 / 目录弹层位置共用同一实现，各自独立键）。
  final String key;

  /// LRU 上限（单条 settings 值的体积防线：32 条 ≈ 数 KB JSON）。
  static const int maxEntries = 32;

  /// 读某条件的偏移（无记录返回 null）。
  Future<double?> read(String signature) async => (await _readAll())[signature];

  /// 写某条件的偏移，并把它提到「最近使用」末尾；超出 [maxEntries] 淘汰最久未用者。
  Future<void> save(String signature, double offset) async {
    final Map<String, double> all = await _readAll();
    // Dart Map 保插入序、jsonEncode 也保序 → 「先删后插」即把键移到末尾，
    // map 顺序就是 LRU 新旧序（末尾 = 最近使用，首个 = 最久未用）。
    all.remove(signature);
    all[signature] = offset;
    while (all.length > maxEntries) {
      all.remove(all.keys.first);
    }
    await _kv.writeSetting(key, jsonEncode(all));
  }

  Future<Map<String, double>> _readAll() async {
    final String? raw = await _kv.readSetting(key);
    if (raw == null || raw.isEmpty) {
      return <String, double>{};
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, double>{};
      }
      return <String, double>{
        for (final MapEntry<Object?, Object?> e in decoded.entries)
          if (e.key is String && e.value is num) e.key! as String: (e.value! as num).toDouble(),
      };
    } on FormatException {
      // 脏数据（旧版本残留 / 手工改库）不阻断搜索页：一律回落「无记忆」。
      return <String, double>{};
    }
  }
}

/// 浏览位置存储注入点：queriesProvider 的实现带 settings KV（生产 = Queries）才有；
/// widget 测试注入的内存仓不带 → null，位置记忆自动停用（也就不可能在
/// FakeAsync 假时钟区里碰真实库，见 app/test/TESTING.md §1）。
final Provider<SearchPositionStore?> searchPositionStoreProvider = Provider<SearchPositionStore?>((Ref ref) {
  // 用 Object 承接：BookRepository 与 SearchSettingsKv 互不为子类型，而 Dart 没有交叉类型，
  // 声明成 BookRepository 的话下面的 is 判定不会触发类型提升。
  final Object repo = ref.watch(queriesProvider);
  return repo is SearchSettingsKv ? SearchPositionStore(repo) : null;
});

/// 目录弹层浏览位置存储注入点（与结果列表位置同实现、独立 settings 键）。
final Provider<SearchPositionStore?> searchTocPositionStoreProvider = Provider<SearchPositionStore?>((Ref ref) {
  final Object repo = ref.watch(queriesProvider);
  return repo is SearchSettingsKv
      ? SearchPositionStore(repo, key: SettingsKeys.searchTocPositions)
      : null;
});

/// 搜索草稿持久化（关 App 重开恢复词 + 六维 + 排序 + 提交态）。
///
/// 值 = JSON：`{q, year, month, ten, channel, category, sort, submitted}`（前七项即
/// [SearchFilter.toUriParams]），脏数据/缺字段一律回落空草稿，不阻断搜索页。
class SearchDraftStore {
  const SearchDraftStore(this._kv);

  final SearchSettingsKv _kv;

  Future<SearchDraft?> read() async {
    final String? raw = await _kv.readSetting(SettingsKeys.searchDraft);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final Map<String, String> params = <String, String>{
        for (final MapEntry<Object?, Object?> e in decoded.entries)
          if (e.key is String && e.value is String) e.key! as String: e.value! as String,
      };
      final bool submitted = decoded['submitted'] == '1';
      return SearchDraft(filter: SearchFilter.fromUriParams(params), submitted: submitted);
    } on FormatException {
      return null;
    }
  }

  Future<void> save(SearchDraft draft) async {
    final Map<String, String> map = draft.filter.toUriParams()
      ..['submitted'] = draft.submitted ? '1' : '0';
    await _kv.writeSetting(SettingsKeys.searchDraft, jsonEncode(map));
  }
}

/// 草稿存储注入点（同 [searchPositionStoreProvider]：非 KV 端口 → null = 停用）。
final Provider<SearchDraftStore?> searchDraftStoreProvider = Provider<SearchDraftStore?>((Ref ref) {
  final Object repo = ref.watch(queriesProvider);
  return repo is SearchSettingsKv ? SearchDraftStore(repo) : null;
});

final StreamProvider<List<SearchHistoryEntry>> searchHistoryProvider =
    StreamProvider<List<SearchHistoryEntry>>((Ref ref) => ref.watch(queriesProvider).watchHistory());

final FutureProvider<List<HotBook>> hotBooksProvider =
    FutureProvider<List<HotBook>>((Ref ref) => ref.watch(queriesProvider).hotBooks(limit: 12));

// ── 贴吧在线搜索（P2-2：c/s/searchpost 匿名 app-form 通道，§8.2/§8.4） ──────

/// 在线搜索客户端注入点：生产 = 真实 dio + 1.5~3.0s 节流；
/// 测试 `overrideWithValue(TiebaSearchClient(dio: mock, minIntervalMs: 0, …))`
/// （mock dio adapter 脚本化 JSON/错误，零真实网络，TESTING.md §1）。
final Provider<TiebaSearchClient> tiebaSearchClientProvider =
    Provider<TiebaSearchClient>((Ref ref) {
  final TiebaSearchClient client = TiebaSearchClient();
  ref.onDispose(client.close);
  return client;
});

/// 搜索来源 Tab：本地库（默认）/ 贴吧在线（§5.3 空态入口 + P2-2 双 Tab）。
enum SearchTab { local, online }

/// autoDispose：离开搜索页即回本地 Tab 默认（在线结果 state 独立保留，切回即见）。
final searchTabProvider = StateProvider.autoDispose<SearchTab>((Ref ref) => SearchTab.local);

/// 在线搜索阶段。
enum OnlineStatus { idle, loading, ready, error }

/// 在线错误分类（决定错误态文案；format → §8.12「贴吧接口似乎已变更」降级文案）。
enum OnlineErrorKind { none, format, rateLimited, server, network }

/// 在线搜索状态（单请求手动触发口径：一次 search/loadMore = 一个 searchpost 请求）。
class OnlineSearchState {
  const OnlineSearchState({
    this.status = OnlineStatus.idle,
    this.query = '',
    this.threads = const <OnlineThread>[],
    this.hasMore = false,
    this.page = 0,
    this.errorKind = OnlineErrorKind.none,
    this.errorDetail = '',
  });

  final OnlineStatus status;

  /// 产出当前结果的搜索词（≠ 当前输入词 → UI 按过期处理，回手动触发入口）。
  final String query;
  final List<OnlineThread> threads;
  final bool hasMore;

  /// 已成功加载的最高页码（loadMore 下一页 = page+1；0 = 尚无成功页）。
  final int page;

  final OnlineErrorKind errorKind;
  final String errorDetail;

  /// 追加加载在途（列表保持可见，页脚转「加载中」）。
  bool get isAppending => status == OnlineStatus.loading && page > 0;

  OnlineSearchState copyWith({
    OnlineStatus? status,
    String? query,
    List<OnlineThread>? threads,
    bool? hasMore,
    int? page,
    OnlineErrorKind? errorKind,
    String? errorDetail,
  }) =>
      OnlineSearchState(
        status: status ?? this.status,
        query: query ?? this.query,
        threads: threads ?? this.threads,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        errorKind: errorKind ?? this.errorKind,
        errorDetail: errorDetail ?? this.errorDetail,
      );
}

/// CollectRequestException.kind → UI 错误分类（频控口径复用 collector 语义分档）。
OnlineErrorKind onlineErrorKindOf(CollectRequestException e) => switch (e.kind) {
      CollectFailureKind.rateLimited => OnlineErrorKind.rateLimited,
      CollectFailureKind.serverError => OnlineErrorKind.server,
      CollectFailureKind.network => OnlineErrorKind.network,
    };

class OnlineSearchNotifier extends StateNotifier<OnlineSearchState> {
  OnlineSearchNotifier(this._ref) : super(const OnlineSearchState());

  final Ref _ref;

  /// 手动触发一次在线搜索（pn=1 重置结果；空词/在途忽略）。
  Future<void> search(String query, {String? forum}) async {
    final String q = query.trim();
    if (q.isEmpty || state.status == OnlineStatus.loading) {
      return;
    }
    state = OnlineSearchState(status: OnlineStatus.loading, query: q);
    await _run(q, forum, pn: 1, append: false);
  }

  /// 手动加载下一页（追加；仅在 hasMore 且非在途时可用）。
  Future<void> loadMore({String? forum}) async {
    final OnlineSearchState cur = state;
    if (cur.status == OnlineStatus.loading || !cur.hasMore || cur.page < 1) {
      return;
    }
    state = cur.copyWith(status: OnlineStatus.loading, errorKind: OnlineErrorKind.none, errorDetail: '');
    await _run(cur.query, forum, pn: cur.page + 1, append: true);
  }

  Future<void> _run(String q, String? forum, {required int pn, required bool append}) async {
    try {
      // only_thread=1：仅主题帖（行 = 帖子粒度，点行复制原帖链接语义干净）。
      // sm 固定取默认 0（接口原序）：排序一律客户端重排，口径见 onlineSortProvider 注释。
      final OnlineSearchPage page = await _ref
          .read(tiebaSearchClientProvider)
          .search(forum ?? kDefaultForums.first, q, pn: pn, rn: 30, onlyThread: true);
      if (!mounted) return;
      final List<OnlineThread> merged =
          append ? <OnlineThread>[...state.threads, ...page.threads] : page.threads;
      state = OnlineSearchState(
        status: OnlineStatus.ready,
        query: q,
        threads: _dedupByTid(merged),
        hasMore: page.hasMore,
        page: pn,
      );
    } catch (e) {
      if (!mounted) return;
      OnlineErrorKind kind = OnlineErrorKind.network;
      String detail = '$e';
      if (e is TiebaSearchFormatException) {
        kind = OnlineErrorKind.format;
        detail = e.detail;
      } else if (e is CollectRequestException) {
        kind = onlineErrorKindOf(e);
        detail = e.message;
      }
      if (append) {
        // 追加失败：保住已加载列表，仅记错误（页脚按钮转「重试」）。
        state = state.copyWith(errorKind: kind, errorDetail: detail);
      } else {
        state = OnlineSearchState(status: OnlineStatus.error, query: q, errorKind: kind, errorDetail: detail);
      }
    }
  }

  /// 主题帖粒度按 tid 去重（跨页重复命中防线）。
  static List<OnlineThread> _dedupByTid(List<OnlineThread> items) {
    final Set<int> seen = <int>{};
    return items.where((OnlineThread t) => seen.add(t.tid)).toList();
  }
}

final StateNotifierProvider<OnlineSearchNotifier, OnlineSearchState> onlineSearchProvider =
    StateNotifierProvider<OnlineSearchNotifier, OnlineSearchState>(
        (Ref ref) => OnlineSearchNotifier(ref));

// ── 贴吧在线结果排序（客户端重排，切换不重新发请求） ────────────────────────
//
// 接口侧核对结论：`c/s/searchpost` **原生支持**排序参数 `sm`
// （aiotieba commit a5472be `src/aiotieba/enums.py SearchInForumType`：0=ALL 全部 /
// 1=TIME app 时间倒序 / 2=RELATION app 相关性排序；`api/search_in_forum/_api.py:26-45`
// 把它作为表单参数 `sm` 传出；归档 tieba-api-catalog/API-CATALOG.md:1570 标注该接口
// 「可匿名 · 风险 low」，匿名通道可用）。客户端侧已透出为
// `TiebaSearchClient.search(sm:)` / `ForumSearchSort`（collector/tieba_search.dart:54-63）。
//
// 但 UI 的排序切换按产品口径**不重新发请求**（单请求手动触发 + 匿名通道频控 §8.11），
// 而一旦按 sm=1 取回时间序，本地就无法还原「相关度原序」——两档语义会互相污染。
// 故取数固定 sm=0（接口原序 = 相关度基线），两档排序一律客户端重排**已加载**结果：
// 相关度 = 接口返回原序；时间 = 按 createTime 倒序稳定排序（见 [sortOnlineThreads]）。

/// 在线结果排序档。
enum OnlineSort { relevance, time }

/// 排序档中文标签（在线排序行 chip 文案）。
String onlineSortLabel(OnlineSort sort) => switch (sort) {
      OnlineSort.relevance => '相关度',
      OnlineSort.time => '时间',
    };

/// 在线结果排序选择（非 autoDispose：本地/在线 Tab 来回切换保持用户选择）。
final StateProvider<OnlineSort> onlineSortProvider =
    StateProvider<OnlineSort>((Ref ref) => OnlineSort.relevance);

/// 在线结果客户端重排（口径见本段文件注释）。
///
/// 「时间」= 按 [OnlineThread.createTime] 倒序**稳定**排序：Dart `List.sort` 不保证稳定，
/// 故以原序 index 做 tie-break —— 同时间与无时间（createTime=0，服务端未携带）的行
/// 保持接口原序，无时间行自然沉底。「相关度」= 原样返回接口序（同一 List 实例，不复制）。
List<OnlineThread> sortOnlineThreads(List<OnlineThread> threads, OnlineSort sort) {
  if (sort != OnlineSort.time || threads.length < 2) {
    return threads;
  }
  final List<int> order = List<int>.generate(threads.length, (int i) => i)
    ..sort((int a, int b) {
      final int byTime = threads[b].createTime.compareTo(threads[a].createTime);
      return byTime != 0 ? byTime : a.compareTo(b);
    });
  return <OnlineThread>[for (final int i in order) threads[i]];
}
