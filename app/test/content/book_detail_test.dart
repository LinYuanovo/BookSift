import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/constants.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/features/content/book_detail_page.dart';
import 'package:booksift/features/content/content_detail_page.dart';
import 'package:booksift/features/home/cards.dart';
import 'package:booksift/theme/app_colors.dart';
import 'package:booksift/theme/app_spacing.dart';

import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import '../support/harness.dart';

// 书聚合页改造验收（§5.5）：
//   · 任务 1 目录跳转：appbar「目录」入口（仅条目非空时显示）→ 弹层行列出当前筛选条目
//     （推荐人 · 日期 · 评论首行）→ 点行关闭弹层并 ensureVisible 滚动到对应卡片；
//   · 任务 2 ScrollChrome 接入：跳顶/跳底按钮的停留隐藏计时挂在假时钟上，滚动后须推进收掉；
//   · 任务 3 卡片本体 onTap 直达原帖（与「原帖 ↗」同语义，cards.dart 既有接线，本页只传参）。
//
// 全部 testWidgets 零真实 IO（FakeBookRepository + harness 三哨兵，app/test/TESTING.md §3.1）。

/// 目录行文字色（弹层内按行文案定位 ListTile 的标题 Text）。
Color tocColorOf(WidgetTester tester, String label) {
  final Finder tile = find.widgetWithText(ListTile, label);
  expect(tile, findsOneWidget, reason: '目录里有 $label');
  return tester.widget<Text>(find.descendant(of: tile, matching: find.byType(Text)).first).style!.color!;
}

/// 长目录语料：同一书组 40 条目（远超一屏 → 弹层须撑满高度上限并在内部滚动）。
FakeLibrary longTocLibrary() {
  return FakeLibrary(
    posts: const <Post>[],
    floors: const <int, List<FloorData>>{},
    entries: <EntryRow>[
      for (int i = 1; i <= 40; i++)
        EntryRow(
          id: i,
          name: '《多目录书》',
          nameNorm: '多目录书',
          channel: 'yy小说吧',
          category: CategoryKind.scan,
          origin: Origin.builtin,
          quality: 2,
          date: '2025-01-01',
          recommender: '推荐人$i',
          comment: '第 $i 条推荐语。',
          bookGroupId: 1,
        ),
    ],
    groups: <BookGroup>[
      BookGroup(id: 1, nameNorm: '多目录书', authorEffNorm: '', entryTotal: 40, distinctComment: 40),
    ],
  );
}

/// 只有外链、无帖溯源的单条目语料（验证「原帖 ↗」走系统外跳而非复制剪贴板）。
FakeLibrary urlOnlyLibrary() {
  return FakeLibrary(
    posts: const <Post>[],
    floors: const <int, List<FloorData>>{},
    entries: <EntryRow>[
      EntryRow(
        id: 1,
        name: '《外链书》',
        nameNorm: '外链书',
        channel: 'yy小说吧',
        category: CategoryKind.scan,
        origin: Origin.builtin,
        quality: 2,
        recommender: '甲',
        comment: '只有外链的那条',
        srcUrl: 'https://tieba.baidu.com/p/11097754039',
        bookGroupId: 1,
      ),
    ],
    groups: <BookGroup>[
      BookGroup(id: 1, nameNorm: '外链书', authorEffNorm: '', entryTotal: 1, distinctComment: 1),
    ],
  );
}

/// 按条目 id 定位卡片（不依赖排序稳定性）。
Finder cardOf(int id) => find.byWidgetPredicate((Widget w) => w is BookEntryCard && w.entry.id == id);

/// 外链两条平台通道 mock（口径同 content/thread_link_test.dart；TESTING.md §1：
/// 未注册通道在假时钟区**永不返回**，失败提示也就不会出现）：
/// booksift/external_launch → false（等价无原生宿主）、url_launcher canLaunch → false
/// ⇒ openThreadExternally 恒 false → 出「没有可打开原帖的应用」。
void mockExternalLaunch(WidgetTester tester) {
  const MethodChannel external = MethodChannel('booksift/external_launch');
  const MethodChannel launcher = MethodChannel('plugins.flutter.io/url_launcher');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(external, (MethodCall call) async => false);
  tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(launcher, (MethodCall call) async => call.method == 'canLaunch' ? false : null);
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(external, null);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(launcher, null);
  });
}

/// 捕获 Clipboard.setData：外链条目**不再**走复制兜底，故断言其恒空。
List<String> mockClipboard(WidgetTester tester) {
  final List<String> copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
    if (call.method == 'Clipboard.setData') {
      copied.add((call.arguments as Map<dynamic, dynamic>)['text'] as String);
    }
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return copied;
}

void main() {
  late FakeBookRepository repo;

  setUp(() {
    repo = FakeBookRepository(library: demoLibrary());
  });

  group('书聚合页书名快速复制', () {
    testWidgets('长按书名复制不带书名号的书名', (WidgetTester tester) async {
      final List<String> copied = mockClipboard(tester);
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, home: const BookDetailPage(bookGroupId: 900)));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('《我不想和你一起重生》'));
      await tester.pumpAndSettle();

      expect(copied, <String>['我不想和你一起重生']);
      expect(find.text('书名已复制到剪贴板'), findsOneWidget);
      await dismissSnackBars(tester);
    });

    testWidgets('双击书名复制不带书名号的书名', (WidgetTester tester) async {
      final List<String> copied = mockClipboard(tester);
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, home: const BookDetailPage(bookGroupId: 900)));
      await tester.pumpAndSettle();

      final Finder title = find.text('《我不想和你一起重生》');
      await tester.tap(title);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(title);
      await tester.pumpAndSettle();

      expect(copied, <String>['我不想和你一起重生']);
      expect(find.text('书名已复制到剪贴板'), findsOneWidget);
      await dismissSnackBars(tester);
    });
  });

  group('书聚合页目录', () {
    testWidgets('入口仅条目非空时显示；弹层行 = 当前筛选条目；点行关闭弹层并滚动定位', (WidgetTester tester) async {
      // 压低视口保证列表可滚动（滚动断言不依赖布局像素估计）。
      useSurface(tester, height: 600);
      await tester.pumpWidget(testApp(repo, home: const BookDetailPage(bookGroupId: 900)));
      await tester.pumpAndSettle();

      // 目录入口 = appbar「目录」IconButton（900「我不想和你一起重生」3 条目非空 → 显示）。
      final Finder tocButton = find.byTooltip('目录');
      expect(tocButton, findsOneWidget);
      await tester.tap(tocButton);
      await tester.pumpAndSettle();

      // 弹层 3 行 = 当前筛选（全部）下条目；行文案「推荐人 · 日期 · 评论首行」（单行省略仅影响渲染）。
      expect(find.byType(ListTile), findsNWidgets(3));
      expect(find.text('推荐人2006 · 2025-04-02 · 重生加恋爱游戏设定，前期笑点密集，节奏轻快不拖沓。'), findsOneWidget);
      expect(find.text('推荐人2007 · 2025-04-10'), findsOneWidget);
      expect(find.text('推荐人2008 · 2025-04-22'), findsOneWidget);

      // 点末行 → 关闭弹层并滚动到对应条目卡片。
      await tester.tap(find.text('推荐人2008 · 2025-04-22'));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNothing, reason: '弹层应已关闭');

      final ScrollableState scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
      expect(scrollable.position.pixels, greaterThan(0), reason: '目录点击应触发滚动定位');

      // ScrollChrome 跳顶/跳底按钮的 1.6s 停留隐藏计时挂在假时钟上，推进收掉（TESTING.md §3.5）。
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    });

    testWidgets('目录行口径：多行评论只取首行；推荐人/日期缺省段省略', (WidgetTester tester) async {
      final FakeBookRepository custom = FakeBookRepository(
        library: FakeLibrary(
          posts: const <Post>[],
          floors: const <int, List<FloorData>>{},
          entries: const <EntryRow>[
            EntryRow(
              id: 1,
              name: '《多行书》',
              nameNorm: '多行书',
              channel: 'yy小说吧',
              category: CategoryKind.scan,
              origin: Origin.builtin,
              quality: 2,
              date: '2025-01-01',
              recommender: '甲',
              comment: '第一行\n第二行',
              bookGroupId: 1,
            ),
            EntryRow(
              id: 2,
              name: '《多行书》',
              nameNorm: '多行书',
              channel: 'yy小说吧',
              category: CategoryKind.scan,
              origin: Origin.builtin,
              quality: 1,
              comment: '只有评论',
              bookGroupId: 1,
            ),
          ],
          groups: const <BookGroup>[
            BookGroup(id: 1, nameNorm: '多行书', authorEffNorm: '', entryTotal: 2, distinctComment: 2),
          ],
        ),
      );
      useSurface(tester);
      await tester.pumpWidget(testApp(custom, home: const BookDetailPage(bookGroupId: 1)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('目录'));
      await tester.pumpAndSettle();

      final Finder sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('甲 · 2025-01-01 · 第一行')),
        findsOneWidget,
        reason: '评论取 entry.comment 第一行',
      );
      expect(find.descendant(of: sheet, matching: find.textContaining('第二行')), findsNothing);
      expect(
        find.descendant(of: sheet, matching: find.text('只有评论')),
        findsOneWidget,
        reason: '推荐人/日期缺省段直接省略（与 BookEntryCard 缺省不渲染同口径）',
      );

      // 点遮罩收掉弹层收尾。
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    });

    testWidgets('目录入口在条目为空时不显示', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, home: const BookDetailPage(bookGroupId: 99999)));
      await tester.pumpAndSettle();

      expect(find.text('书目不存在'), findsOneWidget);
      expect(find.byTooltip('目录'), findsNothing);
    });
  });

  group('书聚合页目录弹层形态', () {
    /// 弹层内的目录 ListView。
    Finder sheetList() => find.descendant(of: find.byType(BottomSheet), matching: find.byType(ListView));

    double capOf(WidgetTester tester) => tester
        .widget<ConstrainedBox>(find.ancestor(of: sheetList(), matching: find.byType(ConstrainedBox)).first)
        .constraints
        .maxHeight;

    double scrollExtentOf(WidgetTester tester) => tester
        .state<ScrollableState>(
            find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first)
        .position
        .maxScrollExtent;

    testWidgets('高度上限 = 屏幕可用高 × tocSheetHeightFactor；短目录按内容收缩', (WidgetTester tester) async {
      useSurface(tester, height: 600);
      await tester.pumpWidget(testApp(repo, initial: '/book/900'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('目录'));
      await tester.pumpAndSettle();

      final double cap = 600 * AppMetrics.tocSheetHeightFactor;
      expect(cap, 420, reason: '令牌值口径（0.7）');
      expect(capOf(tester), cap, reason: 'ConstrainedBox 收口到 70% 可用高度（口径同搜索结果目录）');
      expect(tester.getSize(sheetList()).height, lessThan(cap), reason: '3 行短目录不硬撑到上限');
      expect(scrollExtentOf(tester), 0, reason: '不足一屏 → 无需滚动');
      expect(tester.getRect(find.byType(BottomSheet)).height, lessThan(600), reason: '不再铺满全屏');
    });

    testWidgets('长目录撑满上限，余量在弹层内滚动', (WidgetTester tester) async {
      useSurface(tester, height: 600);
      await tester.pumpWidget(testApp(FakeBookRepository(library: longTocLibrary()), initial: '/book/1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('目录'));
      await tester.pumpAndSettle();

      final double cap = 600 * AppMetrics.tocSheetHeightFactor;
      // ListView 懒构建：只断言「行数远超一屏」+ 撑满上限，不数全部 40 行。
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.byType(ListTile)), findsWidgets);
      expect(tester.getSize(sheetList()).height, cap, reason: '40 行远超上限 → 撑满并在弹层内滚动');
      expect(scrollExtentOf(tester), greaterThan(0));
      expect(tester.getRect(find.byType(BottomSheet)).height, lessThan(600), reason: '仍不占满全屏');
    });

    testWidgets('目录行按条目语义染色：推荐绿 / 排雷红', (WidgetTester tester) async {
      useSurface(tester, height: 600);
      await tester.pumpWidget(testApp(repo, initial: '/book/904'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('目录'));
      await tester.pumpAndSettle();

      final AppColors c = AppColors.of(tester.element(find.byType(BottomSheet)));
      // 904：2013 绿标 → 推荐；2014 红标 → 排雷。
      expect(tocColorOf(tester, '推荐人2013 · 2025-03-30 · 轻松日常向，主角讨喜，适合下饭，更新也稳定。'), c.recommend);
      expect(tocColorOf(tester, '推荐人2014 · 2024-06-11'), c.danger);
    });

    testWidgets('目录行染色：无颜色标记的扫书条目 = 常规文本色（中性）', (WidgetTester tester) async {
      useSurface(tester, height: 600);
      await tester.pumpWidget(testApp(repo, initial: '/book/900'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('目录'));
      await tester.pumpAndSettle();

      final AppColors c = AppColors.of(tester.element(find.byType(BottomSheet)));
      // 900 三条均无 book_grade → 新口径中性（旧口径会按 category=扫书 全染推荐绿）。
      expect(tocColorOf(tester, '推荐人2007 · 2025-04-10'), c.text);
      expect(tocColorOf(tester, '推荐人2008 · 2025-04-22'), c.text);
    });
  });

  group('书聚合页卡片直达原帖', () {
    testWidgets('点卡片本体（评论文本，非书名/推荐人/原帖热区）触发 _openEntrySource 兜底提示',
        (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, home: const BookDetailPage(bookGroupId: 904)));
      await tester.pumpAndSettle();

      // 条目 2013（无 postRef / srcUrl）：点评论文本 = 卡片整体 onTap（AccentCard InkWell）。
      await tester.tap(find.text('轻松日常向，主角讨喜，适合下饭，更新也稳定。'));
      await tester.pumpAndSettle();
      expect(find.text('原帖已不可溯源'), findsOneWidget);
      await dismissSnackBars(tester);
    });

    testWidgets('点卡片本体直达帖子详情（postRef → push /post/:id）', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, initial: '/book/900'));
      await tester.pumpAndSettle();

      // 条目 2006 postRef=20001：点评论文本 → _openEntrySource → openPostDetail。
      await tester.tap(find.text('重生加恋爱游戏设定，前期笑点密集，节奏轻快不拖沓。'));
      await tester.pumpAndSettle();

      expect(find.text('帖子详情'), findsOneWidget);
    });

    testWidgets('条目带 floorSeq → 进帖携 initialFloorSeq 直达该楼层', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, initial: '/book/900'));
      await tester.pumpAndSettle();

      // 语料 2008：postRef=7 / floorSeq=2。卡内不重复书名（hideBookName）→ 入口走「查看」。
      // 390dp 档：四档语义筛选行 + 排序触发器贴临界会折到第二行（book_detail 页 Wrap 布局），
      // 第 3 张卡落在首屏之外 → 先滚到可见再点（真机小屏同样需要滚动）。
      final Finder src088 = find.descendant(of: cardOf(2008), matching: find.text('查看'));
      await tester.ensureVisible(src088);
      await tester.pumpAndSettle();
      await tester.tap(src088);
      await tester.pumpAndSettle();

      final ContentDetailPage detail = tester.widget(find.byType(ContentDetailPage));
      expect(detail.selection.postId, 7);
      expect(detail.selection.initialFloorSeq, 2, reason: '条目所在楼层随选择载荷带进详情页');
    });

    testWidgets('条目无 floorSeq → initialFloorSeq 留空（进帖从头阅读）', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, initial: '/book/900'));
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(of: cardOf(2007), matching: find.text('查看')));
      await tester.pumpAndSettle();

      final ContentDetailPage detail = tester.widget(find.byType(ContentDetailPage));
      expect(detail.selection.postId, 18293);
      expect(detail.selection.initialFloorSeq, isNull);
    });

    testWidgets('无帖只有外链 → 交系统外跳，不再复制剪贴板', (WidgetTester tester) async {
      mockExternalLaunch(tester);
      final List<String> copied = mockClipboard(tester);
      useSurface(tester);
      await tester.pumpWidget(testApp(FakeBookRepository(library: urlOnlyLibrary()), initial: '/book/1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('查看'));
      await tester.pumpAndSettle();

      // 外跳失败如实告知（openThreadExternallyWithFeedback），且不落剪贴板、不进站内详情。
      expect(find.text('没有可打开原帖的应用'), findsOneWidget);
      expect(copied, isEmpty, reason: '复制兜底已删：外链一律交系统打开');
      expect(find.byType(ContentDetailPage), findsNothing, reason: '无帖溯源不进站内详情');
      await dismissSnackBars(tester);
    });
  });

  group('评价卡正文预览（comment 空 → 回退楼层正文；100 字截断）', () {
    testWidgets('comment 为空但有 floorText → 卡片展示楼层正文预览', (WidgetTester tester) async {
      final FakeBookRepository custom = FakeBookRepository(
        library: FakeLibrary(
          posts: const <Post>[],
          floors: const <int, List<FloorData>>{},
          entries: const <EntryRow>[
            EntryRow(
              id: 1,
              name: '《回退书》',
              nameNorm: '回退书',
              channel: 'yy小说吧',
              category: CategoryKind.scan,
              origin: Origin.builtin,
              quality: 2,
              date: '2025-01-01',
              // comment 为空（种子库 4169 条同态）；楼层正文在场。
              floorText: '楼层正文回退预览：这是一段来自楼层正文的正文内容。',
              bookGroupId: 1,
            ),
          ],
          groups: const <BookGroup>[
            BookGroup(id: 1, nameNorm: '回退书', authorEffNorm: '', entryTotal: 1, distinctComment: 1),
          ],
        ),
      );
      useSurface(tester);
      await tester.pumpWidget(testApp(custom, initial: '/book/1'));
      await tester.pumpAndSettle();
      expect(find.textContaining('楼层正文回退预览'), findsOneWidget, reason: 'comment 空 → 回退楼层正文');
    });

    testWidgets('超 100 字 → 折叠为前 100 字 + …（可展开全文）', (WidgetTester tester) async {
      final String long = "长${'字' * 140}";
      final FakeBookRepository custom = FakeBookRepository(
        library: FakeLibrary(
          posts: const <Post>[],
          floors: const <int, List<FloorData>>{},
          entries: <EntryRow>[
            EntryRow(
              id: 1,
              name: '《长评书》',
              nameNorm: '长评书',
              channel: 'yy小说吧',
              category: CategoryKind.scan,
              origin: Origin.builtin,
              quality: 2,
              date: '2025-01-01',
              comment: long,
              bookGroupId: 1,
            ),
          ],
          groups: const <BookGroup>[
            BookGroup(id: 1, nameNorm: '长评书', authorEffNorm: '', entryTotal: 1, distinctComment: 1),
          ],
        ),
      );
      useSurface(tester);
      await tester.pumpWidget(testApp(custom, initial: '/book/1'));
      await tester.pumpAndSettle();
      final String preview = '${String.fromCharCodes(long.runes.take(100))}…';
      expect(find.text(preview), findsOneWidget, reason: '折叠态 = 前 100 字 + …');
      expect(find.text(long), findsNothing);
    });
  });
}
