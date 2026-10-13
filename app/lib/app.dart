import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'core/constants.dart';
import 'core/fonts/font_service.dart';
import 'core/fonts/font_tokens.dart';
import 'theme/book_theme.dart';

/// 应用根组件：双主题（BookTheme light/dark）+ go_router 注入 + 字体槽联动。
///
/// 字体设置变更 → FontService notify → 本组件重建 → BookTheme.of 注入新
/// FontFamilySet（v1.4 §5.2 解析链）。
class SaoshuhuiApp extends ConsumerWidget {
  const SaoshuhuiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FontFamilySet families = ref.watch(fontServiceProvider).families;
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: BookTheme.of(Brightness.light, families),
      darkTheme: BookTheme.of(Brightness.dark, families),
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
