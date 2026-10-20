// FTS 档位服务测试（docs/2026-10-20_FTS索引可选化改造方案.md §8）。
//
// plain test()：真实文件库 + 独立 isolate（TESTING.md §1 允许；不碰 widget 假时钟）。
// 覆盖：detect / apply(full/book/off) / 删除后重建 / settings 落账。

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:booksift/core/constants.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/fts_index.dart';

void main() {
  late Directory root;
  late String dbPath;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('fts_mode_test_');
    dbPath = p.join(root.path, 'app.sqlite');
    final AppDatabase db = AppDatabase(NativeDatabase(File(dbPath)));
    final int postId = await db.into(db.posts).insert(
          PostsCompanion.insert(channel: '测试吧', title: const Value<String?>('索引测试帖')),
        );
    await db.into(db.floors).insert(
          FloorsCompanion.insert(
            postId: postId,
            seq: 1,
            content: const Value<String>('紫气东来测试楼层的完整正文，用于 floor_fts 命中。'),
          ),
        );
    await db.into(db.bookEntries).insert(
          BookEntriesCompanion.insert(
            name: '独特书名剑来',
            nameNorm: '独特书名剑来',
            contentHash: 'fts_h1',
            channel: '测试吧',
            comment: const Value<String?>('这是一段推荐语，包含独特评语词。'),
          ),
        );
    await db.close();
    // 统一从「关闭」态起步（删表 + settings=off），后续用例验证按档重建。
    await DefaultFtsIndexService(dbPath).apply(FtsMode.off).toList();
  });

  tearDown(() async {
    try {
      await root.delete(recursive: true);
    } catch (_) {}
  });

  Future<FtsCapability> detect() => DefaultFtsIndexService(dbPath).detect();

  Future<FtsProgress> apply(FtsMode mode, {bool rebuild = false}) async {
    final List<FtsProgress> events =
        await DefaultFtsIndexService(dbPath).apply(mode, rebuild: rebuild).toList();
    expect(events, isNotEmpty);
    expect(events.last.done, isTrue, reason: events.last.message);
    expect(events.last.message, isNot(contains('Exception')), reason: events.last.message);
    return events.last;
  }

  test('初始库（off）：无 FTS 表；full 重建后两张表有行', () async {
    final FtsCapability before = await detect();
    expect(before.bookTable, isFalse);
    expect(before.floorTable, isFalse);
    expect(before.bookContentRows, 1);

    await apply(FtsMode.full);
    final FtsCapability after = await detect();
    expect(after.bookRows, 1);
    expect(after.floorRows, 1);
    expect(after.healthy, isTrue);
  });

  test('切到 book：floor_fts 与 floors_* 触发器消失，book 索引保留', () async {
    await apply(FtsMode.full);
    await apply(FtsMode.book);
    final FtsCapability cap = await detect();
    expect(cap.bookTable, isTrue);
    expect(cap.bookRows, 1);
    expect(cap.floorTable, isFalse);
    expect(cap.floorTriggers, isFalse);
    expect(cap.bookTriggers, isTrue);
  });

  test('切到 off：两张表与 6 个触发器全消失，settings 落 off', () async {
    await apply(FtsMode.full);
    await apply(FtsMode.off);
    final FtsCapability cap = await detect();
    expect(cap.bookTable, isFalse);
    expect(cap.floorTable, isFalse);
    expect(cap.bookTriggers, isFalse);
    expect(cap.floorTriggers, isFalse);

    final AppDatabase db = AppDatabase(NativeDatabase(File(dbPath)));
    addTearDown(db.close);
    final Setting? mode = await (db.select(db.settings)
          ..where((Settings t) => t.key.equals(SettingsKeys.ftsMode)))
        .getSingleOrNull();
    final Setting? built = await (db.select(db.settings)
          ..where((Settings t) => t.key.equals(SettingsKeys.ftsBuiltMode)))
        .getSingleOrNull();
    expect(mode?.value, 'off');
    expect(built?.value, 'off');
  });

  test('删除后可重建：off → full 恢复两张表与行数', () async {
    await apply(FtsMode.full);
    await apply(FtsMode.off);
    await apply(FtsMode.full, rebuild: true);
    final FtsCapability cap = await detect();
    expect(cap.bookTable, isTrue);
    expect(cap.floorTable, isTrue);
    expect(cap.bookRows, 1);
    expect(cap.floorRows, 1);
  });

  test('full 包在 book 档：只保留 book 影子表（模拟裁剪）', () async {
    await apply(FtsMode.full);
    await apply(FtsMode.book);
    final FtsCapability cap = await detect();
    expect(cap.bookTable, isTrue);
    expect(cap.floorTable, isFalse);
  });
}
