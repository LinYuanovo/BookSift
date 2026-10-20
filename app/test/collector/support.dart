/// 采集服务测试挂具（全部 plain test() 用；TESTING.md §3.2：真实异步 + 内存库）。
///
/// - [FakeClock]/假 sleeper：限速/退避免真等（时钟由 sleeper 推进）；
/// - [FakeTiebaApi]：脚本化 [TiebaApi]（假响应 + 注入错误 + 请求时序记录）；
/// - [fakeClassify]：假分类函数（不依赖 lib/classify 真实现——契约桩会 throw）；
/// - [TestEnv]：内存库 + repo + service 一键组装，快照流全录。
library;

import 'dart:math';

import 'package:drift/native.dart';
import 'package:booksift/classify/classifier.dart';
import 'package:booksift/collector/collect_service.dart';
import 'package:booksift/collector/collect_state.dart';
import 'package:booksift/collector/scheduler.dart';
import 'package:booksift/collector/tieba/src/models.dart';
import 'package:booksift/collector/tieba_api.dart';
import 'package:booksift/collector/worker.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/collect_repository.dart';

// ── 时钟 ─────────────────────────────────────────────────────────────────

class FakeClock implements CollectClock {
  FakeClock([DateTime? start])
      : _now = start ?? DateTime(2026, 10, 13, 8, 0, 0);

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration d) => _now = _now.add(d);
}

/// 假 sleeper：推进假时钟并立即返回（免真等）。
Sleeper fakeSleeper(FakeClock clock) => (Duration d) async {
      clock.advance(d);
    };

// ── 假贴吧 API ───────────────────────────────────────────────────────────

class ApiCall {
  ApiCall(this.key, this.forum, this.pn, this.startedAt);

  /// 'threads:$fname:$pn' / 'posts:$tid:$pn'。
  final String key;
  final String forum;
  final int pn;
  final DateTime startedAt;
  DateTime? endedAt;

  bool get isThreads => key.startsWith('threads:');
}

class _ErrorRule {
  _ErrorRule(this.prefix, this.error, this.remaining);
  final String prefix;
  final Object error;

  /// -1 = 无限次；>0 = 剩余次数。
  int remaining;
}

class FakeTiebaApi implements TiebaApi {
  FakeTiebaApi(this.clock, {this.holdTicks = 4});

  final FakeClock clock;

  /// 每请求保持的事件循环轮数（制造在途重叠，供并发断言）。
  final int holdTicks;

  final Map<String, ThreadsPage> _threads = <String, ThreadsPage>{};
  final Map<String, PostsPage> _posts = <String, PostsPage>{};
  final List<_ErrorRule> _rules = <_ErrorRule>[];

  /// tid → 所属吧（并发/串行断言的吧归属）。
  final Map<int, String> tidForum = <int, String>{};

  final List<ApiCall> calls = <ApiCall>[];
  int _activeNow = 0;
  int _maxActive = 0;
  final Map<String, int> _activeByForum = <String, int>{};
  int _maxActiveSameForum = 0;
  bool closed = false;

  /// 每次请求完成后回调（参数 = 已完成请求数；取消/断言时序注入点）。
  void Function(int callCount)? afterRequest;

  int get maxActive => _maxActive;
  int get maxActiveSameForum => _maxActiveSameForum;

  int countCalls(bool Function(ApiCall c) test) => calls.where(test).length;

  void scriptThreads(String fname, int pn, ThreadsPage page) =>
      _threads['$fname:$pn'] = page;

  void scriptPosts(int tid, int pn, PostsPage page, {String? forum}) {
    _posts['$tid:$pn'] = page;
    if (forum != null) tidForum[tid] = forum;
  }

  void failThreads(String fname, Object error, {int times = 1, int? pn}) =>
      _rules.add(_ErrorRule(
          pn == null ? 'threads:$fname:' : 'threads:$fname:$pn', error, times));

  void failPosts(int tid, Object error, {int times = 1, int? pn}) =>
      _rules.add(_ErrorRule(
          pn == null ? 'posts:$tid:' : 'posts:$tid:$pn', error, times));

  Object? _takeError(String key) {
    for (final _ErrorRule r in _rules) {
      if (key.startsWith(r.prefix) && r.remaining != 0) {
        if (r.remaining > 0) r.remaining--;
        return r.error;
      }
    }
    return null;
  }

  Future<T> _guard<T>(String key, String forum, int pn,
      Future<T> Function() body) async {
    final ApiCall call = ApiCall(key, forum, pn, clock.now());
    calls.add(call);
    _activeNow++;
    _maxActive = max(_maxActive, _activeNow);
    final int f = (_activeByForum[forum] ?? 0) + 1;
    _activeByForum[forum] = f;
    _maxActiveSameForum = max(_maxActiveSameForum, f);
    try {
      final Object? err = _takeError(key);
      if (err != null) throw err;
      for (int i = 0; i < holdTicks; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      final T out = await body();
      afterRequest?.call(calls.length);
      return out;
    } finally {
      call.endedAt = clock.now();
      _activeNow--;
      _activeByForum[forum] = _activeByForum[forum]! - 1;
    }
  }

  @override
  Future<ThreadsPage> getThreads(String fname, {int pn = 1, int rn = 100}) =>
      _guard('threads:$fname:$pn', fname, pn, () async => _threads['$fname:$pn'] ??
          const ThreadsPage(fid: 0, threads: <ThreadSummary>[], hasMore: false));

  @override
  Future<PostsPage> getPosts(int tid, {int pn = 1, int rn = 30}) => _guard(
      'posts:$tid:$pn', tidForum[tid] ?? 'tid:$tid', pn,
      () async => _posts['$tid:$pn'] ?? const PostsPage(floors: <FloorInfo>[], hasMore: false));

  @override
  void close() => closed = true;
}

// ── 错误样本（调度层语义分类见 tieba_api.mapTiebaError） ─────────────────

CollectRequestException err429() => const CollectRequestException(
    kind: CollectFailureKind.rateLimited, code: 429, message: 'HTTP 429');

CollectRequestException err110001() => const CollectRequestException(
    kind: CollectFailureKind.rateLimited,
    code: 110001,
    message: 'errorno=110001 需登录');

CollectRequestException errServer([int code = 4]) => CollectRequestException(
    kind: CollectFailureKind.serverError, code: code, message: 'errorno=$code');

CollectRequestException errNetwork() => const CollectRequestException(
    kind: CollectFailureKind.network, message: '网络异常 connectionTimeout');

// ── 数据脚本构造 ─────────────────────────────────────────────────────────

ThreadSummary mkThread({
  required int tid,
  required int createTime,
  String? title,
  bool isTop = false,
  bool isDeleted = false,
  bool isFrsMask = false,
}) =>
    ThreadSummary(
      tid: tid,
      title: title ?? '推书帖 $tid《书名$tid》',
      authorId: 1000 + tid,
      author: '作者$tid',
      createTime: createTime,
      lastTime: createTime,
      replyNum: 1,
      viewNum: 10,
      isTop: isTop,
      isGood: false,
      isDeleted: isDeleted,
      isFrsMask: isFrsMask,
      threadType: 0,
    );

FloorInfo mkFloor({
  required int pid,
  required int seq,
  String text = '',
  List<ImageInfo> images = const <ImageInfo>[],
  int time = 1760000000,
}) =>
    FloorInfo(
      pid: pid,
      seq: seq,
      authorId: 1,
      author: '层主',
      time: time,
      text: text,
      images: images,
    );

/// 单页帖（默认 1 楼带一本书；hasMore=false）。
PostsPage mkPostsPage(
  int tid, {
  String? floorText,
  bool hasMore = false,
  List<ImageInfo> images = const <ImageInfo>[],
  String title = '',
  int createTime = 0,
}) =>
    PostsPage(
      floors: <FloorInfo>[
        mkFloor(
          pid: tid * 100 + 1,
          seq: 1,
          text: floorText ?? '《书名$tid》 作者：作者君$tid 非常好看推荐',
          images: images,
        ),
      ],
      hasMore: hasMore,
      title: title,
      authorId: 1000 + tid,
      author: '作者$tid',
      authorUserName: 'user_$tid',
      createTime: createTime,
      replyNum: 1,
    );

// ── 假分类函数（不依赖 lib/classify 真实现；top-level 以便跨 isolate 传递） ──

ClassifyResult fakeClassify({
  required String title,
  required String firstFloor,
  required String fullText,
  required List<String> booknames,
}) {
  if (title.contains('水贴') || title.contains('闲聊')) {
    return ClassifyResult(
        kind: null, flag: 0, hitRules: const <String>['fake-R7'], booknames: booknames);
  }
  if (title.contains('排雷') || title.contains('避雷')) {
    return ClassifyResult(
        kind: PostKind.mine,
        flag: -1,
        hitRules: const <String>['fake-R1'],
        booknames: booknames);
  }
  if (title.contains('求书') || title.contains('书荒')) {
    return ClassifyResult(
        kind: PostKind.seek,
        flag: 0,
        hitRules: const <String>['fake-R2'],
        booknames: booknames);
  }
  return ClassifyResult(
      kind: PostKind.scan,
      flag: 1,
      hitRules: const <String>['fake-R5'],
      booknames: booknames);
}

/// 对标题含「坏帖」的帖抛错（模拟分类器确定性失败 → 永久失败不重试）。
ClassifyResult crashingClassify({
  required String title,
  required String firstFloor,
  required String fullText,
  required List<String> booknames,
}) {
  if (title.contains('坏帖')) throw StateError('分类器炸了（测试注入）');
  return fakeClassify(
      title: title,
      firstFloor: firstFloor,
      fullText: fullText,
      booknames: booknames);
}

// ── 环境组装 ─────────────────────────────────────────────────────────────

class TestEnv {
  TestEnv._({
    required this.db,
    required this.repo,
    required this.api,
    required this.clock,
    required this.service,
    required this.snapshots,
    required this.networkGate,
  });

  final AppDatabase db;
  final CollectRepository repo;
  final FakeTiebaApi api;
  final FakeClock clock;
  final CollectService service;
  final List<CollectRunState> snapshots;
  final FakeNetworkGate networkGate;

  CollectRunState get last => snapshots.last;

  static Future<TestEnv> create({
    List<String> forums = const <String>[],
    int budgetLimit = 300,
    ThreadClassifier? classifier,
    int? concurrency,
    int holdTicks = 4,
    int? seed,
    bool bdussImported = false,
    bool wifiAvailable = true,
    TiebaApi Function()? anonymousApiFactory,
    void Function()? onAccountInvalid,
    FakeClock? clock,
  }) async {
    final FakeClock effectiveClock = clock ?? FakeClock();
    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    final CollectRepository repo = CollectRepository(db);
    final FakeTiebaApi api = FakeTiebaApi(effectiveClock, holdTicks: holdTicks);
    final List<CollectRunState> snapshots = <CollectRunState>[];
    final FakeNetworkGate networkGate = FakeNetworkGate(wifiAvailable);
    final CollectService service = CollectService(
      db: db,
      repo: repo,
      api: api,
      workerFactory: () async => LocalPostWorker(classifier ?? fakeClassify),
      clock: effectiveClock,
      sleeper: fakeSleeper(effectiveClock),
      rng: Random(seed ?? 42),
      budgetLimit: budgetLimit,
      bdussImported: bdussImported,
      networkGate: networkGate,
      anonymousApiFactory: anonymousApiFactory,
      onAccountInvalid: onAccountInvalid,
      onState: snapshots.add,
    );
    for (final String f in forums) {
      await repo.addForum(f);
    }
    if (concurrency != null) {
      await repo.setSetting('concurrent_forums', '$concurrency');
    }
    return TestEnv._(
        db: db,
        repo: repo,
        api: api,
        clock: effectiveClock,
        service: service,
        snapshots: snapshots,
        networkGate: networkGate);
  }

  Future<void> dispose() => db.close();
}

class FakeNetworkGate implements NetworkGate {
  FakeNetworkGate(this.wifiAvailable);

  bool wifiAvailable;

  @override
  Future<bool> isWifi() async => wifiAvailable;
}
