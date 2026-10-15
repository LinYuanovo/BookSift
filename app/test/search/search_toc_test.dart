/// 搜索页结果区收尾（P2-5）：
///  · 结果头行视觉对齐 —— 「N 结果」caption 与导出图标同一 centerY（Row center 对齐 +
///    44dp 固定图标槽光学居中，间距走 AppSpacing 令牌）；
///  · Tab 行右端「目录」钮 —— 弹层列**当前已加载**的结果行（本地 = 书组名 + 最近日期，
///    在线 = 帖子标题），点条目 = pop + 精确跳转到结果列表对应卡片
///    （index 键控 GlobalKey + Scrollable.ensureVisible(alignment 0.08)；未构建者由
///    「临时放大 ListView cacheExtent → 帧后 ensureVisible → 恢复」兜底）。
///
/// 分组与边界（TESTING.md §1/§3）：全部 testWidgets —— FakeBookRepository（纯内存微任务）
/// + 脚本化 dio adapter（复用 online_search_test.dart 定义），零真实 IO/网络，
/// 假时钟区内只有微任务与动效 timer。
library;

import 'package:booksift/core/icons.dart';
import 'package:booksift/core/widgets/scroll_chrome.dart';
import 'package:booksift/features/home/cards.dart';
import 'package:booksift/features/search/search_state.dart';
import 'package:booksift/theme/app_spacing.dart';
import 'package:dio/dio.dart' show ResponseBody;
import 'package:flutter/material.dart';
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

/// 目录跳转的对齐比例（search_page._kTocAlignment 的期望值；私有常量故在此复述）。
const double kTocAlignment = 0.08;

/// 筛选行收起动画的外层容器 key（search_page.dart 里 AnimatedCrossFade 的 key；
/// 与 search_chrome_test.dart 同一定义）。
const ValueKey<String> kFilterCollapseKey = ValueKey<String>('search-filter-collapse');

void main() {
  late FakeBookRepository repo;
  setUp(() => repo = FakeBookRepository(library: demoLibrary()));

  group('结果头行视觉对齐', () {
    testWidgets('「N 结果」与导出图标同一 centerY；图标槽 = 44dp 方形；头行 Row center 对齐',
        (WidgetTester tester) async {
      useSurface(tester); // 390×844 compact
      await tester.pumpWidget(testApp(repo, initial: searchRoute(kQuery)));
      await tester.pumpAndSettle();

      final Finder countText = find.text('1 结果');
      final Finder exportBtn = find.byTooltip('导出书单');
      expect(countText, findsOneWidget);
      expect(exportBtn, findsOneWidget);

      // 头行 Row = center 对齐（原 end 对齐把图标压到文本中线之下，看着不齐）。
      final Finder headerRow = find.ancestor(of: countText, matching: find.byType(Row)).first;
      expect(tester.widget<Row>(headerRow).crossAxisAlignment, CrossAxisAlignment.center);

      // 图标槽：固定 44dp 方形（触控下限 token）+ 图标光学居中。
      final Rect btnRect = tester.getRect(exportBtn);
      expect(btnRect.width, AppMetrics.minTouchTarget);
      expect(btnRect.height, AppMetrics.minTouchTarget);

      final double countCenterY = tester.getCenter(countText).dy;
      expect(tester.getCenter(exportBtn).dy, closeTo(countCenterY, 0.5), reason: '图标槽与命中数同 centerY');
      final Finder icon = find.descendant(of: exportBtn, matching: find.byType(AppIcon));
      expect(tester.widget<AppIcon>(icon).assetName, 'assets/icons/external.svg');
      expect(tester.getCenter(icon).dy, closeTo(countCenterY, 0.5), reason: '20dp 图标本体也在同一中线');
      expect(tester.getSize(icon).height, 20, reason: '图标 20dp（与 caption 文本同档光学居中）');
    });

    testWidgets('在线结果头行：徽标与命中计数同一 centerY（无图标钮，Row 默认 center）',
        (WidgetTester tester) async {
      final ScriptedAdapter adapter = ScriptedAdapter(<ResponseBody>[
        jsonBody(searchJson(
          posts: <Map<String, dynamic>>[postItem(tid: 101, title: '头行对齐帖')],
          page: pageInfo(hasMore: 0, totalCount: 1),
        )),
      ]);
      useSurface(tester);
      await tester.pumpWidget(onlineApp(repo, adapter, initial: searchRoute(kQuery)));
      await tester.pumpAndSettle();
      await gotoOnlineAndSearch(tester);

      expect(find.text('1 条'), findsOneWidget);
      expect(
        tester.getCenter(find.text('实时联网·匿名')).dy,
        closeTo(tester.getCenter(find.text('1 条')).dy, 0.5),
      );
    });
  });

  group('结果目录（本地库 Tab）', () {
    testWidgets('Tab 行最右端「目录」钮 → 弹层列已加载书组（书名+最近日期）→ 点击精确跳转',
        (WidgetTester tester) async {
      useSurface(tester, height: 600); // 6 张书级卡必超一屏 → 末卡屏外
      await tester.pumpWidget(testApp(repo, initial: '/search?q=')); // 空词提交 = 条件浏览（6 书组）
      await tester.pumpAndSettle();

      expect(find.text('条件浏览'), findsOneWidget);
      expect(find.text('6 结果'), findsOneWidget);

      // 目录钮在 Tab 切换行同一行的最右端（list 图标 = 帖子详情目录同款语义）。
      final Finder tocBtn = find.byTooltip('目录');
      expect(tocBtn, findsOneWidget);
      expect(
        tester.widget<AppIcon>(find.descendant(of: tocBtn, matching: find.byType(AppIcon))).assetName,
        'assets/icons/list.svg',
      );
      final Finder pill = find.byType(SegmentedPill<SearchTab>);
      expect(tester.getCenter(tocBtn).dy, closeTo(tester.getCenter(pill).dy, 0.5), reason: '与 Tab 同一行');
      expect(tester.getTopLeft(tocBtn).dx, greaterThan(tester.getTopRight(pill).dx), reason: '行最右端');

      // 跳转前：末张结果卡已构建但在视口之下。
      final Finder cards = find.byType(AccentCard);
      expect(cards, findsNWidgets(6), reason: '条件浏览 = demoLibrary 的 6 个书组');
      final Rect viewport = tester.getRect(find.byType(ScrollChrome));
      final Finder lastCard = cards.last;
      final String lastTitle =
          tester.widget<Text>(find.descendant(of: lastCard, matching: find.byType(Text)).first).data!;
      final String lastDate = tester
          .widget<Text>(
              find.descendant(of: lastCard, matching: find.textContaining(RegExp(r'^\d{4}-\d{2}-\d{2}$'))))
          .data!;
      expect(lastDate, '2025-02-05', reason: 'latestDate 最小者排序在末（世子很凶）');
      expect(tester.getRect(lastCard).top, greaterThanOrEqualTo(viewport.bottom - 0.5), reason: '末卡屏外');

      await tester.tap(tocBtn);
      await tester.pumpAndSettle();

      // 弹层：一行一条已加载结果（书名 + 最近日期），行数 = 已加载结果数。
      final Finder sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      final Finder tiles = find.descendant(of: sheet, matching: find.byType(ListTile));
      expect(tiles, findsNWidgets(6));
      expect(
        (tester.widget<ListTile>(tiles.last).title! as Text).data,
        lastTitle,
        reason: '目录行与结果卡同 index 同序',
      );
      expect(
        (tester.widget<ListTile>(tiles.last).trailing! as Text).data,
        lastDate,
        reason: '副标题 = 结果行的最近日期',
      );

      await tester.tap(tiles.last);
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing, reason: '点条目即 pop');
      // 跳转期间挂起「下滑收起筛选行」启发式：筛选行保持展开、视口高度不变
      // （否则收起 → 视口变高 → offset 被夹小 → 被误判上滑又展开，来回抖动且落点偏移）。
      expect(tester.getSize(find.byKey(kFilterCollapseKey)).height, greaterThan(0), reason: '筛选行未收起');
      final Rect viewportAfter = tester.getRect(find.byType(ScrollChrome));
      expect(viewportAfter, viewport, reason: '视口几何在跳转前后不变');
      final Rect lastRect = tester.getRect(find.widgetWithText(AccentCard, lastTitle));
      expect(lastRect.top, greaterThanOrEqualTo(viewportAfter.top - 0.5));
      expect(lastRect.bottom, lessThanOrEqualTo(viewportAfter.bottom + 0.5), reason: '目标卡完整落入视口');
      expect(
        tester.widget<ScrollChrome>(find.byType(ScrollChrome)).controller.offset,
        greaterThan(0),
        reason: '确实发生了滚动（非原地不动）',
      );

      // 反向再跳中段行：目标卡顶落在 alignment 0.08 的精确落点（视口高 − 卡高 的 8%）。
      await tester.tap(tocBtn);
      await tester.pumpAndSettle();
      final Finder midTile = find.descendant(of: find.byType(BottomSheet), matching: find.byType(ListTile)).at(1);
      final String midTitle = (tester.widget<ListTile>(midTile).title! as Text).data!;
      await tester.tap(midTile);
      await tester.pumpAndSettle();

      final Rect midRect = tester.getRect(find.widgetWithText(AccentCard, midTitle));
      expect(midRect.top, greaterThanOrEqualTo(viewport.top - 0.5));
      expect(midRect.bottom, lessThanOrEqualTo(viewport.bottom + 0.5), reason: '完整可见');
      expect(
        midRect.top - viewport.top,
        closeTo(kTocAlignment * (viewport.height - midRect.height), 4),
        reason: 'ensureVisible(alignment: 0.08) 精确落位',
      );
    });

    testWidgets('结果变更后目录同步：换关键词 → 目录只列新结果的已加载行', (WidgetTester tester) async {
      useSurface(tester, height: 600);
      await tester.pumpWidget(testApp(repo, initial: '/search?q='));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('目录'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.byType(ListTile)), findsNWidgets(6));
      await tester.tap(find.widgetWithText(ListTile, '《世子很凶》'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);

      // 换成单书命中 → 目录随之收敛为 1 行（不残留上一次结果的条目）。
      await tester.enterText(find.byType(TextField).first, kQuery);
      await tester.pump(const Duration(milliseconds: 250)); // 联想 debounce（TESTING.md §3.5）
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('1 结果'), findsOneWidget);

      await tester.tap(find.byTooltip('目录'));
      await tester.pumpAndSettle();
      final Finder tiles = find.descendant(of: find.byType(BottomSheet), matching: find.byType(ListTile));
      expect(tiles, findsOneWidget);
      expect((tester.widget<ListTile>(tiles.first).title! as Text).data, '《十日终焉》');
      await tester.tap(tiles.first);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AccentCard, '《十日终焉》'), findsOneWidget);
    });
  });

  group('结果目录（贴吧在线 Tab）', () {
    testWidgets('弹层列已加载帖子标题（未加载页不进目录）→ 点击跳转末条入视口', (WidgetTester tester) async {
      final ScriptedAdapter adapter = ScriptedAdapter(<ResponseBody>[
        jsonBody(searchJson(
          posts: <Map<String, dynamic>>[
            for (int i = 1; i <= 6; i++)
              postItem(tid: i, title: '扫书帖第 $i 条', time: 1760000000 + i * 86400),
          ],
          // hasMore=1：仍有后续页，但目录只列已加载的 6 条。
          page: pageInfo(hasMore: 1, currentPage: 1, totalPage: 3),
        )),
      ]);
      useSurface(tester, height: 600);
      await tester.pumpWidget(onlineApp(repo, adapter, initial: searchRoute(kQuery)));
      await tester.pumpAndSettle();
      await gotoOnlineAndSearch(tester);

      expect(find.text('6 条'), findsOneWidget);
      final Finder cards = find.byType(AccentCard);
      expect(cards, findsNWidgets(6));
      final Rect viewport = tester.getRect(find.byType(ScrollChrome));
      expect(tester.getRect(cards.last).top, greaterThanOrEqualTo(viewport.bottom - 0.5), reason: '末条屏外');

      await tester.tap(find.byTooltip('目录'));
      await tester.pumpAndSettle();
      final Finder tiles = find.descendant(of: find.byType(BottomSheet), matching: find.byType(ListTile));
      expect(tiles, findsNWidgets(6), reason: '只列已加载行，hasMore 的后续页不进目录');
      expect((tester.widget<ListTile>(tiles.last).title! as Text).data, '扫书帖第 6 条');
      expect(tester.widget<ListTile>(tiles.last).trailing, isNull, reason: '在线目录行只有标题');

      await tester.tap(tiles.last);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      final Rect cardRect = tester.getRect(find.widgetWithText(AccentCard, '扫书帖第 6 条'));
      expect(cardRect.top, greaterThanOrEqualTo(viewport.top - 0.5));
      expect(cardRect.bottom, lessThanOrEqualTo(viewport.bottom + 0.5), reason: '目标帖卡完整落入视口');
    });
  });
}
