/// 调试演示快照（M2-① 视觉验收夹具）。
///
/// **用途**：无网络环境下验收「采集进度页」全部视觉区块（设计稿 06 屏
/// index.html:1584–1660 / W5t 2806–2905 / W5d 3400–3495 的示例数据原样复刻），
/// 同时供 widget 测试复用为运行态夹具。
///
/// **门控**：唯一 UI 调用点在 CollectPage AppBar「匿名模式」徽标的长按手势，
/// 且以 `kDebugMode` 常量门控 —— release 构建整条注入路径被树摇掉。
/// 数据本身为纯不可变对象（契约 collect_state.dart），不含任何 IO。
library;

import '../../collector/collect_state.dart';

int _epoch(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

/// 设计稿演示态：68% · yy小说吧 ②解析（pn 12/18）· 哀伤雪刃 429 冷却 48m（22%）·
/// 六格 +37/+212/+58/12/4/9 · 水位 2026-10-11 18:32 → 2026-10-12 08:12 · 7 行示例日志。
CollectRunState debugDemoRunState({DateTime? now}) {
  final DateTime base = now ?? DateTime.now();
  const CollectStats totals = CollectStats(
    threadsAdded: 37,
    floorsAdded: 212,
    entriesAdded: 58,
    skippedDup: 12,
    discardedChat: 4,
    mineThreads: 9,
  );
  return CollectRunState(
    phase: CollectPhase.running,
    startedAt: DateTime(2026, 10, 12, 8, 0, 0),
    overallProgress: 0.68,
    globalStep: CollectStep.parse,
    totals: totals,
    forums: <ForumRunState>[
      ForumRunState(
        fname: 'yy小说吧',
        status: ForumStatus.parsing,
        step: CollectStep.parse,
        stepProgress: 7 / 37,
        stepDetail: 'pn 12/18',
        overallProgress: 0.68,
        watermarkFrom: _epoch(DateTime(2026, 10, 11, 18, 32)),
        watermarkTarget: _epoch(DateTime(2026, 10, 12, 8, 12)),
        stats: totals,
      ),
      ForumRunState(
        fname: '哀伤雪刃',
        status: ForumStatus.cooldown,
        step: CollectStep.parse,
        overallProgress: 0.22, // index.html:1616 data-bar="22"
        cooldownUntil: base.add(const Duration(minutes: 48)),
        watermarkFrom: _epoch(DateTime(2026, 10, 10, 9, 15)),
      ),
    ],
    // 设计稿 06 屏 logbox 7 行原样（index.html:1642–1648；event 词汇按契约
    // 「开始/拉列表/分类/入库/频控」口径，与 W5t dtable 事件列一致）。
    logs: <CollectLogEntry>[
      CollectLogEntry(
        time: DateTime(2026, 10, 12, 8, 12, 44),
        fname: 'yy小说吧',
        event: '拉列表',
        detail: 'pn=12/18 · 新帖 3',
        level: CollectLogLevel.accent,
      ),
      CollectLogEntry(
        time: DateTime(2026, 10, 12, 8, 12, 3),
        fname: 'yy小说吧',
        event: '分类',
        detail: 'tid=11097754039 → 扫书 (书名数=3≥3)',
        level: CollectLogLevel.ok,
      ),
      CollectLogEntry(
        time: DateTime(2026, 10, 12, 8, 11, 58),
        fname: 'yy小说吧',
        event: '分类',
        detail: 'tid=11098706149 → 排雷 (首楼~避雷)',
        level: CollectLogLevel.warn,
      ),
      CollectLogEntry(
        time: DateTime(2026, 10, 12, 8, 11, 40),
        fname: 'yy小说吧',
        event: '分类',
        detail: 'tid=11098448201 → 排雷 (首楼~毒点)',
        level: CollectLogLevel.warn,
      ),
      CollectLogEntry(
        time: DateTime(2026, 10, 12, 8, 11, 22),
        fname: 'yy小说吧',
        event: '入库',
        detail: '+9 楼层 → book_entry ×4',
      ),
      CollectLogEntry(
        time: DateTime(2026, 10, 12, 8, 10, 12),
        fname: '哀伤雪刃',
        event: '频控',
        detail: '429 → 冷却 48m · 不影响其余吧',
        level: CollectLogLevel.warn,
      ),
      CollectLogEntry(
        time: DateTime(2026, 10, 12, 8, 0, 0),
        fname: '全局',
        event: '开始',
        detail: '并发=2 · 匿名 · 仅WiFi',
        level: CollectLogLevel.accent,
      ),
    ],
  );
}
