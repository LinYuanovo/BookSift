// 搜索延迟基准（Phase 4 验收基线：搜索 P95 < 100ms）。
//
// 纯 Dart（dart:io + drift NativeDatabase + lib/booksift.dart 门面），零 flutter 依赖：
// 用真实书名对 Queries.searchBooks 抽样计时，FTS（≥3 字词）与 LIKE 兜底（2 字词）
// 两条口径分开报告 P50/P95/P99。
//
// 运行（app/ 目录）：
//   $env:PATH = "C:\ProgramData\anaconda3\Library\bin;$env:PATH"   # sqlite3.dll
//   Copy-Item ..\work\seed_pack\_build\seed_lite.db $env:TEMP\bench_seed_lite.db -Force
//   & C:\flutter\bin\dart.bat run tool/perf_search_bench.dart --db $env:TEMP\bench_seed_lite.db
//
// 注意：
//  - --db 必须是**可改写副本**：drift 打开即跑迁移（user_version 1→2）会改写文件；
//    路径落在 work/ 下直接拒绝（AGENTS.md §5：研究产物库只读）。
//  - seed_lite.db 出厂无 book_fts（user_version=1）：本工具检测到缺失/空 FTS 时按
//    app_database.dart 同款 DDL 建表并 'rebuild'，重建耗时单独报告（= Phase 3
//    「FTS 后台重建」桌面口径的复测点）。
//  - 采样确定性：ORDER BY id 散列（与 make_dev_seed.dart 同款），同库同参数可复现。
//  - 性能数值只报告不进测试断言（防抖），本工具不是测试。
import 'dart:io';

import 'package:drift/drift.dart' show QueryRow, Variable;
import 'package:drift/native.dart';
import 'package:booksift/booksift.dart';

const String _usage = '''
用法: dart run tool/perf_search_bench.dart --db <可改写副本.db> [选项]
  --db <path>     必填；指向 seed_lite.db 的**副本**（work/ 下路径会被拒绝）
  --runs <n>      每条口径的计时查询数（默认 100）
  --warmup <n>    每条口径的热身查询数（默认 5，不计时）
  --limit <n>     SearchFilter.limit（默认 40 = 生产缺省）
  --json          追加输出机器可读 JSON
''';

Future<void> main(List<String> args) async {
  // ── 参数解析（不引 args 包以外依赖；booksift 门面自带 args 传递依赖，这里手写更直白）──
  String? dbPath;
  int runs = 100;
  int warmup = 5;
  int limit = 40;
  bool asJson = false;
  for (int i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--db':
        dbPath = args[++i];
      case '--runs':
        runs = int.parse(args[++i]);
      case '--warmup':
        warmup = int.parse(args[++i]);
      case '--limit':
        limit = int.parse(args[++i]);
      case '--json':
        asJson = true;
      case '--help':
      case '-h':
        stdout.writeln(_usage);
        return;
      default:
        stderr.writeln('未知参数: ${args[i]}\n$_usage');
        exitCode = 2;
        return;
    }
  }
  if (dbPath == null) {
    stderr.writeln(_usage);
    exitCode = 2;
    return;
  }
  final File dbFile = File(dbPath).absolute;
  if (!dbFile.existsSync()) {
    stderr.writeln('db 不存在: ${dbFile.path}');
    exitCode = 2;
    return;
  }
  final String normalized = dbFile.path.replaceAll(r'\', '/');
  if (normalized.contains('/work/') && !Platform.environment.containsKey('BENCH_ALLOW_WORK_DB')) {
    stderr.writeln(
      '拒绝：--db 指向 work/ 研究产物库（drift 打开即改写）。请先拷贝副本，如：\n'
      '  Copy-Item ${dbFile.path} \$env:TEMP\\bench_seed_lite.db -Force',
    );
    exitCode = 2;
    return;
  }

  final AppDatabase db = AppDatabase(NativeDatabase(dbFile));
  final Queries queries = Queries(db);
  final Stopwatch total = Stopwatch()..start();

  Future<int> scalarInt(String sql, [List<Variable<Object>> vars = const []]) async =>
      ((await db.customSelect(sql, variables: vars).get()).single.data.values.first as num).toInt();
  Future<String> scalarStr(String sql) async =>
      (await db.customSelect(sql).get()).single.data.values.first as String;

  // 打开即触发 drift beforeOpen/onUpgrade（v1→v2 加列）；顺带计时。
  final Stopwatch swOpen = Stopwatch()..start();
  await scalarInt('SELECT 1');
  swOpen.stop();

  final int entryCount = await scalarInt('SELECT COUNT(*) FROM book_entries');
  final String sqliteVersion = await scalarStr('SELECT sqlite_version()');
  final int userVersion = await scalarInt('PRAGMA user_version');

  // ── FTS 就绪（缺失/空壳则建表 + rebuild，与 app_database._createFts 同款 DDL）──
  // ⚠ external-content FTS 的 COUNT(*) 读的是 content 源表（永远=行数），**不能**用来判断
  // 索引是否有内容；必须用真实 MATCH 探活（本工具首版在此翻车：空壳索引被判为满）。
  final bool hasFts =
      await scalarInt("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='book_fts'") > 0;
  double? rebuildMs;
  if (!hasFts) {
    await db.customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS book_fts USING fts5(
        name, author, recommender, comment,
        content='book_entries', content_rowid='id',
        tokenize='trigram'
      )''');
  }
  // 探活词：任取一条 name 原文前 4 字（连续子串必中 trigram 索引）；0 命中 = 索引空壳。
  // ⚠ 不能用 name_norm 探活：norm 去标点词对原文索引可能合法 0 命中（假警报，首版实测踩坑）。
  final List<String> probe = (await db
          .customSelect(
            "SELECT substr(replace(replace(name, '《', ''), '》', ''), 1, 4) AS w FROM book_entries "
            "WHERE name IS NOT NULL AND length(name) >= 4 LIMIT 1",
          )
          .get())
      .map((QueryRow r) => r.read<String>('w'))
      .toList();
  int ftsProbeHits = -1;
  if (probe.isNotEmpty) {
    ftsProbeHits = await scalarInt(
      'SELECT COUNT(*) FROM book_fts WHERE book_fts MATCH ?',
      [Variable<String>('"${probe.single.replaceAll('"', '""')}"')],
    );
    if (ftsProbeHits == 0) {
      final Stopwatch swRebuild = Stopwatch()..start();
      await db.customStatement("INSERT INTO book_fts(book_fts) VALUES('rebuild')");
      swRebuild.stop();
      rebuildMs = swRebuild.elapsedMicroseconds / 1000.0;
      ftsProbeHits = await scalarInt(
        'SELECT COUNT(*) FROM book_fts WHERE book_fts MATCH ?',
        [Variable<String>('"${probe.single.replaceAll('"', '""')}"')],
      );
      if (ftsProbeHits == 0) {
        stderr.writeln('FTS rebuild 后探活仍 0 命中（trigram 不可用？）——FTS 口径结果不可信。');
      }
    }
  }
  final int ftsRows = await scalarInt('SELECT COUNT(*) FROM book_fts');

  // ── 采样词表（确定性：id 散列排序）──
  // FTS 词取 name 原文（去《》）：book_fts 索引建在原文列上，用户典型行为=输完整书名；
  // ⚠ 不用 name_norm 采样——norm 去标点后的词对原文索引 phrase MATCH 会假性零命中
  //  （生产同款现象，见 docs/质量预算复核.md 发现 F-2）。
  const String hashOrder = '((MIN(id) * 2654435761) % 4294967296)';
  const String stripBrackets = "replace(replace(name, '《', ''), '》', '')";
  final List<String> ftsWords = (await db
          .customSelect(
            'SELECT $stripBrackets AS w FROM book_entries '
            'WHERE name IS NOT NULL AND length(name) >= 4 '
            'GROUP BY w ORDER BY $hashOrder LIMIT ${runs + warmup}',
          )
          .get())
      .map((QueryRow r) => r.read<String>('w'))
      .toList();
  final List<String> likeWords = (await db
          .customSelect(
            'SELECT substr(name_norm, 1, 2) AS w FROM book_entries '
            'WHERE name_norm IS NOT NULL AND length(name_norm) >= 2 '
            'GROUP BY w ORDER BY $hashOrder LIMIT ${runs + warmup}',
          )
          .get())
      .map((QueryRow r) => r.read<String>('w'))
      .toList();
  if (ftsWords.length < runs || likeWords.length < runs) {
    stderr.writeln('采样不足：fts=${ftsWords.length} like=${likeWords.length} < runs=$runs（库太小？）');
    exitCode = 1;
    await db.close();
    return;
  }

  // ── 计时循环 ──
  Future<_BenchResult> bench({
    required String label,
    required List<String> words,
    required bool expectFts,
  }) async {
    final List<double> samples = <double>[];
    int zeroHit = 0;
    int pathMismatch = 0;
    int degraded = 0;
    for (int i = 0; i < words.length; i++) {
      final SearchFilter f = SearchFilter(query: words[i], limit: limit);
      final Stopwatch sw = Stopwatch()..start();
      final SearchOutcome outcome = await queries.searchBooks(f);
      sw.stop();
      if (i < warmup) {
        continue; // 热身不计时（页缓存/JIT 稳定后再采样）。
      }
      samples.add(sw.elapsedMicroseconds / 1000.0);
      if (outcome.page.total == 0) {
        zeroHit++;
      }
      if (outcome.degraded) {
        degraded++;
      }
      if (outcome.usedFts != expectFts) {
        pathMismatch++;
      }
    }
    samples.sort();
    return _BenchResult(
      label: label,
      samples: samples,
      zeroHit: zeroHit,
      pathMismatch: pathMismatch,
      degraded: degraded,
    );
  }

  final _BenchResult fts = await bench(label: 'FTS(≥3字)', words: ftsWords, expectFts: true);
  final _BenchResult like = await bench(label: 'LIKE(2字兜底)', words: likeWords, expectFts: false);
  total.stop();
  await db.close();

  // ── 报告 ──
  String fmt(_BenchResult r) =>
      '${r.label.padRight(14)} n=${r.samples.length}  '
      'P50=${r.p50.toStringAsFixed(2)}ms  P95=${r.p95.toStringAsFixed(2)}ms  '
      'P99=${r.p99.toStringAsFixed(2)}ms  min=${r.samples.first.toStringAsFixed(2)}  '
      'max=${r.samples.last.toStringAsFixed(2)}  mean=${r.mean.toStringAsFixed(2)}  '
      '零命中=${r.zeroHit}  路径异常=${r.pathMismatch}  降级=${r.degraded}';

  stdout.writeln('── perf_search_bench ──────────────────────────────');
  stdout.writeln('db           : ${dbFile.path}');
  stdout.writeln(
    'book_entries : $entryCount   book_fts(表观): $ftsRows   探活命中: $ftsProbeHits   user_version=$userVersion',
  );
  stdout.writeln('sqlite       : $sqliteVersion   os: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
  stdout.writeln('open(迁移)   : ${(swOpen.elapsedMicroseconds / 1000.0).toStringAsFixed(1)}ms'
      '${rebuildMs == null ? '' : '   FTS rebuild: ${rebuildMs.toStringAsFixed(1)}ms'}');
  stdout.writeln('口径         : Queries.searchBooks（计数+页查询+组详情全链路），limit=$limit，runs=$runs，warmup=$warmup');
  stdout.writeln(fmt(fts));
  stdout.writeln(fmt(like));
  stdout.writeln('总耗时       : ${(total.elapsedMicroseconds / 1000000.0).toStringAsFixed(1)}s');
  stdout.writeln('预算判定     : 搜索 P95 < 100ms → FTS ${fts.p95 < 100 ? '达标' : '不达标'} / LIKE ${like.p95 < 100 ? '达标' : '不达标'}');

  if (asJson) {
    stdout.writeln('── JSON ──');
    stdout.writeln(_json(fts, like, entryCount, ftsRows, sqliteVersion, swOpen, rebuildMs, dbFile, runs, warmup, limit));
  }
  if (fts.pathMismatch > 0 || like.pathMismatch > 0) {
    stderr.writeln('警告：存在检索路径与口径不符的样本（usedFts 与预期不一致），请核对分词长度。');
  }
}

class _BenchResult {
  _BenchResult({
    required this.label,
    required this.samples,
    required this.zeroHit,
    required this.pathMismatch,
    required this.degraded,
  });

  final String label;

  /// 单查询耗时 ms，升序。
  final List<double> samples;
  final int zeroHit;
  final int pathMismatch;
  final int degraded;

  double percentile(double p) => samples[((p * samples.length).ceil() - 1).clamp(0, samples.length - 1)];
  double get p50 => percentile(0.50);
  double get p95 => percentile(0.95);
  double get p99 => percentile(0.99);
  double get mean => samples.reduce((double a, double b) => a + b) / samples.length;
}

String _json(
  _BenchResult fts,
  _BenchResult like,
  int entryCount,
  int ftsRows,
  String sqliteVersion,
  Stopwatch swOpen,
  double? rebuildMs,
  File dbFile,
  int runs,
  int warmup,
  int limit,
) {
  String block(_BenchResult r) => '''
    {
      "label": "${r.label}", "n": ${r.samples.length},
      "p50_ms": ${r.p50.toStringAsFixed(3)}, "p95_ms": ${r.p95.toStringAsFixed(3)},
      "p99_ms": ${r.p99.toStringAsFixed(3)}, "min_ms": ${r.samples.first.toStringAsFixed(3)},
      "max_ms": ${r.samples.last.toStringAsFixed(3)}, "mean_ms": ${r.mean.toStringAsFixed(3)},
      "zero_hit": ${r.zeroHit}, "path_mismatch": ${r.pathMismatch}, "degraded": ${r.degraded}
    }''';
  return '''
{
  "tool": "perf_search_bench", "ts": "${DateTime.now().toIso8601String()}",
  "db": "${dbFile.path.replaceAll(r'\', '\\')}",
  "book_entries": $entryCount, "book_fts_rows": $ftsRows,
  "sqlite_version": "$sqliteVersion", "os": "${Platform.operatingSystem}",
  "open_migration_ms": ${(swOpen.elapsedMicroseconds / 1000.0).toStringAsFixed(1)},
  "fts_rebuild_ms": ${rebuildMs?.toStringAsFixed(1) ?? 'null'},
  "runs": $runs, "warmup": $warmup, "limit": $limit,
  "budget_p95_ms": 100,
  "fts": ${block(fts)},
  "like": ${block(like)}
}''';
}
