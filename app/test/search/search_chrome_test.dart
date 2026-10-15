/// 搜索页结果区滚动改造测试：
///  · 筛选 chips 行改单行横向滚动（SingleChildScrollView horizontal + Row，compact 窄屏不溢出）；
///  · 本地结果区下滑收起筛选行 / 上滑·回顶展开（AnimatedCrossFade 高度 0 + 透明）；
///  · 本地/在线结果区接 ScrollChrome（与内部 ListView 共享同一 ScrollController）；
///  · 在线结果卡整卡点击 push /online/{tid}，右上角外链钮打开原帖。
///
/// 分组与边界（TESTING.md §1/§3）：全部 testWidgets —— FakeBookRepository 纯内存微任务 +
/// 脚本化 dio adapter / mock 剪贴板平台通道（复用 online_search_test.dart 定义），
/// 假时钟区内无真实异步。
///
/// 方向口径：「下滑」= 浏览更靠下的内容（同「下滑加载更多」），手势向上拖、offset 增大；
/// 「上滑」反之。ScrollChrome 跳顶/跳底按钮自身行为已由 test/core/scroll_chrome_test.dart 覆盖。
library;

import 'package:booksift/core/widgets/scroll_chrome.dart';
import 'package:booksift/features/search/search_page.dart';
import 'package:booksift/features/search/search_state.dart';
import 'package:booksift/theme/book_theme.dart';
import 'package:dio/dio.dart' show ResponseBody;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import '../support/harness.dart';
import 'online_search_test.dart'
    show
        ScriptedAdapter,
        gotoOnlineAndSearch,
        jsonBody,
        kQuery,
        mockClipboard,
        mockExternalLaunch,
        pageInfo,
        postItem,
        scriptedClient,
        searchJson,
        searchRoute;

/// 筛选行收起动画的外层容器（search_page.dart 里 AnimatedCrossFade 的 key）。
const ValueKey<String> kFilterCollapseKey = ValueKey<String>('search-filter-collapse');

/// 自带 /online/{tid} 最小路由的挂具：真实路由表的该路由由并行任务提供（集成阶段接上），
/// 本用例只为验证整卡点击的 push 目标与参数。
Widget onlinePushApp(FakeBookRepository repo, ScriptedAdapter adapter, GoRouter router) {
  return ProviderScope(
    overrides: <Override>[
      ...testOverrides(repo),
      tiebaSearchClientProvider.overrideWithValue(scriptedClient(adapter)),
    ],
    child: MaterialApp.router(
      theme: BookTheme.light,
      darkTheme: BookTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: router,
    ),
  );
}

void main() {
  late FakeBookRepository repo;
  setUp(() => repo = FakeBookRepository(library: demoLibrary()));

  group('筛选面板（固定两行 + 图标动作钮）', () {
    testWidgets('第一行 年/月/旬 + 清空钮；第二行 来源/类别/时间 + 确认钮；compact 零溢出',
        (WidgetTester tester) async {
      useSurface(tester); // 390×844 compact
      await tester.pumpWidget(testApp(repo, initial: searchRoute(kQuery)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '两行布局后 compact 宽度零溢出');

      // 维度 chips = 「年·全部」式摘要（值仍在浮层里选）。
      expect(find.text('年·全部'), findsOneWidget);
      expect(find.text('月·全部'), findsOneWidget);
      expect(find.text('旬·全部'), findsOneWidget);
      expect(find.text('来源·全部'), findsOneWidget);
      expect(find.text('类别·全部'), findsOneWidget);
      expect(find.text('时间↓'), findsOneWidget);
      // 两个行尾动作钮均为纯图标（无文本）。
      expect(find.byTooltip('清空筛选'), findsOneWidget);
      expect(find.byTooltip('确认筛选'), findsOneWidget);
      expect(find.text('清空筛选'), findsNothing, reason: '清空钮为纯图标');

      // 两行布局：年/月/旬 与 来源/类别 的 y 不同（第一行 vs 第二行）。
      final double yYear = tester.getTopLeft(find.text('年·全部')).dy;
      final double yChannel = tester.getTopLeft(find.text('来源·全部')).dy;
      expect(yChannel, greaterThan(yYear), reason: '固定两行（年 月 旬 / 来源 类别 时间）');

      // 点维度 chip → 值域浮层（带联动计数）；选值 → 摘要回写。
      await tester.tap(find.text('年·全部'));
      await tester.pumpAndSettle();
      expect(find.text('年'), findsOneWidget, reason: '浮层标题 = 维度短标签');
      await tester.tap(find.text('2025'));
      await tester.pumpAndSettle();
      expect(find.text('年·2025'), findsOneWidget, reason: '选值回写 chip 摘要');
      // 非默认筛选后清空钮可用 → 点击清空回全部。
      await tester.tap(find.byTooltip('清空筛选'));
      await tester.pumpAndSettle();
      expect(find.text('年·全部'), findsOneWidget, reason: '清空筛选回「全部」');
    });
  });

  group('本地结果区滚动收起 / ScrollChrome', () {
    testWidgets('ScrollChrome 与 ListView 共享 controller；下滑收起、仅回顶展开', (WidgetTester tester) async {
      // 600dp 视口：6 张书级卡必超一屏 → 列表可滚动。
      useSurface(tester, height: 600);
      await tester.pumpWidget(testApp(repo, initial: '/search?q=')); // 空关键词提交 = 条件浏览（6 书组）
      await tester.pumpAndSettle();

      // 结果区接 ScrollChrome，且与内部 ListView 共享同一 ScrollController。
      final Finder chrome = find.descendant(of: find.byType(SearchPage), matching: find.byType(ScrollChrome));
      expect(chrome, findsOneWidget);
      final ScrollController controller = tester.widget<ScrollChrome>(chrome).controller;
      final Finder listFinder = find.descendant(of: chrome, matching: find.byType(ListView));
      expect(identical(controller, tester.widget<ListView>(listFinder).controller), isTrue,
          reason: 'ScrollChrome 与 ListView 同一 ScrollController 实例');

      double panelHeight() => tester.getSize(find.byKey(kFilterCollapseKey)).height;
      expect(panelHeight(), greaterThan(0), reason: '初始展开');
      expect(find.text('条件浏览'), findsOneWidget);

      // 下滑（手势上拖、offset 增大）超阈值 → 收起（高度 0）。
      await tester.drag(listFinder, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(panelHeight(), 0, reason: '下滑超阈值 → 筛选面板高度收起到 0');
      expect(controller.offset, greaterThan(0), reason: '结果区确实发生了滚动');
      expect(find.text('年·全部'), findsOneWidget, reason: '面板仍在树中（透明+零高），非销毁重建');

      // 上滑（手势下拖、offset 减小）但未回顶 → 仍收起（用户口径：上滑不展开）。
      await tester.drag(listFinder, const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0), reason: '已上滑但未回顶');
      expect(panelHeight(), 0, reason: '未回顶 → 保持收起');

      // 一路拖回顶部 → 回顶即展开。
      await tester.drag(listFinder, const Offset(0, 1000));
      await tester.pumpAndSettle();
      expect(controller.offset, 0, reason: '确实回到顶端');
      expect(panelHeight(), greaterThan(0), reason: '回到顶部 → 展开');
    });

    testWidgets('确认钮收起面板且不聚焦搜索框（不弹输入法）', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, initial: '/search?q='));
      await tester.pumpAndSettle();

      double panelHeight() => tester.getSize(find.byKey(kFilterCollapseKey)).height;
      expect(panelHeight(), greaterThan(0));

      // 先让搜索框获得焦点（模拟键盘弹起），再点确认钮。
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      final FocusNode node = tester.widget<TextField>(find.byType(TextField).first).focusNode!;
      expect(node.hasFocus, isTrue);

      await tester.tap(find.byTooltip('确认筛选'));
      await tester.pumpAndSettle();
      expect(panelHeight(), 0, reason: '确认钮收起面板');
      expect(node.hasFocus, isFalse, reason: '收起面板主动移除搜索框焦点 → 不弹输入法');
    });
  });

  group('在线结果区 ScrollChrome / 整卡进在线帖子页', () {
    testWidgets('整卡点击 push /online/{tid} 且不出站；外链钮打开原帖', (WidgetTester tester) async {
      final ScriptedAdapter adapter = ScriptedAdapter(<ResponseBody>[
        jsonBody(searchJson(
          posts: <Map<String, dynamic>>[
            postItem(tid: 101, title: '【扫书】十日终焉 超好看', replyNum: 12, time: 1760000000),
          ],
          page: pageInfo(hasMore: 0, totalCount: 1),
        )),
      ]);
      final List<String> copied = mockClipboard(tester);
      final List<String> opened = mockExternalLaunch(tester);
      final GoRouter router = GoRouter(
        initialLocation: searchRoute(kQuery),
        routes: <RouteBase>[
          GoRoute(
            path: '/search',
            builder: (BuildContext context, GoRouterState state) =>
                SearchPage(initialParams: state.uri.queryParameters),
          ),
          GoRoute(
            path: '/online/:tid',
            builder: (BuildContext context, GoRouterState state) =>
                Scaffold(body: Text('online-thread-${state.pathParameters['tid']}')),
          ),
        ],
      );
      useSurface(tester);
      await tester.pumpWidget(onlinePushApp(repo, adapter, router));
      await tester.pumpAndSettle();
      await gotoOnlineAndSearch(tester);

      expect(find.text('【扫书】十日终焉 超好看'), findsOneWidget);
      // 在线结果区接 ScrollChrome，且与内部 ListView 共享同一 ScrollController。
      final Finder onlineView = find.byKey(const ValueKey<String>('online-results-view'));
      final Finder chrome = find.descendant(of: onlineView, matching: find.byType(ScrollChrome));
      expect(chrome, findsOneWidget);
      final ScrollChrome chromeWidget = tester.widget(chrome);
      final Finder listFinder = find.descendant(of: chrome, matching: find.byType(ListView));
      expect(identical(chromeWidget.controller, tester.widget<ListView>(listFinder).controller), isTrue);

      // 整卡点击 → push 在线帖子页（tid 参数随行）；不再复制链接。
      await tester.tap(find.text('【扫书】十日终焉 超好看'));
      await tester.pumpAndSettle();
      expect(find.text('online-thread-101'), findsOneWidget, reason: 'push /online/{tid} 落到在线帖子页');
      expect(copied, isEmpty, reason: '整卡点击不再复制链接');

      // 返回列表，点卡片右上角外链钮 → 打开原帖（不再写剪贴板）。
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('【扫书】十日终焉 超好看'), findsOneWidget);
      await tester.tap(find.byTooltip('打开原帖'));
      await tester.pumpAndSettle();
      expect(opened, <String>['https://tieba.baidu.com/p/101']);
      expect(copied, isEmpty, reason: '外链钮不再复制');
    });
  });
}
