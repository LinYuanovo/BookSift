/// CollectController / CollectRunNotifier 接线测试（plain test()）。
/// 契约验证：provider 名不变、startAll/cancel/addForum/setForumEnabled/removeForum。
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/collector/collect_controller.dart';
import 'package:booksift/collector/collect_providers.dart';
import 'package:booksift/collector/collect_state.dart';
import 'package:booksift/collector/tieba/src/models.dart';
import 'package:booksift/collector/tieba_api.dart';
import 'package:booksift/collector/worker.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/collect_repository.dart';
import 'package:booksift/data/repo/database_provider.dart';

import 'support.dart';

class _CtlEnv {
  _CtlEnv(this.container, this.db, this.repo, this.api, this.clock);

  final ProviderContainer container;
  final AppDatabase db;
  final CollectRepository repo;
  final FakeTiebaApi api;
  final FakeClock clock;

  CollectController get controller => container.read(collectControllerProvider);

  CollectRunState get state => container.read(collectRunStateProvider);

  Future<void> dispose() async {
    container.dispose();
    await db.close();
  }
}

Future<_CtlEnv> _makeCtlEnv() async {
  final FakeClock clock = FakeClock();
  final AppDatabase db = AppDatabase(NativeDatabase.memory());
  final FakeTiebaApi api = FakeTiebaApi(clock, holdTicks: 1);
  final ProviderContainer container = ProviderContainer(overrides: <Override>[
    appDatabaseProvider.overrideWithValue(db),
    tiebaApiProvider.overrideWithValue(api),
    collectClockProvider.overrideWithValue(clock),
    collectSleeperProvider.overrideWithValue(fakeSleeper(clock)),
    postWorkerFactoryProvider
        .overrideWithValue(() async => LocalPostWorker(fakeClassify)),
    networkGateProvider.overrideWithValue(const AlwaysAllowNetworkGate()),
  ]);
  return _CtlEnv(container, db, CollectRepository(db), api, clock);
}

void main() {
  group('addForum（§5.9：先拉 1 页验证存在性）', () {
    test('成功：fid 落库', () async {
      final _CtlEnv env = await _makeCtlEnv();
      addTearDown(env.dispose);
      env.api.scriptThreads('测试吧', 1, ThreadsPage(
        fid: 999,
        threads: <ThreadSummary>[mkThread(tid: 1, createTime: 100)],
        hasMore: false,
      ));
      await env.controller.addForum('  测试吧  '); // 首尾空白应被 trim
      final CollectionStateEntry? row = await env.repo.forum('测试吧');
      expect(row, isNotNull);
      expect(row!.fid, 999);
      expect(row.enabled, true);
    });

    test('吧不存在（fid=0 且无主题）→ CollectAddForumException', () async {
      final _CtlEnv env = await _makeCtlEnv();
      addTearDown(env.dispose);
      env.api.scriptThreads('不存在吧', 1, const ThreadsPage(
          fid: 0, threads: <ThreadSummary>[], hasMore: false));
      await expectLater(
        env.controller.addForum('不存在吧'),
        throwsA(isA<CollectAddForumException>().having(
            (CollectAddForumException e) => e.reason, 'reason', contains('不存在'))),
      );
      expect(await env.repo.forum('不存在吧'), isNull);
    });

    test('风控 429 → reason 含「风控」', () async {
      final _CtlEnv env = await _makeCtlEnv();
      addTearDown(env.dispose);
      env.api.failThreads('风控吧', err429(), times: -1);
      await expectLater(
        env.controller.addForum('风控吧'),
        throwsA(isA<CollectAddForumException>()
            .having((CollectAddForumException e) => e.reason, 'reason',
                contains('风控'))),
      );
    });

    test('网络错误 → reason 含「网络错误」', () async {
      final _CtlEnv env = await _makeCtlEnv();
      addTearDown(env.dispose);
      env.api.failThreads('断网吧', errNetwork(), times: -1);
      await expectLater(
        env.controller.addForum('断网吧'),
        throwsA(isA<CollectAddForumException>()
            .having((CollectAddForumException e) => e.reason, 'reason',
                contains('网络错误'))),
      );
    });

    test('空吧名直接拒绝', () async {
      final _CtlEnv env = await _makeCtlEnv();
      addTearDown(env.dispose);
      await expectLater(env.controller.addForum('   '),
          throwsA(isA<CollectAddForumException>()));
    });
  });

  group('setForumEnabled / removeForum', () {
    test('停用与删除只动水位行', () async {
      final _CtlEnv env = await _makeCtlEnv();
      addTearDown(env.dispose);
      await env.repo.addForum('A吧', fid: 1);
      await env.controller.setForumEnabled('A吧', false);
      expect((await env.repo.forum('A吧'))!.enabled, false);
      await env.controller.setForumEnabled('A吧', true);
      expect((await env.repo.forum('A吧'))!.enabled, true);
      await env.controller.removeForum('A吧');
      expect(await env.repo.forum('A吧'), isNull);
    });
  });

  group('startAll / cancel（Notifier 全链路接线）', () {
    test('startAll 跑完整轮：默认两吧播种、状态流发布、水位落库', () async {
      final _CtlEnv env = await _makeCtlEnv();
      addTearDown(env.dispose);
      env.api.scriptThreads('yy小说吧', 1, ThreadsPage(
        fid: 1532319,
        threads: <ThreadSummary>[
          mkThread(tid: 1001, createTime: 100),
          mkThread(tid: 1002, createTime: 200),
        ],
        hasMore: false,
      ));
      env.api.scriptPosts(1001, 1, mkPostsPage(1001), forum: 'yy小说吧');
      env.api.scriptPosts(1002, 1, mkPostsPage(1002), forum: 'yy小说吧');

      await env.controller.startAll(); // future 在整轮结束完成

      final CollectRunState st = env.state;
      expect(st.phase, CollectPhase.idle);
      expect(st.finishedAt, isNotNull);
      expect(st.totals.threadsAdded, 2);
      expect(st.forums.length, 2, reason: '默认播种 yy小说吧 + 哀伤雪刃（§8.7）');
      final CollectionStateEntry yy = (await env.repo.forum('yy小说吧'))!;
      expect(yy.lastStatus, 'ok');
      expect(yy.lastThreadTime, 200);
      expect(yy.fid, 1532319);
      final CollectionStateEntry as_ = (await env.repo.forum('哀伤雪刃'))!;
      expect(as_.lastStatus, 'ok', reason: '无脚本 → 空列表自然完成');
      expect(await env.repo.recentLogs(limit: 10).then((List<CollectionLog> l) =>
          l.where((CollectionLog x) => x.status == 'ok').length), 2);
    });

    test('运行中再调 startAll = no-op（同一轮）', () async {
      final _CtlEnv env = await _makeCtlEnv();
      addTearDown(env.dispose);
      await env.repo.addForum('A吧');
      env.api.scriptThreads('A吧', 1, ThreadsPage(
          fid: 1,
          threads: <ThreadSummary>[mkThread(tid: 1, createTime: 100)],
          hasMore: false));
      env.api.scriptPosts(1, 1, mkPostsPage(1), forum: 'A吧');
      final Future<void> f1 = env.controller.startAll();
      final Future<void> f2 = env.controller.startAll();
      await f1;
      await f2;
      expect(env.api.countCalls((ApiCall c) => c.isThreads), 1,
          reason: '仅一轮');
    });

    test('cancel：phase stopping → idle，水位不动', () async {
      final _CtlEnv env = await _makeCtlEnv();
      addTearDown(env.dispose);
      await env.repo.addForum('A吧');
      env.api.scriptThreads('A吧', 1, ThreadsPage(
        fid: 1,
        threads: <ThreadSummary>[
          mkThread(tid: 2, createTime: 200),
          mkThread(tid: 1, createTime: 100),
        ],
        hasMore: false,
      ));
      env.api.scriptPosts(1, 1, mkPostsPage(1), forum: 'A吧');
      env.api.scriptPosts(2, 1, mkPostsPage(2), forum: 'A吧');
      env.api.afterRequest = (int n) {
        if (n == 2) env.controller.cancel(); // 不 await：与 run 并发
      };
      await env.controller.startAll();
      expect(env.state.phase, CollectPhase.idle);
      expect((await env.repo.forum('A吧'))!.lastThreadTime, 0);
      expect((await env.repo.forum('A吧'))!.lastStatus, 'canceled');
    });
  });
}
