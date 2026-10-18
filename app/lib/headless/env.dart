/// Headless 运行环境：数据库打开、词典加载、环境自检（doctor）。
///
/// **纯 Dart**（dart:io + drift/native），不依赖 `path_provider`——所有路径显式传入，
/// 因此 `dart run` 下可用，且行为可复现（同一 `--db` 参数即同一份数据）。
///
/// App 内路径解析在 `lib/data/repo/database_provider.dart`（drift_flutter + path_provider），
/// 与本文件互不依赖：CLI 只认显式路径，不去猜平台目录。
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../classify/classifier.dart';
import '../data/db/app_database.dart';

/// 一条自检结果。
class DoctorCheck {
  const DoctorCheck({
    required this.name,
    required this.ok,
    this.detail = '',
    this.hint = '',
    this.data = const <String, Object?>{},
  });

  /// 检查项名（稳定标识，agent 可按键取值）。
  final String name;

  final bool ok;

  /// 人读结论。
  final String detail;

  /// 失败时的修复建议。
  final String hint;

  /// 机读数据。
  final Map<String, Object?> data;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'ok': ok,
    if (detail.isNotEmpty) 'detail': detail,
    if (hint.isNotEmpty) 'hint': hint,
    if (data.isNotEmpty) 'data': data,
  };
}

/// 自检报告。
class DoctorReport {
  const DoctorReport(this.checks);

  final List<DoctorCheck> checks;

  /// 全部通过（skip 型检查项也算 ok）。
  bool get ok => checks.every((DoctorCheck c) => c.ok);

  List<DoctorCheck> get failures =>
      checks.where((DoctorCheck c) => !c.ok).toList();

  Map<String, Object?> toJson() => <String, Object?>{
    'ok': ok,
    'checks': checks.map((DoctorCheck c) => c.toJson()).toList(),
  };
}

/// 环境工具集（无状态）。
abstract final class HeadlessEnv {
  /// sqlite3 原生库缺失时的修复提示。
  static String get sqliteHint =>
      sqliteHintForPlatform(Platform.operatingSystem);

  static String sqliteHintForPlatform(
    String operatingSystem,
  ) => switch (operatingSystem) {
    'windows' =>
      'sqlite3 原生库不可用。Windows：把含 sqlite3.dll 的目录加入 PATH，'
          '例如 \$env:PATH = "C:\\ProgramData\\anaconda3\\Library\\bin;\$env:PATH"',
    'macos' =>
      'sqlite3 原生库不可用。macOS：安装 Homebrew sqlite3（brew install sqlite3），'
          '并运行 export DYLD_LIBRARY_PATH="\$(brew --prefix sqlite)/lib:\$DYLD_LIBRARY_PATH"；'
          '或改用自带 lib/ 的 dist bundle 运行',
    'linux' =>
      'sqlite3 原生库不可用。Linux：安装系统 libsqlite3'
          '（Debian/Ubuntu：sudo apt install libsqlite3-0），或改用自带 lib/ 的 dist bundle 运行',
    _ => 'sqlite3 原生库不可用。请安装当前系统的 SQLite 3 动态库，或改用自带 lib/ 的 dist bundle 运行',
  };

  /// 打开磁盘库（不存在则创建空库；drift 会在首次访问时建表）。
  static AppDatabase openDb(String path) =>
      AppDatabase(NativeDatabase(File(path)));

  /// 打开内存库（零 IO；测试与一次性查询用）。
  static AppDatabase openMemoryDb() => AppDatabase(NativeDatabase.memory());

  /// 读词典行（每行一个归一化书名）。文件缺失返回空表 → [BookDict.empty] → v3 退化 v2。
  static Future<List<String>> loadDictLines(String path) async {
    final File f = File(path);
    if (!await f.exists()) {
      return const <String>[];
    }
    final List<String> lines = await f.readAsLines();
    return lines
        .where((String l) => l.trim().isNotEmpty)
        .toList(growable: false);
  }

  /// 环境自检。
  ///
  /// [dbPath] / [dictPath] / [seedDir] 传 null 时对应检查项记为 skip（ok=true），
  /// 使 `doctor` 在什么都没配的环境里也能给出有意义的运行时信息。
  static Future<DoctorReport> doctor({
    String? dbPath,
    String? dictPath,
    String? seedDir,
  }) async {
    final List<DoctorCheck> checks = <DoctorCheck>[await _runtime()];
    checks.add(await _sqlite());
    checks.add(await _db(dbPath));
    checks.add(await _dict(dictPath));
    checks.add(await _seed(seedDir));
    return DoctorReport(checks);
  }

  static Future<DoctorCheck> _runtime() async {
    final Map<String, String> env = Platform.environment;
    return DoctorCheck(
      name: 'runtime',
      ok: true,
      detail:
          '${Platform.operatingSystem} / Dart ${Platform.version.split(' ').first}',
      data: <String, Object?>{
        'os': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
        'dart': Platform.version,
        'pid': pid,
        'cwd': Directory.current.path,
        'executable': Platform.resolvedExecutable,
        if (env['SMOKE'] != null) 'env.SMOKE': env['SMOKE'],
        if (env['BOOKSIFT_NET'] != null)
          'env.BOOKSIFT_NET': env['BOOKSIFT_NET'],
      },
    );
  }

  static Future<DoctorCheck> _sqlite() async {
    AppDatabase? db;
    try {
      db = HeadlessEnv.openMemoryDb();
      final QueryRow row = await db.customSelect('SELECT 1 AS one').getSingle();
      return DoctorCheck(
        name: 'sqlite3',
        ok: row.read<int>('one') == 1,
        detail: '原生库可加载，SELECT 1 通过',
      );
    } catch (e) {
      return DoctorCheck(
        name: 'sqlite3',
        ok: false,
        detail: '不可用：$e',
        hint: sqliteHint,
      );
    } finally {
      await db?.close();
    }
  }

  static Future<DoctorCheck> _db(String? path) async {
    if (path == null) {
      return const DoctorCheck(name: 'db', ok: true, detail: 'skip（未指定 --db）');
    }
    final File f = File(path);
    if (!await f.exists()) {
      return DoctorCheck(
        name: 'db',
        ok: false,
        detail: '文件不存在：$path',
        hint: '先用 App 首启导入种子包，或 --db 指向已有的 app.sqlite',
        data: <String, Object?>{'path': path},
      );
    }
    AppDatabase? db;
    try {
      db = HeadlessEnv.openDb(path);
      final QueryRow v = await db
          .customSelect('PRAGMA user_version')
          .getSingle();
      final int userVersion = v.data.values.first as int;
      final Map<String, int> rows = await tableRowCounts(db);
      return DoctorCheck(
        name: 'db',
        ok: true,
        detail: '可读写，schema user_version=$userVersion，${rows.length} 张表',
        data: <String, Object?>{
          'path': path,
          'bytes': await f.length(),
          'userVersion': userVersion,
          'rows': rows,
        },
      );
    } catch (e) {
      return DoctorCheck(
        name: 'db',
        ok: false,
        detail: '打开失败：$e',
        hint: sqliteHint,
        data: <String, Object?>{'path': path},
      );
    } finally {
      await db?.close();
    }
  }

  static Future<DoctorCheck> _dict(String? path) async {
    if (path == null) {
      return const DoctorCheck(
        name: 'dict',
        ok: true,
        detail: 'skip（未指定 --dict）',
      );
    }
    final List<String> lines = await loadDictLines(path);
    if (lines.isEmpty) {
      return DoctorCheck(
        name: 'dict',
        ok: false,
        detail: '词典为空或不存在：$path',
        hint: '默认位置 app/assets/dict/book_dict.txt；缺失时 v3 分类退化为 v2',
        data: <String, Object?>{'path': path},
      );
    }
    final BookDict dict = BookDict.fromLines(lines);
    return DoctorCheck(
      name: 'dict',
      ok: true,
      detail:
          '${lines.length} 行，可锚定 ${dict.anchorCount} 名（G2 剔除 ${dict.evidenceNameCount}）',
      data: <String, Object?>{
        'path': path,
        'lines': lines.length,
        'anchorCount': dict.anchorCount,
        'evidenceNameCount': dict.evidenceNameCount,
      },
    );
  }

  static Future<DoctorCheck> _seed(String? dir) async {
    if (dir == null) {
      return const DoctorCheck(
        name: 'seed',
        ok: true,
        detail: 'skip（未指定 --seed-dir）',
      );
    }
    final File manifest = File('$dir${Platform.pathSeparator}manifest.json');
    if (!await manifest.exists()) {
      return DoctorCheck(
        name: 'seed',
        ok: false,
        detail: 'manifest.json 不存在：$dir',
        hint: '种子包目录应含 manifest.json + seed_pack_lite_v1.zip',
        data: <String, Object?>{'dir': dir},
      );
    }
    final List<File> zipFiles = Directory(dir)
        .listSync()
        .whereType<File>()
        .where((File f) => f.path.toLowerCase().endsWith('.zip'))
        .toList();
    return DoctorCheck(
      name: 'seed',
      ok: zipFiles.isNotEmpty,
      detail: zipFiles.isEmpty
          ? '目录内无 zip 包：$dir'
          : 'manifest + ${zipFiles.length} 个 zip 就位',
      hint: zipFiles.isEmpty ? '种子包 zip 缺失，App 首启导入会失败' : '',
      data: <String, Object?>{
        'dir': dir,
        'zipCount': zipFiles.length,
        'zipFiles': zipFiles.map((File f) => f.uri.pathSegments.last).toList(),
      },
    );
  }

  /// 各表行数（排错常用：判断库是空壳还是有数据）。
  ///
  /// 含 FTS5 虚拟表本身（`book_fts`/`floor_fts`——COUNT 即索引条数，判断
  /// 「搜索没结果是不是 FTS 没建」正需要它），但**排除其影子表**
  /// （`*_data`/`*_idx`/`*_content`/`*_docsize`/`*_config`）：它们是 SQLite 内部结构，
  /// 且 `*_config` 恒有 1 行，混进来会让「新库应全为 0」这类判断失真。
  /// 影子表按「基名是虚拟表 + 前缀匹配」通用识别，不硬编码表名。
  static Future<Map<String, int>> tableRowCounts(AppDatabase db) async {
    final List<QueryRow> tables = await db
        .customSelect(
          "SELECT name, sql FROM sqlite_master WHERE type='table' "
          "AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .get();

    // FTS5 虚拟表基名（其影子表都以 '<基名>_' 开头）。
    final Set<String> virtualBases = <String>{
      for (final QueryRow t in tables)
        if ((t.read<String?>('sql') ?? '').toUpperCase().contains(
          'CREATE VIRTUAL TABLE',
        ))
          t.read<String>('name'),
    };
    bool isShadow(String name) =>
        virtualBases.any((String b) => b != name && name.startsWith('${b}_'));

    final Map<String, int> out = <String, int>{};
    for (final QueryRow t in tables) {
      final String name = t.read<String>('name');
      if (isShadow(name)) {
        continue;
      }
      // 表名来自 sqlite_master，非用户输入；仍加引号防特殊字符。
      final QueryRow c = await db
          .customSelect('SELECT COUNT(*) AS n FROM "$name"')
          .getSingle();
      out[name] = c.read<int>('n');
    }
    return out;
  }
}
