/// 贴吧在线结果排序（P2-5）：相关度 = 接口返回原序 / 时间 = 客户端按 createTime 倒序稳定重排。
///
/// 分组与边界（TESTING.md §1/§3）：
///  · 「sortOnlineThreads」plain test() —— 纯函数：倒序 / 稳定性 / 相关度原样返回；
///  · 「在线排序 UI」testWidgets —— 脚本化 dio adapter（复用 online_search_test.dart 定义，
///    零真实网络），断言切档只重排**已加载**结果、不重新发请求，且取数固定 sm=0
///    （接口原生支持 sm 排序，但切档不重发请求 → 一律客户端重排，口径见
///    search_state.dart 的 onlineSortProvider 段注释）。
library;

import 'package:booksift/collector/tieba_search.dart';
import 'package:booksift/features/home/cards.dart';
import 'package:booksift/features/search/search_state.dart';
import 'package:dio/dio.dart' show ResponseBody;
import 'package:flutter_test/flutter_test.dart';

import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import '../support/harness.dart';
import 'online_search_test.dart'
    show
        ScriptedAdapter,
        gotoOnlineAndSearch,
        jsonBody,
        kQuery,
        onlineApp,
        pageInfo,
        postItem,
        searchJson,
        searchRoute;

OnlineThread th(int tid, int time) => OnlineThread(
      tid: tid,
      title: '帖$tid',
      forumName: 'yy小说吧',
      author: '扫书人甲',
      replyNum: 0,
      createTime: time,
    );

List<int> tidsOf(List<OnlineThread> rows) => <int>[for (final OnlineThread t in rows) t.tid];

/// 在线结果卡标题的屏幕序（y 升序）= 列表序。
List<String> titleOrder(WidgetTester tester, List<String> titles) {
  final List<(double, String)> rows = <(double, String)>[
    for (final String title in titles) (tester.getTopLeft(find.text(title)).dy, title),
  ]..sort(((double, String) a, (double, String) b) => a.$1.compareTo(b.$1));
  return <String>[for (final (double, String) row in rows) row.$2];
}

void main() {
  // ── 纯函数（plain test） ────────────────────────────────────────────────

  group('sortOnlineThreads（客户端重排口径）', () {
    test('相关度档 = 接口返回原序（同一 List 实例，不复制不重排）', () {
      final List<OnlineThread> rows = <OnlineThread>[th(1, 100), th(2, 900), th(3, 500)];
      expect(identical(sortOnlineThreads(rows, OnlineSort.relevance), rows), isTrue);
    });

    test('时间档 = createTime 倒序', () {
      final List<OnlineThread> rows = <OnlineThread>[th(1, 100), th(2, 900), th(3, 500)];
      expect(tidsOf(sortOnlineThreads(rows, OnlineSort.time)), <int>[2, 3, 1]);
    });

    test('时间档稳定：同时间保持接口原序；无时间（createTime=0）行沉底且彼此保序', () {
      final List<OnlineThread> rows = <OnlineThread>[th(1, 0), th(2, 500), th(3, 500), th(4, 0), th(5, 900)];
      // Dart List.sort 不保证稳定 → 以原序 index 做 tie-break。
      expect(tidsOf(sortOnlineThreads(rows, OnlineSort.time)), <int>[5, 2, 3, 1, 4]);
    });

    test('空/单行列表原样返回（不构造新 List）', () {
      final List<OnlineThread> one = <OnlineThread>[th(1, 100)];
      expect(identical(sortOnlineThreads(one, OnlineSort.time), one), isTrue);
      expect(sortOnlineThreads(const <OnlineThread>[], OnlineSort.time), isEmpty);
    });

    test('排序档标签 = 相关度 / 时间', () {
      expect(onlineSortLabel(OnlineSort.relevance), '相关度');
      expect(onlineSortLabel(OnlineSort.time), '时间');
    });
  });

  // ── UI（testWidgets：脚本化 dio，零真实网络） ─────────────────────────────

  group('在线排序 UI', () {
    late FakeBookRepository repo;
    setUp(() => repo = FakeBookRepository(library: demoLibrary()));

    testWidgets('排序行两个 chip（选中态随档切换）；切档只重排已加载结果，请求数不变且 sm=0',
        (WidgetTester tester) async {
      final ScriptedAdapter adapter = ScriptedAdapter(<ResponseBody>[
        jsonBody(searchJson(
          posts: <Map<String, dynamic>>[
            postItem(tid: 1, title: '较旧帖', time: 1700000000),
            postItem(tid: 2, title: '较新帖', time: 1760000000),
            postItem(tid: 3, title: '中间帖', time: 1730000000),
          ],
          page: pageInfo(hasMore: 0, totalCount: 3),
        )),
      ]);
      useSurface(tester);
      await tester.pumpWidget(onlineApp(repo, adapter, initial: searchRoute(kQuery)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('贴吧在线'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(CountChip, '时间'), findsNothing, reason: '无已加载结果 → 不出排序行');

      await tester.tap(find.text('搜索贴吧'));
      await tester.pumpAndSettle();

      const List<String> titles = <String>['较旧帖', '较新帖', '中间帖'];
      expect(adapter.requests, hasLength(1));
      // 取数固定 sm=0（接口原序 = 相关度基线）；排序一律客户端重排，切档不再发请求。
      expect(Uri.splitQueryString(adapter.bodies.single)['sm'], '0');

      expect(find.widgetWithText(CountChip, '相关度'), findsOneWidget);
      expect(find.widgetWithText(CountChip, '时间'), findsOneWidget);
      expect(tester.widget<CountChip>(find.widgetWithText(CountChip, '相关度')).selected, isTrue);
      expect(tester.widget<CountChip>(find.widgetWithText(CountChip, '时间')).selected, isFalse);
      expect(titleOrder(tester, titles), titles, reason: '相关度 = 接口返回原序');

      await tester.tap(find.widgetWithText(CountChip, '时间'));
      await tester.pumpAndSettle();
      expect(tester.widget<CountChip>(find.widgetWithText(CountChip, '时间')).selected, isTrue);
      expect(tester.widget<CountChip>(find.widgetWithText(CountChip, '相关度')).selected, isFalse);
      expect(titleOrder(tester, titles), <String>['较新帖', '中间帖', '较旧帖'], reason: '客户端按时间倒序');
      expect(adapter.requests, hasLength(1), reason: '切档纯客户端重排，不重新发请求');

      await tester.tap(find.widgetWithText(CountChip, '相关度'));
      await tester.pumpAndSettle();
      expect(titleOrder(tester, titles), titles, reason: '切回相关度 = 还原接口原序');
      expect(adapter.requests, hasLength(1));
    });

    testWidgets('跨页：加载更多后切「时间」→ 已加载两页一并倒序（仍只有 2 个请求）',
        (WidgetTester tester) async {
      final ScriptedAdapter adapter = ScriptedAdapter(<ResponseBody>[
        jsonBody(searchJson(
          posts: <Map<String, dynamic>>[
            postItem(tid: 1, title: '第一页旧帖', time: 1700000000),
            postItem(tid: 2, title: '第一页新帖', time: 1750000000),
          ],
          page: pageInfo(hasMore: 1, currentPage: 1, totalPage: 2),
        )),
        jsonBody(searchJson(
          posts: <Map<String, dynamic>>[postItem(tid: 3, title: '第二页最新帖', time: 1760000000)],
          page: pageInfo(hasMore: 0, currentPage: 2, totalPage: 2),
        )),
      ]);
      useSurface(tester);
      await tester.pumpWidget(onlineApp(repo, adapter, initial: searchRoute(kQuery)));
      await tester.pumpAndSettle();
      await gotoOnlineAndSearch(tester);

      const List<String> titles = <String>['第一页旧帖', '第一页新帖', '第二页最新帖'];
      expect(
        titleOrder(tester, titles.sublist(0, 2)),
        titles.sublist(0, 2),
        reason: '默认相关度 = 接口返回原序',
      );
      expect(find.text(titles[2]), findsNothing, reason: '第二页尚未加载');

      await tester.tap(find.text('加载更多'));
      await tester.pumpAndSettle();
      expect(adapter.requests, hasLength(2));
      expect(find.text('3 条'), findsOneWidget);

      await tester.tap(find.widgetWithText(CountChip, '时间'));
      await tester.pumpAndSettle();
      expect(
        titleOrder(tester, titles),
        <String>['第二页最新帖', '第一页新帖', '第一页旧帖'],
        reason: '重排覆盖全部已加载行（含追加页）',
      );
      expect(adapter.requests, hasLength(2), reason: '切档不重新发请求');
    });
  });
}
