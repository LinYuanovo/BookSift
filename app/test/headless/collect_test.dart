// headless 采集驱动测试（collect.dart）。
//
// plain test()：碰 drift + isolate/假 API 的真实事件循环，TESTING.md §1 禁止进 testWidgets。
//
// **零网络**：run() 用 test/collector/support.dart 的 FakeTiebaApi（未脚本化的调用
// 一律返回空页），验证的是「接线」而非采集算法——算法本身由 test/collector/service_test.dart 覆盖。
//
// 覆盖：plan 的吧筛选（停用/冷却）与预算读取 / run 的日志桥接（逐条不受 200 上限）/
// CollectRunResult 三件套 / 请求确实发出（否则 plan→run 的闸门形同虚设）。

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/collector/collect_settings_keys.dart';
import 'package:booksift/collector/collect_state.dart';
import 'package:booksift/collector/worker.dart';
import 'package:booksift/collector/scheduler.dart';
import 'package:booksift/collector/tieba/src/models.dart';
import 'package:booksift/collector/tieba_api.dart';
import 'package:booksift/core/constants.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/collect_repository.dart';
import 'package:booksift/headless/collect.dart';
import 'package:booksift/headless/env.dart';
import 'package:booksift/headless/logs.dart';
import 'package:booksift/headless/network_gate.dart';
import 'package:booksift/headless/query.dart';

import '../collector/support.dart';

/// 直接写 collection_state.cooldown_until（仓库无该字段的 setter）。
Future<void> setCooldown(AppDatabase db, String fname, DateTime until) =>
    (db.update(db.collectionState)..where((CollectionState t) => t.fname.equals(fname)))
        .write(CollectionStateCompanion(cooldownUntil: Value<DateTime?>(until)));

Future<bool> _notWifi() async => false;

void main() {
  late AppDatabase db;
  late CollectRepository repo;
  late MemoryRunLogSink mem;
  late RunLog log;

  setUp(() {
    db = HeadlessEnv.openMemoryDb();
    repo = CollectRepository(db);
    mem = MemoryRunLogSink();
    log = RunLog(runId: 'test-run', sinks: <RunLogSink>[mem]);
  });

  tearDown(() async {
    await log.close();
    await db.close();
  });

  group('plan（零请求）', () {
    test('空库：无关注吧，预算/并发取缺省', () async {
      final CollectPlan plan = await HeadlessCollect.plan(db: db);
      expect(plan.forums, isEmpty);
      expect(plan.enabledForums, isEmpty);
      expect(plan.coolingForums, isEmpty);
      expect(plan.budgetLimit, kDailyBudgetAnonymous);
      expect(plan.budgetUsed, 0);
      expect(plan.budgetRemaining, kDailyBudgetAnonymous);
      expect(plan.concurrentForums, 2);
      expect(plan.wifiOnly, isTrue);
    });

    test('播种后两吧可跑；停用吧不进 enabledForums', () async {
      await repo.seedDefaultsIfEmpty();
      expect(
        (await HeadlessCollect.plan(db: db)).enabledForums,
        kDefaultForums,
      );

      await repo.setForumEnabled(kDefaultForums.first, false);
      final CollectPlan plan = await HeadlessCollect.plan(db: db);
      expect(plan.enabledForums, <String>[kDefaultForums.last]);
      // 停用 ≠ 冷却：不该出现在冷却列表里，否则会误导排错。
      expect(plan.coolingForums, isEmpty);
      expect(plan.forums, hasLength(2), reason: '水位仍要全量透出');
    });

    test('forumFilter 只返回所选吧的计划与水位', () async {
      await repo.seedDefaultsIfEmpty();
      await repo.addForum('额外吧');

      final CollectPlan plan = await HeadlessCollect.plan(
        db: db,
        forumFilter: <String>['额外吧'],
      );

      expect(plan.forums.map((ForumWatermark f) => f.fname), <String>['额外吧']);
      expect(plan.enabledForums, <String>['额外吧']);
    });

    test('冷却中的吧进 coolingForums，过期冷却不算冷却', () async {
      await repo.addForum('冷吧');
      await repo.addForum('已解冻吧');
      final DateTime now = DateTime.now();
      await setCooldown(db, '冷吧', now.add(const Duration(minutes: 30)));
      await setCooldown(db, '已解冻吧', now.subtract(const Duration(minutes: 1)));

      final CollectPlan plan = await HeadlessCollect.plan(db: db);
      expect(plan.coolingForums, <String>['冷吧']);
      expect(plan.enabledForums, <String>['已解冻吧']);
    });

    test('预算/并发/仅WiFi 从 settings 读出', () async {
      await repo.setSetting(CollectSettingsKeys.budgetDate, '2026-10-13');
      await repo.setSetting(CollectSettingsKeys.budgetCount, '120');
      await repo.setSetting(SettingsKeys.concurrentForums, '3');
      await repo.setSetting(SettingsKeys.wifiOnly, 'true');

      final CollectPlan plan = await HeadlessCollect.plan(db: db, budgetLimit: 300);
      expect(plan.budgetDate, '2026-10-13');
      expect(plan.budgetUsed, 120);
      expect(plan.budgetRemaining, 180);
      expect(plan.concurrentForums, 3);
      expect(plan.wifiOnly, isTrue);
    });

    test('仅WiFi 旧值与关闭值和采集服务解析一致', () async {
      for (final String value in <String>['0', 'false']) {
        await repo.setSetting(SettingsKeys.wifiOnly, value);
        expect((await HeadlessCollect.plan(db: db)).wifiOnly, isFalse);
      }
      for (final String value in <String>['1', 'true']) {
        await repo.setSetting(SettingsKeys.wifiOnly, value);
        expect((await HeadlessCollect.plan(db: db)).wifiOnly, isTrue);
      }
    });

    test('budgetRemaining 不会为负（超支时夹到 0）', () async {
      await repo.setSetting(CollectSettingsKeys.budgetCount, '9999');
      final CollectPlan plan = await HeadlessCollect.plan(db: db, budgetLimit: 300);
      expect(plan.budgetRemaining, 0);
    });

    test('plan.toJson 含限速区间，便于 agent 判断本轮耗时量级', () {
      final Map<String, Object?> j =
          CollectPlan(
            forums: const <ForumWatermark>[],
            enabledForums: const <String>[],
            coolingForums: const <String>[],
            budgetDate: null,
            budgetUsed: 0,
            budgetLimit: 8,
            concurrentForums: 2,
            wifiOnly: false,
          ).toJson();
      expect(j['minIntervalMs'], kMinIntervalMs);
      expect(j['maxIntervalMs'], kMaxIntervalMs);
      expect((j['budget'] as Map)['remaining'], 8);
    });
  });

  group('run（假 API，零真实网络）', () {
    test('仅 WiFi 开启且网络不是 WiFi 时不会调用 API', () async {
      await repo.addForum('yy小说吧');
      final FakeClock clock = FakeClock();
      final FakeTiebaApi api = FakeTiebaApi(clock, holdTicks: 0);
      final CollectRunResult result = await HeadlessCollect.run(
        db: db,
        log: log,
        dictLines: const <String>[],
        api: api,
        useIsolateWorker: false,
        clock: clock,
        sleeper: fakeSleeper(clock),
        networkGate: const HostNetworkGate(wifiProbe: _notWifi),
      );

      expect(api.calls, isEmpty);
      expect(result.summary.banner, contains('当前非 WiFi'));
      expect(result.summary.networkGateBlocked, isTrue);
    });

    test('列表请求连续失败时摘要标记 failed', () async {
      await repo.addForum('失败吧');
      final FakeClock clock = FakeClock();
      final FakeTiebaApi api = FakeTiebaApi(clock, holdTicks: 0)
        ..failThreads('失败吧', errServer(), times: -1);

      final CollectRunResult result = await HeadlessCollect.run(
        db: db,
        log: log,
        dictLines: const <String>[],
        api: api,
        useIsolateWorker: false,
        clock: clock,
        sleeper: fakeSleeper(clock),
        networkGate: const AlwaysAllowNetworkGate(),
      );

      expect(result.summary.failed, isTrue);
      expect(result.summary.networkGateBlocked, isFalse);
      expect(result.summary.forums.single['status'], 'cooldown');
    });

    test('已在冷却期的贴吧正常跳过，不将成功运行标为 failed', () async {
      await repo.addForum('冷却吧');
      await repo.addForum('正常吧');
      await setCooldown(db, '冷却吧', DateTime.now().add(const Duration(hours: 1)));
      final FakeClock clock = FakeClock();
      final FakeTiebaApi api = FakeTiebaApi(clock, holdTicks: 0);

      final CollectRunResult result = await HeadlessCollect.run(
        db: db,
        log: log,
        dictLines: const <String>[],
        api: api,
        useIsolateWorker: false,
        clock: clock,
        sleeper: fakeSleeper(clock),
        networkGate: const AlwaysAllowNetworkGate(),
      );

      expect(api.calls.map((ApiCall call) => call.forum).toSet(), <String>{'正常吧'});
      expect(result.summary.failed, isFalse);
      expect(
        result.summary.forums.singleWhere((Map<String, Object?> forum) => forum['fname'] == '冷却吧')['error'],
        isNull,
      );
    });

    test('forumFilter 在实际采集中只调用所选贴吧', () async {
      await repo.addForum('目标吧');
      await repo.addForum('其他吧');
      final FakeClock clock = FakeClock();
      final FakeTiebaApi api = FakeTiebaApi(clock, holdTicks: 0);

      final CollectRunResult result = await HeadlessCollect.run(
        db: db,
        log: log,
        dictLines: const <String>[],
        api: api,
        useIsolateWorker: false,
        clock: clock,
        sleeper: fakeSleeper(clock),
        networkGate: const AlwaysAllowNetworkGate(),
        forumFilter: const <String>['目标吧'],
      );

      expect(api.calls.map((ApiCall call) => call.forum).toSet(), <String>{'目标吧'});
      expect(result.summary.forums.map((Map<String, Object?> f) => f['fname']), <Object?>['目标吧']);
    });

    test('空页跑通：日志逐条桥接到 RunLog，汇总事件带全量计数', () async {
      await repo.addForum('yy小说吧');
      final FakeClock clock = FakeClock();
      final FakeTiebaApi api = FakeTiebaApi(clock, holdTicks: 0);

      final CollectRunResult result = await HeadlessCollect.run(
        db: db,
        log: log,
        dictLines: const <String>[],
        api: api,
        budgetLimit: 8,
        useIsolateWorker: false,
        clock: clock,
        sleeper: fakeSleeper(clock),
        networkGate: const AlwaysAllowNetworkGate(),
      );

      // 真的发过请求（否则「跑了一轮」是假的）。
      expect(api.calls, isNotEmpty);
      expect(api.calls.first.key, contains('threads:yy小说吧'));
      // 请求数受预算约束。
      expect(api.calls.length, lessThanOrEqualTo(8));

      // 逐条日志确实经 onLog 落到 RunLog（不是只躺在 200 条上限的快照里）。
      final List<RunEvent> collectEvents =
          mem.events.where((RunEvent e) => e.data['src'] == 'collect').toList();
      expect(collectEvents, isNotEmpty);
      expect(result.logCount, collectEvents.length);

      // 汇总事件存在且携带机读摘要。
      final RunEvent summary =
          mem.events.lastWhere((RunEvent e) => e.event == '汇总');
      expect(summary.data['phase'], isNotNull);
      expect(summary.data['totals'], isA<Map<String, int>>());
      expect(summary.data['logCount'], result.logCount);

      // 整轮收尾回到 idle。
      expect(result.state.phase, CollectPhase.idle);
      expect(result.summary.phase, 'idle');
      expect(result.summary.forums, hasLength(1));
      expect(result.summary.forums.single['fname'], 'yy小说吧');
    });

    test('进度事件按「相位/步骤」变化去重，不逐快照刷屏', () async {
      await repo.addForum('yy小说吧');
      final FakeClock clock = FakeClock();
      final FakeTiebaApi api = FakeTiebaApi(clock, holdTicks: 0);

      await HeadlessCollect.run(
        db: db,
        log: log,
        dictLines: const <String>[],
        api: api,
        budgetLimit: 8,
        useIsolateWorker: false,
        clock: clock,
        sleeper: fakeSleeper(clock),
        networkGate: const AlwaysAllowNetworkGate(),
      );

      final List<RunEvent> progress =
          mem.events.where((RunEvent e) => e.event == '进度').toList();
      expect(progress, isNotEmpty);
      // 去重的判据是签名串，签名相同的相邻快照不应重复记录。
      final List<String> sigs = progress
          .map((RunEvent e) => '${e.data['phase']}|${e.data['overallProgress']}')
          .toList();
      expect(sigs.length, greaterThanOrEqualTo(1));
      for (final RunEvent e in progress) {
        expect(e.data['forums'], isA<List<Object?>>());
      }
    });

    test('注入的 api 不会被当成自持有资源关掉（所有权归调用方）', () async {
      await repo.addForum('yy小说吧');
      final FakeClock clock = FakeClock();
      final FakeTiebaApi api = FakeTiebaApi(clock, holdTicks: 0);

      await HeadlessCollect.run(
        db: db,
        log: log,
        dictLines: const <String>[],
        api: api,
        useIsolateWorker: false,
        clock: clock,
        sleeper: fakeSleeper(clock),
        networkGate: const AlwaysAllowNetworkGate(),
      );
      expect(api.closed, isFalse, reason: '只有 run() 自己 new 的 ProtoTiebaApi 才由它关');
    });
  });

  group('bduss 档（需求 5：间隔 1.0–2.0s / 并发上限 4 / 预算 600）', () {
    test('plan：间隔与并发按账号档取，toJson 带 accountTier', () async {
      await repo.setSetting(SettingsKeys.concurrentForums, '4');

      final CollectPlan anon = await HeadlessCollect.plan(db: db, budgetLimit: 300);
      expect(anon.concurrentForums, 3, reason: '匿名档上限 3（同一存储值 4）');
      expect(anon.minIntervalMs, kMinIntervalMs);
      expect(anon.maxIntervalMs, kMaxIntervalMs);
      expect(anon.toJson()['accountTier'], 'anonymous');
      expect(anon.toJson()['minIntervalMs'], kMinIntervalMs);

      final CollectPlan bd = await HeadlessCollect.plan(
          db: db, budgetLimit: kDailyBudgetBduss, bduss: 'FAKE_Bduss_not_null');
      expect(bd.concurrentForums, 4, reason: 'BDUSS 档上限 4');
      expect(bd.minIntervalMs, kMinIntervalBdussMs);
      expect(bd.maxIntervalMs, kMaxIntervalBdussMs);
      expect(bd.toJson()['accountTier'], 'bduss');
      expect(bd.toJson()['maxIntervalMs'], kMaxIntervalBdussMs);
    });

    test('run：注入 api 时 bduss 只改档位（不建真客户端）；实际间隔落在 1.0–2.0s', () async {
      await repo.addForum('yy小说吧');
      final FakeClock clock = FakeClock();
      final FakeTiebaApi api = FakeTiebaApi(clock, holdTicks: 0);
      // 1 帖 → 2 个请求（列表 + 楼层），间隔可观测。
      api.scriptThreads(
          'yy小说吧',
          1,
          ThreadsPage(
            fid: 42,
            threads: <ThreadSummary>[mkThread(tid: 999, createTime: 300)],
            hasMore: false,
          ));
      api.scriptPosts(999, 1, mkPostsPage(999), forum: 'yy小说吧');

      final CollectRunResult result = await HeadlessCollect.run(
        db: db,
        log: log,
        dictLines: const <String>[],
        api: api,
        budgetLimit: kDailyBudgetBduss,
        bduss: 'FAKE_Bduss_not_null',
        networkGate: const AlwaysAllowNetworkGate(),
        useIsolateWorker: false,
        clock: clock,
        sleeper: fakeSleeper(clock),
      );

      expect(api.closed, isFalse, reason: '注入的 api 仍归调用方所有');
      expect(api.calls, hasLength(2));
      final int gap = api.calls[1].startedAt.difference(api.calls[0].startedAt).inMilliseconds;
      expect(gap, greaterThanOrEqualTo(kMinIntervalBdussMs));
      expect(gap, lessThanOrEqualTo(kMaxIntervalBdussMs));
      expect(result.summary.phase, 'idle');
    });
  });

  group('CollectRunSummary', () {
    test('把 CollectRunState 投影成机读结构，计数六项齐全', () {
      const CollectRunState s = CollectRunState(
        phase: CollectPhase.idle,
        totals: CollectStats(threadsAdded: 3, floorsAdded: 21, entriesAdded: 9),
        banner: '贴吧接口似乎已变更',
      );
      final CollectRunSummary sum = CollectRunSummary.of(s, logCount: 42);
      final Map<String, Object?> j = sum.toJson();

      expect(j['phase'], 'idle');
      expect(j['banner'], '贴吧接口似乎已变更');
      expect(j['logCount'], 42);
      expect(j['totals'], <String, int>{
        'threadsAdded': 3,
        'floorsAdded': 21,
        'entriesAdded': 9,
        'skippedDup': 0,
        'discardedChat': 0,
        'mineThreads': 0,
      });
    });

    test('失败状态在机读摘要中显式标记', () {
      const CollectRunState state = CollectRunState(
        forums: <ForumRunState>[
          ForumRunState(
            fname: '失败吧',
            status: ForumStatus.failed,
            error: '列表请求失败',
          ),
        ],
      );
      final CollectRunSummary summary =
          CollectRunSummary.of(state, logCount: 1, failed: true);

      expect(summary.failed, isTrue);
      expect(summary.networkGateBlocked, isFalse);
      expect(summary.toJson()['failed'], isTrue);
    });
  });
}
