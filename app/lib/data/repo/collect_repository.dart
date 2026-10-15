/// 采集持久层仓库（collection_state / collection_logs 两表的 CRUD 门面）。
///
/// 水位推进、状态机落库、日志滚动裁剪等**运行时写入**由采集服务
/// （lib/collector/ 实现侧）负责调用/扩展本仓库；UI 只经由
/// `collect_repository_providers.dart` 的三个 provider 读。
///
/// **本文件纯 Dart**（provider 接线已拆出），headless CLI 可直接构造。
library;

import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// §8.7 默认关注吧（unified 两大活跃贴吧渠道）。
const List<String> kDefaultForums = <String>['yy小说吧', '哀伤雪刃'];

/// collection_logs 滚动保留上限（§7.2 注释：最近 200 条）。
const int kCollectionLogLimit = 200;

class CollectRepository {
  CollectRepository(this.db);

  final AppDatabase db;

  /// 全部关注吧（按吧名序）。
  Future<List<CollectionStateEntry>> forums() =>
      (db.select(db.collectionState)..orderBy([(t) => OrderingTerm.asc(t.fname)]))
          .get();

  /// 最近运行日志（新在前；持久层同样限 [kCollectionLogLimit]）。
  Future<List<CollectionLog>> recentLogs({int limit = 50}) =>
      (db.select(db.collectionLogs)
            ..orderBy([(t) => OrderingTerm.desc(t.runAt), (t) => OrderingTerm.desc(t.id)])
            ..limit(limit))
          .get();

  /// 首次使用播种默认两吧（§5.9 空态引导的同源数据；幂等）。
  Future<void> seedDefaultsIfEmpty() async {
    final int count = await db.collectionState.count().getSingle();
    if (count > 0) return;
    await db.batch((Batch b) {
      for (final String fname in kDefaultForums) {
        b.insert(
          db.collectionState,
          CollectionStateCompanion.insert(fname: fname),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  /// 新增关注吧（验证存在性属服务层职责，本方法只管落库；重复添加幂等）。
  Future<void> addForum(String fname, {int? fid}) =>
      db.into(db.collectionState).insertOnConflictUpdate(
        CollectionStateCompanion.insert(fname: fname, fid: Value<int?>(fid)),
      );

  Future<void> setForumEnabled(String fname, bool enabled) =>
      (db.update(db.collectionState)..where((t) => t.fname.equals(fname)))
          .write(CollectionStateCompanion(enabled: Value<bool>(enabled)));

  Future<void> removeForum(String fname) =>
      (db.delete(db.collectionState)..where((t) => t.fname.equals(fname))).go();

  /// 追加一条运行日志并滚动裁剪（超出 [kCollectionLogLimit] 的旧行删除）。
  Future<void> appendLog(CollectionLogsCompanion entry) async {
    await db.into(db.collectionLogs).insert(entry);
    final int total = await db.collectionLogs.count().getSingle();
    if (total > kCollectionLogLimit) {
      final List<CollectionLog> stale = await (db.select(db.collectionLogs)
            ..orderBy([(t) => OrderingTerm.desc(t.id)])
            ..limit(total - kCollectionLogLimit, offset: kCollectionLogLimit))
          .get();
      final List<int> ids = stale.map((CollectionLog l) => l.id).toList();
      await (db.delete(db.collectionLogs)..where((t) => t.id.isIn(ids))).go();
    }
  }

  // ── M2-① 采集服务扩展（只增不改：既有方法签名保持不变） ──────────────

  /// 单吧水位行（不存在返回 null）。
  Future<CollectionStateEntry?> forum(String fname) =>
      (db.select(db.collectionState)..where((t) => t.fname.equals(fname)))
          .getSingleOrNull();

  /// 读 settings KV（不存在返回 null）。
  Future<String?> getSetting(String key) async {
    final Setting? row =
        await (db.select(db.settings)..where((t) => t.key.equals(key)))
            .getSingleOrNull();
    return row?.value;
  }

  /// 写 settings KV（UPSERT）。
  Future<void> setSetting(String key, String value) =>
      db.into(db.settings).insertOnConflictUpdate(
            SettingsCompanion.insert(key: key, value: value),
          );

  /// 一轮运行后的吧级状态落库（§8.7 步骤 6 / §8.12 状态机）。
  ///
  /// 水位（[lastThreadTime]/[lastTid]）传 null = 不推进（取消/网络断口径）；
  /// 计数列为**增量**语义（total_threads/total_floors/new_since_visit += 增量）。
  Future<void> updateForumAfterRun({
    required String fname,
    required DateTime lastRunAt,
    required String lastStatus,
    String? lastError,
    int? consecutiveFailures,
    DateTime? cooldownUntil,
    bool clearCooldown = false,
    int? lastThreadTime,
    int? lastTid,
    int? fid,
    int addThreads = 0,
    int addFloors = 0,
    int addNewSinceVisit = 0,
  }) async {
    final CollectionStateEntry? cur = await forum(fname);
    await (db.update(db.collectionState)..where((t) => t.fname.equals(fname)))
        .write(CollectionStateCompanion(
      lastRunAt: Value<DateTime?>(lastRunAt),
      lastStatus: Value<String>(lastStatus),
      // null = 清空既有错误（成功轮次）。
      lastError: Value<String?>(lastError),
      consecutiveFailures: consecutiveFailures == null
          ? const Value<int>.absent()
          : Value<int>(consecutiveFailures),
      // clearCooldown = 成功轮次清掉过期冷却戳。
      cooldownUntil: clearCooldown
          ? Value<DateTime?>(null)
          : (cooldownUntil == null
              ? const Value<DateTime?>.absent()
              : Value<DateTime?>(cooldownUntil)),
      lastThreadTime: lastThreadTime == null
          ? const Value<int>.absent()
          : Value<int>(lastThreadTime),
      lastTid:
          lastTid == null ? const Value<int>.absent() : Value<int>(lastTid),
      fid: fid == null ? const Value<int?>.absent() : Value<int?>(fid),
      totalThreads: Value<int>((cur?.totalThreads ?? 0) + addThreads),
      totalFloors: Value<int>((cur?.totalFloors ?? 0) + addFloors),
      newSinceVisit:
          Value<int>((cur?.newSinceVisit ?? 0) + addNewSinceVisit),
    ));
  }
}

