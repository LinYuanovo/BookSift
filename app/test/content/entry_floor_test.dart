import 'dart:io';

import 'package:drift/drift.dart' show QueryRow, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/queries.dart';

// 书聚合页「点条目直达原楼层」的数据层守卫（任务：聚合页 → 帖内对应楼）。
//
// EntryRow.floorSeq 由 `_entryCols` 的 `LEFT JOIN floors fl ON fl.id = b.floor_ref`
// 投影而来；本用例在真实 drift 上直接断言该 JOIN 的产物 ——
// 只测 SQL 投影正确性，不涉及 UI（UI 侧的 initialFloorSeq 载荷见 book_detail_test.dart）。

Future<AppDatabase> _openFixture() async {
  final File src = File('test/fixtures/dev_seed.db');
  expect(src.existsSync(), isTrue, reason: '先执行 dart run tool/make_dev_seed.dart');
  final Directory tmp = await Directory.systemTemp.createTemp('booksift_floor');
  final File copy = File('${tmp.path}${Platform.pathSeparator}dev_seed.db');
  await src.copy(copy.path);
  final AppDatabase db = AppDatabase(NativeDatabase(copy));
  await db.customSelect('SELECT 1').get();
  addTearDown(() async {
    await db.close();
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows 句柄延迟释放：临时目录留待系统清理。
    }
  });
  return db;
}

void main() {
  test('bookEntries 投影 floor_seq：与 floors.seq 逐行一致（聚合页直达楼层的数据前提）', () async {
    final AppDatabase db = await _openFixture();
    final Queries q = Queries(db);

    // 取一个有多条条目、且楼层号可分辨的书组做断言。
    final List<QueryRow> groups = await db
        .customSelect(
          'SELECT book_group_id AS gid, COUNT(*) AS n FROM book_entries '
          'WHERE book_group_id IS NOT NULL AND floor_ref IS NOT NULL '
          'GROUP BY book_group_id HAVING n > 1 LIMIT 5',
        )
        .get();
    expect(groups, isNotEmpty, reason: 'fixture 应有多条目书组');

    for (final QueryRow g in groups) {
      final int gid = (g.data['gid']! as num).toInt();
      final List<EntryRow> rows = await q.bookEntries(gid, SemanticFilter.all);
      expect(rows, isNotEmpty);
      for (final EntryRow e in rows) {
        if (e.floorRef == null) {
          // 无楼层溯源的条目（同组内其它来源）→ floorSeq 必须同为 null（不误挂别人的楼层）。
          expect(e.floorSeq, isNull);
          continue;
        }
        // 期望值来自 floors 表本身的 seq（与 EntryRow 走的是同一条 JOIN 路径的对侧读法）。
        final QueryRow? floor = await db
            .customSelect(
              'SELECT seq FROM floors WHERE id = ?',
              variables: <Variable<Object>>[Variable<int>(e.floorRef!)],
            )
            .getSingleOrNull();
        expect(floor, isNotNull, reason: 'floor_ref 应命中 floors 行');
        expect(
          e.floorSeq,
          (floor!.data['seq']! as num).toInt(),
          reason: 'entry ${e.id} 的 floorSeq 必须等于其 floor_ref 对应楼层的 seq',
        );
      }
    }
  });
}
