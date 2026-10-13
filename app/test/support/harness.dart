import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saoshuhui/app_router.dart';
import 'package:saoshuhui/core/fonts/font_service.dart';
import 'package:saoshuhui/data/repo/database_provider.dart';
import 'package:saoshuhui/data/repo/queries.dart';
import 'package:saoshuhui/features/home/home_page.dart';
import 'package:saoshuhui/theme/book_theme.dart';

import '../font_service_test.dart' as fontfakes;
import 'fake_book_repository.dart';

// widget 测试统一挂具（app/test/TESTING.md §3）。
//
// 三条硬约束：
//  1. queriesProvider 一律注入 FakeBookRepository（纯内存，只有微任务）；
//  2. appDatabaseProvider 被替换成「一读就抛」的哨兵 —— 任何组件路径漏走真库都会
//     立刻炸成显式错误，而不是在 FakeAsync 假时钟区里静默挂死；
//  3. fontServiceProvider 注入四端口全 fake 的 FontService（不触 drift / file_picker /
//     dart:ui FontLoader / 文件系统）。

/// 造一个零 IO 的 FontService（端口 fake 复用 font_service_test.dart 的定义，单一出处）。
FontService fakeFontService() {
  return FontService(
    settings: fontfakes.FakeSettingsStore(),
    picker: fontfakes.FakePicker(),
    registrar: fontfakes.FakeRegistrar(),
    files: fontfakes.FakeFileStore(),
  );
}

/// widget 测试的 Provider 覆盖集。
List<Override> testOverrides(FakeBookRepository repo) {
  return <Override>[
    queriesProvider.overrideWithValue(repo),
    fontServiceProvider.overrideWith((Ref ref) => fakeFontService()),
    appDatabaseProvider.overrideWith(
      (Ref ref) => throw StateError(
        'widget 测试禁止触碰真实数据库（drift / path_provider / isolate 都是真实异步，'
        '在 testWidgets 假时钟区内会无限挂死）。请改用 queriesProvider.overrideWithValue(FakeBookRepository())。'
        '见 app/test/TESTING.md。',
      ),
    ),
  ];
}

/// 设定视口（dp）；默认 390×844@3x = compact 手机。
void useSurface(WidgetTester tester, {double width = 390, double height = 844, double dpr = 3}) {
  tester.view.physicalSize = Size(width * dpr, height * dpr);
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
}

/// 全 App 挂具：真实 go_router（复用 createAppRouter）+ 内存 fake 仓 + 明暗主题 token。
Widget testApp(
  FakeBookRepository repo, {
  String initial = '/home',
  Widget? home,
  DateTime? rankToday,
  List<Override> extraOverrides = const <Override>[],
}) {
  return ProviderScope(
    overrides: <Override>[
      ...testOverrides(repo),
      if (rankToday != null) rankTodayProvider.overrideWithValue(rankToday),
      ...extraOverrides,
    ],
    child: home != null
        ? MaterialApp(theme: BookTheme.light, darkTheme: BookTheme.dark, themeMode: ThemeMode.light, home: home)
        : MaterialApp.router(
            theme: BookTheme.light,
            darkTheme: BookTheme.dark,
            themeMode: ThemeMode.light,
            routerConfig: createAppRouter(initialLocation: initial),
          ),
  );
}

ProviderContainer containerOf(WidgetTester tester, Finder of) =>
    ProviderScope.containerOf(tester.element(of));

/// 推进 SnackBar 的 4s 自动消失 timer（否则用例结束时残留 pending timer 会判失败）。
Future<void> dismissSnackBars(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}
