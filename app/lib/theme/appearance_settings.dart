import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../data/db/app_database.dart';
import '../data/repo/database_provider.dart';

/// 外观设置（settings 表 KV：`theme` / `reduce_motion`，键名 core/constants.dart）。
///
/// 取值域：theme ∈ 'system'|'light'|'dark'（缺省/未知一律回落 system）；
/// reduce_motion ∈ 'true'|'false'（缺省 false）。
/// 读取失败（如 widget 测试的 appDatabaseProvider 哨兵、首启竞态）一律回落缺省值，
/// 不阻断 UI —— 与 collectSettingsProvider 同策略。
class AppearanceSettings {
  const AppearanceSettings({this.themeMode = ThemeMode.system, this.reduceMotion = false});

  /// 主题模式（app.dart 直喂 MaterialApp.themeMode）。
  final ThemeMode themeMode;

  /// 减弱动效（app.dart 经 BookTheme.of 注入 AppMotionTheme.reducedTokens）。
  final bool reduceMotion;
}

/// 当前外观设置。app.dart 顶层 watch：设置页写入 → controller invalidate 本 provider
/// → MaterialApp 重建换 themeMode 与动效 token 集，实时生效（设计系统 §3 #07）。
final FutureProvider<AppearanceSettings> appearanceSettingsProvider =
    FutureProvider<AppearanceSettings>((Ref ref) async {
      try {
        final AppDatabase db = ref.watch(appDatabaseProvider);
        Future<String?> read(String key) =>
            (db.select(db.settings)..where((Settings t) => t.key.equals(key)))
                .getSingleOrNull()
                .then((Setting? row) => row?.value);
        final String? theme = await read(SettingsKeys.theme);
        final String? motion = await read(SettingsKeys.reduceMotion);
        return AppearanceSettings(
          themeMode: switch (theme) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          },
          reduceMotion: motion == 'true',
        );
      } catch (_) {
        return const AppearanceSettings();
      }
    });

/// 外观设置写入（设置页「外观」小节消费；写后 invalidate 读取侧）。
class AppearanceSettingsController {
  const AppearanceSettingsController(this._ref);

  final Ref _ref;

  Future<void> setThemeMode(ThemeMode mode) => _write(
        SettingsKeys.theme,
        switch (mode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        },
      );

  Future<void> setReduceMotion(bool value) =>
      _write(SettingsKeys.reduceMotion, value ? 'true' : 'false');

  Future<void> _write(String key, String value) async {
    final AppDatabase db = _ref.read(appDatabaseProvider);
    await db
        .into(db.settings)
        .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
    _ref.invalidate(appearanceSettingsProvider);
  }
}

final Provider<AppearanceSettingsController> appearanceSettingsControllerProvider =
    Provider<AppearanceSettingsController>(AppearanceSettingsController.new);
