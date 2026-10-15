// headless 结构化日志测试（logs.dart）。
//
// 全部 plain test()：FileRunLogSink 用例碰真实 dart:io，按 TESTING.md §1
// 不能进 testWidgets 的 FakeAsync 假时钟区。
//
// 覆盖：JSON 字段契约（agent 解析依赖它，字段名不得随意改）/ seq 单调 /
// run_id 贯穿 / CollectLogEntry 桥接（级别映射 + '全局'→global）/
// 文本行毫秒三位 / JSONL 落盘逐行可解析。

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/collector/collect_state.dart';
import 'package:booksift/headless/logs.dart';

void main() {
  group('RunEvent JSON 契约', () {
    test('字段齐全，空 detail/data 省略，level 走稳定 wire 字面量', () {
      final RunEvent e = RunEvent(
        runId: 'r1',
        seq: 7,
        ts: DateTime.utc(2026, 10, 13, 9, 8, 7, 654),
        scope: 'yy小说吧',
        event: '入库',
        detail: 'tid=123',
        level: RunLevel.warn,
        data: const <String, Object?>{'tid': 123},
      );
      final Map<String, Object?> j = e.toJson();

      expect(j['run'], 'r1');
      expect(j['seq'], 7);
      expect(j['ts'], '2026-10-13T09:08:07.654Z');
      expect(j['level'], 'warn');
      expect(j['scope'], 'yy小说吧');
      expect(j['event'], '入库');
      expect(j['detail'], 'tid=123');
      expect(j['data'], <String, Object?>{'tid': 123});
    });

    test('detail 为空 / data 为空时不出现在 JSON 里（避免噪声键）', () {
      final Map<String, Object?> j = RunEvent(
        runId: 'r1',
        seq: 1,
        ts: DateTime.utc(2026),
        scope: 'global',
        event: 'ping',
      ).toJson();
      expect(j.containsKey('detail'), isFalse);
      expect(j.containsKey('data'), isFalse);
    });

    test('level.wire 是固定字面量，不随枚举重命名漂移', () {
      expect(
        RunLevel.values.map((RunLevel l) => l.wire).toList(),
        <String>['info', 'ok', 'warn', 'error'],
      );
    });

    test('toJsonLine 是单行且可被 jsonDecode 还原', () {
      final String line = RunEvent(
        runId: 'r1',
        seq: 1,
        ts: DateTime.utc(2026),
        scope: 'global',
        event: '开始',
        detail: '换行\n不应出现',
      ).toJsonLine();
      expect(line.contains('\n'), isFalse, reason: 'JSONL 一行一事件，不得含裸换行');
      expect(jsonDecode(line), isA<Map<String, dynamic>>());
      expect((jsonDecode(line) as Map<String, dynamic>)['detail'], '换行\n不应出现');
    });

    test('toTextLine 毫秒固定三位（.098 不塌成 .98）', () {
      final RunEvent e = RunEvent(
        runId: 'r1',
        seq: 1,
        ts: DateTime(2026, 10, 13, 17, 9, 8, 98),
        scope: 'global',
        event: 'x',
      );
      expect(e.toTextLine(), contains('17:09:08.098'));
      final RunEvent e2 = RunEvent(
        runId: 'r1',
        seq: 2,
        ts: DateTime(2026, 10, 13, 17, 9, 8, 346),
        scope: 'global',
        event: 'x',
      );
      expect(e2.toTextLine(), contains('17:09:08.346'));
    });
  });

  group('RunLog 扇出', () {
    test('seq 从 1 单调递增，runId 贯穿每条事件', () {
      final MemoryRunLogSink mem = MemoryRunLogSink();
      final RunLog log = RunLog(
        runId: 'run-x',
        sinks: <RunLogSink>[mem],
        clock: () => DateTime.utc(2026),
      );
      log.emit('global', 'a');
      log.emit('global', 'b');
      log.emit('yy小说吧', 'c', detail: 'd', level: RunLevel.error);

      expect(log.count, 3);
      expect(mem.events.map((RunEvent e) => e.seq).toList(), <int>[1, 2, 3]);
      expect(mem.events.every((RunEvent e) => e.runId == 'run-x'), isTrue);
      expect(mem.events.last.level, RunLevel.error);
      expect(mem.events.last.scope, 'yy小说吧');
    });

    test('多 sink 同时收到同一条事件', () {
      final MemoryRunLogSink a = MemoryRunLogSink();
      final MemoryRunLogSink b = MemoryRunLogSink();
      final RunLog log = RunLog(runId: 'r', sinks: <RunLogSink>[a, b]);
      log.emit('global', 'x');
      expect(a.events, hasLength(1));
      expect(b.events, hasLength(1));
      expect(a.events.single.seq, b.events.single.seq);
    });

    test('emitCollect 桥接：级别映射 + fname「全局」归一为 global', () {
      final MemoryRunLogSink mem = MemoryRunLogSink();
      final RunLog log = RunLog(runId: 'r', sinks: <RunLogSink>[mem]);

      log.emitCollect(CollectLogEntry(
        time: DateTime.utc(2026),
        fname: '全局',
        event: '频控',
        detail: '整轮暂停',
        level: CollectLogLevel.warn,
      ));
      log.emitCollect(CollectLogEntry(
        time: DateTime.utc(2026),
        fname: '哀伤雪刃',
        event: '入库',
        detail: '+3 帖',
        level: CollectLogLevel.ok,
      ));
      log.emitCollect(CollectLogEntry(
        time: DateTime.utc(2026),
        fname: 'x',
        event: 'e',
        detail: '',
        level: CollectLogLevel.accent,
      ));

      expect(mem.events[0].scope, 'global');
      expect(mem.events[0].level, RunLevel.warn);
      expect(mem.events[1].scope, '哀伤雪刃');
      expect(mem.events[1].level, RunLevel.ok);
      // accent 是 UI 强调色，不代表严重度 → 归 info。
      expect(mem.events[2].level, RunLevel.info);
      // 每条都标了来源，便于和 CLI 自身事件区分。
      expect(mem.events.every((RunEvent e) => e.data['src'] == 'collect'), isTrue);
    });

    test('runLevelOf 覆盖全部 UI 级别', () {
      expect(runLevelOf(CollectLogLevel.info), RunLevel.info);
      expect(runLevelOf(CollectLogLevel.ok), RunLevel.ok);
      expect(runLevelOf(CollectLogLevel.warn), RunLevel.warn);
      expect(runLevelOf(CollectLogLevel.accent), RunLevel.info);
    });

    test('newRunId 含时间戳与 pid（同秒多进程不撞）', () {
      final String id = RunLog.newRunId(DateTime(2026, 1, 2, 3, 4, 5));
      expect(id, startsWith('20260102-030405-'));
      expect(id, endsWith('$pid'));
    });
  });

  group('FileRunLogSink（真实 IO）', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('booksift_logs_test');
    });

    tearDown(() async {
      if (await tmp.exists()) {
        await tmp.delete(recursive: true);
      }
    });

    test('落盘为逐行 JSON，目录不存在时自动创建，close 后尾部行不丢', () async {
      final String path = '${tmp.path}${Platform.pathSeparator}nested${Platform.pathSeparator}r.jsonl';
      final FileRunLogSink sink = await FileRunLogSink.open(path);
      final RunLog log = RunLog(runId: 'r-file', sinks: <RunLogSink>[sink]);
      log.emit('global', '开始', detail: '第一条');
      log.emit('yy小说吧', '入库', detail: '第二条', data: const <String, Object?>{'n': 2});
      await log.close();

      final List<String> lines = await File(path).readAsLines();
      expect(lines, hasLength(2), reason: '未 await close 会丢尾行——本用例即回归防线');
      final Map<String, dynamic> first = jsonDecode(lines[0]) as Map<String, dynamic>;
      expect(first['run'], 'r-file');
      expect(first['seq'], 1);
      expect(first['event'], '开始');
      final Map<String, dynamic> second = jsonDecode(lines[1]) as Map<String, dynamic>;
      expect((second['data'] as Map<String, dynamic>)['n'], 2);
    });

    test('追加写：同一文件两次运行不互相覆盖', () async {
      final String path = '${tmp.path}${Platform.pathSeparator}append.jsonl';
      for (int i = 0; i < 2; i++) {
        final RunLog log = RunLog(
          runId: 'run-$i',
          sinks: <RunLogSink>[await FileRunLogSink.open(path)],
        );
        log.emit('global', 'e$i');
        await log.close();
      }
      final List<String> lines = await File(path).readAsLines();
      expect(lines, hasLength(2));
      expect((jsonDecode(lines[0]) as Map<String, dynamic>)['run'], 'run-0');
      expect((jsonDecode(lines[1]) as Map<String, dynamic>)['run'], 'run-1');
    });
  });
}
