/// 并发/限速/预算/退避原语（§8.8 并发模型 + §8.11 频控参数）。
///
/// 全部为可注入纯逻辑：时钟（[CollectClock]）与睡眠（[Sleeper]）由外部提供，
/// 测试用假时钟免真等（test/collector/support.dart）。
library;

import 'dart:async';
import 'dart:collection';
import 'dart:math';

// ── §8.11 频控参数（间隔：匿名 1.5–3.0s / BDUSS 档 1.0–2.0s；预算：匿名 ≤300 / BDUSS 档 ≤600） ──

/// 单请求间隔下限（匿名 1.5s）。
const int kMinIntervalMs = 1500;

/// 单请求间隔上限（匿名 3.0s）。
const int kMaxIntervalMs = 3000;

/// 单请求间隔下限（BDUSS 档 1.0s；原型 §8.11 行 1633「间隔 1.0–2.0s」）。
const int kMinIntervalBdussMs = 1000;

/// 单请求间隔上限（BDUSS 档 2.0s）。
const int kMaxIntervalBdussMs = 2000;

/// 按账号档位取全局间隔区间（单点映射；装配点 = collect_service.dart 建
/// [GlobalRateLimiter] 时）。匿名档原样返回历史值（1.5–3.0s），请求节奏一字不变。
({int minMs, int maxMs}) intervalMsFor({required bool bdussImported}) =>
    bdussImported
        ? (minMs: kMinIntervalBdussMs, maxMs: kMaxIntervalBdussMs)
        : (minMs: kMinIntervalMs, maxMs: kMaxIntervalMs);

/// 每日请求总预算（匿名 ≤300；§8.11）。
const int kDailyBudgetAnonymous = 300;

/// 每日请求总预算（BDUSS 档 ≤600；原型 §8.11「每日请求总预算 ≤300 | ≤600」行 1633）。
const int kDailyBudgetBduss = 600;

/// 按账号档位取每日预算上限（null/空 = 匿名档，§8.11）。装配点：
/// collect_controller.dart（tiebaApiProvider 同源读 bdussProvider）。
int dailyBudgetFor(String? bduss) => (bduss == null || bduss.isEmpty)
    ? kDailyBudgetAnonymous
    : kDailyBudgetBduss;

/// 跨吧并发默认值（§8.8；两档相同）。
const int kDefaultConcurrency = 2;

/// 跨吧并发上限（匿名档 3；§8.8）。
const int kMaxConcurrencyAnonymous = 3;

/// 跨吧并发上限（BDUSS 档 4；需求 5「并发数也适当提高」——账号身份下适度放宽）。
const int kMaxConcurrencyBduss = 4;

/// 按账号档位取并发上限（单点映射：设置页 / 调度器 / CLI 三处共用）。
int maxConcurrencyFor({required bool bdussImported}) =>
    bdussImported ? kMaxConcurrencyBduss : kMaxConcurrencyAnonymous;

/// 单帖失败退避基数 30s×2ⁿ，重试 ≤3 次（§8.11）。
const int kMaxThreadRetries = 3;

/// 吧级连续失败 → 冷却阈值与时长（§8.11：≥3 → 48h）。
const int kForumFailureCooldown = 3;
const Duration kForumCooldownDuration = Duration(hours: 48);

/// 全局连续失败 → 整轮暂停阈值（§8.11/§8.12）。
const int kGlobalFailurePause = 3;

// ── 时钟 / 睡眠注入点 ────────────────────────────────────────────────────

typedef Sleeper = Future<void> Function(Duration d);

abstract interface class CollectClock {
  DateTime now();
}

class SystemClock implements CollectClock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

// ── 异常族（调度层统一语义） ─────────────────────────────────────────────

/// 请求失败类别（决定 last_status 落 rate_limited 还是 api_error，§8.12）。
enum CollectFailureKind {
  /// 429/403/110xxx/验证码页 —— 风控特征。
  rateLimited,

  /// errorno≠0 等非风控服务端错误。
  serverError,

  /// 超时/连接失败等网络异常。
  network,
}

/// 边界统一的请求异常（tieba_api.dart 把 TiebaClient 各异常映射到这里）。
class CollectRequestException implements Exception {
  const CollectRequestException({
    required this.kind,
    required this.message,
    this.code = 0,
  });

  final CollectFailureKind kind;
  final String message;

  /// errorno / HTTP 状态码（0=无）。
  final int code;

  bool get isRateLimited => kind == CollectFailureKind.rateLimited;

  @override
  String toString() =>
      'CollectRequestException(${kind.name}, code=$code, $message)';
}

/// 每日预算触顶（§8.11：当日停止，明日 0 点重置）。
class BudgetExhaustedException implements Exception {
  const BudgetExhaustedException(this.limit);

  final int limit;

  @override
  String toString() => 'BudgetExhaustedException(limit=$limit)';
}

/// 用户取消。
class CollectCanceledException implements Exception {
  const CollectCanceledException();

  @override
  String toString() => 'CollectCanceledException()';
}

/// 全局熔断（连续 3 败整轮暂停，§8.12）。
class GlobalPausedException implements Exception {
  const GlobalPausedException();

  @override
  String toString() => 'GlobalPausedException()';
}

/// 仅 Wi-Fi 设置不满足，阻止一次尚未发出的请求。
class NetworkGateBlockedException implements Exception {
  const NetworkGateBlockedException();
}

// ── Semaphore（§8.8：全局闸门，内部 Completer 等待队列） ─────────────────

class Semaphore {
  Semaphore(int permits) : _available = permits;

  int _available;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  int get available => _available;

  int get waiting => _waiters.length;

  Future<void> acquire() {
    if (_available > 0 && _waiters.isEmpty) {
      _available--;
      return Future<void>.value();
    }
    final Completer<void> c = Completer<void>();
    _waiters.add(c);
    return c.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
    } else {
      _available++;
    }
  }
}

// ── 每日请求预算（settings 持久计数，跨日重置；§8.11） ───────────────────

/// 读写 settings 的最小端口（避免 scheduler 依赖 repo 具体类型）。
abstract interface class BudgetStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

class DailyBudget {
  DailyBudget({
    required BudgetStore store,
    required CollectClock clock,
    this.limit = kDailyBudgetAnonymous,
    this.dateKey = 'collect_budget_date',
    this.countKey = 'collect_budget_count',
  })  : _store = store,
        _clock = clock;

  final BudgetStore _store;
  final CollectClock _clock;
  final int limit;
  final String dateKey;
  final String countKey;

  String? _date;
  int _count = 0;
  bool _loaded = false;

  /// 本轮是否已触顶（触顶后调度器停止发新请求）。
  bool get exhausted => _loaded && _count >= limit;

  int get used => _count;

  String _today() {
    final DateTime n = _clock.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year.toString().padLeft(4, '0')}-${two(n.month)}-${two(n.day)}';
  }

  /// 核算并消耗 1 个请求额度；触顶抛 [BudgetExhaustedException]。
  Future<void> consume() async {
    await _loadForToday();
    if (_count >= limit) throw BudgetExhaustedException(limit);
    _count++;
    await _store.write(dateKey, _date!);
    await _store.write(countKey, '$_count');
  }

  /// 先检查预算，避免额度耗尽后仍等待限速间隔。
  Future<void> ensureAvailable() async {
    await _loadForToday();
    if (_count >= limit) throw BudgetExhaustedException(limit);
  }

  Future<void> _loadForToday() async {
    final String today = _today();
    if (!_loaded || _date != today) {
      final String? storedDate = await _store.read(dateKey);
      final int storedCount =
          int.tryParse(await _store.read(countKey) ?? '') ?? 0;
      // 跨日重置（§8.11：明日 0 点重置，本地计数）。
      _count = storedDate == today ? storedCount : 0;
      _date = today;
      _loaded = true;
    }
  }
}

// ── 全局限速器（§8.8：单令牌桶按 IP 统一核算，抖动 = 出牌节奏） ──────────

/// 所有并发分支共享：**请求启动时刻**全局间隔 ≥ [minMs]..[maxMs] 均匀随机。
/// 每次 throttle 先做预算核算（[DailyBudget.consume]），触顶异常原样上抛。
class GlobalRateLimiter {
  GlobalRateLimiter({
    required CollectClock clock,
    required Sleeper sleeper,
    required Random rng,
    required DailyBudget budget,
    this.beforeStart,
    this.minMs = kMinIntervalMs,
    this.maxMs = kMaxIntervalMs,
  })  : _clock = clock,
        _sleeper = sleeper,
        _rng = rng,
        _budget = budget;

  final CollectClock _clock;
  final Sleeper _sleeper;
  final Random _rng;
  final DailyBudget _budget;
  final Future<void> Function()? beforeStart;
  final int minMs;
  final int maxMs;

  DateTime? _lastStart;
  Future<void> _tail = Future<void>.value();

  /// 排队等到自己的出牌时刻（串行化：链式 Completer，天然 FIFO）。
  Future<void> throttle() {
    final Future<void> prev = _tail;
    final Completer<void> slot = Completer<void>();
    _tail = slot.future;
    final Future<void> result = prev.then((_) => _takeSlot());
    // 无论成败都放行后继；派生 future 的 onError 必须挂接，
    // 否则预算触顶等错误会成为「未处理异步错误」污染测试 zone。
    result.then(
      (_) {
        if (!slot.isCompleted) slot.complete();
      },
      onError: (Object _) {
        if (!slot.isCompleted) slot.complete();
      },
    );
    return result;
  }

  Future<void> _takeSlot() async {
    await _budget.ensureAvailable();
    final int span = maxMs - minMs;
    final int intervalMs = minMs + (span > 0 ? _rng.nextInt(span + 1) : 0);
    final DateTime last = _lastStart ?? _clock.now().subtract(Duration(milliseconds: intervalMs));
    final DateTime earliest = last.add(Duration(milliseconds: intervalMs));
    final DateTime now = _clock.now();
    if (earliest.isAfter(now)) await _sleeper(earliest.difference(now));
    await beforeStart?.call();
    await _budget.consume(); // 网络拒绝的请求不占预算
    _lastStart = _clock.now();
  }
}

/// 退避时长：30s×2ⁿ（n=0,1,2 → 30/60/120s；§8.11）。
Duration retryBackoff(int attempt) =>
    Duration(seconds: 30 * (1 << attempt.clamp(0, 10)));

/// settings.concurrent_forums 解析：默认 2、钳制 [1, 档位上限]（§8.8；匿名上限 3 / BDUSS 档 4）。
int effectiveConcurrency(String? settingValue, {bool bdussImported = false}) {
  final int v = int.tryParse(settingValue ?? '') ?? kDefaultConcurrency;
  return v.clamp(1, maxConcurrencyFor(bdussImported: bdussImported));
}

/// 「登录态失效」文案特征（§8.10 失效检测；errorno ∈ [110000,111000) 的情况由 [isLoginInvalidError] 覆盖）。
const List<String> kLoginInvalidHints = <String>[
  '未登录',
  '请先登录',
  '登录失效',
  '登录已过期',
  'nologin',
  'not logged in',
];

/// 判定「账号登录态失效」（§8.10 自动降级口径）：[CollectFailureKind.rateLimited] 且
/// errorno ∈ [110000,111000)，或失败文案命中 [kLoginInvalidHints]。用法见
/// collect_service.dart `_downgradeToAnonymous`；匿名档的 429/验证码不会命中。
bool isLoginInvalidError(CollectRequestException e) {
  if (e.kind != CollectFailureKind.rateLimited) {
    return false;
  }
  if (e.code >= 110000 && e.code < 111000) {
    return true;
  }
  final String m = e.message.toLowerCase();
  return kLoginInvalidHints.any((String h) => m.contains(h.toLowerCase()));
}
