/// Windows 桌面滚动条去重（需求 4a）回归守卫。
///
/// 根因：`Scrollable` 在桌面平台（windows/linux/macos）会自动给竖直滚动视图套一层
/// `Scrollbar`（widgets/scrollable.dart:1004 → MaterialScrollBehavior.buildScrollbar），
/// 而本项目 `ScrollChrome` 自己已画了一条 4px 细滚动条 → Windows 上出现**两条**。
/// 修法：MaterialApp 挂 [AppScrollBehavior]（buildScrollbar 直通 child）。
///
/// 用例结构：先跑「未挂」的对照（断言 2 条 = 复现 bug），再跑「已挂」（断言 1 条）。
library;

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/app_scroll_behavior.dart';
import 'package:booksift/core/widgets/scroll_chrome.dart';
import 'package:booksift/theme/book_theme.dart';

/// 在指定平台下执行：`debugDefaultTargetPlatformOverride` 必须在**测试体结束前**复位
/// （binding 的 invariant 校验早于 tearDown，用 addTearDown 会被判失败）。
Future<void> _onPlatform(TargetPlatform platform, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _pumpDeskList(WidgetTester tester, {ScrollBehavior? behavior}) async {
  final ScrollController controller = ScrollController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: BookTheme.light,
      scrollBehavior: behavior,
      home: Scaffold(
        body: ScrollChrome(
          controller: controller,
          child: ListView.builder(
            controller: controller,
            itemCount: 50,
            itemBuilder: (BuildContext context, int i) => SizedBox(height: 40, child: Text('行 $i')),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('未挂 AppScrollBehavior：Windows 下复现「两条滚动条」', (WidgetTester tester) async {
    await _onPlatform(TargetPlatform.windows, () async {
      await _pumpDeskList(tester);
      expect(find.byType(Scrollbar), findsNWidgets(2), reason: '框架自动一条 + ScrollChrome 一条');
    });
  });

  testWidgets('挂 AppScrollBehavior：只留 ScrollChrome 自绘那条', (WidgetTester tester) async {
    await _onPlatform(TargetPlatform.windows, () async {
      await _pumpDeskList(tester, behavior: const AppScrollBehavior());
      expect(find.byType(Scrollbar), findsNWidgets(1));
      expect(
        find.descendant(of: find.byType(ScrollChrome), matching: find.byType(Scrollbar)),
        findsOneWidget,
        reason: '保留的那条必须是 ScrollChrome 自己的',
      );
    });
  });

  testWidgets('Android（非桌面）本就只有一条，改动不引入回归', (WidgetTester tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      await _pumpDeskList(tester, behavior: const AppScrollBehavior());
      expect(find.byType(Scrollbar), findsNWidgets(1));
    });
  });
}
