// 检索层档位分路测试（docs/2026-10-20_FTS索引可选化改造方案.md §8）。
//
// 覆盖：
// - off：≥3 字也直接 LIKE，不尝试 FTS、不置 degraded；
// - book：floor_fts 缺失时只查 book_fts，零命中回退 LIKE（不报错、不降级）；
// - full：floor_fts 命中长楼正文（与现状一致）。

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/fts_mode.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/headless/env.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = HeadlessEnv.openMemoryDb();
    final int postId = await db.into(db.posts).insert(
          PostsCompanion.insert(channel: '测试吧', title: const Value<String?>('扫书楼')),
        );
    final int floorId = await db.into(db.floors).insert(
          FloorsCompanion.insert(
            postId: postId,
            seq: 1,
            content: const Value<String>('紫气东来测试楼层的完整正文，只出现在楼层里。'),
          ),
        );
    await db.into(db.bookEntries).insert(
          BookEntriesCompanion.insert(
            name: '独特书名剑来',
            nameNorm: '独特书名剑来',
            contentHash: 'mode_h1',
            channel: '测试吧',
            comment: const Value<String?>('普通推荐语，不含楼层关键词。'),
            floorRef: Value<int?>(floorId),
          ),
        );
  });

  tearDown(() async => db.close());

  Future<void> dropFloorFts() async {
    for (final String name in <String>['floors_ai', 'floors_ad', 'floors_au']) {
      await db.customStatement('DROP TRIGGER IF EXISTS $name');
    }
    await db.customStatement('DROP TABLE IF EXISTS floor_fts');
  }

  test('off：楼层正文仍能经 LIKE 命中，usedFts=false 且 degraded=false', () async {
    final Queries q = Queries(db, ftsMode: FtsMode.off);
    final SearchOutcome out = await q.searchBooks(
      const SearchFilter(query: '紫气东来测试楼层'),
    );
    expect(out.page.items.single.nameNorm, '独特书名剑来');
    expect(out.usedFts, isFalse);
    expect(out.degraded, isFalse, reason: '用户主动关闭，不应提示「已降级」');
  });

  test('book：floor_fts 缺失时零命中回退 LIKE，不抛错、不 degraded', () async {
    await dropFloorFts();
    final Queries q = Queries(db, ftsMode: FtsMode.book);
    final SearchOutcome out = await q.searchBooks(
      const SearchFilter(query: '紫气东来测试楼层'),
    );
    expect(out.page.items.single.nameNorm, '独特书名剑来');
    expect(out.degraded, isFalse);
  });

  test('book：书名命中仍走 book_fts（usedFts=true）', () async {
    await dropFloorFts();
    final Queries q = Queries(db, ftsMode: FtsMode.book);
    final SearchOutcome out = await q.searchBooks(
      const SearchFilter(query: '独特书名剑来'),
    );
    expect(out.usedFts, isTrue);
    expect(out.degraded, isFalse);
  });

  test('full：floor_fts 命中长楼正文（现状行为）', () async {
    final Queries q = Queries(db, ftsMode: FtsMode.full);
    final SearchOutcome out = await q.searchBooks(
      const SearchFilter(query: '紫气东来测试楼层'),
    );
    expect(out.page.items.single.nameNorm, '独特书名剑来');
    expect(out.usedFts, isTrue);
    expect(out.degraded, isFalse);
  });
}
