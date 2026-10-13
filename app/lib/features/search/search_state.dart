import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/repo/queries.dart';

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

  /// 输入联想 debounce（§5.3：200ms；输入时序参数，非动效 token）。
  static const Duration suggestDebounce = Duration(milliseconds: 200);

  void setQuery(String q) {
    state = state.copyWith(filter: state.filter.copyWith(query: q));
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
    _ref.read(suggestInputProvider.notifier).state = '';
    await _ref.read(queriesProvider).addHistory(state.filter);
  }

  void applyFilter(SearchFilter f, {bool submit = true}) {
    state = SearchDraft(filter: f, submitted: submit);
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
  }

  /// 清空五维（保留关键词与排序）。
  void clearDimensions() {
    final SearchFilter f = state.filter;
    state = SearchDraft(
      filter: SearchFilter(query: f.query, sort: f.sort),
      submitted: state.submitted,
    );
  }

  void toggleSort() {
    final SearchFilter next = state.filter.copyWith(
      sort: state.filter.sort == SearchSort.timeDesc ? SearchSort.timeAsc : SearchSort.timeDesc,
    );
    state = SearchDraft(filter: next, submitted: state.submitted);
  }

  /// 回到搜索台（清结果，保留草稿关键词）。
  void backToConsole() {
    state = state.copyWith(submitted: false);
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

final StreamProvider<List<SearchHistoryEntry>> searchHistoryProvider =
    StreamProvider<List<SearchHistoryEntry>>((Ref ref) => ref.watch(queriesProvider).watchHistory());

final FutureProvider<List<HotBook>> hotBooksProvider =
    FutureProvider<List<HotBook>>((Ref ref) => ref.watch(queriesProvider).hotBooks(limit: 12));
