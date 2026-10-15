/// 贴吧在线搜索真实冒烟（env 门控 `BOOKSIFT_ONLINE_SMOKE=1`；默认 skip）。
///
/// **必须独立成文件、只含 plain test()**：同一 suite 里出现 testWidgets 后，
/// TestWidgetsFlutterBinding 会把真实 HttpClient 全局替换为恒 400（零真实网络），
/// 冒烟永远到不了 tiebac.baidu.com —— 本仓实测（flutter test 的 Warning 原文）。
///
/// 口径：≤1 请求；生产节流 1.5~3.0s 由 [TiebaSearchClient] 自带（§8.11 匿名档）；
/// 结束打印 [RiskMonitor] 计数（验收：totalAnomalies==0 = 风控观察为零）。
library;

import 'dart:io' show Platform;

import 'package:booksift/collector/tieba_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bool enabled = Platform.environment['BOOKSIFT_ONLINE_SMOKE'] == '1';

  test(
    'searchpost 真实响应 + 风控计数（单请求，匿名 app-form + sign）',
    () async {
      final TiebaSearchClient client = TiebaSearchClient(); // 生产节流 1.5~3.0s
      try {
        final OnlineSearchPage page = await client.search('yy小说吧', '十日终焉', rn: 10);
        // ignore: avoid_print
        print('smoke: threads=${page.threads.length} hasMore=${page.hasMore} '
            'currentPage=${page.currentPage} totalPage=${page.totalPage} '
            'totalCount=${page.totalCount}');
        for (final OnlineThread t in page.threads.take(3)) {
          // ignore: avoid_print
          print('  · [${t.tid}] ${t.title} @${t.forumName} by ${t.author} '
              'replies=${t.replyNum} time=${t.createTime}');
        }
        expect(client.risk.requests, 1);
        expect(client.risk.totalAnomalies, 0, reason: '风控观察为零口径（§8.11）');
        expect(page.threads, isNotEmpty,
            reason: '「十日终焉」在 yy小说吧 应有命中；为空 = 接口行为已变，需人工复核');
      } finally {
        // 失败路径也报告风控计数（冒烟交付物）。
        // ignore: avoid_print
        print('smoke risk: ${client.risk.toJson()}');
        client.close();
      }
    },
    skip: enabled ? false : '需 BOOKSIFT_ONLINE_SMOKE=1（真实网络；勿与 testWidgets 混 suite）',
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
