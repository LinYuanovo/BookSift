// 正文召回：无书名命中时，平台等正文词能经 floor_fts 召回。
//
// plain test()：内存 drift + NativeDatabase 同步 FFI（TESTING.md §1）。

import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/headless/env.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late Queries queries;

  setUp(() {
    db = HeadlessEnv.openMemoryDb();
    queries = Queries(db);
  });

  tearDown(() async => db.close());

  Future<int> addPost(String title) =>
      db.into(db.posts).insert(PostsCompanion.insert(
            title: Value<String?>(title),
            channel: 'yy小说吧',
            date: const Value<String?>('2025-04-20'),
          ));

  Future<int> addFloor(int postId, String text) =>
      db.into(db.floors).insert(FloorsCompanion.insert(
            postId: postId,
            seq: 1,
            content: Value<String>(text),
          ));

  Future<int> addEntry({
    required String name,
    required String hash,
    required int? postId,
    required int? floorId,
    String? comment,
    int? groupId,
  }) =>
      db.into(db.bookEntries).insert(BookEntriesCompanion.insert(
            name: name,
            nameNorm: name.replaceAll(RegExp(r'[《》]'), ''),
            channel: 'yy小说吧',
            contentHash: hash,
            date: const Value<String?>('2025-04-20'),
            postRef: Value<int?>(postId),
            floorRef: Value<int?>(floorId),
            comment: Value<String?>(comment),
            bookGroupId: Value<int?>(groupId),
          ));

  test('无书名命中时，平台名正文命中仍可召回', () async {
    final int postId = await addPost('本月扫书');
    final int floorId = await addFloor(
      postId,
      '这本发在起点，节奏和人物都不错。',
    );
    await addEntry(
      name: '《不是标题的正文书》',
      hash: 'anchor-3',
      postId: postId,
      floorId: floorId,
    );

    final SearchOutcome out = await queries.searchBooks(
      const SearchFilter(query: '起点'),
    );
    expect(out.page.items.single.nameNorm, '不是标题的正文书');
  });

  test('平台字段命中时覆盖标题片段，返回正文标注的平台书', () async {
    final int titlePost = await addPost('起点合集');
    final int titleFloor = await addFloor(titlePost, '平台：起点');
    await addEntry(
      name: '《起点之书》',
      hash: 'anchor-title',
      postId: titlePost,
      floorId: titleFloor,
      comment: '平台：起点',
    );

    final int bodyPost = await addPost('番茄合集');
    final int bodyFloor = await addFloor(bodyPost, '平台：起点');
    await addEntry(
      name: '《正文之书》',
      hash: 'anchor-body',
      postId: bodyPost,
      floorId: bodyFloor,
    );

    final SearchOutcome out = await queries.searchBooks(
      const SearchFilter(query: '起点'),
    );
    expect(
      out.page.items.map((GroupHit g) => g.nameNorm),
      contains('正文之书'),
    );
  });

  test('精确书名命中只返回标题级，不被同楼正文带出', () async {
    final int postId = await addPost('月度扫书');
    final int floorId = await addFloor(postId, '《甲乙丙丁》发在起点，值得一看。');
    await addEntry(
      name: '《甲乙丙丁》',
      hash: 'anchor-exact',
      postId: postId,
      floorId: floorId,
    );
    await addEntry(
      name: '《起点之外》',
      hash: 'anchor-other',
      postId: postId,
      floorId: floorId,
    );

    final SearchOutcome out = await queries.searchBooks(
      const SearchFilter(query: '甲乙丙丁'),
    );
    expect(out.page.items.single.nameNorm, '甲乙丙丁');
  });

  test('维度筛选同时作用于书名命中与正文命中', () async {
    final int allowedGroup = await db
        .into(db.bookGroups)
        .insert(BookGroupsCompanion.insert(nameNorm: '允许书'));
    final int blockedGroup = await db
        .into(db.bookGroups)
        .insert(BookGroupsCompanion.insert(nameNorm: '排除书'));
    final int allowedPost = await addPost('起点收录');
    final int allowedFloor = await addFloor(allowedPost, '这本书发在起点');
    await addEntry(
      name: '《允许书》',
      hash: 'dim-allow',
      postId: allowedPost,
      floorId: allowedFloor,
      groupId: allowedGroup,
    );
    final int blockedPost = await addPost('起点排除');
    final int blockedFloor = await addFloor(blockedPost, '渠道排除');
    await addEntry(
      name: '《排除书》',
      hash: 'dim-block',
      postId: blockedPost,
      floorId: blockedFloor,
      comment: '起点排除',
      groupId: blockedGroup,
    );
    await (db.update(db.bookEntries)
          ..where((BookEntries b) => b.nameNorm.equals('排除书')))
        .write(const BookEntriesCompanion(channel: Value<String>('其它吧')));

    final SearchOutcome out = await queries.searchBooks(
      const SearchFilter(query: '起点', channel: 'yy小说吧'),
    );
    expect(
      out.page.items.map((GroupHit g) => g.nameNorm),
      contains('允许书'),
    );
    expect(
      out.page.items.map((GroupHit g) => g.nameNorm),
      isNot(contains('排除书')),
    );
  });
}
