import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'core/constants.dart';
import 'core/fonts/font_service.dart';
import 'core/fonts/font_tokens.dart';
import 'core/update/update_controller.dart';
import 'data/seed_import_providers.dart';
import 'theme/app_accent.dart';
import 'theme/appearance_settings.dart';
import 'theme/book_theme.dart';

/// 应用根组件：双主题（BookTheme light/dark）+ go_router 注入 + 字体槽/主题色联动。
///
/// 字体设置变更 → FontService notify → 本组件重建 → BookTheme.of 注入新
/// FontFamilySet（v1.4 §5.2 解析链）。
/// 主题色变更（M3 P2-3）→ accentThemeProvider invalidate → 本组件重建 →
/// BookTheme.of 注入新 AppAccentTheme（加载中/读取失败回落陶土珊瑚默认档）。
/// 主题模式/减弱动效变更（M2）→ appearanceSettingsProvider invalidate → 本组件重建 →
/// themeMode 切换 + BookTheme.of 注入对应动效 token 集（加载中/读取失败回落
/// system + 标准动效，即原硬编码行为）。
///
/// M3 §10.1：首帧后调度一次启动静默更新检查（5s Timer 在 UpdateController 内，
/// 不阻塞启动；双源失败静默，有新版本经 updateAvailableProvider 暴露）。
class BookSiftApp extends ConsumerStatefulWidget {
  const BookSiftApp({super.key});

  @override
  ConsumerState<BookSiftApp> createState() => _BookSiftAppState();
}

class _BookSiftAppState extends ConsumerState<BookSiftApp> {
  @override
  void initState() {
    super.initState();
    // 静默检查接线：首帧后幂等调度（ensureStartupCheckScheduled 内部 5s Timer）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(updateControllerProvider.notifier).ensureStartupCheckScheduled();
        // P0-1 首启种子导入（§9.2）：幂等；闸门关闭（已导入）时近似 no-op，
        // FTS 未就绪则后台续跑重建。
        ref.read(seedBootstrapProvider.notifier).ensureStarted();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final FontFamilySet families = ref.watch(fontServiceProvider).families;
    final AppAccentTheme accent = ref.watch(accentThemeProvider).value ?? AppAccentTheme.defaults;
    final AppearanceSettings appearance =
        ref.watch(appearanceSettingsProvider).value ?? const AppearanceSettings();
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: BookTheme.of(Brightness.light, families, accent, appearance.reduceMotion),
      darkTheme: BookTheme.of(Brightness.dark, families, accent, appearance.reduceMotion),
      themeMode: appearance.themeMode,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
