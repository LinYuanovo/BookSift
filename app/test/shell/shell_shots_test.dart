// 宽屏三栏视觉验收截图（非断言测试；SHOTS=true 才跑，否则 skip）。
//
// 与 test/collect/screenshot_gen_test.dart 同套路：RepaintBoundary.toImage 拿**真实编译像素**，
// 落 app/build/shots/，供人工比对「三栏功能区 / 中间功能区原位显示 / 搜索 chips 单行」。
// flutter_tester 无 CJK 字体 → 经 FontLoader 载入本机黑体（否则中文是豆腐块）。
// 真实 IO（读字体、写 PNG、栅格化）一律在 tester.runAsync 内完成（TESTING.md §1）。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/app_router.dart';
import 'package:booksift/core/fonts/font_tokens.dart';
import 'package:booksift/theme/book_theme.dart';

import '../support/fake_book_repository.dart';
import '../support/harness.dart' show testOverrides, useSurface;

bool get _wantShots => Platform.environment['SHOTS'] == 'true';

bool _fontsLoaded = false;
const String _sans = 'ShotSans';

Future<void> _loadFontsOnce() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  final File f = File(r'C:\Windows\Fonts\simhei.ttf');
  if (!await f.exists()) return;
  final Uint8List bytes = await f.readAsBytes();
  final FontLoader loader = FontLoader(_sans)
    ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

FontFamilySet get _families => const FontFamilySet(
  display: _sans,
  title: _sans,
  headline: _sans,
  cardTitle: _sans,
  body: _sans,
  bodyRich: _sans,
  secondary: _sans,
  caption: _sans,
  label: _sans,
  mono: _sans,
);

Widget _shellApp(FakeBookRepository repo, GlobalKey shotKey) => ProviderScope(
  overrides: testOverrides(repo),
  child: RepaintBoundary(
    key: shotKey,
    child: MaterialApp.router(
      theme: BookTheme.of(Brightness.light, _families),
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      routerConfig: createAppRouter(initialLocation: '/home'),
    ),
  ),
);

Future<void> _capture(WidgetTester tester, GlobalKey shotKey, String name) async {
  await tester.pumpAndSettle();
  final Directory outDir = Directory('build/shots');
  await tester.runAsync(() async {
    if (!outDir.existsSync()) outDir.createSync(recursive: true);
    final RenderRepaintBoundary boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(shotKey));
    final ui.Image image = await boundary.toImage(pixelRatio: 1.5);
    final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) return;
    await File('${outDir.path}/$name.png').writeAsBytes(data.buffer.asUint8List());
    // ignore: avoid_print
    print('[shot] build/shots/$name.png ${image.width}x${image.height}');
  });
}

void main() {
  testWidgets('截图：expanded 三栏（首页 + 详情槽空态）', (WidgetTester tester) async {
    await tester.runAsync(_loadFontsOnce);
    useSurface(tester, width: 1600, height: 1000, dpr: 1);
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(_shellApp(FakeBookRepository(), key));
    await _capture(tester, key, 'shell-wide-home');
  }, skip: !_wantShots);

  testWidgets('截图：expanded 导航栏收起态', (WidgetTester tester) async {
    await tester.runAsync(_loadFontsOnce);
    useSurface(tester, width: 1600, height: 1000, dpr: 1);
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(_shellApp(FakeBookRepository(), key));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('收起导航栏'));
    await _capture(tester, key, 'shell-wide-rail-collapsed');
  }, skip: !_wantShots);

  testWidgets('截图：expanded 设置页在中间功能区原位显示', (WidgetTester tester) async {
    await tester.runAsync(_loadFontsOnce);
    useSurface(tester, width: 1600, height: 1000, dpr: 1);
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(_shellApp(FakeBookRepository(), key));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await _capture(tester, key, 'shell-wide-settings-center');
  }, skip: !_wantShots);

  testWidgets('截图：expanded 搜索台（筛选 chips 按宽度排布）', (WidgetTester tester) async {
    await tester.runAsync(_loadFontsOnce);
    useSurface(tester, width: 1600, height: 1000, dpr: 1);
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(ProviderScope(
      overrides: testOverrides(FakeBookRepository()),
      child: RepaintBoundary(
        key: key,
        child: MaterialApp.router(
          theme: BookTheme.of(Brightness.light, _families),
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.light,
          routerConfig: createAppRouter(initialLocation: '/search'),
        ),
      ),
    ));
    await _capture(tester, key, 'shell-wide-search');
  }, skip: !_wantShots);
}
