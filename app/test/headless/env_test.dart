// headless 环境层测试（env.dart）：词典加载 / 表行数 / doctor 自检。
//
// plain test()：doctor 会真开 sqlite 文件、词典走真实 dart:io，
// 按 TESTING.md §1 不得进 testWidgets。
//
// 覆盖：doctor 五项检查的通过与失败两侧（agent 排错第一入口，误报 ok 比报错更糟）/
// 词典空表退化 / 表行数统计只数用户表。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/headless/env.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('booksift_env_test');
  });

  tearDown(() async {
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  group('loadDictLines', () {
    test('剔除空行与纯空白行', () async {
      final File f = File('${tmp.path}${Platform.pathSeparator}dict.txt');
      await f.writeAsString('诡秘之主\n\n  \n大奉打更人\n');
      expect(await HeadlessEnv.loadDictLines(f.path), <String>[
        '诡秘之主',
        '大奉打更人',
      ]);
    });

    test('文件不存在返回空表（→ v3 退化 v2，而不是抛异常）', () async {
      expect(
        await HeadlessEnv.loadDictLines(
          '${tmp.path}${Platform.pathSeparator}nope.txt',
        ),
        isEmpty,
      );
    });

    test('随包真实词典可加载且可锚定名 > 0', () async {
      const String path = 'assets/dict/book_dict.txt';
      if (!File(path).existsSync()) {
        markTestSkipped('需在 app/ 目录下运行且资产已就位');
        return;
      }
      final List<String> lines = await HeadlessEnv.loadDictLines(path);
      expect(lines.length, greaterThan(10000));
      final DoctorReport r = await HeadlessEnv.doctor(dictPath: path);
      final DoctorCheck dict = r.checks.firstWhere(
        (DoctorCheck c) => c.name == 'dict',
      );
      expect(dict.ok, isTrue);
      expect(dict.data['anchorCount'], greaterThan(0));
    });
  });

  group('tableRowCounts', () {
    test('新建内存库：drift schema 各表就位且为 0，不含 sqlite_ 内部表', () async {
      final db = HeadlessEnv.openMemoryDb();
      addTearDown(db.close);
      final Map<String, int> rows = await HeadlessEnv.tableRowCounts(db);

      expect(rows.keys, contains('book_entries'));
      expect(rows.keys, contains('posts'));
      expect(rows.keys, contains('collection_state'));
      expect(rows.keys.any((String k) => k.startsWith('sqlite_')), isFalse);
      expect(
        rows.values.every((int v) => v == 0),
        isTrue,
        reason: '新库应全为 0；不为 0 说明混进了内部表（如 *_fts_config 恒有 1 行）',
      );
    });

    test('FTS5：虚拟表本身计入，影子表排除（否则 agent 读到一堆内部噪声）', () async {
      final db = HeadlessEnv.openMemoryDb();
      addTearDown(db.close);
      final Map<String, int> rows = await HeadlessEnv.tableRowCounts(db);

      expect(rows.keys, containsAll(<String>['book_fts', 'floor_fts']));
      for (final String k in rows.keys) {
        expect(
          RegExp(r'_(data|idx|content|docsize|config)$').hasMatch(k),
          isFalse,
          reason: '$k 是 FTS5 影子表，不该出现在统计里',
        );
      }
    });
  });

  group('doctor', () {
    test('sqliteHint 按 Windows/macOS/Linux 给各自的动态库修复提示', () {
      final String windows = HeadlessEnv.sqliteHintForPlatform('windows');
      final String macos = HeadlessEnv.sqliteHintForPlatform('macos');
      final String linux = HeadlessEnv.sqliteHintForPlatform('linux');

      expect(windows, contains('sqlite3.dll'));
      expect(windows, contains(r'$env:PATH'));
      expect(macos, contains('macOS'));
      expect(macos, contains('brew install sqlite3'));
      expect(
        macos,
        contains(
          r'export DYLD_LIBRARY_PATH="$(brew --prefix sqlite)/lib:$DYLD_LIBRARY_PATH"',
        ),
      );
      expect(linux, contains('Linux'));
      expect(linux, contains('libsqlite3-0'));
      expect(linux, isNot(contains('macOS')));
    });

    test('runtime 与 sqlite3 两项在纯净环境下即通过', () async {
      final DoctorReport r = await HeadlessEnv.doctor();
      final DoctorCheck runtime = r.checks.firstWhere(
        (DoctorCheck c) => c.name == 'runtime',
      );
      final DoctorCheck sqlite = r.checks.firstWhere(
        (DoctorCheck c) => c.name == 'sqlite3',
      );

      expect(runtime.ok, isTrue);
      expect(runtime.data['os'], Platform.operatingSystem);
      expect(sqlite.ok, isTrue, reason: 'sqlite3 原生库不可用时后续所有 db 命令都会失败');
    });

    test('未指定路径时 db/dict/seed 记为 skip（ok=true），不误报失败', () async {
      final DoctorReport r = await HeadlessEnv.doctor();
      for (final String name in <String>['db', 'dict', 'seed']) {
        final DoctorCheck c = r.checks.firstWhere(
          (DoctorCheck x) => x.name == name,
        );
        expect(c.ok, isTrue);
        expect(c.detail, contains('skip'));
      }
      expect(r.ok, isTrue);
    });

    test('库文件不存在 → db 项 FAIL 且给出可操作 hint，整体 ok=false', () async {
      final String missing = '${tmp.path}${Platform.pathSeparator}nope.sqlite';
      final DoctorReport r = await HeadlessEnv.doctor(dbPath: missing);
      final DoctorCheck db = r.checks.firstWhere(
        (DoctorCheck c) => c.name == 'db',
      );

      expect(db.ok, isFalse);
      expect(db.detail, contains('文件不存在'));
      expect(db.hint, isNotEmpty);
      expect(r.ok, isFalse);
      expect(r.failures.map((DoctorCheck c) => c.name), contains('db'));
    });

    test('库文件可开 → db 项 OK，报出 user_version 与表行数', () async {
      final String path = '${tmp.path}${Platform.pathSeparator}ok.sqlite';
      // 先真建一个库（drift onCreate 落 v2）：doctor 只诊断，不负责建库。
      final seed = HeadlessEnv.openDb(path);
      await HeadlessEnv.tableRowCounts(seed);
      await seed.close();

      final DoctorReport r = await HeadlessEnv.doctor(dbPath: path);
      final DoctorCheck db = r.checks.firstWhere(
        (DoctorCheck c) => c.name == 'db',
      );

      expect(db.ok, isTrue, reason: db.detail);
      expect(
        db.data['userVersion'],
        4,
        reason: 'drift schemaVersion=4（v4 补齐查询索引 _createQueryIndexes）',
      );
      expect((db.data['rows'] as Map).keys, contains('book_entries'));
      expect(db.data['bytes'], greaterThan(0));
    });

    test('doctor 是只读诊断：库不存在时不会顺手创建文件', () async {
      final String ghost = '${tmp.path}${Platform.pathSeparator}ghost.sqlite';
      final DoctorReport r = await HeadlessEnv.doctor(dbPath: ghost);

      expect(
        r.checks.firstWhere((DoctorCheck c) => c.name == 'db').ok,
        isFalse,
      );
      expect(
        File(ghost).existsSync(),
        isFalse,
        reason: '诊断若有「凭空建库」的副作用，会把「库不存在」这个结论自我掩盖',
      );
    });

    test('词典缺失 → dict 项 FAIL；空目录 → seed 项 FAIL', () async {
      final DoctorReport r = await HeadlessEnv.doctor(
        dictPath: '${tmp.path}${Platform.pathSeparator}no_dict.txt',
        seedDir: tmp.path,
      );
      final DoctorCheck dict = r.checks.firstWhere(
        (DoctorCheck c) => c.name == 'dict',
      );
      final DoctorCheck seed = r.checks.firstWhere(
        (DoctorCheck c) => c.name == 'seed',
      );

      expect(dict.ok, isFalse);
      expect(dict.hint, contains('v2'));
      expect(seed.ok, isFalse);
      expect(seed.detail, contains('manifest.json 不存在'));
    });

    test('DoctorCheck.toJson 暴露 name/ok/detail/hint/data', () async {
      final DoctorReport r = await HeadlessEnv.doctor(
        dbPath: '${tmp.path}${Platform.pathSeparator}nope.sqlite',
      );
      final Map<String, Object?> j = r.checks
          .firstWhere((DoctorCheck c) => c.name == 'db')
          .toJson();
      expect(j['name'], 'db');
      expect(j['ok'], isFalse);
      expect(j['detail'], isNotEmpty);
      expect(j['hint'], isNotEmpty);
      expect(j['data'], isA<Map<String, Object?>>());
      expect(r.toJson()['ok'], isFalse);
    });
  });
}
