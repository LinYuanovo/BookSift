/// 采集服务集成测试（plain test() + 内存库 + 假时钟 + 脚本化假 API）。
/// 覆盖 §8.7 增量流程 / §8.8 并发模型 / §8.11 频控 / §8.12 降级 的验收点。
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/collector/collect_service.dart';
import 'package:booksift/collector/collect_settings_keys.dart';
import 'package:booksift/collector/collect_state.dart';
import 'package:booksift/collector/scheduler.dart';
import 'package:booksift/collector/tieba/src/models.dart';
import 'package:booksift/collector/tieba_api.dart';
import 'package:booksift/core/constants.dart';
import 'package:booksift/data/db/app_database.dart';

import 'support.dart';

/// 直接改水位（模拟既有采集进度；updateForumAfterRun 绝对值语义）。
Future<void> setWatermark(TestEnv env, String fname,
        {required int time, required int tid}) =>
    env.repo.updateForumAfterRun(
      fname: fname,
      lastRunAt: env.clock.now(),
      lastStatus: 'ok',
      lastThreadTime: time,
      lastTid: tid,
    );

void scriptThreadPage(TestEnv env, String fname, int pn,
        {required List<ThreadSummary> threads, bool hasMore = false, int fid = 555}) =>
    env.api.scriptThreads(
        fname, pn, ThreadsPage(fid: fid, threads: threads, hasMore: hasMore));

void scriptPost(TestEnv env, int tid, String fname,
        {String? title, String? floorText, bool hasMore = false}) =>
    env.api.scriptPosts(tid, 1,
        mkPostsPage(tid, title: title ?? '', floorText: floorText, hasMore: hasMore),
        forum: fname);

List<int> postsCallTids(TestEnv env) => <int>[
      for (final ApiCall c in env.api.calls.where((ApiCall c) => !c.isThreads))
        int.parse(c.key.split(':')[1]),
    ];

void main() {
  group('仅 Wi-Fi 网络门控', () {
    test('非 Wi-Fi 时不发请求、不移动水位并显示暂停说明', () async {
      final TestEnv env = await TestEnv.create(
        forums: <String>['网络测试吧'],
        wifiAvailable: false,
      );
      addTearDown(env.dispose);

      await env.service.run();

      expect(env.api.calls, isEmpty);
      final CollectionStateEntry forum = (await env.repo.forum('网络测试吧'))!;
      expect(forum.lastThreadTime, 0);
      expect(env.last.banner, contains('当前非 WiFi'));
    });

    test('关闭仅 Wi-Fi 后允许非 Wi-Fi 网络采集', () async {
      final TestEnv env = await TestEnv.create(
        forums: <String>['网络测试吧'],
        wifiAvailable: false,
      );
      addTearDown(env.dispose);
      await env.repo.setSetting(SettingsKeys.wifiOnly, 'false');
      scriptThreadPage(env, '网络测试吧', 1, threads: const <ThreadSummary>[]);

      await env.service.run();

      expect(env.api.calls, hasLength(1));
      expect(env.last.banner, isNull);
    });

    test('运行中切离 Wi-Fi：不再发请求、不计预算、不推进水位', () async {
      final TestEnv env = await TestEnv.create(forums: <String>['网络测试吧']);
      addTearDown(env.dispose);
      scriptThreadPage(env, '网络测试吧', 1, threads: <ThreadSummary>[
        mkThread(tid: 9001, createTime: 100),
      ]);
      scriptPost(env, 9001, '网络测试吧');
      env.api.afterRequest = (int n) {
        if (n == 1) env.networkGate.wifiAvailable = false;
      };

      await env.service.run();

      expect(env.api.calls, hasLength(1), reason: '列表请求后断网，不应再发楼层请求');
      expect(await env.repo.getSetting(CollectSettingsKeys.budgetCount), '1');
      expect(env.last.banner, contains('当前非 WiFi'));
      expect(env.last.forums.single.status, ForumStatus.canceled);
      final CollectionStateEntry state = (await env.repo.forum('网络测试吧'))!;
      expect(state.lastThreadTime, 0);
      expect(state.lastStatus, 'canceled');
    });
  });

  group('§8.8 并发模型', () {
    test('跨吧并发 ≤2（默认）、吧内严格串行、全局间隔 ≥1.5s', () async {
      final TestEnv env = await TestEnv.create(
          forums: <String>['A吧', 'B吧', 'C吧']);
      addTearDown(env.dispose);
      const List<String> fnames = <String>['A吧', 'B吧', 'C吧'];
      for (int i = 0; i < fnames.length; i++) {
        final String f = fnames[i];
        final int t1 = (i + 1) * 100 + 1;
        final int t2 = (i + 1) * 100 + 2;
        scriptThreadPage(env, f, 1, threads: <ThreadSummary>[
          mkThread(tid: t1, createTime: 300 + i),
          mkThread(tid: t2, createTime: 200 + i),
        ], fid: 10 + i);
        scriptPost(env, t1, f);
        scriptPost(env, t2, f);
      }

      await env.service.run();

      expect(env.api.maxActive, lessThanOrEqualTo(2), reason: '总并发默认 2');
      expect(env.api.maxActive, greaterThanOrEqualTo(2),
          reason: '3 吧 2 闸门应实际出现并发在途');
      expect(env.api.maxActiveSameForum, 1, reason: '吧内任意时刻仅一个在途请求');
      // 全局单限速器：相邻请求启动间隔 ≥1.5s（§8.11 匿名档下沿）
      final List<ApiCall> sorted = env.api.calls.toList()
        ..sort((ApiCall a, ApiCall b) => a.startedAt.compareTo(b.startedAt));
      for (int i = 1; i < sorted.length; i++) {
        expect(
          sorted[i].startedAt.difference(sorted[i - 1].startedAt).inMilliseconds,
          greaterThanOrEqualTo(kMinIntervalMs),
          reason: '全局间隔核算（calls: ${sorted.map((ApiCall c) => c.key).toList()}）',
        );
      }
      expect(env.api.calls.length, 9); // 3 列表 + 6 帖
      // 预算本地计数与请求数一致
      expect(await env.repo.getSetting(CollectSettingsKeys.budgetCount), '9');
      expect(env.last.phase, CollectPhase.idle);
      expect(env.last.totals.threadsAdded, 6);
      for (final ForumRunState fs in env.last.forums) {
        expect(fs.status, ForumStatus.done);
        expect(fs.fid, isNotNull, reason: '列表响应带回 fid 落运行态');
      }
    });

    test('concurrent_forums=5 → 钳制到上限 3', () async {
      final TestEnv env = await TestEnv.create(
          forums: <String>['A吧', 'B吧', 'C吧', 'D吧'], concurrency: 5);
      addTearDown(env.dispose);
      for (int i = 0; i < 4; i++) {
        final String f = '${'ABCD'[i]}吧';
        final int t1 = (i + 1) * 100 + 1;
        scriptThreadPage(env, f, 1,
            threads: <ThreadSummary>[mkThread(tid: t1, createTime: 300)]);
        scriptPost(env, t1, f);
      }
      await env.service.run();
      expect(env.api.maxActive, lessThanOrEqualTo(3));
      expect(env.api.maxActiveSameForum, 1);
    });
  });

  group('§8.7 水位机制', () {
    test('整批成功 → 推进到 (max create_time, 对应 tid)，红点/累计同步', () async {
      final TestEnv env = await TestEnv.create(forums: <String>['yy小说吧']);
      addTearDown(env.dispose);
      scriptThreadPage(env, 'yy小说吧', 1, threads: <ThreadSummary>[
        mkThread(tid: 1003, createTime: 300),
        mkThread(tid: 1002, createTime: 200),
        mkThread(tid: 1001, createTime: 100),
      ]);
      for (final int tid in <int>[1001, 1002, 1003]) {
        scriptPost(env, tid, 'yy小说吧');
      }
      await env.service.run();

      final CollectionStateEntry s = (await env.repo.forum('yy小说吧'))!;
      expect(s.lastThreadTime, 300);
      expect(s.lastTid, 1003);
      expect(s.lastStatus, 'ok');
      expect(s.lastError, isNull);
      expect(s.consecutiveFailures, 0);
      expect(s.cooldownUntil, isNull);
      expect(s.newSinceVisit, 3, reason: '首页红点 += threadsAdded');
      expect(s.totalThreads, 3);
      expect(s.totalFloors, 3);
      expect(s.lastRunAt, isNotNull);
      expect(s.fid, 555);
      // 待采队列按 create_time 升序处理
      expect(postsCallTids(env), <int>[1001, 1002, 1003]);
    });

    test('取消 → 水位不动，已提交的帖保留（幂等重拉兜底）', () async {
      final TestEnv env = await TestEnv.create(forums: <String>['yy小说吧']);
      addTearDown(env.dispose);
      scriptThreadPage(env, 'yy小说吧', 1, threads: <ThreadSummary>[
        mkThread(tid: 2002, createTime: 200),
        mkThread(tid: 2001, createTime: 100),
      ]);
      scriptPost(env, 2001, 'yy小说吧');
      scriptPost(env, 2002, 'yy小说吧');
      env.api.afterRequest = (int n) {
        if (n == 2) env.service.requestCancel(); // T1 楼层返回后即取消
      };
      await env.service.run();

      final CollectionStateEntry s = (await env.repo.forum('yy小说吧'))!;
      expect(s.lastThreadTime, 0, reason: '取消 → 水位不动（§8.7）');
      expect(s.lastTid, 0);
      expect(s.lastStatus, 'canceled');
      expect(await env.db.posts.count().getSingle(), 1,
          reason: '取消前已提交的 T1 保留');
      expect(env.last.forums.single.status, ForumStatus.canceled);
      expect(env.last.phase, CollectPhase.idle);
      expect(env.snapshots.any((CollectRunState st) =>
          st.phase == CollectPhase.stopping), isTrue,
          reason: 'phase 经过 stopping');
    });

    test('partial：坏帖不永久卡死——前缀推进 + 后续帖照常入库', () async {
      // 坏帖在队列中间（S0@100, 坏@200, S2@300）：水位推进到连续成功前缀 S0；
      // S2 已入库但水位不越过坏帖（下轮重拉由 UNIQUE 幂等跳过）。
      final TestEnv env = await TestEnv.create(
          forums: <String>['yy小说吧'], classifier: crashingClassify);
      addTearDown(env.dispose);
      scriptThreadPage(env, 'yy小说吧', 1, threads: <ThreadSummary>[
        mkThread(tid: 303, createTime: 300),
        mkThread(tid: 302, createTime: 200, title: '坏帖：分类器会炸'),
        mkThread(tid: 301, createTime: 100),
      ]);
      for (final int tid in <int>[301, 302, 303]) {
        scriptPost(env, tid, 'yy小说吧');
      }
      await env.service.run();

      final CollectionStateEntry s = (await env.repo.forum('yy小说吧'))!;
      expect(s.lastThreadTime, 100, reason: '前缀停在坏帖之前');
      expect(s.lastTid, 301);
      expect(s.lastStatus, 'partial');
      expect(s.lastError, contains('重试耗尽'));
      final List<int> tids = (await env.db.select(env.db.posts).get())
          .map((Post p) => p.tid!)
          .toList()
        ..sort();
      expect(tids, <int>[301, 303], reason: '坏帖之后的 S2 照常入库');
      expect(env.last.forums.single.status, ForumStatus.done);
    });

    test('坏帖在队首 → 水位不动但其余帖全部入库', () async {
      final TestEnv env = await TestEnv.create(
          forums: <String>['yy小说吧'], classifier: crashingClassify);
      addTearDown(env.dispose);
      scriptThreadPage(env, 'yy小说吧', 1, threads: <ThreadSummary>[
        mkThread(tid: 401, createTime: 100, title: '坏帖当头'),
        mkThread(tid: 402, createTime: 200),
        mkThread(tid: 403, createTime: 300),
      ]);
      for (final int tid in <int>[401, 402, 403]) {
        scriptPost(env, tid, 'yy小说吧');
      }
      await env.service.run();
      final CollectionStateEntry s = (await env.repo.forum('yy小说吧'))!;
      expect(s.lastThreadTime, 0, reason: '连续成功前缀为空');
      expect(s.lastStatus, 'partial');
      expect(await env.db.posts.count().getSingle(), 2);
    });
  });

  group('§8.7 增量拉取流程', () {
    test('冷启动（水位=0）只回溯 2 页', () async {
      final TestEnv env = await TestEnv.create(forums: <String>['A吧']);
      addTearDown(env.dispose);
      scriptThreadPage(env, 'A吧', 1,
          threads: <ThreadSummary>[
            mkThread(tid: 11, createTime: 300),
            mkThread(tid: 12, createTime: 290),
          ],
          hasMore: true);
      scriptThreadPage(env, 'A吧', 2,
          threads: <ThreadSummary>[mkThread(tid: 13, createTime: 280)],
          hasMore: true);
      scriptThreadPage(env, 'A吧', 3,
          threads: <ThreadSummary>[mkThread(tid: 14, createTime: 270)],
          hasMore: true); // 不应被拉取
      for (final int tid in <int>[11, 12, 13, 14]) {
        scriptPost(env, tid, 'A吧');
      }
      await env.service.run();
      final List<int> pns = env.api.calls
          .where((ApiCall c) => c.isThreads)
          .map((ApiCall c) => c.pn)
          .toList();
      expect(pns, <int>[1, 2], reason: '冷启动 ≤2 页，第 3 页不拉');
      expect(postsCallTids(env).toSet(), <int>{11, 12, 13});
      expect(env.snapshots.any((CollectRunState st) => st.forums.any(
          (ForumRunState f) => f.stepDetail.contains('（冷启动）'))), isTrue);
    });

    test('常规增量 ≤5 页封顶', () async {
      final TestEnv env = await TestEnv.create(forums: <String>['A吧']);
      addTearDown(env.dispose);
      await setWatermark(env, 'A吧', time: 1, tid: 0);
      for (int pn = 1; pn <= 6; pn++) {
        scriptThreadPage(env, 'A吧', pn,
            threads: <ThreadSummary>[
              mkThread(tid: 100 + pn, createTime: 1000 + pn),
            ],
            hasMore: true);
        scriptPost(env, 100 + pn, 'A吧');
      }
      await env.service.run();
      final List<int> pns = env.api.calls
          .where((ApiCall c) => c.isThreads)
          .map((ApiCall c) => c.pn)
          .toList();
      expect(pns, <int>[1, 2, 3, 4, 5], reason: '单次运行每吧 ≤5 页');
    });

    test('首个不命中出现后扫完本页即停；置顶/删除/屏蔽不计 miss 也不入队', () async {
      final TestEnv env = await TestEnv.create(forums: <String>['A吧']);
      addTearDown(env.dispose);
      await setWatermark(env, 'A吧', time: 200, tid: 50);
      scriptThreadPage(env, 'A吧', 1, threads: <ThreadSummary>[
        mkThread(tid: 90, createTime: 150, isTop: true), // 置顶旧帖：跳过且不算 miss
        mkThread(tid: 10, createTime: 300),
        mkThread(tid: 91, createTime: 140, isDeleted: true), // 删除帖：同上
        mkThread(tid: 11, createTime: 250),
      ], hasMore: true);
      scriptThreadPage(env, 'A吧', 2, threads: <ThreadSummary>[
        mkThread(tid: 12, createTime: 210),
        mkThread(tid: 13, createTime: 150), // 首个不命中
        mkThread(tid: 14, createTime: 220), // 同页容忍并列 → 仍收
      ], hasMore: true);
      scriptThreadPage(env, 'A吧', 3,
          threads: <ThreadSummary>[mkThread(tid: 15, createTime: 205)],
          hasMore: true); // 不应被拉取
      for (final int tid in <int>[10, 11, 12, 14, 15, 90, 91]) {
        scriptPost(env, tid, 'A吧');
      }
      await env.service.run();
      final List<int> pns = env.api.calls
          .where((ApiCall c) => c.isThreads)
          .map((ApiCall c) => c.pn)
          .toList();
      expect(pns, <int>[1, 2], reason: 'page2 出现 miss → 扫完本页即停，无 page3');
      // create_time 升序：210(12), 220(14), 250(11), 300(10)
      expect(postsCallTids(env), <int>[12, 14, 11, 10]);
    });
  });

  group('§8.11 频控：退避 / 吧级冷却 / 全局暂停 / 每日预算', () {
    test('单帖失败 → 30s 退避重入队尾不阻塞，重试成功水位齐平', () async {
      final TestEnv env = await TestEnv.create(forums: <String>['A吧']);
      addTearDown(env.dispose);
      scriptThreadPage(env, 'A吧', 1, threads: <ThreadSummary>[
        mkThread(tid: 21, createTime: 200),
        mkThread(tid: 22, createTime: 100),
      ]);
      scriptPost(env, 21, 'A吧');
      scriptPost(env, 22, 'A吧');
      env.api.failPosts(22, errNetwork(), times: 1); // 首次网络失败，重试成功
      final DateTime t0 = env.clock.now();
      await env.service.run();

      // 队列升序 [22,21]：22 失败重入队尾 → 21 先行 → 30s 后 22 重试成功
      expect(postsCallTids(env), <int>[22, 21, 22]);
      expect(env.clock.now().difference(t0).inSeconds,
          greaterThanOrEqualTo(30), reason: '退避 30s×2⁰ 实际等待');
      final CollectionStateEntry s = (await env.repo.forum('A吧'))!;
      expect(s.lastStatus, 'ok');
      expect(s.lastThreadTime, 200);
      expect(env.last.totals.threadsAdded, 2);
    });

    test('吧级连续 3 败 → 冷却 48h（rate_limited），前缀推进，不阻塞其余吧', () async {
      final TestEnv env = await TestEnv.create(forums: <String>['A吧', 'B吧']);
      addTearDown(env.dispose);
      scriptThreadPage(env, 'A吧', 1, threads: <ThreadSummary>[
        mkThread(tid: 32, createTime: 200), // 坏帖
        mkThread(tid: 31, createTime: 100), // 成功前缀
      ]);
      scriptPost(env, 31, 'A吧');
      env.api.failPosts(32, err429(), times: -1); // 永久 429
      scriptThreadPage(env, 'B吧', 1, threads: <ThreadSummary>[
        mkThread(tid: 41, createTime: 150),
      ]);
      scriptPost(env, 41, 'B吧');
      final DateTime t0 = env.clock.now();
      await env.service.run();

      // A 吧：orig + 2 次退避重试 = 3 连败 → 冷却
      final List<ApiCall> aFails = env.api.calls
          .where((ApiCall c) => c.key == 'posts:32:1')
          .toList();
      expect(aFails.length, 3);
      expect(env.clock.now().difference(t0).inSeconds, greaterThanOrEqualTo(90),
          reason: '退避 30s + 60s 已实际等待');
      final CollectionStateEntry a = (await env.repo.forum('A吧'))!;
      expect(a.lastStatus, 'rate_limited', reason: '429 → rate_limited');
      expect(a.consecutiveFailures, greaterThanOrEqualTo(3));
      expect(a.cooldownUntil, isNotNull);
      expect(
        a.cooldownUntil!.difference(env.clock.now()).inHours.abs(),
        lessThanOrEqualTo(48),
      );
      expect(a.cooldownUntil!.isAfter(env.clock.now().add(const Duration(hours: 47))),
          isTrue, reason: '≈ now+48h');
      expect(a.lastThreadTime, 100, reason: '冷却也推进连续成功前缀');
      // B 吧不受影响
      final CollectionStateEntry b = (await env.repo.forum('B吧'))!;
      expect(b.lastStatus, 'ok');
      expect(b.lastThreadTime, 150);
      final ForumRunState fa =
          env.last.forums.firstWhere((ForumRunState f) => f.fname == 'A吧');
      expect(fa.status, ForumStatus.cooldown);
      expect(fa.cooldownUntil, isNotNull);
      expect(env.last.forums
          .firstWhere((ForumRunState f) => f.fname == 'B吧')
          .status, ForumStatus.done);
      expect(env.snapshots.any((CollectRunState st) => st.logs.any(
          (CollectLogEntry l) => l.detail.contains('冷却 48h'))), isTrue);
    });

    test('启动时仍在冷却期的吧跳过，不发请求', () async {
      final TestEnv env = await TestEnv.create(forums: <String>['A吧', 'B吧']);
      addTearDown(env.dispose);
      await env.repo.updateForumAfterRun(
        fname: 'A吧',
        lastRunAt: env.clock.now(),
        lastStatus: 'rate_limited',
        consecutiveFailures: 3,
        cooldownUntil: env.clock.now().add(const Duration(hours: 1)),
      );
      scriptThreadPage(env, 'B吧', 1,
          threads: <ThreadSummary>[mkThread(tid: 51, createTime: 100)]);
      scriptPost(env, 51, 'B吧');
      await env.service.run();

      expect(
          env.api.countCalls((ApiCall c) => c.forum == 'A吧'), 0,
          reason: '冷却吧零请求');
      final CollectionStateEntry b = (await env.repo.forum('B吧'))!;
      expect(b.lastStatus, 'ok');
      expect(env.last.forums
          .firstWhere((ForumRunState f) => f.fname == 'A吧')
          .status, ForumStatus.cooldown);
      expect(env.snapshots.last.logs.any((CollectLogEntry l) =>
          l.fname == 'A吧' && l.detail.contains('冷却中，不影响其余吧')), isTrue);
    });

    test('全局连续 3 败 → 整轮暂停 + 「接口似乎已变更」横幅，水位不动', () async {
      final TestEnv env = await TestEnv.create(forums: <String>['A吧']);
      addTearDown(env.dispose);
      env.api.failThreads('A吧', errServer(4), times: -1); // 列表永远失败
      await env.service.run();

      expect(env.api.calls.length, 3, reason: '3 连败即全局暂停，不再发请求');
      expect(env.last.banner, kBannerApiBroken);
      final CollectionStateEntry a = (await env.repo.forum('A吧'))!;
      expect(a.lastStatus, 'api_error');
      expect(a.lastThreadTime, 0);
      expect(a.cooldownUntil, isNotNull);
      expect(env.last.phase, CollectPhase.idle);
    });

    test('全局暂停同样中止其余吧（接口全挂 = 全吧连败，§8.12）', () async {
      final TestEnv env = await TestEnv.create(forums: <String>['A吧', 'B吧']);
      addTearDown(env.dispose);
      // 两吧列表全部失败（模拟接口签名/协议变更：任何请求都报错）
      env.api.failThreads('A吧', errServer(4), times: -1);
      env.api.failThreads('B吧', errServer(4), times: -1);
      await env.service.run();

      expect(env.last.banner, kBannerApiBroken);
      for (final String f in <String>['A吧', 'B吧']) {
        final CollectionStateEntry s = (await env.repo.forum(f))!;
        expect(s.lastStatus, 'api_error');
        expect(s.lastThreadTime, 0, reason: '全局熔断（网络断口径）→ 水位不动');
      }
      // 全局在第 3 连败即熔断：两吧合计请求数被掐断（无退避满 3+3 轮）
      expect(env.api.calls.length, lessThanOrEqualTo(5));
      for (final ForumRunState fs in env.last.forums) {
        expect(fs.status, ForumStatus.failed);
      }
    });

    test('每日预算触顶 → 停 + 横幅 + 前缀推进 + 计数持久化', () async {
      final TestEnv env = await TestEnv.create(
          forums: <String>['A吧'], budgetLimit: 3);
      addTearDown(env.dispose);
      scriptThreadPage(env, 'A吧', 1, threads: <ThreadSummary>[
        mkThread(tid: 63, createTime: 300),
        mkThread(tid: 62, createTime: 200),
        mkThread(tid: 61, createTime: 100),
      ]);
      for (final int tid in <int>[61, 62, 63]) {
        scriptPost(env, tid, 'A吧');
      }
      await env.service.run();

      expect(env.api.calls.length, 3, reason: '第 4 个请求被预算拦截');
      expect(env.last.banner, contains('预算'));
      final CollectionStateEntry a = (await env.repo.forum('A吧'))!;
      expect(a.lastStatus, 'partial');
      expect(a.lastThreadTime, 200, reason: '前缀推进到已成功的 T2');
      expect(await env.repo.getSetting(CollectSettingsKeys.budgetCount), '3');
      expect(await env.repo.getSetting(CollectSettingsKeys.budgetDate),
          '2026-10-13');
    });

    test('预算跨日重置（存储日期 ≠ 今日 → 计数归零续跑）', () async {
      final TestEnv env = await TestEnv.create(forums: <String>['A吧']);
      addTearDown(env.dispose);
      await env.repo
          .setSetting(CollectSettingsKeys.budgetDate, '2000-01-01');
      await env.repo.setSetting(CollectSettingsKeys.budgetCount, '300');
      scriptThreadPage(env, 'A吧', 1, threads: <ThreadSummary>[
        mkThread(tid: 71, createTime: 100),
        mkThread(tid: 72, createTime: 200),
      ]);
      scriptPost(env, 71, 'A吧');
      scriptPost(env, 72, 'A吧');
      await env.service.run();

      final CollectionStateEntry a = (await env.repo.forum('A吧'))!;
      expect(a.lastStatus, 'ok');
      expect(await env.repo.getSetting(CollectSettingsKeys.budgetCount), '3');
      expect(await env.repo.getSetting(CollectSettingsKeys.budgetDate),
          '2026-10-13');
    });

    test('列表页瞬时失败 → 原地退避重试后继续', () async {
      final TestEnv env = await TestEnv.create(forums: <String>['A吧']);
      addTearDown(env.dispose);
      scriptThreadPage(env, 'A吧', 1,
          threads: <ThreadSummary>[mkThread(tid: 81, createTime: 100)]);
      scriptPost(env, 81, 'A吧');
      env.api.failThreads('A吧', errNetwork(), times: 2, pn: 1);
      final DateTime t0 = env.clock.now();
      await env.service.run();

      expect(
          env.api.countCalls((ApiCall c) => c.key == 'threads:A吧:1'), 3);
      expect(env.clock.now().difference(t0).inSeconds,
          greaterThanOrEqualTo(90), reason: '30s + 60s 退避');
      expect((await env.repo.forum('A吧'))!.lastStatus, 'ok');
    });
  });

  group('§8.9 分类处置（假分类函数注入）', () {
    test('日常丢弃仅计数、求书入库不抽取、扫书全开', () async {
      final TestEnv env = await TestEnv.create(forums: <String>['A吧']);
      addTearDown(env.dispose);
      scriptThreadPage(env, 'A吧', 1, threads: <ThreadSummary>[
        mkThread(tid: 91, createTime: 100, title: '水贴闲聊专用楼'),
        mkThread(tid: 92, createTime: 200, title: '求书：书荒了求推荐'),
        mkThread(tid: 93, createTime: 300, title: '月度扫书'),
      ]);
      scriptPost(env, 91, 'A吧');
      scriptPost(env, 92, 'A吧',
          floorText: '想看《求之书》这样的，谁有资源');
      scriptPost(env, 93, 'A吧',
          floorText: '《扫之书》 作者：某人 强烈推荐');
      await env.service.run();

      final List<Post> posts = await env.db.select(env.db.posts).get();
      expect(posts.map((Post p) => p.tid).toSet(), <int>{92, 93},
          reason: '日常闲聊整帖丢弃不入库');
      expect(env.last.totals.discardedChat, 1);
      expect(env.last.totals.threadsAdded, 2);
      final Post seek = posts.firstWhere((Post p) => p.tid == 92);
      expect(seek.postKind, '求书');
      expect(seek.recommendFlag, 0);
      final List<BookEntry> entries =
          await env.db.select(env.db.bookEntries).get();
      expect(entries.length, 1, reason: '求书不触发书名抽取');
      expect(entries.single.name, '扫之书');
      expect(entries.single.category, '扫书');
      // 水位覆盖被丢弃帖（丢弃 = 处理成功，不卡水位）
      expect((await env.repo.forum('A吧'))!.lastThreadTime, 300);
      expect(env.snapshots.last.logs.any((CollectLogEntry l) =>
          l.event == '分类' && l.detail.contains('日常（整帖丢弃')), isTrue);
    });

    test('排雷帖：mineThreads 计数 + recommend_flag=-1', () async {
      final TestEnv env = await TestEnv.create(forums: <String>['A吧']);
      addTearDown(env.dispose);
      scriptThreadPage(env, 'A吧', 1, threads: <ThreadSummary>[
        mkThread(tid: 95, createTime: 100, title: '排雷：《毒草》别看'),
      ]);
      scriptPost(env, 95, 'A吧', floorText: '《毒草》 作者：坏人 剧毒');
      await env.service.run();
      expect(env.last.totals.mineThreads, 1);
      final Post p = await env.db.select(env.db.posts).getSingle();
      expect(p.recommendFlag, -1);
    });
  });

  group('幂等与重入（§8.7 去重三层）', () {
    test('同数据跑两遍 → 第二遍全 skippedDup、行数不变', () async {
      final TestEnv env = await TestEnv.create(forums: <String>['A吧']);
      addTearDown(env.dispose);
      scriptThreadPage(env, 'A吧', 1, threads: <ThreadSummary>[
        mkThread(tid: 101, createTime: 100, title: '扫书一期'),
        mkThread(tid: 102, createTime: 200, title: '扫书二期'),
        mkThread(tid: 103, createTime: 300, title: '扫书三期'),
      ]);
      for (final int tid in <int>[101, 102, 103]) {
        scriptPost(env, tid, 'A吧');
      }
      await env.service.run();
      expect(env.last.totals.threadsAdded, 3);
      expect(env.last.totals.entriesAdded, 3);
      final int posts1 = await env.db.posts.count().getSingle();
      final int floors1 = await env.db.floors.count().getSingle();
      final int entries1 = await env.db.bookEntries.count().getSingle();
      final int groups1 = await env.db.bookGroups.count().getSingle();

      // 水位归零重放同批数据（模拟「重入不重复」）
      await setWatermark(env, 'A吧', time: 0, tid: 0);
      await env.service.run();

      expect(env.last.totals.threadsAdded, 0);
      expect(env.last.totals.floorsAdded, 0);
      expect(env.last.totals.entriesAdded, 0);
      expect(env.last.totals.skippedDup, 3, reason: '全部命中 content_hash');
      expect(await env.db.posts.count().getSingle(), posts1);
      expect(await env.db.floors.count().getSingle(), floors1);
      expect(await env.db.bookEntries.count().getSingle(), entries1);
      expect(await env.db.bookGroups.count().getSingle(), groups1);
      final BookGroup g =
          await (env.db.select(env.db.bookGroups)..limit(1)).getSingle();
      expect(g.entryTotal, 1, reason: '组聚合不虚增');
    });
  });

  group('状态发布（契约：CollectRunState 快照）', () {
    test('四步流水/子进度/日志事件/汇总全链路', () async {
      final TestEnv env = await TestEnv.create(forums: <String>['A吧']);
      addTearDown(env.dispose);
      scriptThreadPage(env, 'A吧', 1, threads: <ThreadSummary>[
        mkThread(tid: 111, createTime: 100),
        mkThread(tid: 112, createTime: 200),
      ]);
      scriptPost(env, 111, 'A吧');
      scriptPost(env, 112, 'A吧');
      await env.service.run();

      // 运行中快照：步骤① 细节文案
      expect(
        env.snapshots.any((CollectRunState st) => st.forums.any(
            (ForumRunState f) =>
                f.step == CollectStep.list && f.stepDetail == 'pn 1/2（冷启动）')),
        isTrue,
      );
      // 步骤②：'tid i/N'
      expect(
        env.snapshots.any((CollectRunState st) => st.forums.any(
            (ForumRunState f) => f.stepDetail == 'tid 1/2')),
        isTrue,
      );
      // 运行中 globalStep = 未完成吧最小 step
      final CollectRunState mid = env.snapshots.firstWhere((CollectRunState st) =>
          st.phase == CollectPhase.running &&
          st.forums.any((ForumRunState f) => f.step == CollectStep.ingest));
      expect(mid.globalStep, isNotNull);

      final CollectRunState fin = env.last;
      expect(fin.phase, CollectPhase.idle);
      expect(fin.startedAt, isNotNull);
      expect(fin.finishedAt, isNotNull);
      expect(fin.globalStep, CollectStep.summary);
      expect(fin.overallProgress, 1.0);
      final ForumRunState f = fin.forums.single;
      expect(f.status, ForumStatus.done);
      expect(f.step, CollectStep.summary);
      expect(f.stepProgress, 1.0);
      expect(f.watermarkFrom, 0);
      expect(f.watermarkTarget, 200);
      expect(fin.totals.threadsAdded, 2);
      expect(fin.totals.floorsAdded, 2);
      expect(fin.totals.entriesAdded, 2);

      // 日志：事件名对齐设计稿（开始/拉列表/分类/入库/完成），新在前
      final List<String> events =
          fin.logs.map((CollectLogEntry l) => l.event).toList();
      expect(events, containsAll(<String>['开始', '拉列表', '分类', '入库', '完成']));
      expect(fin.logs.first.event, '完成', reason: '最新在前');
      expect(
        fin.logs.any((CollectLogEntry l) =>
            l.event == '分类' &&
            l.detail.contains('tid=111 → 扫书 (书名数=1')),
        isTrue,
        reason: '分类日志 detail 形如 tid=xxx → 扫书 (书名数=n)',
      );
      // 持久层日志：每吧一条汇总（滚动 200 由 repo.appendLog 保证）
      final List<CollectionLog> dbLogs = await env.repo.recentLogs();
      expect(dbLogs.length, 1);
      expect(dbLogs.single.fname, 'A吧');
      expect(dbLogs.single.status, 'ok');
      expect(dbLogs.single.threadsAdded, 2);
    });

    test('日志滚动上限 200（105 帖 > 200 条事件）', () async {
      final TestEnv env = await TestEnv.create(forums: <String>['A吧']);
      addTearDown(env.dispose);
      final List<ThreadSummary> threads = <ThreadSummary>[
        for (int i = 0; i < 105; i++)
          mkThread(tid: 900 - i, createTime: 1000 + i), // 列表倒序、队列升序
      ];
      scriptThreadPage(env, 'A吧', 1, threads: threads);
      for (final ThreadSummary t in threads) {
        scriptPost(env, t.tid, 'A吧');
      }
      await env.service.run();
      expect(env.last.logs.length, 200);
      expect(env.last.totals.threadsAdded, 105);
      expect(env.last.logs.first.event, '完成');
    });
  });
}
