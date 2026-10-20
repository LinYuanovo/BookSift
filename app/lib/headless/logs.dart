/// Headless 结构化运行日志（JSON Lines）。
///
/// **为什么需要**：采集/UI 侧的 `CollectRunState.logs` 是给人看的快照，且受
/// `kCollectionLogLimit`(200) 裁剪——长轮次会丢早期行，agent 无法事后复盘。
/// 本层提供不裁剪、可落盘、可机读的事件流：
///
/// - 一行一个 JSON 对象（JSONL），字段固定：`run/seq/ts/level/scope/event/detail/data`
/// - 多 sink 扇出：stdout（`--json` 机读 / 默认人读）+ `logs/<run_id>.jsonl` 落盘 + 内存（测试）
/// - `run_id` 贯穿一次进程运行，日志文件名即 run_id，便于跨次对比与 grep
///
/// **纯 Dart**（dart:io + dart:convert），可在 `dart run` 下使用。
library;

import 'dart:convert';
import 'dart:io';

import '../collector/collect_state.dart';

/// 日志级别（与 UI 的 [CollectLogLevel] 语义对齐，另加 [RunLevel.error] 供 CLI 致命错）。
enum RunLevel {
  info,
  ok,
  warn,
  error;

  /// JSON 里的稳定字面量（不要用 name，避免枚举重命名破坏日志解析）。
  String get wire => switch (this) {
    RunLevel.info => 'info',
    RunLevel.ok => 'ok',
    RunLevel.warn => 'warn',
    RunLevel.error => 'error',
  };
}

/// UI 日志级别 → 运行日志级别。
RunLevel runLevelOf(CollectLogLevel level) => switch (level) {
  CollectLogLevel.info => RunLevel.info,
  CollectLogLevel.ok => RunLevel.ok,
  CollectLogLevel.warn => RunLevel.warn,
  CollectLogLevel.accent => RunLevel.info,
};

/// 一条运行事件（= JSONL 一行）。
class RunEvent {
  const RunEvent({
    required this.runId,
    required this.seq,
    required this.ts,
    required this.scope,
    required this.event,
    this.detail = '',
    this.level = RunLevel.info,
    this.data = const <String, Object?>{},
  });

  /// 所属运行 ID（同进程内所有事件共享）。
  final String runId;

  /// 进程内单调递增序号（从 1 起；日志乱序/丢行可据此发现）。
  final int seq;

  /// 事件时刻（UTC）。
  final DateTime ts;

  /// 来源域：吧名 / `global` / 子命令名。
  final String scope;

  /// 事件类型（开始/拉列表/分类/入库/频控/完成/失败/取消/…）。
  final String event;

  /// 人读详情。
  final String detail;

  final RunLevel level;

  /// 机读附加字段（tid/pn/计数/耗时等；空 map 时 JSON 中省略）。
  final Map<String, Object?> data;

  Map<String, Object?> toJson() => <String, Object?>{
    'run': runId,
    'seq': seq,
    'ts': ts.toUtc().toIso8601String(),
    'level': level.wire,
    'scope': scope,
    'event': event,
    if (detail.isNotEmpty) 'detail': detail,
    if (data.isNotEmpty) 'data': data,
  };

  String toJsonLine() => jsonEncode(toJson());

  /// 人读单行：`16:36:24.123 WARN  哀伤雪刃 频控  429 → 2880s 后重试`。
  String toTextLine() {
    final DateTime l = ts.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    final String stamp =
        '${two(l.hour)}:${two(l.minute)}:${two(l.second)}.${l.millisecond.toString().padLeft(3, '0')}';
    final String tag = level.wire.toUpperCase().padRight(5);
    final String buf =
        '$stamp $tag $scope $event${detail.isEmpty ? '' : '  $detail'}';
    return buf;
  }
}

/// 日志输出端。
abstract interface class RunLogSink {
  void write(RunEvent event);
  Future<void> close();
}

/// stdout 输出（[json]=true 走 JSONL，否则人读单行）。
class StdoutRunLogSink implements RunLogSink {
  const StdoutRunLogSink({this.json = false});

  final bool json;

  @override
  void write(RunEvent event) =>
      stdout.writeln(json ? event.toJsonLine() : event.toTextLine());

  @override
  Future<void> close() async => stdout.flush();
}

/// stderr 输出（`--json` 模式：结果数据独占 stdout，诊断日志走 stderr，
/// 于是 `dart run bin/booksift.dart query 剑来 --json | jq .` 不会被日志污染）。
class StderrRunLogSink implements RunLogSink {
  const StderrRunLogSink({this.json = true});

  final bool json;

  @override
  void write(RunEvent event) =>
      stderr.writeln(json ? event.toJsonLine() : event.toTextLine());

  @override
  Future<void> close() async => stderr.flush();
}

/// JSONL 文件输出（追加写；目录不存在时自动创建）。
class FileRunLogSink implements RunLogSink {
  FileRunLogSink._(this.path, this._sink);

  /// 打开（或创建）[path] 追加写。
  static Future<FileRunLogSink> open(String path) async {
    final File f = File(path);
    final Directory parent = f.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    return FileRunLogSink._(path, f.openWrite(mode: FileMode.append));
  }

  final String path;
  final IOSink _sink;

  @override
  void write(RunEvent event) => _sink.writeln(event.toJsonLine());

  @override
  Future<void> close() => _sink.flush().then((_) => _sink.close());
}

/// 内存输出（单元测试与编程式消费用；不碰 IO）。
class MemoryRunLogSink implements RunLogSink {
  final List<RunEvent> events = <RunEvent>[];

  /// 全部 JSONL 行（断言用）。
  List<String> get jsonLines =>
      events.map((RunEvent e) => e.toJsonLine()).toList();

  @override
  void write(RunEvent event) => events.add(event);

  @override
  Future<void> close() async {}
}

/// 运行日志器：分配 run_id / seq，扇出到多个 [RunLogSink]。
///
/// 典型用法（CLI）：
/// ```dart
/// final RunLog log = RunLog(runId: RunLog.newRunId(), sinks: [StdoutRunLogSink(json: asJson)]);
/// log.emit('global', '开始', detail: '…');
/// await log.close();
/// ```
class RunLog {
  RunLog({required this.runId, required this.sinks, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// 生成 run_id：`yyyyMMdd-HHmmss-<pid>`（同秒多进程不撞）。
  static String newRunId([DateTime? now]) {
    final DateTime t = (now ?? DateTime.now()).toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}${two(t.second)}-$pid';
  }

  final String runId;
  final List<RunLogSink> sinks;
  final DateTime Function() _clock;

  int _seq = 0;

  /// 已发出的事件数（= 最后一个 seq）。
  int get count => _seq;

  /// 发一条事件。
  void emit(
    String scope,
    String event, {
    String detail = '',
    RunLevel level = RunLevel.info,
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    final RunEvent e = RunEvent(
      runId: runId,
      seq: ++_seq,
      ts: _clock(),
      scope: scope,
      event: event,
      detail: detail,
      level: level,
      data: data,
    );
    for (final RunLogSink s in sinks) {
      s.write(e);
    }
  }

  /// 把采集服务的一条 UI 日志转成运行事件（scope=fname，'全局' 归一为 `global`）。
  void emitCollect(CollectLogEntry entry) => emit(
    entry.fname == '全局' ? 'global' : entry.fname,
    entry.event,
    detail: entry.detail,
    level: runLevelOf(entry.level),
    data: <String, Object?>{'src': 'collect'},
  );

  /// 关闭全部 sink（落盘必须 await，否则尾部行可能丢）。
  Future<void> close() async {
    for (final RunLogSink s in sinks) {
      await s.close();
    }
  }
}
