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
import 'package:booksift/features/home/cards.dart';
import 'package:booksift/features/search/search_page.dart';
import 'package:booksift/features/search/search_state.dart';
import 'package:booksift/theme/app_colors.dart';
import 'package:booksift/theme/app_spacing.dart';
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

  group('筛选面板（按宽智能换行 + Tab 行动作组）', () {
    testWidgets('宽度不足时维度 chips 按宽换行；清除/确认/目录在 Tab 行同排；compact 零溢出',
        (WidgetTester tester) async {
      useSurface(tester); // 390×844 compact
      await tester.pumpWidget(testApp(repo, initial: searchRoute(kQuery)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '智能换行后 compact 宽度零溢出');

      // 维度 chips = 「年·全部」式摘要（值仍在浮层里选）。
      expect(find.text('年·全部'), findsOneWidget);
      expect(find.text('月·全部'), findsOneWidget);
      expect(find.text('旬·全部'), findsOneWidget);
      expect(find.text('来源·全部'), findsOneWidget);
      expect(find.text('类别·全部'), findsOneWidget);
      expect(find.text('时间↓'), findsOneWidget);
      // 清除 / 确认在 Tab 行，与目录同排（设计令牌图标 close / check，非纯文字）。
      expect(find.byTooltip('清除筛选'), findsOneWidget);
      expect(find.byTooltip('确认筛选'), findsOneWidget);
      expect(find.byTooltip('目录'), findsOneWidget);
      // 分段控件优先占宽：默认字阶下「本地库 / 贴吧在线」固有宽 ≈150；
      // 旧布局（与 Spacer 1:1 平分余量）会被压到 ≈121 → 标签出「本…/贴…」。
      expect(
        tester.getSize(find.byType(SegmentedPill<SearchTab>)).width,
        greaterThan(140),
        reason: '411dp 档也不出「本…/贴…」截断',
      );

      // 智能换行：390 宽放不下 6 颗 chip → 来源 落在 年 之后的 run（y 更大）。
      // 行分组由容器宽度决定（宽容器单行守卫见 filter_panel_test.dart）。
      final double yYear = tester.getTopLeft(find.text('年·全部')).dy;
      final double yChannel = tester.getTopLeft(find.text('来源·全部')).dy;
      expect(yChannel, greaterThan(yYear), reason: 'compact 宽度放不下 → 按宽换行');

      // 点维度 chip → 值域浮层（带联动计数）；选值 → 摘要回写。
      await tester.tap(find.text('年·全部'));
      await tester.pumpAndSettle();
      expect(find.text('年'), findsOneWidget, reason: '浮层标题 = 维度短标签');
      await tester.tap(find.text('2025'));
      await tester.pumpAndSettle();
      expect(find.text('年·2025'), findsOneWidget, reason: '选值回写 chip 摘要');
      // 非默认筛选后清空钮可用 → 点击清空回全部。
      await tester.tap(find.byTooltip('清除筛选'));
      await tester.pumpAndSettle();
      expect(find.text('年·全部'), findsOneWidget, reason: '清空筛选回「全部」');
    });

    testWidgets('宽屏（1024×768）：清除/确认/目录贴右、与 Tab 同一中线、零溢出', (WidgetTester tester) async {
      useSurface(tester, width: 1024, height: 768);
      await tester.pumpWidget(testApp(repo, initial: searchRoute(kQuery)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '宽屏零溢出');

      // 顺序：本地库/贴吧在线 → 清除 → 确认 → 目录（全部同一排）。
      final double xTabs = tester.getTopRight(find.text('贴吧在线')).dx;
      final Finder clear = find.byTooltip('清除筛选');
      final Finder confirm = find.byTooltip('确认筛选');
      final Finder toc = find.byTooltip('目录');
      expect(tester.getTopLeft(clear).dx, greaterThan(xTabs), reason: '动作组在分段控件右侧');
      expect(tester.getTopLeft(confirm).dx, greaterThan(tester.getTopLeft(clear).dx), reason: '确认在清除右侧');
      expect(tester.getTopLeft(toc).dx, greaterThan(tester.getTopLeft(confirm).dx), reason: '目录在确认右侧');

      // 用户口径「居右对齐」：目录钮右缘贴页面右内边距（弹性槽吃满后不存在行尾余量）。
      final AppSpacing s = AppSpacing.of(tester.element(find.byType(SearchPage)));
      final Rect pageRect = tester.getRect(find.byType(SearchPage));
      expect(tester.getTopRight(toc).dx, closeTo(pageRect.right - s.pagePadding, 0.5),
          reason: '动作组贴右（旧布局余量落在动作组右侧）');

      // 上下对齐：动作图标与 Tab 标签同一中线。
      final double yTab = tester.getCenter(find.text('本地库')).dy;
      expect((tester.getCenter(clear).dy - yTab).abs(), lessThan(1.0));
      expect((tester.getCenter(confirm).dy - yTab).abs(), lessThan(1.0));
    });
  });

  group('结果卡（计数 / 日期 / 命中正文）', () {
    testWidgets('关键词命中：无「N 条」、日期贴右、正文 50 字内 + 关键词琥珀高亮', (WidgetTester tester) async {
      useSurface(tester);
      // 「无限流」命中评语列（二级检索）→ snippet 自带 `[词]` 命中标记。
      await tester.pumpWidget(testApp(repo, initial: searchRoute('无限流')));
      await tester.pumpAndSettle();

      final Finder card = find.widgetWithText(AccentCard, '《十日终焉》');
      expect(card, findsOneWidget);

      // 不再显示「N 条」冗余总数（用户口径：扫书 / 推荐 / 排雷 三档已足够）。
      expect(
        find.descendant(of: card, matching: find.textContaining(RegExp(r'\d+\s*条'))),
        findsNothing,
      );

      // 最近日期贴右：右缘 = 卡片右内边距（cardPadding）。
      final AppSpacing s = AppSpacing.of(tester.element(find.byType(SearchPage)));
      final Finder date = find.descendant(of: card, matching: find.text('2025-04-28'));
      expect(date, findsOneWidget);
      expect(tester.getTopRight(date).dx, closeTo(tester.getRect(card).right - s.cardPadding, 0.5),
          reason: '日期居右对齐');

      // 命中正文预览：snippet 命中标记保留 → 琥珀底高亮（c.highlight）。
      final Finder preview = find.descendant(of: card, matching: find.byType(HighlightText));
      expect(preview, findsOneWidget, reason: '关键词命中的正文预览在场');
      final HighlightText hl = tester.widget<HighlightText>(preview);
      expect(hl.text, contains('[无限流]'), reason: 'snippet 命中标记原样交给高亮渲染');
      expect(
        hl.text.replaceAll('[', '').replaceAll(']', '').runes.length,
        lessThanOrEqualTo(kSearchCardPreviewChars + 1),
        reason: '可见 50 字上限（+「…」）',
      );

      // Paint.color getter 经 float32 往返重建 Color，直接 == 比较会假阴性 → 走 ARGB 值。
      final int expectedHl = AppColors.of(tester.element(preview)).highlight.toARGB32();
      bool hasHighlight = false;
      final Text rich = tester.widget<Text>(find.descendant(of: preview, matching: find.byType(Text)).first);
      rich.textSpan!.visitChildren((InlineSpan span) {
        final Paint? bg = span.style?.background;
        if (bg is Paint && bg.color.toARGB32() == expectedHl) {
          hasHighlight = true;
        }
        return true;
      });
      expect(hasHighlight, isTrue, reason: '关键词走 c.highlight 琥珀高亮');
    });

    testWidgets('仅筛选分类/维度（无关键词）：正文预览在场但不高亮', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, initial: '/search?q='));
      await tester.pumpAndSettle();

      final Finder card = find.widgetWithText(AccentCard, '《十日终焉》');
      final Finder preview = find.descendant(of: card, matching: find.byType(HighlightText));
      expect(preview, findsOneWidget, reason: '条件浏览卡也有正文预览（评语回退）');
      final Text rich = tester.widget<Text>(find.descendant(of: preview, matching: find.byType(Text)).first);
      bool anyBg = false;
      rich.textSpan!.visitChildren((InlineSpan span) {
        if (span.style?.background != null) {
          anyBg = true;
        }
        return true;
      });
      expect(anyBg, isFalse, reason: '无关键词 → 不做高亮');
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
