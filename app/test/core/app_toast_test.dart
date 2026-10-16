import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booksift/core/fonts/font_tokens.dart';
import 'package:booksift/theme/app_colors.dart';
import 'package:booksift/theme/app_radius.dart';
import 'package:booksift/core/widgets/app_toast.dart';
import 'package:booksift/theme/book_theme.dart';
import 'package:booksift/theme/app_typography.dart';

import '../support/harness.dart' show dismissSnackBars, useSurface;

// Toast 基建（需求 7）：宽屏取屏宽 1/3 居中、窄屏留 24 边距且不溢出、同一时刻仅一条、
// 淡入淡出走 AppMotionTheme token（减弱动效设置自动退化 ≤100ms）、停留结束自行淡出摘除
// （不留 pending timer / 残留 entry）。
//
// 全部 testWidgets 零真实 IO（只挂 MaterialApp + 一个空 Scaffold）。

/// 最小宿主：真主题 token（AppColors/AppMotion/AppSpacing 都是 ThemeExtension）+ Navigator Overlay。
Future<BuildContext> pumpToastHost(WidgetTester tester, {ThemeData? theme}) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? BookTheme.light,
      home: Builder(
        builder: (BuildContext context) {
          ctx = context;
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    ),
  );
  return ctx;
}

/// 当前 toast 的不透明度（appToastKey 挂在 FadeTransition 上）。
double toastOpacity(WidgetTester tester) =>
    tester.widget<FadeTransition>(find.byKey(appToastKey)).opacity.value;

/// 推进「首帧挂载 → 动效起算」两拍：动画从下一帧开始计时（Ticker 首个 tick 记 elapsed=0）。
Future<void> startMotion(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  group('showAppToast（需求 7：宽屏 1/3 居中）', () {
    testWidgets('宽屏 1440dp：宽度 = 屏宽/3、水平居中、贴底浮起', (WidgetTester tester) async {
      useSurface(tester, width: 1440, height: 900);
      final BuildContext ctx = await pumpToastHost(tester);

      showAppToast(ctx, '已复制');
      await startMotion(tester);
      await tester.pumpAndSettle();
      expect(find.text('已复制'), findsOneWidget);

      final Rect rect = tester.getRect(find.byKey(appToastKey));
      expect(rect.width, closeTo(1440 / 3, 0.01), reason: '宽屏 = 屏宽 1/3（绝不拉满整宽）');
      expect(rect.center.dx, closeTo(720, 0.01), reason: '水平居中');
      expect(rect.right, lessThan(1440), reason: '左右都留有空白');
      expect(rect.bottom, lessThan(900));

      // 风格与项目浮层族一致（需求 1 回归守卫）：raised 底 + 发丝描边 + pill 圆角 + 正文色，
      // 不再是 SnackBar 那套 ink 深底。
      final AppColors colors = BookTheme.light.extension<AppColors>()!;
      final Container box = tester.widget<Container>(
        find.descendant(of: find.byKey(appToastKey), matching: find.byType(Container)),
      );
      final BoxDecoration decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, colors.surfaceRaised, reason: '浮层底 = surfaceRaised（同弹窗/菜单）');
      expect(decoration.borderRadius, AppRadius.pillBorder, reason: '圆角走设计系统 Toast 档 pill');
      expect(decoration.border, isNotNull, reason: '1px 发丝描边');
      expect(decoration.boxShadow, isNotEmpty, reason: '--shadow-overlay 唯一阴影 token');
      // 文字样式必须落在 body 令牌上：toast 挂根 Overlay（没有 Material 祖先），
      // 只写 Text.style 会漏掉 MaterialApp 的兜底 DefaultTextStyle
      // （monospace / w900 / 黄色双下划线 → 用户反馈的「toast 底部黄线」）。
      final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(find.text('已复制'));
      final TextStyle textStyle = (paragraph.text as TextSpan).style!;
      expect(textStyle.color, colors.text, reason: '文字用正文色（不是 onInk）');
      expect(textStyle.fontSize, AppTypography.standard.body.fontSize, reason: '正文档字号');
      expect(textStyle.decoration, isNull, reason: '不得继承兜底样式的下划线');
      expect(textStyle.decorationStyle, isNull, reason: '不得继承兜底样式的双下划线');
      expect(textStyle.fontWeight, isNot(FontWeight.w900), reason: '不得继承兜底样式的 w900');
      expect(textStyle.fontFamily, isNot('monospace'), reason: '不得继承兜底样式的 monospace');

      await dismissSnackBars(tester);
      expect(find.byKey(appToastKey), findsNothing, reason: '停留结束自行淡出摘除（无残留）');
    });

    testWidgets('超宽 2560dp：1/3 命中钳制上限 520（仍远窄于屏幕）', (WidgetTester tester) async {
      useSurface(tester, width: 2560, height: 1440);
      final BuildContext ctx = await pumpToastHost(tester);

      showAppToast(ctx, '提示');
      await startMotion(tester);
      await tester.pumpAndSettle();

      final Rect rect = tester.getRect(find.byKey(appToastKey));
      expect(rect.width, closeTo(520, 0.01), reason: '上限钳制');
      expect(rect.center.dx, closeTo(1280, 0.01), reason: '仍居中');
      await dismissSnackBars(tester);
    });

    testWidgets('窄屏 390dp：宽度 = 屏宽 − 2×24（不溢出、不压底部导航）', (WidgetTester tester) async {
      useSurface(tester); // 390×844 compact
      final BuildContext ctx = await pumpToastHost(tester);

      showAppToast(ctx, '已加入书签（含楼层位置）');
      await startMotion(tester);
      await tester.pumpAndSettle();

      final Rect rect = tester.getRect(find.byKey(appToastKey));
      expect(rect.width, closeTo(390 - 48, 0.01), reason: '左右各留 24');
      expect(rect.left, greaterThanOrEqualTo(24 - 0.01), reason: '不贴边、不溢出左侧');
      expect(rect.right, lessThanOrEqualTo(390 - 24 + 0.01), reason: '不溢出右侧');
      expect(rect.bottom, closeTo(844 - 88 - 20, 0.01), reason: 'compact 抬升底栏高度 + 间距，不压 NavigationBar');
      await dismissSnackBars(tester);
    });

    testWidgets('同一时刻只保留一条：新 toast 顶掉旧的', (WidgetTester tester) async {
      useSurface(tester);
      final BuildContext ctx = await pumpToastHost(tester);

      showAppToast(ctx, '第一条');
      await tester.pump();
      showAppToast(ctx, '第二条');
      await startMotion(tester);
      await tester.pumpAndSettle();

      expect(find.text('第二条'), findsOneWidget);
      expect(find.text('第一条'), findsNothing, reason: '旧 toast 被顶掉（对应原 clearSnackBars 语义）');
      expect(find.byKey(appToastKey), findsOneWidget);

      await dismissSnackBars(tester);
      expect(find.byKey(appToastKey), findsNothing);
    });

    testWidgets('淡入时长走 AppMotionTheme 标准档（fast=200ms）：120ms 时仍在淡入', (WidgetTester tester) async {
      useSurface(tester);
      final BuildContext ctx = await pumpToastHost(tester); // BookTheme.light = standardTokens
      showAppToast(ctx, '标准档');
      await startMotion(tester);
      await tester.pump(const Duration(milliseconds: 120));
      expect(toastOpacity(tester), lessThan(1.0), reason: '标准档 200ms 淡入，120ms 未完成');
      await dismissSnackBars(tester);
      expect(find.byKey(appToastKey), findsNothing);
    });

    // 减弱动效档单独一条用例：同一棵树里换主题会走 MaterialApp 的 AnimatedTheme 插值，
    // 新 token 不会立刻生效（旧树残留）——换主题必须换用例（新树）。
    testWidgets('淡入时长走 AppMotionTheme 减弱动效档（reducedTokens）：120ms 已完全淡入', (WidgetTester tester) async {
      useSurface(tester);
      final BuildContext ctx = await pumpToastHost(
        tester,
        theme: BookTheme.of(Brightness.light, FontFamilySet.standard, null, true),
      );
      showAppToast(ctx, '减弱档');
      await startMotion(tester);
      await tester.pump(const Duration(milliseconds: 120));
      expect(toastOpacity(tester), 1.0, reason: '减弱动效 ≤100ms，120ms 已完全淡入');
      await dismissSnackBars(tester);
      expect(find.byKey(appToastKey), findsNothing);
    });
  });
}
