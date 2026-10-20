import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/fonts/font_service.dart';
import 'package:booksift/core/fonts/font_tokens.dart';
import 'package:booksift/features/profile/settings_page.dart';
import 'package:booksift/theme/app_accent.dart';
import 'package:booksift/theme/app_colors.dart';
import 'package:booksift/theme/book_theme.dart';

import 'support/fake_book_repository.dart';
import 'support/harness.dart';

// M3 P2-3 · 12 主题色（对标宝典）守卫与行为测试。
// 对比度红线：设计系统 §7.1（正文/交互文字 ≥4.5:1；深色 accent 填充对深底 ≥3.0 = UI 图形档）。
// widget 测试零真实 IO：AccentStore 用内存 fake（TESTING.md §3.1），db 走 harness 哨兵。

final class FakeAccentStore implements AccentStore {
  final Map<String, String> data = <String, String>{};
  int writes = 0;

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async {
    writes++;
    data[key] = value;
  }
}

/// 与 app.dart 同构的最小测试壳：watch 字体槽 + 主题色 → BookTheme.of 注入。
class _Shell extends ConsumerWidget {
  const _Shell({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FontFamilySet families = ref.watch(fontServiceProvider).families;
    final AppAccentTheme accent = ref.watch(accentThemeProvider).value ?? AppAccentTheme.defaults;
    return MaterialApp(
      theme: BookTheme.of(Brightness.light, families, accent),
      darkTheme: BookTheme.of(Brightness.dark, families, accent),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: const SettingsPage(),
    );
  }
}

Future<FakeAccentStore> pumpSettings(WidgetTester tester, {bool dark = false, String? initialId}) async {
  tester.view.physicalSize = const Size(1080, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final FakeAccentStore store = FakeAccentStore();
  if (initialId != null) {
    store.data[AccentSettingsKeys.themeAccent] = initialId;
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        ...testOverrides(FakeBookRepository()),
        accentStoreProvider.overrideWith((Ref ref) => store),
      ],
      child: _Shell(dark: dark),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

Finder swatchOf(String id) => find.byKey(ValueKey<String>('swatch-$id'));

Finder accentTitleRow() => find.widgetWithText(ListTile, '主题色');

Finder accentCrossFade() => find.byType(AnimatedCrossFade);

CrossFadeState accentFadeState(WidgetTester tester) =>
    tester.widget<AnimatedCrossFade>(accentCrossFade()).crossFadeState;

double accentChevTurns(WidgetTester tester) => tester
    .widget<AnimatedRotation>(
      find.descendant(of: accentTitleRow(), matching: find.byType(AnimatedRotation)),
    )
    .turns;

/// 主题色区默认折叠：swatch 断言前先点标题行展开（折叠态隐藏子树不可点）。
Future<void> expandAccent(WidgetTester tester) async {
  await tester.tap(accentTitleRow());
  await tester.pumpAndSettle();
}

void main() {
  const double aa = 4.5;

  group('色表与查表', () {
    test('13 档 = default + 宝典 12 色（seed hex 逐值对照 index.iyu:1990-2001，防搬运笔误）', () {
      final List<(String, String, Color)> expected = <(String, String, Color)>[
        ('default', '陶土珊瑚', const Color(0xFFD97757)),
        ('wai_ba_huang', '歪吧黄', const Color(0xFFF4C300)),
        ('mao_zi_lv', '帽子绿', const Color(0xFF00EB10)),
        ('shao_nv_fen', '少女粉', const Color(0xFFFB7299)),
        ('ji_lao_zi', '基佬紫', const Color(0xFF9C27B0)),
        ('pang_ci_lan', '胖次蓝', const Color(0xFF2196F3)),
        ('yi_ma_hong', '姨妈红', const Color(0xFFE5353E)),
        ('fei_lu_lv', '飞卢绿', const Color(0xFF11850A)),
        ('xi_rang_lan', '息壤蓝', const Color(0xFF2964AF)),
        ('duo_kan_cheng', '多看橙', const Color(0xFFED902F)),
        ('chen_sha_se', '辰沙色', const Color(0xFFAE5E53)),
        ('cheng_de_hui', '承德灰', const Color(0xFF747570)),
        ('bai_cao_shuang', '百草霜', const Color(0xFF505050)),
      ];
      expect(AppAccentTheme.all, hasLength(13));
      for (int i = 0; i < expected.length; i++) {
        expect(AppAccentTheme.all[i].id, expected[i].$1);
        expect(AppAccentTheme.all[i].label, expected[i].$2);
        expect(AppAccentTheme.all[i].seed, expected[i].$3);
      }
      expect(AppAccentTheme.all.map((AppAccentTheme a) => a.id).toSet(), hasLength(13));
    });

    test('of()：id 命中 / null / 未知一律回落 default 档', () {
      expect(AppAccentTheme.of('yi_ma_hong'), same(AppAccentTheme.all[6]));
      expect(AppAccentTheme.of(null), same(AppAccentTheme.defaults));
      expect(AppAccentTheme.of('bogus_id'), same(AppAccentTheme.defaults));
      expect(AppAccentTheme.of('default'), same(AppAccentTheme.defaults));
    });

    test('默认档四槽 == 既有 AppColors.light/dark 常量（兼容性不变式）', () {
      expect(AppAccentTheme.defaults.light.accent, AppColors.light.accent);
      expect(AppAccentTheme.defaults.light.accentStrong, AppColors.light.accentStrong);
      expect(AppAccentTheme.defaults.light.accentSoft, AppColors.light.accentSoft);
      expect(AppAccentTheme.defaults.light.onAccent, AppColors.light.onAccent);
      expect(AppAccentTheme.defaults.dark.accent, AppColors.dark.accent);
      expect(AppAccentTheme.defaults.dark.accentStrong, AppColors.dark.accentStrong);
      expect(AppAccentTheme.defaults.dark.accentSoft, AppColors.dark.accentSoft);
      expect(AppAccentTheme.defaults.dark.onAccent, AppColors.dark.onAccent);
    });
  });

  group('对比度自检（13 档 × 深浅双模式）', () {
    test('onAccent ≥4.5 · accentStrong 对 surface/accentSoft 双底 ≥4.5 · 深色填充对深底 ≥3.0', () {
      double minOnLight = double.infinity;
      double minOnDark = double.infinity;
      double minStrongLightSurface = double.infinity;
      double minStrongLightSoft = double.infinity;
      double minStrongDarkSurface = double.infinity;
      double minStrongDarkSoft = double.infinity;
      double minDarkFill = double.infinity;
      for (final AppAccentTheme a in AppAccentTheme.all) {
        final AccentPalette l = a.light;
        final AccentPalette d = a.dark;
        for (final Color c in <Color>[
          l.accent, l.accentStrong, l.accentSoft, l.onAccent,
          d.accent, d.accentStrong, d.accentSoft, d.onAccent,
        ]) {
          expect(c.a, 1.0, reason: '${a.id} 槽位应不透明');
        }
        minOnLight = math.min(minOnLight, contrastRatio(l.onAccent, l.accent));
        minOnDark = math.min(minOnDark, contrastRatio(d.onAccent, d.accent));
        minStrongLightSurface = math.min(minStrongLightSurface, contrastRatio(l.accentStrong, AppColors.light.surface));
        minStrongLightSoft = math.min(minStrongLightSoft, contrastRatio(l.accentStrong, l.accentSoft));
        minStrongDarkSurface = math.min(minStrongDarkSurface, contrastRatio(d.accentStrong, AppColors.dark.surface));
        minStrongDarkSoft = math.min(minStrongDarkSoft, contrastRatio(d.accentStrong, d.accentSoft));
        minDarkFill = math.min(minDarkFill, contrastRatio(d.accent, AppColors.dark.surface));
      }
      // 实测最小值（完成报告用；断言仍是下面的红线）。
      debugPrint('[accent-contrast] onAccent/accent light=${minOnLight.toStringAsFixed(2)} '
          'dark=${minOnDark.toStringAsFixed(2)} | strong/surface light=${minStrongLightSurface.toStringAsFixed(2)} '
          'dark=${minStrongDarkSurface.toStringAsFixed(2)} | strong/soft light=${minStrongLightSoft.toStringAsFixed(2)} '
          'dark=${minStrongDarkSoft.toStringAsFixed(2)} | darkFill/surface=${minDarkFill.toStringAsFixed(2)}');
      expect(minOnLight, greaterThanOrEqualTo(aa), reason: 'light onAccent/accent 全档 ≥4.5');
      expect(minOnDark, greaterThanOrEqualTo(aa), reason: 'dark onAccent/accent 全档 ≥4.5');
      expect(minStrongLightSurface, greaterThanOrEqualTo(aa), reason: 'light accentStrong/surface 全档 ≥4.5');
      expect(minStrongLightSoft, greaterThanOrEqualTo(aa), reason: 'light accentStrong/accentSoft 全档 ≥4.5');
      expect(minStrongDarkSurface, greaterThanOrEqualTo(aa), reason: 'dark accentStrong/surface 全档 ≥4.5');
      expect(minStrongDarkSoft, greaterThanOrEqualTo(aa), reason: 'dark accentStrong/accentSoft 全档 ≥4.5');
      expect(minDarkFill, greaterThanOrEqualTo(3.0), reason: 'dark accent 填充对深底 ≥3.0（UI 图形档）');
    });

    test('亮度适配：中间调 seed（姨妈红）浅色 accent 压暗到白字可读；neon seed 保持原色', () {
      final AccentPalette red = deriveLightPalette(const Color(0xFFE5353E));
      expect(red.accent, isNot(const Color(0xFFE5353E)), reason: '姨妈红落在黑白双候选死区，应压暗');
      expect(contrastRatio(red.onAccent, red.accent), greaterThanOrEqualTo(aa));
      expect(deriveLightPalette(const Color(0xFFF4C300)).accent, const Color(0xFFF4C300),
          reason: '歪吧黄黑字已达 4.6+，accent 保持 seed');
      expect(deriveLightPalette(const Color(0xFF2964AF)).onAccent, const Color(0xFFFFFDF8));
      expect(deriveLightPalette(const Color(0xFFF4C300)).onAccent, const Color(0xFF1F1E1B));
    });
  });

  group('BookTheme 注入', () {
    test('13 档 × 深浅：AppColors accent 四槽与 ColorScheme primary/secondary = 所选档；其余槽不变', () {
      for (final AppAccentTheme a in AppAccentTheme.all) {
        final ThemeData lt = BookTheme.of(Brightness.light, FontFamilySet.standard, a);
        final AppColors lc = lt.extension<AppColors>()!;
        expect(lc.accent, a.light.accent, reason: '${a.id} light.accent');
        expect(lc.accentStrong, a.light.accentStrong, reason: '${a.id} light.accentStrong');
        expect(lc.accentSoft, a.light.accentSoft, reason: '${a.id} light.accentSoft');
        expect(lc.onAccent, a.light.onAccent, reason: '${a.id} light.onAccent');
        expect(lt.colorScheme.primary, a.light.accent, reason: '${a.id} light scheme.primary');
        expect(lt.colorScheme.secondary, a.light.accent, reason: '${a.id} light scheme.secondary');
        expect(lt.colorScheme.onPrimary, a.light.onAccent);
        // 非 accent 的 20 槽保持固定值（既有 24 字段 API 兼容）。
        expect(lc.canvas, AppColors.light.canvas);
        expect(lc.recommend, AppColors.light.recommend);
        expect(lc.danger, AppColors.light.danger);
        expect(lc.bookname, AppColors.light.bookname);

        final ThemeData dt = BookTheme.of(Brightness.dark, FontFamilySet.standard, a);
        final AppColors dc = dt.extension<AppColors>()!;
        expect(dc.accent, a.dark.accent, reason: '${a.id} dark.accent');
        expect(dc.accentStrong, a.dark.accentStrong, reason: '${a.id} dark.accentStrong');
        expect(dc.accentSoft, a.dark.accentSoft, reason: '${a.id} dark.accentSoft');
        expect(dc.onAccent, a.dark.onAccent, reason: '${a.id} dark.onAccent');
        expect(dt.colorScheme.primary, a.dark.accent, reason: '${a.id} dark scheme.primary');
        expect(dc.canvas, AppColors.dark.canvas);
      }
    });

    test('无 accent 注入 = 既有默认主题（BookTheme.light/dark 与 of() 缺省一致）', () {
      final AppColors a = BookTheme.light.extension<AppColors>()!;
      final AppColors b = BookTheme.of(Brightness.light).extension<AppColors>()!;
      expect(a.accent, AppColors.light.accent);
      expect(b.accent, AppColors.light.accent);
      expect(BookTheme.dark.extension<AppColors>()!.accent, AppColors.dark.accent);
      expect(BookTheme.light.colorScheme.primary, AppColors.light.accent);
    });
  });

  group('持久化（内存 fake settings）', () {
    test('默认无键 → default 档；select → 写 theme_accent → invalidate → 读回所选档', () async {
      final FakeAccentStore store = FakeAccentStore();
      final ProviderContainer container = ProviderContainer(overrides: <Override>[
        accentStoreProvider.overrideWith((Ref ref) => store),
      ]);
      addTearDown(container.dispose);
      expect(await container.read(accentThemeProvider.future), same(AppAccentTheme.defaults));
      await container.read(accentControllerProvider).select('yi_ma_hong');
      expect(store.data[AccentSettingsKeys.themeAccent], 'yi_ma_hong');
      expect(store.writes, 1);
      expect((await container.read(accentThemeProvider.future)).id, 'yi_ma_hong');
    });

    test('已有键 → 启动即所选档', () async {
      final FakeAccentStore store = FakeAccentStore()..data[AccentSettingsKeys.themeAccent] = 'duo_kan_cheng';
      final ProviderContainer container = ProviderContainer(overrides: <Override>[
        accentStoreProvider.overrideWith((Ref ref) => store),
      ]);
      addTearDown(container.dispose);
      expect((await container.read(accentThemeProvider.future)).id, 'duo_kan_cheng');
    });

    test('store 抛错（哨兵/首启竞态）→ 回落 default 档，不抛出', () async {
      final ProviderContainer container = ProviderContainer(overrides: <Override>[
        accentStoreProvider.overrideWith((Ref ref) => throw StateError('sentinel')),
      ]);
      addTearDown(container.dispose);
      expect(await container.read(accentThemeProvider.future), same(AppAccentTheme.defaults));
    });
  });

  group('设置页 swatch UI（设计 07）', () {
    testWidgets('默认折叠：标题行 + 当前色名摘要 + chev 未旋转；开发口径副文案已移除', (WidgetTester tester) async {
      await pumpSettings(tester);

      // 标题行：「主题色」+ 收起态摘要 = 当前档色名（默认陶土珊瑚）。
      expect(accentTitleRow(), findsOneWidget);
      expect(find.text('陶土珊瑚'), findsOneWidget);
      expect(accentFadeState(tester), CrossFadeState.showSecond);
      expect(accentChevTurns(tester), 0.0);
      // 内部口径副文案（「P2 · 对标宝典 12 色」）不再出现在任何可见文本中。
      expect(find.textContaining('对标宝典'), findsNothing);
      expect(find.textContaining('P2'), findsNothing);
    });

    testWidgets('点标题行展开：13 枚 swatch 全渲染，当前档带勾（check-s 资产），主题色卡内零 Material Icon；再点收起',
        (WidgetTester tester) async {
      await pumpSettings(tester);
      await expandAccent(tester);

      expect(accentFadeState(tester), CrossFadeState.showFirst);
      expect(accentChevTurns(tester), 0.5); // chev 旋转半圈（˅ → ˄）
      for (final AppAccentTheme a in AppAccentTheme.all) {
        expect(swatchOf(a.id), findsOneWidget, reason: '${a.label} swatch 缺失');
      }
      // 勾只出现在默认档，且为设计 -s stroke2 资产（非 Material Icon）。
      expect(find.descendant(of: swatchOf('default'), matching: find.byType(SvgPicture)), findsOneWidget);
      for (final AppAccentTheme a in AppAccentTheme.all.skip(1)) {
        expect(find.descendant(of: swatchOf(a.id), matching: find.byType(SvgPicture)), findsNothing,
            reason: '${a.label} 未选中不应有勾');
      }
      final Finder card = find
          .ancestor(of: swatchOf('default'), matching: find.byType(Card))
          .first;
      expect(find.descendant(of: card, matching: find.byType(Icon)), findsNothing,
          reason: '主题色卡内不得出现 Material Icon（全仓结构图标单一出口 = SVG 资产）');

      // 再点标题行 → 收起（展开态随 State 保持，可反复切换）。
      await tester.tap(accentTitleRow());
      await tester.pumpAndSettle();
      expect(accentFadeState(tester), CrossFadeState.showSecond);
      expect(accentChevTurns(tester), 0.0);
    });

    testWidgets('点击切换：勾移动 + settings 持久化 + AppColors 实时换色（浅色）', (WidgetTester tester) async {
      final FakeAccentStore store = await pumpSettings(tester);
      await expandAccent(tester);
      await tester.tap(swatchOf('yi_ma_hong'));
      await tester.pumpAndSettle();

      expect(store.data[AccentSettingsKeys.themeAccent], 'yi_ma_hong');
      expect(find.descendant(of: swatchOf('yi_ma_hong'), matching: find.byType(SvgPicture)), findsOneWidget);
      expect(find.descendant(of: swatchOf('default'), matching: find.byType(SvgPicture)), findsNothing);

      final AppAccentTheme selected = AppAccentTheme.of('yi_ma_hong');
      final AppColors live = AppColors.of(tester.element(swatchOf('yi_ma_hong')));
      expect(live.accent, selected.light.accent, reason: '实时重推导：accent');
      expect(live.accentStrong, selected.light.accentStrong);
      expect(live.accentSoft, selected.light.accentSoft);
      expect(live.onAccent, selected.light.onAccent);
      // 非 accent 槽不动。
      expect(live.canvas, AppColors.light.canvas);
    });

    testWidgets('深色模式：选中后 dark 四槽生效；swatch 圆片保持 seed 原色', (WidgetTester tester) async {
      final FakeAccentStore store = await pumpSettings(tester, dark: true, initialId: 'fei_lu_lv');
      await expandAccent(tester);
      // 启动即持久化档：深色四槽已注入。
      final AppAccentTheme selected = AppAccentTheme.of('fei_lu_lv');
      AppColors live = AppColors.of(tester.element(swatchOf('fei_lu_lv')));
      expect(live.accent, selected.dark.accent);
      expect(live.onAccent, selected.dark.onAccent);
      expect(find.descendant(of: swatchOf('fei_lu_lv'), matching: find.byType(SvgPicture)), findsOneWidget);

      // 深色下切换 → dark 系换色；swatch 圆片色 = seed（深浅模式不变，设计 07 色卡即原色）。
      await tester.tap(swatchOf('xi_rang_lan'));
      await tester.pumpAndSettle();
      expect(store.data[AccentSettingsKeys.themeAccent], 'xi_rang_lan');
      live = AppColors.of(tester.element(swatchOf('xi_rang_lan')));
      expect(live.accent, AppAccentTheme.of('xi_rang_lan').dark.accent);
      expect(live.accentStrong, AppAccentTheme.of('xi_rang_lan').dark.accentStrong);
      final Iterable<Container> circles = tester.widgetList<Container>(
        find.descendant(of: swatchOf('xi_rang_lan'), matching: find.byType(Container)),
      );
      expect(
        circles.any((Container c) => (c.decoration is BoxDecoration) &&
            (c.decoration! as BoxDecoration).color == AppAccentTheme.of('xi_rang_lan').seed),
        isTrue,
        reason: 'swatch 圆片 = seed 原色',
      );
    });

    testWidgets('hover scale 1.08（设计 563）；移出还原', (WidgetTester tester) async {
      await pumpSettings(tester);
      await expandAccent(tester);
      final Finder swatch = swatchOf('pang_ci_lan');
      final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(swatch));
      await tester.pump();
      expect(
        tester.widget<AnimatedScale>(find.descendant(of: swatch, matching: find.byType(AnimatedScale))).scale,
        1.08,
      );
      await mouse.moveTo(const Offset(5, 5));
      await tester.pump();
      expect(
        tester.widget<AnimatedScale>(find.descendant(of: swatch, matching: find.byType(AnimatedScale))).scale,
        1.0,
      );
      await mouse.removePointer();
    });
  });
}
