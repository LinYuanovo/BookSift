import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/fonts/font_tokens.dart';
import 'package:booksift/theme/app_typography.dart';
import 'package:booksift/theme/book_theme.dart';

void main() {
  group('FontSlot 编解码', () {
    test('serialize：system / imported:<fontId>', () {
      expect(const FontSlot.system().serialize(), 'system');
      expect(const FontSlot.imported('abc123').serialize(), 'imported:abc123');
    });

    test('parse 容错：null / 垃圾串 / 空前缀一律回落 system', () {
      expect(FontSlot.parse(null), const FontSlot.system());
      expect(FontSlot.parse('system'), const FontSlot.system());
      expect(FontSlot.parse('imported:abc123'), const FontSlot.imported('abc123'));
      expect(FontSlot.parse('imported:'), const FontSlot.system());
      expect(FontSlot.parse('garbage'), const FontSlot.system());
      expect(FontSlot.parse('IMPORTED:abc'), const FontSlot.system());
    });

    test('serialize → parse 往返一致', () {
      for (final FontSlot slot in <FontSlot>[const FontSlot.system(), const FontSlot.imported('x1')]) {
        expect(FontSlot.parse(slot.serialize()), slot);
      }
    });
  });

  group('FontFamilySet', () {
    test('standard：除 mono 外全 null（system 槽），mono = 平台等宽族', () {
      const FontFamilySet s = FontFamilySet.standard;
      for (final FontRole role in FontRole.values) {
        if (role == FontRole.mono) {
          expect(s.familyOf(role), FontFamily.monospace);
        } else {
          expect(s.familyOf(role), isNull, reason: '${role.name} 默认应为 system（null）');
        }
      }
      expect(FontFamily.monospace, 'monospace');
    });

    test('角色覆盖：恰好十角色，familyOf/copyWithFamily 穷尽且互不串扰', () {
      expect(FontRole.values.length, 10);
      FontFamilySet set = FontFamilySet.standard;
      for (final FontRole role in FontRole.values) {
        set = set.copyWithFamily(role, 'F-${role.name}');
      }
      for (final FontRole role in FontRole.values) {
        expect(set.familyOf(role), 'F-${role.name}');
      }
      // 单角色回退 system 不影响其余角色
      final FontFamilySet back = set.copyWithFamily(FontRole.body, null);
      expect(back.familyOf(FontRole.body), isNull);
      expect(back.familyOf(FontRole.display), 'F-display');
      expect(back.familyOf(FontRole.mono), 'F-mono');
    });

    test('相等性 / hashCode', () {
      expect(const FontFamilySet(display: 'D'), const FontFamilySet(display: 'D'));
      expect(const FontFamilySet(display: 'D').hashCode, const FontFamilySet(display: 'D').hashCode);
      expect(const FontFamilySet(display: 'D'), isNot(const FontFamilySet(display: 'E')));
      expect(const FontFamilySet(), isNot(const FontFamilySet(mono: null)));
      expect(const FontFamilySet(), FontFamilySet.standard);
    });
  });

  group('AppTypography.resolve', () {
    test('默认解析：零自定义 family，字号/行高/字重/字距保持 §2.2 数值 token', () {
      final AppTypography t = AppTypography.resolve(FontFamilySet.standard);
      expect(t.families, FontFamilySet.standard);
      expect(t.display.fontFamily, isNull);
      expect(t.title.fontFamily, isNull);
      expect(t.headline.fontFamily, isNull);
      expect(t.cardTitle.fontFamily, isNull);
      expect(t.body.fontFamily, isNull);
      expect(t.bodyStrong.fontFamily, isNull);
      expect(t.bodyRich.fontFamily, isNull);
      expect(t.secondary.fontFamily, isNull);
      expect(t.caption.fontFamily, isNull);
      expect(t.label.fontFamily, isNull);
      expect(t.mono.fontFamily, FontFamily.monospace);
      for (final TextStyle s in <TextStyle>[
        t.display, t.title, t.headline, t.cardTitle,
        t.body, t.bodyStrong, t.bodyRich, t.secondary, t.caption, t.label, t.mono,
      ]) {
        expect(s.fontFamilyFallback, isNull, reason: 'v1.4 不再声明回退链');
      }
      expect(t.display.fontSize, 30);
      expect(t.display.height, 40 / 30);
      expect(t.display.fontWeight, FontWeight.w700);
      expect(t.title.fontSize, 22);
      expect(t.title.height, 32 / 22);
      expect(t.title.fontWeight, FontWeight.w600);
      expect(t.headline.fontSize, 18);
      expect(t.headline.fontWeight, FontWeight.w600);
      expect(t.cardTitle.fontSize, 16);
      expect(t.cardTitle.fontWeight, FontWeight.w600);
      expect(t.body.fontSize, 15);
      expect(t.body.height, 26 / 15);
      expect(t.body.fontWeight, isNull);
      expect(t.bodyStrong.fontSize, 15);
      expect(t.bodyStrong.fontWeight, FontWeight.w500);
      expect(t.bodyRich.height, 27 / 15);
      expect(t.secondary.fontSize, 13.5);
      expect(t.secondary.height, 21 / 13.5);
      expect(t.caption.fontSize, 12);
      expect(t.caption.height, 17 / 12);
      expect(t.label.fontSize, 11);
      expect(t.label.fontWeight, FontWeight.w500);
      expect(t.label.letterSpacing, 1.54);
      expect(t.mono.fontSize, 12);
      expect(t.mono.height, 17 / 12);
    });

    test('自定义 family 注入全部 11 style；bodyStrong 跟随 body 槽', () {
      const FontFamilySet set = FontFamilySet(
        display: 'D',
        title: 'T',
        headline: 'H',
        cardTitle: 'C',
        body: 'B',
        bodyRich: 'R',
        secondary: 'S',
        caption: 'P',
        label: 'L',
        mono: 'M',
      );
      final AppTypography t = AppTypography.resolve(set);
      expect(t.display.fontFamily, 'D');
      expect(t.title.fontFamily, 'T');
      expect(t.headline.fontFamily, 'H');
      expect(t.cardTitle.fontFamily, 'C');
      expect(t.body.fontFamily, 'B');
      expect(t.bodyStrong.fontFamily, 'B', reason: 'bodyStrong 非独立角色，复用 body 槽');
      expect(t.bodyRich.fontFamily, 'R');
      expect(t.secondary.fontFamily, 'S');
      expect(t.caption.fontFamily, 'P');
      expect(t.label.fontFamily, 'L');
      expect(t.mono.fontFamily, 'M');
      expect(t.families, set);
    });

    test('standard 由 standard 槽解析而来；copyWith/lerp 保留 families', () {
      expect(AppTypography.standard.families, FontFamilySet.standard);
      const FontFamilySet set = FontFamilySet(display: 'D');
      final AppTypography base = AppTypography.resolve(set);
      expect(base.copyWith().families, set);
      expect(base.copyWith(body: const TextStyle(fontSize: 99)).display.fontFamily, 'D');
      final AppTypography other = AppTypography.resolve(const FontFamilySet(display: 'E'));
      expect(base.lerp(other, 0.2).families, set);
      expect(base.lerp(other, 0.8).families, other.families);
      expect(base.lerp(null, 0.5).families, set);
    });

    test('tabular 只加 fontFeatures，不动 family', () {
      final AppTypography t = AppTypography.resolve(const FontFamilySet(mono: 'M'));
      final TextStyle tab = AppTypography.tabular(t.mono);
      expect(tab.fontFeatures, const <FontFeature>[FontFeature.tabularFigures()]);
      expect(tab.fontFamily, 'M');
    });
  });

  group('BookTheme 注入', () {
    test('of(brightness, families)：extension 与 textTheme 逐 style 携带 family', () {
      final ThemeData theme = BookTheme.of(Brightness.light, const FontFamilySet(display: 'Foo'));
      final AppTypography t = theme.extension<AppTypography>()!;
      expect(t.families.display, 'Foo');
      expect(t.display.fontFamily, 'Foo');
      expect(theme.textTheme.displaySmall!.fontFamily, 'Foo');
      // 未注入槽位：extension style family=null；textTheme 被 Material 默认排版 merge
      // 后为框架默认族（测试平台 = android → Roboto，即系统字体本尊），绝非自定义家族。
      expect(t.body.fontFamily, isNull);
      expect(theme.textTheme.bodyLarge!.fontFamily, anyOf(isNull, 'Roboto'));
    });

    test('light/dark 静态主题 = 全 system 默认', () {
      for (final ThemeData theme in <ThemeData>[BookTheme.light, BookTheme.dark]) {
        expect(theme.extension<AppTypography>()!.families, FontFamilySet.standard);
      }
    });
  });
}
