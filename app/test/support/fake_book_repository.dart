import 'dart:async';
import 'dart:math';

import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/queries.dart';

import 'demo_data.dart';

// widget 测试专用**纯内存** BookRepository 实现。
//
// 铁律（app/test/TESTING.md §1）：本文件不得出现 dart:io、Isolate、ReceivePort、
// 平台通道、Timer/延时 —— 只允许微任务级 async。原因：testWidgets 跑在 FakeAsync
// 假时钟区，真实事件循环上的回调永不返回；且 flutter_test 的超时也记在假时钟上 →
// 假时间不前进 → 超时永不触发 → 无限挂死。
//
// 语义与 Queries（drift 实现）逐条对齐；drift 侧的正确性由 plain test() 对
// test/fixtures/dev_seed.db 断言（features_test.dart「queries 数据层」组）。

/// 可观察的内存「表」：当前值 + 广播流（等价 drift `.watch()` 语义）。
class _Live<T> {
  _Live(this._value);

  T _value;
  final StreamController<T> _ctrl = StreamController<T>.broadcast();

  T get value => _value;

  set value(T next) {
    _value = next;
    if (!_ctrl.isClosed) {
      _ctrl.add(next);
    }
  }

  /// 首次监听即吐当前值，之后随写入更新（无 Timer，FakeAsync 可正常冲刷）。
  Stream<T> get stream async* {
    yield _value;
    yield* _ctrl.stream;
  }
}

/// 内存语料。
class FakeLibrary {
  FakeLibrary({
    required this.posts,
    required this.floors,
    required this.entries,
    required this.groups,
    this.newContentCount = 0,
  });

  final List<Post> posts;

  /// postId → 楼层。测试语料一律**无图**，避免 CachedNetworkImage 触发真实网络/磁盘缓存。
  final Map<int, List<FloorData>> floors;
  final List<EntryRow> entries;
  final List<BookGroup> groups;
  final int newContentCount;

  BookGroup? groupOfName(String nameNorm) {
    for (final BookGroup g in groups) {
      if (g.nameNorm == nameNorm) {
        return g;
      }
    }
    return null;
  }
}

/// 纯内存 BookRepository（widget 测试注入 queriesProvider 用）。
class FakeBookRepository implements BookRepository {
  FakeBookRepository({FakeLibrary? library, int seed = 20261013})
    : lib = library ?? _fallback,
      _random = Random(seed),
      _newContent = _Live<int>((library ?? _fallback).newContentCount);

  static final FakeLibrary _fallback = demoLibrary();

  final FakeLibrary lib;
  final Random _random;

  final _Live<int> _newContent;
  final _Live<List<SearchHistoryEntry>> _history =
      _Live<List<SearchHistoryEntry>>(const <SearchHistoryEntry>[]);
  final _Live<List<Bookmark>> _bookmarks = _Live<List<Bookmark>>(
    const <Bookmark>[],
  );
  final _Live<List<Favorite>> _favorites = _Live<List<Favorite>>(
    const <Favorite>[],
  );

  int _nextId = 1;

  // ── 测试直接读内存态（不必绕流）──
  List<SearchHistoryEntry> get history => _history.value;
  List<Bookmark> get bookmarks => _bookmarks.value;
  List<Favorite> get favorites => _favorites.value;

  /// 调用计数（可断言「点了就查了一次」）。
  final Map<String, int> calls = <String, int>{};

  void _hit(String name) => calls[name] = (calls[name] ?? 0) + 1;

  // ───────────────────────── 首页 ─────────────────────────

  @override
  Future<List<PostCardData>> timelinePosts({
    required int limit,
    int offset = 0,
  }) async {
    _hit('timelinePosts');
    final List<Post> posts =
        lib.posts
            .where(
              (Post p) =>
                  p.date != null &&
                  (p.postKind == CategoryKind.scan ||
                      p.postKind == CategoryKind.avoid),
            )
            .toList()
          ..sort((Post a, Post b) {
            final int c = b.date!.compareTo(a.date!);
            return c != 0 ? c : b.id.compareTo(a.id);
          });
    return <PostCardData>[
      for (final Post p in posts.skip(offset).take(limit))
        PostCardData(
          post: p,
          books: _chipsOf(p.id),
          entryCount: lib.entries
              .where((EntryRow e) => e.postRef == p.id)
              .length,
          summary: _summaryOf(p.id),
        ),
    ];
  }

  List<BookChip> _chipsOf(int postId) {
    final List<BookChip> out = <BookChip>[];
    for (final EntryRow e in lib.entries.where(
      (EntryRow e) => e.postRef == postId,
    )) {
      if (out.length >= 4) {
        break;
      }
      out.add(
        BookChip(
          name: e.name,
          nameNorm: e.nameNorm,
          bookGroupId: e.bookGroupId,
        ),
      );
    }
    return out;
  }

  String? _summaryOf(int postId) {
    for (final EntryRow e in lib.entries.where(
      (EntryRow e) => e.postRef == postId,
    )) {
      final String? c = summarizeCardText(e.comment);
      if (c != null) {
        return c;
      }
    }
    // 无条目帖 → 回落该帖正文最长楼层（与 Queries.timelinePosts 同口径）。
    final List<FloorData> floors = lib.floors[postId] ?? const <FloorData>[];
    String? best;
    for (final FloorData f in floors) {
      final String t = f.floor.content.trim();
      if (t.isNotEmpty && (best == null || t.length > best.length)) {
        best = t;
      }
    }
    return summarizeCardText(best);
  }

  @override
  Stream<int> watchNewContentCount() => _newContent.stream;

  @override
  Future<List<RankRow>> rankRows(
    RankWindow window, {
    DateTime? today,
    int limit = 10,
  }) async {
    _hit('rankRows:$window');
    // 时段下限复用生产实现（纯函数，无 IO）。
    final String? from = Queries.rankFromDate(
      window,
      today ?? DateTime(2025, 4, 30),
    );
    final Map<String, List<EntryRow>> byName = <String, List<EntryRow>>{};
    for (final EntryRow e in lib.entries) {
      if (e.date == null) {
        continue;
      }
      if (from != null && e.date!.compareTo(from) < 0) {
        continue;
      }
      byName.putIfAbsent(e.nameNorm, () => <EntryRow>[]).add(e);
    }
    final List<MapEntry<String, List<EntryRow>>> sorted =
        byName.entries.toList()..sort((
          MapEntry<String, List<EntryRow>> a,
          MapEntry<String, List<EntryRow>> b,
        ) {
          final int c = b.value.length.compareTo(a.value.length);
          return c != 0 ? c : a.key.compareTo(b.key);
        });
    return <RankRow>[
      for (final MapEntry<String, List<EntryRow>> e in sorted.take(limit))
        RankRow(
          nameNorm: e.key,
          name: lib.groupOfName(e.key)?.nameDisplay ?? e.key,
          author: lib.groupOfName(e.key)?.authorDisplay,
          count: e.value.length,
          bookGroupId: lib.groupOfName(e.key)?.id,
        ),
    ];
  }

  @override
  Future<List<RankRow>> wordRankRows(
    RankWindow window, {
    DateTime? today,
    int limit = 10,
  }) async {
    _hit('wordRankRows:$window');
    final String? from = Queries.rankFromDate(
      window,
      today ?? DateTime(2025, 4, 30),
    );
    final Map<String, List<EntryRow>> byName = <String, List<EntryRow>>{};
    for (final EntryRow e in lib.entries) {
      // 字数榜口径（§5.13）：word_count 非空的库B子集，时段过滤同 rankRows。
      if (e.wordCount == null || e.date == null) {
        continue;
      }
      if (from != null && e.date!.compareTo(from) < 0) {
        continue;
      }
      byName.putIfAbsent(e.nameNorm, () => <EntryRow>[]).add(e);
    }
    int maxWords(List<EntryRow> rows) =>
        rows.map((EntryRow e) => e.wordCount!).reduce(max);
    final List<MapEntry<String, List<EntryRow>>> sorted =
        byName.entries.toList()..sort((
          MapEntry<String, List<EntryRow>> a,
          MapEntry<String, List<EntryRow>> b,
        ) {
          final int c = maxWords(b.value).compareTo(maxWords(a.value));
          return c != 0 ? c : a.key.compareTo(b.key);
        });
    return <RankRow>[
      for (final MapEntry<String, List<EntryRow>> e in sorted.take(limit))
        RankRow(
          nameNorm: e.key,
          name: lib.groupOfName(e.key)?.nameDisplay ?? e.key,
          author: lib.groupOfName(e.key)?.authorDisplay,
          count: maxWords(e.value),
          bookGroupId: lib.groupOfName(e.key)?.id,
        ),
    ];
  }

  @override
  Future<String?> dataCutoff() async {
    String? max;
    for (final EntryRow e in lib.entries) {
      if (e.date != null && (max == null || e.date!.compareTo(max) > 0)) {
        max = e.date;
      }
    }
    return max;
  }

  @override
  Future<List<EntryRow>> randomBooks(int count) async {
    _hit('randomBooks');
    final List<EntryRow> pool =
        lib.entries
            .where(
              (EntryRow e) =>
                  e.category == CategoryKind.scan &&
                  (e.comment?.length ?? 0) >= 20,
            )
            .toList()
          ..shuffle(_random);
    return pool.take(count).toList();
  }

  // ───────────────────────── 分类页五维 ─────────────────────────

  @override
  Future<CategoryCounts> dimensionCounts() async {
    _hit('dimensionCounts');
    final Map<String, int> years = <String, int>{};
    final Map<String, int> months = <String, int>{};
    final Map<String, int> tenDays = <String, int>{};
    final Map<String, int> channels = <String, int>{};
    final Map<String, int> categories = <String, int>{};
    for (final EntryRow e in lib.entries) {
      categories[e.category] = (categories[e.category] ?? 0) + 1;
      final String? d = e.date;
      if (d == null || d.length < 10) {
        continue;
      }
      final int y = int.tryParse(d.substring(0, 4)) ?? 0;
      final String yKey = y <= YearFilter.earlyMaxYear
          ? YearFilter.early
          : '$y';
      years[yKey] = (years[yKey] ?? 0) + 1;
      months[d.substring(5, 7)] = (months[d.substring(5, 7)] ?? 0) + 1;
      tenDays[_tenDayOf(d)] = (tenDays[_tenDayOf(d)] ?? 0) + 1;
      final String ch = ChannelFilter.otherBigMembers.contains(e.channel)
          ? ChannelFilter.otherBig
          : e.channel;
      channels[ch] = (channels[ch] ?? 0) + 1;
    }
    final List<String> yearKeys = years.keys.toList()
      ..sort((String a, String b) => b.compareTo(a));
    return CategoryCounts(
      total: lib.entries.length,
      years: <DimCount>[
        for (final String k in yearKeys)
          DimCount(value: k, label: yearLabel(k), count: years[k]!),
      ],
      months: <DimCount>[
        for (int m = 1; m <= 12; m++)
          DimCount(
            value: '$m',
            label: '$m月',
            count: months[m.toString().padLeft(2, '0')] ?? 0,
          ),
      ],
      tenDays: <DimCount>[
        DimCount(
          value: TenDayFilter.upper,
          label: '上旬',
          count: tenDays[TenDayFilter.upper] ?? 0,
        ),
        DimCount(
          value: TenDayFilter.middle,
          label: '中旬',
          count: tenDays[TenDayFilter.middle] ?? 0,
        ),
        DimCount(
          value: TenDayFilter.lower,
          label: '下旬',
          count: tenDays[TenDayFilter.lower] ?? 0,
        ),
      ],
      channels: <DimCount>[
        for (final String ch in ChannelFilter.categoryNamed)
          DimCount(value: ch, label: ch, count: channels[ch] ?? 0),
        DimCount(
          value: ChannelFilter.otherBig,
          label: '其他',
          count: channels[ChannelFilter.otherBig] ?? 0,
        ),
      ],
      categories: <DimCount>[
        for (final String k in CategoryKind.all)
          DimCount(value: k, label: k, count: categories[k] ?? 0),
      ],
    );
  }

  @override
  Future<CategoryCounts> searchDimensionCounts(SearchFilter f) async {
    _hit('searchDimensionCounts');
    // 联动口径（与 Queries.searchDimensionCounts 对齐）：每个维度用「除自身外」的
    // 已选条件过滤后统计。基线 = 应用全部条件的条目集；某维计数时把该维条件撇开。
    CategoryCounts countsExcluding(CategoryDim except) {
      final List<EntryRow> base = lib.entries
          .where(
            (EntryRow e) => _matchDims(
              e,
              year: except == CategoryDim.year ? null : f.year,
              month: except == CategoryDim.month ? null : f.month,
              tenDay: except == CategoryDim.tenDay ? null : f.tenDay,
              channel: except == CategoryDim.channel ? null : f.channel,
              category: except == CategoryDim.category ? null : f.category,
            ),
          )
          .toList();
      final Map<String, int> years = <String, int>{};
      final Map<String, int> months = <String, int>{};
      final Map<String, int> tenDays = <String, int>{};
      final Map<String, int> channels = <String, int>{};
      final Map<String, int> categories = <String, int>{};
      for (final EntryRow e in base) {
        categories[e.category] = (categories[e.category] ?? 0) + 1;
        final String? d = e.date;
        if (d == null || d.length < 10) {
          continue;
        }
        final int y = int.tryParse(d.substring(0, 4)) ?? 0;
        final String yKey = y <= YearFilter.earlyMaxYear ? YearFilter.early : '$y';
        years[yKey] = (years[yKey] ?? 0) + 1;
        months[d.substring(5, 7)] = (months[d.substring(5, 7)] ?? 0) + 1;
        tenDays[_tenDayOf(d)] = (tenDays[_tenDayOf(d)] ?? 0) + 1;
        final String ch = ChannelFilter.otherBigMembers.contains(e.channel)
            ? ChannelFilter.otherBig
            : e.channel;
        channels[ch] = (channels[ch] ?? 0) + 1;
      }
      final List<String> yearKeys = years.keys.toList()
        ..sort((String a, String b) => b.compareTo(a));
      return CategoryCounts(
        total: base.length,
        years: <DimCount>[
          for (final String k in yearKeys)
            DimCount(value: k, label: yearLabel(k), count: years[k]!),
        ],
        months: <DimCount>[
          for (int m = 1; m <= 12; m++)
            DimCount(value: '$m', label: '$m月', count: months[m.toString().padLeft(2, '0')] ?? 0),
        ],
        tenDays: <DimCount>[
          DimCount(value: TenDayFilter.upper, label: '上旬', count: tenDays[TenDayFilter.upper] ?? 0),
          DimCount(value: TenDayFilter.middle, label: '中旬', count: tenDays[TenDayFilter.middle] ?? 0),
          DimCount(value: TenDayFilter.lower, label: '下旬', count: tenDays[TenDayFilter.lower] ?? 0),
        ],
        channels: <DimCount>[
          for (final String ch in ChannelFilter.categoryNamed)
            DimCount(value: ch, label: ch, count: channels[ch] ?? 0),
          DimCount(value: ChannelFilter.otherBig, label: '其他', count: channels[ChannelFilter.otherBig] ?? 0),
        ],
        categories: <DimCount>[
          for (final String k in CategoryKind.all)
            DimCount(value: k, label: k, count: categories[k] ?? 0),
        ],
      );
    }
    // 每个维度单独算一次（撇开该维自身），再组装。
    final CategoryCounts yearC = countsExcluding(CategoryDim.year);
    final CategoryCounts monthC = countsExcluding(CategoryDim.month);
    final CategoryCounts tenC = countsExcluding(CategoryDim.tenDay);
    final CategoryCounts chanC = countsExcluding(CategoryDim.channel);
    final CategoryCounts catC = countsExcluding(CategoryDim.category);
    return CategoryCounts(
      total: catC.total,
      years: yearC.years,
      months: monthC.months,
      tenDays: tenC.tenDays,
      channels: chanC.channels,
      categories: catC.categories,
    );
  }

  static String _tenDayOf(String isoDate) {
    final int day = int.tryParse(isoDate.substring(8, 10)) ?? 0;
    if (day <= 10) {
      return TenDayFilter.upper;
    }
    return day <= 20 ? TenDayFilter.middle : TenDayFilter.lower;
  }

  bool _matchChannel(EntryRow e, String? channel) {
    if (channel == null) {
      return true;
    }
    if (channel == ChannelFilter.otherBig) {
      return ChannelFilter.otherBigMembers.contains(e.channel);
    }
    if (channel == ChannelFilter.collected) {
      return e.origin == 'collected';
    }
    return e.channel == channel;
  }

  bool _matchDims(
    EntryRow e, {
    String? year,
    String? month,
    String? tenDay,
    String? channel,
    String? category,
  }) {
    final String? d = e.date;
    if (year != null) {
      if (d == null) {
        return false;
      }
      if (year == YearFilter.early) {
        if ((int.tryParse(d.substring(0, 4)) ?? 0) > YearFilter.earlyMaxYear) {
          return false;
        }
      } else if (!d.startsWith(year)) {
        return false;
      }
    }
    if (month != null &&
        (d == null || d.substring(5, 7) != month.padLeft(2, '0'))) {
      return false;
    }
    if (tenDay != null && (d == null || _tenDayOf(d) != tenDay)) {
      return false;
    }
    if (!_matchChannel(e, channel)) {
      return false;
    }
    return category == null || e.category == category;
  }

  @override
  Future<CategoryPreview> categoryPreview(
    CategorySelection sel, {
    int limit = 5,
  }) async {
    _hit('categoryPreview');
    final List<EntryRow> hits = _byDims(
      sel.year,
      sel.month,
      sel.tenDay,
      sel.channel,
      sel.category,
    );
    return CategoryPreview(
      count: hits.length,
      entries: hits.take(limit).toList(),
    );
  }

  List<EntryRow> _byDims(
    String? year,
    String? month,
    String? tenDay,
    String? channel,
    String? category,
  ) {
    return lib.entries
        .where(
          (EntryRow e) => _matchDims(
            e,
            year: year,
            month: month,
            tenDay: tenDay,
            channel: channel,
            category: category,
          ),
        )
        .toList()
      ..sort(
        (EntryRow a, EntryRow b) => (b.date ?? '').compareTo(a.date ?? ''),
      );
  }

  // ───────────────────────── 搜索 ─────────────────────────

  @override
  Future<SearchOutcome> searchBooks(SearchFilter f) async {
    _hit('searchBooks');
    final List<String> words = tokenizeQuery(f.query);
    // §7.3：全部词 ≥3 字走 FTS；出现 2 字词则 LIKE 兜底（degraded 仅指 FTS 异常降级）。
    final bool fts =
        words.isNotEmpty && words.every((String w) => w.length >= 3);
    List<EntryRow> hits = _byDims(
      f.year,
      f.month,
      f.tenDay,
      f.channel,
      f.category,
    );
    // 两级检索（与 Queries.searchBooks 对齐）：第一级仅书名/作者列，有命中即收口；
    // 零命中才放开到含 recommender/comment 的第二级。comment 是整层楼共用的正文，
    // 参与第一级会把同楼其它书一并带出（仅 comment 命中的书不得混进第一级结果）。
    bool titleLevel = false;
    if (words.isNotEmpty) {
      final List<EntryRow> titleHits = hits
          .where((EntryRow e) => _allWordsHit(words, _titleHay(e)))
          .toList();
      if (titleHits.isNotEmpty) {
        hits = titleHits;
        titleLevel = true;
      } else {
        hits = hits
            .where((EntryRow e) => _allWordsHit(words, _fullHay(e)))
            .toList();
      }
    }

    // 书级聚合（book_group 粒度；无组的散条目按 nameNorm 独立成组）。
    final Map<String, List<EntryRow>> grouped = <String, List<EntryRow>>{};
    for (final EntryRow e in hits) {
      grouped.putIfAbsent(e.nameNorm, () => <EntryRow>[]).add(e);
    }
    final List<GroupHit> items = <GroupHit>[
      for (final MapEntry<String, List<EntryRow>> g in grouped.entries)
        _groupHit(g.key, g.value, words, titleLevel: titleLevel),
    ];
    if (f.sort == SearchSort.timeAsc) {
      items.sort(
        (GroupHit a, GroupHit b) =>
            (a.latestDate ?? '').compareTo(b.latestDate ?? ''),
      );
    } else {
      items.sort(
        (GroupHit a, GroupHit b) =>
            (b.latestDate ?? '').compareTo(a.latestDate ?? ''),
      );
    }
    final List<GroupHit> page = items.skip(f.offset).take(f.limit).toList();
    return SearchOutcome(
      page: Paged<GroupHit>(
        items: page,
        total: items.length,
        limit: f.limit,
        offset: f.offset,
      ),
      usedFts: fts,
      words: words,
    );
  }

  static bool _allWordsHit(List<String> words, String hay) =>
      words.every((String w) => hay.contains(w.toLowerCase()));

  /// 第一级匹配域：书名/作者（drift 侧为 name/name_norm/author/author_norm 四列；
  /// EntryRow 未投影 author_norm，作者归一化命中在此从简）。
  static String _titleHay(EntryRow e) =>
      <String?>[e.name, e.nameNorm, e.author]
          .whereType<String>()
          .join('\u0000')
          .toLowerCase();

  /// 第二级匹配域：第一级各列 + recommender/comment（现状全列口径）。
  static String _fullHay(EntryRow e) =>
      <String?>[e.name, e.nameNorm, e.author, e.recommender, e.comment]
          .whereType<String>()
          .join('\u0000')
          .toLowerCase();

  /// 书名锚点候选（与 queries.dart 私有 _nameAnchors 同口径）：带/不带书名号两种写法。
  static List<String> _nameAnchors(Iterable<String?> names) {
    final List<String> out = <String>[];
    for (final String? raw in names) {
      if (raw == null) {
        continue;
      }
      final String bare = raw.replaceAll(RegExp(r'[《》〈〉]'), '').trim();
      if (bare.isEmpty) {
        continue;
      }
      out
        ..add('《$bare》')
        ..add(bare);
    }
    return out;
  }

  GroupHit _groupHit(
    String nameNorm,
    List<EntryRow> rows,
    List<String> words, {
    bool titleLevel = false,
  }) {
    final BookGroup? g = lib.groupOfName(nameNorm);
    int bestFlag = 0;
    int bestEntryId = rows.first.id;
    String? latest;
    final Set<String> channels = <String>{};
    for (final EntryRow e in rows) {
      final int flag = e.recommendFlag;
      if (flag.abs() > bestFlag.abs()) {
        bestFlag = flag;
        bestEntryId = e.id;
      }
      if (e.date != null && (latest == null || e.date!.compareTo(latest) > 0)) {
        latest = e.date;
      }
      channels.add(e.channel);
    }
    // 推荐/排雷 = 该书**全部**条目真实计数（生产口径见 Queries._groupedPage），
    // 而非本次命中的条目数（否则一本书实际有 N 条推荐会被显示成 1）。
    int rec = 0, avoid = 0;
    for (final EntryRow e in lib.entries.where(
      (EntryRow e) => e.nameNorm == nameNorm,
    )) {
      final int flag = e.recommendFlag;
      if (flag > 0) {
        rec++;
      } else if (flag < 0) {
        avoid++;
      }
    }
    final EntryRow best = rows.firstWhere(
      (EntryRow e) => e.id == bestEntryId,
      orElse: () => rows.first,
    );
    final String? snippet = titleLevel
        ? buildExcerpt(
            best.comment,
            words,
            prefer: _nameAnchors(<String?>[best.name, g?.nameDisplay]),
            nullWhenUnanchored: true,
          )
        : buildExcerpt(best.comment, words);
    // 正文预览：命中高亮 snippet 优先，无则回退评语/楼层正文（100 字截断，生产同口径）。
    final String? preview = (snippet != null && snippet.isNotEmpty)
        ? snippet
        : summarizeCardText(best.previewSource);
    return GroupHit(
      groupId: g?.id,
      name: g?.nameDisplay ?? best.name,
      nameNorm: nameNorm,
      author: g?.authorDisplay ?? best.author,
      hitCount: rows.length,
      recommendCount: rec,
      avoidCount: avoid,
      latestDate: latest,
      snippet: snippet,
      preview: preview,
      channels: channels.toList(),
      bestEntryId: bestEntryId,
      bestFlag: bestFlag,
    );
  }

  @override
  Future<List<String>> suggestBooks(String prefix, {int limit = 8}) async {
    _hit('suggestBooks');
    if (prefix.trim().isEmpty) {
      return const <String>[];
    }
    final String p = prefix.trim().toLowerCase();
    return lib.groups
        .map((BookGroup g) => g.nameNorm)
        .where((String n) => n.toLowerCase().contains(p))
        .take(limit)
        .toList();
  }

  @override
  Future<List<HotBook>> hotBooks({int limit = 20}) async {
    _hit('hotBooks');
    final List<BookGroup> sorted = lib.groups.toList()
      ..sort(
        (BookGroup a, BookGroup b) => b.entryTotal.compareTo(a.entryTotal),
      );
    return <HotBook>[
      for (final BookGroup g in sorted.take(limit))
        HotBook(
          nameNorm: g.nameNorm,
          name: g.nameDisplay ?? g.nameNorm,
          entryTotal: g.entryTotal,
          groupId: g.id,
        ),
    ];
  }

  // ───────────────────────── 详情 ─────────────────────────

  @override
  Future<PostDetailData?> postDetail(int postId) async {
    _hit('postDetail:$postId');
    Post? post;
    for (final Post p in lib.posts) {
      if (p.id == postId) {
        post = p;
      }
    }
    if (post == null) {
      return null;
    }
    final List<EntryRow> own = lib.entries
        .where((EntryRow e) => e.postRef == postId)
        .toList();
    final Set<String> seen = <String>{};
    final List<PostBookCount> books = <PostBookCount>[
      for (final EntryRow e in own)
        if (seen.add(e.nameNorm))
          PostBookCount(
            groupId: lib.groupOfName(e.nameNorm)?.id,
            name: lib.groupOfName(e.nameNorm)?.nameDisplay ?? e.name,
            recommend: lib.entries
                .where((EntryRow x) =>
                    x.nameNorm == e.nameNorm && x.recommendFlag > 0)
                .length,
            avoid: lib.entries
                .where((EntryRow x) =>
                    x.nameNorm == e.nameNorm && x.recommendFlag < 0)
                .length,
          ),
    ];
    return PostDetailData(
      post: post,
      floors: lib.floors[postId] ?? const <FloorData>[],
      books: books,
    );
  }

  @override
  Future<BookDetailData?> bookDetail(int groupId) async {
    _hit('bookDetail:$groupId');
    BookGroup? group;
    for (final BookGroup g in lib.groups) {
      if (g.id == groupId) {
        group = g;
      }
    }
    if (group == null) {
      return null;
    }
    final List<EntryRow> own = lib.entries
        .where((EntryRow e) => e.bookGroupId == groupId)
        .toList();
    return BookDetailData(
      group: group,
      recommendCount: own.where((EntryRow e) => e.recommendFlag > 0).length,
      avoidCount: own.where((EntryRow e) => e.recommendFlag < 0).length,
    );
  }

  @override
  Future<List<EntryRow>> bookEntries(
    int groupId,
    SemanticFilter filter, {
    EntrySort sort = EntrySort.qualityDesc,
  }) async {
    _hit('bookEntries:$groupId:$filter:$sort');
    final List<EntryRow> rows = lib.entries
        .where((EntryRow e) => e.bookGroupId == groupId)
        .toList();
    final List<EntryRow> out = switch (filter) {
      SemanticFilter.recommend =>
        rows.where((EntryRow e) => e.recommendFlag > 0).toList(),
      SemanticFilter.avoid =>
        rows.where((EntryRow e) => e.recommendFlag < 0).toList(),
      SemanticFilter.all => rows,
    };
    out.sort(switch (sort) {
      EntrySort.qualityDesc => (EntryRow a, EntryRow b) => b.quality.compareTo(
        a.quality,
      ),
      EntrySort.timeDesc =>
        (EntryRow a, EntryRow b) => (b.date ?? '').compareTo(a.date ?? ''),
      EntrySort.timeAsc => (EntryRow a, EntryRow b) => (a.date ?? '').compareTo(
        b.date ?? '',
      ),
      EntrySort.wordDesc =>
        (EntryRow a, EntryRow b) =>
            (b.wordCount ?? 0).compareTo(a.wordCount ?? 0),
    });
    return out;
  }

  // ───────────────────────── 历史 / 书签 / 收藏 ─────────────────────────

  @override
  Stream<List<SearchHistoryEntry>> watchHistory() => _history.stream;

  @override
  Future<void> addHistory(SearchFilter f) async {
    _hit('addHistory');
    final List<SearchHistoryEntry> kept = _history.value
        .where(
          (SearchHistoryEntry h) =>
              !(h.query == f.query &&
                  h.year == f.year &&
                  h.month == f.month &&
                  h.tenDay == f.tenDay &&
                  h.channel == f.channel &&
                  h.category == f.category),
        )
        .toList();
    _history.value = <SearchHistoryEntry>[
      SearchHistoryEntry(
        id: _nextId++,
        query: f.query,
        year: f.year,
        month: f.month,
        tenDay: f.tenDay,
        channel: f.channel,
        category: f.category,
        sort: f.sort.wire,
        searchedAt: DateTime(2026, 10, 13, 12),
      ),
      ...kept,
    ].take(50).toList();
  }

  @override
  Future<void> deleteHistory(int id) async {
    _history.value = _history.value
        .where((SearchHistoryEntry h) => h.id != id)
        .toList();
  }

  @override
  Future<void> clearHistory() async =>
      _history.value = const <SearchHistoryEntry>[];

  @override
  Stream<List<Bookmark>> watchBookmarks() => _bookmarks.stream;

  @override
  Future<bool> togglePostBookmark({
    required int postRef,
    required String title,
    String? author,
    String? channel,
    int position = 0,
    SearchFilter? snapshot,
    int? floorSeq,
    String? note,
  }) async {
    _hit('togglePostBookmark');
    final int at = _bookmarks.value.indexWhere(
      (Bookmark b) => b.postRef == postRef,
    );
    if (at >= 0) {
      _bookmarks.value = List<Bookmark>.of(_bookmarks.value)..removeAt(at);
      return false;
    }
    _bookmarks.value = <Bookmark>[
      Bookmark(
        id: _nextId++,
        postRef: postRef,
        title: title,
        author: author,
        channel: channel,
        position: position,
        floorSeq: floorSeq,
        snapQuery: snapshot?.query,
        snapYear: snapshot?.year,
        snapMonth: snapshot?.month,
        snapTenDay: snapshot?.tenDay,
        snapChannel: snapshot?.channel,
        snapCategory: snapshot?.category,
        snapSort: snapshot?.sort.wire,
        note: note,
        createdAt: DateTime(2026, 10, 13, 12),
      ),
      ..._bookmarks.value,
    ];
    return true;
  }

  @override
  Stream<List<Favorite>> watchFavorites() => _favorites.stream;

  @override
  Future<bool> toggleFavorite({
    required String targetType,
    required int targetId,
    required String title,
    String? subtitle,
  }) async {
    _hit('toggleFavorite');
    final int at = _favorites.value.indexWhere(
      (Favorite f) => f.targetType == targetType && f.targetId == targetId,
    );
    if (at >= 0) {
      _favorites.value = List<Favorite>.of(_favorites.value)..removeAt(at);
      return false;
    }
    _favorites.value = <Favorite>[
      Favorite(
        id: _nextId++,
        targetType: targetType,
        targetId: targetId,
        title: title,
        subtitle: subtitle,
        addedAt: DateTime(2026, 10, 13, 12),
      ),
      ..._favorites.value,
    ];
    return true;
  }
}
