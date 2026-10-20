// 发行包清洗固化：把 maintenance 的「去重 + v3 分类回填（含 category 镜像）」烘进种子包。
//
// 为什么需要它：这两项维护原本只在**真机首启后**跑（seed_import_providers.dart
// `_runMaintenanceInBackground`），发行包里装的因此是脏数据（25914 条上游重复条目、
// post_kind 只有 post_type 粗分类、category 是 ETL 旧值）。本工具在桌面侧用同一套纯 Dart
// 维护函数（maintenance.dart，本体不 import flutter）跑完再打包 → 新装机开箱即收敛态。
//
// **就地清洗**：缺省对 `_build/seed_lite.db` 原地清洗（工作副本 → 清洗 → 二刷验证 → 替换），
// 带重复数据的旧版本不会在任何路径留存。清洗失败则源库分毫不动（只在最后一步替换）。
//
// ── lite 档（缺省）──────────────────────────────────────────────────────────
// 顺序刻意与真机一致：**先裁 comment 再清洗**。repack_deflate.py 会把 comment 截到 300 字，
// 而 dedup 判据是 normText(comment) 的**前缀链**（maintenance.dart `_judgeDupGroup`）→ 截断本身
// 会制造新的判重命中（实测：500 字库上删 25907 条，300 字库上删 25914 条）。若在 500 字上清洗
// 完再截断，真机首启 dedup 仍会删掉那 7 条，固化不彻底。
//
// ── full 档（--tier full --rowset-from <清洗后的 lite 库>）────────────────────
// full 的 comment 不截断（实测最长 51801 字），若在 full 上重跑 dedup，判重口径会与 lite 不同
// → 两档收敛到不同行集 → `importFull`（INSERT OR IGNORE + 显式 id）会把 lite 已删的重复原样插回来。
// 故 full **不重算、只按 id 转移**：行集 / post_kind / recommend_flag / category 一律取自清洗后的
// lite 库（两档行数本就一致，见 种子包说明.md §2.2），随后重算组聚合、重建 book_fts。
// 转移完仍跑一遍 dedup + reclassify 做**跨档一致性验证**（必须 0 删 0 改 0 同步）。
//
// 产物 schema：经 drift 迁移到当期 schemaVersion（posts 带 post_kind/recommend_flag + 查询索引）。
// App 侧无需改代码——seed_import.dart `_seedPostsHasKindColumns()` 检测到分类列就直迁，
// manifest 的 features.pre_deduped / pre_classified_v3 让导入侧直接落维护闸门。
//
// 运行（CWD = app/）：
//   dart run tool/bake_clean_seed.dart                    # 就地清洗 lite（_build/seed_lite.db）
//   dart run tool/bake_clean_seed.dart --tier full --rowset-from ../work/seed_pack/_build/seed_lite.db
//   dart run tool/bake_clean_seed.dart --out <path>       # 非破坏：写到别处，源库不动
//   dart run tool/bake_clean_seed.dart --no-verify        # 跳过二刷幂等验证
// 输出：
//   <db>                      清洗后的库（就地替换，或 --out 指定处）
//   <db>.report.json          清洗报告（repack_deflate.py 读它填 manifest.clean / features）
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show QueryRow, ResultSetImplementation, UpdateKind;
import 'package:drift/native.dart';

import 'package:booksift/classify/classifier.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/maintenance.dart';
import 'package:booksift/headless/env.dart';

/// manifest `rows` 块的表清单（与 make_seed_pack.py `ALL_TABLES` 同序同名）。
const List<String> _manifestTables = <String>[
  'posts',
  'floors',
  'images',
  'book_entries',
  'book_groups',
  'experts',
  'nouns',
  'site_links',
  'search_history',
  'bookmarks',
  'favorites',
  'collection_state',
  'collection_logs',
  'settings',
];

const String _defaultLiteDb = '../work/seed_pack/_build/seed_lite.db';
const String _defaultFullDb = '../work/seed_pack/_build/seed_full.db';
const String _defaultDict = 'assets/dict/book_dict.txt';
const List<String> _sidecars = <String>['-wal', '-shm', '-journal'];

final Stopwatch _sw = Stopwatch()..start();

void _log(String msg) => stdout.writeln(
    '[${(_sw.elapsedMilliseconds ~/ 60000).toString().padLeft(2, '0')}:'
    '${((_sw.elapsedMilliseconds ~/ 1000) % 60).toString().padLeft(2, '0')}] $msg');

Never _fail(String msg) {
  stderr.writeln(msg);
  exit(1);
}

Future<void> main(List<String> args) async {
  // 手写解析：带值 flag 要吞掉后一个 token，否则 `--tier full` 的 `full` 会被当成位置参数。
  const Set<String> valueFlags = <String>{
    '--tier',
    '--out',
    '--dict',
    '--comment-max',
    '--rowset-from',
  };
  final Map<String, String> flagValues = <String, String>{};
  final Set<String> boolFlags = <String>{};
  final List<String> pos = <String>[];
  for (var i = 0; i < args.length; i++) {
    final String a = args[i];
    if (!a.startsWith('--')) {
      pos.add(a);
    } else if (valueFlags.contains(a)) {
      if (i + 1 >= args.length) {
        _fail('$a 需要一个值');
      }
      flagValues[a] = args[++i];
    } else {
      boolFlags.add(a);
    }
  }

  String? flagValue(String name) => flagValues[name];

  final String tier = flagValue('--tier') ?? 'lite';
  if (tier != 'lite' && tier != 'full') {
    _fail('--tier 只能是 lite 或 full（收到 $tier）');
  }
  final bool full = tier == 'full';
  final String targetPath = pos.isNotEmpty ? pos[0] : (full ? _defaultFullDb : _defaultLiteDb);
  final String? outPath = flagValue('--out');
  final String dictPath = flagValue('--dict') ?? _defaultDict;
  final int commentMax = int.tryParse(flagValue('--comment-max') ?? '300') ?? 300;
  final bool verify = !boolFlags.contains('--no-verify');
  final String? rowsetPath = flagValue('--rowset-from') ?? (full ? _defaultLiteDb : null);

  final File target = File(targetPath);
  if (!target.existsSync()) {
    _fail('源库不存在: ${target.absolute.path}'
        '（先跑 work/seed_pack/make_seed_pack.py；CWD 需为 app/）');
  }
  if (full) {
    if (rowsetPath == null) {
      _fail('--tier full 需要 --rowset-from <清洗后的 lite 库>（行集与分类的权威来源）');
    }
    if (!File(rowsetPath).existsSync()) {
      _fail('rowset 库不存在: ${File(rowsetPath).absolute.path}（先清洗 lite 档）');
    }
    if (File(rowsetPath).absolute.path == target.absolute.path) {
      _fail('--rowset-from 不能指向 full 档自己');
    }
  }
  // 词典缺失会让 BookDict.empty → v3 静默退化 v2（回填结果全错），必须硬失败。
  final List<String> dictLines = await HeadlessEnv.loadDictLines(dictPath);
  if (dictLines.isEmpty) {
    _fail('词典为空或不存在: $dictPath（v3 会退化 v2，拒绝继续）');
  }

  // 工作副本：就地模式下清洗完再替换源库（失败则源库分毫不动）。
  final File work = File(outPath ?? '${target.path}.cleaning.tmp');
  final bool inPlace = outPath == null;
  work.parent.createSync(recursive: true);
  if (work.existsSync()) {
    work.deleteSync();
  }
  for (final String suffix in _sidecars) {
    final File side = File('${work.path}$suffix');
    if (side.existsSync()) {
      side.deleteSync();
    }
  }
  target.copySync(work.path);
  _log('$tier 档：复制 ${target.absolute.path} → ${work.absolute.path}'
      ' (${(work.lengthSync() / 1048576).toStringAsFixed(1)} MB)${inPlace ? '（就地模式）' : ''}');

  final AppDatabase db = AppDatabase(NativeDatabase(work));
  final Map<String, Object?> report = <String, Object?>{};
  try {
    // 触发 drift beforeOpen + 迁移链（v1→当期：posts 加 post_kind/recommend_flag、
    // bookmarks 加 floor_seq、v4 起建查询索引）。
    await db.customSelect('SELECT 1').get();

    Future<int> scalar(String sql) async =>
        ((await db.customSelect(sql).get()).single.data.values.first as num).toInt();
    Future<String?> scalarText(String sql) async =>
        (await db.customSelect(sql).get()).single.data.values.first as String?;
    Future<Map<String, int>> countBy(String sql) async {
      final List<QueryRow> rows = await db.customSelect(sql).get();
      return <String, int>{
        for (final QueryRow r in rows)
          '${r.data.values.first}': (r.data.values.last as num).toInt(),
      };
    }

    final int userVersion = await scalar('PRAGMA user_version');
    final Map<String, int> rowsBefore = <String, int>{
      for (final String t in _manifestTables) t: await scalar('SELECT COUNT(*) FROM "$t"'),
    };
    _log('迁移后 user_version=$userVersion；book_entries=${rowsBefore['book_entries']} '
        'posts=${rowsBefore['posts']}；comment 最长=${await scalar('SELECT MAX(LENGTH(comment)) FROM book_entries')} 字');

    // ── ① post_kind 基线（= seed_import.dart `_copyInTransaction` 无分类列时的 kindSelect
    //      口径；迁移默认值恒为 '扫书'/0，先还原成导入态再交给 v3 修正 / full 档覆盖）──
    await db.customStatement(
      'UPDATE posts SET post_kind = post_type, recommend_flag = '
      "CASE post_type WHEN '扫书' THEN 1 WHEN '排雷' THEN -1 ELSE 0 END",
    );
    _log('① post_kind 按 post_type 派生（导入态基线）');

    // ── ② FTS 触发器摘除（full 档有 ETL 预建的 6 个；逐行 delete+insert 对最长 5 万字的
    //      comment 做 trigram 分词，批量改写前先摘掉，末尾一次性 rebuild 更快也更确定）──
    final List<QueryRow> triggerRows = await db.customSelect(
      "SELECT name, sql FROM sqlite_master WHERE type='trigger' AND tbl_name='book_entries'",
    ).get();
    final Map<String, String> triggers = <String, String>{
      for (final QueryRow r in triggerRows) r.read<String>('name'): r.read<String>('sql'),
    };
    for (final String name in triggers.keys) {
      await db.customStatement('DROP TRIGGER "$name"');
    }
    if (triggers.isNotEmpty) {
      _log('② 摘除 book_entries FTS 触发器 ${triggers.keys.toList()}（收尾重建 book_fts 后复原）');
    }

    // ── ③ 清洗主体 ──
    int trimmed = 0;
    Map<String, Object?> cleanStats;
    if (!full) {
      // lite：裁 comment → dedup → v3 回填（含 category 镜像），全部现算。
      trimmed = await scalar('SELECT COUNT(*) FROM book_entries WHERE LENGTH(comment) > $commentMax');
      if (trimmed > 0) {
        await db.customStatement(
          'UPDATE book_entries SET comment = substr(comment, 1, $commentMax) '
          'WHERE LENGTH(comment) > $commentMax',
        );
      }
      _log('③a comment≤$commentMax：截断 $trimmed 行'
          '（content_hash / comment_norm_hash 保留全文口径，去重键不受影响）');

      final DedupStats dedup = await dedupBookEntries(
        db,
        onProgress: (DedupStats s) =>
            _log('    dedup ${s.groupsScanned}/${s.totalGroups} 组，已删 ${s.rowsDeleted}'),
      );
      _log('③b $dedup');

      final BookDict dict = BookDict.fromLines(dictLines);
      _log('    词典 ${dictLines.length} 行，锚点 ${dict.anchorCount}');
      final ReclassifyStats reclass = await reclassifyPostsV3(
        db,
        dict: dict,
        onProgress: (ReclassifyStats s) => _log(
            '    reclassify ${s.postsScanned}/${s.totalPosts} 帖，帖改 ${s.postsUpdated}、条目同步 ${s.entriesUpdated}'),
      );
      _log('③c $reclass');
      cleanStats = <String, Object?>{
        'mode': 'recompute',
        'classifier_version': classifierVersion,
        'comment_trimmed_rows': trimmed,
        'dedup': <String, Object?>{
          'groups_total': dedup.totalGroups,
          'groups_scanned': dedup.groupsScanned,
          'dup_groups': dedup.dupGroups,
          'rows_deleted': dedup.rowsDeleted,
          'groups_refreshed': dedup.groupsRefreshed,
          'batches': dedup.batches,
          'elapsed_ms': dedup.elapsedMs,
        },
        'reclassify': <String, Object?>{
          'classifier_version': classifierVersion,
          'dict_lines': dictLines.length,
          'dict_anchors': dict.anchorCount,
          'posts_total': reclass.totalPosts,
          'posts_scanned': reclass.postsScanned,
          'posts_updated': reclass.postsUpdated,
          'entries_category_synced': reclass.entriesUpdated,
          'batches': reclass.batches,
          'elapsed_ms': reclass.elapsedMs,
        },
      };
    } else {
      // full：行集与分类**按 id 转移**自清洗后的 lite 库（口径见文件头）。
      await db.customStatement(
          "ATTACH DATABASE '${File(rowsetPath!).absolute.path.replaceAll("'", "''")}' AS rs");
      final int rsEntries = await scalar('SELECT COUNT(*) FROM rs.book_entries');
      final int rsPosts = await scalar('SELECT COUNT(*) FROM rs.posts');
      _log('③a rowset 库 = ${File(rowsetPath).absolute.path}'
          '（book_entries $rsEntries / posts $rsPosts）');

      // 分类与 flag 直迁（两档 posts 行集一致；不存在于 rs 的帖保持 ① 的基线值）。
      await db.customStatement('''
        UPDATE posts SET
          post_kind = COALESCE((SELECT rs.post_kind FROM rs.posts rs WHERE rs.id = posts.id), post_kind),
          recommend_flag = COALESCE((SELECT rs.recommend_flag FROM rs.posts rs WHERE rs.id = posts.id), recommend_flag)
      ''');
      final int postsSynced = await scalar(
          'SELECT COUNT(*) FROM posts p JOIN rs.posts rs ON rs.id = p.id '
          'WHERE p.post_kind = rs.post_kind AND p.recommend_flag = rs.recommend_flag');
      // 行集对齐：lite 已删的重复条目在 full 里同样删掉。
      final int deleted = await db.customUpdate(
        'DELETE FROM book_entries WHERE id NOT IN (SELECT id FROM rs.book_entries)',
        updates: <ResultSetImplementation>{db.bookEntries},
        updateKind: UpdateKind.delete,
      );
      // category 镜像值同样取自 lite（lite 侧已按 v3 post_kind 同步过）。
      final int categorySynced = await db.customUpdate(
        'UPDATE book_entries SET category = '
        '(SELECT rs.category FROM rs.book_entries rs WHERE rs.id = book_entries.id)',
        updates: <ResultSetImplementation>{db.bookEntries},
        updateKind: UpdateKind.update,
      );
      // 组聚合重算（口径 = maintenance.dart `_refreshGroupAggregates` / ingest.dart 同款；
      // 全量刷一遍比追踪受影响组更简单，25862 组在 idx_be_group 下是秒级）。
      await db.customStatement('''
        UPDATE book_groups SET
          entry_total = (SELECT COUNT(*) FROM book_entries WHERE book_group_id = book_groups.id),
          distinct_comment = (SELECT COUNT(DISTINCT comment_norm_hash) FROM book_entries
                              WHERE book_group_id = book_groups.id
                                AND comment_norm_hash IS NOT NULL AND comment_norm_hash <> ''),
          word_count_max = (SELECT MAX(word_count) FROM book_entries WHERE book_group_id = book_groups.id)
      ''');
      await db.customStatement('DETACH DATABASE rs');
      _log('③b 转移完成：删 $deleted 条重复、posts 对齐 $postsSynced、category 覆写 $categorySynced、'
          '组聚合全量重算 ${rowsBefore['book_groups']} 个');

      // book_fts 重建（external-content；触发器已摘除，一次性 rebuild 比逐行 churn 快且确定）。
      if (triggers.isNotEmpty) {
        final Stopwatch ftsSw = Stopwatch()..start();
        await db.customStatement("INSERT INTO book_fts(book_fts) VALUES('rebuild')");
        final int ftsRows = await scalar('SELECT COUNT(*) FROM book_fts');
        final int entryRows = await scalar('SELECT COUNT(*) FROM book_entries');
        _log('③c book_fts rebuild ${ftsSw.elapsedMilliseconds ~/ 1000}s → $ftsRows 行'
            '（book_entries $entryRows，${ftsRows == entryRows ? '一致' : '⚠ 不一致'}）');
        if (ftsRows != entryRows) {
          await db.close();
          _fail('book_fts 重建后行数与 book_entries 不符（$ftsRows vs $entryRows）→ 拒绝产出');
        }
      }
      cleanStats = <String, Object?>{
        'mode': 'transfer-from-lite',
        'classifier_version': classifierVersion,
        'rowset_db': File(rowsetPath).absolute.path,
        'rows_deleted': deleted,
        'posts_aligned': postsSynced,
        'entries_category_written': categorySynced,
        'book_groups_refreshed': rowsBefore['book_groups'],
      };
    }

    // ── ④ 复原 FTS 触发器（DDL 逐字回放，不复制一份到本文件）──
    for (final MapEntry<String, String> e in triggers.entries) {
      await db.customStatement(e.value);
    }
    if (triggers.isNotEmpty) {
      _log('④ FTS 触发器已复原 ${triggers.keys.toList()}');
    }

    // ── ⑤ 幂等/跨档一致性验证：二刷必须 0 删 0 改 0 同步 ──
    Map<String, int>? idempotency;
    if (verify) {
      final DedupStats dedup2 = await dedupBookEntries(db);
      final ReclassifyStats reclass2 =
          await reclassifyPostsV3(db, dict: BookDict.fromLines(dictLines));
      idempotency = <String, int>{
        'dedup_rows_deleted': dedup2.rowsDeleted,
        'dedup_dup_groups': dedup2.dupGroups,
        'reclassify_posts_updated': reclass2.postsUpdated,
        'reclassify_entries_updated': reclass2.entriesUpdated,
        'dedup_elapsed_ms': dedup2.elapsedMs,
        'reclassify_elapsed_ms': reclass2.elapsedMs,
      };
      _log('⑤ 二刷：删 ${dedup2.rowsDeleted} / 帖改 ${reclass2.postsUpdated} / '
          '条目同步 ${reclass2.entriesUpdated}'
          '（dedup ${dedup2.elapsedMs}ms + reclassify ${reclass2.elapsedMs}ms）');
      if (dedup2.rowsDeleted != 0 ||
          reclass2.postsUpdated != 0 ||
          reclass2.entriesUpdated != 0) {
        await db.close();
        _fail('幂等验证失败：清洗后二刷仍有改动 → 产物不是收敛态，源库保持不变');
      }
    } else {
      _log('⑤ 跳过幂等验证（--no-verify）');
    }

    // ── ⑥ 收尾：清闸门（settings 不随包导入；App 侧闸门由 manifest.features 声明，
    //      见 seed_import.dart `_copyInTransaction` 第 5b 步）+ VACUUM + 自检 ──
    await db.customStatement('DELETE FROM settings');
    await db.customStatement('VACUUM');
    final String integrity = await scalarText('PRAGMA integrity_check') ?? '?';
    final int fkViolations = await scalar('SELECT COUNT(*) FROM pragma_foreign_key_check');
    _log('⑥ settings 已清、VACUUM 完成；integrity_check=$integrity，foreign_key_check=$fkViolations 项');

    final Map<String, int> rowsAfter = <String, int>{
      for (final String t in _manifestTables) t: await scalar('SELECT COUNT(*) FROM "$t"'),
    };
    report.addAll(<String, Object?>{
      'tool': 'app/tool/bake_clean_seed.dart',
      'built_at': DateTime.now().toIso8601String(),
      'elapsed_seconds': _sw.elapsedMilliseconds / 1000,
      'tier': tier,
      'src': <String, Object?>{
        'path': target.absolute.path,
        'size_bytes': target.lengthSync(),
        'book_entries': rowsBefore['book_entries'],
        'posts': rowsBefore['posts'],
      },
      'comment_max_chars': full ? null : commentMax,
      'clean': cleanStats,
      'idempotency': idempotency,
      'out': <String, Object?>{
        'path': work.absolute.path,
        'size_bytes': work.lengthSync(),
        'user_version': await scalar('PRAGMA user_version'),
        'integrity_check': integrity,
        'foreign_key_violations': fkViolations,
        'rows': rowsAfter,
        'data_window': <String, Object?>{
          'entry_date_min': await scalarText('SELECT MIN(date) FROM book_entries'),
          'entry_date_max': await scalarText('SELECT MAX(date) FROM book_entries'),
          'post_date_min': await scalarText('SELECT MIN(date) FROM posts'),
          'post_date_max': await scalarText('SELECT MAX(date) FROM posts'),
        },
        'comment_max_chars_actual': await scalar('SELECT MAX(LENGTH(comment)) FROM book_entries'),
        'indexes': await scalar(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%'"),
        'post_kind': await countBy(
            'SELECT post_kind AS k, COUNT(*) AS n FROM posts GROUP BY k ORDER BY n DESC'),
        'category': await countBy(
            'SELECT category AS k, COUNT(*) AS n FROM book_entries GROUP BY k ORDER BY n DESC'),
      },
    });

    await db.close();
    if (integrity != 'ok' || fkViolations != 0) {
      _fail('自检未通过：integrity_check=$integrity，foreign_key_check=$fkViolations → 源库保持不变');
    }

    // ── ⑦ 就地替换（先落侧车清理，再改名；报告写在最终路径旁）──
    final File finalDb = inPlace ? target : work;
    if (inPlace) {
      for (final String suffix in _sidecars) {
        final File side = File('${target.path}$suffix');
        if (side.existsSync()) {
          side.deleteSync();
        }
      }
      target.deleteSync();
      work.renameSync(target.path);
      _log('⑦ 已就地替换 ${target.absolute.path}（旧的含重复数据版本不再存在）');
    }
    final File reportFile = File('${finalDb.path}.report.json');
    await reportFile.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(report)}\n',
        flush: true);

    final Map<String, Object?> outBlock = report['out']! as Map<String, Object?>;
    _log('── 结果（$tier）──');
    _log('  book_entries ${rowsBefore['book_entries']} → ${rowsAfter['book_entries']} '
        '(-${(rowsBefore['book_entries'] ?? 0) - (rowsAfter['book_entries'] ?? 0)})');
    _log('  post_kind    ${outBlock['post_kind']}');
    _log('  category     ${outBlock['category']}');
    _log('  库体积       ${(finalDb.lengthSync() / 1048576).toStringAsFixed(1)} MB，'
        'user_version=${outBlock['user_version']}，索引 ${outBlock['indexes']} 个');
    stdout.writeln('清洗完成: ${finalDb.absolute.path}');
    stdout.writeln('报告: ${reportFile.absolute.path}');
  } catch (e, st) {
    stderr.writeln('清洗失败（源库保持不变）: $e\n$st');
    try {
      await db.close();
    } catch (_) {}
    exitCode = 1;
  }
}
