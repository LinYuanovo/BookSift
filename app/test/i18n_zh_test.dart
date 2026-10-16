import 'dart:io';

import 'package:booksift/core/fonts/font_tokens.dart';
import 'package:booksift/core/fonts/system_font.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// 需求 6：应用为纯中文 UI——长按选词的系统菜单（剪切/复制/粘贴/全选）必须走
/// zh-CN（GlobalMaterialLocalizations），不得回落英文 DefaultMaterialLocalizations。
void main() {
  testWidgets('zh-CN 下 MaterialLocalizations 为中文（选词菜单文案）', (WidgetTester tester) async {
    late MaterialLocalizations localizations;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: const <Locale>[Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (BuildContext context) {
            localizations = MaterialLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(localizations.cutButtonLabel, '剪切');
    expect(localizations.copyButtonLabel, '复制');
    expect(localizations.pasteButtonLabel, '粘贴');
    expect(localizations.selectAllButtonLabel, '全选');
  });

  test('app.dart 已挂载 zh-CN 本地化与桌面滚动行为（防回退英文/双滚动条）', () {
    final String src = File('lib/app.dart').readAsStringSync();
    expect(src, contains('GlobalMaterialLocalizations.delegates'));
    expect(src, contains("Locale('zh', 'CN')"));
    expect(src, contains('AppScrollBehavior'));
    expect(src, contains('applySystemDefaultFont'));
  });

  group('系统默认字体注入（4b）', () {
    setUp(() => WindowsSystemUiFont.debugOverrideFamily = 'Fake UI Font');
    tearDown(() => WindowsSystemUiFont.debugOverrideFamily = null);

    test('flutter test 进程带 FLUTTER_TEST 标记（旁路分支生效的前提）', () {
      expect(Platform.environment['FLUTTER_TEST'], isNotEmpty,
          reason: 'flutter test/无标记时 WindowsSystemUiFont 会真调 user32 —— 标记即旁路开关');
    });

    test('设置 override 后不触发真实平台调用', () {
      expect(WindowsSystemUiFont.defaultFamily(), 'Fake UI Font');
    });

    test('system 槽角色注入系统字体；用户指定角色与 mono 保持原值', () {
      final FontFamilySet injected = applySystemDefaultFont(FontFamilySet.standard);
      for (final FontRole role in FontRole.values) {
        if (role == FontRole.mono) {
          expect(injected.familyOf(role), FontFamily.monospace, reason: 'mono 保持等宽族');
        } else {
          expect(injected.familyOf(role), 'Fake UI Font');
        }
      }
      final FontFamilySet mixed = FontFamilySet.standard.copyWithFamily(FontRole.title, 'MySerif');
      final FontFamilySet result = applySystemDefaultFont(mixed);
      expect(result.title, 'MySerif', reason: '用户显式指定字体的角色不受影响');
      expect(result.body, 'Fake UI Font');
    });

    test('探测不可用时原样返回（零行为变化）', () {
      WindowsSystemUiFont.debugOverrideFamily = null;
      final FontFamilySet families = FontFamilySet.standard;
      expect(applySystemDefaultFont(families), families);
    });
  });
}
