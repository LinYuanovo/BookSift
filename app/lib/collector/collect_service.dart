/// 采集服务编排（M2-①，§8.7 流程 + §8.8 并发模型 + §8.11 频控 + §8.12 降级）。
///
/// 调度数据流：startAll → [CollectService.run] → 每吧一条并发分支
/// （[Semaphore] 闸门 ≤ 并发上限）→ ① get_threads 增量翻页（吧内严格串行，
/// 每个请求经 [GlobalRateLimiter] 全局间隔 + [DailyBudget] 预算核算）→
/// ② 待采队列按 create_time 升序逐帖 get_posts → [PostWorker]（长驻后台
/// isolate：分类 + 书目抽取 + 归一化）→ ③ [IngestPipeline] 单帖单事务入库 →
/// ④ 水位推进（仅成功前缀）+ collection_state/日志落库 → 全程以
/// [CollectRunState] 不可变快照经 onState 发布给 [CollectRunNotifier]。
///
/// **本文件纯 Dart（零 `package:flutter` 依赖）**：生产 provider 接线在
/// `collect_providers.dart`，故 headless CLI 可直接构造 [CollectService]
/// （见 `lib/headless/collect.dart`）。
library;

import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart' show Value;

import '../classify/classifier.dart' show PostKind;
import '../core/constants.dart';
import '../data/db/app_database.dart';
import '../data/repo/collect_repository.dart';
import 'collect_settings_keys.dart';
import 'collect_state.dart';
import 'ingest.dart';
import 'scheduler.dart';
import 'tieba/src/models.dart';
import 'tieba_api.dart';
import 'watermark.dart';
import 'worker.dart';

// ── §8.7/§8.11 采集参数 ──────────────────────────────────────────────────

/// 单次运行每吧主题列表页上限（§8.7 步骤 3：≤5 页 = 500 帖）。
const int kMaxListPages = 5;

/// 冷启动（水位=0）回溯页数（§8.7 步骤 7：只回溯最近 2 页，避免与种子库大面积重叠）。
const int kColdStartListPages = 2;

/// 单帖楼层页上限（§8.7 步骤 4：pn>20 超长帖截断标记 partial）。
const int kMaxPostPages = 20;

/// get_threads 页大小（rn=100，sort=CREATE，§8.7 步骤 1）。
const int kThreadRn = 100;

/// get_posts 页大小（rn=30 ASC，§8.7 步骤 4）。
const int kPostRn = 30;

/// 主题列表页失败原地退避重试次数（吧内尚无队列，阻塞无副作用；§8.11）。
const int kListRetries = 3;

/// §8.12 全局降级横幅文案。
const String kBannerApiBroken =
    '贴吧接口似乎已变更或网络持续异常，本轮采集已暂停；离线检索与阅读不受影响';

typedef CollectStateSink = void Function(CollectRunState state);

enum _StopReason { canceled, paused, budget }

enum _ForumOutcome {
  completed,
  canceled,
  paused,
  cooldown,
  listFailed,
  budget,
  crashed,

  /// 启动时仍在冷却期 → 跳过（不落库不重写冷却，§8.11）。
  skippedCooldown,
}

class _StopSignal implements Exception {
  const _StopSignal(this.reason);
  final _StopReason reason;
}

class _CooldownSignal implements Exception {
  const _CooldownSignal(this.cause);
  final CollectRequestException cause;
}

class _PermFailSignal implements Exception {
  const _PermFailSignal(this.message, this.kind);
  final String message;
  final CollectFailureKind kind;
}

class _ThreadTask {
  _ThreadTask(this.thread, this.dueAt);
  final ThreadSummary thread;
  int retries = 0;
  DateTime dueAt;
}

/// 每吧一轮的运行上下文（分支私有，不跨吧共享）。
class _ForumCtx {
  _ForumCtx(this.entry, this.wmFrom);

  final CollectionStateEntry entry;
  final Watermark wmFrom;

  String get fname => entry.fname;

  /// 吧级连续请求失败计数（成功清零；≥3 → 冷却 48h，§8.11）。
  int forumFailures = 0;
  CollectStats stats = const CollectStats.zero();
  int? learnedFid;
  _ForumOutcome outcome = _ForumOutcome.completed;
  String? failMessage;
  CollectFailureKind? failKind;
  final Set<int> succeededTids = <int>{};
  final Set<int> failedTids = <int>{};
}

class CollectService {
  CollectService({
    required AppDatabase db,
    required CollectRepository repo,
    required TiebaApi api,
    required PostWorkerFactory workerFactory,
    required CollectStateSink onState,
    CollectClock clock = const SystemClock(),
    Sleeper? sleeper,
    Random? rng,
    NetworkGate networkGate = const AlwaysAllowNetworkGate(),
    this.budgetLimit = kDailyBudgetAnonymous,
    this.onLog,
  })  : _repo = repo,
        _api = api,
        _workerFactory = workerFactory,
        _onState = onState,
        _clock = clock,
        _sleeper = sleeper ?? ((Duration d) => Future<void>.delayed(d)),
        _rng = rng ?? Random(),
        _gate = networkGate,
        _ingest = IngestPipeline(db);

  final CollectRepository _repo;
  final TiebaApi _api;
  final PostWorkerFactory _workerFactory;
  final CollectStateSink _onState;
  final CollectClock _clock;
  final Sleeper _sleeper;
  final Random _rng;
  final NetworkGate _gate;
  final IngestPipeline _ingest;

  /// 每日请求预算上限（匿名 ≤300，§8.11；BDUSS 档 600 未接入）。
  final int budgetLimit;

  /// 逐条日志回调（可选；headless/CLI 结构化日志落盘用，见 lib/headless/logs.dart）。
  ///
  /// 与 [onState] 的分工：onState 发整轮不可变快照（UI 消费），其 `logs` 受
  /// [kCollectionLogLimit]=200 上限裁剪，长轮次会丢早期行；onLog 每条即时分发、
  /// 不裁剪，故落盘/排错走这里。null = 不额外分发（UI 路径零开销）。
  final void Function(CollectLogEntry entry)? onLog;

  CollectPhase _phase = CollectPhase.idle;
  Future<void>? _runFuture;
  bool _cancelRequested = false;
  bool _globalPaused = false;
  bool _budgetExhausted = false;
  int _globalFailures = 0;
  Completer<void>? _cancelCompleter;

  final Map<String, ForumRunState> _forumStates =
      <String, ForumRunState>{}; // LinkedHashMap：forums 顺序 = 启动顺序
  final List<CollectLogEntry> _logs = <CollectLogEntry>[];
  String? _banner;
  DateTime? _startedAt;
  DateTime? _finishedAt;

  late Semaphore _sem;
  late GlobalRateLimiter _limiter;

  bool get isRunning => _runFuture != null;

  /// 当前轮完成 future（未运行 = 立即完成）。cancel()/测试等待用。
  Future<void> get completion => _runFuture ?? Future<void>.value();

  void requestCancel() {
    if (_phase != CollectPhase.running) return;
    _cancelRequested = true;
    _phase = CollectPhase.stopping;
    final Completer<void>? c = _cancelCompleter;
    if (c != null && !c.isCompleted) c.complete();
    _log('全局', '取消', '取消请求已发出，等待各吧分支收尾（水位不推进）',
        level: CollectLogLevel.warn);
    _publish();
  }

  /// 启动一轮增量采集；运行中再调用返回同一 future（= no-op 语义）。
  Future<void> run() {
    final Future<void>? existing = _runFuture;
    if (existing != null) return existing;
    final Completer<void> c = Completer<void>();
    _runFuture = c.future;
    () async {
      try {
        await _runInner();
      } catch (e, st) {
        _log('全局', '失败', '采集异常终止：$e', level: CollectLogLevel.warn);
        debugPrintCollect('$e\n$st');
      } finally {
        _phase = CollectPhase.idle;
        _finishedAt = _clock.now();
        _runFuture = null;
        _publish();
        if (!c.isCompleted) c.complete();
      }
    }();
    return c.future;
  }

  Future<void> _runInner() async {
    _cancelRequested = false;
    _globalPaused = false;
    _budgetExhausted = false;
    _globalFailures = 0;
    _banner = null;
    _logs.clear();
    _forumStates.clear();
    _finishedAt = null;
    _startedAt = _clock.now();
    _cancelCompleter = Completer<void>();

    // wifi_only（§8.11：默认仅 WiFi；NetworkGate 现状恒 true，见 worker.dart 注释）。
    final String wifiRaw = await _repo.getSetting(SettingsKeys.wifiOnly) ?? '1';
    final bool wifiOnly = wifiRaw != '0' && wifiRaw != 'false';
    if (wifiOnly && !await _gate.isWifi()) {
      _banner = '当前非 WiFi 网络，已按设置暂停采集（设置页可关闭「仅 WiFi」）';
      _log('全局', '频控', _banner!, level: CollectLogLevel.warn);
      _publish();
      return;
    }

    await _repo.seedDefaultsIfEmpty();
    final List<CollectionStateEntry> forums =
        (await _repo.forums()).where((CollectionStateEntry e) => e.enabled).toList();
    if (forums.isEmpty) {
      _banner = '暂无启用的关注吧，请先添加';
      _log('全局', '失败', _banner!, level: CollectLogLevel.warn);
      _publish();
      return;
    }

    final int concurrency =
        effectiveConcurrency(await _repo.getSetting(SettingsKeys.concurrentForums));
    _sem = Semaphore(concurrency);
    final DailyBudget budget = DailyBudget(
      store: _RepoBudgetStore(_repo),
      clock: _clock,
      limit: budgetLimit,
      dateKey: CollectSettingsKeys.budgetDate,
      countKey: CollectSettingsKeys.budgetCount,
    );
    _limiter = GlobalRateLimiter(
      clock: _clock,
      sleeper: _sleeper,
      rng: _rng,
      budget: budget,
    );

    PostWorker? worker;
    try {
      worker = await _workerFactory();
    } catch (e) {
      _banner = '采集解析器启动失败：$e';
      _log('全局', '失败', _banner!, level: CollectLogLevel.warn);
      _publish();
      return;
    }

    _phase = CollectPhase.running;
    for (final CollectionStateEntry e in forums) {
      _forumStates[e.fname] = ForumRunState(
        fname: e.fname,
        fid: e.fid,
        watermarkFrom: e.lastThreadTime,
      );
    }
    _log('全局', '开始',
        '开始采集 · 并发=$concurrency · 匿名 · ${wifiOnly ? '仅WiFi' : '任意网络'} · ${forums.length} 吧');
    _publish();

    try {
      await Future.wait(<Future<void>>[
        for (final CollectionStateEntry e in forums) _drainForum(e, worker),
      ]);
    } finally {
      await worker.close();
    }
  }

  // ── 单吧分支 ───────────────────────────────────────────────────────────

  Future<void> _drainForum(CollectionStateEntry entry, PostWorker worker) async {
    final _ForumCtx ctx = _ForumCtx(entry, Watermark(entry.lastThreadTime, entry.lastTid));
    final List<ThreadSummary> queue = <ThreadSummary>[];
    try {
      // 冷却吧跳过启动（§8.11：48h 冷却，不影响其余吧）。
      final DateTime? cooldown = entry.cooldownUntil;
      if (cooldown != null && cooldown.isAfter(_clock.now())) {
        ctx.outcome = _ForumOutcome.skippedCooldown;
        _setForum(ctx.fname, (ForumRunState s) => s.copyWith(
              status: ForumStatus.cooldown,
              cooldownUntil: cooldown,
              stepDetail: '冷却至 ${_fmtTime(cooldown)}',
            ));
        _log(ctx.fname, '频控', '冷却中，不影响其余吧（至 ${_fmtTime(cooldown)}）',
            level: CollectLogLevel.warn);
        return;
      }

      _setForum(ctx.fname, (ForumRunState s) => s.copyWith(status: ForumStatus.listing));
      _log(ctx.fname, '开始', ctx.wmFrom.isCold
          ? '冷启动（水位=0），只回溯最近 $kColdStartListPages 页'
          : '水位 ${_fmtEpoch(ctx.wmFrom.lastThreadTime)} / last_tid=${ctx.wmFrom.lastTid}');

      // ── ① 拉帖列表（增量判定，§8.7 步骤 1-3） ──
      final int maxPages =
          ctx.wmFrom.isCold ? kColdStartListPages : kMaxListPages;
      bool missSeen = false; // 首个不命中出现后再扫完本页即停（容忍同秒并列）
      int pn = 0;
      while (pn < maxPages && !missSeen) {
        pn++;
        if (_cancelRequested) { ctx.outcome = _ForumOutcome.canceled; break; }
        if (_globalPaused) { ctx.outcome = _ForumOutcome.paused; break; }
        if (_budgetExhausted) { ctx.outcome = _ForumOutcome.budget; break; }
        final int pageNo = pn;
        _setForum(ctx.fname, (ForumRunState s) => s.copyWith(
              status: ForumStatus.listing,
              step: CollectStep.list,
              stepProgress: (pageNo - 1) / maxPages,
              stepDetail: 'pn $pageNo/$maxPages${ctx.wmFrom.isCold ? '（冷启动）' : ''}',
              overallProgress: 0.2 * (pageNo - 1) / maxPages,
            ));
        ThreadsPage page;
        try {
          page = await _callWithRetry(
            ctx,
            () => _api.getThreads(ctx.fname, pn: pageNo, rn: kThreadRn),
            describe: '列表 pn=$pageNo',
            maxAttempts: kListRetries,
          );
        } on _StopSignal catch (sig) {
          ctx.outcome = _mapStop(sig.reason);
          break;
        } on _CooldownSignal catch (sig) {
          ctx.outcome = _ForumOutcome.cooldown;
          ctx.failKind = sig.cause.kind;
          ctx.failMessage = '列表 ${sig.cause.message}';
          break;
        } on _PermFailSignal catch (sig) {
          ctx.outcome = _ForumOutcome.listFailed;
          ctx.failKind = sig.kind;
          ctx.failMessage = '列表 ${sig.message}';
          break;
        }
        if (page.fid > 0 && ctx.learnedFid != page.fid) {
          ctx.learnedFid = page.fid;
          // ForumRunState.copyWith 不含 fid（契约冻结）→ 手工全量重建。
          final int fid = page.fid;
          _setForum(ctx.fname, (ForumRunState s) => ForumRunState(
                fname: s.fname,
                fid: fid,
                status: s.status,
                step: s.step,
                stepProgress: s.stepProgress,
                stepDetail: s.stepDetail,
                overallProgress: s.overallProgress,
                watermarkFrom: s.watermarkFrom,
                watermarkTarget: s.watermarkTarget,
                cooldownUntil: s.cooldownUntil,
                error: s.error,
                stats: s.stats,
              ));
        }
        int hits = 0;
        for (final ThreadSummary t in page.threads) {
          // 置顶/删除/屏蔽帖不入队也**不算 miss**（置顶帖恒在首页页首且 create_time
          // 陈旧，若计 miss 会把增量扫描在第一页就截停——fetch_poc 候选口径同源）。
          if (t.isTop || t.isDeleted || t.isFrsMask) continue;
          if (isNewerThanWatermark(t, ctx.wmFrom)) {
            queue.add(t);
            hits++;
          } else {
            missSeen = true;
          }
        }
        final int maxSeen = queue.isEmpty
            ? ctx.wmFrom.lastThreadTime
            : queue.map((ThreadSummary t) => t.createTime).reduce(max);
        _setForum(ctx.fname, (ForumRunState s) => s.copyWith(
              stepProgress: pageNo / maxPages,
              overallProgress: 0.2 * pageNo / maxPages,
              watermarkTarget: maxSeen,
            ));
        _log(ctx.fname, '拉列表',
            'pn=$pageNo/$maxPages 本页 ${page.threads.length} 条 · 命中新帖 $hits${missSeen ? ' · 已见水位内帖，扫完本页即停' : ''}');
        if (!page.hasMore) break;
      }

      if (ctx.outcome != _ForumOutcome.completed) {
        // 列表阶段被停（取消/熔断/预算/冷却/失败）——queue 未处理。
        return;
      }

      // ── ②③ 待采队列按 create_time 升序逐帖（吧内串行，§8.7 步骤 4-5） ──
      sortQueueAscending(queue);
      await _processThreads(ctx, queue, worker);
    } catch (e) {
      ctx.outcome = _ForumOutcome.crashed;
      ctx.failMessage = '$e';
      _log(ctx.fname, '失败', '分支异常：$e', level: CollectLogLevel.warn);
    } finally {
      await _finishForum(ctx, queue);
    }
  }

  /// ②③ 线程循环：失败退避 30s×2ⁿ ≤3 次、**延迟重入队尾不阻塞**（§8.8）。
  Future<void> _processThreads(
      _ForumCtx ctx, List<ThreadSummary> queue, PostWorker worker) async {
    final int n = queue.length;
    final List<_ThreadTask> pending = <_ThreadTask>[
      for (final ThreadSummary t in queue) _ThreadTask(t, _clock.now()),
    ];
    final List<_ThreadTask> retries = <_ThreadTask>[];
    int processed = 0;
    while (true) {
      // 队列耗尽判定**先于**停止旗标：本吧工作已全部做完时正常收尾，
      // 不被并发分支触发的全局熔断/取消误伤（否则健康吧会被记 api_error）。
      if (pending.isEmpty && retries.isEmpty) return;
      if (_cancelRequested) { ctx.outcome = _ForumOutcome.canceled; return; }
      if (_globalPaused) { ctx.outcome = _ForumOutcome.paused; return; }
      if (_budgetExhausted) { ctx.outcome = _ForumOutcome.budget; return; }
      _ThreadTask task;
      if (pending.isNotEmpty) {
        task = pending.removeAt(0);
      } else if (retries.isNotEmpty) {
        retries.sort((_ThreadTask a, _ThreadTask b) => a.dueAt.compareTo(b.dueAt));
        final _ThreadTask next = retries.first;
        final Duration wait = next.dueAt.difference(_clock.now());
        if (wait > Duration.zero && !await _sleepCancelable(wait)) {
          ctx.outcome = _ForumOutcome.canceled;
          return;
        }
        if (_cancelRequested || _globalPaused || _budgetExhausted) continue;
        retries.removeAt(0);
        task = next;
      } else {
        return; // 防御性：循环顶部已判空，此分支不可达
      }

      final int k = (processed + 1).clamp(1, max(n, 1));
      final int tid = task.thread.tid;
      try {
        _setForum(ctx.fname, (ForumRunState s) => s.copyWith(
              status: ForumStatus.parsing,
              step: CollectStep.parse,
              stepProgress: n == 0 ? 1 : (k - 1) / n,
              stepDetail: 'tid $k/$n',
              overallProgress: 0.2 + 0.7 * (n == 0 ? 1 : (k - 1) / n),
            ));
        final ThreadRecord rec = await _fetchThreadOnce(ctx, task.thread);
        final ThreadAnalysis analysis = await worker.analyze(ThreadInput(
          tid: rec.tid,
          title: rec.title,
          author: rec.author,
          createTime: rec.createTime,
          floors: <FloorInput>[
            for (final FloorInfo f in rec.floors)
              FloorInput(pid: f.pid, seq: f.seq, text: f.text),
          ],
        ));
        if (analysis.kind == null) {
          // 日常闲聊：整帖丢弃不入库，仅日志计数（§8.9 处置表）。
          _addStats(ctx, const CollectStats(discardedChat: 1));
          _log(ctx.fname, '分类', 'tid=$tid → 日常（整帖丢弃，仅计数）');
          ctx.succeededTids.add(tid);
          ctx.forumFailures = 0;
          processed++;
          _publish();
          continue;
        }
        _log(ctx.fname, '分类',
            'tid=$tid → ${analysis.kind} (书名数=${analysis.booknames.length}'
            '${analysis.hitRules.isEmpty ? '' : '，规则:${analysis.hitRules.join(';')}'}'
            '${analysis.dictAnchor.isEmpty ? '' : '，锚点:${analysis.dictAnchor}'})');
        _setForum(ctx.fname, (ForumRunState s) => s.copyWith(
              status: ForumStatus.ingesting,
              step: CollectStep.ingest,
              stepProgress: n == 0 ? 1 : k / n,
              stepDetail: 'tid $k/$n',
              overallProgress: 0.2 + 0.7 * (n == 0 ? 1 : (k - 0.5) / n),
            ));
        final IngestResult r =
            await _ingest.ingestThread(rec, analysis, collectedAt: _clock.now());
        _addStats(
            ctx,
            CollectStats(
              threadsAdded: r.newPost ? 1 : 0,
              floorsAdded: r.floorsAdded,
              entriesAdded: r.entriesAdded,
              skippedDup: r.skippedDup,
              mineThreads:
                  (analysis.kind == PostKind.mine && r.newPost) ? 1 : 0,
            ));
        _log(ctx.fname, '入库',
            'tid=$tid ${r.newPost ? '+1帖 ' : '(重入) '}+${r.floorsAdded}楼'
            ' +${r.entriesAdded}书目 重复跳过${r.skippedDup}'
            '${r.postRefBackfilled > 0 ? ' 回填溯源${r.postRefBackfilled}' : ''}'
            '${rec.partial ? '（超长帖截断 partial）' : ''}',
            level: CollectLogLevel.ok);
        ctx.succeededTids.add(tid);
        ctx.forumFailures = 0;
        processed++;
        _publish();
      } on _StopSignal catch (sig) {
        ctx.outcome = _mapStop(sig.reason);
        return;
      } on BudgetExhaustedException catch (e) {
        _budgetExhausted = true;
        _banner ??= '今日请求预算已用完（≤${e.limit}），明日 0 点自动恢复';
        _log('全局', '频控', _banner!, level: CollectLogLevel.warn);
        ctx.outcome = _ForumOutcome.budget;
        return;
      } on CollectCanceledException {
        ctx.outcome = _ForumOutcome.canceled;
        return;
      } on GlobalPausedException {
        ctx.outcome = _ForumOutcome.paused;
        return;
      } on CollectRequestException catch (e) {
        // 单帖请求失败：退避重入队尾（§8.8「失败不阻塞队列」）。
        ctx.forumFailures++;
        if (ctx.forumFailures >= kForumFailureCooldown) {
          ctx.outcome = _ForumOutcome.cooldown;
          ctx.failKind = e.kind;
          ctx.failMessage = 'tid=$tid ${e.message}';
          _log(ctx.fname, '频控',
              '连续 ${ctx.forumFailures} 次失败 → 本吧冷却 48h（不影响其余吧）',
              level: CollectLogLevel.warn);
          return;
        }
        if (task.retries < kMaxThreadRetries) {
          task.retries++;
          final Duration backoff = retryBackoff(task.retries - 1);
          task.dueAt = _clock.now().add(backoff);
          retries.add(task);
          _log(ctx.fname, '频控',
              'tid=$tid 失败（${e.message}）→ ${backoff.inSeconds}s 后重试'
              '（第${task.retries}/$kMaxThreadRetries次，重入队尾）',
              level: CollectLogLevel.warn);
        } else {
          ctx.failedTids.add(tid);
          processed++;
          _log(ctx.fname, '失败', 'tid=$tid 重试耗尽（${e.message}），跳过该帖',
              level: CollectLogLevel.warn);
        }
        _publish();
      } catch (e) {
        // worker/入库等确定性失败：重试无益（分类器/DB 异常是 bug 不是网络抖动），
        // 直接记永久失败——水位前缀会停在该帖之前，下轮重入由幂等去重兜底。
        ctx.failedTids.add(tid);
        processed++;
        _log(ctx.fname, '失败', 'tid=$tid 处理失败：$e', level: CollectLogLevel.warn);
        _publish();
      }
    }
  }

  /// 单帖全部楼层（pn=1.. ≤20 页 rn=30 ASC；单次尝试，失败由任务循环重入队尾）。
  Future<ThreadRecord> _fetchThreadOnce(
      _ForumCtx ctx, ThreadSummary t) async {
    final List<FloorInfo> floors = <FloorInfo>[];
    final Set<int> seenPid = <int>{};
    String title = t.title;
    int authorId = t.authorId;
    String author = t.author;
    String authorUserName = '';
    int createTime = t.createTime;
    bool partial = false;
    for (int pn = 1; pn <= kMaxPostPages; pn++) {
      final PostsPage page = await _request(
          ctx.fname, () => _api.getPosts(t.tid, pn: pn, rn: kPostRn));
      ctx.forumFailures = 0; // 每页成功都清零（吧级连续失败口径）
      if (page.title.isNotEmpty) title = page.title;
      if (page.authorId != 0) authorId = page.authorId;
      if (page.author.isNotEmpty) author = page.author;
      if (page.authorUserName.isNotEmpty) authorUserName = page.authorUserName;
      if (page.createTime != 0) createTime = page.createTime;
      for (final FloorInfo f in page.floors) {
        if (f.pid == 0 || seenPid.add(f.pid)) floors.add(f);
      }
      if (!page.hasMore) break;
      if (pn == kMaxPostPages) partial = true; // 超长帖截断（§8.7 步骤 4）
    }
    floors.sort((FloorInfo a, FloorInfo b) => a.seq.compareTo(b.seq));
    return ThreadRecord(
      fname: ctx.fname,
      tid: t.tid,
      title: title,
      authorId: authorId,
      author: author,
      authorUserName: authorUserName,
      createTime: createTime,
      floors: floors,
      partial: partial,
    );
  }

  // ── ④ 收尾：水位推进 + 状态落库 + 汇总日志（§8.7 步骤 6） ─────────────

  Future<void> _finishForum(_ForumCtx ctx, List<ThreadSummary> queue) async {
    if (ctx.outcome == _ForumOutcome.skippedCooldown) return; // 跳过吧不落库
    final String fname = ctx.fname;
    Watermark? advance;
    String lastStatus;
    String? lastError;
    ForumStatus st;
    DateTime? cooldownUntil;
    bool clearCooldown = false;
    int consecutiveFailures = 0;
    String logEvent;
    CollectLogLevel logLevel = CollectLogLevel.info;

    switch (ctx.outcome) {
      case _ForumOutcome.canceled:
        // 取消 → 水位不动（§8.7：中断不推进，下轮重拉靠 UNIQUE 幂等去重）。
        lastStatus = 'canceled';
        st = ForumStatus.canceled;
        logEvent = '取消';
        logLevel = CollectLogLevel.warn;
      case _ForumOutcome.paused:
        // 全局熔断（连续 3 败 ≈ 接口变更/网络断）→ 水位不动（同取消口径，保守）。
        lastStatus = 'api_error';
        st = ForumStatus.failed;
        lastError = '全局熔断：连续请求失败（接口疑似变更）';
        logEvent = '失败';
        logLevel = CollectLogLevel.warn;
      case _ForumOutcome.cooldown:
        // 吧级冷却（§8.11：连续≥3 败 → cooldown_until=now+48h，
        // last_status=rate_limited(429/110xxx)/api_error）。
        // 水位推进到连续成功前缀（决策见 watermark.dart advancePrefix 注释）：
        // 前缀内各帖已单事务落库，推进不破坏幂等；不推进则 48h 后重拉已入库
        // 前缀、白耗预算。与取消/全局熔断（水位不动）语义不同：那是用户意图/
        // 接口疑似全挂，保守不推进。
        advance = _prefixAdvance(ctx, queue);
        lastStatus = ctx.failKind == CollectFailureKind.rateLimited
            ? 'rate_limited'
            : 'api_error';
        st = ForumStatus.cooldown;
        cooldownUntil = _clock.now().add(kForumCooldownDuration);
        consecutiveFailures = max(ctx.forumFailures, kForumFailureCooldown);
        lastError = ctx.failMessage;
        logEvent = '频控';
        logLevel = CollectLogLevel.warn;
      case _ForumOutcome.listFailed:
        lastStatus = ctx.failKind == CollectFailureKind.rateLimited
            ? 'rate_limited'
            : 'api_error';
        st = ForumStatus.failed;
        lastError = ctx.failMessage;
        consecutiveFailures = ctx.forumFailures;
        logEvent = '失败';
        logLevel = CollectLogLevel.warn;
      case _ForumOutcome.crashed:
        lastStatus = 'api_error';
        st = ForumStatus.failed;
        lastError = ctx.failMessage;
        logEvent = '失败';
        logLevel = CollectLogLevel.warn;
      case _ForumOutcome.budget:
        // 预算触顶 → 当日停止（§8.11），水位推进到连续成功前缀（已入库数据有效，
        // 明日续采不重复拉取）。
        advance = _prefixAdvance(ctx, queue);
        lastStatus = 'partial';
        st = ForumStatus.done;
        clearCooldown = true;
        logEvent = '频控';
        logLevel = CollectLogLevel.warn;
      case _ForumOutcome.skippedCooldown:
        // 不可达（入口已 return）；占位保证 switch 穷尽。
        lastStatus = 'rate_limited';
        st = ForumStatus.cooldown;
        logEvent = '频控';
      case _ForumOutcome.completed:
        advance = _prefixAdvance(ctx, queue);
        final bool allOk = ctx.failedTids.isEmpty;
        lastStatus = allOk ? 'ok' : 'partial';
        st = ForumStatus.done;
        clearCooldown = true;
        lastError = allOk
            ? null
            : '${ctx.failedTids.length} 帖重试耗尽，水位推进到连续成功前缀';
        logEvent = '完成';
        logLevel = allOk ? CollectLogLevel.ok : CollectLogLevel.warn;
    }

    final CollectStats stats = ctx.stats;
    await _repo.updateForumAfterRun(
      fname: fname,
      lastRunAt: _clock.now(),
      lastStatus: lastStatus,
      lastError: lastError,
      consecutiveFailures: consecutiveFailures,
      cooldownUntil: cooldownUntil,
      clearCooldown: clearCooldown,
      lastThreadTime: advance?.lastThreadTime,
      lastTid: advance?.lastTid,
      fid: ctx.learnedFid,
      addThreads: stats.threadsAdded,
      addFloors: stats.floorsAdded,
      addNewSinceVisit: stats.threadsAdded, // 首页红点（§8.7 步骤 6）
    );
    final String detail = <String>[
      '状态=$lastStatus',
      '+${stats.threadsAdded}帖 +${stats.floorsAdded}楼 +${stats.entriesAdded}书目',
      '重复跳过${stats.skippedDup} 丢弃闲聊${stats.discardedChat}',
      if (advance != null) '水位→${_fmtEpoch(advance.lastThreadTime)}/tid=${advance.lastTid}',
      if (lastError != null) 'err=$lastError',
    ].join(' · ');
    await _repo.appendLog(CollectionLogsCompanion.insert(
      fname: fname,
      runAt: _clock.now(),
      status: lastStatus,
      threadsAdded: Value<int>(stats.threadsAdded),
      floorsAdded: Value<int>(stats.floorsAdded),
      entriesAdded: Value<int>(stats.entriesAdded),
      skippedDup: Value<int>(stats.skippedDup),
      detail: Value<String?>(detail),
    ));
    _setForum(fname, (ForumRunState s) => s.copyWith(
          status: st,
          step: CollectStep.summary,
          stepProgress: st == ForumStatus.done ? 1 : s.stepProgress,
          overallProgress: st == ForumStatus.done ? 1 : s.overallProgress,
          stepDetail: st == ForumStatus.done
              ? (lastStatus == 'ok' ? '完成' : '部分完成（$lastStatus）')
              : (st == ForumStatus.cooldown && cooldownUntil != null
                  ? '冷却至 ${_fmtTime(cooldownUntil)}'
                  : (lastError ?? '')),
          cooldownUntil: cooldownUntil,
          error: lastError,
        ));
    _log(fname, logEvent, detail, level: logLevel);
    _publish();
  }

  /// partial 水位推进口径：按 create_time 升序的**连续成功前缀**
  /// （决策依据见 watermark.dart advancePrefix 注释）。
  Watermark? _prefixAdvance(_ForumCtx ctx, List<ThreadSummary> queue) =>
      advancePrefix(queue,
          (ThreadSummary t) => ctx.succeededTids.contains(t.tid), ctx.wmFrom);

  // ── 请求原语：闸门 + 全局限速 + 预算 + 全局熔断计数 ────────────────────

  Future<T> _request<T>(String fname, Future<T> Function() call) async {
    if (_cancelRequested) throw const CollectCanceledException();
    if (_globalPaused) throw const GlobalPausedException();
    if (_budgetExhausted) throw BudgetExhaustedException(budgetLimit);
    await _sem.acquire();
    try {
      await _limiter.throttle(); // 全局间隔 + 每日预算核算（触顶上抛）
      if (_cancelRequested) throw const CollectCanceledException();
      final T r = await call();
      _globalFailures = 0;
      return r;
    } on CollectRequestException {
      _globalFailures++;
      if (_globalFailures >= kGlobalFailurePause && !_globalPaused) {
        _globalPaused = true;
        _banner = kBannerApiBroken;
        _log('全局', '频控', '连续 $_globalFailures 次请求失败 → 整轮暂停',
            level: CollectLogLevel.warn);
        _publish();
      }
      rethrow;
    } finally {
      _sem.release();
    }
  }

  /// 原地退避重试（仅列表阶段用；线程任务的重试走「延迟重入队尾」）。
  Future<T> _callWithRetry<T>(
    _ForumCtx ctx,
    Future<T> Function() call, {
    required String describe,
    required int maxAttempts,
  }) async {
    CollectRequestException? last;
    for (int attempt = 0; attempt <= maxAttempts; attempt++) {
      if (attempt > 0) {
        final Duration d = retryBackoff(attempt - 1);
        _log(ctx.fname, '频控', '$describe 失败 → ${d.inSeconds}s 后重试'
            '（第$attempt/$maxAttempts次）', level: CollectLogLevel.warn);
        if (!await _sleepCancelable(d)) throw const _StopSignal(_StopReason.canceled);
      }
      try {
        final T v = await _request(ctx.fname, call);
        ctx.forumFailures = 0;
        return v;
      } on BudgetExhaustedException {
        _budgetExhausted = true;
        _banner ??= '今日请求预算已用完（≤$budgetLimit），明日 0 点自动恢复';
        throw const _StopSignal(_StopReason.budget);
      } on CollectCanceledException {
        throw const _StopSignal(_StopReason.canceled);
      } on GlobalPausedException {
        throw const _StopSignal(_StopReason.paused);
      } on CollectRequestException catch (e) {
        last = e;
        ctx.forumFailures++;
        _log(ctx.fname, '频控', '$describe 失败（${e.message}），本吧连续 ${ctx.forumFailures} 次',
            level: CollectLogLevel.warn);
        if (ctx.forumFailures >= kForumFailureCooldown) throw _CooldownSignal(e);
        if (attempt >= maxAttempts) {
          throw _PermFailSignal('$describe: ${e.message}', e.kind);
        }
      }
    }
    throw _PermFailSignal('$describe: ${last?.message ?? "未知错误"}',
        last?.kind ?? CollectFailureKind.network);
  }

  /// 可取消睡眠：返回 false = 睡眠期间收到取消。
  Future<bool> _sleepCancelable(Duration d) async {
    if (d <= Duration.zero) return !_cancelRequested;
    final Completer<void>? cancel = _cancelCompleter;
    if (cancel != null) {
      await Future.any<void>(<Future<void>>[
        _sleeper(d),
        cancel.future,
      ]);
    } else {
      await _sleeper(d);
    }
    return !_cancelRequested;
  }

  _ForumOutcome _mapStop(_StopReason reason) => switch (reason) {
        _StopReason.canceled => _ForumOutcome.canceled,
        _StopReason.paused => _ForumOutcome.paused,
        _StopReason.budget => _ForumOutcome.budget,
      };

  // ── 状态发布（不可变快照；logs 新在前 cap 200 = collection_logs 口径） ──

  void _log(
    String fname,
    String event,
    String detail, {
    CollectLogLevel level = CollectLogLevel.info,
  }) {
    final CollectLogEntry entry = CollectLogEntry(
      time: _clock.now(),
      fname: fname,
      event: event,
      detail: detail,
      level: level,
    );
    _logs.insert(0, entry);
    if (_logs.length > kCollectionLogLimit) {
      _logs.removeRange(kCollectionLogLimit, _logs.length);
    }
    onLog?.call(entry);
    _publish();
  }

  /// 计数累计并同步进运行态快照（stats 是 UI stat-grid 数据源）。
  void _addStats(_ForumCtx ctx, CollectStats delta) {
    ctx.stats = ctx.stats + delta;
    final CollectStats stats = ctx.stats;
    _setForum(ctx.fname, (ForumRunState s) => s.copyWith(stats: stats));
  }

  void _setForum(String fname, ForumRunState Function(ForumRunState) f) {
    final ForumRunState? cur = _forumStates[fname];
    if (cur == null) return;
    _forumStates[fname] = f(cur);
    _publish();
  }

  void _publish() {
    final List<ForumRunState> forums =
        _forumStates.values.toList(growable: false);
    final CollectStats totals = forums.fold<CollectStats>(
        const CollectStats.zero(), (CollectStats s, ForumRunState f) => s + f.stats);
    final List<ForumRunState> active = forums
        .where((ForumRunState f) => const <ForumStatus>{
              ForumStatus.queued,
              ForumStatus.listing,
              ForumStatus.parsing,
              ForumStatus.ingesting,
            }.contains(f.status))
        .toList();
    // 契约口径：未完成吧的最小 step；全部完成 = summary；从未运行（无吧记录）= null。
    final CollectStep? globalStep = forums.isEmpty
        ? null
        : (active.isEmpty
            ? CollectStep.summary
            : active
                .map((ForumRunState f) => f.step)
                .reduce((CollectStep a, CollectStep b) =>
                    a.index <= b.index ? a : b));
    final double overall = forums.isEmpty
        ? 0
        : forums.fold<double>(0, (double s, ForumRunState f) => s + f.overallProgress) /
            forums.length;
    _onState(CollectRunState(
      phase: _phase,
      startedAt: _startedAt,
      forums: forums,
      logs: List<CollectLogEntry>.unmodifiable(_logs),
      totals: totals,
      overallProgress: overall.clamp(0.0, 1.0),
      globalStep: globalStep,
      banner: _banner,
      finishedAt: _finishedAt,
    ));
  }

  String _fmtEpoch(int epochSec) =>
      epochSec == 0 ? '0（冷启动）' : beijingTimeStr(epochSec);

  String _fmtTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }
}

/// 调试输出钩子（默认 print 到 debug 控制台；测试可静默）。
void Function(String) debugPrintCollect = (String s) {};

/// repo → [BudgetStore] 适配（settings 两键持久计数，§8.11 本地计数口径）。
class _RepoBudgetStore implements BudgetStore {
  const _RepoBudgetStore(this._repo);

  final CollectRepository _repo;

  @override
  Future<String?> read(String key) => _repo.getSetting(key);

  @override
  Future<void> write(String key, String value) => _repo.setSetting(key, value);
}

