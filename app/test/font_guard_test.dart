import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/fonts/font_tokens.dart';
import 'package:booksift/theme/app_typography.dart';
import 'package:booksift/theme/book_theme.dart';

/// 守卫测试（设计系统 v1.4 §2.2 治理）：字体家族不得硬编码在主题/设置层，
/// 只能来自 FontFamilySet（FontSlot 解析结果）与 FontFamily 常量唯一定义处。
Iterable<File> dartFiles(String dir) sync* {
  for (final FileSystemEntity entity in Directory(dir).listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart') && !entity.path.endsWith('.g.dart')) {
      yield entity;
    }
  }
}

String normalized(File file) => file.path.replaceAll(r'\', '/');

List<String> offenders(Iterable<String> dirs, RegExp pattern) {
  final List<String> result = <String>[];
  for (final String dir in dirs) {
    for (final File file in dartFiles(dir)) {
      final List<String> lines = file.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) {
          result.add('${normalized(file)}:${i + 1}');
        }
      }
    }
  }
  return result;
}

void main() {
  test('lib/theme 与 lib/features/profile 无 fontFamily/fontFamilyFallback 字面量', () {
    // 允许 `fontFamily: families.display` / `fontFamily: null` 等符号引用，禁止字符串字面量。
    final RegExp literal = RegExp(r'''fontFamily(?:Fallback)?\s*:\s*(?:r?['"]|<String>\[\s*r?['"]|\[\s*r?['"])''');
    expect(offenders(<String>['lib/theme', 'lib/features/profile'], literal), isEmpty,
        reason: '字体家族必须由 FontFamilySet 注入（v1.4 §2.2），槽/常量定义只在 lib/core/fonts/font_tokens.dart');
  });

  test("'monospace' 字面量唯一定义处 = font_tokens.dart 的 FontFamily 常量", () {
    final List<String> result = <String>[];
    for (final File file in dartFiles('lib')) {
      final String path = normalized(file);
      if (path.endsWith('lib/core/fonts/font_tokens.dart')) continue;
      final List<String> lines = file.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains("'${FontFamily.monospace}'") || lines[i].contains('"${FontFamily.monospace}"')) {
          result.add('$path:${i + 1}');
        }
      }
    }
    expect(result, isEmpty, reason: '其余代码只准引用 FontFamily.monospace 符号');
  });

  test('旧硬编码家族名（SourceSerif4/Inter/RobotoMono 及回退链）已从 lib/ 全部移除', () {
    final RegExp legacy = RegExp(
      r"'(SourceSerif4|Inter|NotoSerifSC|NotoSansSC|RobotoMono|PingFang SC|Microsoft YaHei|Cascadia Mono|Consolas|Menlo|Georgia|SimSun|serif|sans-serif)'",
    );
    expect(offenders(<String>['lib'], legacy), isEmpty, reason: '未渲染的打包家族名不得残留（回退混乱根因）');
  });

  test('默认启动零自定义字体：light/dark 主题全部 style family ∈ {null, monospace, Material 默认}', () {
    for (final ThemeData theme in <ThemeData>[BookTheme.light, BookTheme.dark]) {
      final AppTypography t = theme.extension<AppTypography>()!;
      expect(t.families, FontFamilySet.standard);
      // 扩展字阶（组件唯一引用层）：只准 null（系统默认）或平台等宽族。
      final List<TextStyle> tokenStyles = <TextStyle>[
        t.display, t.title, t.headline, t.cardTitle, t.body, t.bodyStrong,
        t.bodyRich, t.secondary, t.caption, t.label, t.mono,
      ];
      for (final TextStyle s in tokenStyles) {
        expect(s.fontFamily, anyOf(isNull, FontFamily.monospace));
        expect(s.fontFamilyFallback, isNull);
      }
      // Material textTheme 会被框架默认排版 merge：null 槽位落到框架默认族
      // （Roboto = Android 系统字体 / 引擎内置），同样不得出现自定义家族。
      final List<TextStyle?> themeStyles = <TextStyle?>[
        theme.textTheme.displaySmall, theme.textTheme.headlineSmall, theme.textTheme.titleLarge,
        theme.textTheme.titleMedium, theme.textTheme.bodyLarge, theme.textTheme.bodyMedium,
        theme.textTheme.bodySmall, theme.textTheme.labelLarge, theme.textTheme.labelMedium,
        theme.textTheme.labelSmall,
      ];
      for (final TextStyle? s in themeStyles) {
        if (s == null) continue;
        expect(s.fontFamily, anyOf(isNull, FontFamily.monospace, 'Roboto'));
        expect(s.fontFamilyFallback, isNull);
      }
    }
  });
}
