/// 水位纯函数单测（§8.7 增量判定 + partial 连续成功前缀推进）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/collector/tieba/src/models.dart';
import 'package:booksift/collector/watermark.dart';

import 'support.dart';

void main() {
  group('isNewerThanWatermark（§8.7 步骤 2 增量判定）', () {
    const Watermark wm = Watermark(200, 50);

    test('create_time 更大 → 命中', () {
      expect(isNewerThanWatermark(mkThread(tid: 1, createTime: 201), wm), true);
    });
    test('create_time 相等且 tid 更大 → 命中（同秒次序键）', () {
      expect(isNewerThanWatermark(mkThread(tid: 51, createTime: 200), wm), true);
    });
    test('create_time 相等且 tid 不更大 → 不命中', () {
      expect(isNewerThanWatermark(mkThread(tid: 50, createTime: 200), wm), false);
      expect(isNewerThanWatermark(mkThread(tid: 9, createTime: 200), wm), false);
    });
    test('create_time 更小 → 不命中', () {
      expect(isNewerThanWatermark(mkThread(tid: 999, createTime: 199), wm), false);
    });
    test('冷启动（水位 0）一切皆新', () {
      expect(
          isNewerThanWatermark(mkThread(tid: 1, createTime: 1), const Watermark(0, 0)),
          true);
      expect(const Watermark(0, 0).isCold, true);
    });
  });

  group('sortQueueAscending（§8.7 步骤 4）', () {
    test('create_time 升序、同秒按 tid 升序', () {
      final List<ThreadSummary> q = <ThreadSummary>[
        mkThread(tid: 3, createTime: 300),
        mkThread(tid: 2, createTime: 100),
        mkThread(tid: 20, createTime: 200),
        mkThread(tid: 10, createTime: 200),
        mkThread(tid: 1, createTime: 100),
      ];
      sortQueueAscending(q);
      expect(q.map((ThreadSummary t) => t.tid).toList(), <int>[1, 2, 10, 20, 3]);
    });
  });

  group('advancePrefix（partial 水位推进口径）', () {
    final List<ThreadSummary> queue = <ThreadSummary>[
      mkThread(tid: 1, createTime: 100),
      mkThread(tid: 2, createTime: 200),
      mkThread(tid: 3, createTime: 300),
    ];

    test('全部成功 → 推进到队尾', () {
      final Watermark? w = advancePrefix(queue, (_) => true, const Watermark(0, 0));
      expect(w, isNotNull);
      expect(w!.lastThreadTime, 300);
      expect(w.lastTid, 3);
    });
    test('中间失败 → 只推进到连续成功前缀（T3 已入库也不越过坏帖）', () {
      final Watermark? w = advancePrefix(
          queue, (ThreadSummary t) => t.tid != 2, const Watermark(0, 0));
      expect(w!.lastThreadTime, 100);
      expect(w.lastTid, 1);
    });
    test('首帖即失败 → 不推进（null）', () {
      final Watermark? w = advancePrefix(
          queue, (ThreadSummary t) => t.tid != 1, const Watermark(0, 0));
      expect(w, isNull);
    });
    test('空队列 → 不推进', () {
      expect(advancePrefix(<ThreadSummary>[], (_) => true, const Watermark(5, 5)),
          isNull);
    });
    test('不回退：成功前缀都旧于现水位 → null', () {
      final Watermark? w =
          advancePrefix(queue, (_) => true, const Watermark(999, 999));
      expect(w, isNull);
    });
  });
}
