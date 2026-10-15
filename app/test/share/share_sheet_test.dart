import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/icons.dart';
import 'package:booksift/features/share/share_card.dart';
import 'package:booksift/features/share/share_service.dart';
import 'package:booksift/features/share/share_sheet.dart';

import '../support/harness.dart' show dismissSnackBars, useSurface;
import 'support.dart';

// 文字转图分享弹层（M3 P1-4，原型 §5.11）：参数面板 → 实时卡片的联动、截断提示、
// 保存/分享两条出口、自由模式、以及「弹层内零 Material Icon」守卫。
//
// 零真实 IO：栅格化注入 fakeRenderPng（纯微任务）、导出注入 FakeShareSink；
// 真 toImage 的断言在 share_card_render_test.dart 里走 tester.runAsync（TESTING.md §3.1/§3.4）。

/// 弹层内 Finder（把断言收窄到 sheet 子树，避免与宿主 Scaffold 混淆）。
Finder _inSheet(Finder matching) => find.descendant(of: find.byType(ShareSheet), matching: matching);

void main() {
  group('弹层结构（§5.11 线框：卡片 + 参数面板 + 保存/分享）', () {
    testWidgets('标题/预览卡/字号·行距步进/4 配色 swatch/水印框/两个导出按钮齐活', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      await openShareSheet(tester, demoShareSpec);

      expect(find.text('生成图片'), findsOneWidget);
      expect(_inSheet(find.byType(ShareCard)), findsOneWidget);
      // 导出锚点：RepaintBoundary 常驻在预览区（不做 tab 切换隐藏，见 share_sheet.dart 文件头）。
      expect(_inSheet(find.byType(RepaintBoundary)), findsWidgets);

      // 步进控件（cards.dart MetaChip 复用）：A-/A+、L-/L+ 与当前读数。
      for (final String label in <String>['A-', 'A+', 'L-', 'L+']) {
        expect(_inSheet(find.text(label)), findsOneWidget);
      }
      expect(_inSheet(find.text('16')), findsOneWidget, reason: '字号读数');
      expect(_inSheet(find.text('1.7')), findsOneWidget, reason: '行距读数');

      // 4 配色 swatch（白/黑/绿/米）。
      for (final ShareCardPalette p in ShareCardPalette.values) {
        expect(_inSheet(find.text(p.label)), findsOneWidget);
      }
      expect(_inSheet(find.text('配色')), findsOneWidget);

      // 水印框预填默认值；两个出口按钮（本机非移动端 → 「保存图片」口径）。
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('扫书汇APP | BY 残梦灬语宵'), findsWidgets);
      expect(find.text('保存图片'), findsOneWidget);
      expect(find.text('分享…'), findsOneWidget);
      expect(find.text('保存到相册'), findsNothing, reason: '桌面口径不谎称能存相册');
    });

    testWidgets('图标守卫：弹层内零 Material Icon，结构图标全走设计 SVG', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      await openShareSheet(tester, demoShareSpec);

      expect(_inSheet(find.byType(Icon)), findsNothing);
      expect(_inSheet(find.byType(SvgPicture)), findsWidgets, reason: '关闭 + 选中 swatch 的勾');
      expect(
        tester.widgetList<AppIcon>(_inSheet(find.byType(AppIcon))).map((AppIcon i) => i.name),
        containsAll(<String>['close', 'check']),
      );
      // 导出物本身不含图标资产（栅格化不依赖 asset 解码）。
      expect(find.descendant(of: find.byType(ShareCard), matching: find.byType(SvgPicture)), findsNothing);
    });
  });

  group('参数域联动（字号 8–30 / 行距 1.0–3.0 / 4 配色 / 水印）', () {
    testWidgets('A+ / A- 实时改正文字号，读数同步', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      await openShareSheet(tester, demoShareSpec);
      expect(cardSpecOf(tester).fontSize, 16);

      await tester.tap(find.text('A+'));
      await tester.pumpAndSettle();
      expect(cardSpecOf(tester).fontSize, 17);
      expect(_inSheet(find.text('17')), findsOneWidget);

      await tester.tap(find.text('A-'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A-'));
      await tester.pumpAndSettle();
      expect(cardSpecOf(tester).fontSize, 15);
      expect(_inSheet(find.text('15')), findsOneWidget);
    });

    testWidgets('字号顶到上限 30 后 A+ 不再加（§5.11 值域）', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      await openShareSheet(tester, const ShareCardSpec(fontSize: ShareCardSpec.maxFontSize));
      await tester.tap(find.text('A+'));
      await tester.pumpAndSettle();
      expect(cardSpecOf(tester).fontSize, 30);
    });

    testWidgets('L+ / L- 步进 0.1，读数同步', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      await openShareSheet(tester, demoShareSpec);

      await tester.tap(find.text('L+'));
      await tester.pumpAndSettle();
      expect(cardSpecOf(tester).lineHeight, 1.8);
      expect(_inSheet(find.text('1.8')), findsOneWidget);

      await tester.tap(find.text('L-'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('L-'));
      await tester.pumpAndSettle();
      expect(cardSpecOf(tester).lineHeight, 1.6);
    });

    testWidgets('行距落到下限 1.0 后 L- 不再减（§5.11 值域）', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      await openShareSheet(tester, const ShareCardSpec(lineHeight: ShareCardSpec.minLineHeight));
      await tester.tap(find.text('L-'));
      await tester.pumpAndSettle();
      expect(cardSpecOf(tester).lineHeight, 1.0);
      expect(_inSheet(find.text('1.0')), findsOneWidget);
    });

    testWidgets('点 swatch 换配色：卡片底色随之改变，勾标跟着走', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      await openShareSheet(tester, demoShareSpec);
      expect(cardSpecOf(tester).palette, ShareCardPalette.paper);

      await tester.tap(find.text('绿'));
      await tester.pumpAndSettle();
      expect(cardSpecOf(tester).palette, ShareCardPalette.moss);
      expect(tester.widget<ShareCard>(_inSheet(find.byType(ShareCard))).spec.palette.background,
          ShareCardPalette.moss.background);

      await tester.tap(find.text('黑'));
      await tester.pumpAndSettle();
      expect(cardSpecOf(tester).palette, ShareCardPalette.ink);

      await tester.tap(find.text('米'));
      await tester.pumpAndSettle();
      expect(cardSpecOf(tester).palette, ShareCardPalette.sand);
      // 选中的 swatch 才挂勾（AppIcon('check')），其余三枚不挂。
      expect(_inSheet(find.byType(AppIcon).hitTestable()), findsWidgets);
    });

    testWidgets('水印可编辑：改即上卡片，清空回落默认（§5.11）', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      await openShareSheet(tester, demoShareSpec);

      await tester.enterText(find.byType(TextField), '扫书汇 | 残梦手写');
      await tester.pumpAndSettle();
      expect(cardSpecOf(tester).effectiveWatermark, '扫书汇 | 残梦手写');
      expect(
        find.descendant(of: find.byType(ShareCard), matching: find.text('扫书汇 | 残梦手写')),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(cardSpecOf(tester).effectiveWatermark, '扫书汇APP | BY 残梦灬语宵');
      expect(
        find.descendant(of: find.byType(ShareCard), matching: find.text('扫书汇APP | BY 残梦灬语宵')),
        findsOneWidget,
      );
    });
  });

  group('错误态：>8000 字截断（§5.11）', () {
    testWidgets('给出明确截断提示，卡片只渲染前 8000 字 + 标记', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      final ShareCardSpec over = demoShareSpec.copyWith(quote: '字' * (ShareCardSpec.maxQuoteChars + 1));
      await openShareSheet(tester, over);

      expect(_inSheet(find.textContaining('超过 8000 字上限')), findsOneWidget);
      expect(_inSheet(find.textContaining('8001 字')), findsOneWidget);
      expect(cardSpecOf(tester).displayQuote, endsWith(ShareCardSpec.truncatedSuffix));
      expect(
        find.descendant(of: find.byType(ShareCard), matching: find.textContaining('…（已截断）')),
        findsOneWidget,
      );
    });

    testWidgets('未超限不挂截断提示', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      await openShareSheet(tester, demoShareSpec);
      expect(_inSheet(find.textContaining('已截断')), findsNothing);
    });
  });

  group('导出出口（保存 / 分享）', () {
    testWidgets('保存：字节交 sink + SnackBar 报落盘路径（桌面口径）', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      final FakeShareSink sink = FakeShareSink();
      await openShareSheet(tester, demoShareSpec, sink: sink);

      await tester.tap(find.text('保存图片'));
      await tester.pumpAndSettle();

      expect(sink.savedBytes.single, fakePng());
      expect(sink.savedNames.single, matches(RegExp(r'^booksift_share_\d{8}_\d{6}\.png$')));
      expect(find.textContaining(r'C:\Users\x\Documents\booksift_share'), findsOneWidget);
      // 弹层不自动关（用户可能接着点分享）。
      expect(find.byType(ShareSheet), findsOneWidget);
      await dismissSnackBars(tester);
    });

    testWidgets('保存被取消 / 失败：SnackBar 说人话，弹层不崩', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      final FakeShareSink sink = FakeShareSink()
        ..saveOutcome = const ShareOutcome(ShareOutcomeKind.cancelled, message: '已取消保存');
      await openShareSheet(tester, demoShareSpec, sink: sink);

      await tester.tap(find.text('保存图片'));
      await tester.pumpAndSettle();
      expect(find.text('已取消保存'), findsOneWidget);
      await dismissSnackBars(tester);

      sink.saveOutcome = const ShareOutcome(ShareOutcomeKind.failed, message: '保存失败：磁盘满');
      await tester.tap(find.text('保存图片'));
      await tester.pumpAndSettle();
      expect(find.text('保存失败：磁盘满'), findsOneWidget);
      expect(find.byType(ShareSheet), findsOneWidget);
      await dismissSnackBars(tester);
    });

    testWidgets('分享：交系统面板，带卡片文案与 iPad 锚点矩形', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      final FakeShareSink sink = FakeShareSink();
      await openShareSheet(tester, demoShareSpec, sink: sink);

      await tester.tap(find.text('分享…'));
      await tester.pumpAndSettle();

      expect(sink.sharedBytes.single, fakePng());
      expect(sink.shareText, '《十日终焉》 · 扫书汇APP | BY 残梦灬语宵');
      expect(sink.shareOrigin, isNotNull, reason: 'share_plus 在 iPad 上要 popover 锚点');
      expect(sink.shareOrigin!.width, greaterThan(0));
      expect(find.text('已交给系统分享面板'), findsOneWidget);
      await dismissSnackBars(tester);
    });

    testWidgets('分享不可用 → 平台层降级保存的文案原样透出', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      final FakeShareSink sink = FakeShareSink()
        ..shareOutcome = const ShareOutcome(
          ShareOutcomeKind.saved,
          path: '/tmp/x.png',
          message: '系统分享不可用（UnimplementedError），已改为保存到：/tmp/x.png',
        );
      await openShareSheet(tester, demoShareSpec, sink: sink);

      await tester.tap(find.text('分享…'));
      await tester.pumpAndSettle();
      expect(find.textContaining('已改为保存到'), findsOneWidget);
      await dismissSnackBars(tester);
    });
  });

  group('自由模式（我的 → 工具，§5.11）', () {
    testWidgets('多出书名/作者/正文三框，输入即改卡片', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      await openShareSheet(tester, const ShareCardSpec(), freeMode: true);

      expect(find.text('自由模式 · 手动输入或粘贴文本'), findsOneWidget);
      expect(_inSheet(find.text('内容')), findsOneWidget);
      // 书名 / 作者 / 正文 / 水印 = 4 个输入框（顺序即构建顺序）。
      expect(find.byType(TextField), findsNWidgets(4));

      await tester.enterText(find.byType(TextField).at(0), '十日终焉');
      await tester.pumpAndSettle();
      expect(cardSpecOf(tester).headline, '《十日终焉》');
      expect(find.descendant(of: find.byType(ShareCard), matching: find.text('《十日终焉》')), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(1), '杀虫队队员');
      await tester.pumpAndSettle();
      expect(cardSpecOf(tester).creditLine, '杀虫队队员');

      await tester.enterText(find.byType(TextField).at(2), '悬疑无限流，十日一轮。');
      await tester.pumpAndSettle();
      expect(cardSpecOf(tester).quote, '悬疑无限流，十日一轮。');
      expect(
        find.descendant(of: find.byType(ShareCard), matching: find.textContaining('十日一轮')),
        findsOneWidget,
      );
      // 无推荐人 → 默认水印只留品牌段。
      expect(cardSpecOf(tester).defaultWatermark, '扫书汇APP');
    });

    testWidgets('非自由模式（帖子/书聚合入口）不给内容输入框，只给参数面板', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      await openShareSheet(tester, demoShareSpec);
      expect(find.text('实时预览 · 导出 PNG（2.5×）'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget, reason: '只有水印框');
      expect(_inSheet(find.text('内容')), findsNothing);
    });
  });

  group('关闭', () {
    testWidgets('关闭按钮收起弹层', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      await openShareSheet(tester, demoShareSpec);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(find.byType(ShareSheet), findsNothing);
    });
  });
}
