/// 数据层维护任务（存量数据修复）。
///
/// 两个任务，各自独立 settings 闸门，全部完成才落账（中断/失败不写，重跑幂等续跑）：
///
/// 1. **book_entries 去重**（闸门 [SettingsKeys.dedupVersion]，完成值 [dedupDoneValue]）：
///    种子合并 ETL 曾把同一帖子从两个上游各收一遍，产生大量存量重复。
///    - 候选分组键：`name_norm + normPerson(recommender) + COALESCE(date,'') + channel`
///      （与问题盘点时的可见键口径一致；`normPerson` 的 NFKC/去空白/占位词归空无法
///      在 SQL 内表达，故 SQL 先按原始可见键粗筛，Dart 侧再按归一化人名归并）。
///    - 组内判定：组内评论的 [normText] 归一化串按长度排序后构成**前缀链**
///      （每个短串都是相邻长串的前缀；完全相同是其特例）→ 判重；
///      中间分叉的组**整组保留不动**（保守）。
///    - keeper 选择：comment 最长者优先 → quality 高者 → post_ref 非空者 → id 最小者。
///    - 删除分批落事务（每批 [dedupBookEntries] 的 batchGroups 个去重组），批间让出
///      事件循环；删除后按 ingest.dart `_refreshGroupAggregates` 同口径重算受影响
///      book_groups 的 entry_total / distinct_comment / word_count_max；
///      book_fts 由既有 `book_entries_ad` AFTER DELETE 触发器同步
///      （app_database.dart `_createFts`，本文件不自建索引逻辑）。
///
/// 2. **存量 posts v3 分类回填**（闸门 [SettingsKeys.classifierVersion]，落账值 =
///    [classifierVersion]）：种子库（schema v1）没有 post_kind/recommend_flag 列，
///    导入时回退为 post_type 粗分类；v3 分类器此前只在实时采集入库时跑
///    （worker.dart `analyzeThread`），从未作用于种子存量。本任务按
///    **analyzeThread 同口径**（首楼 = floors 按 seq 升序第一行；全文 = 标题 + 全楼层
///    '\n' 拼接；书名抽取 = parse.dart extractBookNames）对全部 posts 跑 [classifyV3]，
///    仅当 kind/flag 变化时 UPDATE posts（`kind == null`（日常闲聊）的帖保持原样）；
///    并在**同一事务**内把 book_entries.category 镜像同步为其所属帖的**当前**
///    posts.post_kind（§7.2 冗余列口径，ingest.dart 实时采集入库同写法）。闸门是
///    一次性的，故本轮对存量条目**全量对齐**——包括 post_kind 本就正确、category
///    仍是上游 ETL 旧值的条目；kind=null 帖的条目同样按当前 post_kind 镜像，不开
///    特例；`post_ref IS NULL` 的条目**不动**（无帖可依）。
///
/// 结构：纯 Dart 核心（[dedupBookEntries] / [reclassifyPostsV3] 可在任意已打开连接上
/// 执行，测试用内存库）+ 生产后台 isolate 编排（[runMaintenance]，模式照
/// seed_import.dart `_ftsRebuildIsolate`：控制端口 / 批式 yield / 可取消 / 失败事件，
/// 独立连接 WAL + busy_timeout）。
///
/// 本文件**不 import flutter**（headless 契约，见 app/HEADLESS.md）。
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' show min;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../classify/classifier.dart';
import '../collector/normalization.dart';
import '../collector/tieba/src/parse.dart' show extractBookNames;
import '../core/constants.dart';
import 'db/app_database.dart';

// ───────────────────────────── settings 闸门 ─────────────────────────────

/// settings.dedup_version 的完成值。
const String dedupDoneValue = '1';

/// 去重闸门：true = 需要执行 [dedupBookEntries]。
Future<bool> needsDedup(AppDatabase db) async =>
    await _readSetting(db, SettingsKeys.dedupVersion) != dedupDoneValue;

/// v3 回填闸门：true = 需要执行 [reclassifyPostsV3]。
Future<bool> needsReclassify(AppDatabase db) async =>
    await _readSetting(db, SettingsKeys.classifierVersion) != '$classifierVersion';

Future<String?> _readSetting(AppDatabase db, String key) async {
  final QueryRow? row = await db
      .customSelect('SELECT value AS v FROM settings WHERE key = ?',
          variables: <Variable>[Variable.withString(key)])
      .getSingleOrNull();
  return row?.read<String>('v');
}

Future<void> _writeSetting(AppDatabase db, String key, String value) => db.customStatement(
      "INSERT INTO settings(key, value) VALUES(?, ?) "
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      <dynamic>[key, value],
    );

// ───────────────────────────── book_entries 去重 ─────────────────────────────

/// 去重进度/结果快照（[dedupBookEntries] 的 onProgress 回调与返回值）。
class DedupStats {
  const DedupStats({
    this.totalGroups = 0,
    this.groupsScanned = 0,
    this.dupGroups = 0,
    this.rowsDeleted = 0,
    this.groupsRefreshed = 0,
    this.batches = 0,
    this.cancelled = false,
    this.elapsedMs = 0,
  });

  /// 候选重复组总数（可见键归并后）。
  final int totalGroups;

  /// 已扫描判定的组数。
  final int groupsScanned;

  /// 判定为可去重的组数（前缀链/同文）。
  final int dupGroups;

  /// 已删除行数。
  final int rowsDeleted;

  /// 已重算聚合的 book_groups 数（跨批计数，同组可能重复计，信息性）。
  final int groupsRefreshed;

  /// 已提交的去重事务批数。
  final int batches;

  /// 是否被中断（闸门未落，重跑续跑）。
  final bool cancelled;
  final int elapsedMs;

  @override
  String toString() => 'DedupStats(组 $groupsScanned/$totalGroups，判重 $dupGroups，'
      '删除 $rowsDeleted，聚合重算 $groupsRefreshed，批 $batches，'
      'cancelled=$cancelled，${elapsedMs}ms)';
}

/// 归并后的候选重复组（同一 normPerson 下可能有多个原始 recommender 写法）。
class _DupGroupKey {
  _DupGroupKey(this.nameNorm, this.date, this.channel);

  final String nameNorm;

  /// COALESCE(date, '') 口径。
  final String date;
  final String channel;

  /// 原始 recommender 集合（'' = NULL/空）。
  final Set<String> recommenders = <String>{};
}

class _DupMember {
  const _DupMember({
    required this.id,
    required this.comment,
    required this.normComment,
    required this.quality,
    required this.postRef,
    required this.groupId,
  });

  final int id;

  /// COALESCE(comment, '') 原始推荐语（keeper 比长用）。
  final String comment;

  /// normText(comment)（前缀链判定用）。
  final String normComment;
  final int quality;
  final int? postRef;
  final int? groupId;
}

class _DupVerdict {
  const _DupVerdict({required this.deleteIds, required this.groupIds});

  final List<int> deleteIds;

  /// 受影响 book_groups（删除后需重算聚合列；null groupId 已剔除）。
  final Set<int> groupIds;
}

/// book_entries 存量去重（前缀链/同文判重，分叉保守保留；算法见库注释）。
///
/// 在任意已打开连接上可跑（测试用内存库，生产由 [runMaintenance] 的后台 isolate
/// 调起）。[isCancelled] 在组间与批间检查；中断时已提交批次不回滚（幂等）、
/// 闸门不落，重跑续跑。
Future<DedupStats> dedupBookEntries(
  AppDatabase db, {
  int batchGroups = 300,
  bool Function()? isCancelled,
  void Function(DedupStats)? onProgress,
}) async {
  final Stopwatch sw = Stopwatch()..start();
  // 1) 候选分组：SQL 按原始可见键粗筛（COUNT>1），Dart 侧按 normPerson 归并。
  final List<QueryRow> candidates = await db.customSelect(
    "SELECT name_norm AS nn, COALESCE(recommender, '') AS rec, COALESCE(date, '') AS d, "
    'channel AS ch FROM book_entries '
    'GROUP BY nn, rec, d, ch HAVING COUNT(*) > 1',
  ).get();
  final Map<String, _DupGroupKey> merged = <String, _DupGroupKey>{};
  for (final QueryRow row in candidates) {
    final String nn = row.read<String>('nn');
    final String rec = row.read<String>('rec');
    final String d = row.read<String>('d');
    final String ch = row.read<String>('ch');
    final String key = '$nn\u001f${normPerson(rec)}\u001f$d\u001f$ch';
    merged.putIfAbsent(key, () => _DupGroupKey(nn, d, ch)).recommenders.add(rec);
  }
  final List<_DupGroupKey> groups = merged.values.toList(growable: false);

  var scanned = 0, dupGroups = 0, deleted = 0, refreshed = 0, batches = 0;
  var cancelled = false;
  final List<int> pendingDelete = <int>[];
  final Set<int> affectedGroups = <int>{};
  var groupsSinceFlush = 0;

  DedupStats snapshot() => DedupStats(
        totalGroups: groups.length,
        groupsScanned: scanned,
        dupGroups: dupGroups,
        rowsDeleted: deleted,
        groupsRefreshed: refreshed,
        batches: batches,
        cancelled: cancelled,
        elapsedMs: sw.elapsedMilliseconds,
      );

  Future<void> flush() async {
    if (pendingDelete.isEmpty) {
      return;
    }
    final List<int> ids = List<int>.of(pendingDelete);
    final Set<int> gids = Set<int>.of(affectedGroups);
    await db.transaction(() async {
      // SQLite 变量上限保守取 500/语句（现代 SQLite 为 32766，留足余量）。
      for (var i = 0; i < ids.length; i += 500) {
        final List<int> chunk = ids.sublist(i, min(i + 500, ids.length));
        await db.customUpdate(
          'DELETE FROM book_entries WHERE id IN (${List<String>.filled(chunk.length, '?').join(',')})',
          variables: <Variable<Object>>[for (final int id in chunk) Variable.withInt(id)],
          updates: <ResultSetImplementation>{db.bookEntries},
          updateKind: UpdateKind.delete,
        );
      }
      // 受影响组聚合列重算（口径 = ingest.dart _refreshGroupAggregates）。
      for (final int gid in gids) {
        await _refreshGroupAggregates(db, gid);
      }
    });
    deleted += ids.length;
    refreshed += gids.length;
    batches++;
    pendingDelete.clear();
    affectedGroups.clear();
  }

  for (final _DupGroupKey g in groups) {
    if (isCancelled?.call() ?? false) {
      cancelled = true;
      break;
    }
    final List<_DupMember> members = await _fetchDupMembers(db, g);
    final _DupVerdict? verdict = _judgeDupGroup(members);
    scanned++;
    if (verdict != null) {
      dupGroups++;
      pendingDelete.addAll(verdict.deleteIds);
      affectedGroups.addAll(verdict.groupIds);
      groupsSinceFlush++;
    }
    if (groupsSinceFlush >= batchGroups) {
      await flush();
      groupsSinceFlush = 0;
      onProgress?.call(snapshot());
      await Future<void>.delayed(Duration.zero); // 批间让出事件循环，cancel 可达
    }
  }
  if (cancelled) {
    // 已提交批次不回滚（重跑幂等）；未冲刷的判定丢弃，闸门不落 → 重跑续跑。
    return snapshot();
  }
  await flush();
  // 全部完成才落闸门（含「零候选」路径：空库/已去重库直接标记完成）。
  await _writeSetting(db, SettingsKeys.dedupVersion, dedupDoneValue);
  final DedupStats done = snapshot();
  onProgress?.call(done);
  return done;
}

/// 取候选组全部成员（以原始 recommender 集合匹配；normPerson 归并已在分组键完成）。
Future<List<_DupMember>> _fetchDupMembers(AppDatabase db, _DupGroupKey g) async {
  final List<String> recs = g.recommenders.toList(growable: false);
  final String placeholders = List<String>.filled(recs.length, '?').join(',');
  final List<QueryRow> rows = await db.customSelect(
    "SELECT id, COALESCE(comment, '') AS c, quality AS q, post_ref AS pr, book_group_id AS gid "
    'FROM book_entries WHERE name_norm = ? AND channel = ? AND COALESCE(date, \'\') = ? '
    "AND COALESCE(recommender, '') IN ($placeholders)",
    variables: <Variable>[
      Variable.withString(g.nameNorm),
      Variable.withString(g.channel),
      Variable.withString(g.date),
      for (final String r in recs) Variable.withString(r),
    ],
  ).get();
  return <_DupMember>[
    for (final QueryRow r in rows)
      _DupMember(
        id: r.read<int>('id'),
        comment: r.read<String>('c'),
        normComment: normText(r.read<String>('c')),
        quality: r.read<int>('q'),
        postRef: r.read<int?>('pr'),
        groupId: r.read<int?>('gid'),
      ),
  ];
}

/// 组内判定：归一化评论构成前缀链（含完全相同）→ 返回删除集；
/// 中间分叉 → null（整组保守保留）。
_DupVerdict? _judgeDupGroup(List<_DupMember> members) {
  if (members.length < 2) {
    return null;
  }
  final List<_DupMember> byLength = List<_DupMember>.of(members)
    ..sort((_DupMember a, _DupMember b) {
      final int byLen = a.normComment.length.compareTo(b.normComment.length);
      if (byLen != 0) {
        return byLen;
      }
      final int byText = a.normComment.compareTo(b.normComment);
      return byText != 0 ? byText : a.id.compareTo(b.id);
    });
  for (var i = 1; i < byLength.length; i++) {
    if (!byLength[i].normComment.startsWith(byLength[i - 1].normComment)) {
      return null; // 中间分叉：保守不动
    }
  }
  // keeper：comment 最长者优先 → quality 高者 → post_ref 非空者 → id 最小者。
  final _DupMember keeper = (List<_DupMember>.of(members)
        ..sort((_DupMember a, _DupMember b) {
          final int byComment = b.comment.length.compareTo(a.comment.length);
          if (byComment != 0) {
            return byComment;
          }
          final int byQuality = b.quality.compareTo(a.quality);
          if (byQuality != 0) {
            return byQuality;
          }
          final int byRef = (b.postRef != null ? 1 : 0).compareTo(a.postRef != null ? 1 : 0);
          if (byRef != 0) {
            return byRef;
          }
          return a.id.compareTo(b.id);
        }))
      .first;
  return _DupVerdict(
    deleteIds: <int>[for (final _DupMember m in members) if (m.id != keeper.id) m.id],
    groupIds: <int>{
      for (final _DupMember m in members)
        if (m.groupId != null) m.groupId!,
    },
  );
}

/// 组聚合计数重算（entry_total / distinct_comment / word_count_max，
/// 口径与 ingest.dart `_refreshGroupAggregates` 一致；maintenance 侧等价实现，
/// 不改 ingest.dart）。
Future<void> _refreshGroupAggregates(AppDatabase db, int gid) async {
  await db.customUpdate(
    '''UPDATE book_groups SET
         entry_total = (SELECT COUNT(*) FROM book_entries WHERE book_group_id = ?1),
         distinct_comment = (SELECT COUNT(DISTINCT comment_norm_hash) FROM book_entries
                             WHERE book_group_id = ?1
                               AND comment_norm_hash IS NOT NULL
                               AND comment_norm_hash <> ''),
         word_count_max = (SELECT MAX(word_count) FROM book_entries WHERE book_group_id = ?1)
       WHERE id = ?1''',
    variables: <Variable<Object>>[Variable.withInt(gid)],
    updates: <ResultSetImplementation>{db.bookGroups},
    updateKind: UpdateKind.update,
  );
}

// ───────────────────────────── 存量帖 v3 分类回填 ─────────────────────────────

/// 回填进度/结果快照（[reclassifyPostsV3] 的 onProgress 回调与返回值）。
class ReclassifyStats {
  const ReclassifyStats({
    this.totalPosts = 0,
    this.postsScanned = 0,
    this.postsUpdated = 0,
    this.entriesUpdated = 0,
    this.batches = 0,
    this.cancelled = false,
    this.elapsedMs = 0,
  });

  /// posts 总行数。
  final int totalPosts;

  /// 已扫描判定的帖数。
  final int postsScanned;

  /// 实际 UPDATE 的帖数（kind/flag 有变化；kind=null 的帖不计）。
  final int postsUpdated;

  /// 实际 UPDATE 的 book_entries 行数（category 镜像同步为所属帖 post_kind）。
  final int entriesUpdated;

  /// 已处理批数（按 id 游标分批）。
  final int batches;

  /// 是否被中断（闸门未落，重跑续跑）。
  final bool cancelled;
  final int elapsedMs;

  @override
  String toString() => 'ReclassifyStats(帖 $postsScanned/$totalPosts，更新 $postsUpdated，'
      '条目 $entriesUpdated，批 $batches，cancelled=$cancelled，${elapsedMs}ms)';
}

class _PostKindUpdate {
  const _PostKindUpdate(this.id, this.kind, this.flag);

  final int id;
  final String kind;
  final int flag;
}

/// 存量 posts 按 v3 分类器回填 post_kind/recommend_flag，并把所属条目的
/// book_entries.category 镜像同步为当前 post_kind（算法与口径见库注释）。
///
/// [dict] 由调用方一次性构建传入（构建昂贵；生产路径在主 isolate 读词典行、
/// 维护 isolate 内 `BookDict.fromLines` 一次构建复用）。空词典传 [BookDict.empty]
/// 退化为 v2 行为（与 worker.dart 生产绑定同语义）。
Future<ReclassifyStats> reclassifyPostsV3(
  AppDatabase db, {
  required BookDict dict,
  int batchSize = 2000,
  bool Function()? isCancelled,
  void Function(ReclassifyStats)? onProgress,
}) async {
  final Stopwatch sw = Stopwatch()..start();
  final int total =
      (await db.customSelect('SELECT COUNT(*) AS n FROM posts').getSingle()).read<int>('n');
  var cursor = 0, scanned = 0, updated = 0, entriesSynced = 0, batches = 0;
  var cancelled = false;

  ReclassifyStats snapshot() => ReclassifyStats(
        totalPosts: total,
        postsScanned: scanned,
        postsUpdated: updated,
        entriesUpdated: entriesSynced,
        batches: batches,
        cancelled: cancelled,
        elapsedMs: sw.elapsedMilliseconds,
      );

  while (true) {
    if (isCancelled?.call() ?? false) {
      cancelled = true;
      break;
    }
    final List<QueryRow> posts = await db.customSelect(
      "SELECT id, COALESCE(title, '') AS t, post_kind AS k, recommend_flag AS f "
      'FROM posts WHERE id > ? ORDER BY id LIMIT ?',
      variables: <Variable>[Variable.withInt(cursor), Variable.withInt(batchSize)],
    ).get();
    if (posts.isEmpty) {
      break;
    }
    final List<int> ids = <int>[for (final QueryRow p in posts) p.read<int>('id')];
    final Map<int, List<String>> floorsByPost = await _fetchBatchFloors(db, ids);
    final List<_PostKindUpdate> updates = <_PostKindUpdate>[];
    for (final QueryRow p in posts) {
      final int id = p.read<int>('id');
      final String title = p.read<String>('t');
      final List<String> floorTexts = floorsByPost[id] ?? const <String>[];
      // 调用口径严格照 worker.dart analyzeThread：首楼 = seq 升序第一行；
      // 全文 = 标题 + 全楼层 '\n' 拼接；书名抽取 = parse.dart extractBookNames。
      final String firstFloor = floorTexts.isEmpty ? '' : floorTexts.first;
      final String fullText = <String>[title, ...floorTexts].join('\n');
      final ClassifyResult cr = classifyV3(
        title: title,
        firstFloor: firstFloor,
        fullText: fullText,
        booknames: extractBookNames(fullText),
        dict: dict,
      );
      final String? kind = cr.kind;
      if (kind == null) {
        continue; // 日常闲聊：保持原样不动（不删除、不改写）。
      }
      if (kind != p.read<String>('k') || cr.flag != p.read<int>('f')) {
        updates.add(_PostKindUpdate(id, kind, cr.flag));
      }
    }
    // 事务按批必开（不以 updates.isNotEmpty 为条件）：kind 无变化的批也要镜像对齐
    // category（存量全量对齐是本任务目标，闸门一次性，错过本轮不再有下次）。
    final int synced = await db.transaction(() async {
      var n = 0;
      for (final _PostKindUpdate u in updates) {
        await db.customUpdate(
          'UPDATE posts SET post_kind = ?, recommend_flag = ? WHERE id = ?',
          variables: <Variable<Object>>[
            Variable.withString(u.kind),
            Variable.withInt(u.flag),
            Variable.withInt(u.id),
          ],
          updates: <ResultSetImplementation>{db.posts},
          updateKind: UpdateKind.update,
        );
      }
      // category 镜像当前 post_kind：`IS NOT`（SQLite 空安全不等）滤掉已同步行 →
      // 计数 = 实际变化数、重跑幂等；post_ref IS NULL 与指向批外的条目不受影响；
      // 批内 id 均来自 posts，子查询必命中非 NULL。IN 分块 500 防变量上限
      // （同 _fetchBatchFloors 惯例）。
      for (var i = 0; i < ids.length; i += 500) {
        final List<int> chunk = ids.sublist(i, min(i + 500, ids.length));
        n += await db.customUpdate(
          'UPDATE book_entries SET category = '
          '(SELECT post_kind FROM posts WHERE posts.id = book_entries.post_ref) '
          'WHERE post_ref IN (${List<String>.filled(chunk.length, '?').join(',')}) '
          'AND category IS NOT '
          '(SELECT post_kind FROM posts WHERE posts.id = book_entries.post_ref)',
          variables: <Variable<Object>>[for (final int id in chunk) Variable.withInt(id)],
          updates: <ResultSetImplementation>{db.bookEntries},
          updateKind: UpdateKind.update,
        );
      }
      return n;
    });
    updated += updates.length;
    entriesSynced += synced;
    scanned += posts.length;
    cursor = ids.last;
    batches++;
    onProgress?.call(snapshot());
    await Future<void>.delayed(Duration.zero); // 批间让出事件循环，cancel 可达
  }
  if (!cancelled) {
    // 全部完成才落闸门（值 = 当前分类器版本；未来版本升级后 != 即重跑）。
    await _writeSetting(db, SettingsKeys.classifierVersion, '$classifierVersion');
  }
  final ReclassifyStats done = snapshot();
  onProgress?.call(done);
  return done;
}

/// 取一批帖的全部楼层文本（post_id 分组、seq 升序；IN 分块 500 防变量上限）。
Future<Map<int, List<String>>> _fetchBatchFloors(AppDatabase db, List<int> ids) async {
  final Map<int, List<String>> out = <int, List<String>>{};
  for (var i = 0; i < ids.length; i += 500) {
    final List<int> chunk = ids.sublist(i, min(i + 500, ids.length));
    final List<QueryRow> rows = await db.customSelect(
      'SELECT post_id AS pid, text AS t FROM floors '
      'WHERE post_id IN (${List<String>.filled(chunk.length, '?').join(',')}) '
      'ORDER BY post_id, seq',
      variables: <Variable>[for (final int id in chunk) Variable.withInt(id)],
    ).get();
    for (final QueryRow r in rows) {
      out.putIfAbsent(r.read<int>('pid'), () => <String>[]).add(r.read<String>('t'));
    }
  }
  return out;
}

// ───────────────────────────── 生产后台 isolate 编排 ─────────────────────────────

/// 维护阶段（progress 事件归属）。
enum MaintenancePhase { dedup, reclassify }

/// [runMaintenance] 事件类型。
enum MaintenanceEventKind { ready, progress, done, failed }

/// 后台维护事件（ready 携带控制端口；done 报告 didWork/cancelled）。
class MaintenanceEvent {
  const MaintenanceEvent(
    this.kind, {
    this.phase,
    this.port,
    this.message = '',
    this.didWork = false,
    this.cancelled = false,
  });

  final MaintenanceEventKind kind;

  /// progress 事件所属阶段（ready/done/failed 为 null）。
  final MaintenancePhase? phase;

  /// ready 事件的 isolate 控制端口（发送 [maintenanceCancelMessage] 中断）。
  final SendPort? port;
  final String message;

  /// done：是否发生了实际数据修改（供调用方决定刷新 UI）。
  final bool didWork;

  /// done：是否中断收尾（闸门未落，重跑续跑）。
  final bool cancelled;
}

/// 中断 [runMaintenance] 的控制消息。
const String maintenanceCancelMessage = 'cancel';

class _MaintenanceJob {
  const _MaintenanceJob({required this.dbPath, required this.dictLines, required this.events});

  final String dbPath;

  /// 词典行（主 isolate 读入后传入；isolate 内 BookDict.fromLines 一次构建）。
  final List<String> dictLines;
  final SendPort events;
}

/// 后台执行全部待办维护（先 dedup 后 reclassify；各自独立闸门，全部完成才落账）。
///
/// 模式照 seed_import.dart `_ftsRebuildIsolate`：独立 isolate 开第二个 drift 连接
/// （WAL + busy_timeout，与主连接并发安全），控制端口可中断，批间 yield 进度；
/// 取消订阅事件流（或向 ready 事件携带的控制端口发 [maintenanceCancelMessage]）
/// → 批间优雅收尾，闸门不落，重跑续跑。
Stream<MaintenanceEvent> runMaintenance({
  required String dbPath,
  required List<String> dictLines,
}) async* {
  final ReceivePort events = ReceivePort();
  SendPort? control;
  var completed = false;
  try {
    await Isolate.spawn(
      _maintenanceIsolate,
      _MaintenanceJob(dbPath: dbPath, dictLines: dictLines, events: events.sendPort),
      onError: events.sendPort,
      onExit: events.sendPort,
    );
    await for (final Object? msg in events) {
      if (msg is MaintenanceEvent) {
        switch (msg.kind) {
          case MaintenanceEventKind.ready:
            control = msg.port;
            continue;
          case MaintenanceEventKind.done:
            completed = !msg.cancelled;
            yield msg;
            return;
          case MaintenanceEventKind.failed:
            completed = true; // 失败不再补发 cancel
            yield msg;
            return;
          case MaintenanceEventKind.progress:
            yield msg;
        }
      } else if (msg == null) {
        yield const MaintenanceEvent(MaintenanceEventKind.failed, message: '维护 isolate 意外退出');
        return;
      } else if (msg is List) {
        yield MaintenanceEvent(MaintenanceEventKind.failed, message: '维护 isolate 错误: ${msg.first}');
        return;
      }
    }
  } finally {
    if (!completed) {
      control?.send(maintenanceCancelMessage); // 订阅取消/异常 → 通知 isolate 批间收尾
    }
    events.close();
  }
}

/// 维护 isolate 入口：先 dedup 后 reclassify，各自闸门判定，全部完成才落账。
Future<void> _maintenanceIsolate(_MaintenanceJob job) async {
  final ReceivePort control = ReceivePort();
  job.events.send(MaintenanceEvent(MaintenanceEventKind.ready, port: control.sendPort));
  var cancelled = false;
  control.listen((Object? msg) {
    if (msg == maintenanceCancelMessage) {
      cancelled = true;
    }
  });
  // 独立连接：WAL（读写互不阻塞）+ busy_timeout（写写冲突等待），与主连接成对。
  final AppDatabase db = AppDatabase(
    NativeDatabase(
      File(job.dbPath),
      setup: (d) {
        d.execute('PRAGMA busy_timeout=8000');
        d.execute('PRAGMA journal_mode=WAL');
      },
    ),
  );
  final Stopwatch sw = Stopwatch()..start();
  try {
    var didWork = false;
    // 1) book_entries 去重（dedup_version 闸门）。
    if (await needsDedup(db)) {
      final DedupStats stats = await dedupBookEntries(
        db,
        isCancelled: () => cancelled,
        onProgress: (DedupStats s) => job.events.send(MaintenanceEvent(
          MaintenanceEventKind.progress,
          phase: MaintenancePhase.dedup,
          message: 'dedup $s',
        )),
      );
      if (stats.cancelled) {
        job.events.send(
            const MaintenanceEvent(MaintenanceEventKind.done, cancelled: true, message: '已取消（dedup 中断，闸门未落）'));
        return;
      }
      didWork = stats.rowsDeleted > 0;
    }
    // 2) 存量帖 v3 分类回填（classifier_version 闸门；词典一次构建复用）。
    if (await needsReclassify(db)) {
      final BookDict dict = job.dictLines.isEmpty ? BookDict.empty() : BookDict.fromLines(job.dictLines);
      final ReclassifyStats stats = await reclassifyPostsV3(
        db,
        dict: dict,
        isCancelled: () => cancelled,
        onProgress: (ReclassifyStats s) => job.events.send(MaintenanceEvent(
          MaintenanceEventKind.progress,
          phase: MaintenancePhase.reclassify,
          message: 'reclassify $s',
        )),
      );
      if (stats.cancelled) {
        job.events.send(const MaintenanceEvent(MaintenanceEventKind.done,
            cancelled: true, message: '已取消（reclassify 中断，闸门未落）'));
        return;
      }
      didWork = didWork || stats.postsUpdated > 0 || stats.entriesUpdated > 0;
    }
    job.events.send(MaintenanceEvent(
      MaintenanceEventKind.done,
      didWork: didWork,
      message: '后台维护完成（${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s）',
    ));
  } catch (e) {
    job.events.send(MaintenanceEvent(MaintenanceEventKind.failed, message: '$e'));
  } finally {
    await db.close();
    control.close();
  }
}
