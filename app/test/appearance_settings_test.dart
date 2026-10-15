/// 外观设置（主题模式 / 减弱动效）守卫与行为测试（M2）。
///
/// 持久化组 = plain test() + NativeDatabase.memory()（TESTING.md §3.2 允许档：
/// 当前 isolate 同步 FFI，Future 以微任务完成，不落盘、不触 path_provider）。
/// widget 组 = 全内存：appDatabaseProvider 哨兵抛错 → provider 回落缺省渲染；
/// 或 appearanceSettingsProvider 直接 override 注入持久化态。零真实 IO。
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/constants.dart';
import 'package:booksift/core/fonts/font_tokens.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/database_provider.dart';
import 'package:booksift/features/home/cards.dart';
import 'package:booksift/features/profile/settings_page.dart';
import 'package:booksift/theme/app_motion.dart';
import 'package:booksift/theme/appearance_settings.dart';
import 'package:booksift/theme/book_theme.dart';

import 'support/fake_book_repository.dart';
import 'support/harness.dart';

/// 直读 settings 表原始值（校验写入口径本身，而非仅 provider 回读）。
Future<String?> rawRead(AppDatabase db, String key) async {
  final Setting? row =
      await (db.select(db.settings)..where((Settings t) => t.key.equals(key))).getSingleOrNull();
  return row?.value;
}

ProviderContainer containerWithDb(AppDatabase db) {
  final ProviderContainer container = ProviderContainer(overrides: <Override>[
    appDatabaseProvider.overrideWithValue(db),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('解析与持久化往返（内存 drift 库）', () {
    test('空表 → 缺省：themeMode=system · reduceMotion=false', () async {
      final AppDatabase db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final ProviderContainer container = containerWithDb(db);

      final AppearanceSettings s = await container.read(appearanceSettingsProvider.future);
      expect(s.themeMode, ThemeMode.system);
      expect(s.reduceMotion, isFalse);
    });

    test('setThemeMode 三档往返：写 theme 键 → invalidate → 读回所选档', () async {
      final AppDatabase db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final ProviderContainer container = containerWithDb(db);

      for (final (ThemeMode mode, String stored) in <(ThemeMode, String)>[
        (ThemeMode.dark, 'dark'),
        (ThemeMode.light, 'light'),
        (ThemeMode.system, 'system'),
      ]) {
        await container.read(appearanceSettingsControllerProvider).setThemeMode(mode);
        expect(await rawRead(db, SettingsKeys.theme), stored);
        expect((await container.read(appearanceSettingsProvider.future)).themeMode, mode);
      }
    });

    test("setReduceMotion 往返：写 reduce_motion 键 'true'/'false' → 读回", () async {
      final AppDatabase db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final ProviderContainer container = containerWithDb(db);

      await container.read(appearanceSettingsControllerProvider).setReduceMotion(true);
      expect(await rawRead(db, SettingsKeys.reduceMotion), 'true');
      expect((await container.read(appearanceSettingsProvider.future)).reduceMotion, isTrue);

      await container.read(appearanceSettingsControllerProvider).setReduceMotion(false);
      expect(await rawRead(db, SettingsKeys.reduceMotion), 'false');
      expect((await container.read(appearanceSettingsProvider.future)).reduceMotion, isFalse);
    });

    test("未知/非约定存量值 → 回落缺省（theme='sepia' → system；reduce_motion='1' → false）", () async {
      final AppDatabase db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db
          .into(db.settings)
          .insertOnConflictUpdate(SettingsCompanion.insert(key: SettingsKeys.theme, value: 'sepia'));
      await db
          .into(db.settings)
          .insertOnConflictUpdate(SettingsCompanion.insert(key: SettingsKeys.reduceMotion, value: '1'));
      final ProviderContainer container = containerWithDb(db);

      final AppearanceSettings s = await container.read(appearanceSettingsProvider.future);
      expect(s.themeMode, ThemeMode.system);
      expect(s.reduceMotion, isFalse);
    });

    test('读取失败（DB 哨兵抛错）→ 回落缺省，不抛出', () async {
      final ProviderContainer container = ProviderContainer(overrides: <Override>[
        appDatabaseProvider.overrideWith((Ref ref) => throw StateError('sentinel')),
      ]);
      addTearDown(container.dispose);

      final AppearanceSettings s = await container.read(appearanceSettingsProvider.future);
      expect(s.themeMode, ThemeMode.system);
      expect(s.reduceMotion, isFalse);
    });
  });

  group('BookTheme.of 动效注入', () {
    test('reduceMotion=true → extensions 注入 reducedTokens；缺省/静态实例 = standardTokens', () {
      final ThemeData reduced = BookTheme.of(Brightness.light, FontFamilySet.standard, null, true);
      final AppMotionTheme m = reduced.extension<AppMotionTheme>()!;
      expect(m.reduceMotion, isTrue);
      expect(m.normal, const Duration(milliseconds: 100));
      expect(m.staggerDelay, Duration.zero);
      expect(m.pulse, Duration.zero);

      final AppMotionTheme standard = BookTheme.of(Brightness.light).extension<AppMotionTheme>()!;
      expect(standard.reduceMotion, isFalse);
      expect(standard.normal, const Duration(milliseconds: 300));
      // 既有静态实例保持标准集（向后兼容：harness 与存量调用不受影响）。
      expect(BookTheme.light.extension<AppMotionTheme>()!.reduceMotion, isFalse);
      expect(BookTheme.dark.extension<AppMotionTheme>()!.reduceMotion, isFalse);
    });

    test('深浅双模式均按 reduceMotion 注入', () {
      for (final Brightness b in <Brightness>[Brightness.light, Brightness.dark]) {
        expect(
          BookTheme.of(b, FontFamilySet.standard, null, true).extension<AppMotionTheme>()!.reduceMotion,
          isTrue,
        );
        expect(BookTheme.of(b).extension<AppMotionTheme>()!.reduceMotion, isFalse);
      }
    });
  });

  group('设置页 UI（widget，全内存）', () {
    /// 屏外元素按 TESTING.md §7-6 加高视口（新两卡把「关于」区推到更远）。
    Future<void> pumpSettings(WidgetTester tester, {List<Override> extraOverrides = const <Override>[]}) async {
      useSurface(tester, height: 1600, dpr: 1);
      await tester.pumpWidget(
        testApp(FakeBookRepository(), home: const SettingsPage(), extraOverrides: extraOverrides),
      );
      // FutureProvider 微任务级完成：两次定步 pump 冲刷（同 collect_idle_test）。
      await tester.pump();
      await tester.pump();
    }

    Text segmentText(WidgetTester tester, String label) => tester.widget<Text>(
          find.descendant(of: find.byType(SegmentedPill<ThemeMode>), matching: find.text(label)),
        );

    testWidgets('缺省渲染（DB 哨兵 → 回落）：三档分段 + 跟随系统选中 + 减弱动效关', (WidgetTester tester) async {
      await pumpSettings(tester);

      expect(find.text('主题模式'), findsOneWidget);
      expect(segmentText(tester, '跟随系统').style?.fontWeight, FontWeight.w600);
      expect(segmentText(tester, '浅色').style?.fontWeight, FontWeight.w400);
      expect(segmentText(tester, '深色').style?.fontWeight, FontWeight.w400);

      expect(find.text('减弱动效'), findsOneWidget);
      expect(find.text('全部动效退化为 ≤100ms opacity · 实时生效'), findsOneWidget);
      final Switch sw = tester.widget<Switch>(
        find.descendant(of: find.widgetWithText(ListTile, '减弱动效'), matching: find.byType(Switch)),
      );
      expect(sw.value, isFalse);
    });

    testWidgets('持久化态渲染（provider override）：深色选中 + 减弱动效开', (WidgetTester tester) async {
      await pumpSettings(
        tester,
        extraOverrides: <Override>[
          appearanceSettingsProvider.overrideWith(
            (Ref ref) async => const AppearanceSettings(themeMode: ThemeMode.dark, reduceMotion: true),
          ),
        ],
      );

      expect(segmentText(tester, '深色').style?.fontWeight, FontWeight.w600);
      expect(segmentText(tester, '跟随系统').style?.fontWeight, FontWeight.w400);
      final Switch sw = tester.widget<Switch>(
        find.descendant(of: find.widgetWithText(ListTile, '减弱动效'), matching: find.byType(Switch)),
      );
      expect(sw.value, isTrue);
    });

    testWidgets('写入失败（DB 哨兵）→ SnackBar「保存失败」，分段选中态不变', (WidgetTester tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('深色'));
      await tester.pump();
      expect(find.text('保存失败'), findsOneWidget);
      expect(segmentText(tester, '跟随系统').style?.fontWeight, FontWeight.w600);
      await dismissSnackBars(tester);
    });
  });
}
