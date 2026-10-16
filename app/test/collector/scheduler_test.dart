/// 调度原语单测：Semaphore / 限速器间隔 / 退避 / 并发钳制 / 每日预算。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/collector/scheduler.dart';

import 'support.dart';

class _MapBudgetStore implements BudgetStore {
  final Map<String, String> map = <String, String>{};

  @override
  Future<String?> read(String key) async => map[key];

  @override
  Future<void> write(String key, String value) async => map[key] = value;
}

void main() {
  group('Semaphore（§8.8 全局闸门）', () {
    test('许可耗尽后 acquire 等待，release 依 FIFO 放行', () async {
      final Semaphore sem = Semaphore(2);
      await sem.acquire();
      await sem.acquire();
      expect(sem.available, 0);
      bool third = false;
      final Future<void> f = sem.acquire().then((_) => third = true);
      await Future<void>.delayed(Duration.zero);
      expect(third, false, reason: '无许可时不得放行');
      expect(sem.waiting, 1);
      sem.release();
      await f;
      expect(third, true);
    });
  });

  group('retryBackoff（§8.11 30s×2ⁿ）', () {
    test('n=0,1,2 → 30/60/120s', () {
      expect(retryBackoff(0), const Duration(seconds: 30));
      expect(retryBackoff(1), const Duration(seconds: 60));
      expect(retryBackoff(2), const Duration(seconds: 120));
    });
  });

  group('档位映射（需求 5：间隔/并发两档，匿名值不变）', () {
    test('intervalMsFor：匿名 1500–3000 原样；BDUSS 档 1000–2000（§8.11）', () {
      final ({int minMs, int maxMs}) anon = intervalMsFor(bdussImported: false);
      expect(anon.minMs, kMinIntervalMs);
      expect(anon.minMs, 1500);
      expect(anon.maxMs, kMaxIntervalMs);
      expect(anon.maxMs, 3000);

      final ({int minMs, int maxMs}) bd = intervalMsFor(bdussImported: true);
      expect(bd.minMs, kMinIntervalBdussMs);
      expect(bd.minMs, 1000);
      expect(bd.maxMs, kMaxIntervalBdussMs);
      expect(bd.maxMs, 2000);
    });

    test('maxConcurrencyFor：匿名 3、BDUSS 档 4（默认 2 两档同）', () {
      expect(kDefaultConcurrency, 2);
      expect(maxConcurrencyFor(bdussImported: false), kMaxConcurrencyAnonymous);
      expect(maxConcurrencyFor(bdussImported: false), 3);
      expect(maxConcurrencyFor(bdussImported: true), kMaxConcurrencyBduss);
      expect(maxConcurrencyFor(bdussImported: true), 4);
    });
  });

  group('effectiveConcurrency（§8.8 默认2；上限匿名3/BDUSS档4）', () {
    test('缺省 2、匿名钳制 [1,3]、非法回落（行为与历史一字不变）', () {
      expect(effectiveConcurrency(null), 2);
      expect(effectiveConcurrency(''), 2);
      expect(effectiveConcurrency('3'), 3);
      expect(effectiveConcurrency('5'), 3, reason: '匿名上限 3');
      expect(effectiveConcurrency('0'), 1);
      expect(effectiveConcurrency('-1'), 1);
      expect(effectiveConcurrency('x'), 2);
    });

    test('BDUSS 档：4 放行、5 钳到 4', () {
      expect(effectiveConcurrency('4', bdussImported: true), 4);
      expect(effectiveConcurrency('5', bdussImported: true), 4, reason: 'BDUSS 档上限 4');
      expect(effectiveConcurrency('4'), 3, reason: '同一原值在匿名档仍钳到 3');
    });
  });

  group('isLoginInvalidError（§8.10 失效检测）', () {
    test('110000–110999 与未登录文案命中；429/网络/服务端错误不命中', () {
      expect(
        isLoginInvalidError(const CollectRequestException(
            kind: CollectFailureKind.rateLimited, code: 110001, message: 'errorno=110001 需登录')),
        isTrue,
      );
      expect(
        isLoginInvalidError(const CollectRequestException(
            kind: CollectFailureKind.rateLimited, code: 0, message: '请先登录后再操作')),
        isTrue,
      );
      expect(
        isLoginInvalidError(const CollectRequestException(
            kind: CollectFailureKind.rateLimited, code: 429, message: 'HTTP 429')),
        isFalse,
        reason: '匿名档风控 429 不触发账号降级',
      );
      expect(
        isLoginInvalidError(const CollectRequestException(
            kind: CollectFailureKind.network, code: 110001, message: '需登录')),
        isFalse,
        reason: '非 rateLimited 类别不触发',
      );
      expect(
        isLoginInvalidError(const CollectRequestException(
            kind: CollectFailureKind.serverError, code: 4, message: 'errorno=4')),
        isFalse,
      );
    });
  });

  group('GlobalRateLimiter（§8.11 1.5–3.0s 均匀抖动）', () {
    test('连续出牌间隔落在 [1500,3000]ms 且串行化', () async {
      final FakeClock clock = FakeClock();
      final _MapBudgetStore store = _MapBudgetStore();
      final DailyBudget budget =
          DailyBudget(store: store, clock: clock, limit: 100);
      final GlobalRateLimiter limiter = GlobalRateLimiter(
        clock: clock,
        sleeper: fakeSleeper(clock),
        rng: Random(7),
        budget: budget,
      );
      final List<DateTime> starts = <DateTime>[clock.now()];
      await limiter.throttle(); // 首次不等待
      for (int i = 0; i < 20; i++) {
        await limiter.throttle();
        starts.add(clock.now());
      }
      for (int i = 2; i < starts.length; i++) {
        final int gap = starts[i].difference(starts[i - 1]).inMilliseconds;
        expect(gap, greaterThanOrEqualTo(1500));
        expect(gap, lessThanOrEqualTo(3000));
      }
      // 抖动不是常数（Random(7) 20 次抽样应出现多档取值）
      final Set<int> gaps = <int>{
        for (int i = 2; i < starts.length; i++)
          starts[i].difference(starts[i - 1]).inMilliseconds,
      };
      expect(gaps.length, greaterThan(1));
      expect(budget.used, 21);
    });

    test('并发 throttle 全局串行：两分支同时进入也只按节拍出牌', () async {
      final FakeClock clock = FakeClock();
      final DailyBudget budget = DailyBudget(
          store: _MapBudgetStore(), clock: clock, limit: 100);
      final GlobalRateLimiter limiter = GlobalRateLimiter(
          clock: clock,
          sleeper: fakeSleeper(clock),
          rng: Random(3),
          budget: budget);
      final List<DateTime> outs = <DateTime>[];
      await limiter.throttle(); // 预出牌：首张不等待，后续张张有间隔
      await Future.wait(<Future<void>>[
        for (int i = 0; i < 4; i++)
          limiter.throttle().then((_) => outs.add(clock.now())),
      ]);
      outs.sort((DateTime a, DateTime b) => a.compareTo(b));
      for (int i = 1; i < outs.length; i++) {
        expect(outs[i].difference(outs[i - 1]).inMilliseconds,
            greaterThanOrEqualTo(1500));
      }
    });
  });

  group('DailyBudget（§8.11 每日 ≤300 本地计数、跨日重置）', () {
    test('触顶抛 BudgetExhaustedException 并持久计数', () async {
      final _MapBudgetStore store = _MapBudgetStore();
      final FakeClock clock = FakeClock();
      final DailyBudget budget =
          DailyBudget(store: store, clock: clock, limit: 3);
      await budget.consume();
      await budget.consume();
      await budget.consume();
      expect(store.map['collect_budget_count'], '3');
      await expectLater(budget.consume(),
          throwsA(isA<BudgetExhaustedException>()));
      expect(budget.exhausted, true);
    });

    test('跨日自动重置（存储的是昨天日期）', () async {
      final _MapBudgetStore store = _MapBudgetStore()
        ..map['collect_budget_date'] = '2000-01-01'
        ..map['collect_budget_count'] = '300';
      final FakeClock clock = FakeClock();
      final DailyBudget budget =
          DailyBudget(store: store, clock: clock, limit: 300);
      await budget.consume(); // 不应抛：日期不匹配 → 计数归零
      expect(budget.used, 1);
      expect(store.map['collect_budget_date'], '2026-10-13');
    });

    test('同日重入读取既有计数', () async {
      final _MapBudgetStore store = _MapBudgetStore()
        ..map['collect_budget_date'] = '2026-10-13'
        ..map['collect_budget_count'] = '299';
      final DailyBudget budget = DailyBudget(
          store: store, clock: FakeClock(), limit: 300);
      await budget.consume();
      await expectLater(budget.consume(),
          throwsA(isA<BudgetExhaustedException>()));
    });
  });
}
