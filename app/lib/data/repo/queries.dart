import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../classify/src/engine.dart' show entryKindLabel, kRecommendKind;
import '../../core/constants.dart';
import '../db/app_database.dart';

// 数据访问层（M1-④）：首页时间线/热门榜、分类五维计数与浏览、六维搜索（FTS+LIKE 兜底）、
// 帖子/书聚合详情、历史/书签/收藏 CRUD。全部查询参数化（原型 §7.3，消灭字符串拼接缺陷）。
// 本文件纯 Dart（provider 接线在 queries_providers.dart），headless CLI 可直接构造 Queries。
// 维度取值编码与 search_history / bookmarks 快照列一致（原型 §7.2）。

// ───────────────────────── 维度取值编码 ─────────────────────────

/// 排序（search_history.sort / bookmarks.snap_sort 编码）。
enum SearchSort {
  timeDesc('time_desc'),
  timeAsc('time_asc');

  const SearchSort(this.wire);
  final String wire;

  static SearchSort fromWire(String? wire) => SearchSort.values.firstWhere(
    (SearchSort s) => s.wire == wire,
    orElse: () => SearchSort.timeDesc,
  );
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
  static const List<String> otherBigMembers = <String>[
    '大佬贴吧扫书',
    '大佬专栏',
    '丫丫书屋',
    '龙空论坛',
  ];

  /// 具名渠道（搜索台来源维完整取值）。
  static const List<String> named = <String>[
    'yy小说吧',
    '哀伤雪刃',
    '雪群推书',
    '大佬贴吧扫书',
    '大佬专栏',
    '丫丫书屋',
    '龙空论坛',
    '两吧',
  ];

  /// 分类页来源维展示序（§5.12：yy/哀伤/雪群/两吧 具名，其余并为「其他」）。
  static const List<String> categoryNamed = <String>[
    'yy小说吧',
    '哀伤雪刃',
    '雪群推书',
    '两吧',
  ];
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

/// 书聚合页语义筛选（原型 §5.5：全部/仅扫书/仅推荐/仅排雷）。
enum SemanticFilter { all, scan, recommend, avoid }

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

/// **条目级**推荐语义：只认原帖的颜色标记（book_grade），无标记时只有「排雷」类算负面。
/// +1=推荐（book_grade 绿）/ −1=排雷（book_grade 红，或无标记但 category=排雷）/ 0=中性。
///
/// 为什么不再由 category=扫书 派生推荐：扫书帖内绝大多数条目只是「被扫到」，并没有
/// 原帖的背书颜色；把它们一律算推荐会让 24,564 条无标扫书虚增推荐数（用户拍板口径）。
int entryFlagOf({required String category, String? bookGrade}) {
  switch (bookGrade) {
    case '#11850A':
      return 1;
    case '#FF0000':
      return -1;
    default:
      // 其它非空 grade（如大佬存量的 '#000000'）= 有标记但非绿非红 → 中性，不再回落 category。
      if (bookGrade != null && bookGrade.isNotEmpty) {
        return 0;
      }
  }
  // grade 为空：只有「排雷」类算负面；扫书/求书/日常一律中性。
  return category == CategoryKind.avoid ? -1 : 0;
}

/// 上述规则的 SQL 内联等价式（别名列直查，供聚合/筛选用）。
/// **必须与 [entryFlagOf] 逐条一致**：Dart 侧口径表驱动见 test/data/entry_flag_test.dart，
/// SQL↔Dart 逐组对账见 features_test.dart「书聚合：计数对比」用例。
String _flagSql([String alias = 'b']) =>
    '''CASE
  WHEN $alias.book_grade = '#11850A' THEN 1
  WHEN $alias.book_grade = '#FF0000' THEN -1
  WHEN $alias.book_grade IS NOT NULL AND $alias.book_grade != '' THEN 0
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
  int get hashCode => Object.hash(
    query,
    year,
    month,
    tenDay,
    channel,
    category,
    sort,
    limit,
    offset,
  );
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
  const CategorySelection({
    this.year,
    this.month,
    this.tenDay,
    this.channel,
    this.category,
  });

  final String? year;
  final String? month;
  final String? tenDay;
  final String? channel;
  final String? category;

  bool get isEmpty =>
      year == null &&
      month == null &&
      tenDay == null &&
      channel == null &&
      category == null;

  static const CategorySelection empty = CategorySelection();

  /// 点值 chip：单选；再次点已选值 = 取消回「全部」。
  CategorySelection toggled(CategoryDim dim, String value) {
    String? pick(String? current) => current == value ? null : value;
    return switch (dim) {
      CategoryDim.year => CategorySelection(
        year: pick(year),
        month: month,
        tenDay: tenDay,
        channel: channel,
        category: category,
      ),
      CategoryDim.month => CategorySelection(
        year: year,
        month: pick(month),
        tenDay: tenDay,
        channel: channel,
        category: category,
      ),
      CategoryDim.tenDay => CategorySelection(
        year: year,
        month: month,
        tenDay: pick(tenDay),
        channel: channel,
        category: category,
      ),
      CategoryDim.channel => CategorySelection(
        year: year,
        month: month,
        tenDay: tenDay,
        channel: pick(channel),
        category: category,
      ),
      CategoryDim.category => CategorySelection(
        year: year,
        month: month,
        tenDay: tenDay,
        channel: channel,
        category: pick(category),
      ),
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
  SearchFilter toFilter({
    SearchSort sort = SearchSort.timeDesc,
    int limit = 40,
    int offset = 0,
  }) {
    return SearchFilter(
      year: year,
      month: month,
      tenDay: tenDay,
      channel: channel,
      category: category,
      sort: sort,
      limit: limit,
      offset: offset,
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
    this.floorSeq,
    this.floorText,
    this.bookGroupId,
    this.srcUrl,
    this.postTitle,
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
      floorSeq: d['floor_seq'] as int?,
      floorText: d['floor_text'] as String?,
      bookGroupId: d['book_group_id'] as int?,
      srcUrl: d['src_url'] as String?,
      postTitle: d['post_title'] as String?,
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

  /// 条目所在楼层号（LEFT JOIN floors；null = 无楼层溯源，点击只进帖不定位）。
  final int? floorSeq;

  /// 条目所在楼层正文（LEFT JOIN floors；评论列为空时卡片预览回退用它，null = 无楼层）。
  final String? floorText;
  final int? bookGroupId;
  final String? srcUrl;

  /// 所属帖标题（LEFT JOIN posts；null = 散条目/无帖溯源）——[kindLabel] 的判定输入。
  final String? postTitle;

  /// 搜索命中摘要（`[词]` 标记；FTS snippet 或 LIKE 兜底自拼）。
  final String? snippet;

  /// 卡片正文预览原文：优先 [comment]（条目级评语），空则回退 [floorText]（整层正文）。
  /// 种子库有 4169 条 comment 为空但楼层正文在场——不回退会让书聚合卡片正文空白。
  String? get previewSource => _previewSourceOf(comment, floorText);

  /// 推荐语义（§8.9）：+1 推荐 / −1 排雷 / 0 中性。
  int get recommendFlag =>
      entryFlagOf(category: category, bookGrade: bookGrade);

  /// 三分类型（扫书 / 推书 / 排雷）：书卡计数、页头 CountTrio 与「仅推荐/仅排雷」筛选同源，
  /// 判定见 [entryKindLabel]（标记优先，其次标题，再类别）。
  String get kindLabel =>
      entryKindLabel(category: category, flag: recommendFlag, title: postTitle);
}

/// 首页卡片书名 chip。
class BookChip {
  const BookChip({
    required this.name,
    required this.nameNorm,
    this.bookGroupId,
  });

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
    required this.scanCount,
    required this.recommendCount,
    required this.avoidCount,
    this.latestDate,
    this.snippet,
    this.preview,
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

  /// 三分计数（扫书 / 推书 / 排雷）：按该书**全部条目**计，判定见 [entryKindLabel]。
  /// 书卡「x扫书 x推荐 x排雷」与书聚合页头同源；「仅推荐/仅排雷」筛选也走这三分。
  final int scanCount;
  final int recommendCount;
  final int avoidCount;
  final String? latestDate;
  final String? snippet;

  /// 卡片正文预览（标题下）：snippet 命中高亮优先，无则取最佳条目评语/楼层正文
  /// （100 字截断，用户口径）。null = 该书确实没有可展示的正文。
  final String? preview;
  final List<String> channels;
  final int bestEntryId;
  final int bestFlag;
}

/// 分页结果。
class Paged<T> {
  const Paged({
    required this.items,
    required this.total,
    this.limit = 0,
    this.offset = 0,
  });

  final List<T> items;
  final int total;
  final int limit;
  final int offset;

  bool get hasMore => limit > 0 && offset + items.length < total;
}

/// 搜索产物：结果页 + 检索路径标记（FTS / LIKE 兜底 / FTS 异常降级，§7.3）。
class SearchOutcome {
  const SearchOutcome({
    required this.page,
    this.usedFts = false,
    this.degraded = false,
    this.words = const <String>[],
  });

  final Paged<GroupHit> page;
  final bool usedFts;

  /// FTS 查询异常自动降级 LIKE（UI SnackBar「已降级为慢速搜索」，§5.3）。
  final bool degraded;
  final List<String> words;

  static const SearchOutcome empty = SearchOutcome(
    page: Paged<GroupHit>(items: <GroupHit>[], total: 0),
  );
}

/// 楼层（含图片）。
class FloorData {
  const FloorData({required this.floor, required this.images});

  final Floor floor;
  final List<FloorImage> images;
}

/// 帖内提及书目的全站推荐/排雷次数（按该书全部条目计，三分口径同 [Queries.kindCountsOf]：
/// 颜色标记 → 帖标题推书/排雷词 → 类别，与书卡/书聚合页计数同源）。
class PostBookCount {
  const PostBookCount({
    required this.groupId,
    required this.name,
    required this.recommend,
    required this.avoid,
  });

  /// book_groups.id（缺组行时为 null，chip 不可点）。
  final int? groupId;
  final String name;
  final int recommend;
  final int avoid;
}

/// 帖子详情聚合（头部书目 chips = 帖内提及书的按帖推荐/排雷次数）。
class PostDetailData {
  const PostDetailData({
    required this.post,
    required this.floors,
    required this.books,
  });

  final Post post;
  final List<FloorData> floors;
  final List<PostBookCount> books;
}

/// 书聚合详情头部。
class BookDetailData {
  const BookDetailData({
    required this.group,
    required this.scanCount,
    required this.recommendCount,
    required this.avoidCount,
  });

  final BookGroup group;

  /// 三分计数（扫书 / 推书 / 排雷）：页头 CountTrio 与「仅推荐/仅排雷」筛选同源，
  /// 判定见 [entryKindLabel]。
  final int scanCount;
  final int recommendCount;
  final int avoidCount;

  int get entryTotal => group.entryTotal;
}

/// 维度值 + 真实命中计数（§5.12 诚实标注）。
class DimCount {
  const DimCount({
    required this.value,
    required this.label,
    required this.count,
  });

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
  const HotBook({
    required this.nameNorm,
    required this.name,
    required this.entryTotal,
    this.groupId,
  });

  final String nameNorm;
  final String name;
  final int entryTotal;
  final int? groupId;
}

/// 卡片摘要（首页时间线 / 书聚合评价卡 / 搜索结果卡「标题下正文」）：换行/连续空白
/// 压平成单空格，超过 [maxChars] 中文字符截断加「…」。上限定为 100（用户口径）。
/// 与 export 层 summarizeComment 同族但**不复用**（Queries 须保持纯 Dart、不 import
/// features/ 的 Flutter 依赖）。
const int kCardSummaryMaxChars = AppConstants.previewMaxChars;

String? summarizeCardText(String? text, {int maxChars = kCardSummaryMaxChars}) {
  final String flat = (text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.isEmpty) {
    return null;
  }
  final List<int> runes = flat.runes.toList();
  return runes.length > maxChars
      ? '${String.fromCharCodes(runes.take(maxChars))}…'
      : flat;
}

/// 预览原文选择：评语非空用评语，否则回退楼层正文（与 [EntryRow.previewSource] 同口径）。
String? _previewSourceOf(String? comment, String? floorText) {
  if (comment != null && comment.trim().isNotEmpty) {
    return comment;
  }
  return (floorText != null && floorText.trim().isNotEmpty) ? floorText : null;
}

/// 关键词分词（空格分词，全命中 AND；继承扫书 queryPosts 语义）。
List<String> tokenizeQuery(String query) => query
    .trim()
    .split(RegExp(r'\s+'))
    .where((String w) => w.isNotEmpty)
    .toList();

/// LIKE 兜底摘要：以首个命中词为中心截窗，`[词]` 标记与 FTS snippet 同约定。
///
/// [prefer]：**优先锚点**（书级检索第一级用，见 [Queries.searchBooks]）。命中发生在
/// 书名/作者列时，摘要应当围绕该书书名在整层正文里截窗——查询词未必出现在 comment 里，
/// 而 comment 是整个楼层共用的正文，随便截一段就是无关内容。锚点取 [prefer] 中最早出现者；
/// [prefer] 全部落空才退回 [words]。
///
/// [nullWhenUnanchored]：锚点与命中词都不在 text 里时返回 null（不再截 text 开头）——
/// 第一级宁可不出摘要，也不给书名命中的书配一段无关楼层文字。
String? buildExcerpt(
  String? text,
  List<String> words, {
  int radius = 14,
  List<String> prefer = const <String>[],
  bool nullWhenUnanchored = false,
}) {
  if (text == null || text.isEmpty) {
    return null;
  }
  final String lower = text.toLowerCase();
  int idx = -1;
  int hitLen = 0;
  void scan(List<String> terms) {
    for (final String w in terms) {
      if (w.isEmpty) {
        continue;
      }
      final int i = lower.indexOf(w.toLowerCase());
      if (i >= 0 && (idx < 0 || i < idx)) {
        idx = i;
        hitLen = w.length;
      }
    }
  }

  scan(prefer);
  if (idx < 0) {
    scan(words);
  }
  if (idx < 0) {
    if (nullWhenUnanchored) {
      return null;
    }
    return text.length > radius * 2
        ? '${text.substring(0, radius * 2)}…'
        : text;
  }
  final int start = math.max(0, idx - radius);
  final int end = math.min(text.length, idx + hitLen + radius);
  return '${start > 0 ? '…' : ''}${text.substring(start, idx)}'
      '[${text.substring(idx, idx + hitLen)}]'
      '${text.substring(idx + hitLen, end)}${end < text.length ? '…' : ''}';
}

/// 书名锚点候选（[buildExcerpt] 的 prefer 入参）：书名在库里可能带/不带书名号，
/// 两种写法都试一遍，命中哪种就按哪种截窗（顺序 = 优先序，带书名号者在前）。
List<String> _nameAnchors(Iterable<String?> names) {
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

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ───────────────────────── 数据访问契约 ─────────────────────────

/// settings 表 KV 读写端口（搜索结果浏览位置记忆用；消费方见
/// `features/search/search_state.dart` 的 `SearchPositionStore`）。
///
/// 单列一个端口而不并进 [BookRepository]：位置记忆只是搜索页的旁路能力，而 widget
/// 测试注入的内存仓不带 settings 表——并进主契约会逼所有实现方都造 KV；按需
/// `repo is SearchSettingsKv` 判定即可在测试挂具下优雅降级成「不记忆」。
abstract interface class SearchSettingsKv {
  /// 读 settings KV（不存在返回 null）。
  Future<String?> readSetting(String key);

  /// 写 settings KV（UPSERT）。
  Future<void> writeSetting(String key, String value);
}

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
  Future<List<PostCardData>> timelinePosts({
    required int limit,
    int offset = 0,
  });

  /// 自采新内容红点计数（collection_state.new_since_visit 之和）。
  Stream<int> watchNewContentCount();

  /// 热门榜（§5.13：按 [window] 时段内推荐次数重排）。
  Future<List<RankRow>> rankRows(
    RankWindow window, {
    DateTime? today,
    int limit = 10,
  });

  /// 字数榜（§5.13：word_count IS NOT NULL 的库B子集，MAX(word_count) 降序，
  /// 时段过滤与 [rankRows] 同构；[RankRow.count] 承载字数值）。
  Future<List<RankRow>> wordRankRows(
    RankWindow window, {
    DateTime? today,
    int limit = 10,
  });

  /// 内置库数据截至日（榜单页脚「数据截至 …」）。
  Future<String?> dataCutoff();

  /// 随机书荒（P1-3）。
  Future<List<EntryRow>> randomBooks(int count);

  /// 五维真实命中计数（§5.12）。
  Future<CategoryCounts> dimensionCounts();

  /// 搜索页六维联动计数（§5.3）：每维用「除自身外」的已选条件过滤后统计候选命中数。
  Future<CategoryCounts> searchDimensionCounts(SearchFilter f);

  /// 分类页选中即时过滤：交集条数 + 预览前 N。
  Future<CategoryPreview> categoryPreview(
    CategorySelection sel, {
    int limit = 5,
  });

  /// 六维搜索（§7.3：≥3 字走 FTS，2 字词 LIKE 兜底）。
  Future<SearchOutcome> searchBooks(SearchFilter f);

  /// 帖子详情（§5.6：楼层流 + 推荐/排雷计数对比）。
  Future<PostDetailData?> postDetail(int postId);

  /// 书聚合详情头（§5.5）。
  Future<BookDetailData?> bookDetail(int groupId);

  /// 书聚合评价列表（语义筛选 × 排序）。
  Future<List<EntryRow>> bookEntries(
    int groupId,
    SemanticFilter filter, {
    EntrySort sort = EntrySort.qualityDesc,
  });

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

    /// 帖子内阅读楼层号（schema v3；null = 无楼层记忆，旧书签语义）。
    int? floorSeq,
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
class Queries implements BookRepository, SearchSettingsKv {
  const Queries(this.db);

  final AppDatabase db;

  static const String _entryCols =
      'b.id, b.name, b.name_norm, b.author, b.recommender, b.comment, b.date, b.channel, '
      'b.sub_channel, b.category, b.book_grade, b.origin, b.quality, b.word_count, '
      'b.post_ref, b.floor_ref, b.book_group_id, b.src_url, fl.seq AS floor_seq, '
      'fl.text AS floor_text, p.title AS post_title';

  /// [EntryRow] 投影的 FROM 段：LEFT JOIN floors 取楼层号（书聚合页点卡片直达楼层）、
  /// LEFT JOIN posts 取帖标题（三分类型 [EntryRow.kindLabel] 的判定输入）。
  static const String _entryFrom =
      ' FROM book_entries b LEFT JOIN floors fl ON fl.id = b.floor_ref '
      'LEFT JOIN posts p ON p.id = b.post_ref';

  // ── 首页：时间线（§5.2）──

  /// 最新扫书帖卡片流（扫书+排雷帖；日期倒序分页），关联书名 chips（前 4 + 总数）。
  @override
  Future<List<PostCardData>> timelinePosts({
    required int limit,
    int offset = 0,
  }) async {
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
          variables: <Variable<Object>>[
            for (final int id in ids) Variable<int>(id),
          ],
          readsFrom: <TableInfo<Table, Object?>>{db.bookEntries},
        )
        .get();
    final Map<int, List<BookChip>> chips = <int, List<BookChip>>{};
    final Map<int, int> counts = <int, int>{};
    final Map<int, String> summaries = <int, String>{};
    for (final QueryRow r in entryRows) {
      final int postRef = r.data['post_ref']! as int;
      counts[postRef] = (counts[postRef] ?? 0) + 1;
      final List<BookChip> list = chips.putIfAbsent(
        postRef,
        () => <BookChip>[],
      );
      if (list.length < 4) {
        list.add(
          BookChip(
            name: r.data['name']! as String,
            nameNorm: r.data['name_norm']! as String,
            bookGroupId: r.data['book_group_id'] as int?,
          ),
        );
      }
      final String? comment = r.data['comment'] as String?;
      if (comment != null &&
          comment.trim().isNotEmpty &&
          !summaries.containsKey(postRef)) {
        summaries[postRef] = summarizeCardText(comment) ?? '';
      }
    }
    // 无条目（纯楼层扫书帖：帖子只有楼层正文、没有 book_entries 行，如「为什么没人推」帖）
    // → 回落取该帖正文最长的楼层文本作摘要，避免首页卡片只剩标题、看不到任何正文。
    final List<int> needSummary = <int>[
      for (final Post p in posts)
        if (!summaries.containsKey(p.id)) p.id,
    ];
    if (needSummary.isNotEmpty) {
      final String sHoles = List<String>.filled(needSummary.length, '?').join(', ');
      final List<QueryRow> floorRows = await db
          .customSelect(
            'SELECT post_id, text FROM floors WHERE post_id IN ($sHoles) '
            "AND length(trim(text)) > 0 ORDER BY length(text) DESC",
            variables: <Variable<Object>>[
              for (final int id in needSummary) Variable<int>(id),
            ],
            readsFrom: <TableInfo<Table, Object?>>{db.floors},
          )
          .get();
      for (final QueryRow r in floorRows) {
        final int postRef = r.data['post_id']! as int;
        summaries.putIfAbsent(postRef, () => summarizeCardText(r.data['text'] as String?) ?? '');
      }
    }
    return <PostCardData>[
      for (final Post p in posts)
        PostCardData(
          post: p,
          books: chips[p.id] ?? const <BookChip>[],
          entryCount: counts[p.id] ?? 0,
          summary: (summaries[p.id] ?? '').isEmpty ? null : summaries[p.id],
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

  /// 榜单行共用投影（LEFT JOIN book_groups 取显示名/作者/组 id，§5.13）。
  static RankRow _rankRowOf(QueryRow r) => RankRow(
    nameNorm: r.data['name_norm']! as String,
    name: (r.data['name'] as String?) ?? (r.data['name_norm']! as String),
    author: r.data['author'] as String?,
    count: (r.data['cnt']! as num).toInt(),
    bookGroupId: r.data['gid'] as int?,
  );

  /// 榜单查询参数装配：时段下限（全时段省略）+ limit。
  static List<Variable<Object>> _rankVars(String? from, int limit) {
    final List<Variable<Object>> vars = <Variable<Object>>[];
    if (from != null) {
      vars.add(Variable<String>(from));
    }
    vars.add(Variable<int>(limit));
    return vars;
  }

  @override
  Future<List<RankRow>> rankRows(
    RankWindow window, {
    DateTime? today,
    int limit = 10,
  }) {
    final String? from = rankFromDate(window, today ?? DateTime.now());
    return db
        .customSelect(
          'SELECT b.name_norm AS name_norm, COUNT(*) AS cnt, '
          'MAX(g.name_display) AS name, MAX(g.author_display) AS author, MAX(g.id) AS gid '
          'FROM book_entries b LEFT JOIN book_groups g ON g.name_norm = b.name_norm '
          'WHERE b.date IS NOT NULL${from == null ? '' : ' AND b.date >= ?'} '
          'GROUP BY b.name_norm ORDER BY cnt DESC, b.name_norm LIMIT ?',
          variables: _rankVars(from, limit),
          readsFrom: <TableInfo<Table, Object?>>{db.bookEntries, db.bookGroups},
        )
        .map(_rankRowOf)
        .get();
  }

  @override
  Future<List<RankRow>> wordRankRows(
    RankWindow window, {
    DateTime? today,
    int limit = 10,
  }) {
    // 字数榜（库B子集）：同构查询，过滤 word_count IS NOT NULL，MAX(word_count) 降序（§5.13）。
    final String? from = rankFromDate(window, today ?? DateTime.now());
    return db
        .customSelect(
          'SELECT b.name_norm AS name_norm, MAX(b.word_count) AS cnt, '
          'MAX(g.name_display) AS name, MAX(g.author_display) AS author, MAX(g.id) AS gid '
          'FROM book_entries b LEFT JOIN book_groups g ON g.name_norm = b.name_norm '
          'WHERE b.word_count IS NOT NULL AND b.date IS NOT NULL'
          '${from == null ? '' : ' AND b.date >= ?'} '
          'GROUP BY b.name_norm ORDER BY cnt DESC, b.name_norm LIMIT ?',
          variables: _rankVars(from, limit),
          readsFrom: <TableInfo<Table, Object?>>{db.bookEntries, db.bookGroups},
        )
        .map(_rankRowOf)
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
          'SELECT $_entryCols$_entryFrom '
          "WHERE b.category = ? AND b.comment IS NOT NULL AND length(b.comment) >= 20 "
          'ORDER BY RANDOM() LIMIT ?',
          variables: <Variable<Object>>[
            Variable<String>(CategoryKind.scan),
            Variable<int>(count),
          ],
          readsFrom: <TableInfo<Table, Object?>>{db.bookEntries, db.floors},
        )
        .map((QueryRow r) => EntryRow.fromRow(r))
        .get();
  }

  // ── 分类页：五维计数与浏览（§5.12，不依赖 FTS）──

  @override
  Future<CategoryCounts> dimensionCounts() async {
    Future<List<QueryRow>> q(String sql) => db
        .customSelect(
          sql,
          readsFrom: <TableInfo<Table, Object?>>{db.bookEntries},
        )
        .get();

    final int total =
        ((await q('SELECT COUNT(*) AS c FROM book_entries')).single.data['c']!
                as num)
            .toInt();

    // 年：GROUP BY substr(date,1,4)，≤2016 并为「更早」。
    final List<QueryRow> yearRows = await q(
      "SELECT substr(date,1,4) AS v, COUNT(*) AS c FROM book_entries WHERE date IS NOT NULL GROUP BY v ORDER BY v DESC",
    );
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
      years.add(
        DimCount(value: YearFilter.early, label: '更早', count: earlyCount),
      );
    }

    // 月：固定 1–12 全列（缺失月计 0，诚实标注）。
    final Map<int, int> monthCounts = <int, int>{};
    for (final QueryRow r in await q(
      'SELECT CAST(substr(date,6,2) AS INTEGER) AS v, COUNT(*) AS c FROM book_entries WHERE date IS NOT NULL GROUP BY v',
    )) {
      monthCounts[(r.data['v']! as num).toInt()] = (r.data['c']! as num)
          .toInt();
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
      'COUNT(*) AS c FROM book_entries WHERE date IS NOT NULL GROUP BY v',
    )) {
      tenCounts[r.data['v']! as String] = (r.data['c']! as num).toInt();
    }
    final List<DimCount> tenDays = <DimCount>[
      DimCount(
        value: TenDayFilter.upper,
        label: '上旬',
        count: tenCounts[TenDayFilter.upper] ?? 0,
      ),
      DimCount(
        value: TenDayFilter.middle,
        label: '中旬',
        count: tenCounts[TenDayFilter.middle] ?? 0,
      ),
      DimCount(
        value: TenDayFilter.lower,
        label: '下旬',
        count: tenCounts[TenDayFilter.lower] ?? 0,
      ),
    ];

    // 来源：具名四渠道 + 「其他」聚合（§5.12 口径）。
    final Map<String, int> channelCounts = <String, int>{};
    for (final QueryRow r in await q(
      'SELECT channel AS v, COUNT(*) AS c FROM book_entries GROUP BY v',
    )) {
      channelCounts[r.data['v']! as String] = (r.data['c']! as num).toInt();
    }
    int otherCount = 0;
    final List<DimCount> channels = <DimCount>[];
    for (final String name in ChannelFilter.categoryNamed) {
      channels.add(
        DimCount(value: name, label: name, count: channelCounts[name] ?? 0),
      );
    }
    channelCounts.forEach((String name, int c) {
      if (ChannelFilter.otherBigMembers.contains(name)) {
        otherCount += c;
      }
    });
    channels.add(
      DimCount(value: ChannelFilter.otherBig, label: '其他', count: otherCount),
    );

    // 类别：固定枚举序（排雷为规则回填，计数可为 0 仍展示）。
    final Map<String, int> catCounts = <String, int>{};
    for (final QueryRow r in await q(
      'SELECT category AS v, COUNT(*) AS c FROM book_entries GROUP BY v',
    )) {
      catCounts[r.data['v']! as String] = (r.data['c']! as num).toInt();
    }
    final List<DimCount> categories = <DimCount>[
      for (final String k in CategoryKind.all)
        DimCount(value: k, label: k, count: catCounts[k] ?? 0),
    ];

    return CategoryCounts(
      total: total,
      years: years,
      months: months,
      tenDays: tenDays,
      channels: channels,
      categories: categories,
    );
  }

  /// 选中即时过滤：交集真实条数 + 预览前 [limit] 条书级卡（§5.12）。
  @override
  Future<CategoryPreview> categoryPreview(
    CategorySelection sel, {
    int limit = 5,
  }) async {
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
          'SELECT $_entryCols$_entryFrom WHERE 1 = 1$dims '
          'ORDER BY b.date DESC, b.id DESC LIMIT ?',
          variables: <Variable<Object>>[...vars, Variable<int>(limit)],
          readsFrom: <TableInfo<Table, Object?>>{db.bookEntries, db.floors},
        )
        .map((QueryRow r) => EntryRow.fromRow(r))
        .get();
    return CategoryPreview(
      count: (countRow.data['c']! as num).toInt(),
      entries: entries,
    );
  }

  // ── 搜索（§7.3：≥3 字 FTS trigram，2 字词 LIKE 兜底，FTS 异常降级）──

  /// 六维搜索（两级检索）。
  ///
  /// 为什么要分级（真机反馈修复）：book_entries.comment 存的是**整层帖子正文**——
  /// 一个扫书楼里的所有书共用同一段 comment，让它直接参与匹配就会把同楼的其它书
  /// 一并召回（搜「我一个护林员」连《从气运词条开始成就人皇》《从红楼开始纵横武侠世界》
  /// 都出来，而且每张卡是同一段高亮摘要）。故：
  ///  · 第一级：只匹配书名/作者（FTS 用列过滤 {name author}，LIKE 用四列
  ///    name/name_norm/author/author_norm）；有命中就地收口，不再看正文。
  ///  · 第二级（第一级零命中）：维持现状全列匹配（含 recommender/comment），
  ///    保住「按推荐语/推荐人找书」这类真实召回。
  /// 摘要口径同样分级：第一级以**该书书名**为锚在 comment 上截窗（[_groupedPage]），
  /// 且不让 FTS 的 snippet(comment) 生效——列过滤下 snippet 会退回 comment 开头，
  /// 给书名命中的书配一段无关楼层文字。
  @override
  Future<SearchOutcome> searchBooks(SearchFilter f) async {
    final List<String> words = tokenizeQuery(f.query);
    if (words.isEmpty) {
      return SearchOutcome(page: await _browseGroups(f), words: words);
    }
    if (words.every((String w) => w.runes.length >= 3)) {
      // ── 第一级：仅书名/作者列（fts5 列过滤语法；trigram 分词器实测支持）──
      final SearchOutcome titleLevel = await _titleLevelFts(words, f);
      if (titleLevel.page.total > 0) {
        return titleLevel;
      }
      // ── 第二级：评语 / 楼层正文（角色名、楼内提及都走这里）──
      final String match = words
          .map((String w) => '"${w.replaceAll('"', '""')}"')
          .join(' AND ');
      final SearchOutcome fts;
      try {
        fts = SearchOutcome(
          page: await _ftsGroups(match, words, f),
          usedFts: true,
          words: words,
        );
      } on Object {
        // FTS 查询异常自动降级 LIKE（§5.3 错误态）。
        return SearchOutcome(
          page: await _likeGroups(words, f),
          degraded: true,
          words: words,
        );
      }
      if (fts.page.total > 0) {
        return fts;
      }
      // FTS 零命中 → LIKE 兜底重试（含 *_norm 列 + 楼层正文）：trigram 索引建在原文上，
      // 归一化书名查询（无标点）会因标点差异零召回——含标点书名占 20.6%，
      // norm 词采样零命中 86%（实测见 docs/质量预算复核.md F-2）。
      // 置于 try 外：重试自身的异常按未预期错误传播，不误用「FTS 降级」语义。
      return SearchOutcome(page: await _likeGroups(words, f), words: words);
    }
    // 含 2 字词（trigram 恒零命中）：第一级四列 LIKE → 零命中才放开到全列。
    final Paged<GroupHit> titleLevel = await _likeGroups(
      words,
      f,
      titleOnly: true,
    );
    if (titleLevel.total > 0) {
      return SearchOutcome(page: titleLevel, words: words);
    }
    return SearchOutcome(page: await _likeGroups(words, f), words: words);
  }

  /// 第一级（仅书名/作者）的 FTS 路径：fts5 列过滤语法 {name author} : "词"，多词 AND。
  /// 列过滤不可用（老 SQLite / MATCH 语法异常）时退回四列 LIKE，并如实记 degraded
  /// （UI 出「已降级为慢速搜索」）。抽成方法而非内联 try/catch：Dart 的 final 局部变量
  /// 不允许在 try 与 catch 两个分支里各赋值一次（catch 入口处按「可能已赋值」处理）。
  Future<SearchOutcome> _titleLevelFts(
    List<String> words,
    SearchFilter f,
  ) async {
    final String titleMatch = words
        .map((String w) => '{name author} : "${w.replaceAll('"', '""')}"')
        .join(' AND ');
    try {
      return SearchOutcome(
        page: await _ftsGroups(titleMatch, words, f, titleOnly: true),
        usedFts: true,
        words: words,
      );
    } on Object {
      return SearchOutcome(
        page: await _likeGroups(words, f, titleOnly: true),
        degraded: true,
        words: words,
      );
    }
  }

  // ── settings KV（搜索结果浏览位置记忆；复用既有 settings 表，不新造表）──

  @override
  Future<String?> readSetting(String key) async {
    final Setting? row = await (db.select(
      db.settings,
    )..where((Settings t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> writeSetting(String key, String value) => db
      .into(db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  /// 维度筛选 SQL 片段（全部参数化；变量按出现序追加进 [vars]）。
  ///
  /// [except] = 计算该维度自身的候选计数时忽略它（联动口径：月份计数应受「年」筛选影响，
  /// 但不受「月」自身选择影响）——见 [searchDimensionCounts]。
  String _dimClauses(
    SearchFilter f,
    List<Variable<Object>> vars, {
    CategoryDim? except,
  }) {
    final StringBuffer sql = StringBuffer();
    if (except != CategoryDim.year) {
      if (f.year == YearFilter.early) {
        sql.write(
          ' AND CAST(substr(b.date,1,4) AS INTEGER) <= ${YearFilter.earlyMaxYear}',
        );
      } else if (f.year != null) {
        sql.write(' AND substr(b.date,1,4) = ?');
        vars.add(Variable<String>(f.year!));
      }
    }
    if (except != CategoryDim.month && f.month != null) {
      sql.write(' AND CAST(substr(b.date,6,2) AS INTEGER) = ?');
      vars.add(Variable<int>(int.parse(f.month!)));
    }
    if (except != CategoryDim.tenDay) {
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
    }
    if (except != CategoryDim.channel) {
      switch (f.channel) {
        case ChannelFilter.otherSmall:
          sql.write(
            ' AND b.channel IN (${List<String>.filled(ChannelFilter.otherSmallMembers.length, '?').join(', ')})',
          );
          vars.addAll(ChannelFilter.otherSmallMembers.map(Variable<String>.new));
        case ChannelFilter.otherBig:
          sql.write(
            ' AND b.channel IN (${List<String>.filled(ChannelFilter.otherBigMembers.length, '?').join(', ')})',
          );
          vars.addAll(ChannelFilter.otherBigMembers.map(Variable<String>.new));
        case ChannelFilter.collected:
          sql.write(" AND b.origin = 'collected'");
        case final String named?:
          sql.write(' AND b.channel = ?');
          vars.add(Variable<String>(named));
        case null:
          break;
      }
    }
    if (except != CategoryDim.category && f.category != null) {
      sql.write(' AND b.category = ?');
      vars.add(Variable<String>(f.category!));
    }
    return sql.toString();
  }

  /// 搜索页六维「联动计数」（§5.3）：对每个维度 D，用**除 D 外**的已选条件过滤后统计
  /// 各候选值命中数 —— 选 2026 年后，月份候选计数随之只反映 2026 年；反之亦然。
  /// 全空条件时等价于全局 [dimensionCounts]。
  @override
  Future<CategoryCounts> searchDimensionCounts(SearchFilter f) async {
    Future<int> countFor(CategoryDim dim) async {
      final List<Variable<Object>> vars = <Variable<Object>>[];
      final String dims = _dimClauses(f, vars, except: dim);
      final QueryRow r = await db
          .customSelect(
            'SELECT COUNT(*) AS c FROM book_entries b WHERE 1 = 1$dims',
            variables: vars,
            readsFrom: <TableInfo<Table, Object?>>{db.bookEntries},
          )
          .getSingle();
      return (r.data['c']! as num).toInt();
    }

    Future<Map<String, int>> groupFor(CategoryDim dim, String vExpr) async {
      final List<Variable<Object>> vars = <Variable<Object>>[];
      final String dims = _dimClauses(f, vars, except: dim);
      final List<QueryRow> rows = await db
          .customSelect(
            'SELECT $vExpr AS v, COUNT(*) AS c FROM book_entries b '
            'WHERE b.date IS NOT NULL$dims GROUP BY v',
            variables: vars,
            readsFrom: <TableInfo<Table, Object?>>{db.bookEntries},
          )
          .get();
      return <String, int>{
        for (final QueryRow r in rows)
          '${r.data['v']}': (r.data['c']! as num).toInt(),
      };
    }

    final int total = await countFor(CategoryDim.category);
    final Map<String, int> yearMap = await groupFor(
      CategoryDim.year,
      'substr(b.date,1,4)',
    );
    final Map<String, int> monthMap = await groupFor(
      CategoryDim.month,
      'CAST(substr(b.date,6,2) AS INTEGER)',
    );
    final Map<String, int> tenMap = await groupFor(
      CategoryDim.tenDay,
      "CASE WHEN CAST(substr(b.date,9,2) AS INTEGER) BETWEEN 1 AND 10 THEN 'upper' "
          "WHEN CAST(substr(b.date,9,2) AS INTEGER) BETWEEN 11 AND 20 THEN 'middle' ELSE 'lower' END",
    );
    final Map<String, int> channelMap = await groupFor(
      CategoryDim.channel,
      'b.channel',
    );
    final Map<String, int> catMap = await groupFor(
      CategoryDim.category,
      'b.category',
    );

    int earlyCount = 0;
    final List<DimCount> years = <DimCount>[];
    final List<String> yearKeys = yearMap.keys.toList()
      ..sort((String a, String b) => b.compareTo(a));
    for (final String y in yearKeys) {
      final int c = yearMap[y]!;
      if ((int.tryParse(y) ?? 0) <= YearFilter.earlyMaxYear) {
        earlyCount += c;
      } else {
        years.add(DimCount(value: y, label: y, count: c));
      }
    }
    if (earlyCount > 0) {
      years.add(DimCount(value: YearFilter.early, label: '更早', count: earlyCount));
    }

    final List<DimCount> months = <DimCount>[
      for (int m = 1; m <= 12; m++)
        DimCount(value: '$m', label: '$m月', count: monthMap['$m'] ?? 0),
    ];
    final List<DimCount> tenDays = <DimCount>[
      DimCount(value: TenDayFilter.upper, label: '上旬', count: tenMap[TenDayFilter.upper] ?? 0),
      DimCount(value: TenDayFilter.middle, label: '中旬', count: tenMap[TenDayFilter.middle] ?? 0),
      DimCount(value: TenDayFilter.lower, label: '下旬', count: tenMap[TenDayFilter.lower] ?? 0),
    ];
    int otherCount = 0;
    for (final String name in ChannelFilter.otherBigMembers) {
      otherCount += channelMap[name] ?? 0;
    }
    final List<DimCount> channels = <DimCount>[
      for (final String name in ChannelFilter.categoryNamed)
        DimCount(value: name, label: name, count: channelMap[name] ?? 0),
      DimCount(value: ChannelFilter.otherBig, label: '其他', count: otherCount),
    ];
    final List<DimCount> categories = <DimCount>[
      for (final String k in CategoryKind.all)
        DimCount(value: k, label: k, count: catMap[k] ?? 0),
    ];
    return CategoryCounts(
      total: total,
      years: years,
      months: months,
      tenDays: tenDays,
      channels: channels,
      categories: categories,
    );
  }

  /// FTS 检索路径（book_fts trigram）。[match] 由调用方拼好：第二级是裸短语 AND，
  /// 第一级带 {name author} 列过滤（[titleOnly]）。
  Future<Paged<GroupHit>> _ftsGroups(
    String match,
    List<String> words,
    SearchFilter f, {
    bool titleOnly = false,
  }) {
    final List<Variable<Object>> vars = <Variable<Object>>[
      Variable<String>(match),
    ];
    final String dims = _dimClauses(f, vars);
    // 第一级（titleOnly）恒取 NULL AS snip：snippet(book_fts, 3, …) 取的是 comment 列，
    // 而第一级 MATCH 被列过滤限制在 name/author，snippet 在 comment 里找不到命中词就会
    // 退回该列开头——正好是「同楼无关正文」（见 searchBooks 的两级检索注释）。
    final String snipExpr = titleOnly
        ? 'NULL'
        : 'snippet(book_fts, 3, \'[\', \']\', \'…\', 16)';
    return _groupedPage(
      matchedCte:
          'WITH matched AS ('
          'SELECT b.*, $snipExpr AS snip, ${_flagSql()} AS flag '
          'FROM book_fts JOIN book_entries b ON b.id = book_fts.rowid '
          'WHERE book_fts MATCH ?$dims)',
      cteVars: vars,
      filter: f,
      words: words,
      excerptByName: titleOnly,
    );
  }

  /// LIKE 检索路径（2 字词兜底 / FTS 零命中重试 / FTS 异常降级 / 第一级列过滤不可用）。
  ///
  /// [titleOnly] = 第一级：只匹配 name/name_norm/author/author_norm 四列。
  /// 第二级放开到 recommender/comment，并 OR 进所属楼层正文（floor_fts）：
  /// 角色名经常只出现在楼层正文、不在条目评语里。
  Future<Paged<GroupHit>> _likeGroups(
    List<String> words,
    SearchFilter f, {
    bool titleOnly = false,
  }) {
    final List<Variable<Object>> vars = <Variable<Object>>[];
    final List<String> conds = <String>[];
    // name_norm/author_norm：ETL 归一化列（去标点），承接归一化查询对原文的召回
    // （FTS 零命中重试与 2 字词兜底共用本路径）。
    final List<String> cols = titleOnly
        ? const <String>['b.name', 'b.name_norm', 'b.author', 'b.author_norm']
        : const <String>[
            'b.name',
            'b.name_norm',
            'b.author',
            'b.author_norm',
            'b.recommender',
            'b.comment',
          ];
    for (final String w in words) {
      final String arg = _likeArg(w);
      final String colExpr = cols.map((String c) => "$c LIKE ? ESCAPE '\\'").join(' OR ');
      if (titleOnly) {
        conds.add('($colExpr)');
        for (int i = 0; i < cols.length; i++) {
          vars.add(Variable<String>(arg));
        }
      } else {
        // 楼层正文：角色名常只出现在 floors.text，条目评语是空的。
        conds.add('($colExpr OR EXISTS (SELECT 1 FROM floors fl WHERE fl.id = b.floor_ref AND fl.text LIKE ? ESCAPE \'\\\'))');
        for (int i = 0; i < cols.length + 1; i++) {
          vars.add(Variable<String>(arg));
        }
      }
    }
    final String dims = _dimClauses(f, vars);
    return _groupedPage(
      matchedCte:
          'WITH matched AS ('
          'SELECT b.*, NULL AS snip, ${_flagSql()} AS flag FROM book_entries b '
          'WHERE ${conds.join(' AND ')}$dims)',
      cteVars: vars,
      filter: f,
      words: words,
      excerptByName: titleOnly,
    );
  }

  Future<Paged<GroupHit>> _browseGroups(SearchFilter f) {
    final List<Variable<Object>> vars = <Variable<Object>>[];
    final String dims = _dimClauses(f, vars);
    return _groupedPage(
      matchedCte:
          'WITH matched AS ('
          'SELECT b.*, NULL AS snip, ${_flagSql()} AS flag FROM book_entries b WHERE 1 = 1$dims)',
      cteVars: vars,
      filter: f,
      words: const <String>[],
    );
  }

  static String _likeArg(String w) =>
      '%${w.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%';

  /// 书级分组分页：聚合计数 → 页内 gid 取最佳条目（quality↓+推荐语长↓）二段查询。
  ///
  /// [excerptByName] = 第一级（书名/作者命中）的摘要口径：以该书书名为锚在 comment
  /// 上截窗，书名不在 comment 里才退回查询词，都不在则不出摘要（宁缺毋滥，
  /// 不给书名命中的书配一段同楼无关正文）。第二级维持原样：有 FTS snippet 用 snippet，
  /// 否则按查询词截窗。
  Future<Paged<GroupHit>> _groupedPage({
    required String matchedCte,
    required List<Variable<Object>> cteVars,
    required SearchFilter filter,
    required List<String> words,
    bool excerptByName = false,
  }) async {
    const String gidExpr = 'COALESCE(m.book_group_id, -m.id)';
    final String order = filter.sort == SearchSort.timeAsc
        ? 'latest IS NULL, latest ASC, hits DESC'
        : 'latest DESC, hits DESC';
    final int total =
        ((await db
                        .customSelect(
                          '$matchedCte SELECT COUNT(*) AS c FROM (SELECT 1 FROM matched m GROUP BY $gidExpr)',
                          variables: cteVars,
                          readsFrom: <TableInfo<Table, Object?>>{
                            db.bookEntries,
                          },
                        )
                        .getSingle())
                    .data['c']!
                as num)
            .toInt();
    final List<QueryRow> aggRows = await db
        .customSelect(
          '$matchedCte '
          'SELECT $gidExpr AS gid, COUNT(*) AS hits, '
          'MAX(m.date) AS latest, MAX(g.name_display) AS gname, MAX(g.author_display) AS gauthor, '
          'GROUP_CONCAT(DISTINCT m.channel) AS chans, '
          '${_kindPayload('m')} AS kinds '
          'FROM matched m LEFT JOIN book_groups g ON g.id = m.book_group_id '
          'LEFT JOIN posts p ON p.id = m.post_ref '
          'GROUP BY gid ORDER BY $order LIMIT ? OFFSET ?',
          variables: <Variable<Object>>[
            ...cteVars,
            Variable<int>(filter.limit),
            Variable<int>(filter.offset),
          ],
          readsFrom: <TableInfo<Table, Object?>>{db.bookEntries, db.bookGroups, db.posts},
        )
        .get();
    if (aggRows.isEmpty) {
      return Paged<GroupHit>(
        items: <GroupHit>[],
        total: total,
        limit: filter.limit,
        offset: filter.offset,
      );
    }
    final List<int> gids = aggRows
        .map((QueryRow r) => (r.data['gid']! as num).toInt())
        .toList();
    final List<QueryRow> bestRows = await db
        .customSelect(
          '$matchedCte '
          'SELECT $gidExpr AS gid, m.id AS entry_id, m.name AS name, m.name_norm AS name_norm, '
          'm.author AS author, m.snip AS snip, COALESCE(m.comment, \'\') AS comment, '
          'fl.text AS floor_text, '
          '${_flagSql('m')} AS flag '
          'FROM matched m LEFT JOIN floors fl ON fl.id = m.floor_ref '
          'WHERE $gidExpr IN (${List<String>.filled(gids.length, '?').join(', ')}) '
          "ORDER BY gid, m.quality DESC, length(COALESCE(m.comment, '')) DESC, m.id",
          variables: <Variable<Object>>[
            ...cteVars,
            for (final int g in gids) Variable<int>(g),
          ],
          readsFrom: <TableInfo<Table, Object?>>{db.bookEntries, db.floors},
        )
        .get();
    final Map<int, QueryRow> best = <int, QueryRow>{};
    for (final QueryRow r in bestRows) {
      best.putIfAbsent((r.data['gid']! as num).toInt(), () => r);
    }
    // 三分计数口径（用户拍板）：按**该书全部条目**计，而非本次命中的条目数
    // ——搜索词通常只命中该书的部分条目（如只命中书名的那几条），命中集计数会把一本
    // 实际有 N 条推荐的书记成 1。散条目（gid < 0，无聚合组）不存在「该书全部」，用命中集。
    final List<int> groupGids = <int>[
      for (final int g in gids)
        if (g > 0) g,
    ];
    final Map<int, (int scan, int recommend, int avoid)> totals =
        <int, (int, int, int)>{};
    if (groupGids.isNotEmpty) {
      final String placeholders = List<String>.filled(
        groupGids.length,
        '?',
      ).join(', ');
      final List<QueryRow> totalRows = await db
          .customSelect(
            'SELECT b.book_group_id AS gid, ${_kindPayload('b')} AS kinds '
            'FROM book_entries b LEFT JOIN posts p ON p.id = b.post_ref '
            'WHERE b.book_group_id IN ($placeholders) '
            'GROUP BY b.book_group_id',
            variables: <Variable<Object>>[
              for (final int g in groupGids) Variable<int>(g),
            ],
            readsFrom: <TableInfo<Table, Object?>>{db.bookEntries, db.posts},
          )
          .get();
      for (final QueryRow r in totalRows) {
        totals[(r.data['gid']! as num).toInt()] =
            kindCountsOf(r.data['kinds'] as String?);
      }
    }
    final List<GroupHit> items = <GroupHit>[];
    for (final QueryRow r in aggRows) {
      final int gid = (r.data['gid']! as num).toInt();
      final QueryRow? b = best[gid];
      final String? snip = b?.data['snip'] as String?;
      final String? groupName = r.data['gname'] as String?;
      final String? entryName = b?.data['name'] as String?;
      final (int scanK, int recK, int avoidK) = kindCountsOf(r.data['kinds'] as String?);
      final (int scan, int rec, int avoid) total =
          totals[gid] ?? (scanK, recK, avoidK);
      final String? snippet = (snip == null || snip.isEmpty)
          ? buildExcerpt(
              b?.data['comment'] as String?,
              words,
              // 第一级：条目自身书名优先（comment 就是该条目所在楼层的正文），
              // 其次书组显示名；两个都没在 comment 里出现则返回 null。
              prefer: excerptByName
                  ? _nameAnchors(<String?>[entryName, groupName])
                  : const <String>[],
              nullWhenUnanchored: excerptByName,
            )
          : snip;
      // 卡片正文预览（标题下）：命中高亮 snippet 优先；无 snippet（书名级命中/条件浏览）
      // 回退该条目评语，评语为空再回退楼层正文 —— 与 EntryRow.previewSource 同口径，
      // 保证「所有卡片都显示正文预览」（用户口径）。
      final String? preview = (snippet != null && snippet.isNotEmpty)
          ? snippet
          : summarizeCardText(
              _previewSourceOf(
                b?.data['comment'] as String?,
                b?.data['floor_text'] as String?,
              ),
            );
      items.add(
        GroupHit(
          groupId: gid > 0 ? gid : null,
          name:
              groupName ?? entryName ?? (r.data['name_norm'] as String? ?? ''),
          nameNorm: (b?.data['name_norm'] as String?) ?? '',
          author: r.data['gauthor'] as String? ?? b?.data['author'] as String?,
          hitCount: (r.data['hits']! as num).toInt(),
          scanCount: total.$1,
          recommendCount: total.$2,
          avoidCount: total.$3,
          latestDate: r.data['latest'] as String?,
          snippet: snippet,
          preview: preview,
          channels: ((r.data['chans'] as String?) ?? '')
              .split(',')
              .where((String s) => s.isNotEmpty)
              .toList(),
          bestEntryId: (b?.data['entry_id'] as num?)?.toInt() ?? 0,
          bestFlag: (b?.data['flag'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    return Paged<GroupHit>(
      items: items,
      total: total,
      limit: filter.limit,
      offset: filter.offset,
    );
  }

  /// 三分计数载荷（[kindCountsOf] 的输入）：每条目 `category\u001f flag\u001f title`，
  /// 多条以 `\u001e` 连接（SQLite char(31)/char(30)）。**必须**与 [entryKindLabel] 对账
  /// （test/data/entry_kind_test.dart 表驱动守卫）。
  static String _kindPayload(String alias) =>
      "GROUP_CONCAT(COALESCE($alias.category, '') || char(31) || (${_flagSql(alias)}) || char(31) || COALESCE(p.title, ''), char(30))";

  /// `category\u001f flag\u001f title` 串（`\u001e` 分隔）→ (扫书, 推书, 排雷) 条数。
  /// 同一帖的多条条目各算一次：书卡要的是「被扫到 / 被推 / 被排雷」的**条目**次数，不是帖数。
  static (int scan, int recommend, int avoid) kindCountsOf(String? packed) {
    if (packed == null || packed.isEmpty) {
      return (0, 0, 0);
    }
    int scan = 0;
    int recommend = 0;
    int avoid = 0;
    for (final String piece in packed.split('\u001e')) {
      final List<String> fields = piece.split('\u001f');
      switch (entryKindLabel(
        category: fields.isEmpty ? '' : fields.first,
        flag: fields.length > 1 ? (int.tryParse(fields[1]) ?? 0) : 0,
        title: fields.length > 2 ? fields.sublist(2).join('\u001f') : null,
      )) {
        case kRecommendKind:
          recommend++;
        case CategoryKind.avoid:
          avoid++;
        default:
          scan++;
      }
    }
    return (scan, recommend, avoid);
  }

  // ── 帖子详情（§5.6）──

  @override
  Future<PostDetailData?> postDetail(int postId) async {
    final Post? post = await (db.select(
      db.posts,
    )..where((Posts t) => t.id.equals(postId))).getSingleOrNull();
    if (post == null) {
      return null;
    }
    final List<Floor> floors =
        await (db.select(db.floors)
              ..where((Floors t) => t.postId.equals(postId))
              ..orderBy([
                (Floors t) => OrderingTerm.asc(t.seq),
                (Floors t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    final List<FloorImage> images = floors.isEmpty
        ? <FloorImage>[]
        : await db
              .customSelect(
                'SELECT * FROM images WHERE floor_id IN (${List<String>.filled(floors.length, '?').join(', ')}) ORDER BY id',
                variables: <Variable<Object>>[
                  for (final Floor f in floors) Variable<int>(f.id),
                ],
                readsFrom: <TableInfo<Table, Object?>>{db.images},
              )
              .map((QueryRow r) => db.images.map(r.data))
              .get();
    final Map<int, List<FloorImage>> byFloor = <int, List<FloorImage>>{};
    for (final FloorImage img in images) {
      byFloor.putIfAbsent(img.floorId, () => <FloorImage>[]).add(img);
    }
    // 帖内提及书目 → 每本书的全站推荐/排雷次数（跨帖聚合）。计数走 [kindCountsOf]
    // 同一三分口径（颜色标记 → 帖标题 → 类别）：否则「推荐一本宝藏书」这类无绿标的推荐帖，
    // 帖页书目 chip 挂 0 推荐而书卡挂 1 推荐，两个页面自相矛盾（用户反馈原症状）。
    final List<QueryRow> bookRows = await db
        .customSelect(
          'SELECT MAX(g.id) AS gid, MAX(g.name_display) AS name, '
          '${_kindPayload('b')} AS kinds '
          'FROM book_entries b LEFT JOIN book_groups g ON g.name_norm = b.name_norm '
          'LEFT JOIN posts p ON p.id = b.post_ref '
          'WHERE b.name_norm IN '
          '(SELECT name_norm FROM book_entries WHERE post_ref = ?) '
          'GROUP BY b.name_norm',
          variables: <Variable<Object>>[Variable<int>(postId)],
          readsFrom: <TableInfo<Table, Object?>>{
            db.bookEntries,
            db.bookGroups,
            db.posts,
          },
        )
        .get();
    final List<PostBookCount> books = <PostBookCount>[];
    for (final QueryRow r in bookRows) {
      final (int _, int recommend, int avoid) =
          kindCountsOf(r.data['kinds'] as String?);
      books.add(PostBookCount(
        groupId: (r.data['gid'] as num?)?.toInt(),
        name: (r.data['name'] as String?) ?? '',
        recommend: recommend,
        avoid: avoid,
      ));
    }
    // 排序随计数下移（原 SQL ORDER BY rec DESC, avoid DESC, name_norm）：
    // 推荐多者在前，再排雷多者，再按书名稳定序。
    books.sort((PostBookCount a, PostBookCount b) {
      final int byRec = b.recommend.compareTo(a.recommend);
      if (byRec != 0) {
        return byRec;
      }
      final int byAvoid = b.avoid.compareTo(a.avoid);
      if (byAvoid != 0) {
        return byAvoid;
      }
      return a.name.compareTo(b.name);
    });
    return PostDetailData(
      post: post,
      floors: <FloorData>[
        for (final Floor f in floors)
          FloorData(floor: f, images: byFloor[f.id] ?? const <FloorImage>[]),
      ],
      books: books,
    );
  }

  // ── 书聚合（§5.5）──

  @override
  Future<BookDetailData?> bookDetail(int groupId) async {
    final BookGroup? group = await (db.select(
      db.bookGroups,
    )..where((BookGroups t) => t.id.equals(groupId))).getSingleOrNull();
    if (group == null) {
      return null;
    }
    final QueryRow counts = await db
        .customSelect(
          'SELECT ${_kindPayload('b')} AS kinds '
          'FROM book_entries b LEFT JOIN posts p ON p.id = b.post_ref '
          'WHERE b.book_group_id = ?',
          variables: <Variable<Object>>[Variable<int>(groupId)],
          readsFrom: <TableInfo<Table, Object?>>{db.bookEntries, db.posts},
        )
        .getSingle();
    final (int scan, int recommend, int avoid) =
        kindCountsOf(counts.data['kinds'] as String?);
    return BookDetailData(
      group: group,
      scanCount: scan,
      recommendCount: recommend,
      avoidCount: avoid,
    );
  }

  /// 评价列表：三分筛选 + 排序（质量↓默认）。
  ///
  /// 三档皆按**三分类型**过滤（与页头计数同源，见 [EntryRow.kindLabel]）：
  /// 数字与点开的列表同口径，不再出现「计数 13、点开只有 4」。
  /// 「仅扫书」= 非推荐且非排雷（求书档也算扫书）——逐字对齐 [kindCountsOf] 的
  /// default 分支（本文件 1952-1975 行），保证「点 N 扫书 → 列表正好 N 条」。
  @override
  Future<List<EntryRow>> bookEntries(
    int groupId,
    SemanticFilter filter, {
    EntrySort sort = EntrySort.qualityDesc,
  }) async {
    final String order = switch (sort) {
      EntrySort.qualityDesc =>
        "b.quality DESC, length(COALESCE(b.comment, '')) DESC, b.date DESC, b.id DESC",
      EntrySort.timeDesc => 'b.date DESC, b.id DESC',
      EntrySort.timeAsc => 'b.date IS NULL, b.date ASC, b.id ASC',
      EntrySort.wordDesc =>
        'b.word_count IS NULL, b.word_count DESC, b.id DESC',
    };
    final List<EntryRow> rows = await db
        .customSelect(
          'SELECT $_entryCols$_entryFrom WHERE b.book_group_id = ? ORDER BY $order',
          variables: <Variable<Object>>[Variable<int>(groupId)],
          readsFrom: <TableInfo<Table, Object?>>{db.bookEntries, db.floors, db.posts},
        )
        .map((QueryRow r) => EntryRow.fromRow(r))
        .get();
    return switch (filter) {
      SemanticFilter.all => rows,
      // 「扫书」桶 = [kindCountsOf] 的 default 分支（本文件 1970-1971 行）：
      // 非推书且非排雷（含求书档）——页头数字与点开的列表同源。
      SemanticFilter.scan =>
        rows.where((EntryRow e) => e.kindLabel != kRecommendKind && e.kindLabel != CategoryKind.avoid).toList(),
      SemanticFilter.recommend =>
        rows.where((EntryRow e) => e.kindLabel == kRecommendKind).toList(),
      SemanticFilter.avoid =>
        rows.where((EntryRow e) => e.kindLabel == CategoryKind.avoid).toList(),
    };
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
            Variable<String>(
              '${p.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%',
            ),
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
        .map(
          (QueryRow r) => HotBook(
            nameNorm: r.data['name_norm']! as String,
            name:
                (r.data['name_display'] as String?) ??
                (r.data['name_norm']! as String),
            entryTotal: (r.data['entry_total']! as num).toInt(),
            groupId: r.data['id'] as int?,
          ),
        )
        .get();
  }

  // ── 搜索历史（§5.3：六维快照 CRUD）──

  @override
  Stream<List<SearchHistoryEntry>> watchHistory() {
    return (db.select(db.searchHistory)
          ..orderBy([
            (SearchHistory t) => OrderingTerm.desc(t.searchedAt),
            (SearchHistory t) => OrderingTerm.desc(t.id),
          ])
          ..limit(50))
        .watch();
  }

  /// 记录一次提交：同条件去重（刷新时间），滚动保留 50 条。
  @override
  Future<void> addHistory(SearchFilter f) {
    return db.transaction(() async {
      await (db.delete(db.searchHistory)..where(
            (SearchHistory t) =>
                t.query.equals(f.query) &
                t.year.equalsNullable(f.year) &
                t.month.equalsNullable(f.month) &
                t.tenDay.equalsNullable(f.tenDay) &
                t.channel.equalsNullable(f.channel) &
                t.category.equalsNullable(f.category),
          ))
          .go();
      await db
          .into(db.searchHistory)
          .insert(
            SearchHistoryCompanion.insert(
              query: Value<String>(f.query),
              year: Value<String?>(f.year),
              month: Value<String?>(f.month),
              tenDay: Value<String?>(f.tenDay),
              channel: Value<String?>(f.channel),
              category: Value<String?>(f.category),
              sort: Value<String>(f.sort.wire),
              searchedAt: DateTime.now(),
            ),
          );
      await db.customStatement(
        'DELETE FROM search_history WHERE id NOT IN '
        '(SELECT id FROM search_history ORDER BY searched_at DESC, id DESC LIMIT 50)',
      );
    });
  }

  @override
  Future<void> deleteHistory(int id) => (db.delete(
    db.searchHistory,
  )..where((SearchHistory t) => t.id.equals(id))).go();

  @override
  Future<void> clearHistory() => db.delete(db.searchHistory).go();

  // ── 书签（§5.6：六维快照 + 列表位置）与收藏（§5.5/§5.6 双粒度）──

  @override
  Stream<List<Bookmark>> watchBookmarks() {
    return (db.select(
      db.bookmarks,
    )..orderBy([(Bookmarks t) => OrderingTerm.desc(t.createdAt)])).watch();
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
    int? floorSeq,
    String? note,
  }) async {
    final Bookmark? existing = await (db.select(
      db.bookmarks,
    )..where((Bookmarks t) => t.postRef.equals(postRef))).getSingleOrNull();
    if (existing != null) {
      await (db.delete(
        db.bookmarks,
      )..where((Bookmarks t) => t.id.equals(existing.id))).go();
      return false;
    }
    await db
        .into(db.bookmarks)
        .insert(
          BookmarksCompanion.insert(
            postRef: Value<int>(postRef),
            title: title,
            author: Value<String?>(author),
            channel: Value<String?>(channel),
            position: Value<int>(position),
            floorSeq: Value<int?>(floorSeq),
            snapQuery: Value<String?>(snapshot?.query),
            snapYear: Value<String?>(snapshot?.year),
            snapMonth: Value<String?>(snapshot?.month),
            snapTenDay: Value<String?>(snapshot?.tenDay),
            snapChannel: Value<String?>(snapshot?.channel),
            snapCategory: Value<String?>(snapshot?.category),
            snapSort: Value<String?>(snapshot?.sort.wire),
            note: Value<String?>(note),
            createdAt: DateTime.now(),
          ),
        );
    return true;
  }

  @override
  Stream<List<Favorite>> watchFavorites() {
    return (db.select(
      db.favorites,
    )..orderBy([(Favorites t) => OrderingTerm.desc(t.addedAt)])).watch();
  }

  /// 添加/取消收藏。返回操作后是否为已收藏态。
  @override
  Future<bool> toggleFavorite({
    required String targetType,
    required int targetId,
    required String title,
    String? subtitle,
  }) async {
    final Favorite? existing =
        await (db.select(db.favorites)..where(
              (Favorites t) =>
                  t.targetType.equals(targetType) & t.targetId.equals(targetId),
            ))
            .getSingleOrNull();
    if (existing != null) {
      await (db.delete(
        db.favorites,
      )..where((Favorites t) => t.id.equals(existing.id))).go();
      return false;
    }
    await db
        .into(db.favorites)
        .insert(
          FavoritesCompanion.insert(
            targetType: targetType,
            targetId: targetId,
            title: title,
            subtitle: Value<String?>(subtitle),
            addedAt: DateTime.now(),
          ),
        );
    return true;
  }
}
