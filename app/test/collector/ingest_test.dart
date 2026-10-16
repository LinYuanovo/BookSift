/// 入库管线单测（§8.7 单帖单事务 + 三层去重 + book_group 聚合）。
/// plain test() + NativeDatabase.memory()（TESTING.md §3.2）。
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/classify/classifier.dart';
import 'package:booksift/collector/ingest.dart';
import 'package:booksift/collector/normalization.dart';
import 'package:booksift/collector/tieba/src/models.dart';
import 'package:booksift/collector/worker.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/queries.dart';

import 'support.dart';

const int _createTime = 1760000000; // 2025-10-09 17:33 北京时间
const String _floorText = '《雪中悍刀行》 作者：烽火戏诸侯 天不生我李淳罡，剑道万古如长夜。';

ThreadRecord _record({
  int tid = 11001,
  String fname = 'yy小说吧',
  String title = '月度扫书',
  String floorText = _floorText,
  List<ImageInfo> images = const <ImageInfo>[],
}) =>
    ThreadRecord(
      fname: fname,
      tid: tid,
      title: title,
      authorId: 7,
      author: '楼主显示名',
      authorUserName: 'lz_user_name',
      createTime: _createTime,
      floors: <FloorInfo>[
        FloorInfo(
          pid: tid * 10 + 1,
          seq: 1,
          authorId: 7,
          author: '楼主显示名',
          time: _createTime,
          text: floorText,
          images: images,
        ),
      ],
    );

Future<ThreadAnalysis> _analysis(ThreadRecord rec,
        {ThreadClassifier? classify}) async =>
    LocalPostWorker(classify ?? fakeClassify).analyze(ThreadInput(
      tid: rec.tid,
      title: rec.title,
      author: rec.author,
      createTime: rec.createTime,
      floors: <FloorInput>[
        for (final FloorInfo f in rec.floors)
          FloorInput(pid: f.pid, seq: f.seq, text: f.text),
      ],
    ));

void main() {
  late AppDatabase db;
  late IngestPipeline pipeline;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    pipeline = IngestPipeline(db);
  });
  tearDown(() async => db.close());

  Future<IngestResult> ingestOne({
    ThreadRecord? rec,
    ThreadClassifier? classify,
  }) async {
    final ThreadRecord r = rec ?? _record();
    return pipeline.ingestThread(r, await _analysis(r, classify: classify),
        collectedAt: DateTime(2026, 10, 13, 8, 0, 0));
  }

  test('单帖单事务：posts/floors/images/book_entries/book_groups 全落库', () async {
    final ImageInfo img = ImageInfo(
      urlOriginal: 'http://tiebapic.baidu.com/x/sign=abc',
      urlPermanent: 'https://imgsrc.baidu.com/forum/pic/item/'
          '0123456789abcdef0123456789abcdef',
      hash: '0123456789abcdef0123456789abcdef',
      width: 100,
      height: 50,
    );
    final IngestResult r = await ingestOne(rec: _record(images: <ImageInfo>[img]));

    expect(r.newPost, true);
    expect(r.floorsAdded, 1);
    expect(r.imagesAdded, 1);
    expect(r.entriesAdded, 1);

    final Post post = await db.select(db.posts).getSingle();
    expect(post.tid, 11001);
    expect(post.origin, 'collected');
    expect(post.channel, 'yy小说吧');
    expect(post.postKind, PostKind.scan);
    expect(post.recommendFlag, 1);
    expect(post.author, '楼主显示名');
    expect(post.authorName, 'lz_user_name');
    expect(post.date, beijingTimeStr(_createTime).substring(0, 10));
    expect(post.dateRaw, '$_createTime');
    expect(post.floorCount, 1);
    expect(post.imageCount, 1);
    expect(post.collectedAt, isNotNull);

    final Floor floor = await db.select(db.floors).getSingle();
    expect(floor.content, _floorText);
    expect(floor.textNormHash, h16(normText(_floorText)));
    expect(floor.charCount, _floorText.length);
    expect(floor.pid, 110011);

    final FloorImage image = await db.select(db.images).getSingle();
    expect(image.urlPermanent, img.urlPermanent);

    final BookEntry entry = await db.select(db.bookEntries).getSingle();
    expect(entry.name, '雪中悍刀行');
    expect(entry.nameNorm, '雪中悍刀行');
    expect(entry.author, '烽火戏诸侯');
    expect(entry.authorKind, 'parsed');
    expect(entry.commentSrc, 'collected_floor');
    expect(entry.category, PostKind.scan);
    expect(entry.origin, 'collected');
    expect(entry.recommender, '楼主显示名');
    expect(entry.srcTid, 11001);
    expect(entry.srcUrl, 'https://tieba.baidu.com/p/11001');
    expect(entry.quality, 3);
    // 按帖口径 hash：旧三参拼接尾部追加 0x1f + post_ref（问题C）。
    expect(entry.contentHash,
        entryContentHash(
          nameNorm: normName('雪中悍刀行'),
          authorNorm: normPerson('烽火戏诸侯'),
          commentNormHash: h16(normText(_floorText)),
          postRef: post.id,
        ));
    expect(entry.commentNormHash, h16(normText(_floorText)));
    expect(entry.postRef, post.id);
    expect(entry.floorRef, floor.id);
    // 自采无小说字数数据：word_count 必须为 NULL，不得写推荐语长度（问题D）。
    expect(entry.wordCount, isNull);

    final BookGroup group = await db.select(db.bookGroups).getSingle();
    expect(group.nameNorm, '雪中悍刀行');
    expect(group.entryTotal, 1);
    expect(group.distinctComment, 1);
    expect(group.channels, contains('yy小说吧'));
    expect(entry.bookGroupId, group.id);

    // FTS 触发器自动维护（§7.3）
    final int ftsHits = (await db.customSelect(
      "SELECT COUNT(*) c FROM book_fts WHERE book_fts MATCH '雪中悍'",
    ).getSingle()).data['c'] as int;
    expect(ftsHits, 1);
  });

  test('幂等：同数据二遍 → 全 skippedDup、行数不变（§8.7 去重三层）', () async {
    final IngestResult r1 = await ingestOne();
    final IngestResult r2 = await ingestOne();
    expect(r1.entriesAdded, 1);
    expect(r2.newPost, false);
    expect(r2.floorsAdded, 0);
    expect(r2.entriesAdded, 0);
    expect(r2.skippedDup, 1);
    expect(await db.posts.count().getSingle(), 1);
    expect(await db.floors.count().getSingle(), 1);
    expect(await db.bookEntries.count().getSingle(), 1);
    expect(await db.bookGroups.count().getSingle(), 1);
    final BookGroup g = await db.select(db.bookGroups).getSingle();
    expect(g.entryTotal, 1, reason: '聚合计数不因重入虚增');
  });

  test('种子帖 tid 与源不一致：按同吧同标题回认，楼层/条目就地合并，不新建重复帖', () async {
    final int seedPostId = await db.into(db.posts).insert(PostsCompanion.insert(
          title: const Value<String?>('月度扫书'),
          tid: const Value<int?>(99999),
          channel: 'yy小说吧',
          origin: const Value<String>('seed'),
          date: const Value<String?>('2025-10-01'),
          floorCount: const Value<int>(1),
        ));
    final int seedFloorId = await db.into(db.floors).insert(FloorsCompanion.insert(
          postId: seedPostId,
          seq: 1,
          content: const Value<String>('《雪中悍刀行》 作者：烽火戏诸侯 旧推荐语'),
        ));
    final int seedEntryId =
        await db.into(db.bookEntries).insert(BookEntriesCompanion.insert(
              name: '雪中悍刀行',
              nameNorm: '雪中悍刀行',
              channel: 'yy小说吧',
              contentHash: 'seedhashlegacy0001',
              comment: const Value<String?>('《雪中悍刀行》 作者：烽火戏诸侯 旧推荐语'),
              commentNormHash: Value<String?>(
                  h16(normText('《雪中悍刀行》 作者：烽火戏诸侯 旧推荐语'))),
              postRef: Value<int?>(seedPostId),
              floorRef: Value<int?>(seedFloorId),
              origin: const Value<String>('seed'),
            ));

    final IngestResult r = await ingestOne();

    expect(r.newPost, false);
    expect(await db.posts.count().getSingle(), 1);
    final Post post = await db.select(db.posts).getSingle();
    expect(post.id, seedPostId);
    expect(post.tid, 11001);
    expect(post.origin, 'collected');

    expect(await db.floors.count().getSingle(), 1);
    final Floor floor = await db.select(db.floors).getSingle();
    expect(floor.id, seedFloorId);
    expect(floor.pid, 110011, reason: '种子 pid 为空时按 seq 对齐并回填 pid');
    expect(floor.content, _floorText);

    expect(await db.bookEntries.count().getSingle(), 1);
    final BookEntry entry = await db.select(db.bookEntries).getSingle();
    expect(entry.id, seedEntryId, reason: '就地覆盖旧行，避免书聚合页重复卡片');
    expect(entry.postRef, seedPostId);
    expect(entry.floorRef, seedFloorId);
    expect(entry.origin, 'collected');
    expect(entry.comment, _floorText);
  });

  test('楼层编辑按 pid UPSERT 更新文本，同帖同书仍只保留一条（§8.7 去重层 2）', () async {
    await ingestOne();
    final IngestResult r2 = await ingestOne(
        rec: _record(floorText: '《雪中悍刀行》 作者：烽火戏诸侯 修订后的推荐语'));
    expect(r2.floorsAdded, 0);
    expect(await db.floors.count().getSingle(), 1);
    final Floor f = await db.select(db.floors).getSingle();
    expect(f.content, contains('修订后的推荐语'));
    expect(f.textNormHash, h16(normText(f.content)));
    // 推荐语变长 → 同帖同书就地把旧行覆盖为完整版，避免书聚合页出现两条
    // 点击后进入同一帖的重复卡片。
    expect(await db.bookEntries.count().getSingle(), 1);
    final BookEntry entry = await db.select(db.bookEntries).getSingle();
    expect(entry.comment, contains('修订后的推荐语'));
    final BookGroup g = await db.select(db.bookGroups).getSingle();
    expect(g.entryTotal, 1);
    expect(g.distinctComment, 1);
  });

  test('dup 命中且 keeper 无溯源 → 回填 post_ref（对标 merge_etl 补链）', () async {
    // 预置一条无溯源的 keeper（模拟种子库条目）
    final String hash = entryContentHash(
      nameNorm: normName('雪中悍刀行'),
      authorNorm: normPerson('烽火戏诸侯'),
      commentNormHash: h16(normText(_floorText)),
    );
    await db.into(db.bookEntries).insert(BookEntriesCompanion.insert(
          name: '雪中悍刀行',
          nameNorm: '雪中悍刀行',
          channel: '大佬贴吧扫书',
          contentHash: hash,
          comment: Value<String?>(_floorText),
          commentNormHash: Value<String?>(h16(normText(_floorText))),
        ));
    final IngestResult r = await ingestOne();
    expect(r.entriesAdded, 0);
    expect(r.skippedDup, 1);
    expect(r.postRefBackfilled, 1);
    final BookEntry keeper = await db.select(db.bookEntries).getSingle();
    expect(keeper.postRef, isNotNull);
    expect(keeper.srcTid, 11001);
    expect(await db.bookEntries.count().getSingle(), 1);
  });

  test('同书同推荐语两帖入库 → 按帖各记一条推荐（问题C：rankRows cnt=2）', () async {
    final IngestResult r1 = await ingestOne();
    final IngestResult r2 = await ingestOne(rec: _record(tid: 11002));
    expect(r1.entriesAdded, 1);
    expect(r2.entriesAdded, 1, reason: '跨帖同书同语 = 第二次推荐，不得按全局 hash 丢弃');
    expect(r2.skippedDup, 0);
    expect(await db.bookEntries.count().getSingle(), 2);
    // 两条 hash 互异（按帖口径含 post_ref）、聚合进同一 book_group。
    final List<BookEntry> entries = await db.select(db.bookEntries).get();
    expect(entries.map((BookEntry e) => e.contentHash).toSet(), hasLength(2));
    expect(entries.map((BookEntry e) => e.bookGroupId).toSet(), hasLength(1));

    // 榜单/热门口径：自采与内置同权，不过滤 origin（问题E）。
    final Queries q = Queries(db);
    final DateTime today = DateTime(2025, 10, 10);
    final List<RankRow> rows = await q.rankRows(RankWindow.allTime, today: today);
    expect(rows, hasLength(1));
    expect(rows.single.nameNorm, '雪中悍刀行');
    expect(rows.single.count, 2, reason: 'COUNT(*) 按帖计数 = 真实推荐次数');
    final List<HotBook> hot = await q.hotBooks(limit: 5);
    expect(hot, hasLength(1));
    expect(hot.single.nameNorm, '雪中悍刀行');
    expect(hot.single.entryTotal, 2);
    // 字数榜：自采 word_count=NULL → 不污染字数榜（问题D）。
    expect(await q.wordRankRows(RankWindow.allTime, today: today), isEmpty);
  });

  test('存量旧口径行（三参 hash）：同帖重采幂等、他帖同书仍新记一条（问题C向后兼容）', () async {
    final IngestResult r1 = await ingestOne();
    expect(r1.entriesAdded, 1);
    // 模拟升级前采集落库的行：hash 改回旧三参口径（post_ref 已指向本帖）。
    final String legacyHash = entryContentHash(
      nameNorm: normName('雪中悍刀行'),
      authorNorm: normPerson('烽火戏诸侯'),
      commentNormHash: h16(normText(_floorText)),
    );
    await db.customUpdate(
      'UPDATE book_entries SET content_hash = ?',
      variables: <Variable<Object>>[Variable.withString(legacyHash)],
      updates: {db.bookEntries},
      updateKind: UpdateKind.update,
    );
    // 原帖重采：旧 hash 命中且 post_ref=本帖 → 幂等跳过，不重复插入。
    final IngestResult r1b = await ingestOne();
    expect(r1b.entriesAdded, 0);
    expect(r1b.skippedDup, 1);
    expect(await db.bookEntries.count().getSingle(), 1);
    // 新帖同书同语：命中他帖行 → 不算重复，插入新行（新 hash 含本帖 id，UNIQUE 不冲突）。
    final IngestResult r2 = await ingestOne(rec: _record(tid: 11002));
    expect(r2.entriesAdded, 1);
    expect(await db.bookEntries.count().getSingle(), 2);
  });

  test('与既有种子组同 name_norm → 聚合进同一 book_group（§8.7）', () async {
    final int gid = await db.into(db.bookGroups).insert(BookGroupsCompanion.insert(
          nameNorm: '雪中悍刀行',
          authorEffNorm: const Value<String>('烽火戏诸侯'),
          nameDisplay: const Value<String?>('雪中悍刀行'),
          entryTotal: const Value<int>(5),
          channels: const Value<String?>('["大佬贴吧扫书"]'),
          dateMin: const Value<String?>('2020-01-01'),
          dateMax: const Value<String?>('2024-12-31'),
        ));
    // 组下挂 5 条种子条目（entry_total 按 SQL 聚合重算，须有实条目支撑）
    for (int i = 0; i < 5; i++) {
      await db.into(db.bookEntries).insert(BookEntriesCompanion.insert(
            name: '雪中悍刀行',
            nameNorm: '雪中悍刀行',
            channel: '大佬贴吧扫书',
            contentHash: 'seedhash000000$i',
            commentNormHash: Value<String?>('seedcch0000000$i'),
            bookGroupId: Value<int?>(gid),
          ));
    }
    final IngestResult r = await ingestOne();
    expect(r.entriesAdded, 1);
    final BookEntry entry = (await db.select(db.bookEntries).get())
        .firstWhere((BookEntry e) => e.origin == 'collected');
    expect(entry.bookGroupId, gid);
    expect(await db.bookGroups.count().getSingle(), 1, reason: '不新建组');
    final BookGroup g = await db.select(db.bookGroups).getSingle();
    expect(g.entryTotal, 6);
    expect(g.distinctComment, 6);
    expect(g.channels, contains('大佬贴吧扫书'));
    expect(g.channels, contains('yy小说吧'));
    expect(g.dateMin, '2020-01-01');
    expect(g.dateMax, beijingTimeStr(_createTime).substring(0, 10));
  });

  test('排雷帖：recommend_flag=-1、entries.category=排雷（§8.9）', () async {
    final IngestResult r = await ingestOne(
      rec: _record(title: '排雷帖', floorText: '《毒草书》 作者：某人 剧毒慎入'),
    );
    expect(r.entriesAdded, 1);
    final Post post = await db.select(db.posts).getSingle();
    expect(post.postKind, PostKind.mine);
    expect(post.recommendFlag, -1);
    final BookEntry entry = await db.select(db.bookEntries).getSingle();
    expect(entry.category, PostKind.mine);
  });
}
