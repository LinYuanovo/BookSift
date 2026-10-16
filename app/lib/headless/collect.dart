/// Headless 采集驱动：把 [CollectService] 在**无 Flutter** 环境下组装起来。
///
/// [CollectService] 本体是纯 Dart 且全依赖注入（见其构造函数），所以这里不复制任何
/// 编排逻辑，只做接线：db/repo/api/worker/时钟 → 服务，服务日志 → [RunLog] 结构化落盘。
///
/// **合规**（AGENTS.md §6）：本层不做任何门控——[plan] 零请求，[run] 一定发真请求。
/// 「是否允许发请求」由调用方（CLI）把关，见 `bin/booksift.dart` 的 `--net` + 环境变量双闸。
library;

import '../classify/classifier.dart';
import '../collector/collect_service.dart';
import '../collector/collect_settings_keys.dart';
import '../collector/collect_state.dart';
import '../collector/scheduler.dart';
import '../collector/tieba_api.dart';
import '../collector/worker.dart';
import '../core/constants.dart';
import '../data/db/app_database.dart';
import '../data/repo/collect_repository.dart';
import 'logs.dart';
import 'query.dart';

/// 采集计划（零请求产物：当前水位 + 预算余量 + 将参与本轮的吧）。
class CollectPlan {
  const CollectPlan({
    required this.forums,
    required this.enabledForums,
    required this.coolingForums,
    required this.budgetDate,
    required this.budgetUsed,
    required this.budgetLimit,
    required this.concurrentForums,
    required this.wifiOnly,
    this.bdussImported = false,
  });

  /// 全部关注吧水位。
  final List<ForumWatermark> forums;

  /// 本轮会参与的吧名（enabled 且不在冷却）。
  final List<String> enabledForums;

  /// 冷却中、本轮跳过的吧名。
  final List<String> coolingForums;

  final String? budgetDate;
  final int budgetUsed;
  final int budgetLimit;
  final int concurrentForums;
  final bool wifiOnly;

  /// 本轮账号档：true = 走 BDUSS（间隔 1.0–2.0s / 并发上限 4）。
  final bool bdussImported;

  int get budgetRemaining => (budgetLimit - budgetUsed).clamp(0, budgetLimit);

  /// 本轮实际全局限速区间（按账号档位取，与 CollectService 同源）。
  int get minIntervalMs => intervalMsFor(bdussImported: bdussImported).minMs;
  int get maxIntervalMs => intervalMsFor(bdussImported: bdussImported).maxMs;

  Map<String, Object?> toJson() => <String, Object?>{
        'forums': forums.map((ForumWatermark f) => f.toJson()).toList(),
        'enabledForums': enabledForums,
        'coolingForums': coolingForums,
        'budget': <String, Object?>{
          'date': budgetDate,
          'used': budgetUsed,
          'limit': budgetLimit,
          'remaining': budgetRemaining,
        },
        'concurrentForums': concurrentForums,
        'wifiOnly': wifiOnly,
        'accountTier': bdussImported ? 'bduss' : 'anonymous',
        'minIntervalMs': minIntervalMs,
        'maxIntervalMs': maxIntervalMs,
      };
}

/// 一轮采集的结果摘要（[CollectRunState] 的机读投影）。
class CollectRunSummary {
  const CollectRunSummary({
    required this.phase,
    required this.startedAt,
    required this.finishedAt,
    required this.banner,
    required this.totals,
    required this.forums,
    required this.logCount,
  });

  factory CollectRunSummary.of(CollectRunState s, {required int logCount}) =>
      CollectRunSummary(
        phase: s.phase.name,
        startedAt: s.startedAt,
        finishedAt: s.finishedAt,
        banner: s.banner,
        totals: <String, int>{
          'threadsAdded': s.totals.threadsAdded,
          'floorsAdded': s.totals.floorsAdded,
          'entriesAdded': s.totals.entriesAdded,
          'skippedDup': s.totals.skippedDup,
          'discardedChat': s.totals.discardedChat,
          'mineThreads': s.totals.mineThreads,
        },
        forums: <Map<String, Object?>>[
          for (final ForumRunState f in s.forums)
            <String, Object?>{
              'fname': f.fname,
              'status': f.status.name,
              'step': f.step.name,
              'overallProgress': f.overallProgress,
              'watermarkFrom': f.watermarkFrom,
              'watermarkTarget': f.watermarkTarget,
              'error': f.error,
              'cooldownUntil': f.cooldownUntil?.toIso8601String(),
              'stats': <String, int>{
                'threadsAdded': f.stats.threadsAdded,
                'floorsAdded': f.stats.floorsAdded,
                'entriesAdded': f.stats.entriesAdded,
                'skippedDup': f.stats.skippedDup,
                'discardedChat': f.stats.discardedChat,
                'mineThreads': f.stats.mineThreads,
              },
            },
        ],
        logCount: logCount,
      );

  final String phase;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  /// 降级横幅（如「贴吧接口似乎已变更」）；null = 无。
  final String? banner;
  final Map<String, int> totals;
  final List<Map<String, Object?>> forums;

  /// 本轮逐条日志总数（未被 200 条上限裁剪的真实计数）。
  final int logCount;

  Map<String, Object?> toJson() => <String, Object?>{
        'phase': phase,
        'startedAt': startedAt?.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
        'banner': banner,
        'totals': totals,
        'forums': forums,
        'logCount': logCount,
      };
}

/// 一轮采集的结果（状态快照 + 机读摘要 + 逐条日志真实计数）。
class CollectRunResult {
  const CollectRunResult({
    required this.state,
    required this.summary,
    required this.logCount,
  });

  /// 整轮结束时的最终快照。
  final CollectRunState state;

  final CollectRunSummary summary;

  /// 本轮采集逐条日志数（不受 UI 快照 200 条上限裁剪）。
  final int logCount;
}

/// headless 采集入口（无状态）。
abstract final class HeadlessCollect {
  /// 生成计划：只读 db，**零网络请求**。
  static Future<CollectPlan> plan({
    required AppDatabase db,
    int budgetLimit = kDailyBudgetAnonymous,
    String? bduss,
  }) async {
    final CollectRepository repo = CollectRepository(db);
    final List<CollectionStateEntry> rows = await repo.forums();
    final DateTime now = DateTime.now();
    final List<String> cooling = <String>[];
    final List<String> enabled = <String>[];
    for (final CollectionStateEntry e in rows) {
      if (!e.enabled) {
        continue;
      }
      if (e.cooldownUntil != null && e.cooldownUntil!.isAfter(now)) {
        cooling.add(e.fname);
      } else {
        enabled.add(e.fname);
      }
    }
    final String? budgetDate = await repo.getSetting(CollectSettingsKeys.budgetDate);
    final int budgetUsed =
        int.tryParse(await repo.getSetting(CollectSettingsKeys.budgetCount) ?? '') ?? 0;
    final bool bdussImported = (bduss ?? '').isNotEmpty;
    final int concurrent = effectiveConcurrency(
      await repo.getSetting(SettingsKeys.concurrentForums),
      bdussImported: bdussImported,
    );
    final bool wifiOnly =
        (await repo.getSetting(SettingsKeys.wifiOnly) ?? 'false') == 'true';
    return CollectPlan(
      forums: rows.map(ForumWatermark.of).toList(growable: false),
      enabledForums: enabled,
      coolingForums: cooling,
      budgetDate: budgetDate,
      budgetUsed: budgetUsed,
      budgetLimit: budgetLimit,
      concurrentForums: concurrent,
      wifiOnly: wifiOnly,
      bdussImported: bdussImported,
    );
  }

  /// 跑一轮增量采集（**真网络请求**；调用方须自行门控）。
  ///
  /// [dictLines] 为 v3 书名词典行（空表 → 退化 v2）；[api] 缺省用生产
  /// [ProtoTiebaApi]；[useIsolateWorker]=false 时用同 isolate 的 [LocalPostWorker]
  /// （栈更直观，排错分类问题时更好用）。
  ///
  /// 返回整轮结束后的状态快照；逐条日志已经 [RunLog] 落盘，不受 200 条上限影响。
  static Future<CollectRunResult> run({
    required AppDatabase db,
    required RunLog log,
    required List<String> dictLines,
    TiebaApi? api,
    int budgetLimit = kDailyBudgetAnonymous,
    String? bduss,
    bool useIsolateWorker = true,
    CollectClock clock = const SystemClock(),
    Sleeper? sleeper,
    NetworkGate networkGate = const AlwaysAllowNetworkGate(),
  }) async {
    final bool bdussImported = (bduss ?? '').isNotEmpty;
    final ProtoTiebaApi? owned = api == null ? ProtoTiebaApi(bduss: bduss) : null;
    final TiebaApi effective = api ?? owned!;
    final CollectRepository repo = CollectRepository(db);
    CollectRunState latest = const CollectRunState.idle();
    int logCount = 0;
    String lastSig = '';

    // 同 isolate 兜底用的分类器（词典只建一次；isolate 路径由 worker 内部自建）。
    final BookDict dict = BookDict.fromLines(dictLines);
    ClassifyResult classify({
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

    final CollectService service = CollectService(
      db: db,
      repo: repo,
      api: effective,
      workerFactory: () async => useIsolateWorker
          ? IsolatePostWorker.spawn(dictLines: dictLines)
          : LocalPostWorker(classify),
      onState: (CollectRunState s) {
        latest = s;
        // 快照每步都发，日志只记「相位/步骤/进度」变化，避免刷屏。
        final String sig = <String>[
          s.phase.name,
          s.globalStep?.name ?? '-',
          s.overallProgress.toStringAsFixed(2),
          for (final ForumRunState f in s.forums) '${f.fname}:${f.status.name}:${f.step.name}',
        ].join('|');
        if (sig != lastSig) {
          lastSig = sig;
          log.emit(
            'global',
            '进度',
            detail: '相位=${s.phase.name} 总进度=${(s.overallProgress * 100).toStringAsFixed(0)}%',
            data: <String, Object?>{
              'phase': s.phase.name,
              'overallProgress': s.overallProgress,
              'globalStep': s.globalStep?.name,
              'forums': <Map<String, Object?>>[
                for (final ForumRunState f in s.forums)
                  <String, Object?>{
                    'fname': f.fname,
                    'status': f.status.name,
                    'step': f.step.name,
                    'stepDetail': f.stepDetail,
                    'progress': f.overallProgress,
                  },
              ],
            },
          );
        }
      },
      onLog: (CollectLogEntry entry) {
        logCount++;
        log.emitCollect(entry);
      },
      budgetLimit: budgetLimit,
      bdussImported: bdussImported,
      // 账号档专用：登录态失效 → 本轮换匿名客户端（CLI 无凭证落盘，
      // 失效提示由 CollectService 的「降级」日志承担）。
      anonymousApiFactory: bdussImported ? ProtoTiebaApi.new : null,
      clock: clock,
      sleeper: sleeper,
      networkGate: networkGate,
    );

    try {
      await service.run();
      await service.completion;
    } finally {
      owned?.close();
    }

    final CollectRunSummary summary = CollectRunSummary.of(latest, logCount: logCount);
    log.emit(
      'global',
      '汇总',
      detail: '相位=${latest.phase.name} 日志 $logCount 条'
          '${latest.banner == null ? '' : ' 横幅=${latest.banner}'}',
      level: latest.banner == null ? RunLevel.ok : RunLevel.warn,
      data: summary.toJson(),
    );
    return CollectRunResult(state: latest, summary: summary, logCount: logCount);
  }
}
