// Headless CLI 参数契约测试。
//
// plain test()：命令会初始化真实日志输出并可能读取磁盘库。

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart' show UsageException;
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database, OpenMode, sqlite3;
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/collect_repository.dart';
import 'package:booksift/headless/env.dart';
import '../../bin/booksift.dart' as cli;

void main() {
  Future<void> expectUsage(List<String> args) async {
    final cli.BookSiftRunner runner = cli.BookSiftRunner()..argv = args;
    try {
      await runner.run(args);
      fail('expected CLI usage error: $args');
    } on cli.CliError catch (e) {
      expect(e.code, cli.ExitCode.usage, reason: '$args');
    } on UsageException {
      // args 在子命令缺失/多余位置参数时直接抛 UsageException；对外仍是 exit 2。
    } finally {
      await runner.closeLog();
    }
  }

  Future<int> runForCode(List<String> args) async {
    final cli.BookSiftRunner runner = cli.BookSiftRunner()..argv = args;
    try {
      return await runner.run(args) ?? cli.ExitCode.ok;
    } on cli.CliError catch (e) {
      return e.code;
    } on UsageException {
      return cli.ExitCode.usage;
    } finally {
      await runner.closeLog();
    }
  }

  test('JSON 模式失败也返回单个机读 error 对象', () async {
    final StringBuffer output = StringBuffer();
    final StringBuffer errors = StringBuffer();
    final cli.BookSiftRunner runner = cli.BookSiftRunner(
      resultSink: output,
      errorSink: errors,
    );
    final int code = await runner.runSafely(<String>[
      '--json',
      '--no-log-file',
      '--db',
      'missing-for-json-error.sqlite',
      'stats',
    ]);
    expect(code, cli.ExitCode.failure);
    final Map<String, dynamic> json = jsonDecode(output.toString()) as Map<String, dynamic>;
    expect(json['error'], isA<Map<String, dynamic>>());
    expect((json['error'] as Map)['type'], 'runtime');
    expect(errors, isEmpty);
  });

  test('version 输出支持人读与 JSON 两种模式', () async {
    final StringBuffer human = StringBuffer();
    final cli.BookSiftRunner humanRunner = cli.BookSiftRunner(resultSink: human);
    expect(await humanRunner.runSafely(<String>['--version']), cli.ExitCode.ok);
    expect(human.toString(), contains('1.0.1'));

    final StringBuffer json = StringBuffer();
    final cli.BookSiftRunner jsonRunner = cli.BookSiftRunner(resultSink: json);
    expect(
      await jsonRunner.runSafely(<String>[
        '--no-log-file',
        '--json',
        '--version',
      ]),
      cli.ExitCode.ok,
    );
    expect((jsonDecode(json.toString()) as Map<String, dynamic>)['version'], '1.0.1');

    final StringBuffer misplaced = StringBuffer();
    final cli.BookSiftRunner misplacedRunner = cli.BookSiftRunner(resultSink: misplaced);
    expect(
      await misplacedRunner.runSafely(<String>[
        '--json', '--no-log-file', 'stats', '--version',
      ]),
      cli.ExitCode.usage,
    );
    expect((jsonDecode(misplaced.toString()) as Map<String, dynamic>)['error'], isNotNull);
  });

  test('全局开关只识别 -- 之前的参数', () async {
    final Directory tmp = await Directory.systemTemp.createTemp('booksift_cli_delimiter_test');
    final String dbPath = '${tmp.path}${Platform.pathSeparator}app.sqlite';
    final AppDatabase db = HeadlessEnv.openDb(dbPath);
    await HeadlessEnv.tableRowCounts(db);
    await db.close();

    try {
      final StringBuffer human = StringBuffer();
      final StringBuffer humanErrors = StringBuffer();
      final cli.BookSiftRunner runner = cli.BookSiftRunner(
        resultSink: human,
        errorSink: humanErrors,
      );
      final int code = await runner.runSafely(<String>[
        '--no-log-file',
        '--db',
        dbPath,
        'query',
        '--',
        '--version',
        '--json',
      ]);
      expect(code, cli.ExitCode.ok);
      expect(humanErrors, isEmpty);
      expect(human.toString(), contains('--version --json'));
      expect(human.toString(), isNot(contains('扫书汇 CLI v')));

      final StringBuffer jsonOutput = StringBuffer();
      final StringBuffer jsonErrors = StringBuffer();
      final cli.BookSiftRunner jsonRunner = cli.BookSiftRunner(
        resultSink: jsonOutput,
        errorSink: jsonErrors,
      );
      expect(
        await jsonRunner.runSafely(<String>[
          '--json',
          '--no-log-file',
          '--db',
          '${tmp.path}${Platform.pathSeparator}missing.sqlite',
          'query',
          '--',
          '--json',
        ]),
        cli.ExitCode.failure,
      );
      final Map<String, dynamic> error =
          jsonDecode(jsonOutput.toString()) as Map<String, dynamic>;
      expect((error['error'] as Map<String, dynamic>)['type'], 'runtime');
      expect(jsonErrors, isEmpty);
    } finally {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    }
  });

  test('collect 运行时双闸未放行返回 gated JSON 与退出码 3', () async {
    final StringBuffer output = StringBuffer();
    final StringBuffer errors = StringBuffer();
    final cli.BookSiftRunner runner = cli.BookSiftRunner(
      resultSink: output,
      errorSink: errors,
      environment: const <String, String>{},
    );

    final int code = await runner.runSafely(<String>[
      '--json',
      '--no-log-file',
      'collect',
      '--net',
    ]);

    expect(code, cli.ExitCode.gated);
    final Map<String, dynamic> result =
        jsonDecode(output.toString()) as Map<String, dynamic>;
    expect((result['error'] as Map<String, dynamic>)['type'], 'gated');
    expect((result['error'] as Map<String, dynamic>)['code'], cli.ExitCode.gated);
    expect(errors, isEmpty);
  });

  group('数字与枚举参数', () {
    test('query 的 limit/offset、日期维度与排序拒绝无效值', () async {
      await expectUsage(<String>[
        '--json', '--no-log-file', 'query', '  ',
      ]);
      for (final List<String> args in <List<String>>[
        <String>['--no-log-file', 'query', '书名', '--limit', 'many'],
        <String>['--no-log-file', 'query', '书名', '--limit', '-1'],
        <String>['--no-log-file', 'query', '书名', '--offset', '-1'],
        <String>['--no-log-file', 'query', '书名', '--month', '13'],
        <String>['--no-log-file', 'query', '书名', '--ten-day', 'invalid'],
        <String>['--no-log-file', 'query', '书名', '--channel', 'not-a-channel'],
        <String>['--no-log-file', 'query', '书名', '--category', 'unknown'],
        <String>['--no-log-file', 'query', '书名', '--sort', 'invalid'],
      ]) {
        await expectUsage(<String>['--json', ...args]);
      }
    });

    test('logs 与 collect 的数字参数拒绝格式错误及越界值', () async {
      await expectUsage(<String>[
        '--json', '--no-log-file', 'logs', '--limit', '-1',
      ]);
      await expectUsage(<String>[
        '--json', '--no-log-file', 'collect', '--budget', 'not-a-number',
      ]);
      await expectUsage(<String>[
        '--json', '--no-log-file', 'collect', '--budget', '301',
      ]);
    });

    test('classify 拒绝 text-file 与 floor 同时出现及空白内容', () async {
      await expectUsage(<String>[
        '--json',
        '--no-log-file',
        'classify',
        '--text-file',
        'not-read.txt',
        '--floor',
        '正文',
      ]);
      await expectUsage(<String>[
        '--json', '--no-log-file', 'classify', '--title', '  ',
      ]);
    });

    test('rank 与 show 拒绝未知枚举、错误 id 和多余参数', () async {
      for (final List<String> args in <List<String>>[
        <String>['rank', '--window', 'forever'],
        <String>['rank', '--kind', 'unknown'],
        <String>['rank', '--limit', '1001'],
        <String>['show', 'book', '0'],
        <String>['show', 'book', 'one'],
        <String>['show', 'book', '1', '--filter', 'unknown'],
        <String>['show', 'book', '1', '--sort', 'random'],
        <String>['show', 'book', '1', '--limit', '1001'],
        <String>['show', 'book', '1', '--offset', '-1'],
        <String>['show', 'post', '1', 'extra'],
      ]) {
        await expectUsage(<String>['--json', '--no-log-file', ...args]);
      }
      expect(
        await runForCode(<String>['--json', '--no-log-file', 'show']),
        cli.ExitCode.usage,
      );
    });
  });

  test('collect plan 日志文件不记录原始 BDUSS', () async {
    final Directory tmp = await Directory.systemTemp.createTemp('booksift_cli_test');
    final String secret = 'A' * 40;
    final String dbPath = '${tmp.path}${Platform.pathSeparator}app.sqlite';
    final AppDatabase db = HeadlessEnv.openDb(dbPath);
    await HeadlessEnv.tableRowCounts(db);
    await db.close();

    final List<String> args = <String>[
      '--json',
      '--db',
      dbPath,
      '--log-dir',
      '${tmp.path}${Platform.pathSeparator}logs',
      'collect',
      '--bduss',
      secret,
    ];
    try {
      final cli.BookSiftRunner runner = cli.BookSiftRunner()..argv = args;
      try {
        expect(await runner.run(args), cli.ExitCode.ok);
      } finally {
        await runner.closeLog();
      }

      final List<FileSystemEntity> entries = Directory(
        '${tmp.path}${Platform.pathSeparator}logs',
      ).listSync();
      expect(entries, hasLength(1));
      final String log = await File(entries.single.path).readAsString();
      expect(log, isNot(contains(secret)));
      expect(log, contains('AAAAAA……AAAA'));
      expect(
        jsonDecode(const LineSplitter().convert(log).first),
        isA<Map<String, dynamic>>(),
      );
    } finally {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    }
  });

  test('各库命令对缺失/损坏输入返回可预期失败且不创建数据库', () async {
    final Directory tmp = await Directory.systemTemp.createTemp('booksift_cli_error_test');
    final String missingDb = '${tmp.path}${Platform.pathSeparator}missing.sqlite';
    try {
      for (final List<String> command in <List<String>>[
        <String>['stats'],
        <String>['query', '书名'],
        <String>['logs'],
        <String>['collect'],
      ]) {
        expect(
          await runForCode(<String>[
            '--json',
            '--no-log-file',
            '--db',
            missingDb,
            ...command,
          ]),
          cli.ExitCode.failure,
          reason: command.first,
        );
      }
      expect(
        await runForCode(<String>[
          '--json', '--no-log-file', '--db', missingDb,
          'collect', '--forum', '不存在的吧',
        ]),
        cli.ExitCode.usage,
      );
      expect(
        await runForCode(<String>[
          '--json', '--no-log-file', '--db', missingDb,
          'collect', '--seed-forums', '--forum', '不存在的吧',
        ]),
        cli.ExitCode.usage,
      );
      expect(File(missingDb).existsSync(), isFalse);

      final AppDatabase forumsDb = HeadlessEnv.openDb(missingDb);
      await CollectRepository(forumsDb).addForum('已关注吧');
      await forumsDb.close();
      expect(
        await runForCode(<String>[
          '--json',
          '--no-log-file',
          '--db',
          missingDb,
          'collect',
          '--forum',
          '不存在的吧',
        ]),
        cli.ExitCode.usage,
      );

      expect(
        await runForCode(<String>[
          '--json',
          '--no-log-file',
          '--db',
          missingDb,
          'doctor',
          '--seed-dir',
          tmp.path,
        ]),
        cli.ExitCode.failure,
      );
      expect(File(missingDb).existsSync(), isTrue,
          reason: 'doctor 只读检查不改写已存在的测试库');

      await File('${tmp.path}${Platform.pathSeparator}manifest.json')
          .writeAsString('{broken');
      expect(
        await runForCode(<String>[
          '--json',
          '--no-log-file',
          'seed',
          '--dir',
          tmp.path,
        ]),
        cli.ExitCode.failure,
      );
    } finally {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    }
  });

  test('只读 CLI 命令不会迁移旧 schema', () async {
    final Directory tmp = await Directory.systemTemp.createTemp('booksift_cli_read_only_test');
    final String dbPath = '${tmp.path}${Platform.pathSeparator}app.sqlite';
    final AppDatabase db = HeadlessEnv.openDb(dbPath);
    await HeadlessEnv.tableRowCounts(db);
    await db.close();
    final Database legacy = sqlite3.open(dbPath);
    legacy.execute('PRAGMA user_version = 3');
    legacy.close();

    try {
      expect(
        await runForCode(<String>['--no-log-file', '--db', dbPath, 'stats']),
        cli.ExitCode.ok,
      );
      expect(
        await runForCode(<String>['--no-log-file', '--db', dbPath, 'collect']),
        cli.ExitCode.ok,
      );
      final Database reopened = sqlite3.open(dbPath, mode: OpenMode.readOnly);
      expect(reopened.select('PRAGMA user_version').first['user_version'], 3);
      reopened.close();
      expect(
        await runForCode(<String>[
          '--no-log-file', '--db', dbPath, 'collect', '--seed-forums',
        ]),
        cli.ExitCode.ok,
      );
      final Database seeded = sqlite3.open(dbPath, mode: OpenMode.readOnly);
      expect(seeded.select('PRAGMA user_version').first['user_version'], 4);
      expect(seeded.select('SELECT COUNT(*) AS n FROM collection_state').single['n'], 2);
      seeded.close();
    } finally {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    }
  });

  test('logs 可不连数据库回放、过滤并保留末尾事件', () async {
    final Directory tmp = await Directory.systemTemp.createTemp('booksift_cli_logs_test');
    final String path = '${tmp.path}${Platform.pathSeparator}run.jsonl';
    final List<Map<String, Object?>> events = <Map<String, Object?>>[
      <String, Object?>{
        'run': '20261019-030000-1',
        'seq': 1,
        'ts': '2026-10-19T03:00:00.000Z',
        'level': 'info',
        'scope': 'global',
        'event': '开始',
      },
      <String, Object?>{
        'run': '20261019-030000-1',
        'seq': 2,
        'ts': '2026-10-19T03:00:01.000Z',
        'level': 'info',
        'scope': 'yy小说吧',
        'event': '拉列表',
        'data': <String, Object?>{'pn': 1},
      },
      <String, Object?>{
        'run': '20261019-030000-1',
        'seq': 3,
        'ts': '2026-10-19T03:00:02.000Z',
        'level': 'warn',
        'scope': 'yy小说吧',
        'event': '频控',
        'detail': '限速等待',
      },
    ];
    await File(path).writeAsString(events.map(jsonEncode).join('\n'));

    Future<Map<String, dynamic>> replay(List<String> command) async {
      final List<String> args = <String>[
        '--json', '--no-log-file', 'logs', '--file', path, ...command,
      ];
      final StringBuffer output = StringBuffer();
      final cli.BookSiftRunner runner = cli.BookSiftRunner(resultSink: output)
        ..argv = args;
      try {
        expect(await runner.run(args), cli.ExitCode.ok);
        return jsonDecode(output.toString()) as Map<String, dynamic>;
      } finally {
        await runner.closeLog();
      }
    }

    try {
      final Map<String, dynamic> filtered = await replay(<String>[
        '--scope', 'yy小说吧', '--level', 'warn',
      ]);
      expect(filtered['count'], 1);
      expect((filtered['items'] as List).single['event'], '频控');

      final Map<String, dynamic> tail = await replay(<String>['--limit', '2']);
      expect((tail['items'] as List).map((dynamic row) => row['seq']), <int>[2, 3]);

      await File(path).writeAsString(
        <Map<String, Object?>>[events.first, events.first].map(jsonEncode).join('\n'),
      );
      await expectLater(
        replay(const <String>[]),
        throwsA(isA<cli.CliError>().having(
          (cli.CliError error) => error.message,
          'message',
          contains('seq 非单调递增/不连续'),
        )),
      );
      await File(path).writeAsString(<Map<String, Object?>>[
        events.first,
        <String, Object?>{...events.last, 'seq': 1},
      ].map(jsonEncode).join('\n'));
      await expectLater(
        replay(const <String>[]),
        throwsA(isA<cli.CliError>().having(
          (cli.CliError error) => error.message,
          'message',
          contains('seq 非单调递增/不连续'),
        )),
      );
      await File(path).writeAsString(
        <Map<String, Object?>>[events.first, events.last].map(jsonEncode).join('\n'),
      );
      await expectLater(
        replay(const <String>[]),
        throwsA(isA<cli.CliError>().having(
          (cli.CliError error) => error.message,
          'message',
          contains('seq 非单调递增/不连续'),
        )),
      );
    } finally {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    }
  });

  test('rank/show 成功结果保持稳定的 JSON 形状', () async {
    final Directory tmp = await Directory.systemTemp.createTemp('booksift_cli_query_test');
    final String dbPath = '${tmp.path}${Platform.pathSeparator}app.sqlite';
    final AppDatabase db = HeadlessEnv.openDb(dbPath);
    try {
      final int postId = await db.into(db.posts).insert(PostsCompanion.insert(
            title: const Value<String?>('推荐：测试帖子'),
            channel: '测试吧',
            date: const Value<String?>('2026-10-18'),
          ));
      await db.into(db.floors).insert(FloorsCompanion.insert(
            postId: postId,
            seq: 1,
            content: const Value<String>('测试楼层'),
          ));
      final int groupId = await db.into(db.bookGroups).insert(BookGroupsCompanion.insert(
            nameNorm: '测试书',
            nameDisplay: const Value<String?>('测试书'),
            wordCountMax: const Value<int?>(42000),
          ));
      await db.into(db.bookEntries).insert(BookEntriesCompanion.insert(
            name: '测试书',
            nameNorm: '测试书',
            channel: '测试吧',
            contentHash: 'test-entry-hash',
            category: const Value<String>('扫书'),
            comment: const Value<String?>('这本书值得一看，推荐给喜欢奇幻题材的读者。'),
            date: const Value<String?>('2026-10-01'),
            wordCount: const Value<int?>(42000),
            bookGroupId: Value<int?>(groupId),
            postRef: Value<int?>(postId),
          ));
      await db.close();

      Future<Map<String, dynamic>> runJson(List<String> command) async {
        final StringBuffer output = StringBuffer();
        final List<String> args = <String>[
          '--json', '--no-log-file', '--db', dbPath, ...command,
        ];
        final cli.BookSiftRunner runner = cli.BookSiftRunner(resultSink: output)
          ..argv = args;
        try {
          expect(await runner.run(args), cli.ExitCode.ok);
          return jsonDecode(output.toString()) as Map<String, dynamic>;
        } finally {
          await runner.closeLog();
        }
      }

      final Map<String, dynamic> rank = await runJson(<String>[
        'rank', '--kind', 'word', '--window', 'year',
      ]);
      expect(rank['kind'], 'word');
      expect((rank['items'] as List).single['count'], 42000);

      final Map<String, dynamic> facets = await runJson(<String>[
        'facets', '--year', '2026', '--month', '10',
      ]);
      final Map<String, dynamic> dimensions =
          facets['dimensions'] as Map<String, dynamic>;
      final Map<String, dynamic> scanCategory =
          (dimensions['categories'] as List).cast<Map<String, dynamic>>().singleWhere(
                (Map<String, dynamic> item) => item['value'] == '扫书',
              );
      expect(scanCategory['count'], 1);
      expect((dimensions['years'] as List).single['value'], '2026');

      final Map<String, dynamic> hot = await runJson(<String>['hot', '--limit', '1']);
      expect((hot['items'] as List).single['name'], '测试书');

      final Map<String, dynamic> timeline =
          await runJson(<String>['timeline', '--limit', '1']);
      expect((timeline['items'] as List).single['post']['title'], '推荐：测试帖子');

      final Map<String, dynamic> random =
          await runJson(<String>['random', '--count', '1']);
      expect((random['items'] as List).single['name'], '测试书');

      final Map<String, dynamic> book = await runJson(<String>[
        'show', 'book', '$groupId',
      ]);
      expect(book['type'], 'book');
      expect((book['book'] as Map)['nameDisplay'], '测试书');
      expect(book['counts'], <String, int>{'scan': 0, 'recommend': 1, 'avoid': 0});
      expect(book['filter'], 'all');
      expect(book['sort'], 'quality_desc');
      expect(book['entryCount'], 1);
      expect(book['totalEntries'], 1);
      expect(book['limit'], 50);
      expect(book['offset'], 0);
      expect((book['entries'] as List).single['postTitle'], '推荐：测试帖子');

      final Map<String, dynamic> recommendations = await runJson(<String>[
        'show', 'book', '$groupId', '--filter', 'recommend', '--sort', 'time_desc',
      ]);
      expect(recommendations['filter'], 'recommend');
      expect(recommendations['sort'], 'time_desc');
      expect(recommendations['entryCount'], 1);
      expect((recommendations['entries'] as List).single['recommendFlag'], 0);

      final Map<String, dynamic> page = await runJson(<String>[
        'show', 'book', '$groupId', '--limit', '0', '--offset', '1',
      ]);
      expect(page['totalEntries'], 1);
      expect(page['entryCount'], 0);
      expect(page['entries'], isEmpty);

      final Map<String, dynamic> post = await runJson(<String>[
        'show', 'post', '$postId',
      ]);
      expect(post['type'], 'post');
      expect((post['post'] as Map)['title'], '推荐：测试帖子');
      expect((post['floors'] as List).single['floor']['content'], '测试楼层');
    } finally {
      if (await File(dbPath).exists()) {
        await File(dbPath).delete();
      }
      if (await tmp.exists()) {
        await tmp.delete(recursive: true);
      }
    }
  });
}
