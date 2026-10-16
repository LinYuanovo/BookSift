/// 水位机制（§8.7：collection_state.last_thread_time / last_tid）。
///
/// **不是**“先拉全量帖子再按日期差筛”：[CollectService] 按 get_threads 的
/// create_time 倒序逐页拉取，页内用 [isNewerThanWatermark] 逐条比较；
/// 首次遇到不新于水位的帖子后，扫完当前页即停止（增量最多 5 页；冷启动水位=0
/// 只回看最近 2 页）。水位推进只取本轮按时间升序的连续成功前缀，见 [advancePrefix]。
library;

import 'tieba/src/models.dart';

/// 每吧水位快照（epoch 秒 + 同秒次序键 tid）。
class Watermark {
  const Watermark(this.lastThreadTime, this.lastTid);

  final int lastThreadTime;
  final int lastTid;

  /// 冷启动（水位=0）：只回溯最近 2 页（§8.7 步骤 7）。
  bool get isCold => lastThreadTime == 0;
}

/// 增量判定（§8.7 步骤 2）：`create_time > last_thread_time`
/// 或（`== last_thread_time` 且 `tid > last_tid`）。
bool isNewerThanWatermark(ThreadSummary t, Watermark w) =>
    t.createTime > w.lastThreadTime ||
    (t.createTime == w.lastThreadTime && t.tid > w.lastTid);

/// 待采队列排序（§8.7 步骤 4：按 create_time 升序；同秒按 tid 升序稳定）。
void sortQueueAscending(List<ThreadSummary> queue) => queue.sort(
      (ThreadSummary a, ThreadSummary b) {
        final int c = a.createTime.compareTo(b.createTime);
        return c != 0 ? c : a.tid.compareTo(b.tid);
      },
    );

/// partial 水位推进（关键决策，任务书要求写入注释与报告）：
///
/// §8.7 原文是「只在整批事务成功提交后推进」，但单帖重试耗尽会让水位被一个
/// 坏帖（如已删除/超长异常帖）永久卡死。口径折中：**水位推进到按 create_time
/// 升序的连续成功前缀**——前缀内每帖都已单事务落库（满足「已成功才推进」的
/// 幂等保证），前缀之后的失败帖保留给下轮重试（重入不重复：posts.tid UNIQUE +
/// content_hash UNIQUE 兜底）；失败帖之后的已成功帖本轮不推水位，下轮重拉由
/// 去重跳过（skippedDup），不会重复入库。
///
/// 返回 null = 前缀为空（不推进）。cancel / 网络断（全局暂停）不走本函数
/// （水位不动，§8.7）。
Watermark? advancePrefix(
  List<ThreadSummary> ascendingQueue,
  bool Function(ThreadSummary t) succeeded,
  Watermark from,
) {
  int time = from.lastThreadTime;
  int tid = from.lastTid;
  bool moved = false;
  for (final ThreadSummary t in ascendingQueue) {
    if (!succeeded(t)) break; // 首个非成功即停（连续前缀）
    if (t.createTime > time || (t.createTime == time && t.tid > tid)) {
      time = t.createTime;
      tid = t.tid;
      moved = true;
    }
  }
  return moved ? Watermark(time, tid) : null;
}
