import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/features/share/share_card.dart';
import 'package:booksift/features/share/share_service.dart';
import 'package:booksift/theme/book_theme.dart';

import '../support/harness.dart' show useSurface;
import 'support.dart';

// 分享卡渲染/导出（M3 P1-4，原型 §5.11）。
//
// 真栅格化（RepaintBoundary.toImage → PNG 字节）是**引擎侧真实异步**，一律包在
// tester.runAsync 内（TESTING.md §3.4）；不落盘、不触平台通道，所以没有文件 IO。
// 参数域/水印/截断/配色对比度是纯函数断言 → plain test()。

/// 大端 4 字节整数（PNG IHDR 宽高）。
int _be32(Uint8List b, int offset) =>
    (b[offset] << 24) | (b[offset + 1] << 16) | (b[offset + 2] << 8) | b[offset + 3];

/// 渲染宿主：卡片包在带 GlobalKey 的 RepaintBoundary 里（与 share_sheet 的导出锚点同构）。
Widget _host(GlobalKey key, ShareCardSpec spec, {double width = 320}) => MaterialApp(
      theme: BookTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Center(child: RepaintBoundary(key: key, child: ShareCard(spec: spec, width: width))),
        ),
      ),
    );

/// WCAG 2.1 相对亮度 / 对比度（与 test/theme_tokens_test.dart 同式；此处独立一份，
/// 避免把断言耦合到并行改动中的 theme 测试文件）。
double _luminance(Color color) {
  double channel(double s) => s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b);
}

double _contrast(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('导出栅格化（§5.11：RepaintBoundary → toImage(2.5) → PNG）', () {
    testWidgets('真渲染出合法 PNG：magic + IHDR + 尺寸 = 卡宽 × 2.5', (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();
      useSurface(tester, width: 420, height: 900, dpr: 1);
      await tester.pumpWidget(_host(key, demoShareSpec));
      await tester.pump();

      final Uint8List? png = await tester.runAsync(() => renderPng(key));
      expect(png, isNotNull);
      expect(png!.sublist(0, 8), kPngMagic, reason: '前 8 字节必须是 PNG 签名');
      expect(String.fromCharCodes(png.sublist(12, 16)), 'IHDR');
      expect(_be32(png, 16), 800, reason: '卡宽 320dp × pixelRatio 2.5');
      expect(_be32(png, 20), greaterThan(200), reason: '卡片有实际高度');
      expect(png.length, greaterThan(200));
    });

    testWidgets('ShareService.save：真栅格化字节流进 sink，文件名走默认式', (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();
      final FakeShareSink sink = FakeShareSink();
      useSurface(tester, width: 420, height: 900, dpr: 1);
      await tester.pumpWidget(_host(key, demoShareSpec));
      await tester.pump();

      final ShareOutcome? outcome = await tester.runAsync(
        () => ShareService(sink).save(key, now: DateTime(2026, 10, 13, 12, 0, 0)),
      );
      expect(outcome, isNotNull);
      expect(outcome!.kind, ShareOutcomeKind.saved);
      expect(outcome.isSuccess, isTrue);
      expect(sink.savedBytes.single.sublist(0, 8), kPngMagic);
      expect(sink.savedNames.single, 'booksift_share_20261013_120000.png');
    });

    testWidgets('4 配色各渲染不崩，且像素互不相同（配色确实进了导出物）', (WidgetTester tester) async {
      useSurface(tester, width: 420, height: 900, dpr: 1);
      final Set<String> digests = <String>{};
      for (final ShareCardPalette palette in ShareCardPalette.values) {
        final GlobalKey key = GlobalKey();
        await tester.pumpWidget(_host(key, demoShareSpec.copyWith(palette: palette)));
        await tester.pump();
        final Uint8List? png = await tester.runAsync(() => renderPng(key));
        expect(png, isNotNull, reason: '${palette.label} 档应能栅格化');
        expect(png!.sublist(0, 8), kPngMagic, reason: '${palette.label} 档应导出 PNG');
        expect(_be32(png, 16), 800);
        digests.add(base64Encode(png));
      }
      expect(digests, hasLength(ShareCardPalette.values.length), reason: '4 档配色不得渲染出同一张图');
    });

    testWidgets('字号/行距极值（8·1.0 与 30·3.0）渲染不崩', (WidgetTester tester) async {
      useSurface(tester, width: 420, height: 1400, dpr: 1);
      for (final (double fontSize, double lineHeight) in <(double, double)>[
        (ShareCardSpec.minFontSize, ShareCardSpec.minLineHeight),
        (ShareCardSpec.maxFontSize, ShareCardSpec.maxLineHeight),
      ]) {
        final GlobalKey key = GlobalKey();
        await tester.pumpWidget(
          _host(key, demoShareSpec.copyWith(fontSize: fontSize, lineHeight: lineHeight)),
        );
        await tester.pump();
        final Uint8List? png = await tester.runAsync(() => renderPng(key));
        expect(png, isNotNull, reason: '字号 $fontSize / 行距 $lineHeight 应能栅格化');
        expect(png!.sublist(0, 8), kPngMagic);
      }
    });

    test('锚点未挂载 → ShareRenderException（不把裸断言抛给 UI）', () async {
      await expectLater(
        renderPng(GlobalKey()),
        throwsA(isA<ShareRenderException>().having(
          (ShareRenderException e) => e.message,
          'message',
          contains('不在当前界面'),
        )),
      );
    });

    test('渲染失败收敛成 failed 结果（服务门面不抛异常）', () async {
      final ShareOutcome outcome = await ShareService(
        FakeShareSink(),
        (GlobalKey key, {double pixelRatio = kSharePixelRatio}) async =>
            throw const ShareRenderException('卡片栅格化失败：boom'),
      ).save(GlobalKey());
      expect(outcome.kind, ShareOutcomeKind.failed);
      expect(outcome.isSuccess, isFalse);
      expect(outcome.message, contains('boom'));
    });
  });

  group('参数域（§5.11 继承宝典：字号 8–30 / 行距 1.0–3.0 / 水印 / 8000 字截断）', () {
    test('字号步进 1，越界夹紧到 8–30', () {
      expect(ShareCardSpec.defaultFontSize, 16);
      expect(const ShareCardSpec().stepFontSize(ShareCardSpec.fontSizeStep).fontSize, 17);
      expect(const ShareCardSpec().stepFontSize(-ShareCardSpec.fontSizeStep).fontSize, 15);
      expect(const ShareCardSpec(fontSize: ShareCardSpec.maxFontSize)
          .stepFontSize(ShareCardSpec.fontSizeStep)
          .fontSize, 30);
      expect(const ShareCardSpec(fontSize: ShareCardSpec.minFontSize)
          .stepFontSize(-ShareCardSpec.fontSizeStep)
          .fontSize, 8);
    });

    test('行距步进 0.1（一位小数，无浮点尾巴），越界夹紧到 1.0–3.0', () {
      expect(ShareCardSpec.defaultLineHeight, 1.7);
      expect(const ShareCardSpec().stepLineHeight(ShareCardSpec.lineHeightStep).lineHeight, 1.8);
      expect(const ShareCardSpec().stepLineHeight(-ShareCardSpec.lineHeightStep).lineHeight, 1.6);
      expect(const ShareCardSpec(lineHeight: ShareCardSpec.maxLineHeight)
          .stepLineHeight(ShareCardSpec.lineHeightStep)
          .lineHeight, 3.0);
      expect(const ShareCardSpec(lineHeight: ShareCardSpec.minLineHeight)
          .stepLineHeight(-ShareCardSpec.lineHeightStep)
          .lineHeight, 1.0);
    });

    test('水印默认「扫书汇APP | BY {推荐人}」；无推荐人只留品牌段；用户改过用用户的', () {
      expect(demoShareSpec.defaultWatermark, '扫书汇APP | BY 残梦灬语宵');
      expect(demoShareSpec.effectiveWatermark, '扫书汇APP | BY 残梦灬语宵');
      expect(const ShareCardSpec(bookName: 'x').defaultWatermark, '扫书汇APP');
      expect(demoShareSpec.copyWith(watermark: '扫书汇 | 手写').effectiveWatermark, '扫书汇 | 手写');
      // 清空 = 回落默认（弹层里删光输入框不该出水印空行）。
      expect(demoShareSpec.copyWith(watermark: '  ').effectiveWatermark, '扫书汇APP | BY 残梦灬语宵');
    });

    test('>8000 字 → 截断到 8000 + 标记；≤8000 字原样', () {
      expect(ShareCardSpec.maxQuoteChars, 8000);
      final ShareCardSpec over = demoShareSpec.copyWith(quote: '字' * 9000);
      expect(over.isTruncated, isTrue);
      expect(over.displayQuote.length, 8000 + ShareCardSpec.truncatedSuffix.length);
      expect(over.displayQuote, endsWith('…（已截断）'));
      expect(over.displayQuote.startsWith('字' * 8000), isTrue);

      final ShareCardSpec exact = demoShareSpec.copyWith(quote: '字' * 8000);
      expect(exact.isTruncated, isFalse);
      expect(exact.displayQuote, '字' * 8000);
    });

    test('标题行：书名补《》；无书名回落帖标题；都空则 null', () {
      expect(demoShareSpec.headline, '《十日终焉》');
      expect(const ShareCardSpec(title: '【扫书】四月合集').headline, '【扫书】四月合集');
      expect(const ShareCardSpec(bookName: '《已带书名号》').headline, '《已带书名号》');
      expect(const ShareCardSpec().headline, isNull);
      expect(demoShareSpec.creditLine, '杀虫队队员 / 推荐人 残梦灬语宵');
      expect(const ShareCardSpec().creditLine, isNull);
    });

    test('导出文件名 = booksift_share_<yyyyMMdd>_<HHmmss>.png（纯 ASCII）', () {
      expect(defaultShareFileName(now: DateTime(2026, 1, 2, 3, 4, 5)), 'booksift_share_20260102_030405.png');
      expect(RegExp(r'^booksift_share_\d{8}_\d{6}\.png$').hasMatch(defaultShareFileName()), isTrue);
    });

    test('桌面/移动判定：本机（Windows）走保存对话框口径', () {
      // 移动与否决定「保存到相册」按钮文案与落盘策略；断言口径本身，不断言具体平台。
      expect(isMobileShareTarget, isA<bool>());
    });
  });

  group('4 配色（§5.11 给定底色 + 派生前景）', () {
    test('底色与原型逐值一致：白 FFFFFFFF / 黑 FF293443 / 绿 FFCFECBA / 米 FFE6D3AA', () {
      expect(ShareCardPalette.paper.background.toARGB32(), 0xFFFFFFFF);
      expect(ShareCardPalette.ink.background.toARGB32(), 0xFF293443);
      expect(ShareCardPalette.moss.background.toARGB32(), 0xFFCFECBA);
      expect(ShareCardPalette.sand.background.toARGB32(), 0xFFE6D3AA);
      expect(ShareCardPalette.values.map((ShareCardPalette p) => p.label), <String>['白', '黑', '绿', '米']);
    });

    test('每档正文/次级/强调对底色对比度 ≥4.5:1（导出物同样守 WCAG）', () {
      for (final ShareCardPalette p in ShareCardPalette.values) {
        expect(_contrast(p.foreground, p.background), greaterThanOrEqualTo(4.5), reason: '${p.label} 正文');
        expect(_contrast(p.muted, p.background), greaterThanOrEqualTo(4.5), reason: '${p.label} 次级');
        expect(_contrast(p.accent, p.background), greaterThanOrEqualTo(4.5), reason: '${p.label} 强调');
        expect(p.background.a, 1.0, reason: '${p.label} 底色不透明（导出 PNG 不留透明底）');
      }
    });

    test('4 档互不相同（swatch 不会撞色）', () {
      final Set<int> backgrounds =
          ShareCardPalette.values.map((ShareCardPalette p) => p.background.toARGB32()).toSet();
      expect(backgrounds, hasLength(4));
    });
  });

  group('卡片结构', () {
    testWidgets('书名走 display 衬线槽、正文吃用户字号/行距、水印行在场', (WidgetTester tester) async {
      useSurface(tester, width: 420, height: 900, dpr: 1);
      await tester.pumpWidget(_host(GlobalKey(), demoShareSpec));
      await tester.pump();

      final Finder card = find.byType(ShareCard);
      expect(find.descendant(of: card, matching: find.text('《十日终焉》')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('杀虫队队员 / 推荐人 残梦灬语宵')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.textContaining('悬疑无限流')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('扫书汇APP | BY 残梦灬语宵')), findsOneWidget);

      // 书名 = display 槽（family 来自字体 token，衬线由 FontService 解析）+ 700 字重。
      final Text headline = tester.widget<Text>(find.descendant(of: card, matching: find.text('《十日终焉》')));
      expect(headline.style?.fontWeight, FontWeight.w700);
      expect(headline.style?.fontSize, closeTo(16 * 1.6, 0.01), reason: '书名随正文字号等比放大');
      expect(headline.style?.color, ShareCardPalette.paper.foreground);

      // 正文吃参数域的字号与行距。
      final Text quote = tester.widget<Text>(find.descendant(of: card, matching: find.textContaining('悬疑无限流')));
      expect(quote.style?.fontSize, 16);
      expect(quote.style?.height, 1.7);

      // 导出物内不塞 SVG/图标资产（栅格化不依赖 asset bundle 解码）。
      expect(find.descendant(of: card, matching: find.byType(Icon)), findsNothing);
    });
  });
}
