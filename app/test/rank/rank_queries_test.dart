import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/features/rank/rank_page.dart';

// 热门榜数据层（M2-②）：plain test()，真实事件循环 + drift on fixtures/dev_seed.db 临时副本
// （TESTING.md §3.2；openFixture 与 features_test.dart 同款，禁止在 testWidgets 内调用）。
// widget 交互用例见 rank_page_test.dart。

int _tmpSeq = 0;

/// 打开 fixture 的独立可写副本（drift NativeDatabase；触发 beforeOpen）。
Future<AppDatabase> openFixture() async {
  final File src = File('test/fixtures/dev_seed.db');
  expect(src.existsSync(), isTrue, reason: '先执行 dart run tool/make_dev_seed.dart');
  final Directory tmp = await Directory.systemTemp.createTemp('booksift_rt${_tmpSeq++}');
  final File copy = File('${tmp.path}${Platform.pathSeparator}dev_seed.db');
  await src.copy(copy.path);
  final AppDatabase db = AppDatabase(NativeDatabase(copy));
  await db.customSelect('SELECT 1').get();
  addTearDown(() async {
    await db.close();
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows 句柄延迟释放：临时目录留待系统清理，不影响用例结论。
    }
  });
  return db;
}

void main() {
  group('字数榜查询（drift 真实库，§5.13）', () {
    late AppDatabase db;
    late Queries q;

    setUp(() async {
      db = await openFixture();
      q = Queries(db);
    });
    tearDown(() async => db.close());

    test('wordRankRows：word_count 子集 MAX 降序 + name_norm 并列兜底 + 时段过滤同构', () async {
      final DateTime anchor = DateTime(2025, 4, 30);
      final List<RankRow> all = await q.wordRankRows(RankWindow.allTime, today: anchor);
      expect(all, hasLength(10));
      // fixture 实查（sqlite3 同 SQL 复核）：全时段字数榜首 = 综漫之全美收录 46304。
      expect(all.first.nameNorm, '综漫之全美收录');
      expect(all.first.count, 46304);
      for (int i = 1; i < all.length; i++) {
        expect(all[i - 1].count, greaterThanOrEqualTo(all[i].count), reason: 'MAX(word_count) 降序');
        if (all[i - 1].count == all[i].count) {
          expect(all[i - 1].nameNorm.compareTo(all[i].nameNorm), lessThan(0), reason: '并列 name_norm 升序稳定序');
        }
      }

      // 时段过滤同构：本月（2025-04）为全时段子集口径，count 均为正。
      final List<RankRow> month = await q.wordRankRows(RankWindow.thisMonth, today: anchor);
      expect(month.length, lessThanOrEqualTo(all.length));
      expect(month.every((RankRow r) => r.count > 0), isTrue);

      // 推荐榜与字数榜口径互异：推荐榜全时段 Top1 = 魔魂启临（fixture 实查：COUNT(*) 降序
      // + name_norm 并列兜底）。2026-10-14 起 fixture 源库换成发行包同源的清洗库（去重
      // 25914 条）：世子很凶 21→17 条，让位给未变的魔魂启临 19 条 —— 名次随去重位移属预期。
      final List<RankRow> rec = await q.rankRows(RankWindow.allTime, today: anchor);
      expect(rec.first.nameNorm, '魔魂启临');
      expect(rec.first.count, 19);
    });
  });

  group('榜单文案 helper（纯函数）', () {
    test('rankWordLabel：万字折算（1 位小数去尾 .0）与原值', () {
      expect(rankWordLabel(9999), '9999 字');
      expect(rankWordLabel(10000), '1 万字');
      expect(rankWordLabel(120000), '12 万字');
      expect(rankWordLabel(15827), '1.6 万字');
      expect(rankWordLabel(2450000), '245 万字');
    });

    test('rankScopeLabel：四时段 scope 文案（锚定 today，设计稿 RANK_SCOPE）', () {
      final DateTime anchor = DateTime(2025, 4, 30);
      expect(rankScopeLabel(RankWindow.allTime, anchor), '全时段');
      expect(rankScopeLabel(RankWindow.thisYear, anchor), '本年 · 2025');
      expect(rankScopeLabel(RankWindow.thisMonth, anchor), '本月 · 2025-04');
      expect(rankScopeLabel(RankWindow.last30, anchor), '近30天');
    });
  });
}
