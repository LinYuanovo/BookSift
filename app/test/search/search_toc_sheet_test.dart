// 搜索结果目录弹层（A 高度收口 + 行染色 / B 触底自动加载更多）。
//
// A：isScrollControlled 的弹层不设限就会铺满全屏（真机反馈）——改为最大高度 =
//    屏幕可用高度 × AppMetrics.tocSheetHeightFactor，短目录仍按内容收缩；
//    目录行按「推荐多 / 排雷多」染色（rec > avoid → recommend，avoid > rec → danger）。
// B：目录 ListView 滚到底且还有下一页时，递增 resultPageProvider（与结果列表
//    「加载更多」按钮完全同口径），新行随结果视图重建追加进目录；带节流防连发。
//
// 分组与边界（TESTING.md §1/§3）：全部 testWidgets —— FakeBookRepository 纯内存微任务，
// 零真实 IO/网络。分页语料用 45 个书组（默认每页 40 → hasMore=true）。
library;

import 'dart:convert';

import 'package:booksift/core/constants.dart';
import 'package:booksift/core/widgets/scroll_chrome.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/features/search/search_page.dart';
import 'package:booksift/features/search/search_state.dart';
import 'package:booksift/theme/app_colors.dart';
import 'package:booksift/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import '../support/harness.dart';
import 'search_position_memory_test.dart' show MemoryKv;

/// 分页语料：[groups] 个书组各 1 条目（>40 → 首页 hasMore=true）。
FakeLibrary pagedLibrary({int groups = 45}) {
  return FakeLibrary(
    posts: <Post>[],
    floors: <int, List<FloorData>>{},
    entries: <EntryRow>[
      for (int i = 1; i <= groups; i++)
        EntryRow(
          id: i,
          name: '《分页书$i》',
          nameNorm: '分页书$i',
          author: '作者$i',
          recommender: '推荐人',
          comment: '第 $i 本的推荐语。',
          date: '2025-01-${(i % 28 + 1).toString().padLeft(2, '0')}',
          channel: 'yy小说吧',
          category: CategoryKind.scan,
          origin: Origin.builtin,
          quality: 2,
          bookGroupId: i,
        ),
    ],
    groups: <BookGroup>[
      for (int i = 1; i <= groups; i++)
        BookGroup(
          id: i,
          nameNorm: '分页书$i',
          authorEffNorm: '作者$i',
          nameDisplay: '分页书$i',
          authorDisplay: '作者$i',
          entryTotal: 1,
          distinctComment: 1,
          channels: '["yy小说吧"]',
          dateMin: '2025-01-01',
          dateMax: '2025-01-28',
        ),
    ],
  );
}

void main() {
  /// 弹层内目录 ListView。
  Finder sheetList() => find.descendant(of: find.byType(BottomSheet), matching: find.byType(ListView));

  double sheetListHeight(WidgetTester tester) => tester.getSize(sheetList()).height;

  double maxHeightOf(WidgetTester tester) => tester
      .widget<ConstrainedBox>(find
          .ancestor(of: sheetList(), matching: find.byType(ConstrainedBox))
          .first)
      .constraints
      .maxHeight;

  double scrollExtentOf(WidgetTester tester) =>
      tester.widget<ListView>(sheetList()).controller!.position.maxScrollExtent;

  group('目录弹层高度收口（A）', () {
    testWidgets('长目录：上限 = 屏幕可用高度 × tocSheetHeightFactor，不再铺满全屏',
        (WidgetTester tester) async {
      useSurface(tester, height: 600);
      await tester.pumpWidget(testApp(FakeBookRepository(library: pagedLibrary()), initial: '/search?q='));
      await tester.pumpAndSettle();
      expect(find.text('45 结果'), findsOneWidget);

      await tester.tap(find.byTooltip('目录'));
      await tester.pumpAndSettle();

      final double cap = 600 * AppMetrics.tocSheetHeightFactor;
      expect(cap, 420, reason: '令牌值口径（0.7）');
      expect(maxHeightOf(tester), cap, reason: 'ConstrainedBox 收口到 70% 可用高度');
      expect(sheetListHeight(tester), cap, reason: '长目录撑满上限（内容更高 → 内部滚动）');
      expect(tester.getRect(find.byType(BottomSheet)).height, lessThan(600), reason: '不再占满全屏');
      expect(scrollExtentOf(tester), greaterThan(0), reason: '超出部分在弹层内滚动');
    });

    testWidgets('短目录仍按内容收缩（不硬撑到上限）', (WidgetTester tester) async {
      useSurface(tester, height: 600);
      await tester.pumpWidget(testApp(FakeBookRepository(library: demoLibrary()), initial: '/search?q='));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('目录'));
      await tester.pumpAndSettle();

      final double cap = 600 * AppMetrics.tocSheetHeightFactor;
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.byType(ListTile)), findsNWidgets(6));
      expect(sheetListHeight(tester), lessThan(cap), reason: '6 行按内容收缩');
      expect(scrollExtentOf(tester), 0, reason: '不足一屏 → 无需滚动');
    });
  });

  group('目录行按推荐/排雷染色（A）', () {
    testWidgets('推荐多 = recommend 绿，排雷多 = danger 红，持平 = 常规文本色',
        (WidgetTester tester) async {
      useSurface(tester, height: 600);
      await tester.pumpWidget(testApp(FakeBookRepository(library: demoLibrary()), initial: '/search?q='));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('目录'));
      await tester.pumpAndSettle();

      final AppColors c = AppColors.of(tester.element(find.byType(BottomSheet)));
      Color titleColorOf(String title) {
        final Finder tile = find.widgetWithText(ListTile, title);
        expect(tile, findsOneWidget, reason: '目录里有 $title');
        final Text text = tester.widget<Text>(find.descendant(of: tile, matching: find.byType(Text)).first);
        return text.style!.color!;
      }

      expect(titleColorOf('《世子很凶》'), c.recommend, reason: '5 推荐 / 0 排雷');
      expect(titleColorOf('《毒书一号》'), c.danger, reason: '0 推荐 / 1 排雷');
      expect(titleColorOf('《逍遥小书生》'), c.text, reason: '1 推荐 / 1 排雷 → 持平不染语义色');
    });
  });

  group('目录触底自动加载更多（B）', () {
    testWidgets('滚到底 → 递增 resultPageProvider（与「加载更多」按钮同口径）→ 目录追加新行',
        (WidgetTester tester) async {
      useSurface(tester, height: 600);
      await tester.pumpWidget(testApp(FakeBookRepository(library: pagedLibrary()), initial: '/search?q='));
      await tester.pumpAndSettle();
      final ProviderContainer container = containerOf(tester, find.byType(SearchPage));

      // 首页 40 条、hasMore=true。
      expect(find.text('45 结果'), findsOneWidget);
      expect(container.read(resultPageProvider), 1);

      // F：结果列表末尾的「加载更多」按钮保留不变。40 张卡远超一屏，按钮落在
      // cacheExtent 之外根本没被构建（offstage 也找不到）→ 先滚到底再断言。
      await tester.drag(find.byType(ScrollChrome), const Offset(0, -12000));
      await tester.pumpAndSettle();
      expect(find.text('加载更多'), findsOneWidget);

      await tester.tap(find.byTooltip('目录'));
      await tester.pumpAndSettle();
      final double extentBefore = scrollExtentOf(tester);
      expect(extentBefore, greaterThan(0), reason: '40 行超一屏 → 目录可滚');

      // 触底：一次拖到底（拖拽途中会派发大量滚动通知 → 只应触发一页）。
      await tester.drag(sheetList(), const Offset(0, -4000));
      await tester.pumpAndSettle();

      expect(container.read(resultPageProvider), 2, reason: '递增一页（节流生效，未连发多页）');
      expect(scrollExtentOf(tester), greaterThan(extentBefore), reason: '45 行 → 目录更长');
      // 与「加载更多」按钮同一口径：结果 provider 的键是 limit=40*pages。
      final SearchOutcome? outcome =
          container.read(searchResultProvider(const SearchFilter(limit: 80, offset: 0))).value;
      expect(outcome?.page.items, hasLength(45));
      expect(outcome?.page.hasMore, isFalse, reason: '全部加载完 → 不再触发');
    });

    testWidgets('不足一屏的目录不触发自动加载（extentAfter 恒 0 也不能误判触底）',
        (WidgetTester tester) async {
      useSurface(tester, height: 600);
      await tester.pumpWidget(testApp(FakeBookRepository(library: demoLibrary()), initial: '/search?q='));
      await tester.pumpAndSettle();
      final ProviderContainer container = containerOf(tester, find.byType(SearchPage));

      await tester.tap(find.byTooltip('目录'));
      await tester.pumpAndSettle();
      expect(scrollExtentOf(tester), 0, reason: '6 行不足一屏');
      await tester.drag(sheetList(), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(container.read(resultPageProvider), 1, reason: '没有下一页可加载时不动分页');
      expect(find.byType(BottomSheet), findsOneWidget, reason: '拖拽不该把弹层关掉');
    });
  });

  group('目录浏览位置记忆（C）', () {
    testWidgets('长目录滚动 → 关闭再打开回到上次位置（不变更搜索词）', (WidgetTester tester) async {
      useSurface(tester, height: 600);
      await tester.pumpWidget(testApp(FakeBookRepository(library: pagedLibrary()), initial: '/search?q='));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('目录'));
      await tester.pumpAndSettle();
      expect(scrollExtentOf(tester), greaterThan(0), reason: '长目录可滚动');
      await tester.drag(sheetList(), const Offset(0, -200));
      await tester.pumpAndSettle();
      final double scrolled =
          tester.widget<ListView>(sheetList()).controller!.position.pixels;
      expect(scrolled, greaterThan(0));

      // 关闭弹层（点 drag handle 外的遮罩关闭）。
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);

      // 再次打开：回到上次目录位置（而非默认顶部）。
      await tester.tap(find.byTooltip('目录'));
      await tester.pumpAndSettle();
      final double reopened =
          tester.widget<ListView>(sheetList()).controller!.position.pixels;
      expect(reopened, closeTo(scrolled, 1.0), reason: '目录位置被记住');
    });

    testWidgets('变更搜索条件 → 目录位置作废回顶（不把旧条件位置带过来）', (WidgetTester tester) async {
      useSurface(tester, height: 600);
      await tester.pumpWidget(testApp(FakeBookRepository(library: pagedLibrary()), initial: '/search?q='));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('目录'));
      await tester.pumpAndSettle();
      await tester.drag(sheetList(), const Offset(0, -200));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();

      // 换搜索词（新条件签名）→ 目录位置重置。
      await tester.enterText(find.byType(TextField).first, '分页书1');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('目录'));
      await tester.pumpAndSettle();
      final double reopened =
          tester.widget<ListView>(sheetList()).controller!.position.pixels;
      expect(reopened, 0, reason: '换词后目录从顶部开始');
    });

    testWidgets('目录位置持久化：写入 settings KV（跨 App 重启恢复的前提）',
        (WidgetTester tester) async {
      final MemoryKv kv = MemoryKv();
      useSurface(tester, height: 600);
      await tester.pumpWidget(testApp(
        FakeBookRepository(library: pagedLibrary()),
        initial: '/search?q=',
        extraOverrides: <Override>[
          searchTocPositionStoreProvider.overrideWithValue(SearchPositionStore(kv, key: SettingsKeys.searchTocPositions)),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('目录'));
      await tester.pumpAndSettle();
      await tester.drag(sheetList(), const Offset(0, -200));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();
      await tester.pump(); // dispose 里的 save 是微任务链，推进一帧让它落库。

      expect(kv.values.containsKey(SettingsKeys.searchTocPositions), isTrue,
          reason: '关闭目录时把位置写入独立 settings 键');
      final Map<String, dynamic> saved =
          jsonDecode(kv.values[SettingsKeys.searchTocPositions]!) as Map<String, dynamic>;
      expect(saved.values.single as num, greaterThan(0), reason: '存的是目录滚动偏移');
      expect(saved.keys.single, searchPositionSignature(const SearchFilter()),
          reason: '键 = 当前条件签名（换条件互不串位）');
    });
  });
}
