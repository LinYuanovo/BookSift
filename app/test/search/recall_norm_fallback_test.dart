// 归一化书名召回兜底测试（Phase 5 复核 F-2/V-4 修复的回归守卫）。
//
// 背景：book_fts trigram 索引建在 name 原文上，用户输入无标点的归一化书名
// （如「娘子护架」而原文「娘子，护架」）时短语零命中。修复 = searchBooks 在
// FTS 零命中时重试 LIKE，且 _likeGroups 增补 name_norm/author_norm 两列。
// 实测影响面：含标点书名 15,337/74,498（20.6%），norm 查询采样零命中 86%。
//
// plain test()：内存 drift + NativeDatabase 同步 FFI（TESTING.md §1 允许），
// 与 test/headless/query_test.dart 同款骨架。

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/headless/env.dart';

void main() {
  late AppDatabase db;
  late Queries queries;

  setUp(() {
    db = HeadlessEnv.openMemoryDb();
    queries = Queries(db);
  });

  tearDown(() async => db.close());

  Future<void> insertEntry({
    required String name,
    required String nameNorm,
    required String hash,
    String? author,
    String? authorNorm,
    String channel = 'yy小说吧',
    String category = '扫书',
    String? date = '2024-05-06',
  }) =>
      db.into(db.bookEntries).insert(BookEntriesCompanion.insert(
            name: name,
            nameNorm: nameNorm,
            author: Value<String?>(author),
            authorNorm: Value<String?>(authorNorm),
            channel: channel,
            contentHash: hash,
            category: Value<String>(category),
            date: Value<String?>(date),
          ));

  SearchFilter filter(String q) => SearchFilter(query: q);

  group('归一化查询召回（F-2 修复）', () {
    setUp(() async {
      await insertEntry(name: '娘子，护架', nameNorm: '娘子护架', hash: 'h1');
      await insertEntry(name: '诡秘之主', nameNorm: '诡秘之主', hash: 'h2');
      await insertEntry(
        name: '剑来',
        nameNorm: '剑来',
        hash: 'h3',
        author: '爱潜水的乌贼·本尊',
        authorNorm: '爱潜水的乌贼本尊',
      );
    });

    test('norm 词查含标点原文：FTS 零命中 → LIKE 重试命中，非降级', () async {
      final SearchOutcome out = await queries.searchBooks(filter('娘子护架'));
      expect(out.page.total, 1);
      expect(out.page.items.single.name, contains('娘子'));
      expect(out.usedFts, isFalse); // 重试路径如实报告非 FTS
      expect(out.degraded, isFalse); // 不是异常降级，不触发 SnackBar
    });

    test('原文词（含标点）仍走 FTS 直接命中', () async {
      final SearchOutcome out = await queries.searchBooks(filter('娘子，护架'));
      expect(out.page.total, 1);
      expect(out.usedFts, isTrue);
    });

    test('无标点原文 FTS 直接命中（不受重试影响）', () async {
      final SearchOutcome out = await queries.searchBooks(filter('诡秘之主'));
      expect(out.page.total, 1);
      expect(out.usedFts, isTrue);
    });

    test('跨标点子串（norm 连续、原文断开）经重试命中', () async {
      final SearchOutcome out = await queries.searchBooks(filter('子护架'));
      expect(out.page.total, 1);
      expect(out.usedFts, isFalse);
    });

    test('author_norm 列参与兜底召回', () async {
      final SearchOutcome out = await queries.searchBooks(filter('爱潜水的乌贼本尊'));
      expect(out.page.total, 1);
      expect(out.page.items.single.name, contains('剑来'));
    });

    test('2 字词 LIKE 路径命中含标点原文（6 列改造回归守卫）', () async {
      final SearchOutcome out = await queries.searchBooks(filter('娘子'));
      expect(out.page.total, 1);
      expect(out.usedFts, isFalse);
    });

    test('混合词长（含 <3 字词）走 LIKE 路径且 norm 列生效', () async {
      final SearchOutcome out = await queries.searchBooks(filter('娘子护架 番外'));
      // 「番外」不存在 → AND 语义零命中，但不得抛异常
      expect(out.page.total, 0);
      expect(out.usedFts, isFalse);
    });

    test('真不存在的查询：重试后仍空，不抛异常', () async {
      final SearchOutcome out = await queries.searchBooks(filter('完全不存在的书名啊'));
      expect(out.page.total, 0);
      expect(out.page.items, isEmpty);
      expect(out.degraded, isFalse);
    });
  });
}
