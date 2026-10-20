import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/fonts/font_tokens.dart';
import 'package:booksift/theme/app_colors.dart';
import 'package:booksift/theme/app_motion.dart';
import 'package:booksift/theme/app_radius.dart';
import 'package:booksift/theme/app_spacing.dart';
import 'package:booksift/theme/app_typography.dart';
import 'package:booksift/theme/book_theme.dart';

/// WCAG 2.1 相对亮度（sRGB 通道线性化）。
double relativeLuminance(Color color) {
  double channel(double s) => s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b);
}

/// WCAG 2.1 对比度 (L1+0.05)/(L2+0.05)。
double contrastRatio(Color a, Color b) {
  final double la = relativeLuminance(a);
  final double lb = relativeLuminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// 23 个语义色（shadowOverlay 为阴影色，不参与对比度断言）。
Map<String, Color> allSemanticColors(AppColors c) => <String, Color>{
  'canvas': c.canvas,
  'surface': c.surface,
  'surfaceRaised': c.surfaceRaised,
  'surfaceSunken': c.surfaceSunken,
  'border': c.border,
  'borderStrong': c.borderStrong,
  'text': c.text,
  'textSecondary': c.textSecondary,
  'textMuted': c.textMuted,
  'accent': c.accent,
  'accentStrong': c.accentStrong,
  'accentSoft': c.accentSoft,
  'onAccent': c.onAccent,
  'ink': c.ink,
  'onInk': c.onInk,
  'recommend': c.recommend,
  'recommendSoft': c.recommendSoft,
  'danger': c.danger,
  'dangerSoft': c.dangerSoft,
  'bookname': c.bookname,
  'info': c.info,
  'infoSoft': c.infoSoft,
  'highlight': c.highlight,
};

void expectContrastPairs(Map<String, (Color, Color)> pairs, double minRatio) {
  pairs.forEach((String name, (Color, Color) pair) {
    expect(contrastRatio(pair.$1, pair.$2), greaterThanOrEqualTo(minRatio), reason: '$name 对比度不足 $minRatio:1');
  });
}

void main() {
  const AppColors light = AppColors.light;
  const AppColors dark = AppColors.dark;
  const double aa = 4.5;

  group('token 非空', () {
    test('light/dark ThemeData 均携带全部四个 ThemeExtension', () {
      for (final ThemeData theme in <ThemeData>[BookTheme.light, BookTheme.dark]) {
        expect(theme.extension<AppColors>(), isNotNull);
        expect(theme.extension<AppTypography>(), isNotNull);
        expect(theme.extension<AppSpacing>(), isNotNull);
        expect(theme.extension<AppMotionTheme>(), isNotNull);
        expect(theme.useMaterial3, isTrue);
      }
    });

    test('语义色 23 值 light/dark 两套齐全且全部不透明', () {
      for (final AppColors c in <AppColors>[light, dark]) {
        final Map<String, Color> colors = allSemanticColors(c);
        expect(colors.length, 23);
        colors.forEach((String name, Color color) {
          expect(color.a, 1.0, reason: '$name 应为不透明色');
        });
      }
      expect(light.canvas, isNot(dark.canvas));
      expect(light.text, isNot(dark.text));
    });

    test('字阶非空：字号/行高为正，默认槽全 system（仅 mono = 平台等宽族）', () {
      final AppTypography t = AppTypography.standard;
      for (final TextStyle s in <TextStyle>[
        t.display, t.title, t.headline, t.cardTitle,
        t.body, t.bodyStrong, t.bodyRich, t.secondary, t.caption, t.label, t.mono,
      ]) {
        expect(s.fontSize! > 0, isTrue);
        expect(s.height! > 0, isTrue);
      }
      expect(t.display.fontFamily, isNull, reason: 'system 槽 = fontFamily null 走平台默认（v1.4 §2.2）');
      expect(t.title.fontFamily, isNull);
      expect(t.body.fontFamily, isNull);
      expect(t.mono.fontFamily, FontFamily.monospace);
      expect(t.families, FontFamilySet.standard);
      expect(t.display.fontWeight, FontWeight.w700);
      expect(t.display.fontSize, 30);
    });

    test('间距 4/8 体系与圆角档位精确值', () {
      const AppSpacing s = AppSpacing.standard;
      expect(
        <double>[s.space1, s.space2, s.space3, s.space4, s.space5, s.space6, s.space8, s.space10, s.space12],
        <double>[4, 8, 12, 16, 20, 24, 32, 40, 48],
      );
      expect(s.cardPadding, 20);
      expect(s.cardGap, 16);
      expect(s.sectionGap, 32);
      expect(AppMetrics.buttonHeight, 48);
      expect(AppMetrics.buttonHeightSmall, 40);
      expect(AppMetrics.buttonPaddingH, 24);
      expect(AppMetrics.buttonSmallPaddingH, 20);
      expect(AppMetrics.fontPickerDialogWidth, 420);
      expect(AppMetrics.fontPickerDialogHeight, 380);
      expect(AppMetrics.fontSlotDropdownMaxWidth, 150);
      expect(
        <double>[
          AppMetrics.iconXs,
          AppMetrics.iconSm,
          AppMetrics.iconBase,
          AppMetrics.iconLg,
        ],
        <double>[13, 16, 20, 24],
      );
      expect(AppRadius.sm, 10);
      expect(AppRadius.md, 14);
      expect(AppRadius.lg, 20);
      expect(AppRadius.xl, 24);
      expect(AppRadius.pill, 999);
    });

    test('按钮族主题：三套按钮共用 r14 / h48 / 水平 24', () {
      for (final ThemeData theme in <ThemeData>[BookTheme.light, BookTheme.dark]) {
        for (final ButtonStyle? style in <ButtonStyle?>[
          theme.textButtonTheme.style,
          theme.outlinedButtonTheme.style,
          theme.filledButtonTheme.style,
        ]) {
          expect(style, isNotNull);
          expect(
            style!.padding!.resolve(const <WidgetState>{}),
            const EdgeInsets.symmetric(horizontal: AppMetrics.buttonPaddingH),
          );
          expect(
            style.minimumSize!.resolve(const <WidgetState>{}),
            const Size(64, AppMetrics.buttonHeight),
          );
          expect(
            style.shape!.resolve(const <WidgetState>{}),
            const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
          );
          expect(
            style.textStyle!.resolve(const <WidgetState>{}),
            theme.extension<AppTypography>()!.bodyStrong,
          );
        }
      }
    });

    test('同心圆角 helper：inner = outer − padding，下限 0', () {
      expect(AppRadius.innerRadius(20, 16), 4);
      expect(AppRadius.innerRadius(20, 20), 0);
      expect(AppRadius.innerRadius(14, 20), 0);
      expect(AppRadius.innerBorderRadius(20, 6), const BorderRadius.all(Radius.circular(14)));
    });

    test('动效 token：时长四档 + stagger + spring 参数精确值', () {
      const AppMotionTheme m = AppMotionTheme.standardTokens;
      expect(m.instant, const Duration(milliseconds: 100));
      expect(m.fast, const Duration(milliseconds: 200));
      expect(m.normal, const Duration(milliseconds: 300));
      expect(m.slow, const Duration(milliseconds: 500));
      expect(m.staggerDelay, const Duration(milliseconds: 40));
      expect(m.spring.mass, 1.0);
      expect(m.spring.stiffness, 380.0);
      expect(m.spring.damping, 26.0);
      expect(m.enter, (duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic));
      expect(m.exit, (duration: const Duration(milliseconds: 200), curve: Curves.easeInCubic));
      expect(m.switch_, (duration: const Duration(milliseconds: 300), curve: Curves.easeInOutCubicEmphasized));
      expect(m.transition, m.switch_);
      expect(m.pop.duration, const Duration(milliseconds: 100));
      expect(m.staggerAt(3), const Duration(milliseconds: 120));
      expect(m.staggerAt(7), const Duration(milliseconds: 280));
      expect(m.staggerAt(99), const Duration(milliseconds: 280), reason: 'cascade 上限前 8 项');
    });
  });

  group('WCAG 对比度（设计系统 §7.1）', () {
    test('light：正文/交互文字全部 ≥4.5:1', () {
      expectContrastPairs(<String, (Color, Color)>{
        'text/surface': (light.text, light.surface),
        'text/canvas': (light.text, light.canvas),
        'textSecondary/surface': (light.textSecondary, light.surface),
        'textMuted/surface': (light.textMuted, light.surface),
        'textMuted/canvas': (light.textMuted, light.canvas),
        'recommend/recommendSoft': (light.recommend, light.recommendSoft),
        'danger/dangerSoft': (light.danger, light.dangerSoft),
        'bookname/surface': (light.bookname, light.surface),
        'accentStrong/surface': (light.accentStrong, light.surface),
        'accentStrong/canvas': (light.accentStrong, light.canvas),
        'onAccent/accent': (light.onAccent, light.accent),
        'onInk/ink': (light.onInk, light.ink),
        'info/surface': (light.info, light.surface),
        'text/highlight': (light.text, light.highlight),
      }, aa);
    });

    test('dark：正文/交互文字全部 ≥4.5:1', () {
      expectContrastPairs(<String, (Color, Color)>{
        'text/surface': (dark.text, dark.surface),
        'text/canvas': (dark.text, dark.canvas),
        'textSecondary/surface': (dark.textSecondary, dark.surface),
        'textMuted/surface': (dark.textMuted, dark.surface),
        'recommend/recommendSoft': (dark.recommend, dark.recommendSoft),
        'danger/dangerSoft': (dark.danger, dark.dangerSoft),
        'bookname/surface': (dark.bookname, dark.surface),
        'onAccent/accent': (dark.onAccent, dark.accent),
        'onInk/ink': (dark.onInk, dark.ink),
        'info/surface': (dark.info, dark.surface),
        'text/highlight': (dark.text, dark.highlight),
      }, aa);
    });

    test('与 §7.1 实测值一致（防色值搬运笔误）', () {
      expect(contrastRatio(light.text, light.surface), closeTo(15.82, 0.02));
      expect(contrastRatio(light.textMuted, light.surface), closeTo(5.00, 0.02));
      expect(contrastRatio(light.textMuted, light.canvas), closeTo(4.61, 0.02));
      expect(contrastRatio(light.onAccent, light.accent), closeTo(5.77, 0.02));
      expect(contrastRatio(light.bookname, light.surface), closeTo(4.80, 0.02));
      expect(contrastRatio(light.recommend, light.recommendSoft), closeTo(5.07, 0.02));
      expect(contrastRatio(dark.text, dark.surface), closeTo(14.17, 0.02));
      expect(contrastRatio(dark.onAccent, dark.accent), closeTo(7.23, 0.02));
      expect(contrastRatio(dark.danger, dark.dangerSoft), closeTo(4.92, 0.02));
      expect(contrastRatio(dark.bookname, dark.surface), closeTo(6.93, 0.02));
    });
  });

  group('reduceMotion', () {
    test('退化 token 集：全部时长 ≤100ms、stagger 归零、语义键同步退化', () {
      const AppMotionTheme m = AppMotionTheme.reducedTokens;
      expect(m.reduceMotion, isTrue);
      for (final Duration d in <Duration>[
        m.instant, m.fast, m.normal, m.slow, m.staggerDelay,
        m.enter.duration, m.exit.duration, m.pop.duration, m.switch_.duration, m.transition.duration,
        m.staggerAt(7),
      ]) {
        expect(d, lessThanOrEqualTo(const Duration(milliseconds: 100)));
      }
      expect(m.staggerAt(3), Duration.zero);
    });

    test('标准 token 集 reduceMotion 缺省关闭', () {
      expect(AppMotionTheme.standardTokens.reduceMotion, isFalse);
      expect(AppMotionTheme.standardTokens.normal, const Duration(milliseconds: 300));
    });
  });

  test('theme 目录之外无硬编码色值（路线图 M1-② lint 治理的测试化守卫）', () {
    final RegExp colorLiteral = RegExp(r'Color\(0[xX]|\bColors\.');
    final List<String> offenders = <String>[];
    for (final FileSystemEntity entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart') || entity.path.endsWith('.g.dart')) {
        continue;
      }
      final String normalized = entity.path.replaceAll(r'\', '/');
      if (normalized.startsWith('lib/theme/')) {
        continue;
      }
      final List<String> lines = File(normalized).readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        if (colorLiteral.hasMatch(lines[i])) {
          offenders.add('$normalized:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty, reason: '组件禁止硬编码色值，只能引用 AppColors（设计系统 §5.2）');
  });
}
