/// 入库管线（§8.7 步骤 5：单帖单事务 posts+floors+images+book_entries+
/// book_groups UPSERT；三层去重见 §8.7）。
///
/// FTS 由 app_database.dart 的 external-content 触发器自动维护，无需手动重建。
/// **注意**：posts 表（schema v2）没有 hit_rules/classifier_version 列，
/// 分类命中规则只进运行日志（任务书约束）。
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/constants.dart';
import '../data/db/app_database.dart';
import 'normalization.dart';
import 'tieba/src/models.dart';
import 'worker.dart';

/// 单帖完整原始数据（跨页累积后的楼层 + 帖元信息）。
class ThreadRecord {
  ThreadRecord({
    required this.fname,
    required this.tid,
    required this.title,
    required this.authorId,
    required this.author,
    required this.authorUserName,
    required this.createTime,
    required this.floors,
    this.partial = false,
  });

  final String fname;
  final int tid;
  final String title;
  final int authorId;
  final String author;
  final String authorUserName;
  final int createTime;

  /// 全部楼层（按 seq 升序、pid 去重后）。
  final List<FloorInfo> floors;

  /// 超长帖截断标记（§8.7 步骤 4：pn>20 → partial）。
  final bool partial;

  int get imageCount => floors.fold<int>(0, (int s, FloorInfo f) => s + f.images.length);
}

/// 单帖入库结果（计数进 CollectStats）。
class IngestResult {
  const IngestResult({
    required this.postId,
    this.newPost = false,
    this.floorsAdded = 0,
    this.imagesAdded = 0,
    this.entriesAdded = 0,
    this.skippedDup = 0,
    this.postRefBackfilled = 0,
  });

  final int postId;

  /// posts 是否新建（重入时 tid UNIQUE 命中 → false，threadsAdded 不计）。
  final bool newPost;
  final int floorsAdded;
  final int imagesAdded;
  final int entriesAdded;

  /// content_hash 命中本帖既有行或无溯源种子行（按帖去重，见 [ingestThread] §3 注释）。
  final int skippedDup;

  /// 命中 dup 且既有行 post_ref 为空 → 回填条数（对标 merge_etl 补链逻辑）。
  final int postRefBackfilled;
}

class IngestPipeline {
  IngestPipeline(this.db);

  final AppDatabase db;

  /// 单帖单事务（§8.8「事务粒度 = 单帖」；drift 单连接串行事务天然单写者）。
  Future<IngestResult> ingestThread(
    ThreadRecord rec,
    ThreadAnalysis analysis, {
    DateTime? collectedAt,
  }) {
    final DateTime now = collectedAt ?? DateTime.now();
    return db.transaction(() async {
      // ── 1. posts：INSERT OR IGNORE by tid（去重层 1，§8.7） ──
      final Post? existing = await (db.select(db.posts)
            ..where((Posts t) => t.tid.equals(rec.tid)))
          .getSingleOrNull();
      final String dateStr = _beijingDate(rec.createTime);
      int postId;
      bool newPost = false;
      if (existing == null) {
        newPost = true;
        postId = await db.into(db.posts).insert(PostsCompanion.insert(
          tid: Value<int?>(rec.tid),
          title: Value<String?>(rec.title),
          author: Value<String?>(rec.author),
          authorName: Value<String?>(
              rec.authorUserName.isEmpty ? null : rec.authorUserName),
          userId: Value<int?>(rec.authorId),
          date: Value<String?>(dateStr.isEmpty ? null : dateStr),
          dateRaw: Value<String?>('${rec.createTime}'),
          channel: rec.fname,
          // 自采帖无源 post_type 留档，两列同取产品分类（schema 注释允许）。
          postType: Value<String>(analysis.kind ?? '扫书'),
          postKind: Value<String>(analysis.kind ?? '扫书'),
          recommendFlag: Value<int>(analysis.flag), // kindFlag 派生（§8.9）
          floorCount: Value<int>(rec.floors.length),
          imageCount: Value<int>(rec.imageCount),
          origin: Value<String>(Origin.collected),
          collectedAt: Value<DateTime?>(now),
        ));
      } else {
        postId = existing.id;
      }

      // ── 2. floors：按 pid UPSERT（去重层 2；编辑过的楼层更新文本，§8.7） ──
      final List<Floor> existingFloors = await (db.select(db.floors)
            ..where((Floors t) => t.postId.equals(postId)))
          .get();
      final Map<int, Floor> byPid = <int, Floor>{
        for (final Floor f in existingFloors)
          if (f.pid != null) f.pid!: f,
      };
      final Map<int, int> floorIdByPid = <int, int>{};
      int floorsAdded = 0;
      int imagesAdded = 0;
      for (final FloorInfo f in rec.floors) {
        final String textHash = h16(normText(f.text));
        final DateTime? createdAt = f.time > 0
            ? DateTime.fromMillisecondsSinceEpoch(f.time * 1000, isUtc: true)
            : null;
        final Floor? ex = f.pid != 0 ? byPid[f.pid] : null;
        int floorId;
        if (ex == null) {
          floorId = await db.into(db.floors).insert(FloorsCompanion.insert(
            postId: postId,
            seq: f.seq,
            pid: Value<int?>(f.pid == 0 ? null : f.pid),
            content: Value<String>(f.text),
            textNormHash: Value<String?>(textHash),
            charCount: Value<int>(f.text.length),
            createdAt: Value<DateTime?>(createdAt),
            authorId: Value<int?>(f.authorId),
          ));
          floorsAdded++;
          imagesAdded += await _insertImages(floorId, f.images);
        } else {
          floorId = ex.id;
          // 幂等：文本未变则整行不动（第二遍跑全 skipped、行数不变）。
          if (ex.content != f.text || ex.textNormHash != textHash) {
            await (db.update(db.floors)
                  ..where((Floors t) => t.id.equals(floorId)))
                .write(FloorsCompanion(
              content: Value<String>(f.text),
              textNormHash: Value<String?>(textHash),
              charCount: Value<int>(f.text.length),
              seq: Value<int>(f.seq),
            ));
            await (db.delete(db.images)
                  ..where((Images t) => t.floorId.equals(floorId)))
                .go();
            imagesAdded += await _insertImages(floorId, f.images);
          }
        }
        if (f.pid != 0) floorIdByPid[f.pid] = floorId;
      }

      // ── 3. book_entries：按帖去重（§8.7 去重层 3 修订；口径见 entryContentHash）──
      //
      // 旧口径（三参 hash，全局唯一）会把「同一本书被两个帖推荐且推荐语相同/皆空」
      // 判成重复丢弃 → 推荐次数恒为 1。现改为按帖口径：
      //   newHash = h16(name_norm 1f author_norm 1f comment_norm_hash 1f postId)
      // 查重按 (newHash, 旧三参hash) 双键命中，优先级 本帖行 > 无溯源种子行(NULL) > 他帖行：
      //   - 命中本帖行           → skippedDup（同帖重采幂等）；
      //   - 命中 post_ref IS NULL → 回填溯源后 skippedDup（对标 merge_etl 补链）；
      //   - 命中他帖行           → 不算重复，插入新行 = 一次新的推荐记录
      //     （newHash 含本 postId，与既有行 content_hash UNIQUE 不冲突，无 schema 迁移）；
      //   - 未命中               → 插入。
      int entriesAdded = 0;
      int skippedDup = 0;
      int backfilled = 0;
      final Set<int> touchedGroups = <int>{};
      final String kind = analysis.kind ?? '扫书';
      for (final EntryDraft e in analysis.entries) {
        final String postHash = entryContentHash(
          nameNorm: e.nameNorm,
          authorNorm: e.authorNorm,
          commentNormHash: e.commentNormHash,
          postRef: postId,
        );
        final BookEntry? hit = await (db.select(db.bookEntries)
              ..where((BookEntries t) =>
                  t.contentHash.isIn(<String>[postHash, e.contentHash]))
              ..orderBy(<OrderingTerm Function(BookEntries)>[
                // (post_ref = postId) DESC：布尔表达式对 NULL 行取 0（isNotNull 短路），
                // 避免 SQL 三值逻辑把 NULL 行排到最后（种子行须先于他帖行命中）。
                (BookEntries t) => OrderingTerm(
                    expression: t.postRef.isNotNull() & t.postRef.equals(postId),
                    mode: OrderingMode.desc),
                // (post_ref IS NULL) DESC：无溯源种子行次优先（走回填）。
                (BookEntries t) => OrderingTerm(
                    expression: t.postRef.isNull(), mode: OrderingMode.desc),
              ])
              ..limit(1))
            .getSingleOrNull();
        // 命中他帖行 = 跨帖同书推荐，按未命中处理（插入新行各记一条）。
        final BookEntry? dup =
            (hit != null && hit.postRef != null && hit.postRef != postId) ? null : hit;
        if (dup != null) {
          skippedDup++;
          // keeper 无溯源而 dup 有时回填（§8.7 对标 merge_etl 补链逻辑）。
          if (dup.postRef == null) {
            await (db.update(db.bookEntries)
                  ..where((BookEntries t) => t.id.equals(dup.id)))
                .write(BookEntriesCompanion(
              postRef: Value<int?>(postId),
              floorRef: Value<int?>(floorIdByPid[e.floorPid]),
              srcTid: dup.srcTid == null ? Value<int?>(rec.tid) : const Value<int?>.absent(),
              srcUrl: dup.srcUrl == null
                  ? Value<String?>(_srcUrl(rec.tid))
                  : const Value<String?>.absent(),
            ));
            backfilled++;
          }
          continue;
        }
        final int gid = await _upsertGroup(
          nameNorm: e.nameNorm,
          name: e.name,
          author: e.author,
          authorNorm: e.authorNorm,
          fname: rec.fname,
          date: dateStr,
        );
        touchedGroups.add(gid);
        await db.into(db.bookEntries).insert(BookEntriesCompanion.insert(
          name: e.name,
          nameNorm: e.nameNorm,
          channel: rec.fname,
          // 按帖口径 hash（含 postId）：跨帖同书同语各记一条推荐（见 §3 注释）。
          contentHash: postHash,
          author: Value<String?>(e.author),
          authorNorm: Value<String?>(e.authorNorm.isEmpty ? null : e.authorNorm),
          authorKind: Value<String?>(e.author != null ? 'parsed' : null),
          recommender: Value<String?>(rec.author),
          comment: Value<String?>(e.comment),
          commentSrc: Value<String?>('collected_floor'),
          commentNormHash: Value<String?>(e.commentNormHash),
          date: Value<String?>(dateStr.isEmpty ? null : dateStr),
          dateRaw: Value<String?>('${rec.createTime}'),
          // category 冗余自 posts.post_kind（§7.2：避免搜索 join）。
          category: Value<String>(kind),
          postRef: Value<int?>(postId),
          floorRef: Value<int?>(floorIdByPid[e.floorPid]),
          srcTid: Value<int?>(rec.tid),
          srcUrl: Value<String?>(_srcUrl(rec.tid)),
          // word_count = 小说字数；自采拿不到该数据，写 NULL（评论长度≠字数，
          // 写长度会污染书详情字数副行与字数榜）。同书内置条目经
          // book_groups.word_count_max = MAX(word_count) 跨条目继承，NULL 不参与。
          quality: Value<int>(e.quality),
          bookGroupId: Value<int?>(gid),
          origin: Value<String>(Origin.collected),
          collectedAt: Value<DateTime?>(now),
        ));
        entriesAdded++;
      }

      // ── 4. book_groups 聚合计数重算（与种子组同 name_norm 自动聚合，§8.7） ──
      for (final int gid in touchedGroups) {
        await _refreshGroupAggregates(gid);
      }

      return IngestResult(
        postId: postId,
        newPost: newPost,
        floorsAdded: floorsAdded,
        imagesAdded: imagesAdded,
        entriesAdded: entriesAdded,
        skippedDup: skippedDup,
        postRefBackfilled: backfilled,
      );
    });
  }

  Future<int> _insertImages(int floorId, List<ImageInfo> images) async {
    for (final ImageInfo img in images) {
      await db.into(db.images).insert(ImagesCompanion.insert(
        floorId: floorId,
        urlOriginal: Value<String?>(
            img.urlOriginal.isEmpty ? null : img.urlOriginal),
        urlPermanent: Value<String?>(
            img.urlPermanent.isEmpty ? null : img.urlPermanent),
        width: Value<int>(img.width),
        height: Value<int>(img.height),
      ));
    }
    return images.length;
  }

  /// book_groups 按 name_norm UPSERT（§8.7：自采条目与内置条目聚合进同一组）。
  Future<int> _upsertGroup({
    required String nameNorm,
    required String name,
    required String? author,
    required String authorNorm,
    required String fname,
    required String date,
  }) async {
    final BookGroup? g = await (db.select(db.bookGroups)
          ..where((BookGroups t) => t.nameNorm.equals(nameNorm)))
        .getSingleOrNull();
    if (g == null) {
      return db.into(db.bookGroups).insert(BookGroupsCompanion.insert(
        nameNorm: nameNorm,
        authorEffNorm: Value<String>(authorNorm),
        nameDisplay: Value<String?>(name),
        authorDisplay: Value<String?>(author),
        channels: Value<String?>(jsonEncode(<String>[fname])),
        dateMin: Value<String?>(date),
        dateMax: Value<String?>(date),
      ));
    }
    // 渠道集合合并（JSON 数组，§7.2 channels 口径）。
    final Set<String> channels = <String>{};
    try {
      final List<dynamic> decoded =
          jsonDecode(g.channels ?? '[]') as List<dynamic>;
      channels.addAll(decoded.cast<String>());
    } catch (_) {
      // 渠道列损坏时重建（不致命）。
    }
    channels.add(fname);
    await (db.update(db.bookGroups)..where((BookGroups t) => t.id.equals(g.id)))
        .write(BookGroupsCompanion(
      channels: Value<String?>(jsonEncode(channels.toList())),
      dateMin: Value<String?>(
          g.dateMin == null || date.compareTo(g.dateMin!) < 0 ? date : g.dateMin),
      dateMax: Value<String?>(
          g.dateMax == null || date.compareTo(g.dateMax!) > 0 ? date : g.dateMax),
      // 组级作者展示位为空时用新条目补（不回退既有值）。
      authorEffNorm: g.authorEffNorm.isEmpty && authorNorm.isNotEmpty
          ? Value<String>(authorNorm)
          : const Value<String>.absent(),
      authorDisplay: (g.authorDisplay == null || g.authorDisplay!.isEmpty) &&
              author != null
          ? Value<String?>(author)
          : const Value<String?>.absent(),
    ));
    return g.id;
  }

  /// 组聚合计数重算（entry_total / distinct_comment / word_count_max，
  /// §7.2 book_groups 榜单口径；SQL 聚合保证与全量重算一致）。
  Future<void> _refreshGroupAggregates(int gid) async {
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
      updates: {db.bookGroups},
      updateKind: UpdateKind.update,
    );
  }
}

/// 帖子源链（§7.2 src_url 口径）。
String _srcUrl(int tid) => 'https://tieba.baidu.com/p/$tid';

/// epoch 秒 → 北京时间 'YYYY-MM-DD'（贴吧时间戳为东八区，models.dart 同口径）。
String _beijingDate(int epochSec) {
  if (epochSec <= 0) return '';
  final String s = beijingTimeStr(epochSec);
  return s.length >= 10 ? s.substring(0, 10) : '';
}
