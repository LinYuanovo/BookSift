/// Headless 检索/统计门面 API。
///
/// 把 `lib/data/repo/queries.dart` 的 [Queries]（drift 实现，纯 Dart）与
/// `lib/data/repo/collect_repository.dart` 的水位读取，收拢成一个**稳定、可编程**
/// 的入口，供 CLI（`bin/booksift.dart`）、脚本与测试复用；App 侧仍走 riverpod
/// provider（`queries_providers.dart`），两条路径共用同一份 [Queries] 实现。
///
/// 附带 [DbOverview] 与 JSON 映射：`queries.dart` 的数据类是 UI 视图模型，
/// 没有序列化能力，agent 要机读就得有人补这一层——补在这里，不去改那些大文件。
library;

import 'package:drift/drift.dart';

import '../data/db/app_database.dart';
import '../data/repo/collect_repository.dart';
import '../data/repo/queries.dart';
import 'env.dart';

/// 单吧水位快照（collection_state 行的机读投影）。
class ForumWatermark {
  const ForumWatermark({
    required this.fname,
    required this.fid,
    required this.enabled,
    required this.lastStatus,
    required this.lastThreadTime,
    required this.lastRunAt,
    required this.lastTid,
    required this.consecutiveFailures,
    required this.cooldownUntil,
    required this.totalThreads,
    required this.totalFloors,
    required this.newSinceVisit,
    required this.lastError,
  });

  factory ForumWatermark.of(CollectionStateEntry e) => ForumWatermark(
        fname: e.fname,
        fid: e.fid,
        enabled: e.enabled,
        lastStatus: e.lastStatus,
        lastThreadTime: e.lastThreadTime,
        lastRunAt: e.lastRunAt,
        lastTid: e.lastTid,
        consecutiveFailures: e.consecutiveFailures,
        cooldownUntil: e.cooldownUntil,
        totalThreads: e.totalThreads,
        totalFloors: e.totalFloors,
        newSinceVisit: e.newSinceVisit,
        lastError: e.lastError,
      );

  final String fname;
  final int? fid;
  final bool enabled;
  final String lastStatus;

  /// 增量水位（epoch 秒；0 = 冷启动）。
  final int lastThreadTime;
  final DateTime? lastRunAt;
  final int lastTid;
  final int consecutiveFailures;
  final DateTime? cooldownUntil;
  final int totalThreads;
  final int totalFloors;
  final int newSinceVisit;
  final String? lastError;

  Map<String, Object?> toJson() => <String, Object?>{
        'fname': fname,
        'fid': fid,
        'enabled': enabled,
        'lastStatus': lastStatus,
        'lastThreadTime': lastThreadTime,
        'lastRunAt': lastRunAt?.toIso8601String(),
        'lastTid': lastTid,
        'consecutiveFailures': consecutiveFailures,
        'cooldownUntil': cooldownUntil?.toIso8601String(),
        'totalThreads': totalThreads,
        'totalFloors': totalFloors,
        'newSinceVisit': newSinceVisit,
        'lastError': lastError,
      };
}

/// 库概览（排错第一入口：库是空壳还是有数据、水位推到哪、设置是什么）。
class DbOverview {
  const DbOverview({
    required this.tables,
    required this.forums,
    required this.settings,
    required this.userVersion,
  });

  /// 各表行数。
  final Map<String, int> tables;

  /// 关注吧水位。
  final List<ForumWatermark> forums;

  /// settings KV（含种子版本闸门、分类器版本、预算计数）。
  final Map<String, String> settings;

  /// drift schema 版本（PRAGMA user_version）。
  final int userVersion;

  Map<String, Object?> toJson() => <String, Object?>{
        'userVersion': userVersion,
        'tables': tables,
        'forums': forums.map((ForumWatermark f) => f.toJson()).toList(),
        'settings': settings,
      };
}

/// 检索/统计门面。
class BookQueryApi {
  BookQueryApi(this.db)
      : _queries = Queries(db),
        _repo = CollectRepository(db);

  final AppDatabase db;
  final Queries _queries;
  final CollectRepository _repo;

  /// 直接暴露底层实现（门面未覆盖的方法可经此调用，避免逐条转发造成的重复）。
  Queries get queries => _queries;

  /// 采集持久层（水位/日志读写）。
  CollectRepository get repo => _repo;

  // ── 检索 ──────────────────────────────────────────────────────────────

  /// 六维搜索（≥3 字走 FTS，2 字词 LIKE 兜底；异常自动降级）。
  Future<SearchOutcome> search(SearchFilter filter) => _queries.searchBooks(filter);

  /// 书名联想。
  Future<List<String>> suggest(String prefix, {int limit = 8}) =>
      _queries.suggestBooks(prefix, limit: limit);

  /// 五维真实命中计数。
  Future<CategoryCounts> dimensionCounts() => _queries.dimensionCounts();

  /// 热门榜。
  Future<List<RankRow>> rank(RankWindow window, {int limit = 10, DateTime? today}) =>
      _queries.rankRows(window, today: today, limit: limit);

  /// 热门书名（book_groups.entry_total Top N）。
  Future<List<HotBook>> hotBooks({int limit = 20}) => _queries.hotBooks(limit: limit);

  /// 随机书荒。
  Future<List<EntryRow>> randomBooks(int count) => _queries.randomBooks(count);

  /// 首页时间线。
  Future<List<PostCardData>> timeline({int limit = 40, int offset = 0}) =>
      _queries.timelinePosts(limit: limit, offset: offset);

  /// 数据截至日。
  Future<String?> dataCutoff() => _queries.dataCutoff();

  /// 书聚合详情。
  Future<BookDetailData?> bookDetail(int groupId) => _queries.bookDetail(groupId);

  /// 书聚合评价列表。
  Future<List<EntryRow>> bookEntries(
    int groupId,
    SemanticFilter filter, {
    EntrySort sort = EntrySort.qualityDesc,
  }) =>
      _queries.bookEntries(groupId, filter, sort: sort);

  /// 帖子详情。
  Future<PostDetailData?> postDetail(int postId) => _queries.postDetail(postId);

  // ── 概览 / 排错 ────────────────────────────────────────────────────────

  /// 库概览（表行数 + 水位 + settings + schema 版本）。
  Future<DbOverview> overview() async {
    final QueryRow v = await db.customSelect('PRAGMA user_version').getSingle();
    final List<CollectionStateEntry> rows = await _repo.forums();
    final List<Setting> settings = await db.select(db.settings).get();
    return DbOverview(
      userVersion: v.data.values.first as int,
      tables: await HeadlessEnv.tableRowCounts(db),
      forums: rows.map(ForumWatermark.of).toList(growable: false),
      settings: <String, String>{
        for (final Setting s in settings) s.key: s.value,
      },
    );
  }

  /// 最近运行日志（collection_logs，新在前）。
  Future<List<CollectionLog>> recentLogs({int limit = 50}) =>
      _repo.recentLogs(limit: limit);
}

// ── JSON 映射（UI 视图模型 → 机读） ──────────────────────────────────────

Map<String, Object?> dimCountJson(DimCount d) =>
    <String, Object?>{'value': d.value, 'label': d.label, 'count': d.count};

Map<String, Object?> categoryCountsJson(CategoryCounts c) => <String, Object?>{
      'total': c.total,
      'years': c.years.map(dimCountJson).toList(),
      'months': c.months.map(dimCountJson).toList(),
      'tenDays': c.tenDays.map(dimCountJson).toList(),
      'channels': c.channels.map(dimCountJson).toList(),
      'categories': c.categories.map(dimCountJson).toList(),
    };

Map<String, Object?> groupHitJson(GroupHit g) => <String, Object?>{
      'groupId': g.groupId,
      'name': g.name,
      'nameNorm': g.nameNorm,
      'author': g.author,
      'hitCount': g.hitCount,
      'recommendCount': g.recommendCount,
      'avoidCount': g.avoidCount,
      'latestDate': g.latestDate,
      'snippet': g.snippet,
      'channels': g.channels,
      'bestEntryId': g.bestEntryId,
      'bestFlag': g.bestFlag,
    };

Map<String, Object?> searchOutcomeJson(SearchOutcome o) => <String, Object?>{
      'total': o.page.total,
      'limit': o.page.limit,
      'offset': o.page.offset,
      'hasMore': o.page.hasMore,
      'usedFts': o.usedFts,
      'degraded': o.degraded,
      'words': o.words,
      'items': o.page.items.map(groupHitJson).toList(),
    };

Map<String, Object?> entryRowJson(EntryRow e) => <String, Object?>{
      'id': e.id,
      'name': e.name,
      'nameNorm': e.nameNorm,
      'author': e.author,
      'recommender': e.recommender,
      'comment': e.comment,
      'date': e.date,
      'channel': e.channel,
      'subChannel': e.subChannel,
      'category': e.category,
      'bookGrade': e.bookGrade,
      'origin': e.origin,
      'quality': e.quality,
      'wordCount': e.wordCount,
      'postRef': e.postRef,
      'floorRef': e.floorRef,
      'bookGroupId': e.bookGroupId,
      'srcUrl': e.srcUrl,
      'snippet': e.snippet,
      'recommendFlag': e.recommendFlag,
    };

Map<String, Object?> rankRowJson(RankRow r) => <String, Object?>{
      'name': r.name,
      'nameNorm': r.nameNorm,
      'author': r.author,
      'count': r.count,
      'bookGroupId': r.bookGroupId,
    };

Map<String, Object?> hotBookJson(HotBook h) => <String, Object?>{
      'name': h.name,
      'nameNorm': h.nameNorm,
      'entryTotal': h.entryTotal,
      'groupId': h.groupId,
    };

Map<String, Object?> collectionLogJson(CollectionLog l) => <String, Object?>{
      'id': l.id,
      'fname': l.fname,
      'runAt': l.runAt.toIso8601String(),
      'status': l.status,
      'threadsAdded': l.threadsAdded,
      'floorsAdded': l.floorsAdded,
      'entriesAdded': l.entriesAdded,
      'skippedDup': l.skippedDup,
      'detail': l.detail,
    };
