/// 数据维护任务单测（lib/data/maintenance.dart）。
///
/// - dedupBookEntries：前缀链/同文判重、分叉保守保留、keeper 次序、组聚合重算、
///   FTS 删除触发器同步、闸门与幂等、中断续跑；
/// - repairPostReferences：种子升级后 book_entries(src_tid)、bookmarks、
///   favorites 的悬空 post 引用修复、闸门与幂等、中断续跑；
/// - reclassifyPostsV3：存量帖 v3 回填（空词典 = v2 行为即可覆盖 T1a 标题规则）、
///   kind=null 不动、book_entries.category 镜像同步（post_ref IS NULL 不动、
///   已同步不重复计）、首楼人工排雷保护、推书条目保留、闸门落账与幂等；
/// - runMaintenance：文件库 + 后台 isolate 端到端（plain test 真实 IO，
///   同 seed_import_test 的 isolate 先例）。
///
/// plain test() + NativeDatabase.memory() / 临时文件库（TESTING.md §3.2）。
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:booksift/classify/classifier.dart';
import 'package:booksift/collector/normalization.dart';
import 'package:booksift/core/constants.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/maintenance.dart';

int _hashSeq = 0;

/// 每行独立的 content_hash（列有 UNIQUE 约束）。
String _hash() => 't${(_hashSeq++).toString().padLeft(12, '0')}';

Future<int> _addPost(
  AppDatabase db, {
  required String title,
  String kind = '扫书',
  int flag = 1,
  int? tid,
  String origin = 'builtin',
  String? author,
  String? firstFloor,
}) async {
  final int id = await db.into(db.posts).insert(PostsCompanion.insert(
        channel: 'yy小说吧',
        title: Value<String?>(title),
        tid: Value<int?>(tid),
        origin: Value<String>(origin),
        author: Value<String?>(author),
        postType: Value<String>(kind), // 种子导入派生口径：post_kind 回退 = post_type
        postKind: Value<String>(kind),
        recommendFlag: Value<int>(flag),
      ));
  if (firstFloor != null) {
    await db.into(db.floors).insert(FloorsCompanion.insert(
          postId: id,
          seq: 1,
          content: Value<String>(firstFloor),
        ));
  }
  return id;
}

Future<int> _addEntry(
  AppDatabase db, {
  required String nameNorm,
  required String comment,
  String recommender = '张三',
  String? date,
  String channel = 'yy小说吧',
  String category = '扫书',
  String? commentSrc,
  int quality = 2,
  int? postRef,
  int? floorRef,
  int? srcTid,
  int? groupId,
  String origin = 'builtin',
}) =>
    db.into(db.bookEntries).insert(BookEntriesCompanion.insert(
          name: nameNorm,
          nameNorm: nameNorm,
          channel: channel,
          contentHash: _hash(),
          recommender: Value<String?>(recommender),
          comment: Value<String?>(comment),
          commentSrc: Value<String?>(commentSrc),
          commentNormHash: Value<String?>(h16(normText(comment))),
          date: Value<String?>(date),
          category: Value<String>(category),
          quality: Value<int>(quality),
          postRef: Value<int?>(postRef),
          floorRef: Value<int?>(floorRef),
          srcTid: Value<int?>(srcTid),
          bookGroupId: Value<int?>(groupId),
          wordCount: Value<int?>(comment.length),
          origin: Value<String>(origin),
        ));

Future<List<int>> _entryIds(AppDatabase db) async =>
    <int>[for (final BookEntry e in await db.select(db.bookEntries).get()) e.id]..sort();

Future<BookEntry> _entry(AppDatabase db, int id) =>
    (db.select(db.bookEntries)..where((BookEntries t) => t.id.equals(id))).getSingle();

Future<BookGroup> _group(AppDatabase db, int gid) =>
    (db.select(db.bookGroups)..where((BookGroups t) => t.id.equals(gid))).getSingle();

Future<Post> _post(AppDatabase db, int id) =>
    (db.select(db.posts)..where((Posts t) => t.id.equals(id))).getSingle();

Future<Floor> _floorOf(AppDatabase db, int postId) =>
    (db.select(db.floors)..where((Floors t) => t.postId.equals(postId))).getSingle();

Future<int> _addBookmark(
  AppDatabase db, {
  required int? postRef,
  required String title,
  String? author,
  String? channel,
}) =>
    db.into(db.bookmarks).insert(BookmarksCompanion.insert(
          postRef: Value<int?>(postRef),
          title: title,
          author: Value<String?>(author),
          channel: Value<String?>(channel),
          createdAt: DateTime(2026, 1, 1),
        ));

Future<Bookmark> _bookmark(AppDatabase db, int id) =>
    (db.select(db.bookmarks)..where((Bookmarks t) => t.id.equals(id))).getSingle();

Future<int> _addFavorite(
  AppDatabase db, {
  required String targetType,
  required int targetId,
  required String title,
  String? subtitle,
}) =>
    db.into(db.favorites).insert(FavoritesCompanion.insert(
          targetType: targetType,
          targetId: targetId,
          title: title,
          subtitle: Value<String?>(subtitle),
          addedAt: DateTime(2026, 1, 1),
        ));

Future<Favorite> _favorite(AppDatabase db, int id) =>
    (db.select(db.favorites)..where((Favorites t) => t.id.equals(id))).getSingle();

Future<int> _ftsCount(AppDatabase db, String term) async => (await db
            .customSelect('SELECT COUNT(*) AS c FROM book_fts WHERE book_fts MATCH ?',
                variables: <Variable>[Variable.withString(term)])
            .getSingle())
        .read<int>('c');

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async => db.close());

  group('dedupBookEntries', () {
    test('前缀链判重：keeper=最长评论，组聚合重算，FTS 触发器同步删除', () async {
      final int gid = await db.into(db.bookGroups).insert(BookGroupsCompanion.insert(
            nameNorm: '链书',
            nameDisplay: const Value<String?>('链书'),
            entryTotal: const Value<int>(3),
            distinctComment: const Value<int>(3),
            wordCountMax: const Value<int>(99), // 故意置脏值，验证重算
          ));
      await _addEntry(db, nameNorm: '链书', comment: '独有词甲', date: '2024-01-01', groupId: gid);
      await _addEntry(db, nameNorm: '链书', comment: '独有词甲乙', date: '2024-01-01', groupId: gid);
      final int keeper = await _addEntry(
          db, nameNorm: '链书', comment: '独有词甲乙丙', date: '2024-01-01', groupId: gid);
      expect(await _ftsCount(db, '独有词甲'), 3, reason: '删除前 3 行均入 FTS');

      final DedupStats stats = await dedupBookEntries(db);

      expect(stats.cancelled, false);
      expect(stats.totalGroups, 1);
      expect(stats.dupGroups, 1);
      expect(stats.rowsDeleted, 2);
      expect(stats.batches, 1, reason: '单组一次提交');
      expect(await _entryIds(db), <int>[keeper], reason: '最长评论者为 keeper');
      // 组聚合列按 ingest._refreshGroupAggregates 口径重算。
      final BookGroup g = await _group(db, gid);
      expect(g.entryTotal, 1);
      expect(g.distinctComment, 1);
      expect(g.wordCountMax, '独有词甲乙丙'.length);
      // book_fts 由既有 AFTER DELETE 触发器同步（不自建索引逻辑）。
      expect(await _ftsCount(db, '独有词甲'), 1);
      // 闸门落账。
      expect(await needsDedup(db), false);
      expect(
        (await db.customSelect(
          "SELECT value AS v FROM settings WHERE key = '${SettingsKeys.dedupVersion}'",
        ).getSingle())
            .read<String>('v'),
        '1',
      );
    });

    test('同文判重 keeper 次序：quality 高者 → post_ref 非空 → id 最小', () async {
      final int pid = await _addPost(db, title: '月度扫书', firstFloor: '《同文书》 作者：某人 不错');
      // 组 A（recommender=张三）：quality 2 并列两条 → post_ref 非空者胜；quality 1 垫底删。
      await _addEntry(db, nameNorm: '同文书', comment: '同一本书推荐');
      final int keeperA = await _addEntry(db, nameNorm: '同文书', comment: '同一本书推荐', postRef: pid);
      await _addEntry(db, nameNorm: '同文书', comment: '同一本书推荐', quality: 1);
      // 组 B（recommender=李四）：comment/quality/post_ref 全并列 → id 最小者胜。
      final int keeperB =
          await _addEntry(db, nameNorm: '同文书', comment: '同文再测', recommender: '李四');
      await _addEntry(db, nameNorm: '同文书', comment: '同文再测', recommender: '李四');

      final DedupStats stats = await dedupBookEntries(db);

      expect(stats.rowsDeleted, 3);
      expect(stats.dupGroups, 2);
      expect(await _entryIds(db), containsAllInOrder(<int>[keeperA, keeperB]));
    });

    test('中间分叉的组整组保留（保守不动）', () async {
      // 归一化后 6/6/8 长：'推荐语abc' 与 '推荐语abd' 同长互不为前缀 → 分叉。
      await _addEntry(db, nameNorm: '分叉书', comment: '推荐语abc');
      await _addEntry(db, nameNorm: '分叉书', comment: '推荐语abd');
      await _addEntry(db, nameNorm: '分叉书', comment: '推荐语abcde');

      final DedupStats stats = await dedupBookEntries(db);

      expect(stats.dupGroups, 0);
      expect(stats.rowsDeleted, 0);
      expect((await _entryIds(db)).length, 3, reason: '分叉组一行不删');
      expect(await needsDedup(db), false, reason: '无删除也落闸门（完成即标记）');
    });

    test('幂等：闸门落账后重跑 0 删除', () async {
      await _addEntry(db, nameNorm: '链书', comment: '再跑一遍甲', date: '2024-01-01');
      await _addEntry(db, nameNorm: '链书', comment: '再跑一遍甲乙', date: '2024-01-01');

      final DedupStats first = await dedupBookEntries(db);
      expect(first.rowsDeleted, 1);
      expect(await needsDedup(db), false);

      final DedupStats second = await dedupBookEntries(db);
      expect(second.totalGroups, 0, reason: '去重后已无候选组');
      expect(second.rowsDeleted, 0);
      expect((await _entryIds(db)).length, 1);
    });

    test('中断：已提交批次保留、闸门不落、重跑续完全量', () async {
      // 三个独立前缀链组（各 2 行），batchGroups=1 → 每组一提交。
      for (final String name in <String>['书甲', '书乙', '书丙']) {
        await _addEntry(db, nameNorm: name, comment: '$name 推荐语甲');
        await _addEntry(db, nameNorm: name, comment: '$name 推荐语甲乙');
      }
      var cancelCalls = 0;
      final DedupStats partial = await dedupBookEntries(
        db,
        batchGroups: 1,
        isCancelled: () => ++cancelCalls >= 3, // 第三次组间检查触发中断
      );
      expect(partial.cancelled, true);
      expect(partial.rowsDeleted, 2, reason: '中断前已提交 2 批各删 1 行');
      expect(partial.batches, 2);
      expect(await needsDedup(db), true, reason: '中断不落闸门');
      expect((await _entryIds(db)).length, 4);

      final DedupStats resumed = await dedupBookEntries(db);
      expect(resumed.cancelled, false);
      expect(resumed.rowsDeleted, 1, reason: '重跑只补剩余 1 组');
      expect(await needsDedup(db), false);
      expect((await _entryIds(db)).length, 3);
    });
  });

  group('dedupLegacyCollectedPosts（存量自采/种子重复帖）', () {
    test('同吧同标题的两行合并为一帖；同帖同书保留长评/自采版本', () async {
      final int gid = await db.into(db.bookGroups).insert(
            BookGroupsCompanion.insert(
              nameNorm: '链书',
              nameDisplay: const Value<String?>('链书'),
              entryTotal: const Value<int>(2),
              distinctComment: const Value<int>(2),
            ),
          );
      final int seedPost = await _addPost(
        db,
        title: '月度扫书',
        origin: 'seed',
        firstFloor: '旧正文',
      );
      final Floor seedFloor = await _floorOf(db, seedPost);
      await _addEntry(
        db,
        nameNorm: '链书',
        comment: '短评',
        date: '2025-10-01',
        postRef: seedPost,
        floorRef: seedFloor.id,
        groupId: gid,
        origin: 'seed',
      );

      final int collectedPost = await _addPost(
        db,
        title: '月度扫书',
        origin: 'collected',
        tid: 11001,
        firstFloor: '新正文',
      );
      final Floor collectedFloor = await _floorOf(db, collectedPost);
      final int collectedEntry = await _addEntry(
        db,
        nameNorm: '链书',
        comment: '短评补全自采',
        date: '2025-10-09',
        postRef: collectedPost,
        floorRef: collectedFloor.id,
        groupId: gid,
        origin: 'collected',
      );
      final int bookmarkId = await _addBookmark(
        db,
        postRef: collectedPost,
        title: '月度扫书',
        channel: 'yy小说吧',
      );
      final int favoriteId = await _addFavorite(
        db,
        targetType: 'post',
        targetId: collectedPost,
        title: '月度扫书',
      );

      final LegacyPostDedupStats stats = await dedupLegacyCollectedPosts(db);

      expect(stats.postsMerged, 1);
      expect(stats.entriesDeleted, 1);
      expect(await needsLegacyPostDedup(db), false);
      expect(await db.posts.count().getSingle(), 1);
      final Post post = await db.select(db.posts).getSingle();
      expect(post.id, seedPost, reason: '保留 seed 行以维持既有 floor_ref/post_ref 引用');
      expect(post.tid, 11001);
      expect(post.origin, 'collected');
      expect(post.floorCount, 1);

      expect(await db.floors.count().getSingle(), 1);
      final Floor floor = await db.select(db.floors).getSingle();
      expect(floor.id, seedFloor.id);
      expect(floor.content, '新正文');

      expect(await db.bookEntries.count().getSingle(), 1);
      final BookEntry entry = await db.select(db.bookEntries).getSingle();
      expect(entry.id, collectedEntry, reason: '长评/自采版本胜出');
      expect(entry.postRef, seedPost);
      expect(entry.floorRef, seedFloor.id);
      expect(entry.origin, 'collected');
      expect((await _group(db, gid)).entryTotal, 1);
      expect(
        (await _bookmark(db, bookmarkId)).postRef,
        seedPost,
        reason: '书签须从被删 collected 帖重挂到 seed keeper',
      );
      expect(
        (await _favorite(db, favoriteId)).targetId,
        seedPost,
        reason: '帖子收藏须从被删 collected 帖重挂到 seed keeper',
      );
    });
    test('同标题但双方 tid 都非空且不同：不得合并', () async {
      await _addPost(db, title: '同名不同帖', tid: 100, origin: 'seed');
      await _addPost(db, title: '同名不同帖', tid: 200, origin: 'collected');

      final LegacyPostDedupStats stats = await dedupLegacyCollectedPosts(db);

      expect(stats.postsMerged, 0);
      expect(await db.posts.count().getSingle(), 2);
    });
  });

  group('repairPostReferences', () {
    test('src_tid 回填条目；悬空书签/收藏按标题回填；闸门落账且二次幂等', () async {
      // 同标题 seed 行先插入（id 更小），验证匹配优先 origin='collected'。
      await _addPost(db, title: '种子升级样例帖', origin: 'seed');
      final int postId = await _addPost(
        db,
        title: '种子升级样例帖',
        tid: 11113728843,
        origin: 'collected',
      );
      final int entryId = await _addEntry(
        db,
        nameNorm: '样例书',
        comment: '样例推荐语',
        postRef: null,
        srcTid: 11113728843,
        origin: 'seed',
      );
      final int bookmarkId = await _addBookmark(
        db,
        postRef: 999999,
        title: '种子升级样例帖',
        channel: 'yy小说吧',
      );
      final int favoriteId = await _addFavorite(
        db,
        targetType: 'post',
        targetId: 999999,
        title: '种子升级样例帖',
      );

      expect(await needsPostRefRepair(db), isTrue);
      final PostRefRepairStats stats = await repairPostReferences(db);

      expect(stats.cancelled, false);
      expect(stats.entriesRepaired, 1);
      expect(stats.bookmarksRepaired, 1);
      expect(stats.favoritesRepaired, 1);
      expect((await _entry(db, entryId)).postRef, postId);
      expect((await _bookmark(db, bookmarkId)).postRef, postId);
      expect((await _favorite(db, favoriteId)).targetId, postId);
      expect(await needsPostRefRepair(db), isFalse);
      expect(
        (await db.customSelect(
          'SELECT value AS v FROM settings WHERE key = ?',
          variables: <Variable>[
            Variable.withString(SettingsKeys.postRefRepairVersion),
          ],
        ).getSingle())
            .read<String>('v'),
        '1',
      );

      final PostRefRepairStats second = await repairPostReferences(db);
      expect(second.cancelled, false);
      expect(second.entriesRepaired, 0);
      expect(second.bookmarksRepaired, 0);
      expect(second.favoritesRepaired, 0);
      expect(await needsPostRefRepair(db), isFalse);
    });

    test('post_ref 指向错误 tid 时按 src_tid 重挂（旧版按 id 串帖）', () async {
      final int wrongPost = await _addPost(
        db,
        title: '错误种子帖',
        tid: 11113728840,
        origin: 'seed',
      );
      final int targetPost = await _addPost(
        db,
        title: '正确自采帖',
        tid: 11113728841,
        origin: 'collected',
      );
      final int entryId = await _addEntry(
        db,
        nameNorm: '错配书',
        comment: '错配推荐语',
        postRef: wrongPost,
        srcTid: 11113728841,
        origin: 'seed',
      );

      final PostRefRepairStats stats = await repairPostReferences(db);

      expect(stats.entriesRepaired, 1);
      expect((await _entry(db, entryId)).postRef, targetPost);
    });

    test('id 存在但标题不符：书签/收藏按标题改挂，错误 floor_ref 清空', () async {
      final int wrongPost = await _addPost(
        db,
        title: '旧标题占位帖',
        tid: 11113728842,
        origin: 'seed',
        firstFloor: '旧楼层',
      );
      final Floor wrongFloor = await _floorOf(db, wrongPost);
      final int targetPost = await _addPost(
        db,
        title: '正确标题自采帖',
        tid: 11113728843,
        origin: 'collected',
      );
      final int bookmarkId = await _addBookmark(
        db,
        postRef: wrongPost,
        title: '正确标题自采帖',
        channel: 'yy小说吧',
      );
      final int favoriteId = await _addFavorite(
        db,
        targetType: 'post',
        targetId: wrongPost,
        title: '正确标题自采帖',
      );
      final int entryId = await _addEntry(
        db,
        nameNorm: '楼层错配书',
        comment: '楼层错配推荐语',
        postRef: targetPost,
        floorRef: wrongFloor.id,
        origin: 'seed',
      );

      final PostRefRepairStats stats = await repairPostReferences(db);

      expect(stats.bookmarksRepaired, 1);
      expect(stats.favoritesRepaired, 1);
      expect((await _bookmark(db, bookmarkId)).postRef, targetPost);
      expect((await _favorite(db, favoriteId)).targetId, targetPost);
      expect((await _entry(db, entryId)).floorRef, isNull,
          reason: 'floor_ref 不属于 post_ref 时必须清空，避免跳错楼');
    });

    test('同名多候选：书签置 NULL、收藏删除，不 LIMIT 1 猜帖', () async {
      await _addPost(db, title: '同名候选帖', tid: 11113728844, origin: 'collected');
      await _addPost(db, title: '同名候选帖', tid: 11113728845, origin: 'collected');
      final int bookmarkId = await _addBookmark(
        db,
        postRef: 999997,
        title: '同名候选帖',
        channel: 'yy小说吧',
      );
      final int favoriteId = await _addFavorite(
        db,
        targetType: 'post',
        targetId: 999997,
        title: '同名候选帖',
      );

      await repairPostReferences(db);

      expect((await _bookmark(db, bookmarkId)).postRef, isNull);
      expect(
        await (db.select(db.favorites)
              ..where((Favorites t) => t.id.equals(favoriteId)))
            .getSingleOrNull(),
        isNull,
      );
    });

    test('book_group 收藏按《书名》+作者回挂到新组 id', () async {
      final int gid = await db.into(db.bookGroups).insert(BookGroupsCompanion.insert(
            nameNorm: '组修复书',
            nameDisplay: const Value<String?>('组修复书'),
            authorDisplay: const Value<String?>('组作者'),
          ));
      final int favoriteId = await _addFavorite(
        db,
        targetType: 'book_group',
        targetId: 999996,
        title: '《组修复书》',
        subtitle: '组作者',
      );

      await repairPostReferences(db);

      expect((await _favorite(db, favoriteId)).targetId, gid);
    });

    test('无匹配：书签置 NULL；收藏按 schema 约束删除（target_id NOT NULL）', () async {
      final int bookmarkId = await _addBookmark(
        db,
        postRef: 999998,
        title: '已不存在的帖子',
      );
      final int favoriteId = await _addFavorite(
        db,
        targetType: 'post',
        targetId: 999998,
        title: '已不存在的帖子',
      );

      final PostRefRepairStats stats = await repairPostReferences(db);

      expect(stats.bookmarksRepaired, 1);
      expect(stats.favoritesRepaired, 1);
      expect((await _bookmark(db, bookmarkId)).postRef, isNull);
      expect(
        await (db.select(db.favorites)
              ..where((Favorites t) => t.id.equals(favoriteId)))
            .getSingleOrNull(),
        isNull,
        reason: 'target_id 为 NOT NULL，无法置 NULL，只能删除悬空收藏行',
      );
      expect(await needsPostRefRepair(db), isFalse);
    });

    test('中断：不落闸门，重跑可继续修复', () async {
      final int postId = await _addPost(
        db,
        title: '中断样例帖',
        tid: 11113728844,
        origin: 'collected',
      );
      final int entryId = await _addEntry(
        db,
        nameNorm: '中断样例书',
        comment: '中断样例推荐语',
        srcTid: 11113728844,
        origin: 'seed',
      );

      final PostRefRepairStats partial = await repairPostReferences(
        db,
        isCancelled: () => true,
      );
      expect(partial.cancelled, true);
      expect(await needsPostRefRepair(db), isTrue);
      expect((await _entry(db, entryId)).postRef, isNull);

      final PostRefRepairStats resumed = await repairPostReferences(db);
      expect(resumed.cancelled, false);
      expect(resumed.entriesRepaired, 1);
      expect((await _entry(db, entryId)).postRef, postId);
      expect(await needsPostRefRepair(db), isFalse);
    });
  });

  group('reclassifyPostsV3', () {
    test('旧分类器闸门 3 在版本 4 下触发重跑', () async {
      await db
          .into(db.settings)
          .insertOnConflictUpdate(
            SettingsCompanion.insert(
              key: SettingsKeys.classifierVersion,
              value: '3',
            ),
          );
      expect(classifierVersion, 5);
      expect(await needsReclassify(db), isTrue);

      await _addPost(db, title: '排雷：旧库样例');
      final ReclassifyStats stats =
          await reclassifyPostsV3(db, dict: BookDict.empty());
      expect(stats.postsUpdated, 1);
      expect(await needsReclassify(db), isFalse);
      expect(
        (await db.customSelect(
          "SELECT value AS v FROM settings WHERE key = '${SettingsKeys.classifierVersion}'",
        ).getSingle()).read<String>('v'),
        '$classifierVersion',
      );
    });

    test('排雷标题帖回填为 排雷/-1；未变不动；kind=null 保持原样；闸门落账', () async {
      // CLI 实测（空词典）：排雷：… → 排雷/-1（T1a）；月度扫书：… → 扫书/1（T1d）；
      // 闲聊标题 → kind=null。
      final int p1 = await _addPost(
        db,
        title: '排雷：《开局合欢宗，被师姐拿捏命脉》',
        firstFloor: '女主有毒，强行送女，剧毒慎入',
      );
      final int p2 = await _addPost(
        db,
        title: '月度扫书：九月汇总',
        firstFloor: '《雪中悍刀行》 作者：烽火戏诸侯 天不生我李淳罡，剑道万古如长夜。',
      );
      final int p3 = await _addPost(
        db,
        title: '今天天气不错，随便聊聊',
        firstFloor: '如题，大家今天都在干嘛',
      );
      final int p4 = await _addPost(db, title: '排雷：另一本《毒草集》'); // 无楼层路径

      final ReclassifyStats stats =
          await reclassifyPostsV3(db, dict: BookDict.empty(), batchSize: 2);

      expect(stats.totalPosts, 4);
      expect(stats.batches, 2, reason: 'batchSize=2 × 4 帖');
      expect(stats.postsScanned, 4);
      expect(stats.postsUpdated, 2, reason: '仅 p1/p4 的 kind/flag 发生变化');
      expect(stats.cancelled, false);

      final Post post1 = await _post(db, p1);
      expect(post1.postKind, '排雷');
      expect(post1.recommendFlag, -1);
      final Post post4 = await _post(db, p4);
      expect(post4.postKind, '排雷', reason: '无楼层帖也应按标题规则回填');
      expect(post4.recommendFlag, -1);
      final Post post2 = await _post(db, p2);
      expect(post2.postKind, '扫书', reason: 'v3 判定与现值一致 → 不动');
      expect(post2.recommendFlag, 1);
      final Post post3 = await _post(db, p3);
      expect(post3.postKind, '扫书', reason: 'kind=null（日常）保持原样不动');
      expect(post3.recommendFlag, 1);

      // 闸门落账 = 当前分类器版本；重跑由调用方按闸门跳过。
      expect(await needsReclassify(db), false);
      expect(
        (await db.customSelect(
          "SELECT value AS v FROM settings WHERE key = '${SettingsKeys.classifierVersion}'",
        ).getSingle())
            .read<String>('v'),
        '$classifierVersion',
      );
    });

    test('category 镜像同步：重判帖条目跟随；post_ref NULL 不动；已同步不重复计', () async {
      // p1 将被 v3 重判为 排雷；p2 的 kind 判定与现值一致（扫书）不变。
      final int p1 = await _addPost(
        db,
        title: '排雷：《开局合欢宗，被师姐拿捏命脉》',
        firstFloor: '女主有毒，强行送女，剧毒慎入',
      );
      final int p2 = await _addPost(
        db,
        title: '月度扫书：九月汇总',
        firstFloor: '《雪中悍刀行》 作者：烽火戏诸侯 天不生我李淳罡，剑道万古如长夜。',
      );
      final int e1 = await _addEntry(db, nameNorm: '合欢宗', comment: '旧值条目', postRef: p1);
      final int e2 = await _addEntry(db, nameNorm: '雪中悍刀行', comment: '已同步条目', postRef: p2);
      final int e3 =
          await _addEntry(db, nameNorm: '无帖书', comment: '无帖可依', category: '求书');
      final int e4 = await _addEntry(
          db, nameNorm: '合欢宗', comment: '预同步条目', postRef: p1, category: '排雷');

      final List<ReclassifyStats> snaps = <ReclassifyStats>[];
      final ReclassifyStats stats = await reclassifyPostsV3(
        db,
        dict: BookDict.empty(),
        onProgress: snaps.add,
      );

      expect(stats.postsUpdated, 1, reason: '仅 p1 kind/flag 变化');
      expect(stats.entriesUpdated, 1, reason: 'e1 失同步；e2/e4 已同步、e3 无帖可依均不计');
      expect((await _entry(db, e1)).category, '排雷', reason: '跟随所属帖新 kind');
      expect((await _entry(db, e2)).category, '扫书');
      expect((await _entry(db, e3)).category, '求书', reason: 'post_ref IS NULL 不动');
      expect((await _entry(db, e4)).category, '排雷');
      expect(snaps.last.entriesUpdated, 1, reason: 'onProgress 快照带 entriesUpdated');
      expect(await needsReclassify(db), false, reason: '闸门照旧落账');
    });

    test('首楼明确排雷强制校正 post 与普通条目，人工推书条目保留', () async {
      final int pid = await _addPost(
        db,
        title: '普通标题',
        firstFloor: '避雷：《人工书》剧毒慎入',
      );
      final int curated = await _addEntry(
        db,
        nameNorm: '人工书',
        comment: '人工记录',
        postRef: pid,
        category: '排雷',
      );
      final int stale = await _addEntry(
        db,
        nameNorm: '旧条目',
        comment: '旧分类',
        postRef: pid,
        category: '扫书',
      );

      final ReclassifyStats stats = await reclassifyPostsV3(
        db,
        dict: BookDict.empty(),
      );
      final Post post = await _post(db, pid);
      expect(post.postKind, '排雷', reason: '人工排雷标签强制覆盖规则');
      expect(post.recommendFlag, -1);
      expect((await _entry(db, curated)).category, '排雷');
      expect((await _entry(db, stale)).category, '排雷');
      expect(stats.postsScanned, 1);
      expect(stats.protectedPosts, 1);
      expect(stats.postsUpdated, 1);
      expect(stats.entriesUpdated, 1);
    });

    test('首楼明确推书帖级强制扫书，条目 category=推书 不被镜像覆盖', () async {
      final int pid = await _addPost(
        db,
        title: '普通标题',
        kind: '排雷',
        flag: -1,
        firstFloor: '推书：《人工推书》节奏不错',
      );
      final int recommend = await _addEntry(
        db,
        nameNorm: '人工推书',
        comment: '节奏不错',
        postRef: pid,
        category: '推书',
      );

      final ReclassifyStats stats = await reclassifyPostsV3(
        db,
        dict: BookDict.empty(),
      );
      final Post post = await _post(db, pid);
      expect(post.postKind, '扫书');
      expect(post.recommendFlag, 1);
      expect((await _entry(db, recommend)).category, '推书');
      expect(stats.protectedPosts, 1);
      expect(stats.postsUpdated, 1);
      expect(stats.entriesUpdated, 0, reason: '已经是推书，不重复计');
    });

    test('人工标签按楼层前缀写条目，不把普通“扫书”当保护标签', () async {
      final int pushPost = await _addPost(
        db,
        title: '普通标题',
        firstFloor: '推书：《推书甲》好看',
      );
      final int pushEntry = await _addEntry(
        db,
        nameNorm: '推书甲',
        comment: '好看',
        postRef: pushPost,
        category: '排雷',
      );
      final int scanPost = await _addPost(
        db,
        title: '扫书：九月合集',
        firstFloor: '扫书：《扫书乙》毒点很多，劝退。',
      );
      final int scanEntry = await _addEntry(
        db,
        nameNorm: '扫书乙',
        comment: '毒点很多，劝退。',
        postRef: scanPost,
        category: '扫书',
      );

      final ReclassifyStats stats = await reclassifyPostsV3(
        db,
        dict: BookDict.empty(),
      );

      expect((await _entry(db, pushEntry)).category, '推书');
      expect((await _post(db, pushPost)).postKind, '扫书');
      expect(
        (await _entry(db, scanEntry)).category,
        '排雷',
        reason: '普通扫书不是人工保护标签，仍由规则细化',
      );
      expect((await _post(db, scanPost)).postKind, '排雷');
      expect(stats.protectedPosts, 1);
    });

    test('宝典 item 开头排雷只保护对应条目，其他条目继续跟随帖级规则', () async {
      final int pid = await _addPost(
        db,
        title: '扫书：两本都不错',
        firstFloor: '两本都值得看。',
      );
      final int curatedMine = await _addEntry(
        db,
        nameNorm: '人工排雷书',
        comment: '\u3000\u3000排雷：《人工排雷书》剧毒慎入',
        commentSrc: 'clist_item',
        postRef: pid,
        category: '扫书',
      );
      final int curatedScan = await _addEntry(
        db,
        nameNorm: '规则扫书',
        comment: '普通评论里提到排雷，但开头不是人工标签',
        commentSrc: 'clist_item',
        postRef: pid,
        category: '排雷',
      );
      final int orphanMine = await _addEntry(
        db,
        nameNorm: '孤立人工排雷书',
        comment: '\u3000\u3000排雷：《孤立人工排雷书》',
        commentSrc: 'clist_item',
        category: '扫书',
      );

      final ReclassifyStats stats = await reclassifyPostsV3(
        db,
        dict: BookDict.empty(),
      );

      expect((await _post(db, pid)).postKind, '扫书');
      expect((await _entry(db, curatedMine)).category, '排雷',
          reason: '宝典 item 开头明确排雷，条目不得被帖级镜像覆盖');
      expect((await _entry(db, curatedScan)).category, '扫书',
          reason: '非开头的普通提及不构成人工保护');
      expect((await _entry(db, orphanMine)).category, '排雷',
          reason: '没有帖可依的人工排雷条目也必须保护');
      expect(stats.protectedPosts, 1);
      expect(stats.entriesUpdated, 3);

      final ReclassifyStats second = await reclassifyPostsV3(
        db,
        dict: BookDict.empty(),
      );
      expect(second.postsUpdated, 0);
      expect(second.entriesUpdated, 0, reason: '人工保护与镜像更新均应幂等');
    });

    test('kind=null（日常闲聊）帖的条目按当前 post_kind 镜像（updates 为空也开事务）', () async {
      final int pid = await _addPost(
        db,
        title: '今天天气不错，随便聊聊',
        firstFloor: '如题，大家今天都在干嘛',
      );
      final int eid = await _addEntry(
          db, nameNorm: '闲聊书', comment: '闲聊帖条目', postRef: pid, category: '求书');

      final ReclassifyStats stats = await reclassifyPostsV3(db, dict: BookDict.empty());

      expect(stats.postsUpdated, 0, reason: 'kind=null 帖保持原样');
      expect(stats.entriesUpdated, 1, reason: '整轮无任何 post 变化，事务仍执行了 category 同步');
      expect((await _entry(db, eid)).category, '扫书', reason: '镜像当前 post_kind');
    });

    test('幂等：二刷 postsUpdated == 0 且 entriesUpdated == 0', () async {
      final int pid = await _addPost(db, title: '排雷：另一本《毒草集》');
      await _addEntry(db, nameNorm: '毒草集', comment: '排雷条目', postRef: pid);

      final ReclassifyStats first = await reclassifyPostsV3(db, dict: BookDict.empty());
      expect(first.postsUpdated, 1);
      expect(first.entriesUpdated, 1);

      final ReclassifyStats second = await reclassifyPostsV3(db, dict: BookDict.empty());
      expect(second.postsUpdated, 0);
      expect(second.entriesUpdated, 0);
      expect(second.cancelled, false);
    });
  });

  group('runMaintenance（后台 isolate 端到端）', () {
    test('文件库：dedup+reclassify 全跑并落闸门，二刷 didWork=false', () async {
      final Directory dir = await Directory.systemTemp.createTemp('maintenance_it');
      addTearDown(() async {
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      });
      final String path = p.join(dir.path, 'app.sqlite');
      // 准备：一条前缀链重复 + 一条种子派生口径的排雷标题帖。
      final AppDatabase setupDb = AppDatabase(NativeDatabase(File(path)));
      await _addEntry(setupDb, nameNorm: '链书', comment: '端到端甲', date: '2024-01-01');
      await _addEntry(setupDb, nameNorm: '链书', comment: '端到端甲乙', date: '2024-01-01');
      await _addPost(
        setupDb,
        title: '排雷：《开局合欢宗，被师姐拿捏命脉》',
        firstFloor: '女主有毒，剧毒慎入',
      );
      await setupDb.close();

      final List<MaintenanceEvent> events = <MaintenanceEvent>[];
      await for (final MaintenanceEvent e
          in runMaintenance(dbPath: path, dictLines: const <String>[])) {
        events.add(e);
      }
      final MaintenanceEvent done = events.last;
      expect(done.kind, MaintenanceEventKind.done);
      expect(done.cancelled, false);
      expect(done.didWork, true);
      expect(events.where((e) => e.kind == MaintenanceEventKind.failed), isEmpty);

      final AppDatabase verifyDb = AppDatabase(NativeDatabase(File(path)));
      expect(await needsPostRefRepair(verifyDb), false);
      expect(await needsDedup(verifyDb), false);
      expect(await needsReclassify(verifyDb), false);
      expect(await needsLegacyPostDedup(verifyDb), false);
      expect((await verifyDb.select(verifyDb.bookEntries).get()).length, 1);
      final Post post = (await verifyDb.select(verifyDb.posts).get()).single;
      expect(post.postKind, '排雷');
      expect(post.recommendFlag, -1);
      await verifyDb.close();

      // 二刷：双闸门均已落账 → isolate 内零工作量。
      MaintenanceEvent? second;
      await for (final MaintenanceEvent e
          in runMaintenance(dbPath: path, dictLines: const <String>[])) {
        if (e.kind == MaintenanceEventKind.done) {
          second = e;
        }
      }
      expect(second, isNotNull);
      expect(second!.didWork, false);
    });
  });
}
