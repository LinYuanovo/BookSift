/// 贴吧在线结果排序（吧内 searchpost）：相关度 = sm=2 / 时间 = sm=1。
///
/// 两档结果集与顺序均由服务端返回；切换排序必须重发第一页请求，
/// 不能拿相关度结果在客户端倒序冒充时间排序。翻页沿用当前 sm 与当前吧。
library;

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

/// 在线结果卡标题的屏幕序（y 升序）= 列表序。
List<String> titleOrder(WidgetTester tester, List<String> titles) {
  final List<(double, String)> rows = <(double, String)>[
    for (final String title in titles) (tester.getTopLeft(find.text(title)).dy, title),
  ]..sort(((double, String) a, (double, String) b) => a.$1.compareTo(b.$1));
  return <String>[for (final (double, String) row in rows) row.$2];
}

void main() {
  test('排序档标签 = 相关度 / 时间', () {
    expect(onlineSortLabel(OnlineSort.relevance), '相关度');
    expect(onlineSortLabel(OnlineSort.time), '时间');
  });

  group('在线排序 UI（吧内 searchpost 服务端取数）', () {
    late FakeBookRepository repo;
    setUp(() => repo = FakeBookRepository(library: demoLibrary()));

    testWidgets('切「时间」重发 sm=1；切回「相关度」重发 sm=2，结果随之替换',
        (WidgetTester tester) async {
      final ScriptedAdapter adapter = ScriptedAdapter(<ResponseBody>[
        jsonBody(searchJson(
          posts: <Map<String, dynamic>>[
            postItem(tid: 1, title: '相关度第一', time: 1700000000),
            postItem(tid: 2, title: '相关度第二', time: 1760000000),
            postItem(tid: 3, title: '相关度第三', time: 1730000000),
          ],
          page: pageInfo(hasMore: 0, totalCount: 3),
        )),
        jsonBody(searchJson(
          posts: <Map<String, dynamic>>[
            postItem(tid: 2, title: '时间最新', time: 1760000000),
            postItem(tid: 3, title: '时间居中', time: 1730000000),
            postItem(tid: 1, title: '时间最旧', time: 1700000000),
          ],
          page: pageInfo(hasMore: 0, totalCount: 3),
        )),
        jsonBody(searchJson(
          posts: <Map<String, dynamic>>[
            postItem(tid: 1, title: '相关度第一', time: 1700000000),
            postItem(tid: 2, title: '相关度第二', time: 1760000000),
            postItem(tid: 3, title: '相关度第三', time: 1730000000),
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
      expect(adapter.requests, hasLength(1));
      Map<String, String> form = Uri.splitQueryString(adapter.bodies[0]);
      expect(form['sm'], '2');
      expect(form['kw'], 'yy小说吧');
      expect(form['only_thread'], '1');
      expect(
        titleOrder(tester, <String>['相关度第一', '相关度第二', '相关度第三']),
        <String>['相关度第一', '相关度第二', '相关度第三'],
        reason: '默认相关度 = 服务端 sm=2 原序',
      );

      await tester.tap(find.widgetWithText(CountChip, '时间'));
      await tester.pumpAndSettle();
      expect(adapter.requests, hasLength(2), reason: '切时间必须重新发请求');
      form = Uri.splitQueryString(adapter.bodies[1]);
      expect(form['sm'], '1');
      expect(form['pn'], '1', reason: '切档重取第一页');
      expect(form['kw'], 'yy小说吧');
      expect(
        titleOrder(tester, <String>['时间最新', '时间居中', '时间最旧']),
        <String>['时间最新', '时间居中', '时间最旧'],
        reason: '显示服务端时间排序结果',
      );
      expect(find.text('相关度第一'), findsNothing, reason: '旧排序结果被替换');

      await tester.tap(find.widgetWithText(CountChip, '相关度'));
      await tester.pumpAndSettle();
      expect(adapter.requests, hasLength(3), reason: '切回相关度同样重发请求');
      form = Uri.splitQueryString(adapter.bodies[2]);
      expect(form['sm'], '2');
      expect(find.text('相关度第一'), findsOneWidget);
      expect(find.text('时间最新'), findsNothing);
    });

    testWidgets('加载更多沿用当前 sm；切档后旧分页不再拼接', (WidgetTester tester) async {
      final ScriptedAdapter adapter = ScriptedAdapter(<ResponseBody>[
        jsonBody(searchJson(
          posts: <Map<String, dynamic>>[
            postItem(tid: 1, title: '相关度第一页', time: 1700000000),
          ],
          page: pageInfo(hasMore: 1, currentPage: 1, totalPage: 2),
        )),
        jsonBody(searchJson(
          posts: <Map<String, dynamic>>[
            postItem(tid: 2, title: '相关度第二页', time: 1710000000),
          ],
          page: pageInfo(hasMore: 0, currentPage: 2, totalPage: 2),
        )),
        jsonBody(searchJson(
          posts: <Map<String, dynamic>>[
            postItem(tid: 9, title: '时间第一页', time: 1760000000),
          ],
          page: pageInfo(hasMore: 0, currentPage: 1, totalPage: 1),
        )),
      ]);
      useSurface(tester);
      await tester.pumpWidget(onlineApp(repo, adapter, initial: searchRoute(kQuery)));
      await tester.pumpAndSettle();
      await gotoOnlineAndSearch(tester);

      await tester.tap(find.text('加载更多'));
      await tester.pumpAndSettle();
      Map<String, String> form = Uri.splitQueryString(adapter.bodies[1]);
      expect(form['pn'], '2');
      expect(form['sm'], '2', reason: '翻页沿用当前排序');
      expect(find.text('相关度第二页'), findsOneWidget);

      await tester.tap(find.widgetWithText(CountChip, '时间'));
      await tester.pumpAndSettle();
      form = Uri.splitQueryString(adapter.bodies[2]);
      expect(form['sm'], '1');
      expect(form['pn'], '1');
      expect(form['kw'], 'yy小说吧');
      expect(find.text('时间第一页'), findsOneWidget);
      expect(find.text('相关度第一页'), findsNothing);
      expect(find.text('相关度第二页'), findsNothing);
    });
  });
}
