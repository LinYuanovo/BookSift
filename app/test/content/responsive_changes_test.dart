// 本次改造的竖屏/宽屏适配守卫（替代无法做视觉判读的模拟器截图核对）：
// 在真机竖屏逻辑尺寸（480×1066，对应 1440×3200@3x）与宽屏 expanded（1280×800）下，
// 逐页断言「零 overflow」且本轮新增元素在场。
//
// 覆盖：搜索页（多行筛选面板 + 确认钮 + 联动）、帖子详情（作者可点/查看）、书聚合（查看）、
// 首页时间线（50 字正文摘要）。全部 testWidgets，内存 fake 仓，零真实 IO（TESTING.md §1）。
library;

import 'package:booksift/features/content/content_detail_page.dart';
import 'package:booksift/features/home/cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import '../support/harness.dart';

/// 真机竖屏逻辑尺寸（1440×3200 physical，dpr 3）。
void usePhonePortrait(WidgetTester tester) =>
    useSurface(tester, width: 480, height: 1066, dpr: 3);

void main() {
  late FakeBookRepository repo;
  setUp(() => repo = FakeBookRepository(library: demoLibrary()));

  group('竖屏（480×1066）零溢出 + 新元素在场', () {
    testWidgets('搜索页：多行换行筛选 chips + 确认钮 + 结果列表', (WidgetTester tester) async {
      usePhonePortrait(tester);
      await tester.pumpWidget(testApp(repo, initial: '/search?q='));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '竖屏零 overflow');
      expect(find.text('年·全部'), findsOneWidget);
      expect(find.text('类别·全部'), findsOneWidget);
      expect(find.byTooltip('确认筛选'), findsOneWidget);
      expect(find.text('条件浏览'), findsOneWidget);
    });

    testWidgets('帖子详情：作者名可点；书架 chips + 查看/原帖外链在场', (WidgetTester tester) async {
      usePhonePortrait(tester);
      await tester.pumpWidget(testApp(repo, initial: '/post/7'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '竖屏零 overflow');
      expect(find.text('扫书人甲'), findsOneWidget, reason: '作者名在场（可点）');
      expect(find.byType(PostBookChip), findsWidgets);
    });

    testWidgets('书聚合：评价卡「查看」在场', (WidgetTester tester) async {
      usePhonePortrait(tester);
      await tester.pumpWidget(testApp(repo, initial: '/book/900'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '竖屏零 overflow');
      expect(find.text('查看'), findsWidgets);
      expect(find.byType(BookEntryCard), findsWidgets);
    });

    testWidgets('首页时间线：卡片标题下正文摘要（含楼层回退）不超 100 字 + …',
        (WidgetTester tester) async {
      usePhonePortrait(tester);
      await tester.pumpWidget(testApp(repo, initial: '/home'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // demo 帖 7 楼层正文含《篡水浒》… 摘要应在（100 字截断 + …）。
      expect(find.byType(PostCard), findsWidgets);
      final bool hasSummary = tester
          .widgetList<Text>(find.byType(Text))
          .any((Text t) => (t.data ?? '').endsWith('…'));
      expect(hasSummary, isTrue, reason: '时间线卡片展示截断后的正文摘要');
    });
  });

  group('宽屏 expanded（1280×800）零溢出 + 新元素在场', () {
    testWidgets('搜索页宽屏：多行换行 chips + 确认钮', (WidgetTester tester) async {
      useSurface(tester, width: 1280, height: 800);
      await tester.pumpWidget(testApp(repo, initial: '/search?q='));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '宽屏零 overflow');
      expect(find.text('年·全部'), findsOneWidget);
      expect(find.byTooltip('确认筛选'), findsOneWidget);
    });

    testWidgets('宽屏书聚合：评价卡零溢出 + 查看在场', (WidgetTester tester) async {
      useSurface(tester, width: 1280, height: 800);
      await tester.pumpWidget(testApp(repo, initial: '/book/900'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '宽屏零 overflow');
      expect(find.text('查看'), findsWidgets);
    });

    testWidgets('宽屏帖子详情（右槽形态）：作者可点 + 楼层流零溢出', (WidgetTester tester) async {
      useSurface(tester, width: 1280, height: 800);
      await tester.pumpWidget(testApp(repo, initial: '/home'));
      await tester.pumpAndSettle();
      // 点时间线卡片 → expanded 右槽接管。
      await tester.tap(find.text('【扫书】yy小说吧四月下旬合集').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '宽屏右槽零 overflow');
      expect(find.byType(ContentDetailPage), findsOneWidget);
    });
  });
}

