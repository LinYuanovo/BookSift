/// 扫书汇 · BookSift headless CLI —— agent / 脚本 / 人工排错的统一入口。
///
/// ```powershell
/// cd app
/// $env:PATH = "C:\ProgramData\anaconda3\Library\bin;$env:PATH"   # sqlite3.dll
/// & C:\flutter\bin\dart.bat run bin/booksift.dart --help
/// & C:\flutter\bin\dart.bat run bin/booksift.dart doctor
/// & C:\flutter\bin\dart.bat run bin/booksift.dart stats --json | jq .
/// ```
///
/// ## 输出约定
/// - 默认：人读文本 → **stdout**，运行日志也 → stdout
/// - `--json`：结果（单个 JSON 对象）→ **stdout**，运行日志（JSONL）→ **stderr**
///   于是 `... --json | jq .` 不会被日志污染，两个流可分别重定向
/// - `--log-dir`（默认 `logs/`）：每次运行落一份 `logs/<run_id>.jsonl`，事后可复盘/grep；
///   `run_id` 形如 `20261013-163624-12345`（时间戳 + pid），日志每行都带该 id 与单调 `seq`
///
/// ## 退出码
/// `0` 成功 / `1` 运行失败 / `2` 参数错误 / `3` 网络闸门未放行
///
/// ## 合规
/// 只有 `collect --net` 会发真请求，且须**双闸**（`--net` + 环境变量 `BOOKSIFT_NET=1`），
/// 并受 `--budget` 请求预算上限约束（默认 8，硬上限 = 匿名档 300）。见 AGENTS.md §6。
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:booksift/booksift.dart';
import 'package:path/path.dart' as p;

/// 退出码。
abstract final class ExitCode {
  static const int ok = 0;
  static const int failure = 1;
  static const int usage = 2;
  static const int gated = 3;
}

/// 可预期的运行失败（消息直接给人看，不打栈）。
class CliError implements Exception {
  const CliError(this.message, {this.code = ExitCode.failure, this.hint = ''});

  final String message;
  final int code;
  final String hint;

  @override
  String toString() => message;
}

Future<void> main(List<String> argv) async {
  final BookSiftRunner runner = BookSiftRunner()..argv = argv;
  int code = ExitCode.ok;
  try {
    code = await runner.run(argv) ?? ExitCode.ok;
  } on UsageException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(e.usage);
    code = ExitCode.usage;
  } on CliError catch (e) {
    stderr.writeln('错误：${e.message}');
    if (e.hint.isNotEmpty) {
      stderr.writeln('提示：${e.hint}');
    }
    code = e.code;
  } catch (e, st) {
    stderr.writeln('未预期异常：$e');
    stderr.writeln(st);
    code = ExitCode.failure;
  } finally {
    await runner.closeLog();
  }
  exitCode = code;
}

/// 顶层命令树 + 全局选项 + 运行日志生命周期。
class BookSiftRunner extends CommandRunner<int> {
  BookSiftRunner()
      : super('booksift', '扫书汇 headless CLI：检索 / 统计 / 分类 / 采集 / 自检') {
    argParser
      ..addFlag(
        'json',
        negatable: false,
        help: '机读输出：结果 JSON 走 stdout，运行日志 JSONL 走 stderr。',
      )
      ..addOption(
        'db',
        help: 'SQLite 库路径。缺省用 $_defaultDbHint（drift_flutter 在桌面的落点，'
            '若 App 从未运行过则不存在）。',
      )
      ..addOption(
        'dict',
        help: 'v3 书名词典路径（每行一个归一化书名）。缺省 $_defaultDictHint；'
            '缺失时分类退化为 v2。',
      )
      ..addOption(
        'log-dir',
        defaultsTo: 'logs',
        help: 'JSONL 运行日志目录（不存在则创建）。',
      )
      ..addFlag(
        'log-file',
        defaultsTo: true,
        help: '是否把运行日志落盘到 --log-dir。',
      );

    addCommand(DoctorCommand(this));
    addCommand(StatsCommand(this));
    addCommand(QueryCommand(this));
    addCommand(ClassifyCommand(this));
    addCommand(LogsCommand(this));
    addCommand(SeedCommand(this));
    addCommand(CollectCommand(this));
  }

  RunLog? _log;
  String? _logPath;

  /// 本次调用的原始参数（日志里记一笔，便于复现同一次调用）。
  List<String> argv = const <String>[];

  /// 本次运行的日志文件路径（未落盘 = null）。
  String? get logPath => _logPath;

  /// 取运行日志器（惰性建，全局选项决定 sink 组合）。
  Future<RunLog> logFor(ArgResults global) async {
    final RunLog? existing = _log;
    if (existing != null) {
      return existing;
    }
    final bool json = global['json'] as bool;
    final List<RunLogSink> sinks = <RunLogSink>[
      // --json：数据独占 stdout，诊断走 stderr；否则都给人看。
      json ? const StderrRunLogSink() : const StdoutRunLogSink(),
    ];
    final String runId = RunLog.newRunId();
    if (global['log-file'] as bool) {
      final String path = p.join(global['log-dir'] as String, '$runId.jsonl');
      sinks.add(await FileRunLogSink.open(path));
      _logPath = path;
    }
    final RunLog log = RunLog(runId: runId, sinks: sinks);
    log.emit(
      'cli',
      '启动',
      detail: 'argv=${argv.join(' ')}',
      data: <String, Object?>{
        'runId': runId,
        'argv': argv,
        'cwd': Directory.current.path,
        'json': json,
      },
    );
    _log = log;
    return log;
  }

  Future<void> closeLog() async {
    final RunLog? log = _log;
    if (log == null) {
      return;
    }
    log.emit('cli', '结束', detail: '共 ${log.count} 条事件', data: <String, Object?>{
      'events': log.count,
      if (_logPath != null) 'logFile': _logPath,
    });
    await log.close();
    _log = null;
  }
}

/// `--db` / `--dict` 缺省值的展示串（帮助文本用）。
const String _defaultDbHint = '~/Documents/app.sqlite';
const String _defaultDictHint = 'assets/dict/book_dict.txt';

/// 缺省库路径：drift_flutter 的 `driftDatabase(name: 'app')` 在桌面落到
/// 「文档目录/app.sqlite」。**这是约定推断，不是探测结果**——不存在时报错并提示用 --db。
String defaultDbPath() {
  final Map<String, String> env = Platform.environment;
  final String home = env['USERPROFILE'] ?? env['HOME'] ?? '.';
  return p.join(home, 'Documents', '${AppConstants.databaseName}.sqlite');
}

/// 子命令基类：全局选项读取 + 输出分流 + db 打开。
abstract class BookSiftCommand extends Command<int> {
  BookSiftCommand(this.cli);

  final BookSiftRunner cli;

  ArgResults get _global => globalResults!;

  bool get asJson => _global['json'] as bool;

  Future<RunLog> get log => cli.logFor(_global);

  String get dbPathArg {
    final String? v = _global['db'] as String?;
    return v ?? defaultDbPath();
  }

  String get dictPathArg {
    final String? v = _global['dict'] as String?;
    return v ?? p.join('assets', 'dict', 'book_dict.txt');
  }

  /// 打开库（调用方负责 close）；不存在则给出可操作的报错。
  AppDatabase openDb() {
    final String path = dbPathArg;
    if (!File(path).existsSync()) {
      throw CliError(
        '数据库不存在：$path',
        hint: '用 --db 指定实际路径。桌面端默认落点是 $_defaultDbHint；'
            'App 从未运行过时需要先跑一次 App 完成种子导入。',
      );
    }
    return HeadlessEnv.openDb(path);
  }

  /// 结果输出：`--json` 打 JSON 到 stdout，否则打人读文本。
  void emitResult(Object? json, String human) {
    if (asJson) {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(json));
    } else {
      stdout.writeln(human);
    }
  }
}

// ── doctor ────────────────────────────────────────────────────────────────

class DoctorCommand extends BookSiftCommand {
  DoctorCommand(super.cli) {
    argParser.addOption(
      'seed-dir',
      help: '种子包目录（含 manifest.json + zip）。缺省 assets/seed。',
    );
  }

  @override
  String get name => 'doctor';

  @override
  String get description => '环境自检：运行时 / sqlite3 / 数据库 / 词典 / 种子包（零网络）。';

  @override
  Future<int> run() async {
    final RunLog log = await this.log;
    final String seedDir =
        argResults!['seed-dir'] as String? ?? p.join('assets', 'seed');
    log.emit('doctor', '开始', detail: 'db=$dbPathArg dict=$dictPathArg seed=$seedDir');

    final DoctorReport report = await HeadlessEnv.doctor(
      dbPath: dbPathArg,
      dictPath: dictPathArg,
      seedDir: seedDir,
    );

    for (final DoctorCheck c in report.checks) {
      log.emit(
        'doctor',
        c.name,
        detail: c.detail,
        level: c.ok ? RunLevel.ok : RunLevel.error,
        data: <String, Object?>{...c.data, if (c.hint.isNotEmpty) 'hint': c.hint},
      );
    }

    emitResult(
      <String, Object?>{
        ...report.toJson(),
        'paths': <String, String>{
          'db': dbPathArg,
          'dbExists': File(dbPathArg).existsSync().toString(),
          'dict': dictPathArg,
          'seedDir': seedDir,
        },
        'defaultDbPathGuess': defaultDbPath(),
      },
      <String>[
        '扫书汇 环境自检  ${report.ok ? '✔ 全部通过' : '✘ 有 ${report.failures.length} 项未通过'}',
        for (final DoctorCheck c in report.checks)
          '  ${c.ok ? '[ok]  ' : '[FAIL]'} ${c.name.padRight(8)} ${c.detail}'
              '${c.ok || c.hint.isEmpty ? '' : '\n           提示: ${c.hint}'}',
        '',
        '  库路径     : $dbPathArg  (存在=${File(dbPathArg).existsSync()})',
        '  词典路径   : $dictPathArg',
        '  种子包目录 : $seedDir',
      ].join('\n'),
    );
    return report.ok ? ExitCode.ok : ExitCode.failure;
  }
}

// ── stats ─────────────────────────────────────────────────────────────────

class StatsCommand extends BookSiftCommand {
  StatsCommand(super.cli);

  @override
  String get name => 'stats';

  @override
  String get description => '库概览：各表行数 / 五维计数 / 关注吧水位 / settings / 数据截至日（零网络）。';

  @override
  Future<int> run() async {
    final RunLog log = await this.log;
    final AppDatabase db = openDb();
    try {
      final BookQueryApi api = BookQueryApi(db);
      log.emit('stats', '开始', detail: dbPathArg);
      final DbOverview ov = await api.overview();
      final CategoryCounts counts = await api.dimensionCounts();
      final String? cutoff = await api.dataCutoff();
      log.emit(
        'stats',
        '完成',
        detail: 'schema v${ov.userVersion}，${ov.tables.length} 张表',
        level: RunLevel.ok,
        data: <String, Object?>{'userVersion': ov.userVersion, 'rows': ov.tables},
      );

      final Map<String, Object?> json = <String, Object?>{
        'db': dbPathArg,
        'overview': ov.toJson(),
        'dataCutoff': cutoff,
        'dimensionCounts': categoryCountsJson(counts),
      };

      final StringBuffer sb = StringBuffer()
        ..writeln('库：$dbPathArg   schema user_version=${ov.userVersion}   数据截至：${cutoff ?? '—'}')
        ..writeln('')
        ..writeln('── 表行数 ──');
      ov.tables.forEach((String k, int v) => sb.writeln('  ${k.padRight(20)} $v'));
      sb
        ..writeln('')
        ..writeln('── 五维计数（total=${counts.total}）──')
        ..writeln('  年代   ${_dims(counts.years)}')
        ..writeln('  月份   ${_dims(counts.months)}')
        ..writeln('  旬     ${_dims(counts.tenDays)}')
        ..writeln('  渠道   ${_dims(counts.channels)}')
        ..writeln('  分类   ${_dims(counts.categories)}')
        ..writeln('')
        ..writeln('── 关注吧水位 ──');
      if (ov.forums.isEmpty) {
        sb.writeln('  （空）');
      }
      for (final ForumWatermark f in ov.forums) {
        sb.writeln(
          '  ${f.fname}  enabled=${f.enabled}  last=${f.lastStatus}'
          '  watermark=${f.lastThreadTime}  帖=${f.totalThreads} 楼=${f.totalFloors}'
          '  连败=${f.consecutiveFailures}',
        );
      }
      sb
        ..writeln('')
        ..writeln('── settings ──');
      if (ov.settings.isEmpty) {
        sb.writeln('  （空）');
      }
      ov.settings.forEach((String k, String v) => sb.writeln('  $k = $v'));

      emitResult(json, sb.toString().trimRight());
      return ExitCode.ok;
    } finally {
      await db.close();
    }
  }

  static String _dims(List<DimCount> list) =>
      list.map((DimCount d) => '${d.label}:${d.count}').join('  ');
}

// ── query ─────────────────────────────────────────────────────────────────

class QueryCommand extends BookSiftCommand {
  QueryCommand(super.cli) {
    argParser
      ..addOption('limit', defaultsTo: '20', help: '返回条数上限。')
      ..addOption('offset', defaultsTo: '0', help: '分页偏移。')
      ..addOption('year', help: '年代维（如 2024 / early）。')
      ..addOption('month', help: '月份维（01..12）。')
      ..addOption('ten-day', help: '旬维：upper / middle / lower。')
      ..addOption('channel', help: '渠道维（如 yy小说吧 / 其他）。')
      ..addOption('category', help: '分类维：扫书 / 排雷 / 求书 / 日常。')
      ..addOption('sort', defaultsTo: SearchSort.timeDesc.wire, help: '排序：time_desc / time_asc。')
      ..addFlag('suggest', negatable: false, help: '改走书名联想（前缀匹配），不返回书级卡。');
  }

  @override
  String get name => 'query';

  @override
  String get description => '六维检索（≥3 字走 FTS，2 字词 LIKE 兜底）/ 书名联想（零网络）。';

  @override
  Future<int> run() async {
    final RunLog log = await this.log;
    final List<String> rest = argResults!.rest;
    if (rest.isEmpty) {
      throw const CliError('缺少查询词', code: ExitCode.usage, hint: 'booksift query 剑来 --limit 10');
    }
    final String query = rest.join(' ');
    final bool suggest = argResults!['suggest'] as bool;
    final AppDatabase db = openDb();
    try {
      final BookQueryApi api = BookQueryApi(db);
      log.emit('query', '开始', detail: 'q="$query" suggest=$suggest', data: <String, Object?>{
        'query': query,
        'suggest': suggest,
      });

      if (suggest) {
        final List<String> hits =
            await api.suggest(query, limit: int.parse(argResults!['limit'] as String));
        log.emit('query', '完成', detail: '${hits.length} 条联想', level: RunLevel.ok);
        emitResult(
          <String, Object?>{'query': query, 'suggest': hits},
          hits.isEmpty ? '（无联想结果）' : hits.map((String s) => '  $s').join('\n'),
        );
        return ExitCode.ok;
      }

      final SearchFilter filter = SearchFilter(
        query: query,
        year: argResults!['year'] as String?,
        month: argResults!['month'] as String?,
        tenDay: argResults!['ten-day'] as String?,
        channel: argResults!['channel'] as String?,
        category: argResults!['category'] as String?,
        sort: SearchSort.fromWire(argResults!['sort'] as String?),
        limit: int.parse(argResults!['limit'] as String),
        offset: int.parse(argResults!['offset'] as String),
      );
      final SearchOutcome out = await api.search(filter);
      log.emit(
        'query',
        '完成',
        detail: '命中 ${out.page.total} 书，返回 ${out.page.items.length}'
            '，路径=${out.usedFts ? 'FTS' : 'LIKE'}${out.degraded ? '（降级）' : ''}',
        level: out.degraded ? RunLevel.warn : RunLevel.ok,
        data: <String, Object?>{
          'total': out.page.total,
          'returned': out.page.items.length,
          'usedFts': out.usedFts,
          'degraded': out.degraded,
          'words': out.words,
        },
      );

      final StringBuffer sb = StringBuffer()
        ..writeln(
          '「$query」→ ${out.page.total} 本书（返回 ${out.page.items.length}）'
          '  检索路径=${out.usedFts ? 'FTS' : 'LIKE 兜底'}'
          '${out.degraded ? '  ⚠ 已降级' : ''}  分词=${out.words}',
        );
      for (final GroupHit g in out.page.items) {
        sb.writeln(
          '  ${g.name}${g.author == null ? '' : ' / ${g.author}'}'
          '  命中${g.hitCount} 荐${g.recommendCount} 雷${g.avoidCount}'
          '  最近=${g.latestDate ?? '—'}  渠道=${g.channels.join(',')}  gid=${g.groupId ?? '—'}',
        );
      }
      emitResult(
        <String, Object?>{'query': query, ...searchOutcomeJson(out)},
        sb.toString().trimRight(),
      );
      return ExitCode.ok;
    } finally {
      await db.close();
    }
  }
}

// ── classify ──────────────────────────────────────────────────────────────

class ClassifyCommand extends BookSiftCommand {
  ClassifyCommand(super.cli) {
    argParser
      ..addOption('title', defaultsTo: '', help: '帖子标题。')
      ..addMultiOption('floor', help: '楼层正文（可重复；首个即「首楼」）。')
      ..addOption('text-file', help: '从文件读全文（与 --floor 二选一；便于喂长帖）。')
      ..addFlag('no-dict', negatable: false, help: '强制空词典 → v3 退化为 v2 行为（对比用）。');
  }

  @override
  String get name => 'classify';

  @override
  String get description => '离线跑 v3 分类器：给出 kind / flag / 命中规则 / 抽取书名 / 词典锚点（零网络、零 DB）。';

  @override
  Future<int> run() async {
    final RunLog log = await this.log;
    final List<String> floors = argResults!['floor'] as List<String>;
    final String? textFile = argResults!['text-file'] as String?;
    final String title = argResults!['title'] as String;

    List<String> floorLines = floors;
    if (textFile != null) {
      final File f = File(textFile);
      if (!await f.exists()) {
        throw CliError('--text-file 不存在：$textFile');
      }
      floorLines = <String>[await f.readAsString()];
    }
    if (title.isEmpty && floorLines.isEmpty) {
      throw const CliError(
        '没有可分类的内容',
        code: ExitCode.usage,
        hint: 'booksift classify --title "《某某》 排雷" --floor "正文…"',
      );
    }

    final bool noDict = argResults!['no-dict'] as bool;
    final List<String> dictLines =
        noDict ? const <String>[] : await HeadlessEnv.loadDictLines(dictPathArg);
    final BookDict dict = BookDict.fromLines(dictLines);
    log.emit('classify', '词典', detail: noDict
        ? '强制空词典（v2 行为）'
        : '${dictLines.length} 行 → 可锚定 ${dict.anchorCount} 名', data: <String, Object?>{
      'dictPath': noDict ? null : dictPathArg,
      'dictLines': dictLines.length,
      'anchorCount': dict.anchorCount,
      'evidenceNameCount': dict.evidenceNameCount,
      'noDict': noDict,
    });

    final String firstFloor = floorLines.isEmpty ? '' : floorLines.first;
    final String fullText = <String>[title, ...floorLines].join('\n');
    final List<String> booknames = extractBooknames(fullText);
    final ClassifyResult r = classifyV3(
      title: title,
      firstFloor: firstFloor,
      fullText: fullText,
      booknames: booknames,
      dict: dict,
    );

    log.emit(
      'classify',
      '完成',
      detail: 'kind=${r.kind ?? '日常(丢弃)'} flag=${r.flag} 规则=${r.hitRules.join(',')}',
      level: r.kind == null ? RunLevel.warn : RunLevel.ok,
      data: <String, Object?>{
        'kind': r.kind,
        'flag': r.flag,
        'hitRules': r.hitRules,
        'booknames': r.booknames,
        'dictAnchor': r.dictAnchor,
      },
    );

    emitResult(
      <String, Object?>{
        'kind': r.kind,
        'kindLabel': r.kind ?? '日常闲聊（采集端丢弃）',
        'flag': r.flag,
        'hitRules': r.hitRules,
        'booknames': r.booknames,
        'dictAnchor': r.dictAnchor,
        'dict': <String, Object?>{
          'lines': dictLines.length,
          'anchorCount': dict.anchorCount,
          'degradedToV2': dict.isEmpty,
        },
        'input': <String, Object?>{
          'title': title,
          'floorCount': floorLines.length,
          'fullTextChars': fullText.length,
        },
      },
      <String>[
        '分类结果',
        '  kind       : ${r.kind ?? '（日常闲聊 → 采集端丢弃）'}',
        '  flag       : ${r.flag}   （+1 推荐 / −1 排雷 / 0 中性）',
        '  命中规则   : ${r.hitRules.join(' , ')}',
        '  抽取书名   : ${r.booknames.isEmpty ? '（无）' : r.booknames.join('、')}',
        '  词典锚点   : ${r.dictAnchor.isEmpty ? '（未命中）' : r.dictAnchor}',
        '  词典       : ${dictLines.length} 行 / 可锚定 ${dict.anchorCount}'
            '${dict.isEmpty ? '  ⚠ 空词典 → v2 行为' : ''}',
      ].join('\n'),
    );
    return ExitCode.ok;
  }
}

// ── logs ──────────────────────────────────────────────────────────────────

class LogsCommand extends BookSiftCommand {
  LogsCommand(super.cli) {
    argParser.addOption('limit', defaultsTo: '50', help: '最多返回几条（新在前）。');
  }

  @override
  String get name => 'logs';

  @override
  String get description => '导出库里 collection_logs 的历史运行日志（每轮一行汇总；零网络）。';

  @override
  Future<int> run() async {
    final RunLog log = await this.log;
    final int limit = int.parse(argResults!['limit'] as String);
    final AppDatabase db = openDb();
    try {
      final BookQueryApi api = BookQueryApi(db);
      final List<CollectionLog> rows = await api.recentLogs(limit: limit);
      log.emit('logs', '完成', detail: '${rows.length} 条历史运行日志', level: RunLevel.ok);

      final StringBuffer sb = StringBuffer()
        ..writeln('collection_logs（新在前，最多 $limit 条）：实际 ${rows.length} 条');
      for (final CollectionLog r in rows) {
        sb.writeln(
          '  ${r.runAt.toIso8601String()}  ${r.fname.padRight(10)} ${r.status.padRight(12)}'
          ' +${r.threadsAdded}帖/+${r.floorsAdded}楼/+${r.entriesAdded}目 跳重${r.skippedDup}'
          '${r.detail == null ? '' : '  ${r.detail}'}',
        );
      }
      emitResult(
        <String, Object?>{
          'count': rows.length,
          'limit': limit,
          'items': rows.map(collectionLogJson).toList(),
          'note': 'collection_logs 是每轮一行的粗汇总；逐条事件日志在 --log-dir 的 JSONL 里。',
        },
        sb.toString().trimRight(),
      );
      return ExitCode.ok;
    } finally {
      await db.close();
    }
  }
}

// ── seed ──────────────────────────────────────────────────────────────────

class SeedCommand extends BookSiftCommand {
  SeedCommand(super.cli) {
    argParser
      ..addOption('dir', help: '种子包目录。缺省 assets/seed。')
      ..addFlag(
        'verify',
        defaultsTo: true,
        help: '是否对 zip 做流式 sha256 校验（54MB 包桌面秒级；--no-verify 只看元数据）。',
      );
  }

  @override
  String get name => 'seed';

  @override
  String get description => '体检内置种子包：manifest 元数据 + zip 大小/SHA256 校验（零网络、不导入）。';

  @override
  Future<int> run() async {
    final RunLog log = await this.log;
    final String dir = argResults!['dir'] as String? ?? p.join('assets', 'seed');
    final bool verify = argResults!['verify'] as bool;
    if (!Directory(dir).existsSync()) {
      throw CliError('种子包目录不存在：$dir');
    }

    final SeedPackReport report = await SeedInspector.inspect(
      dir,
      verifyHash: verify,
      onProgress: (String stage) => log.emit('seed', stage, detail: dir),
    );
    log.emit(
      'seed',
      '完成',
      detail: report.ok
          ? '${report.manifest['pack_name']} v${report.manifest['pack_version']} 校验通过'
          : '校验未通过（size=${report.sizeMatches} sha=${report.shaMatches}）',
      level: report.ok ? RunLevel.ok : RunLevel.error,
      data: report.toJson(),
    );

    final Map<String, Object?> m = report.manifest;
    final StringBuffer sb = StringBuffer()
      ..writeln('种子包：$dir')
      ..writeln('  包名/版本 : ${m['pack_name']} v${m['pack_version']}  tier=${m['tier']}')
      ..writeln('  构建时间  : ${m['built_at']}')
      ..writeln('  zip       : ${report.zipPath ?? '（缺失）'}  ${report.zipBytes ?? '—'} 字节')
      ..writeln('  大小一致  : ${report.sizeMatches ? '✔' : '✘ 期望 ${report.expectedZipBytes}'}')
      ..writeln('  SHA256    : ${report.shaMatches == null ? '（未校验）' : (report.shaMatches! ? '✔ 一致' : '✘ 不一致')}')
      ..writeln('    期望 ${report.expectedSha256 ?? '—'}')
      ..writeln('    实测 ${report.actualSha256 ?? '—'}')
      ..writeln('  内置库    : ${m['db_size_bytes']} 字节  sha=${m['db_sha256']}')
      ..writeln('  数据窗口  : ${(m['data_window'] as Map?)?['post_date_min']} ~ ${(m['data_window'] as Map?)?['post_date_max']}')
      ..writeln('  行数      : ${jsonEncode(m['rows'])}')
      ..writeln('  结论      : ${report.ok ? '✔ 完整' : '✘ 不完整'}')
      ..writeln('')
      ..writeln('  注：CLI 只做校验，导入仍由 App 首启执行（seed_import.dart 依赖 AssetBundle）。');

    emitResult(report.toJson(), sb.toString().trimRight());
    return report.ok ? ExitCode.ok : ExitCode.failure;
  }
}

// ── collect ───────────────────────────────────────────────────────────────

class CollectCommand extends BookSiftCommand {
  CollectCommand(super.cli) {
    argParser
      ..addFlag(
        'net',
        negatable: false,
        help: '真的发网络请求。**还须**设置环境变量 BOOKSIFT_NET=1（双闸防误触）。'
            '不加此旗 = 只出计划（零请求）。',
      )
      ..addOption(
        'budget',
        defaultsTo: '8',
        help: '本次请求预算上限（硬上限：匿名档 $kDailyBudgetAnonymous / 带 --bduss 时 $kDailyBudgetBduss）。',
      )
      ..addOption(
        'bduss',
        help: '贴吧登录凭证（裸值或 `BDUSS=…` 片段；也可用环境变量 BOOKSIFT_BDUSS，参数优先）。'
            '提供后按账号档运行：请求间隔 1.0–2.0s、并发上限 4、预算上限 $kDailyBudgetBduss。'
            '凭证不进日志（最多打掩码）。',
      )
      ..addFlag(
        'isolate',
        defaultsTo: true,
        help: '解析/分类是否下放到后台 isolate；--no-isolate 走同 isolate（栈更直观，排错用）。',
      )
      ..addFlag(
        'seed-forums',
        negatable: false,
        help: '计划阶段若关注吧为空，先播种默认两吧（${kDefaultForums.join('、')}）。',
      );
  }

  @override
  String get name => 'collect';

  @override
  String get description => '增量采集：默认只出计划（零请求）；--net + BOOKSIFT_NET=1 才真跑。';

  @override
  Future<int> run() async {
    final RunLog log = await this.log;
    final bool net = argResults!['net'] as bool;
    final int budget = int.parse(argResults!['budget'] as String);

    // 凭证：--bduss 参数优先，回落环境变量 BOOKSIFT_BDUSS（纯 Dart 读不到
    // 系统加密存储，headless 走参数/环境变量；解析/掩码与 App 同源 bduss_format.dart）。
    final String? rawArg = argResults!['bduss'] as String?;
    final String? rawEnv = Platform.environment['BOOKSIFT_BDUSS'];
    final String? rawBduss =
        (rawArg != null && rawArg.trim().isNotEmpty) ? rawArg : rawEnv;
    final String? bduss = (rawBduss == null || rawBduss.trim().isEmpty)
        ? null
        : parseBdussInput(rawBduss);
    if (rawBduss != null && rawBduss.trim().isNotEmpty && bduss == null) {
      throw const CliError(
        '--bduss / BOOKSIFT_BDUSS 看起来不是 BDUSS（应为 40 位以上字母数字串）',
        code: ExitCode.usage,
        hint: '只填 BDUSS 裸值或 `BDUSS=…` Cookie 片段，不要填账号密码。',
      );
    }
    final bool bdussImported = bduss != null;
    final int budgetCap =
        bdussImported ? kDailyBudgetBduss : kDailyBudgetAnonymous;
    if (budget <= 0 || budget > budgetCap) {
      throw CliError(
        '--budget 超出范围（1..$budgetCap）：$budget',
        code: ExitCode.usage,
        hint: 'AGENTS.md §6：禁止对贴吧高频压测；'
            '${bdussImported ? 'BDUSS 档' : '匿名档'}日预算上限 $budgetCap。',
      );
    }

    final AppDatabase db = openDb();
    try {
      if (argResults!['seed-forums'] as bool) {
        await CollectRepository(db).seedDefaultsIfEmpty();
        log.emit('collect', '播种', detail: '关注吧为空时写入默认两吧');
      }

      final CollectPlan plan =
          await HeadlessCollect.plan(db: db, budgetLimit: budget, bduss: bduss);
      log.emit(
        'collect',
        '计划',
        detail: '可跑 ${plan.enabledForums.length} 吧'
            '${plan.coolingForums.isEmpty ? '' : '，冷却跳过 ${plan.coolingForums.length}'}'
            '，预算 ${plan.budgetUsed}/${plan.budgetLimit}'
            '，账号档 ${bdussImported ? 'BDUSS（${maskBduss(bduss)}）' : '匿名'}',
        data: plan.toJson(),
      );

      if (!net) {
        final StringBuffer sb = StringBuffer()
          ..writeln('采集计划（零请求；加 --net 且设 BOOKSIFT_NET=1 才会真跑）')
          ..writeln('  关注吧       : ${plan.forums.map((ForumWatermark f) => f.fname).join('、')}')
          ..writeln('  本轮可跑     : ${plan.enabledForums.isEmpty ? '（无）' : plan.enabledForums.join('、')}')
          ..writeln('  冷却跳过     : ${plan.coolingForums.isEmpty ? '（无）' : plan.coolingForums.join('、')}')
          ..writeln('  预算         : 已用 ${plan.budgetUsed} / 上限 ${plan.budgetLimit}（${plan.budgetDate ?? '今日未计数'}），余 ${plan.budgetRemaining}')
          ..writeln('  并发吧数     : ${plan.concurrentForums}   仅WiFi=${plan.wifiOnly}')
          ..writeln('  请求间隔     : ${plan.minIntervalMs}~${plan.maxIntervalMs}ms'
              '（全局限速器抖动；${bdussImported ? 'BDUSS 档' : '匿名档'}）')
          ..writeln('  账号档       : ${bdussImported ? 'BDUSS（${maskBduss(bduss)}）' : '匿名（--bduss 或 BOOKSIFT_BDUSS 可切账号档）'}')
          ..writeln('')
          ..writeln('  水位：');
        for (final ForumWatermark f in plan.forums) {
          sb.writeln(
            '    ${f.fname.padRight(10)} enabled=${f.enabled} last=${f.lastStatus}'
            ' watermark=${f.lastThreadTime} 帖=${f.totalThreads} 楼=${f.totalFloors}',
          );
        }
        emitResult(plan.toJson(), sb.toString().trimRight());
        return ExitCode.ok;
      }

      // ── 真网络：双闸 ────────────────────────────────────────────────
      final String? gate = Platform.environment['BOOKSIFT_NET'];
      if (gate != '1') {
        throw CliError(
          'collect --net 被闸门拦下：环境变量 BOOKSIFT_NET 未设为 1',
          code: ExitCode.gated,
          hint: '确认要发真请求后执行：\$env:BOOKSIFT_NET="1"；'
              '并留意 --budget（本次=$budget）。AGENTS.md §6：写操作与批量抓取有封号风险。',
        );
      }
      if (plan.enabledForums.isEmpty) {
        log.emit('collect', '跳过', detail: '无可跑的吧（全部停用或冷却中）', level: RunLevel.warn);
        emitResult(
          <String, Object?>{'ran': false, 'reason': 'no-enabled-forum', 'plan': plan.toJson()},
          '无可跑的吧，未发请求。',
        );
        return ExitCode.ok;
      }

      final List<String> dictLines = await HeadlessEnv.loadDictLines(dictPathArg);
      log.emit(
        'collect',
        '开始',
        detail: '真网络：${plan.enabledForums.join('、')}，预算 $budget，'
            '账号档 ${bdussImported ? 'BDUSS（${maskBduss(bduss)}）' : '匿名'}，'
            '词典 ${dictLines.length} 行',
        level: RunLevel.warn,
        data: <String, Object?>{
          'net': true,
          'budget': budget,
          'accountTier': bdussImported ? 'bduss' : 'anonymous',
          // 凭证本体绝不进日志 / --json（最多掩码）。
          if (bdussImported) 'bdussMasked': maskBduss(bduss),
          'forums': plan.enabledForums,
          'dictLines': dictLines.length,
        },
      );

      final CollectRunResult result = await HeadlessCollect.run(
        db: db,
        log: log,
        dictLines: dictLines,
        budgetLimit: budget,
        bduss: bduss,
        useIsolateWorker: argResults!['isolate'] as bool,
      );
      final CollectRunSummary summary = result.summary;

      final StringBuffer sb = StringBuffer()
        ..writeln('采集结束：相位=${summary.phase}'
            '${summary.banner == null ? '' : '  ⚠ ${summary.banner}'}')
        ..writeln('  +${summary.totals['threadsAdded']} 帖 / +${summary.totals['floorsAdded']} 楼'
            ' / +${summary.totals['entriesAdded']} 目，跳重 ${summary.totals['skippedDup']}，'
            '丢闲聊 ${summary.totals['discardedChat']}，排雷 ${summary.totals['mineThreads']}')
        ..writeln('  逐条日志 ${summary.logCount} 条 → ${cli.logPath ?? '（未落盘）'}');
      for (final Map<String, Object?> f in summary.forums) {
        sb.writeln('    ${f['fname']}  ${f['status']}  step=${f['step']}'
            '  watermark ${f['watermarkFrom']} → ${f['watermarkTarget']}'
            '${f['error'] == null ? '' : '  err=${f['error']}'}');
      }
      emitResult(
        <String, Object?>{'ran': true, ...summary.toJson()},
        sb.toString().trimRight(),
      );
      return ExitCode.ok;
    } finally {
      await db.close();
    }
  }
}
