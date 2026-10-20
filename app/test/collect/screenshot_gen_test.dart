// 采集页视觉验收截图生成器（非断言测试；SHOTS=true 才跑，否则 skip）。
//
// 用途：把「采集中心」四态（compact running / medium running / expanded running /
// compact idle）用**真实编译像素**渲染成 PNG，落到 app/build/shots/，供与设计稿
// work/ui_design/claude/index.html（06 / W5t / W5d）逐屏人工/工具比对。
//
// 为什么不用默认字体：flutter_tester 无 CJK 字体 → 中文豆腐块，无法比对。这里经
// FontLoader 载入本机 Windows 字体（华文宋体=衬线槽、黑体=无衬线槽），映射进
// FontFamilySet → BookTheme.of，得到接近真机的可读渲染。
//
// 纪律：所有真实 IO（读字体文件 / 写 PNG / toImage 栅格化）都在 tester.runAsync
// 内完成（逃逸 testWidgets 的 FakeAsync 假时钟区，见 app/test/TESTING.md）。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/fonts/font_tokens.dart';
import 'package:booksift/features/collect/collect_page.dart';
import 'package:booksift/features/collect/collect_settings.dart';
import 'package:booksift/features/content/book_detail_page.dart';
import 'package:booksift/features/home/home_page.dart' show rankTodayProvider;
import 'package:booksift/features/rank/rank_page.dart';
import 'package:booksift/theme/book_theme.dart';

import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import '../support/fake_collect.dart';
import '../support/harness.dart' show useSurface, testOverrides;

bool get _wantShots => Platform.environment['SHOTS'] == 'true';

bool _fontsLoaded = false;
const String _serifFamily = 'AppSerif';
const String _sansFamily = 'AppSans';

/// 载入本机字体（衬线=华文宋体 STZHONGS.TTF；无衬线=黑体 simhei.ttf）。
/// 缺字体则退回不载（截图会豆腐，但不崩）。只在首次调用真正读盘。
Future<void> _loadFontsOnce() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  Future<void> load(String family, String path) async {
    final File f = File(path);
    if (!await f.exists()) return;
    final Uint8List bytes = await f.readAsBytes();
    final FontLoader loader = FontLoader(family)
      ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }

  await load(_serifFamily, r'C:\Windows\Fonts\STZHONGS.TTF');
  await load(_sansFamily, r'C:\Windows\Fonts\simhei.ttf');
}

FontFamilySet get _families => const FontFamilySet(
  display: _serifFamily,
  title: _serifFamily,
  headline: _serifFamily,
  cardTitle: _serifFamily,
  body: _sansFamily,
  bodyRich: _sansFamily,
  secondary: _sansFamily,
  caption: _sansFamily,
  label: _sansFamily,
  mono: _serifFamily,
);

Widget _app(GlobalKey shotKey, List<Override> overrides, [Widget child = const CollectPage()]) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: BookTheme.of(Brightness.light, _families),
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(key: shotKey, child: child),
    ),
  );
}

/// 渲染一帧并写出 PNG（pixelRatio=2 保清晰）。
/// [settle]：数据经 FutureProvider 异步到达的页面（rank/book）用 pumpAndSettle 等重建+入场动画收敛；
/// collect 运行态含无限 pulse 动画**不得** settle，用定步长 pump。
Future<void> _capture(WidgetTester tester, GlobalKey shotKey, String name, {bool settle = false}) async {
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 750)); // 让入场动画（环 500ms / 计数 300ms）收敛
  }
  final Directory outDir = Directory('build/shots');
  await tester.runAsync(() async {
    if (!outDir.existsSync()) outDir.createSync(recursive: true);
    final RenderRepaintBoundary boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(shotKey));
    final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
    final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) return;
    await File('${outDir.path}/$name.png').writeAsBytes(data.buffer.asUint8List());
    // ignore: avoid_print
    print('[shot] build/shots/$name.png  ${image.width}x${image.height}');
  });
}

void main() {
  testWidgets('截图：采集页 compact 运行态（设计稿 06 屏）', (WidgetTester tester) async {
    await tester.runAsync(_loadFontsOnce);
    useSurface(tester, width: 390, height: 844, dpr: 1);
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(_app(key, collectTestOverrides(
      notifier: FakeCollectRunNotifier(initial: demoRunState()),
      settings: const CollectSettings(wifiOnly: true, concurrentForums: 2),
    )));
    await _capture(tester, key, 'collect-06-compact-running');
  }, skip: !_wantShots);

  testWidgets('截图：采集页 medium 运行态（设计稿 W5t）', (WidgetTester tester) async {
    await tester.runAsync(_loadFontsOnce);
    useSurface(tester, width: 1024, height: 768, dpr: 1);
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(_app(key, collectTestOverrides(
      notifier: FakeCollectRunNotifier(initial: demoRunState()),
      settings: const CollectSettings(wifiOnly: true, concurrentForums: 2),
    )));
    await _capture(tester, key, 'collect-W5t-medium-running');
  }, skip: !_wantShots);

  testWidgets('截图：采集页 expanded 运行态（设计稿 W5d）', (WidgetTester tester) async {
    await tester.runAsync(_loadFontsOnce);
    useSurface(tester, width: 1440, height: 900, dpr: 1);
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(_app(key, collectTestOverrides(
      notifier: FakeCollectRunNotifier(initial: demoRunState()),
      settings: const CollectSettings(wifiOnly: true, concurrentForums: 2),
    )));
    await _capture(tester, key, 'collect-W5d-expanded-running');
  }, skip: !_wantShots);

  testWidgets('截图：采集页 compact 空闲态（原型 §5.9）', (WidgetTester tester) async {
    await tester.runAsync(_loadFontsOnce);
    useSurface(tester, width: 390, height: 844, dpr: 1);
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(_app(key, collectTestOverrides(
      notifier: FakeCollectRunNotifier(),
      forums: demoForums(),
      logs: demoLogs(),
    )));
    await _capture(tester, key, 'collect-idle-compact');
  }, skip: !_wantShots);

  testWidgets('截图：热门榜页 compact（设计稿 09 屏）', (WidgetTester tester) async {
    await tester.runAsync(_loadFontsOnce);
    useSurface(tester, width: 390, height: 844, dpr: 1);
    final GlobalKey key = GlobalKey();
    final FakeBookRepository repo = FakeBookRepository(library: demoLibrary());
    await tester.pumpWidget(_app(key, <Override>[
      ...testOverrides(repo),
      rankTodayProvider.overrideWithValue(DateTime(2025, 4, 30)),
    ], const RankPage()));
    await _capture(tester, key, 'rank-09-compact', settle: true);
  }, skip: !_wantShots);

  testWidgets('截图：书聚合页 compact（设计稿 04 屏）', (WidgetTester tester) async {
    await tester.runAsync(_loadFontsOnce);
    useSurface(tester, width: 390, height: 844, dpr: 1);
    final GlobalKey key = GlobalKey();
    final FakeBookRepository repo = FakeBookRepository(library: demoLibrary());
    await tester.pumpWidget(_app(key, testOverrides(repo), const BookDetailPage(bookGroupId: 904)));
    await _capture(tester, key, 'book-04-compact', settle: true);
  }, skip: !_wantShots);
}
