import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/constants.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/queries.dart';

// 条目级推荐语义（entryFlagOf）口径守卫。
//
// 口径（用户拍板）：**只认原帖颜色标记** book_grade —— 绿 '#11850A' → 推荐(+1)、
// 红 '#FF0000' → 排雷(−1)、其它非空标记 → 中性(0)；标记为空时只有 category=排雷 算 −1，
// 扫书/求书/日常一律 0（取代旧的「category=扫书 → 推荐」派生：扫书帖里绝大多数条目
// 只是被扫到、并无原帖背书，旧口径把 24,564 条无标扫书虚增成推荐）。
//
// 两组用例，边界不可混（TESTING.md §3）：
//   · 纯函数表驱动 —— 零 IO；
//   · SQL 内联式（queries.dart `_flagSql`，库内私有）↔ Dart 侧对账 —— plain test()
//     跑真实事件循环 + drift 打开 fixtures/dev_seed.db 临时副本，插一组「口径探针」
//     条目后用 bookDetail / bookEntries 的 SQL 结果反查。

int _tmpSeq = 0;

/// 打开 fixture 的独立可写副本（drift NativeDatabase；触发 beforeOpen）。
/// 与 features_test.dart / rank_queries_test.dart 同款，**禁止在 testWidgets 内调用**。
Future<AppDatabase> openFixture() async {
  final File src = File('test/fixtures/dev_seed.db');
  expect(
    src.existsSync(),
    isTrue,
    reason: '先执行 dart run tool/make_dev_seed.dart',
  );
  final Directory tmp = await Directory.systemTemp.createTemp(
    'booksift_flag${_tmpSeq++}',
  );
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

/// 口径矩阵：(category, book_grade, 期望 flag)。覆盖标记四态 × 类别四档 + 未知类。
const List<(String, String?, int)> kFlagCases = <(String, String?, int)>[
  // 有颜色标记：标记优先于类别（排雷帖里的绿标条目仍算推荐）。
  (CategoryKind.scan, '#11850A', 1),
  (CategoryKind.avoid, '#11850A', 1),
  (CategoryKind.ask, '#11850A', 1),
  (CategoryKind.scan, '#FF0000', -1),
  (CategoryKind.avoid, '#FF0000', -1),
  (CategoryKind.daily, '#FF0000', -1),
  // 其它非空标记（大佬存量 '#000000'）= 有标但非绿非红 → 中性，不回落类别。
  (CategoryKind.scan, '#000000', 0),
  (CategoryKind.avoid, '#000000', 0),
  // 标记为空（null / 空串同义）：只有排雷类算负面。
  (CategoryKind.scan, null, 0),
  (CategoryKind.scan, '', 0),
  (CategoryKind.avoid, null, -1),
  (CategoryKind.avoid, '', -1),
  (CategoryKind.ask, null, 0),
  (CategoryKind.daily, null, 0),
  ('未知类', null, 0),
];

void main() {
  group('entryFlagOf 口径（纯函数表驱动）', () {
    test('颜色标记优先；无标记时只有排雷类算负面，扫书一律中性', () {
      for (final (String category, String? grade, int want) in kFlagCases) {
        expect(
          entryFlagOf(category: category, bookGrade: grade),
          want,
          reason: 'category=$category book_grade=${grade ?? '<null>'}',
        );
      }
    });

    test('EntryRow.recommendFlag 走同一口径（无标扫书 = 0，不是推荐）', () {
      const EntryRow scanNoGrade = EntryRow(
        id: 1,
        name: '《无标扫书》',
        nameNorm: '无标扫书',
        channel: 'yy小说吧',
        category: CategoryKind.scan,
        origin: Origin.builtin,
        quality: 2,
      );
      expect(scanNoGrade.recommendFlag, 0);
      expect(
        EntryRow(
          id: 2,
          name: '《绿标》',
          nameNorm: '绿标',
          channel: 'yy小说吧',
          category: CategoryKind.scan,
          bookGrade: '#11850A',
          origin: Origin.builtin,
          quality: 2,
        ).recommendFlag,
        1,
      );
    });
  });

  group('_flagSql ↔ entryFlagOf 对账（drift 真实库）', () {
    late AppDatabase db;
    late Queries q;

    setUp(() async {
      db = await openFixture();
      q = Queries(db);
    });
    tearDown(() async => db.close());

    test('口径探针：SQL 聚合计数与语义筛选逐条等于表驱动期望', () async {
      const int probeGroup = 990001;
      await db.customStatement(
        "INSERT INTO book_groups (id, name_norm, entry_total) VALUES ($probeGroup, '口径探针', ${kFlagCases.length})",
      );
      for (int i = 0; i < kFlagCases.length; i++) {
        final (String category, String? grade, _) = kFlagCases[i];
        // 直拼 SQL：值全是本文件的常量（无引号/无外部输入），换来能显式写 NULL ——
        // drift 的 Variable<T extends Object> 绑不了 null，而「无标记」正是 NULL 与 '' 两态。
        final String gradeSql = grade == null ? 'NULL' : "'$grade'";
        await db.customStatement(
          'INSERT INTO book_entries '
          "(name, name_norm, channel, category, book_grade, content_hash, book_group_id) "
          "VALUES ('探针书', '探针书', 'yy小说吧', '$category', $gradeSql, 'flag_probe_$i', $probeGroup)",
        );
      }

      final List<EntryRow> all = await q.bookEntries(
        probeGroup,
        SemanticFilter.all,
      );
      expect(all, hasLength(kFlagCases.length));
      final List<EntryRow> rec = await q.bookEntries(
        probeGroup,
        SemanticFilter.recommend,
      );
      final List<EntryRow> avoid = await q.bookEntries(
        probeGroup,
        SemanticFilter.avoid,
      );
      final List<EntryRow> scan = await q.bookEntries(
        probeGroup,
        SemanticFilter.scan,
      );

      // ① SQL 筛选结果 = Dart 侧逐条判定（两侧不许各漂一半）。
      expect(
        rec.map((EntryRow e) => e.id).toSet(),
        all
            .where((EntryRow e) => e.recommendFlag == 1)
            .map((EntryRow e) => e.id)
            .toSet(),
        reason: 'SemanticFilter.recommend 的 SQL 与 entryFlagOf 口径不一致',
      );
      expect(
        avoid.map((EntryRow e) => e.id).toSet(),
        all
            .where((EntryRow e) => e.recommendFlag == -1)
            .map((EntryRow e) => e.id)
            .toSet(),
        reason: 'SemanticFilter.avoid 的 SQL 与 entryFlagOf 口径不一致',
      );
      // 仅扫书 = 非推荐且非排雷（含求书桶）：探针集里即 recommendFlag == 0 的补集桶。
      expect(
        scan.map((EntryRow e) => e.id).toSet(),
        all
            .where((EntryRow e) => e.recommendFlag == 0)
            .map((EntryRow e) => e.id)
            .toSet(),
        reason: 'SemanticFilter.scan 的 SQL 与 entryFlagOf 口径不一致',
      );

      // ② 聚合计数直接钉在表驱动期望上（防 Dart 与 SQL 一起漂移到错口径）。
      int wantCount(int flag) {
        int n = 0;
        for (final (String, String?, int) c in kFlagCases) {
          if (c.$3 == flag) {
            n++;
          }
        }
        return n;
      }

      final BookDetailData? d = await q.bookDetail(probeGroup);
      expect(d, isNotNull);
      expect(d!.recommendCount, wantCount(1));
      expect(d.avoidCount, wantCount(-1));
      // 扫书计数 = default 桶（非推荐且非排雷）：点 N 扫书 → 列表 N 条的依据。
      expect(d.scanCount, wantCount(0));
      expect(
        d.recommendCount,
        all.where((EntryRow e) => e.recommendFlag == 1).length,
      );
      expect(
        d.avoidCount,
        all.where((EntryRow e) => e.recommendFlag == -1).length,
      );
      expect(
        scan.length,
        d.scanCount,
        reason: '仅扫书筛选条数须等于页头扫书计数（数字与点开的列表同源）',
      );
    });
  });
}
