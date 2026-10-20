import 'package:flutter/widgets.dart';

import '../../collector/collect_state.dart';
import '../../theme/app_colors.dart';

// 采集中心展示格式化（单一出处；文案口径 = 设计稿 06 屏 index.html:1584–1660 与
// 原型 §5.9/§8.7）。全部纯函数，widget 测试可直接断言。

String _two(int v) => v.toString().padLeft(2, '0');

/// 水位展示 `YYYY-MM-DD HH:mm`（§5.9 '水位: 2026-10-11 18:32'）；0 = 冷启动 → '未采集'。
String formatWatermark(int epochSeconds) {
  if (epochSeconds <= 0) {
    return '未采集';
  }
  final DateTime d = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
  return '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';
}

/// logbox 时间列 `HH:mm:ss`（index.html:1642）。
String formatHms(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';

/// dtable / 最近日志时间列 `MM-dd HH:mm`（§5.9 '10-12 08:00'）。
String formatMonthDayTime(DateTime t) => '${_two(t.month)}-${_two(t.day)} ${_two(t.hour)}:${_two(t.minute)}';

/// dash-forums 冷却 sub `冷却至 HH:mm`（index.html:2854）。
String formatClock(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

/// 相对时间（§5.9 '上次: 成功 +37帖 · 2小时前'）。
String relativeTime(DateTime t, {DateTime? now}) {
  final Duration d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) {
    return '刚刚';
  }
  if (d.inMinutes < 60) {
    return '${d.inMinutes}分钟前';
  }
  if (d.inHours < 24) {
    return '${d.inHours}小时前';
  }
  return '${d.inDays}天前';
}

/// 冷却倒计时（设计稿 '冷却中 48m'，index.html:1615；≥1h → 'NhMm'，向上取整分钟）。
String cooldownRemain(DateTime until, {DateTime? now}) {
  final Duration d = until.difference(now ?? DateTime.now());
  if (d <= Duration.zero) {
    return '0m';
  }
  final int minutes = (d.inSeconds / 60).ceil();
  if (minutes < 60) {
    return '${minutes}m';
  }
  return '${minutes ~/ 60}h${_two(minutes % 60)}m';
}

/// collection_state.last_status 中文映射（§7.2：never/ok/partial/api_error/rate_limited/canceled）。
String lastStatusLabel(String status) => switch (status) {
  'ok' => '成功',
  'api_error' => '接口异常',
  'rate_limited' => '冷却中',
  'partial' => '部分成功',
  'canceled' => '已取消',
  _ => '未采集',
};

/// 运行态单吧状态中文（dash-forums / 日志徽标兜底）。
String forumStatusLabel(ForumStatus status) => switch (status) {
  ForumStatus.queued => '排队中',
  ForumStatus.listing => '拉帖列表',
  ForumStatus.parsing => '解析楼层',
  ForumStatus.ingesting => '入库',
  ForumStatus.done => '完成',
  ForumStatus.cooldown => '冷却中',
  ForumStatus.failed => '失败',
  ForumStatus.canceled => '已取消',
};

/// ①②③④ 展示序号（契约 CollectStep.number 同源）。
const List<String> kStepCircled = <String>['①', '②', '③', '④'];

String stepCircled(CollectStep step) => kStepCircled[step.index];

/// 步骤标题（设计稿 steps index.html:1635–1638）。
String stepTitle(CollectStep step) => switch (step) {
  CollectStep.list => '拉帖列表',
  CollectStep.parse => '解析楼层 + 分类',
  CollectStep.ingest => '入库 / 重建 FTS',
  CollectStep.summary => '完成汇总',
};

/// 步骤短名（dash-forums sub '② 解析楼层 · …'，index.html:2850）。
String stepShortTitle(CollectStep step) => switch (step) {
  CollectStep.list => '拉帖列表',
  CollectStep.parse => '解析楼层',
  CollectStep.ingest => '入库',
  CollectStep.summary => '汇总',
};

/// 步骤小标题行（设计稿原文；active 步骤以运行态 stepDetail 替换动态段）。
String stepSubtitle(CollectStep step, {bool active = false, String detail = ''}) {
  final bool inject = active && detail.isNotEmpty;
  return switch (step) {
    CollectStep.list => inject
        ? 'get_threads · $detail · 增量 tid > 水位'
        : 'get_threads · pn 1→18 · 增量 tid > 水位',
    CollectStep.parse => 'PbContent 拼装 · post_kind 分类器'
        ' · ${inject ? detail : 'tid 7/37'}',
    CollectStep.ingest => 'drift 事务 · trigram 索引增量',
    CollectStep.summary => '首页出现「自采」徽标新扫书',
  };
}

/// 主卡 caption '步骤 ① 拉帖列表 · pn 12/18 · 并发 2'（index.html:1613）。
String runningCaption(ForumRunState forum, int concurrency) {
  final String head = '步骤 ${stepCircled(forum.step)} ${stepTitle(forum.step)}';
  final String detail = forum.stepDetail.isEmpty ? '' : ' · ${forum.stepDetail}';
  return '$head$detail · 并发 $concurrency';
}

/// logbox / dtable 级别语义色（index.html:511–514：默认正文 / .ok 绿 / .warn 红 / .acc 强调）。
Color logLevelColor(BuildContext context, CollectLogLevel level) {
  final AppColors c = AppColors.of(context);
  return switch (level) {
    CollectLogLevel.info => c.textSecondary,
    CollectLogLevel.ok => c.recommend,
    CollectLogLevel.warn => c.danger,
    CollectLogLevel.accent => c.accentStrong,
  };
}
