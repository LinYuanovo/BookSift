import 'package:flutter/material.dart';

/// 语义色 token（组件唯一引用层）。
///
/// 出处：`docs/设计系统-Claude-v1.2.md` §2.1 semantic 映射表，色值逐值搬运。
/// 治理约定（§5.2）：CSS 变量名 == Dart 字段名（`--color-recommend` ↔ [AppColors.recommend]）；
/// 业务代码禁止硬编码 primitive hex（test/theme_tokens_test.dart 有全仓守卫用例）。
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentStrong,
    required this.accentSoft,
    required this.onAccent,
    required this.ink,
    required this.onInk,
    required this.recommend,
    required this.recommendSoft,
    required this.danger,
    required this.dangerSoft,
    required this.bookname,
    required this.info,
    required this.infoSoft,
    required this.highlight,
    required this.shadowOverlay,
  });

  /// 屏幕/页面底 `--color-canvas`
  final Color canvas;

  /// appbar / 状态栏 / 底栏 `--color-surface`
  final Color surface;

  /// 卡片 / 弹层内容 `--color-surface-raised`
  final Color surfaceRaised;

  /// 搜索底 / 骨架 / 轨道 / 中性徽标底 `--color-surface-sunken`
  final Color surfaceSunken;

  /// 发丝线 `--color-border`
  final Color border;

  /// 输入框 / chip 描边 `--color-border-strong`
  final Color borderStrong;

  /// 主文字（暖近黑/暖近白）`--color-text`
  final Color text;

  /// 次级文字 `--color-text-secondary`
  final Color textSecondary;

  /// 弱化文字（仍 ≥4.5:1）`--color-text-muted`
  final Color textMuted;

  /// 品牌填充：按钮/指示器/进度/开关 `--color-accent`
  final Color accent;

  /// 珊瑚的文字级：链接/选中文字 `--color-accent-strong`
  final Color accentStrong;

  /// 选中态底 / nav 胶囊 / 快照 chip `--color-accent-soft`
  final Color accentSoft;

  /// 珊瑚填充上的文字 `--color-on-accent`
  final Color onAccent;

  /// 主按钮（墨色）/ Toast 底 `--color-ink`
  final Color ink;

  /// 墨底上的文字 `--color-on-ink`
  final Color onInk;

  /// 推荐语义（林绿）`--color-recommend`
  final Color recommend;

  /// 推荐语义染底 `--color-recommend-soft`
  final Color recommendSoft;

  /// 排雷语义（砖红）`--color-danger`
  final Color danger;

  /// 排雷语义染底 `--color-danger-soft`
  final Color dangerSoft;

  /// 《书名》标红可点 `--color-bookname`
  final Color bookname;

  /// URL 链接 / 「导入」徽标 `--color-info`
  final Color info;

  /// info 染底 `--color-info-soft`
  final Color infoSoft;

  /// 搜索词琥珀高亮（荧光笔心智）`--color-highlight`
  final Color highlight;

  /// 仅浮层阴影色 `--shadow-overlay`（light rgba(31,30,27,.16) / dark rgba(0,0,0,.55)；
  /// 阴影几何 0 12px 32px 见 AppMetrics.shadow*）。
  final Color shadowOverlay;

  static const AppColors light = AppColors(
    canvas: Color(0xFFF0F0EB),
    surface: Color(0xFFFAF9F5),
    surfaceRaised: Color(0xFFFFFDF8),
    surfaceSunken: Color(0xFFE9E7DE),
    border: Color(0xFFE3DFD5),
    borderStrong: Color(0xFFD6D1C4),
    text: Color(0xFF1F1E1B),
    textSecondary: Color(0xFF66645C),
    textMuted: Color(0xFF6E6C62),
    accent: Color(0xFFD97757),
    accentStrong: Color(0xFFA64E2C),
    accentSoft: Color(0xFFF6E7DF),
    onAccent: Color(0xFF241209),
    ink: Color(0xFF1F1E1B),
    onInk: Color(0xFFFAF9F5),
    recommend: Color(0xFF2F6F35),
    recommendSoft: Color(0xFFE4EDDF),
    danger: Color(0xFFA93B32),
    dangerSoft: Color(0xFFF4E3DE),
    bookname: Color(0xFFC0453A),
    info: Color(0xFF3F6B8A),
    infoSoft: Color(0xFFE3EBF1),
    highlight: Color(0xFFF3E3B6),
    shadowOverlay: Color(0x291F1E1B),
  );

  static const AppColors dark = AppColors(
    canvas: Color(0xFF171614),
    surface: Color(0xFF201F1C),
    surfaceRaised: Color(0xFF2A2926),
    surfaceSunken: Color(0xFF121110),
    border: Color(0xFF3A3833),
    borderStrong: Color(0xFF4A4741),
    text: Color(0xFFF0EEE4),
    textSecondary: Color(0xFFB6B3A6),
    textMuted: Color(0xFF94917F),
    accent: Color(0xFFE59A76),
    accentStrong: Color(0xFFEEB292),
    accentSoft: Color(0xFF453025),
    onAccent: Color(0xFF201F1C),
    ink: Color(0xFFF0EEE4),
    onInk: Color(0xFF201F1C),
    recommend: Color(0xFF9CC084),
    recommendSoft: Color(0xFF2A3524),
    danger: Color(0xFFE08E7E),
    dangerSoft: Color(0xFF43302A),
    bookname: Color(0xFFE8927C),
    info: Color(0xFF8FB4CC),
    infoSoft: Color(0xFF25313A),
    highlight: Color(0xFF5A4A1E),
    shadowOverlay: Color(0x8C000000),
  );

  static AppColors of(BuildContext context) => Theme.of(context).extension<AppColors>()!;

  /// 按主题色档（M3 P2-3 · AppAccentTheme）替换 accent 四槽，其余 20 字段原样保留。
  /// 直传四色而非 AccentPalette：本文件保持零依赖（app_accent.dart 含 riverpod/drift）。
  AppColors withAccentColors({
    required Color accent,
    required Color accentStrong,
    required Color accentSoft,
    required Color onAccent,
  }) =>
      copyWith(accent: accent, accentStrong: accentStrong, accentSoft: accentSoft, onAccent: onAccent);

  @override
  AppColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? border,
    Color? borderStrong,
    Color? text,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? accentStrong,
    Color? accentSoft,
    Color? onAccent,
    Color? ink,
    Color? onInk,
    Color? recommend,
    Color? recommendSoft,
    Color? danger,
    Color? dangerSoft,
    Color? bookname,
    Color? info,
    Color? infoSoft,
    Color? highlight,
    Color? shadowOverlay,
  }) {
    return AppColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      text: text ?? this.text,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      accentStrong: accentStrong ?? this.accentStrong,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      ink: ink ?? this.ink,
      onInk: onInk ?? this.onInk,
      recommend: recommend ?? this.recommend,
      recommendSoft: recommendSoft ?? this.recommendSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      bookname: bookname ?? this.bookname,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      highlight: highlight ?? this.highlight,
      shadowOverlay: shadowOverlay ?? this.shadowOverlay,
    );
  }

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) {
      return this;
    }
    return AppColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      text: Color.lerp(text, other.text, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentStrong: Color.lerp(accentStrong, other.accentStrong, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      onInk: Color.lerp(onInk, other.onInk, t)!,
      recommend: Color.lerp(recommend, other.recommend, t)!,
      recommendSoft: Color.lerp(recommendSoft, other.recommendSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      bookname: Color.lerp(bookname, other.bookname, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSoft: Color.lerp(infoSoft, other.infoSoft, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      shadowOverlay: Color.lerp(shadowOverlay, other.shadowOverlay, t)!,
    );
  }
}
