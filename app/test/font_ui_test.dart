import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/fonts/font_ports.dart' show PickedFontFile;
import 'package:booksift/core/fonts/font_registry.dart';
import 'package:booksift/core/fonts/font_service.dart';
import 'package:booksift/core/fonts/font_tokens.dart';
import 'package:booksift/core/fonts/system_font_catalog.dart';
import 'package:booksift/features/profile/font_manage_page.dart';
import 'package:booksift/features/profile/settings_page.dart';
import 'package:booksift/theme/app_typography.dart';
import 'package:booksift/theme/book_theme.dart';

import 'font_service_test.dart'
    show FakeFileStore, FakePicker, FakeRegistrar, FakeSettingsStore, FakeSystemCatalog, fakeBytes, sampleFont, systemEntry;

/// 与 app.dart 同构的最小测试壳：watch FontService → BookTheme.of 注入 families。
class TestApp extends ConsumerWidget {
  const TestApp({required this.home, super.key});

  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FontFamilySet families = ref.watch(fontServiceProvider).families;
    return MaterialApp(theme: BookTheme.of(Brightness.light, families), home: home);
  }
}

const String sample = 'Aa 扫书汇 ·《十日终焉》2026';

({
  FontService service,
  FakeSettingsStore store,
  FakeFileStore files,
  FakeRegistrar registrar,
  FakePicker picker,
  FakeSystemCatalog catalog,
})
uiService({bool withFont = false, String? rolesJson}) {
  final FakeSettingsStore store = FakeSettingsStore();
  final FakeFileStore files = FakeFileStore();
  final FakeRegistrar registrar = FakeRegistrar();
  final FakePicker picker = FakePicker();
  final FakeSystemCatalog catalog = FakeSystemCatalog();
  if (withFont) {
    store.data[FontSettingsKeys.registry] = FontRegistryCodec.encode(<ImportedFont>[sampleFont()]);
    files.files['f1.ttf'] = fakeBytes();
  }
  if (rolesJson != null) {
    store.data[FontSettingsKeys.roles] = rolesJson;
  }
  final FontService service = FontService(
    settings: store,
    picker: picker,
    registrar: registrar,
    files: files,
    systemFonts: catalog,
  );
  return (service: service, store: store, files: files, registrar: registrar, picker: picker, catalog: catalog);
}

Widget wrap(Widget home, FontService service) => ProviderScope(
  overrides: <Override>[fontServiceProvider.overrideWith((Ref ref) => service)],
  child: TestApp(home: home),
);

/// 样张文本中按字号定位（display=30 / title=22 / body=15…），取解析后的 family。
String? sampleFamily(WidgetTester tester, double fontSize) {
  final Iterable<Text> texts = tester
      .widgetList<Text>(find.text(sample))
      .where((Text t) => t.style?.fontSize == fontSize);
  expect(texts, isNotEmpty, reason: 'fontSize=$fontSize 的样张预览行应已渲染');
  return texts.first.style?.fontFamily;
}

void useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('设置页：字体管理入口 + 摘要；点击进入字体管理页', (WidgetTester tester) async {
    useTallViewport(tester);
    final b = uiService();
    await b.service.bootstrap();
    await tester.pumpWidget(wrap(const SettingsPage(), b.service));

    expect(find.text('字体管理'), findsOneWidget);
    expect(find.text('系统默认字体 · 可按角色换字体'), findsOneWidget);

    await tester.tap(find.text('字体管理'));
    await tester.pumpAndSettle();
    expect(find.text('导入字体'), findsOneWidget);
    expect(find.text('恢复默认'), findsOneWidget);
    expect(find.text('角色字体'), findsOneWidget);
    expect(find.text('我的字体'), findsOneWidget);
  });

  testWidgets('字体管理页：十角色行 + Aa 样张按角色排版（display 槽 → 样张换家族）', (WidgetTester tester) async {
    useTallViewport(tester);
    final b = uiService(withFont: true, rolesJson: '{"display":"imported:f1"}');
    await b.service.bootstrap();
    await tester.pumpWidget(wrap(const FontManagePage(), b.service));
    await tester.pumpAndSettle();

    // 十角色行全部渲染（高视口下 ListView 不裁剪）
    for (final String label in <String>[
      'Display · 大字', 'Title · 页面标题', 'Headline · 栏目标题', 'CardTitle · 卡片标题',
      'Body · 正文', 'BodyRich · 富文本', 'Secondary · 次级', 'Caption · 元信息',
      'Label · 徽标', 'Mono · 等宽',
    ]) {
      expect(find.text(label), findsOneWidget, reason: '$label 角色行缺失');
    }
    expect(find.byType(DropdownButton<FontSlot>), findsNWidgets(10));

    // Aa 样张按角色解析结果排版：display=导入家族，title/headline/label=system，mono=平台等宽
    expect(sampleFamily(tester, 30), 'MySerif');
    expect(sampleFamily(tester, 22), isNull);
    expect(sampleFamily(tester, 18), isNull);
    expect(sampleFamily(tester, 11), isNull);
    final Text monoPreview = tester.widget<Text>(find.textContaining('tid 11097754039'));
    expect(monoPreview.style?.fontFamily, FontFamily.monospace);
  });

  testWidgets('角色下拉：选导入字体 → 槽位持久化 + 样张/主题即时换家族', (WidgetTester tester) async {
    useTallViewport(tester);
    final b = uiService(withFont: true);
    await b.service.bootstrap();
    await tester.pumpWidget(wrap(const FontManagePage(), b.service));
    await tester.pumpAndSettle();
    expect(sampleFamily(tester, 22), isNull, reason: 'title 初始为 system');

    // 第二个下拉 = Title 角色（第一个是 Display）
    await tester.tap(find.byType(DropdownButton<FontSlot>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MySerif').last);
    await tester.pumpAndSettle();

    expect(b.service.families.title, 'MySerif');
    expect(sampleFamily(tester, 22), 'MySerif');
    final Map<String, dynamic> roles = jsonDecode(b.store.data[FontSettingsKeys.roles]!) as Map<String, dynamic>;
    expect(roles['title'], 'imported:f1');
  });

  testWidgets('恢复默认：全部角色回 system，样张家族清空', (WidgetTester tester) async {
    useTallViewport(tester);
    final b = uiService(withFont: true, rolesJson: '{"display":"imported:f1","title":"imported:f1"}');
    await b.service.bootstrap();
    await tester.pumpWidget(wrap(const FontManagePage(), b.service));
    await tester.pumpAndSettle();
    expect(sampleFamily(tester, 30), 'MySerif');

    await tester.tap(find.text('恢复默认'));
    await tester.pumpAndSettle();

    expect(b.service.families, FontFamilySet.standard);
    expect(sampleFamily(tester, 30), isNull);
    expect(sampleFamily(tester, 22), isNull);
    expect(find.text('已恢复系统默认字体'), findsOneWidget);
  });

  testWidgets('导入字体：按钮 → mock picker → 「我的字体」出现新条目', (WidgetTester tester) async {
    useTallViewport(tester);
    final b = uiService();
    await b.service.bootstrap();
    b.picker.next = PickedFontFile(fileName: 'Kaiti.ttf', bytes: fakeBytes());
    await tester.pumpWidget(wrap(const FontManagePage(), b.service));
    await tester.pumpAndSettle();
    expect(find.text('暂无导入字体（ttf / otf）'), findsOneWidget);

    await tester.tap(find.text('导入字体'));
    await tester.pumpAndSettle();

    expect(b.service.registry.length, 1);
    expect(find.text('Kaiti'), findsWidgets); // 我的字体行 + 各角色下拉候选
    expect(b.registrar.loaded, <String>['Kaiti']);
  });

  testWidgets('读取系统字体：弹选择界面 → 搜索过滤 → 加入我的字体', (WidgetTester tester) async {
    useTallViewport(tester);
    final b = uiService();
    final SystemFontEntry arial = systemEntry();
    final SystemFontEntry kaiti =
        systemEntry(familyName: 'Kaiti', fileName: 'Kaiti.otf', filePath: r'C:\Windows\Fonts\Kaiti.otf');
    b.catalog.fonts = <SystemFontEntry>[kaiti, arial];
    b.catalog.bytes[kaiti.filePath] = fakeBytes();
    await b.service.bootstrap();
    await tester.pumpWidget(wrap(const FontManagePage(), b.service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('读取系统字体'));
    await tester.pumpAndSettle();

    expect(find.text('Arial'), findsOneWidget);
    expect(find.text('Kaiti'), findsOneWidget);
    expect(find.text('仅列出可加载的 ttf / otf / ttc 字体'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, '加入我的字体')).onPressed,
      isNull,
      reason: '未选中字体时确认按钮禁用',
    );

    // 搜索过滤（大小写不敏感）
    await tester.enterText(find.byType(TextField), 'kaiti');
    await tester.pumpAndSettle();
    expect(find.text('Arial'), findsNothing);
    expect(find.text('Kaiti'), findsOneWidget);

    await tester.tap(find.text('Kaiti'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加入我的字体'));
    await tester.pumpAndSettle();

    expect(b.service.registry.length, 1);
    expect(b.service.registry.single.familyName, 'Kaiti');
    expect(b.registrar.loaded, <String>['Kaiti']);
    expect(find.text('加入我的字体'), findsNothing, reason: '选择弹层已关闭');
    expect(find.textContaining('已加入「Kaiti」'), findsOneWidget);
  });

  testWidgets('读取系统字体：枚举失败 → 明确提示且不打开选择界面', (WidgetTester tester) async {
    useTallViewport(tester);
    final b = uiService();
    b.catalog.listError = '当前系统不支持读取系统字体，请使用「导入字体」选择文件';
    await b.service.bootstrap();
    await tester.pumpWidget(wrap(const FontManagePage(), b.service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('读取系统字体'));
    await tester.pumpAndSettle();

    expect(find.text('当前系统不支持读取系统字体，请使用「导入字体」选择文件'), findsOneWidget);
    expect(find.text('加入我的字体'), findsNothing);
  });

  testWidgets('删除字体：确认弹层 → 引用角色回退 system', (WidgetTester tester) async {
    useTallViewport(tester);
    final b = uiService(withFont: true, rolesJson: '{"display":"imported:f1"}');
    await b.service.bootstrap();
    await tester.pumpWidget(wrap(const FontManagePage(), b.service));
    await tester.pumpAndSettle();
    expect(sampleFamily(tester, 30), 'MySerif');

    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    expect(find.text('删除字体'), findsOneWidget);
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();

    expect(b.service.registry, isEmpty);
    expect(b.service.families.display, isNull);
    expect(sampleFamily(tester, 30), isNull);
  });

  test('主题链路：AppTypography.of 走 BookTheme.of(families)，getter 全集不变', () {
    // 并行子代理兼容锚点：11 个 getter + tabular + of 签名保持不变（编译期即验证）。
    final AppTypography t = AppTypography.resolve(FontFamilySet.standard);
    final List<TextStyle> all = <TextStyle>[
      t.display, t.title, t.headline, t.cardTitle,
      t.body, t.bodyStrong, t.bodyRich, t.secondary, t.caption, t.label, t.mono,
    ];
    expect(all.length, 11);
    expect(AppTypography.tabular(t.mono).fontFeatures, isNotNull);
    expect(BookTheme.of(Brightness.dark, t.families).extension<AppTypography>()!.families, t.families);
  });
}
