/// 解析 worker：分类 + 书目抽取 + 归一化（CPU 打包下放，§8.8）。
///
/// **isolate 策略（关键决策，报告有记录）**：任务书基线是「每轮一个长驻后台
/// isolate」——启动时把 assets/dict/book_dict.txt 的行传进去建 BookDict 一次
/// （构建昂贵，不能每帖重建），之后逐帖送原始数据、回送 ingest 产物。
/// 本文件按该基线实现 [IsolatePostWorker]（生产），另提供同构的
/// [LocalPostWorker]（同 isolate 直调）供测试注入假分类函数——两者共用同一
/// 纯函数 [analyzeThread]，行为一致。
///
/// 本文件**不 import flutter**（rootBundle 资产加载与 provider 接线在
/// collect_service.dart）：纯 Dart，可在 `dart run tool/smoke_collect.dart`
/// 与 plain test() 中直接使用。
library;

import 'dart:async';
import 'dart:isolate';

import '../classify/classifier.dart';
import 'normalization.dart';
import 'tieba/src/parse.dart' show extractBookNames;

// ── 端口抽象：网络闸门（§8.11 wifi_only） ────────────────────────────────

/// WiFi 判定端口。**现状诚实标注**：connectivity_plus 未接入（禁加新依赖），
/// 默认实现 [AlwaysAllowNetworkGate] 恒 true；接入后仅替换实现，调度层不动。
abstract interface class NetworkGate {
  Future<bool> isWifi();
}

class AlwaysAllowNetworkGate implements NetworkGate {
  const AlwaysAllowNetworkGate();

  @override
  Future<bool> isWifi() async => true;
}

// ── worker 输入/输出（普通可序列化对象，§8.8「输入输出为普通可序列化对象」） ──

/// 单帖原始数据（主 isolate 已完成 protobuf → 模型转换与 PbContent 拼装）。
class ThreadInput {
  const ThreadInput({
    required this.tid,
    required this.title,
    required this.author,
    required this.createTime,
    required this.floors,
  });

  final int tid;
  final String title;

  /// 发帖人显示名（entries.recommender）。
  final String author;
  final int createTime;
  final List<FloorInput> floors;
}

/// 楼层文本切片（worker 只需文本；图片入库走主 isolate 的 FloorInfo）。
class FloorInput {
  const FloorInput({
    required this.pid,
    required this.seq,
    required this.text,
  });

  final int pid;
  final int seq;
  final String text;
}

/// 抽取产物：一条待入库 book_entry 草稿（归一化/哈希已算好）。
class EntryDraft {
  const EntryDraft({
    required this.name,
    required this.nameNorm,
    required this.author,
    required this.authorNorm,
    required this.comment,
    required this.commentNormHash,
    required this.contentHash,
    required this.floorPid,
    required this.floorSeq,
    required this.quality,
  });

  final String name;
  final String nameNorm;

  /// 解析出的小说作者（null = 30 字窗口未命中，§8.7）。
  final String? author;
  final String authorNorm;
  final String comment;
  final String commentNormHash;
  final String contentHash;

  /// 来源楼层定位（入库时换 floorRef）。
  final int floorPid;
  final int floorSeq;

  /// 3=作者+推荐语 2=推荐语 1=仅推荐人（§7.2 quality 口径）。
  final int quality;
}

/// 单帖分析产物（分类 + 抽取；ingest 侧只消费本对象）。
class ThreadAnalysis {
  const ThreadAnalysis({
    required this.kind,
    required this.flag,
    required this.hitRules,
    required this.booknames,
    required this.dictAnchor,
    required this.entries,
  });

  /// null = 日常闲聊（整帖丢弃仅计数，§8.9）。
  final String? kind;
  final int flag;
  final List<String> hitRules;
  final List<String> booknames;
  final String dictAnchor;
  final List<EntryDraft> entries;
}

/// 分类函数注入点（= classifier.dart 的 classifyV3 签名子集；
/// 测试注入假实现，生产在 isolate 内绑定 BookDict 后调真实现）。
typedef ThreadClassifier = ClassifyResult Function({
  required String title,
  required String firstFloor,
  required String fullText,
  required List<String> booknames,
});

/// 作者抽取正则（§8.7 原文）：书名后 30 字窗口内
/// `(?:作者|by|BY|著)[：:\s]*([^\s，。；、《》"']{1,20})`。
final RegExp _authorRe =
    RegExp("""(?:作者|by|BY|著)[：:\\s]*([^\\s，。；、《》"']{1,20})""");

/// 书名匹配（§8.7：`《([^《》\n]{1,60})》`，parse.dart extractBookNames 同源）。
final RegExp _bookWrapRe = RegExp(r'《([^《》\n]{1,60})》');

/// 作者搜索窗口（书名后 30 字，§8.7）与多书楼层推荐语窗口（书名前后 200 字）。
const int _authorWindowChars = 30;
const int _commentWindowChars = 200;

/// 纯函数：单帖 → 分类 + 书目抽取（[LocalPostWorker] 与 [IsolatePostWorker]
/// 共用，保证两条路径行为一致）。
///
/// 书名抽取用 parse.dart 的 extractBookNames（`《([^《》\n]{1,60})》`，§8.7 口径，
/// 已实现）；classifier.dart 的 extractBooknames 真实现落地后可切换（两者语义
/// 一致，见完成报告「接线点」）。
ThreadAnalysis analyzeThread(
  ThreadInput input, {
  required ThreadClassifier classify,
}) {
  final String firstFloor = input.floors.isNotEmpty ? input.floors.first.text : '';
  final String fullText = <String>[
    input.title,
    for (final FloorInput f in input.floors) f.text,
  ].join('\n');
  final List<String> booknames = extractBookNames(fullText);

  final ClassifyResult cr = classify(
    title: input.title,
    firstFloor: firstFloor,
    fullText: fullText,
    booknames: booknames,
  );

  // 日常闲聊整帖丢弃（entries 不抽）；求书不触发书名抽取（§8.9 处置表）。
  final List<EntryDraft> entries =
      (cr.kind == null || cr.kind == PostKind.seek)
          ? const <EntryDraft>[]
          : _extractEntries(input);

  return ThreadAnalysis(
    kind: cr.kind,
    flag: cr.flag,
    hitRules: cr.hitRules,
    booknames: cr.booknames,
    dictAnchor: cr.dictAnchor,
    entries: entries,
  );
}

/// 逐楼层抽取（§8.7：每个含书名的楼层 → 0..N 条 book_entry）。
List<EntryDraft> _extractEntries(ThreadInput input) {
  final List<EntryDraft> out = <EntryDraft>[];
  final Set<String> seenHashes = <String>{};
  for (final FloorInput f in input.floors) {
    final Iterable<RegExpMatch> matches = _bookWrapRe.allMatches(f.text).toList();
    if (matches.isEmpty) continue;
    // 楼层内保序去重书名（同 parse.extractBookNames 键口径：去空白）。
    final Set<String> seenNames = <String>{};
    final bool single =
        matches.where((RegExpMatch m) => seenNames.add(_nameKey(m))).length == 1;
    seenNames.clear();
    for (final RegExpMatch m in matches) {
      final String name = (m.group(1) ?? '').trim();
      final String key = _nameKey(m);
      if (name.isEmpty || key.isEmpty || !seenNames.add(key)) continue;

      // 作者：书名后 30 字窗口（§8.7）。
      final String authorWindow = f.text.substring(
        m.end,
        (m.end + _authorWindowChars).clamp(0, f.text.length),
      );
      final String? author = _authorRe.firstMatch(authorWindow)?.group(1);

      // 推荐语：单书楼层=全楼文本；多书楼层=书名前后 200 字窗口（§8.7）。
      final String comment = single
          ? f.text.trim()
          : f.text
              .substring(
                (m.start - _commentWindowChars).clamp(0, f.text.length),
                (m.end + _commentWindowChars).clamp(0, f.text.length),
              )
              .trim();
      if (comment.isEmpty) continue;

      final String nameNorm = normName(name);
      if (nameNorm.isEmpty) continue;
      final String authorNorm = normPerson(author ?? '');
      final String commentNormHash = h16(normText(comment));
      final String contentHash = entryContentHash(
        nameNorm: nameNorm,
        authorNorm: authorNorm,
        commentNormHash: commentNormHash,
      );
      // 同帖内同 content_hash 只留首条（跨帖去重由 DB UNIQUE 兜底）。
      if (!seenHashes.add(contentHash)) continue;
      out.add(EntryDraft(
        name: name,
        nameNorm: nameNorm,
        author: (author == null || author.isEmpty) ? null : author,
        authorNorm: authorNorm,
        comment: comment,
        commentNormHash: commentNormHash,
        contentHash: contentHash,
        floorPid: f.pid,
        floorSeq: f.seq,
        quality: (author != null && author.isNotEmpty) ? 3 : 2,
      ));
    }
  }
  return out;
}

String _nameKey(RegExpMatch m) =>
    (m.group(1) ?? '').replaceAll(RegExp(r'\s+'), '');

// ── PostWorker 端口 ─────────────────────────────────────────────────────

abstract interface class PostWorker {
  Future<ThreadAnalysis> analyze(ThreadInput input);

  Future<void> close();
}

typedef PostWorkerFactory = Future<PostWorker> Function();

/// worker 侧异常（分类器未实现/内部错误——调度层按确定性失败处理不重试）。
class WorkerException implements Exception {
  const WorkerException(this.message);

  final String message;

  @override
  String toString() => 'WorkerException($message)';
}

/// 同 isolate 实现（测试/冒烟注入假分类函数；无 isolate 开销）。
class LocalPostWorker implements PostWorker {
  LocalPostWorker(this._classify);

  final ThreadClassifier _classify;

  @override
  Future<ThreadAnalysis> analyze(ThreadInput input) async =>
      analyzeThread(input, classify: _classify);

  @override
  Future<void> close() async {}
}

// ── 长驻后台 isolate 实现（生产，§8.8「CPU 工作下放」） ──────────────────

class _InitMsg {
  const _InitMsg(this.dictLines, this.classifier);
  final List<String> dictLines;
  final ThreadClassifier? classifier;
}

class _ReadyMsg {
  const _ReadyMsg(this.port);
  final SendPort port;
}

class _InitErrorMsg {
  const _InitErrorMsg(this.text);
  final String text;
}

class _AnalyzeMsg {
  const _AnalyzeMsg(this.id, this.input);
  final int id;
  final ThreadInput input;
}

class _ResultMsg {
  const _ResultMsg(this.id, this.analysis);
  final int id;
  final ThreadAnalysis analysis;
}

class _ErrorMsg {
  const _ErrorMsg(this.id, this.text);
  final int id;
  final String text;
}

class _CloseMsg {
  const _CloseMsg();
}

/// 每轮一个长驻后台 isolate：init 时用词典行建 BookDict 一次，之后逐帖分析。
class IsolatePostWorker implements PostWorker {
  IsolatePostWorker._(this._isolate, this._fromWorker);

  /// 启动 worker isolate。
  ///
  /// [dictLines]：book_dict.txt 的行（主 isolate 经 rootBundle 读入后传进来，
  /// 任务书要求）。[classifier] 缺省 = 生产路径（isolate 内构建
  /// `BookDict.fromLines(dictLines)` 并绑定 classifyV3）；注入非空时跳过
  /// BookDict 构建（测试/冒烟用——classifier.dart 真实现落地前 BookDict 是桩）。
  static Future<IsolatePostWorker> spawn({
    required List<String> dictLines,
    ThreadClassifier? classifier,
  }) async {
    final ReceivePort fromWorker = ReceivePort();
    final Isolate isolate = await Isolate.spawn(
      _workerEntry,
      fromWorker.sendPort,
      debugName: 'collect-worker',
    );
    final IsolatePostWorker worker =
        IsolatePostWorker._(isolate, fromWorker);
    worker._listen();
    final SendPort toWorker = await worker._ready.future;
    worker._toWorker = toWorker;
    try {
      toWorker.send(_InitMsg(dictLines, classifier));
      await worker._initDone.future;
    } catch (e) {
      await worker.close();
      rethrow;
    }
    return worker;
  }

  final Isolate _isolate;
  final ReceivePort _fromWorker;
  final Completer<SendPort> _ready = Completer<SendPort>();
  final Completer<void> _initDone = Completer<void>();
  final Map<int, Completer<ThreadAnalysis>> _pending =
      <int, Completer<ThreadAnalysis>>{};
  SendPort? _toWorkerPort;
  int _nextId = 1;
  bool _closed = false;
  StreamSubscription<dynamic>? _sub;

  set _toWorker(SendPort port) => _toWorkerPort = port;

  SendPort get _toWorker => _toWorkerPort!;

  /// 单订阅终身路由（ReceivePort 是单订阅流，只能 listen 一次）。
  void _listen() {
    _sub = _fromWorker.listen((dynamic msg) {
      if (msg is _ReadyMsg) {
        if (!_ready.isCompleted) _ready.complete(msg.port);
      } else if (msg is _InitErrorMsg) {
        if (!_initDone.isCompleted) {
          _initDone.completeError(WorkerException(msg.text));
        }
      } else if (msg is _ResultMsg) {
        _pending.remove(msg.id)?.complete(msg.analysis);
      } else if (msg is _ErrorMsg) {
        _pending.remove(msg.id)?.completeError(WorkerException(msg.text));
      } else if (msg == 'init-ok') {
        if (!_initDone.isCompleted) _initDone.complete();
      }
    });
  }

  @override
  Future<ThreadAnalysis> analyze(ThreadInput input) {
    if (_closed) {
      return Future<ThreadAnalysis>.error(
          const WorkerException('worker 已关闭'));
    }
    final int id = _nextId++;
    final Completer<ThreadAnalysis> c = Completer<ThreadAnalysis>();
    _pending[id] = c;
    _toWorker.send(_AnalyzeMsg(id, input));
    return c.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw WorkerException('worker 分析超时 tid=${input.tid}'),
    );
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _toWorkerPort?.send(const _CloseMsg());
    await _sub?.cancel();
    _fromWorker.close();
    _isolate.kill(priority: Isolate.immediate);
    if (!_ready.isCompleted) {
      _ready.completeError(const WorkerException('worker 关闭'));
    }
    if (!_initDone.isCompleted) {
      _initDone.completeError(const WorkerException('worker 关闭'));
    }
    for (final Completer<ThreadAnalysis> c in _pending.values) {
      if (!c.isCompleted) c.completeError(const WorkerException('worker 关闭'));
    }
    _pending.clear();
  }
}

/// worker isolate 入口（top-level 以便 Isolate.spawn）。
Future<void> _workerEntry(SendPort toMain) async {
  final ReceivePort port = ReceivePort();
  toMain.send(_ReadyMsg(port.sendPort));
  ThreadClassifier? classify;
  await for (final dynamic msg in port) {
    if (msg is _InitMsg) {
      try {
        if (msg.classifier != null) {
          classify = msg.classifier;
        } else {
          // 生产路径：词典一次构建（昂贵，长驻 isolate 的核心理由）。
          final BookDict dict = msg.dictLines.isEmpty
              ? BookDict.empty()
              : BookDict.fromLines(msg.dictLines);
          classify = ({
            required String title,
            required String firstFloor,
            required String fullText,
            required List<String> booknames,
          }) =>
              classifyV3(
                title: title,
                firstFloor: firstFloor,
                fullText: fullText,
                booknames: booknames,
                dict: dict,
              );
        }
        toMain.send('init-ok');
      } catch (e) {
        toMain.send(_InitErrorMsg('$e'));
        port.close();
        return;
      }
    } else if (msg is _AnalyzeMsg) {
      final ThreadClassifier fn = classify!;
      try {
        final ThreadAnalysis out = analyzeThread(msg.input, classify: fn);
        toMain.send(_ResultMsg(msg.id, out));
      } catch (e) {
        toMain.send(_ErrorMsg(msg.id, '$e'));
      }
    } else if (msg is _CloseMsg) {
      port.close();
      return;
    }
  }
}
