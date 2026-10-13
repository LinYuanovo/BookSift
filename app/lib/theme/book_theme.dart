import 'package:flutter/material.dart';

import '../core/fonts/font_tokens.dart';
import 'app_colors.dart';
import 'app_motion.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// ThemeData 组装（设计系统 §5.1 ColorScheme 语义槽映射 + §5.2 extensions 注入）。
abstract final class BookTheme {
  /// M3 seed（§5.1：浅色 = 陶土珊瑚；深色 = 其浅阶，semantic 槽随后逐项覆盖）。
  static const Color _seedLight = Color(0xFFD97757);
  static const Color _seedDark = Color(0xFFE59A76);

  static final ThemeData light = of(Brightness.light);
  static final ThemeData dark = of(Brightness.dark);

  /// 按字体槽解析结果构建主题（v1.4 §5.2：families 变化 → 新 ThemeData；默认全 system）。
  static ThemeData of(Brightness brightness, [FontFamilySet families = FontFamilySet.standard]) =>
      _build(brightness, families);

  static ThemeData _build(Brightness brightness, FontFamilySet families) {
    final bool isLight = brightness == Brightness.light;
    final AppColors colors = isLight ? AppColors.light : AppColors.dark;
    final AppTypography typography = AppTypography.resolve(families);

    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: isLight ? _seedLight : _seedDark,
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
      extensions: <ThemeExtension<dynamic>>[colors, typography, AppSpacing.standard, AppMotionTheme.standardTokens],
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
    );
  }
}
