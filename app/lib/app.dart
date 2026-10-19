import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'core/app_scroll_behavior.dart';
import 'core/constants.dart';
import 'core/fonts/font_service.dart';
import 'core/fonts/font_tokens.dart';
import 'core/fonts/system_font.dart';
import 'core/update/update_controller.dart';
import 'core/widgets/window_title_bar.dart';
import 'core/window/window_frame.dart';
import 'data/seed_import_providers.dart';
import 'theme/app_accent.dart';
import 'theme/app_motion.dart';
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
/// 需求 4b：family 解析结果先过 [applySystemDefaultFont]（Windows 读系统默认 UI
/// 字体族注入 system 槽角色；非 Windows/失败原样返回），再交给 BookTheme。
/// 需求 4a：[AppScrollBehavior] 关掉框架在 Windows 桌面自动叠加的滚动条，
/// 只保留 ScrollChrome 自绘那条。
/// 需求 6：本地化为纯中文（zh-CN）→ 长按选词的系统菜单（剪切/复制/粘贴/全选）
/// 走 GlobalMaterialLocalizations 中文文案。
///
/// M3 §10.1：首帧后调度一次启动静默更新检查（5s Timer 在 UpdateController 内，
/// 不阻塞启动；双源失败静默，有新版本经 updateAvailableProvider 暴露）。
class BookSiftApp extends ConsumerStatefulWidget {
  const BookSiftApp({super.key});

  @override
  ConsumerState<BookSiftApp> createState() => _BookSiftAppState();
}

class _BookSiftAppState extends ConsumerState<BookSiftApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAccessibilityFeatures() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final FontFamilySet families = applySystemDefaultFont(ref.watch(fontServiceProvider).families);
    final AppAccentTheme accent = ref.watch(accentThemeProvider).value ?? AppAccentTheme.defaults;
    final AppearanceSettings appearance =
        ref.watch(appearanceSettingsProvider).value ?? const AppearanceSettings();
    final bool systemReduceMotion =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    final AppMotionTheme motion = appearance.reduceMotion || systemReduceMotion
        ? AppMotionTheme.reducedTokens
        : AppMotionTheme.standardTokens;
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const <Locale>[Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: BookTheme.of(Brightness.light, families, accent, appearance.reduceMotion),
      darkTheme: BookTheme.of(Brightness.dark, families, accent, appearance.reduceMotion),
      themeMode: appearance.themeMode,
      themeAnimationDuration: motion.transition.duration,
      themeAnimationCurve: motion.transition.curve,
      // Windows 自绘标题栏：顶部条挂在 Navigator 之上（Toast 的根 Overlay 仍在下方），
      // 窗口拖动/双击最大化由 runner 的 HTCAPTION 命中交给系统（见 core/window/window_frame.dart）。
      builder: (BuildContext context, Widget? child) {
        final Widget view = child ?? const SizedBox.shrink();
        if (!WindowFrameMetrics.enabled) {
          return view;
        }
        return Column(
          children: <Widget>[
            const WindowTitleBar(),
            Expanded(child: view),
          ],
        );
      },
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
