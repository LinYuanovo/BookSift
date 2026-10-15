import 'package:flutter/material.dart';

import '../core/fonts/font_tokens.dart';
import 'app_accent.dart';
import 'app_colors.dart';
import 'app_motion.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// ThemeData 组装（设计系统 §5.1 ColorScheme 语义槽映射 + §5.2 extensions 注入）。
abstract final class BookTheme {
  static final ThemeData light = of(Brightness.light);
  static final ThemeData dark = of(Brightness.dark);

  /// 按字体槽解析结果 + 主题色档构建主题（v1.4 §5.2：families 变化 → 新 ThemeData；
  /// M3 P2-3：accent 变化 → accent 四槽与 ColorScheme seed/primary/secondary 系随之变化，
  /// 其余 20 语义槽不变；accent 缺省 = 陶土珊瑚，与原 _seedLight #D97757 / _seedDark #E59A76 等价）。
  /// [reduceMotion]（M2 设置项）：true → extensions 注入 AppMotionTheme.reducedTokens
  /// （全部时长 ≤100ms、stagger 归零），false/缺省 = standardTokens。
  static ThemeData of(
    Brightness brightness, [
    FontFamilySet families = FontFamilySet.standard,
    AppAccentTheme? accent,
    bool reduceMotion = false,
  ]) =>
      _build(brightness, families, accent ?? AppAccentTheme.defaults, reduceMotion);

  static ThemeData _build(Brightness brightness, FontFamilySet families, AppAccentTheme accent, bool reduceMotion) {
    final bool isLight = brightness == Brightness.light;
    final AccentPalette palette = isLight ? accent.light : accent.dark;
    final AppColors colors = (isLight ? AppColors.light : AppColors.dark).withAccentColors(
      accent: palette.accent,
      accentStrong: palette.accentStrong,
      accentSoft: palette.accentSoft,
      onAccent: palette.onAccent,
    );
    final AppTypography typography = AppTypography.resolve(families);

    final ColorScheme scheme = ColorScheme.fromSeed(
      // M3 seed = 当前主题色档的本模式 accent（默认档即原 _seedLight/_seedDark）。
      seedColor: palette.accent,
      brightness: brightness,
    ).copyWith(
      // §5.1 语义槽覆盖（M3 自动色不满足纸感要求）
      surface: colors.surface,
      surfaceContainerLowest: colors.surfaceRaised,
      surfaceContainerHighest: colors.surfaceSunken,
      onSurface: colors.text,
      onSurfaceVariant: colors.textSecondary,
      outline: colors.border,
      outlineVariant: colors.borderStrong,
      primary: colors.accent,
      onPrimary: colors.onAccent,
      primaryContainer: colors.accentSoft,
      onPrimaryContainer: colors.accentStrong,
      secondary: colors.accent,
      onSecondary: colors.onAccent,
      secondaryContainer: colors.accentSoft,
      onSecondaryContainer: colors.accentStrong,
      error: colors.danger,
      errorContainer: colors.dangerSoft,
      onError: colors.onInk,
      onErrorContainer: colors.danger,
    );

    // 字阶 → Material TextTheme 角色映射（按字号/用途对齐）：
    // displaySmall=display30 · headlineSmall=headline18 · titleLarge=title22 · titleMedium=cardTitle16
    // bodyLarge=body15 · bodyMedium=secondary13.5 · bodySmall=caption12
    // labelLarge=bodyStrong15（按钮） · labelMedium/labelSmall=label11
    TextStyle inked(TextStyle style) => style.copyWith(color: colors.text);
    final TextTheme textTheme = TextTheme(
      displaySmall: inked(typography.display),
      headlineSmall: inked(typography.headline),
      titleLarge: inked(typography.title),
      titleMedium: inked(typography.cardTitle),
      bodyLarge: inked(typography.body),
      bodyMedium: inked(typography.secondary),
      bodySmall: inked(typography.caption),
      labelLarge: inked(typography.bodyStrong),
      labelMedium: inked(typography.label),
      labelSmall: inked(typography.label),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.canvas,
      canvasColor: colors.canvas,
      // 不设全局 fontFamily：字阶 token 已逐 style 携带 family（null = 平台系统默认，v1.4 §2.2）。
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[
        colors,
        typography,
        AppSpacing.standard,
        reduceMotion ? AppMotionTheme.reducedTokens : AppMotionTheme.standardTokens,
      ],
      dividerColor: colors.border,
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: AppMetrics.hairline,
        space: AppMetrics.hairline,
      ),
      // 按压涟漪/高亮走 accent-soft（§1：以色块分层，不用 Material elevation）
      splashColor: colors.accentSoft,
      highlightColor: colors.accentSoft.withValues(alpha: 0.5),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accent, // 珊瑚 caret（§3 #02）
        selectionColor: colors.accentSoft,
        selectionHandleColor: colors.accent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: inked(typography.headline), // AppBar 标题 = headline（§2.2）
        toolbarHeight: AppMetrics.appBarHeight,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: AppMetrics.bottomNavHeight,
        indicatorColor: colors.accentSoft, // 指示胶囊 accent-soft（§4 底部导航）
        labelTextStyle: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => inked(typography.label).copyWith(
            color: states.contains(WidgetState.selected) ? colors.accentStrong : colors.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => IconThemeData(
            size: 24, // §4：导航图标 24
            color: states.contains(WidgetState.selected) ? colors.accentStrong : colors.textSecondary,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.accentSoft,
        selectedIconTheme: IconThemeData(color: colors.accentStrong, size: 24),
        unselectedIconTheme: IconThemeData(color: colors.textSecondary, size: 24),
        selectedLabelTextStyle: inked(typography.label).copyWith(color: colors.accentStrong),
        unselectedLabelTextStyle: inked(typography.label).copyWith(color: colors.textSecondary),
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceRaised,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias, // 同心圆角：贴边子元素靠外层裁切（§2.4）
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgBorder,
          side: BorderSide(color: colors.border, width: AppMetrics.hairline),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.ink, // Snackbar ink 底（§4）
        contentTextStyle: typography.body.copyWith(color: colors.onInk),
        actionTextColor: colors.accent, // 右侧动作字 = accent（§4）
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorder), // r14（§4）
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceRaised, // 弹层内容 = raised（§2.1）
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgBorder,
          side: BorderSide(color: colors.border, width: AppMetrics.hairline),
        ),
      ),
      // 弹出菜单（书聚合排序 / ⋮更多 等）：浮层唯一阴影场景（§2.1 --shadow-overlay）；
      // raised 底 + 1px 发丝描边 + r14，去掉 M3 默认 surfaceTint 粉染。
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdBorder,
          side: BorderSide(color: colors.border, width: AppMetrics.hairline),
        ),
        textStyle: typography.body.copyWith(color: colors.text),
      ),
      // 底部弹层（维度值域 / 随机书荒 / 分享导出）：raised 底 + 去 surfaceTint 粉染 + 顶部 r24。
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
    );
  }
}
