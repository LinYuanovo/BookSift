import 'dart:convert';
import 'dart:io';

import 'package:booksift/classify/classifier.dart';
import 'package:booksift/content/content_draft.dart';
import 'package:booksift/content/content_store.dart';
import 'package:booksift/content/document_reader.dart';
import 'package:booksift/core/constants.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/maintenance.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/headless/env.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'document_reader_test.dart' show sampleImage;

void main() {
  late AppDatabase db;
  late ContentStore store;
  late Queries queries;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = ContentStore(db);
    queries = Queries(db);
  });
  tearDown(() => db.close());

  ContentDraft draft(String text, {String source = ''}) =>
      const DocumentReader().read(
        bytes: Uint8List.fromList(utf8.encode(text)),
        fileName: '扫书原文.txt',
        sourceUrl: source,
        now: DateTime.utc(2026, 11, 4),
      );

  test('真实入库：原始字节、图片、全文索引、首页、书页与来源一体回读', () async {
    final ContentDraft input = draft(
      '推荐：《星海旅程》 作者：林原\n完整长评${'原始真实内容' * 160}\n最终校验词。',
      source: 'https://mp.weixin.qq.com/s/real',
    );
    final ContentSaveResult result = await store.save(
      input.copyWith(
        floors: <ContentFloorDraft>[
          ContentFloorDraft(
            text: input.floors.single.text,
            images: const <ContentImageDraft>[
              ContentImageDraft(url: 'data:image/png;base64,$sampleImage'),
            ],
          ),
        ],
      ),
    );
    expect(result.entryCount, 1);
    final PostDetailData detail = (await queries.postDetail(result.postId))!;
    expect(detail.post.origin, Origin.imported);
    expect(detail.sourceUrl, input.sourceUrl);
    expect(detail.floors.single.floor.content, contains('最终校验词'));
    expect(
      detail.floors.single.images.single.urlOriginal,
      startsWith('data:image/png'),
    );
    final document = (await store.original(result.postId))!;
    expect(document.originalBytes, input.rawDocument);
    expect(
      document.originalHash,
      sha256.convert(input.rawDocument!).toString(),
    );
    expect((await queries.timelinePosts(limit: 40)).single.entryCount, 1);
    expect(
      (await queries.searchBooks(const SearchFilter(query: '星海旅程'))).page.total,
      1,
    );
    final BookEntry entry = await db.select(db.bookEntries).getSingle();
    expect(entry.comment, contains('最终校验词'));
    expect(entry.wordCount, isNull);
    final BookDetailData book = (await queries.bookDetail(entry.bookGroupId!))!;
    expect(book.group.entryTotal, 1);
    expect(book.recommendCount, 1);
    expect(book.group.authorDisplay, '林原');
    expect(
      (await db
              .customSelect(
                "SELECT count(*) AS n FROM floor_fts WHERE floor_fts MATCH '最终校验'",
              )
              .getSingle())
          .read<int>('n'),
      1,
    );
  });

  test('同一来源及原文重复导入幂等，不同帖子同书正常聚合', () async {
    final ContentDraft input = draft('《春日记事》 作者：刘然\n全部评价。');
    final ContentSaveResult first = await store.save(input);
    final ContentSaveResult duplicate = await store.save(input);
    expect(duplicate.alreadyImported, isTrue);
    expect(duplicate.postId, first.postId);
    await store.save(input.copyWith(sourceUrl: 'https://example.com/another'));
    expect((await db.select(db.posts).get()).length, 2);
    expect((await db.select(db.bookEntries).get()).length, 2);
    expect((await db.select(db.bookGroups).get()).single.entryTotal, 2);
    await dedupBookEntries(db);
    expect((await db.select(db.bookEntries).get()).length, 2);
  });

  test('无法识别及日常分类的导入帖在首页完整可见，可编辑补书', () async {
    final ContentSaveResult saved = await store.save(
      draft('读书观点\n未识别的完整讨论和末尾。').copyWith(category: CategoryKind.daily),
    );
    expect(saved.entryCount, 0);
    expect(
      (await queries.timelinePosts(limit: 40)).single.summary,
      contains('完整讨论'),
    );
    final SearchOutcome fallbackSearch = await queries.searchBooks(
      const SearchFilter(query: '完整讨论'),
    );
    expect(fallbackSearch.postTotal, 1);
    expect(fallbackSearch.posts.single.post.id, saved.postId);
    final ContentDraft current = (await store.load(saved.postId))!;
    await store.save(
      current.copyWith(
        entries: <ContentEntryDraft>[
          ContentEntryDraft(
            name: '新书校对',
            author: '真实作者',
            comment: current.floors.single.text,
            channel: current.channel,
            date: current.date,
          ),
        ],
      ),
    );
    expect(
      (await queries.searchBooks(const SearchFilter(query: '新书校对'))).page.total,
      1,
    );
  });

  test('编辑存量内置帖子保留 ID、图片、书签、收藏和初次原始快照', () async {
    final ContentSaveResult imported = await store.save(
      draft('《旧书名》 作者：旧作者\n旧评价。'),
    );
    final int postId = imported.postId;
    final BookEntry oldEntry = await db.select(db.bookEntries).getSingle();
    final Floor oldFloor = await db.select(db.floors).getSingle();
    await (db.delete(
      db.contentDocuments,
    )..where((ContentDocuments table) => table.postId.equals(postId))).go();
    await (db.update(db.posts)..where((Posts table) => table.id.equals(postId)))
        .write(const PostsCompanion(origin: Value<String>(Origin.seed)));
    await (db.update(db.bookEntries)
          ..where((BookEntries table) => table.id.equals(oldEntry.id)))
        .write(const BookEntriesCompanion(origin: Value<String>(Origin.seed)));
    await queries.toggleFavorite(
      targetType: FavoriteTarget.post,
      targetId: postId,
      title: '旧标题',
    );
    await queries.togglePostBookmark(
      postRef: postId,
      title: '旧标题',
      floorSeq: 1,
    );
    final ContentDraft current = (await store.load(postId))!;
    await store.save(
      current.copyWith(
        title: '新标题',
        author: '新书评人',
        floors: <ContentFloorDraft>[
          ContentFloorDraft(id: oldFloor.id, text: '新的正文检索锚点'),
        ],
        entries: <ContentEntryDraft>[
          ContentEntryDraft(
            id: oldEntry.id,
            name: '新书名',
            author: '新作者',
            comment: '新评价完整结尾',
            channel: current.channel,
            date: current.date,
            category: '排雷',
          ),
        ],
      ),
    );
    final Post post = await db.select(db.posts).getSingle();
    expect(post.id, postId);
    expect(post.origin, Origin.imported);
    final BookEntry entry = await db.select(db.bookEntries).getSingle();
    expect(entry.id, oldEntry.id);
    expect(entry.floorRef, oldFloor.id);
    expect(entry.origin, Origin.imported);
    expect((await db.select(db.favorites).get()).single.title, '新标题');
    expect((await db.select(db.bookmarks).get()).single.title, '新标题');
    expect(
      (await queries.searchBooks(const SearchFilter(query: '旧书名'))).page.total,
      0,
    );
    expect(
      (await queries.searchBooks(const SearchFilter(query: '新书名'))).page.total,
      1,
    );
    expect((await queries.bookDetail(entry.bookGroupId!))!.avoidCount, 1);
    final original = (await store.original(postId))!;
    expect(utf8.decode(original.originalBytes), contains('旧评价'));
    await store.save((await store.load(postId))!.copyWith(title: '第二次修改'));
    expect((await store.original(postId))!.originalHash, original.originalHash);
    await reclassifyPostsV3(db, dict: BookDict.empty());
    expect((await db.select(db.bookEntries).getSingle()).category, '排雷');
  });

  test('删除书目重算聚合，保留空书组收藏，正文未丢失', () async {
    final ContentSaveResult saved = await store.save(
      draft('《暂存书目》 作者：行舟\n真实原文留存。'),
    );
    final BookEntry entry = await db.select(db.bookEntries).getSingle();
    await queries.toggleFavorite(
      targetType: FavoriteTarget.bookGroup,
      targetId: entry.bookGroupId!,
      title: '《暂存书目》',
    );
    final ContentDraft current = (await store.load(saved.postId))!;
    await store.save(current.copyWith(entries: const <ContentEntryDraft>[]));
    expect(await db.select(db.bookEntries).get(), isEmpty);
    expect((await db.select(db.bookGroups).getSingle()).entryTotal, 0);
    expect(
      (await db.select(db.favorites).get()).single.targetId,
      entry.bookGroupId,
    );
    expect(
      (await queries.postDetail(saved.postId))!.floors.single.floor.content,
      contains('真实原文'),
    );
  });

  test('并发修改保护与非法字段回滚，不丢失草稿或写入半条帖子', () async {
    final ContentSaveResult saved = await store.save(
      draft('《并发校验》 作者：墨白\n完整评论。'),
    );
    final ContentDraft stale = (await store.load(saved.postId))!;
    await (db.update(db.posts)
          ..where((Posts table) => table.id.equals(saved.postId)))
        .write(const PostsCompanion(title: Value<String?>('其他更新')));
    await expectLater(
      store.save(stale.copyWith(title: '草稿更新')),
      throwsA(isA<ContentEditException>()),
    );
    expect((await db.select(db.posts).getSingle()).title, '其他更新');
    await expectLater(
      store.save(draft('错误日期帖子').copyWith(date: '2026-02-31')),
      throwsA(isA<ContentEditException>()),
    );
    expect((await db.select(db.posts).get()).length, 1);
    final ContentDraft current = (await store.load(saved.postId))!;
    await expectLater(
      store.save(
        current.copyWith(
          floors: <ContentFloorDraft>[ContentFloorDraft(id: 999, text: '非法引用')],
        ),
      ),
      throwsA(isA<ContentEditException>()),
    );
    expect((await db.select(db.posts).getSingle()).title, '其他更新');
  });

  test('真实文件数据库关闭重开仍保留全文、图片和原始留档', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'booksift-content-store-',
    );
    final File file = File('${directory.path}/library.sqlite');
    AppDatabase disk = AppDatabase(NativeDatabase(file));
    try {
      final ContentSaveResult saved = await ContentStore(
        disk,
      ).save(draft('《重启回读》 作者：云林\n真实落盘最终内容。'));
      await disk.close();
      disk = AppDatabase(NativeDatabase(file));
      final ContentDraft recovered = (await ContentStore(
        disk,
      ).load(saved.postId))!;
      expect(recovered.floors.single.text, contains('真实落盘最终内容'));
      expect(recovered.entries.single.author, '云林');
      expect(utf8.decode(recovered.rawDocument!), contains('真实落盘最终内容'));
      expect(
        (await disk.customSelect('PRAGMA foreign_key_check').get()),
        isEmpty,
      );
    } finally {
      await disk.close();
      await directory.delete(recursive: true);
    }
  });

  test('真实 v4 只读库仍能浏览帖子且不执行迁移', () async {
    final AppDatabase legacy = HeadlessEnv.openReadOnlyDb(
      'test/fixtures/dev_seed.db',
    );
    try {
      final PostDetailData? detail = await Queries(legacy).postDetail(2);
      expect(detail, isNotNull);
      expect(detail!.sourceUrl, isNull);
      expect(
        (await legacy.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        4,
      );
      expect(
        await legacy
            .customSelect(
              "SELECT name FROM sqlite_master WHERE name = 'content_documents'",
            )
            .get(),
        isEmpty,
      );
    } finally {
      await legacy.close();
    }
  });
}
