import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import 'database_provider.dart';

// 数据访问层（M1-④）：首页时间线/热门榜、分类五维计数与浏览、六维搜索（FTS+LIKE 兜底）、
// 帖子/书聚合详情、历史/书签/收藏 CRUD。全部查询参数化（原型 §7.3，消灭字符串拼接缺陷）。
// 维度取值编码与 search_history / bookmarks 快照列一致（原型 §7.2）。

// ───────────────────────── 维度取值编码 ─────────────────────────

/// 排序（search_history.sort / bookmarks.snap_sort 编码）。
enum SearchSort {
  timeDesc('time_desc'),
  timeAsc('time_asc');

  const SearchSort(this.wire);
  final String wire;

  static SearchSort fromWire(String? wire) =>
      SearchSort.values.firstWhere((SearchSort s) => s.wire == wire, orElse: () => SearchSort.timeDesc);
}

/// 年份维度的「更早」聚合值（≤2016，原型 §5.3/§5.12）。
abstract final class YearFilter {
  static const String early = 'early';
  static const int earlyMaxYear = 2016;
}

/// 旬维编码（继承扫书 SUBSTR(post_time,9,2) 规则，原型 §5.3）。
abstract final class TenDayFilter {
  static const String upper = 'upper';
  static const String middle = 'middle';
  static const String lower = 'lower';
}

/// 来源维聚合值与渠道名（原型 §5.3 搜索台 / §5.12 分类页）。
abstract final class ChannelFilter {
  /// §5.3「其他」= 丫丫书屋 + 龙空论坛 + 两吧。
  static const String otherSmall = 'other';

  /// §5.12「其他」= 大佬贴吧扫书 + 大佬专栏 + 丫丫书屋 + 龙空论坛。
  static const String otherBig = 'misc';

  /// §5.3「自采」= origin='collected'（非渠道值，走 origin 列）。
  static const String collected = 'collected';

  static const List<String> otherSmallMembers = <String>['丫丫书屋', '龙空论坛', '两吧'];
  static const List<String> otherBigMembers = <String>['大佬贴吧扫书', '大佬专栏', '丫丫书屋', '龙空论坛'];

  /// 具名渠道（搜索台来源维完整取值）。
  static const List<String> named = <String>[
    'yy小说吧', '哀伤雪刃', '雪群推书', '大佬贴吧扫书', '大佬专栏', '丫丫书屋', '龙空论坛', '两吧',
  ];

  /// 分类页来源维展示序（§5.12：yy/哀伤/雪群/两吧 具名，其余并为「其他」）。
  static const List<String> categoryNamed = <String>['yy小说吧', '哀伤雪刃', '雪群推书', '两吧'];
}

/// 类别维取值（post_kind 枚举，原型 §8.9）。
abstract final class CategoryKind {
  static const String scan = '扫书';
  static const String avoid = '排雷';
  static const String ask = '求书';
  static const String daily = '日常';
  static const List<String> all = <String>[scan, avoid, ask, daily];
}

/// 热门榜时间范围（原型 §5.13，锚定设备当天）。
enum RankWindow { allTime, thisYear, thisMonth, last30 }

/// 书聚合页语义筛选（原型 §5.5：全部/仅推荐/仅排雷）。
enum SemanticFilter { all, recommend, avoid }

/// 书聚合页评价排序（原型 §5.5：质量↓默认 / 时间↓ / 时间↑ / 字数↓）。
enum EntrySort { qualityDesc, timeDesc, timeAsc, wordDesc }

/// 分类页五维（原型 §5.12）。
enum CategoryDim { year, month, tenDay, channel, category }

/// 收藏目标粒度（favorites.target_type，原型 §7.2）。
abstract final class FavoriteTarget {
  static const String bookGroup = 'book_group';
  static const String post = 'post';
  static const String entry = 'entry';
}

/// 条目推荐语义（§8.9）：大佬存量按 book_grade 直接映射，其余按 category 冗余派生。
/// +1=推荐 / −1=排雷 / 0=中性。
int entryFlagOf({required String category, String? bookGrade}) {
  switch (bookGrade) {
    case '#11850A':
      return 1;
    case '#FF0000':
      return -1;
    default:
      if (bookGrade != null && bookGrade.isNotEmpty) {
        return 0;
      }
  }
  switch (category) {
    case CategoryKind.scan:
      return 1;
    case CategoryKind.avoid:
      return -1;
    default:
      return 0;
  }
}

/// 上述规则的 SQL 内联等价式（别名列直查，供聚合/筛选用）。
String _flagSql([String alias = 'b']) => '''CASE
  WHEN $alias.book_grade = '#11850A' THEN 1
  WHEN $alias.book_grade = '#FF0000' THEN -1
  WHEN $alias.book_grade IS NOT NULL AND $alias.book_grade != '' THEN 0
  WHEN $alias.category = '${CategoryKind.scan}' THEN 1
  WHEN $alias.category = '${CategoryKind.avoid}' THEN -1
  ELSE 0 END''';

// ───────────────────────── 筛选条件模型 ─────────────────────────

/// 六维搜索条件（关键词 + 年/月/旬/来源/类别 + 排序；原型 §5.3）。
///
/// 不可变；==/hashCode 完整实现以充当 FutureProvider.family 键。
class SearchFilter {
  const SearchFilter({
    this.query = '',
    this.year,
    this.month,
    this.tenDay,
    this.channel,
    this.category,
    this.sort = SearchSort.timeDesc,
    this.limit = 40,
    this.offset = 0,
  });

  final String query;
  final String? year;
  final String? month;
  final String? tenDay;
  final String? channel;
  final String? category;
  final SearchSort sort;
  final int limit;
  final int offset;

  /// 无任何筛选（纯浏览缺省态）。
  bool get isDefault =>
      query.isEmpty &&
      year == null &&
      month == null &&
      tenDay == null &&
      channel == null &&
      category == null &&
      sort == SearchSort.timeDesc;

  SearchFilter copyWith({
    String? query,
    Value<String?> year = const Value<String?>.absent(),
    Value<String?> month = const Value<String?>.absent(),
    Value<String?> tenDay = const Value<String?>.absent(),
    Value<String?> channel = const Value<String?>.absent(),
    Value<String?> category = const Value<String?>.absent(),
    SearchSort? sort,
    int? limit,
    int? offset,
  }) {
    return SearchFilter(
      query: query ?? this.query,
      year: year.present ? year.value : this.year,
      month: month.present ? month.value : this.month,
      tenDay: tenDay.present ? tenDay.value : this.tenDay,
      channel: channel.present ? channel.value : this.channel,
      category: category.present ? category.value : this.category,
      sort: sort ?? this.sort,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }

  /// /search 路由 queryParameters（app_router 接线用）。
  Map<String, String> toUriParams() {
    return <String, String>{
      if (query.isNotEmpty) 'q': query,
      'year': ?year,
      'month': ?month,
      'ten': ?tenDay,
      'channel': ?channel,
      'category': ?category,
      if (sort != SearchSort.timeDesc) 'sort': sort.wire,
    };
  }

  static SearchFilter fromUriParams(Map<String, String> p) {
    return SearchFilter(
      query: p['q'] ?? '',
      year: p['year'],
      month: p['month'],
      tenDay: p['ten'],
      channel: p['channel'],
      category: p['category'],
      sort: SearchSort.fromWire(p['sort']),
    );
  }

  static SearchFilter fromHistory(SearchHistoryEntry h) {
    return SearchFilter(
      query: h.query,
      year: h.year,
      month: h.month,
      tenDay: h.tenDay,
      channel: h.channel,
      category: h.category,
      sort: SearchSort.fromWire(h.sort),
    );
  }

  /// 历史行摘要（§5.3：每条显示完整条件摘要）。
  String describe() {
    final List<String> parts = <String>[
      if (query.isNotEmpty) query,
      if (year != null) year == YearFilter.early ? '更早' : '$year年',
      if (month != null) '$month月',
      if (tenDay != null) tenDayLabel(tenDay!),
      if (channel != null) channelLabel(channel!),
      ?category,
    ];
    return parts.isEmpty ? '全部' : parts.join(' · ');
  }

  @override
  bool operator ==(Object other) {
    return other is SearchFilter &&
        other.query == query &&
        other.year == year &&
        other.month == month &&
        other.tenDay == tenDay &&
        other.channel == channel &&
        other.category == category &&
        other.sort == sort &&
        other.limit == limit &&
        other.offset == offset;
  }

  @override
  int get hashCode => Object.hash(query, year, month, tenDay, channel, category, sort, limit, offset);
}

/// 维度值 → 展示文案。
String tenDayLabel(String value) => switch (value) {
  TenDayFilter.upper => '上旬',
  TenDayFilter.middle => '中旬',
  TenDayFilter.lower => '下旬',
  _ => value,
};

String channelLabel(String value) => switch (value) {
  ChannelFilter.otherSmall || ChannelFilter.otherBig => '其他',
  ChannelFilter.collected => '自采',
  _ => value,
};

String yearLabel(String value) => value == YearFilter.early ? '更早' : value;

/// 分类页五维选中态（单选含「全部」=null；原型 §5.12）。
class CategorySelection {
  const CategorySelection({this.year, this.month, this.tenDay, this.channel, this.category});

  final String? year;
  final String? month;
  final String? tenDay;
  final String? channel;
  final String? category;

  bool get isEmpty => year == null && month == null && tenDay == null && channel == null && category == null;

  static const CategorySelection empty = CategorySelection();

  /// 点值 chip：单选；再次点已选值 = 取消回「全部」。
  CategorySelection toggled(CategoryDim dim, String value) {
    String? pick(String? current) => current == value ? null : value;
    return switch (dim) {
      CategoryDim.year => CategorySelection(year: pick(year), month: month, tenDay: tenDay, channel: channel, category: category),
      CategoryDim.month => CategorySelection(year: year, month: pick(month), tenDay: tenDay, channel: channel, category: category),
      CategoryDim.tenDay => CategorySelection(year: year, month: month, tenDay: pick(tenDay), channel: channel, category: category),
      CategoryDim.channel => CategorySelection(year: year, month: month, tenDay: tenDay, channel: pick(channel), category: category),
      CategoryDim.category => CategorySelection(year: year, month: month, tenDay: tenDay, channel: channel, category: pick(category)),
    };
  }

  String? valueOf(CategoryDim dim) => switch (dim) {
    CategoryDim.year => year,
    CategoryDim.month => month,
    CategoryDim.tenDay => tenDay,
    CategoryDim.channel => channel,
    CategoryDim.category => category,
  };

  /// 「查看全部结果」→ 搜索页携条件（关键词空 = 纯条件浏览，§5.12）。
  SearchFilter toFilter({SearchSort sort = SearchSort.timeDesc, int limit = 40, int offset = 0}) {
    return SearchFilter(
      year: year, month: month, tenDay: tenDay, channel: channel, category: category,
      sort: sort, limit: limit, offset: offset,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CategorySelection &&
        other.year == year &&
        other.month == month &&
        other.tenDay == tenDay &&
        other.channel == channel &&
        other.category == category;
  }

  @override
  int get hashCode => Object.hash(year, month, tenDay, channel, category);
}

// ───────────────────────── 行模型 ─────────────────────────

/// 书目条目视图行（详情页/分类预览/书聚合评价卡共用）。
class EntryRow {
  const EntryRow({
    required this.id,
    required this.name,
    required this.nameNorm,
    this.author,
    this.recommender,
    this.comment,
    this.date,
    required this.channel,
    this.subChannel,
    required this.category,
    this.bookGrade,
    required this.origin,
    required this.quality,
    this.wordCount,
    this.postRef,
    this.floorRef,
    this.bookGroupId,
    this.srcUrl,
    this.snippet,
  });

  factory EntryRow.fromRow(QueryRow r, {String? snippet}) {
    final Map<String, dynamic> d = r.data;
    return EntryRow(
      id: d['id']! as int,
      name: d['name']! as String,
      nameNorm: d['name_norm']! as String,
      author: d['author'] as String?,
      recommender: d['recommender'] as String?,
      comment: d['comment'] as String?,
      date: d['date'] as String?,
      channel: d['channel']! as String,
      subChannel: d['sub_channel'] as String?,
      category: d['category']! as String,
      bookGrade: d['book_grade'] as String?,
      origin: d['origin']! as String,
      quality: d['quality']! as int,
      wordCount: d['word_count'] as int?,
      postRef: d['post_ref'] as int?,
      floorRef: d['floor_ref'] as int?,
      bookGroupId: d['book_group_id'] as int?,
      srcUrl: d['src_url'] as String?,
      snippet: snippet,
    );
  }

  final int id;
  final String name;
  final String nameNorm;
  final String? author;
  final String? recommender;
  final String? comment;
  final String? date;
  final String channel;
  final String? subChannel;
  final String category;
  final String? bookGrade;
  final String origin;
  final int quality;
  final int? wordCount;
  final int? postRef;
  final int? floorRef;
  final int? bookGroupId;
  final String? srcUrl;

  /// 搜索命中摘要（`[词]` 标记；FTS snippet 或 LIKE 兜底自拼）。
  final String? snippet;

  /// 推荐语义（§8.9）：+1 推荐 / −1 排雷 / 0 中性。
  int get recommendFlag => entryFlagOf(category: category, bookGrade: bookGrade);
}

/// 首页卡片书名 chip。
class BookChip {
  const BookChip({required this.name, required this.nameNorm, this.bookGroupId});

  final String name;
  final String nameNorm;
  final int? bookGroupId;
}

/// 首页时间线卡片（帖粒度 + 关联书名 chips + 首条推荐语摘要）。
class PostCardData {
  const PostCardData({
    required this.post,
    required this.books,
    required this.entryCount,
    this.summary,
  });

  final Post post;
  final List<BookChip> books;
  final int entryCount;
  final String? summary;
}

/// 日期分组（首页 group header）。
class TimelineGroup {
  const TimelineGroup({required this.date, required this.posts});

  final String date;
  final List<PostCardData> posts;
}

/// 热门榜行（§5.13）。
class RankRow {
  const RankRow({
    required this.nameNorm,
    required this.name,
    this.author,
    required this.count,
    this.bookGroupId,
  });

  final String nameNorm;
  final String name;
  final String? author;
  final int count;
  final int? bookGroupId;
}

/// 搜索结果书级卡（book_group 粒度，§5.4）。
class GroupHit {
  const GroupHit({
    required this.groupId,
    required this.name,
    required this.nameNorm,
    this.author,
    required this.hitCount,
    required this.recommendCount,
    required this.avoidCount,
    this.latestDate,
    this.snippet,
    required this.channels,
    required this.bestEntryId,
    required this.bestFlag,
  });

  /// book_groups.id；无聚合组的散条目为 null（点击退化为按书名搜索）。
  final int? groupId;
  final String name;
  final String nameNorm;
  final String? author;
  final int hitCount;
  final int recommendCount;
  final int avoidCount;
  final String? latestDate;
  final String? snippet;
  final List<String> channels;
  final int bestEntryId;
  final int bestFlag;
}

/// 分页结果。
class Paged<T> {
  const Paged({required this.items, required this.total, this.limit = 0, this.offset = 0});

  final List<T> items;
  final int total;
  final int limit;
  final int offset;

  bool get hasMore => limit > 0 && offset + items.length < total;
}

/// 搜索产物：结果页 + 检索路径标记（FTS / LIKE 兜底 / FTS 异常降级，§7.3）。
class SearchOutcome {
  const SearchOutcome({required this.page, this.usedFts = false, this.degraded = false, this.words = const <String>[]});

  final Paged<GroupHit> page;
  final bool usedFts;

  /// FTS 查询异常自动降级 LIKE（UI SnackBar「已降级为慢速搜索」，§5.3）。
  final bool degraded;
  final List<String> words;

  static const SearchOutcome empty = SearchOutcome(page: Paged<GroupHit>(items: <GroupHit>[], total: 0));
}

/// 楼层（含图片）。
class FloorData {
  const FloorData({required this.floor, required this.images});

  final Floor floor;
  final List<FloorImage> images;
}

/// 帖子详情聚合（头部计数对比 = 帖内条目推荐/排雷数）。
class PostDetailData {
  const PostDetailData({
    required this.post,
    required this.floors,
    required this.recommendCount,
    required this.avoidCount,
  });

  final Post post;
  final List<FloorData> floors;
  final int recommendCount;
  final int avoidCount;
}

/// 书聚合详情头部。
class BookDetailData {
  const BookDetailData({required this.group, required this.recommendCount, required this.avoidCount});

  final BookGroup group;
  final int recommendCount;
  final int avoidCount;

  int get entryTotal => group.entryTotal;
}

/// 维度值 + 真实命中计数（§5.12 诚实标注）。
class DimCount {
  const DimCount({required this.value, required this.label, required this.count});

  final String value;
  final String label;
  final int count;
}

/// 五维计数聚合（dimensionCountsProvider 载荷）。
class CategoryCounts {
  const CategoryCounts({
    required this.total,
    required this.years,
    required this.months,
    required this.tenDays,
    required this.channels,
    required this.categories,
  });

  final int total;
  final List<DimCount> years;
  final List<DimCount> months;
  final List<DimCount> tenDays;
  final List<DimCount> channels;
  final List<DimCount> categories;

  List<DimCount> of(CategoryDim dim) => switch (dim) {
    CategoryDim.year => years,
    CategoryDim.month => months,
    CategoryDim.tenDay => tenDays,
    CategoryDim.channel => channels,
    CategoryDim.category => categories,
  };
}

/// 分类页结果区（命中计数 + 预览前 N）。
class CategoryPreview {
  const CategoryPreview({required this.count, required this.entries});

  final int count;
  final List<EntryRow> entries;
}

/// 热门书名（搜索台空态，book_groups.entry_total Top N）。
class HotBook {
  const HotBook({required this.nameNorm, required this.name, required this.entryTotal, this.groupId});

  final String nameNorm;
  final String name;
  final int entryTotal;
  final int? groupId;
}

/// 关键词分词（空格分词，全命中 AND；继承扫书 queryPosts 语义）。
List<String> tokenizeQuery(String query) =>
    query.trim().split(RegExp(r'\s+')).where((String w) => w.isNotEmpty).toList();

/// LIKE 兜底摘要：以首个命中词为中心截窗，`[词]` 标记与 FTS snippet 同约定。
String? buildExcerpt(String? text, List<String> words, {int radius = 14}) {
  if (text == null || text.isEmpty) {
    return null;
  }
  final String lower = text.toLowerCase();
  int idx = -1;
  int hitLen = 0;
  for (final String w in words) {
    final int i = lower.indexOf(w.toLowerCase());
    if (i >= 0 && (idx < 0 || i < idx)) {
      idx = i;
      hitLen = w.length;
    }
  }
  if (idx < 0) {
    return text.length > radius * 2 ? '${text.substring(0, radius * 2)}…' : text;
  }
  final int start = math.max(0, idx - radius);
  final int end = math.min(text.length, idx + hitLen + radius);
  return '${start > 0 ? '…' : ''}${text.substring(start, idx)}'
      '[${text.substring(idx, idx + hitLen)}]'
      '${text.substring(idx + hitLen, end)}${end < text.length ? '…' : ''}';
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ───────────────────────── 数据访问契约 ─────────────────────────

/// 领域层唯一对外契约（UI 与 Provider 只依赖本接口，不依赖 drift 具体实现）。
///
/// 存在的理由是测试架构（`app/test/TESTING.md`）：`testWidgets` 跑在
/// AutomatedTestWidgetsFlutterBinding 的 FakeAsync **假时钟区**，任何走真实事件循环的异步
/// （dart:io、Isolate/ReceivePort、平台通道）在区内 `await` 都**永不返回**；而 flutter_test
/// 的超时计时器同样记在假时钟上 → 假时间不前进 → 超时永不触发 → 无限挂死。
/// 有了本接口，widget 测试即可 `queriesProvider.overrideWithValue(FakeBookRepository())`
/// 注入纯内存实现（只有微任务，FakeAsync 可正常冲刷），把真实 drift 的正确性断言留给
/// plain `test()`（真实事件循环，IO 正常）。
abstract interface class BookRepository {
  /// 首页时间线（§5.2）。
  Future<List<PostCardData>> timelinePosts({required int limit, int offset = 0});

  /// 自采新内容红点计数（collection_state.new_since_visit 之和）。
  Stream<int> watchNewContentCount();

  /// 热门榜（§5.13：按 [window] 时段内推荐次数重排）。
  Future<List<RankRow>> rankRows(RankWindow window, {DateTime? today, int limit = 10});

  /// 内置库数据截至日（榜单页脚「数据截至 …」）。
  Future<String?> dataCutoff();

  /// 随机书荒（P1-3）。
  Future<List<EntryRow>> randomBooks(int count);

  /// 五维真实命中计数（§5.12）。
  Future<CategoryCounts> dimensionCounts();

  /// 分类页选中即时过滤：交集条数 + 预览前 N。
  Future<CategoryPreview> categoryPreview(CategorySelection sel, {int limit = 5});

  /// 六维搜索（§7.3：≥3 字走 FTS，2 字词 LIKE 兜底）。
  Future<SearchOutcome> searchBooks(SearchFilter f);

  /// 帖子详情（§5.6：楼层流 + 推荐/排雷计数对比）。
  Future<PostDetailData?> postDetail(int postId);

  /// 书聚合详情头（§5.5）。
  Future<BookDetailData?> bookDetail(int groupId);

  /// 书聚合评价列表（语义筛选 × 排序）。
  Future<List<EntryRow>> bookEntries(int groupId, SemanticFilter filter, {EntrySort sort = EntrySort.qualityDesc});

  /// 书名联想（§5.3）。
  Future<List<String>> suggestBooks(String prefix, {int limit = 8});

  /// 热门书名（book_groups.entry_total Top N）。
  Future<List<HotBook>> hotBooks({int limit = 20});

  /// 搜索历史六维快照（§5.3）。
  Stream<List<SearchHistoryEntry>> watchHistory();
  Future<void> addHistory(SearchFilter f);
  Future<void> deleteHistory(int id);
  Future<void> clearHistory();

  /// 书签（含搜索条件快照，§5.6）。
  Stream<List<Bookmark>> watchBookmarks();
  Future<bool> togglePostBookmark({
    required int postRef,
    required String title,
    String? author,
    String? channel,
    int position = 0,
    SearchFilter? snapshot,
    String? note,
  });

  /// 收藏（书/帖双粒度，§5.5/§5.6）。
  Stream<List<Favorite>> watchFavorites();
  Future<bool> toggleFavorite({
    required String targetType,
    required int targetId,
    required String title,
    String? subtitle,
  });
}

// ───────────────────────── 查询实现 ─────────────────────────

/// drift 查询集（原型 §7.3 检索策略 / §9.2 Provider 划分的领域层落点）。
class Queries implements BookRepository {
  const Queries(this.db);

  final AppDatabase db;

  static const String _entryCols =
      'b.id, b.name, b.name_norm, b.author, b.recommender, b.comment, b.date, b.channel, '
      'b.sub_channel, b.category, b.book_grade, b.origin, b.quality, b.word_count, '
      'b.post_ref, b.floor_ref, b.book_group_id, b.src_url';

  // ── 首页：时间线（§5.2）──

  /// 最新扫书帖卡片流（扫书+排雷帖；日期倒序分页），关联书名 chips（前 4 + 总数）。
  @override
  Future<List<PostCardData>> timelinePosts({required int limit, int offset = 0}) async {
    final List<Post> posts = await db
        .customSelect(
          'SELECT p.* FROM posts p '
          'WHERE p.date IS NOT NULL AND p.post_kind IN (?, ?) '
          'ORDER BY p.date DESC, p.id DESC LIMIT ? OFFSET ?',
          variables: <Variable<Object>>[
            Variable<String>(CategoryKind.scan),
            Variable<String>(CategoryKind.avoid),
            Variable<int>(limit),
            Variable<int>(offset),
          ],
          readsFrom: <TableInfo<Table, Object?>>{db.posts},
        )
        .map((QueryRow r) => db.posts.map(r.data))
        .get();
    if (posts.isEmpty) {
      return <PostCardData>[];
    }
    final List<int> ids = posts.map((Post p) => p.id).toList();
    final String holes = List<String>.filled(ids.length, '?').join(', ');
    final List<QueryRow> entryRows = await db
        .customSelect(
          'SELECT post_ref, name, name_norm, book_group_id, comment FROM book_entries '
          'WHERE post_ref IN ($holes) ORDER BY id',
          variables: <Variable<Object>>[for (final int id in ids) Variable<int>(id)],
          readsFrom: <TableInfo<Table, Object?>>{db.bookEntries},
        )
        .get();
    final Map<int, List<BookChip>> chips = <int, List<BookChip>>{};
    final Map<int, int> counts = <int, int>{};
    final Map<int, String> summaries = <int, String>{};
    for (final QueryRow r in entryRows) {
      final int postRef = r.data['post_ref']! as int;
      counts[postRef] = (counts[postRef] ?? 0) + 1;
      final List<BookChip> list = chips.putIfAbsent(postRef, () => <BookChip>[]);
      if (list.length < 4) {
        list.add(BookChip(
          name: r.data['name']! as String,
          nameNorm: r.data['name_norm']! as String,
          bookGroupId: r.data['book_group_id'] as int?,
        ));
      }
      final String? comment = r.data['comment'] as String?;
      if (comment != null && comment.length >= 12 && !summaries.containsKey(postRef)) {
        summaries[postRef] = comment.length > 80 ? '${comment.substring(0, 80)}…' : comment;
      }
    }
    return <PostCardData>[
      for (final Post p in posts)
        PostCardData(
          post: p,
          books: chips[p.id] ?? const <BookChip>[],
          entryCount: counts[p.id] ?? 0,
          summary: summaries[p.id],
        ),
    ];
  }

  /// 按日期分组（首页 group header 大日期）。
  static List<TimelineGroup> groupByDate(List<PostCardData> cards) {
    final List<TimelineGroup> groups = <TimelineGroup>[];
    for (final PostCardData card in cards) {
      final String date = card.post.date ?? '';
      if (groups.isNotEmpty && groups.last.date == date) {
        groups.last.posts.add(card);
      } else {
        groups.add(TimelineGroup(date: date, posts: <PostCardData>[card]));
      }
    }
    return groups;
  }

  /// 采集提示卡：全部吧 new_since_visit 之和（§5.2，>0 才显示）。
  @override
  Stream<int> watchNewContentCount() {
    return db
        .customSelect(
          'SELECT COALESCE(SUM(new_since_visit), 0) AS n FROM collection_state',
          readsFrom: <TableInfo<Table, Object?>>{db.collectionState},
        )
        .watch()
        .map((List<QueryRow> rows) => rows.single.data['n']! as int);
  }

  // ── 热门榜（§5.13：推荐次数榜，GROUP BY name_norm，不依赖 FTS）──

  /// 时间范围下限（全时段 = null）；[today] 缺省设备当天，可注入以固定测试锚点。
  static String? rankFromDate(RankWindow window, DateTime today) {
    return switch (window) {
      RankWindow.allTime => null,
      RankWindow.thisYear => '${today.year.toString().padLeft(4, '0')}-01-01',
      RankWindow.thisMonth => _isoDate(DateTime(today.year, today.month)),
      RankWindow.last30 => _isoDate(today.subtract(const Duration(days: 29))),
    };
  }

  @override
  Future<List<RankRow>> rankRows(RankWindow window, {DateTime? today, int limit = 10}) {
    final String? from = rankFromDate(window, today ?? DateTime.now());
    final List<Variable<Object>> vars = <Variable<Object>>[];
    final String dateClause = from == null ? '' : ' AND b.date >= ?';
    if (from != null) {
      vars.add(Variable<String>(from));
    }
    vars.add(Variable<int>(limit));
    return db
        .customSelect(
          'SELECT b.name_norm AS name_norm, COUNT(*) AS cnt, '
          'MAX(g.name_display) AS name, MAX(g.author_display) AS author, MAX(g.id) AS gid '
          'FROM book_entries b LEFT JOIN book_groups g ON g.name_norm = b.name_norm '
          'WHERE b.date IS NOT NULL$dateClause '
          'GROUP BY b.name_norm ORDER BY cnt DESC, b.name_norm LIMIT ?',
          variables: vars,
          readsFrom: <TableInfo<Table, Object?>>{db.bookEntries, db.bookGroups},
        )
        .map((QueryRow r) => RankRow(
              nameNorm: r.data['name_norm']! as String,
              name: (r.data['name'] as String?) ?? (r.data['name_norm']! as String),
              author: r.data['author'] as String?,
              count: (r.data['cnt']! as num).toInt(),
              bookGroupId: r.data['gid'] as int?,
            ))
        .get();
  }

  /// 榜单底部「数据截至」注记。
  @override
  Future<String?> dataCutoff() async {
    final QueryRow r = await db
        .customSelect(
          'SELECT MAX(date) AS d FROM book_entries',
          readsFrom: <TableInfo<Table, Object?>>{db.bookEntries},
        )
        .getSingle();
    return r.data['d'] as String?;
  }

  /// 随机书荒（P1-3：有推荐语的书目条目）。
  @override
  Future<List<EntryRow>> randomBooks(int count) {
    return db
        .customSelect(
          'SELECT $_entryCols FROM book_entries b '
          "WHERE b.category = ? AND b.comment IS NOT NULL AND length(b.comment) >= 20 "
          'ORDER BY RANDOM() LIMIT ?',
          variables: <Variable<Object>>[Variable<String>(CategoryKind.scan), Variable<int>(count)],
          readsFrom: <TableInfo<Table, Object?>>{db.bookEntries},
        )
        .map((QueryRow r) => EntryRow.fromRow(r))
        .get();
  }

  // ── 分类页：五维计数与浏览（§5.12，不依赖 FTS）──

  @override
  Future<CategoryCounts> dimensionCounts() async {
    Future<List<QueryRow>> q(String sql) => db
        .customSelect(sql, readsFrom: <TableInfo<Table, Object?>>{db.bookEntries})
        .get();

    final int total = ((await q('SELECT COUNT(*) AS c FROM book_entries')).single.data['c']! as num).toInt();

    // 年：GROUP BY substr(date,1,4)，≤2016 并为「更早」。
    final List<QueryRow> yearRows = await q(
        "SELECT substr(date,1,4) AS v, COUNT(*) AS c FROM book_entries WHERE date IS NOT NULL GROUP BY v ORDER BY v DESC");
    int earlyCount = 0;
    final List<DimCount> years = <DimCount>[];
    for (final QueryRow r in yearRows) {
      final String y = r.data['v']! as String;
      final int c = (r.data['c']! as num).toInt();
      if ((int.tryParse(y) ?? 0) <= YearFilter.earlyMaxYear) {
        earlyCount += c;
      } else {
        years.add(DimCount(value: y, label: y, count: c));
      }
    }
    if (earlyCount > 0) {
      years.add(DimCount(value: YearFilter.early, label: '更早', count: earlyCount));
    }

    // 月：固定 1–12 全列（缺失月计 0，诚实标注）。
    final Map<int, int> monthCounts = <int, int>{};
    for (final QueryRow r in await q(
        'SELECT CAST(substr(date,6,2) AS INTEGER) AS v, COUNT(*) AS c FROM book_entries WHERE date IS NOT NULL GROUP BY v')) {
      monthCounts[(r.data['v']! as num).toInt()] = (r.data['c']! as num).toInt();
    }
    final List<DimCount> months = <DimCount>[
      for (int m = 1; m <= 12; m++)
        DimCount(value: '$m', label: '$m月', count: monthCounts[m] ?? 0),
    ];

    // 旬：上/中/下（substr(date,9,2) 区间）。
    final Map<String, int> tenCounts = <String, int>{};
    for (final QueryRow r in await q(
        'SELECT CASE WHEN CAST(substr(date,9,2) AS INTEGER) BETWEEN 1 AND 10 THEN \'upper\' '
        "WHEN CAST(substr(date,9,2) AS INTEGER) BETWEEN 11 AND 20 THEN 'middle' ELSE 'lower' END AS v, "
        'COUNT(*) AS c FROM book_entries WHERE date IS NOT NULL GROUP BY v')) {
      tenCounts[r.data['v']! as String] = (r.data['c']! as num).toInt();
    }
    final List<DimCount> tenDays = <DimCount>[
      DimCount(value: TenDayFilter.upper, label: '上旬', count: tenCounts[TenDayFilter.upper] ?? 0),
      DimCount(value: TenDayFilter.middle, label: '中旬', count: tenCounts[TenDayFilter.middle] ?? 0),
      DimCount(value: TenDayFilter.lower, label: '下旬', count: tenCounts[TenDayFilter.lower] ?? 0),
    ];

    // 来源：具名四渠道 + 「其他」聚合（§5.12 口径）。
    final Map<String, int> channelCounts = <String, int>{};
    for (final QueryRow r in await q('SELECT channel AS v, COUNT(*) AS c FROM book_entries GROUP BY v')) {
      channelCounts[r.data['v']! as String] = (r.data['c']! as num).toInt();
    }
    int otherCount = 0;
    final List<DimCount> channels = <DimCount>[];
    for (final String name in ChannelFilter.categoryNamed) {
      channels.add(DimCount(value: name, label: name, count: channelCounts[name] ?? 0));
    }
    channelCounts.forEach((String name, int c) {
      if (ChannelFilter.otherBigMembers.contains(name)) {
        otherCount += c;
      }
    });
    channels.add(DimCount(value: ChannelFilter.otherBig, label: '其他', count: otherCount));

    // 类别：固定枚举序（排雷为规则回填，计数可为 0 仍展示）。
    final Map<String, int> catCounts = <String, int>{};
    for (final QueryRow r in await q('SELECT category AS v, COUNT(*) AS c FROM book_entries GROUP BY v')) {
      catCounts[r.data['v']! as String] = (r.data['c']! as num).toInt();
    }
    final List<DimCount> categories = <DimCount>[
      for (final String k in CategoryKind.all) DimCount(value: k, label: k, count: catCounts[k] ?? 0),
    ];

    return CategoryCounts(
      total: total, years: years, months: months, tenDays: tenDays, channels: channels, categories: categories,
    );
  }

  /// 选中即时过滤：交集真实条数 + 预览前 [limit] 条书级卡（§5.12）。
  @override
  Future<CategoryPreview> categoryPreview(CategorySelection sel, {int limit = 5}) async {
    final List<Variable<Object>> vars = <Variable<Object>>[];
    final String dims = _dimClauses(sel.toFilter(), vars);
    final QueryRow countRow = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM book_entries b WHERE 1 = 1$dims',
          variables: vars,
          readsFrom: <TableInfo<Table, Object?>>{db.bookEntries},
        )
        .getSingle();
    final List<EntryRow> entries = await db
        .customSelect(
          'SELECT $_entryCols FROM book_entries b WHERE 1 = 1$dims '
          'ORDER BY b.date DESC, b.id DESC LIMIT ?',
          variables: <Variable<Object>>[...vars, Variable<int>(limit)],
          readsFrom: <TableInfo<Table, Object?>>{db.bookEntries},
        )
        .map((QueryRow r) => EntryRow.fromRow(r))
        .get();
    return CategoryPreview(count: (countRow.data['c']! as num).toInt(), entries: entries);
  }

  // ── 搜索（§7.3：≥3 字 FTS trigram，2 字词 LIKE 兜底，FTS 异常降级）──

  @override
  Future<SearchOutcome> searchBooks(SearchFilter f) async {
    final List<String> words = tokenizeQuery(f.query);
    if (words.isEmpty) {
      return SearchOutcome(page: await _browseGroups(f), words: words);
    }
    if (words.every((String w) => w.runes.length >= 3)) {
      final String match = words.map((String w) => '"${w.replaceAll('"', '""')}"').join(' AND ');
      try {
        return SearchOutcome(page: await _ftsGroups(match, words, f), usedFts: true, words: words);
      } on Object {
        // FTS 查询异常自动降级 LIKE（§5.3 错误态）。
        return SearchOutcome(page: await _likeGroups(words, f), degraded: true, words: words);
      }
    }
    return SearchOutcome(page: await _likeGroups(words, f), words: words);
  }

  /// 维度筛选 SQL 片段（全部参数化；变量按出现序追加进 [vars]）。
  String _dimClauses(SearchFilter f, List<Variable<Object>> vars) {
    final StringBuffer sql = StringBuffer();
    if (f.year == YearFilter.early) {
      sql.write(' AND CAST(substr(b.date,1,4) AS INTEGER) <= ${YearFilter.earlyMaxYear}');
    } else if (f.year != null) {
      sql.write(' AND substr(b.date,1,4) = ?');
      vars.add(Variable<String>(f.year!));
    }
    if (f.month != null) {
      sql.write(' AND CAST(substr(b.date,6,2) AS INTEGER) = ?');
      vars.add(Variable<int>(int.parse(f.month!)));
    }
    switch (f.tenDay) {
      case TenDayFilter.upper:
        sql.write(' AND CAST(substr(b.date,9,2) AS INTEGER) BETWEEN 1 AND 10');
      case TenDayFilter.middle:
        sql.write(' AND CAST(substr(b.date,9,2) AS INTEGER) BETWEEN 11 AND 20');
      case TenDayFilter.lower:
        sql.write(' AND CAST(substr(b.date,9,2) AS INTEGER) >= 21');
      case null:
        break;
    }
    switch (f.channel) {
      case ChannelFilter.otherSmall:
        sql.write(' AND b.channel IN (${List<String>.filled(ChannelFilter.otherSmallMembers.length, '?').join(', ')})');
        vars.addAll(ChannelFilter.otherSmallMembers.map(Variable<String>.new));
      case ChannelFilter.otherBig:
        sql.write(' AND b.channel IN (${List<String>.filled(ChannelFilter.otherBigMembers.length, '?').join(', ')})');
        vars.addAll(ChannelFilter.otherBigMembers.map(Variable<String>.new));
      case ChannelFilter.collected:
        sql.write(" AND b.origin = 'collected'");
      case final String named?:
        sql.write(' AND b.channel = ?');
        vars.add(Variable<String>(named));
      case null:
        break;
    }
    if (f.category != null) {
      sql.write(' AND b.category = ?');
      vars.add(Variable<String>(f.category!));
    }
    return sql.toString();
  }

  Future<Paged<GroupHit>> _ftsGroups(String match, List<String> words, SearchFilter f) {
    final List<Variable<Object>> vars = <Variable<Object>>[Variable<String>(match)];
    final String dims = _dimClauses(f, vars);
    return _groupedPage(
      matchedCte: 'WITH matched AS ('
          'SELECT b.*, snippet(book_fts, 3, \'[\', \']\', \'…\', 16) AS snip, ${_flagSql()} AS flag '
          'FROM book_fts JOIN book_entries b ON b.id = book_fts.rowid '
          'WHERE book_fts MATCH ?$dims)',
      cteVars: vars,
      filter: f,
      words: words,
    );
  }

  Future<Paged<GroupHit>> _likeGroups(List<String> words, SearchFilter f) {
    final List<Variable<Object>> vars = <Variable<Object>>[];
    final List<String> conds = <String>[];
    for (final String w in words) {
      final String arg = _likeArg(w);
      conds.add("(b.name LIKE ? ESCAPE '\\' OR b.author LIKE ? ESCAPE '\\' "
          "OR b.recommender LIKE ? ESCAPE '\\' OR b.comment LIKE ? ESCAPE '\\')");
      for (int i = 0; i < 4; i++) {
        vars.add(Variable<String>(arg));
      }
    }
    final String dims = _dimClauses(f, vars);
    return _groupedPage(
      matchedCte: 'WITH matched AS ('
          'SELECT b.*, NULL AS snip, ${_flagSql()} AS flag FROM book_entries b '
          'WHERE ${conds.join(' AND ')}$dims)',
      cteVars: vars,
      filter: f,
      words: words,
    );
  }

  Future<Paged<GroupHit>> _browseGroups(SearchFilter f) {
    final List<Variable<Object>> vars = <Variable<Object>>[];
    final String dims = _dimClauses(f, vars);
    return _groupedPage(
      matchedCte: 'WITH matched AS ('
          'SELECT b.*, NULL AS snip, ${_flagSql()} AS flag FROM book_entries b WHERE 1 = 1$dims)',
      cteVars: vars,
      filter: f,
      words: const <String>[],
    );
  }

  static String _likeArg(String w) =>
      '%${w.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%';

  /// 书级分组分页：聚合计数 → 页内 gid 取最佳条目（quality↓+推荐语长↓）二段查询。
  Future<Paged<GroupHit>> _groupedPage({
    required String matchedCte,
    required List<Variable<Object>> cteVars,
    required SearchFilter filter,
    required List<String> words,
  }) async {
    const String gidExpr = 'COALESCE(m.book_group_id, -m.id)';
    final String order = filter.sort == SearchSort.timeAsc
        ? 'latest IS NULL, latest ASC, hits DESC'
        : 'latest DESC, hits DESC';
    final int total = ((await db
            .customSelect(
              '$matchedCte SELECT COUNT(*) AS c FROM (SELECT 1 FROM matched m GROUP BY $gidExpr)',
              variables: cteVars,
              readsFrom: <TableInfo<Table, Object?>>{db.bookEntries},
            )
            .getSingle())
        .data['c']! as num)
        .toInt();
    final List<QueryRow> aggRows = await db
        .customSelect(
          '$matchedCte '
          'SELECT $gidExpr AS gid, COUNT(*) AS hits, SUM(m.flag = 1) AS rec, SUM(m.flag = -1) AS avoid, '
          'MAX(m.date) AS latest, MAX(g.name_display) AS gname, MAX(g.author_display) AS gauthor, '
          'GROUP_CONCAT(DISTINCT m.channel) AS chans '
          'FROM matched m LEFT JOIN book_groups g ON g.id = m.book_group_id '
          'GROUP BY gid ORDER BY $order LIMIT ? OFFSET ?',
          variables: <Variable<Object>>[...cteVars, Variable<int>(filter.limit), Variable<int>(filter.offset)],
          readsFrom: <TableInfo<Table, Object?>>{db.bookEntries, db.bookGroups},
        )
        .get();
    if (aggRows.isEmpty) {
      return Paged<GroupHit>(items: <GroupHit>[], total: total, limit: filter.limit, offset: filter.offset);
    }
    final List<int> gids = aggRows.map((QueryRow r) => (r.data['gid']! as num).toInt()).toList();
    final List<QueryRow> bestRows = await db
        .customSelect(
          '$matchedCte '
          'SELECT $gidExpr AS gid, m.id AS entry_id, m.name AS name, m.name_norm AS name_norm, '
          'm.author AS author, m.snip AS snip, COALESCE(m.comment, \'\') AS comment, '
          '${_flagSql('m')} AS flag '
          'FROM matched m WHERE $gidExpr IN (${List<String>.filled(gids.length, '?').join(', ')}) '
          "ORDER BY gid, m.quality DESC, length(COALESCE(m.comment, '')) DESC, m.id",
          variables: <Variable<Object>>[...cteVars, for (final int g in gids) Variable<int>(g)],
          readsFrom: <TableInfo<Table, Object?>>{db.bookEntries},
        )
        .get();
    final Map<int, QueryRow> best = <int, QueryRow>{};
    for (final QueryRow r in bestRows) {
      best.putIfAbsent((r.data['gid']! as num).toInt(), () => r);
    }
    final List<GroupHit> items = <GroupHit>[];
    for (final QueryRow r in aggRows) {
      final int gid = (r.data['gid']! as num).toInt();
      final QueryRow? b = best[gid];
      final String? snip = b?.data['snip'] as String?;
      items.add(GroupHit(
        groupId: gid > 0 ? gid : null,
        name: (r.data['gname'] as String?) ?? (b?.data['name'] as String?) ?? (r.data['name_norm'] as String? ?? ''),
        nameNorm: (b?.data['name_norm'] as String?) ?? '',
        author: r.data['gauthor'] as String? ?? b?.data['author'] as String?,
        hitCount: (r.data['hits']! as num).toInt(),
        recommendCount: (r.data['rec']! as num).toInt(),
        avoidCount: (r.data['avoid']! as num).toInt(),
        latestDate: r.data['latest'] as String?,
        snippet: (snip == null || snip.isEmpty)
            ? buildExcerpt(b?.data['comment'] as String?, words)
            : snip,
        channels: ((r.data['chans'] as String?) ?? '').split(',').where((String s) => s.isNotEmpty).toList(),
        bestEntryId: (b?.data['entry_id'] as num?)?.toInt() ?? 0,
        bestFlag: (b?.data['flag'] as num?)?.toInt() ?? 0,
      ));
    }
    return Paged<GroupHit>(items: items, total: total, limit: filter.limit, offset: filter.offset);
  }

  // ── 帖子详情（§5.6）──

  @override
  Future<PostDetailData?> postDetail(int postId) async {
    final Post? post = await (db.select(db.posts)..where((Posts t) => t.id.equals(postId))).getSingleOrNull();
    if (post == null) {
      return null;
    }
    final List<Floor> floors = await (db.select(db.floors)
          ..where((Floors t) => t.postId.equals(postId))
          ..orderBy([(Floors t) => OrderingTerm.asc(t.seq), (Floors t) => OrderingTerm.asc(t.id)]))
        .get();
    final List<FloorImage> images = floors.isEmpty
        ? <FloorImage>[]
        : await db.customSelect(
            'SELECT * FROM images WHERE floor_id IN (${List<String>.filled(floors.length, '?').join(', ')}) ORDER BY id',
            variables: <Variable<Object>>[for (final Floor f in floors) Variable<int>(f.id)],
            readsFrom: <TableInfo<Table, Object?>>{db.images},
          ).map((QueryRow r) => db.images.map(r.data)).get();
    final Map<int, List<FloorImage>> byFloor = <int, List<FloorImage>>{};
    for (final FloorImage img in images) {
      byFloor.putIfAbsent(img.floorId, () => <FloorImage>[]).add(img);
    }
    final QueryRow counts = await db
        .customSelect(
          'SELECT COALESCE(SUM(${_flagSql()} = 1), 0) AS rec, COALESCE(SUM(${_flagSql()} = -1), 0) AS avoid '
          'FROM book_entries b WHERE b.post_ref = ?',
          variables: <Variable<Object>>[Variable<int>(postId)],
          readsFrom: <TableInfo<Table, Object?>>{db.bookEntries},
        )
        .getSingle();
    return PostDetailData(
      post: post,
      floors: <FloorData>[
        for (final Floor f in floors) FloorData(floor: f, images: byFloor[f.id] ?? const <FloorImage>[]),
      ],
      recommendCount: (counts.data['rec']! as num).toInt(),
      avoidCount: (counts.data['avoid']! as num).toInt(),
    );
  }

  // ── 书聚合（§5.5）──

  @override
  Future<BookDetailData?> bookDetail(int groupId) async {
    final BookGroup? group =
        await (db.select(db.bookGroups)..where((BookGroups t) => t.id.equals(groupId))).getSingleOrNull();
    if (group == null) {
      return null;
    }
    final QueryRow counts = await db
        .customSelect(
          'SELECT COALESCE(SUM(${_flagSql()} = 1), 0) AS rec, COALESCE(SUM(${_flagSql()} = -1), 0) AS avoid '
          'FROM book_entries b WHERE b.book_group_id = ?',
          variables: <Variable<Object>>[Variable<int>(groupId)],
          readsFrom: <TableInfo<Table, Object?>>{db.bookEntries},
        )
        .getSingle();
    return BookDetailData(
      group: group,
      recommendCount: (counts.data['rec']! as num).toInt(),
      avoidCount: (counts.data['avoid']! as num).toInt(),
    );
  }

  /// 评价列表：语义筛选 + 排序（质量↓默认）。
  @override
  Future<List<EntryRow>> bookEntries(int groupId, SemanticFilter filter, {EntrySort sort = EntrySort.qualityDesc}) {
    final String semantic = switch (filter) {
      SemanticFilter.all => '',
      SemanticFilter.recommend => ' AND (${_flagSql()}) = 1',
      SemanticFilter.avoid => ' AND (${_flagSql()}) = -1',
    };
    final String order = switch (sort) {
      EntrySort.qualityDesc => "b.quality DESC, length(COALESCE(b.comment, '')) DESC, b.date DESC, b.id DESC",
      EntrySort.timeDesc => 'b.date DESC, b.id DESC',
      EntrySort.timeAsc => 'b.date IS NULL, b.date ASC, b.id ASC',
      EntrySort.wordDesc => 'b.word_count IS NULL, b.word_count DESC, b.id DESC',
    };
    return db
        .customSelect(
          'SELECT $_entryCols FROM book_entries b WHERE b.book_group_id = ?$semantic ORDER BY $order',
          variables: <Variable<Object>>[Variable<int>(groupId)],
          readsFrom: <TableInfo<Table, Object?>>{db.bookEntries},
        )
        .map((QueryRow r) => EntryRow.fromRow(r))
        .get();
  }

  // ── 搜索台：联想与热门书名（§5.3）──

  /// 实时联想：book_groups.name_display 前缀 LIKE，≤[limit] 条。
  @override
  Future<List<String>> suggestBooks(String prefix, {int limit = 8}) async {
    final String p = prefix.trim();
    if (p.isEmpty) {
      return <String>[];
    }
    final List<QueryRow> rows = await db
        .customSelect(
          "SELECT name_display FROM book_groups WHERE name_display LIKE ? ESCAPE '\\' "
          'ORDER BY entry_total DESC, id LIMIT ?',
          variables: <Variable<Object>>[
            Variable<String>('${p.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%'),
            Variable<int>(limit),
          ],
          readsFrom: <TableInfo<Table, Object?>>{db.bookGroups},
        )
        .get();
    return rows.map((QueryRow r) => r.data['name_display']! as String).toList();
  }

  @override
  Future<List<HotBook>> hotBooks({int limit = 20}) {
    return db
        .customSelect(
          'SELECT id, name_norm, name_display, entry_total FROM book_groups '
          'ORDER BY entry_total DESC, id LIMIT ?',
          variables: <Variable<Object>>[Variable<int>(limit)],
          readsFrom: <TableInfo<Table, Object?>>{db.bookGroups},
        )
        .map((QueryRow r) => HotBook(
              nameNorm: r.data['name_norm']! as String,
              name: (r.data['name_display'] as String?) ?? (r.data['name_norm']! as String),
              entryTotal: (r.data['entry_total']! as num).toInt(),
              groupId: r.data['id'] as int?,
            ))
        .get();
  }

  // ── 搜索历史（§5.3：六维快照 CRUD）──

  @override
  Stream<List<SearchHistoryEntry>> watchHistory() {
    return (db.select(db.searchHistory)
          ..orderBy([(SearchHistory t) => OrderingTerm.desc(t.searchedAt), (SearchHistory t) => OrderingTerm.desc(t.id)])
          ..limit(50))
        .watch();
  }

  /// 记录一次提交：同条件去重（刷新时间），滚动保留 50 条。
  @override
  Future<void> addHistory(SearchFilter f) {
    return db.transaction(() async {
      await (db.delete(db.searchHistory)..where((SearchHistory t) =>
              t.query.equals(f.query) &
              t.year.equalsNullable(f.year) &
              t.month.equalsNullable(f.month) &
              t.tenDay.equalsNullable(f.tenDay) &
              t.channel.equalsNullable(f.channel) &
              t.category.equalsNullable(f.category)))
          .go();
      await db.into(db.searchHistory).insert(SearchHistoryCompanion.insert(
            query: Value<String>(f.query),
            year: Value<String?>(f.year),
            month: Value<String?>(f.month),
            tenDay: Value<String?>(f.tenDay),
            channel: Value<String?>(f.channel),
            category: Value<String?>(f.category),
            sort: Value<String>(f.sort.wire),
            searchedAt: DateTime.now(),
          ));
      await db.customStatement(
          'DELETE FROM search_history WHERE id NOT IN '
          '(SELECT id FROM search_history ORDER BY searched_at DESC, id DESC LIMIT 50)');
    });
  }

  @override
  Future<void> deleteHistory(int id) =>
      (db.delete(db.searchHistory)..where((SearchHistory t) => t.id.equals(id))).go();

  @override
  Future<void> clearHistory() => db.delete(db.searchHistory).go();

  // ── 书签（§5.6：六维快照 + 列表位置）与收藏（§5.5/§5.6 双粒度）──

  @override
  Stream<List<Bookmark>> watchBookmarks() {
    return (db.select(db.bookmarks)..orderBy([(Bookmarks t) => OrderingTerm.desc(t.createdAt)])).watch();
  }

  /// 添加/取消书签（同 postRef 已存在则移除）。返回操作后是否为已收藏态。
  @override
  Future<bool> togglePostBookmark({
    required int postRef,
    required String title,
    String? author,
    String? channel,
    int position = 0,
    SearchFilter? snapshot,
    String? note,
  }) async {
    final Bookmark? existing =
        await (db.select(db.bookmarks)..where((Bookmarks t) => t.postRef.equals(postRef))).getSingleOrNull();
    if (existing != null) {
      await (db.delete(db.bookmarks)..where((Bookmarks t) => t.id.equals(existing.id))).go();
      return false;
    }
    await db.into(db.bookmarks).insert(BookmarksCompanion.insert(
          postRef: Value<int>(postRef),
          title: title,
          author: Value<String?>(author),
          channel: Value<String?>(channel),
          position: Value<int>(position),
          snapQuery: Value<String?>(snapshot?.query),
          snapYear: Value<String?>(snapshot?.year),
          snapMonth: Value<String?>(snapshot?.month),
          snapTenDay: Value<String?>(snapshot?.tenDay),
          snapChannel: Value<String?>(snapshot?.channel),
          snapCategory: Value<String?>(snapshot?.category),
          snapSort: Value<String?>(snapshot?.sort.wire),
          note: Value<String?>(note),
          createdAt: DateTime.now(),
        ));
    return true;
  }

  @override
  Stream<List<Favorite>> watchFavorites() {
    return (db.select(db.favorites)..orderBy([(Favorites t) => OrderingTerm.desc(t.addedAt)])).watch();
  }

  /// 添加/取消收藏。返回操作后是否为已收藏态。
  @override
  Future<bool> toggleFavorite({
    required String targetType,
    required int targetId,
    required String title,
    String? subtitle,
  }) async {
    final Favorite? existing = await (db.select(db.favorites)
          ..where((Favorites t) => t.targetType.equals(targetType) & t.targetId.equals(targetId)))
        .getSingleOrNull();
    if (existing != null) {
      await (db.delete(db.favorites)..where((Favorites t) => t.id.equals(existing.id))).go();
      return false;
    }
    await db.into(db.favorites).insert(FavoritesCompanion.insert(
          targetType: targetType,
          targetId: targetId,
          title: title,
          subtitle: Value<String?>(subtitle),
          addedAt: DateTime.now(),
        ));
    return true;
  }
}

/// 领域层单例（§9.2：随 databaseProvider 注入）。
///
/// 静态类型是 [BookRepository] 而非 [Queries]：widget 测试用
/// `queriesProvider.overrideWithValue(FakeBookRepository())` 注入纯内存实现，
/// 使 testWidgets 假时钟区内不出现任何真实 IO（见 app/test/TESTING.md）。
final Provider<BookRepository> queriesProvider =
    Provider<BookRepository>((Ref ref) => Queries(ref.watch(appDatabaseProvider)));
