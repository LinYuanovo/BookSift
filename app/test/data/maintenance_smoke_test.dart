/// 真实库冒烟（手动触发，不进常规回归）：BOOKSIFT_SMOKE_DB 指向种子库**副本**
/// 路径时执行，否则整体跳过。
///
/// 用法（仓库根）：
///   copy work\seed_pack\_build\seed_lite.db "%TEMP%\smoke.db"
///   $env:BOOKSIFT_SMOKE_DB = "$env:TEMP\smoke.db"
///   pwsh tools\run_tests_safe.ps1 -TestTarget test/data/maintenance_smoke_test.dart -TimeoutSec 900
///
/// 注意：drift 打开即跑迁移会**改写文件**，所以务必传副本。结果摘要写到 `<db>.result.txt`
/// （真实库体量下 print 输出易被吞，落盘可复查）。lite 种子库无 FTS 表，本冒烟不覆盖
/// book_fts 同步（触发器同步已由 test/data/maintenance_test.dart 的内存库用例覆盖）；
/// 想覆盖就把 BOOKSIFT_SMOKE_DB 指向 `_build/seed_full.db` 的副本（预建 FTS + 6 个触发器）。
///
/// **口径变更（2026-10-14，种子包说明.md §12）**：`_build/seed_lite.db` 现在已是
/// `tool/bake_clean_seed.dart` 就地清洗过的收敛态库（去重 + v3 回填 + category 镜像都固化了），
/// 所以本冒烟不再是「看维护能删多少」，而是两条更强的验收：
///   ① dedup 在收敛态库上必须 **0 删除**（若 >0，说明发行包里还有没洗干净的重复）；
///   ② 把 post_kind 重置回 post_type 派生的导入态基线、再重跑 v3 回填，post_kind 与
///      category 的分布必须**逐档复原**成库里原本（= 打包时固化）的分布 —— 这等于证明
///      发行包内的分类与当前分类器口径逐帖一致，词典/规则漂移会在这里暴露。
library;

import 'dart:collection';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/classify/classifier.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/maintenance.dart';

void main() {
  final String? path = Platform.environment['BOOKSIFT_SMOKE_DB'];
  test(
    '真实库 dedup + reclassify 冒烟',
    // 真实库体量（53441 entries / 38905 posts）：远超默认 30s 用例超时。
    timeout: const Timeout(Duration(minutes: 10)),
    skip: path == null ? 'BOOKSIFT_SMOKE_DB 未设置（用法见文件头）' : null,
    () async {
      final AppDatabase db = AppDatabase(NativeDatabase(File(path!)));
      final StringBuffer out = StringBuffer();
      try {
        /// 某表某列的取值分布（SplayTreeMap → 键序稳定，便于逐档比对与打印）。
        Future<SplayTreeMap<String, int>> distBy(String table, String col) async {
          final List<QueryRow> rows = await db
              .customSelect('SELECT $col AS k, COUNT(*) AS n FROM $table GROUP BY k')
              .get();
          return SplayTreeMap<String, int>.from(<String, int>{
            for (final QueryRow r in rows) r.read<String>('k'): r.read<int>('n'),
          });
        }

        Future<int> entryCount() async =>
            (await db.customSelect('SELECT COUNT(*) AS n FROM book_entries').getSingle())
                .read<int>('n');

        // 固化基线：库里原本的分布（= 打包时 bake_clean_seed.dart 烘进去的结果）。
        final SplayTreeMap<String, int> kindBaked = await distBy('posts', 'post_kind');
        final SplayTreeMap<String, int> categoryBaked = await distBy('book_entries', 'category');
        final int entriesBaked = await entryCount();
        out.writeln('baked_entries: $entriesBaked');
        out.writeln('baked_post_kind: $kindBaked');
        out.writeln('baked_category: $categoryBaked');
        final Object? userVersion =
            (await db.customSelect('PRAGMA user_version').getSingle()).data.values.first;
        out.writeln('user_version: $userVersion');

        // 1) dedup：收敛态库上必须 0 删除。
        final DedupStats dd = await dedupBookEntries(db);
        out.writeln('dedup: $dd');
        out.writeln('entries_after_dedup: ${await entryCount()}');
        final DedupStats ddAgain = await dedupBookEntries(db);
        out.writeln('dedup_rerun: $ddAgain');

        // 2) 把分类重置回「导入态基线」（= seed_import.dart `_copyInTransaction` 在源库
        //    无分类列时的 kindSelect 派生口径），再重跑 v3 回填，看能否逐档复原。
        await db.customStatement(
          "UPDATE posts SET post_kind = post_type, recommend_flag = "
          "CASE post_type WHEN '扫书' THEN 1 WHEN '排雷' THEN -1 ELSE 0 END",
        );
        out.writeln('post_kind_reset: ${await distBy('posts', 'post_kind')}');

        final List<String> dictLines = await File('assets/dict/book_dict.txt').readAsLines();
        final Stopwatch dictSw = Stopwatch()..start();
        final BookDict dict = BookDict.fromLines(dictLines);
        out.writeln('dict: ${dictLines.length} 行，锚点 ${dict.anchorCount}，'
            '构建 ${dictSw.elapsedMilliseconds}ms');
        final ReclassifyStats rc = await reclassifyPostsV3(db, dict: dict);
        out.writeln('reclassify: $rc');

        final SplayTreeMap<String, int> kindAfter = await distBy('posts', 'post_kind');
        final SplayTreeMap<String, int> categoryAfter = await distBy('book_entries', 'category');
        out.writeln('post_kind_after: $kindAfter');
        out.writeln('category_after: $categoryAfter');

        // 已知样本：post_type=扫书 但 v3 判为排雷的标题帖（基线调查实测存在）。
        final List<QueryRow> sample = await db
            .customSelect("SELECT id, post_kind AS k, recommend_flag AS f FROM posts "
                "WHERE title LIKE '排雷：《三国：开局娶了貂蝉》'")
            .get();
        if (sample.isEmpty) {
          out.writeln('sample: 未找到《三国：开局娶了貂蝉》排雷帖（跳过样本断言）');
        } else {
          out.writeln('sample: id=${sample.first.read<int>('id')} '
              'kind=${sample.first.read<String>('k')} flag=${sample.first.read<int>('f')}');
          expect(sample.first.read<String>('k'), '排雷');
          expect(sample.first.read<int>('f'), -1);
        }

        expect(dd.rowsDeleted, 0,
            reason: '源库已固化清洗成果（种子包说明.md §12），不应再有可删重复；'
                '若 >0 说明发行包里还残留重复条目');
        expect(ddAgain.rowsDeleted, 0, reason: '幂等：二刷 0 删除');
        expect(await entryCount(), entriesBaked, reason: '收敛态库不应因维护而掉行');
        expect(rc.postsScanned, greaterThan(0));
        expect(rc.postsUpdated, greaterThan(0),
            reason: '基线已被重置为 post_type 派生，v3 回填应重新改回一批');
        expect(kindAfter, kindBaked,
            reason: '重置后重跑 v3 必须逐档复原发行包固化的 post_kind 分布（不一致 = 分类器/词典口径漂移）');
        expect(categoryAfter, categoryBaked,
            reason: 'category 镜像同步后必须复原发行包固化的分布');
        expect(await needsDedup(db), false);
        expect(await needsReclassify(db), false);
      } finally {
        await File('$path.result.txt').writeAsString(out.toString());
        await db.close();
      }
    },
  );
}
