import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/icons.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/features/content/book_detail_page.dart';
import 'package:booksift/features/home/cards.dart';
import 'package:booksift/features/share/share_card.dart';
import 'package:booksift/features/share/share_sheet.dart';

import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import '../support/harness.dart' show testApp, useSurface;
import 'support.dart';

// 三处入口接线（原型 §5.11）：帖子详情 ⋮「分享扫书」（带正文）/ 书聚合 ⋮「导出该书推荐」
// （拼接多条）/ 我的→工具「文字转图」（自由模式）。
//
// 只断言「入口把什么载荷送进弹层」，不点导出按钮 —— 弹层默认服务是真 ShareService，
// 一旦点导出就会走真实 toImage（TESTING.md §1）；导出链路由 share_card_render_test /
// share_sheet_test 分别覆盖。

void main() {
  late FakeBookRepository repo;

  group('入口接线', () {
    setUp(() => repo = FakeBookRepository(library: demoLibrary()));

    testWidgets('帖子详情 ⋮「分享扫书」：带帖标题 + 全部楼层正文 + 发帖人当推荐人',
        (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      await tester.pumpWidget(testApp(repo, initial: '/post/7'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      expect(find.text('分享扫书'), findsOneWidget);
      await tester.tap(find.text('分享扫书'));
      await tester.pumpAndSettle();

      expect(find.byType(ShareSheet), findsOneWidget);
      final ShareCardSpec spec = cardSpecOf(tester);
      // 帖子无书名语义 → 走 title 行（不套《》）。
      expect(spec.headline, '【扫书】yy小说吧四月下旬合集');
      expect(spec.author, '扫书人甲');
      expect(spec.recommender, '扫书人甲');
      expect(spec.defaultWatermark, '扫书汇APP | BY 扫书人甲');
      // 两楼正文以空行拼接（不带「N楼」前缀，卡片是引用文而非楼层流）。
      expect(spec.quote.split('\n\n'), hasLength(2));
      expect(spec.quote, contains('《篡水浒》'));
      expect(spec.quote, contains('tieba.baidu.com/p/11097754039'));
    });

    testWidgets('书聚合 ⋮「导出该书推荐」：书名 + 作者 + 多条推荐语拼接（推荐人/日期/排雷署名）',
        (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      await tester.pumpWidget(testApp(repo, home: const BookDetailPage(bookGroupId: 904)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      expect(find.text('导出该书推荐'), findsOneWidget);
      await tester.tap(find.text('导出该书推荐'));
      await tester.pumpAndSettle();

      expect(find.byType(ShareSheet), findsOneWidget);
      final ShareCardSpec spec = cardSpecOf(tester);
      expect(spec.headline, '《逍遥小书生》');
      expect(spec.author, '荣荣');
      // 语料 904 两条：2013 有推荐语、2014（排雷）无 → 只拼有推荐语的那条，不塞占位行。
      expect(spec.quote, contains('轻松日常向，主角讨喜，适合下饭，更新也稳定。'));
      expect(spec.quote, contains('推荐人 推荐人2013'));
      expect(spec.quote, contains('2025-03-30'));
      expect(spec.quote, isNot(contains('（该条无推荐语）')));
      expect(spec.recommender, '推荐人2013');
      expect(spec.defaultWatermark, '扫书汇APP | BY 推荐人2013');
    });

    testWidgets('书聚合导出跟随当前语义筛选：仅排雷 → 无推荐语条目显式标注 + 排雷署名',
        (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      await tester.pumpWidget(testApp(repo, home: const BookDetailPage(bookGroupId: 904)));
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(
        of: find.byType(SegmentedPill<SemanticFilter>),
        matching: find.text('仅排雷'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('导出该书推荐'));
      await tester.pumpAndSettle();

      final ShareCardSpec spec = cardSpecOf(tester);
      expect(spec.quote, contains('（该条无推荐语）'), reason: '不静默丢条目，显式标注');
      expect(spec.quote, contains('排雷'));
      expect(spec.quote, contains('推荐人2014'));
      expect(spec.quote, isNot(contains('轻松日常向')), reason: '被筛掉的推荐条目不进卡片');
    });

    testWidgets('我的 → 工具「文字转图」：AppIcon(share) 入口 + 自由模式弹层', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      await tester.pumpWidget(testApp(repo, initial: '/profile'));
      await tester.pumpAndSettle();

      expect(_inSheet(find.text('工具')), findsNothing);
      expect(find.text('工具'), findsOneWidget, reason: 'SectionTitle 分区头');
      expect(find.text('文字转图'), findsOneWidget);

      // 入口图标走设计稿 SVG（i-share）；行尾 chevron 亦已迁设计 SVG（i-chev），tile 内零 Material Icon。
      final Finder tile = find.ancestor(of: find.text('文字转图'), matching: find.byType(ListTile));
      expect(
        tester.widget<AppIcon>(find.descendant(
          of: tile, matching: find.byWidgetPredicate((Widget w) => w is AppIcon && w.name == 'share'),
        )).name,
        'share',
      );
      expect(
        find.descendant(of: tile, matching: find.byWidgetPredicate((Widget w) => w is AppIcon && w.name == 'chev')),
        findsOneWidget,
        reason: '行尾 chevron = 设计 SVG（i-chev 右向）',
      );
      expect(find.descendant(of: tile, matching: find.byType(Icon)), findsNothing);

      await tester.tap(find.text('文字转图'));
      await tester.pumpAndSettle();
      expect(find.byType(ShareSheet), findsOneWidget);
      expect(find.text('自由模式 · 手动输入或粘贴文本'), findsOneWidget);
      // 书名/作者/正文/水印 = 4 框。
      expect(find.byType(TextField), findsNWidgets(4));
      expect(cardSpecOf(tester).quote, isEmpty);
    });
  });
}

/// 弹层内 Finder（入口测试里也用来断言「弹层未开时不误命中」）。
Finder _inSheet(Finder matching) => find.descendant(of: find.byType(ShareSheet), matching: matching);
