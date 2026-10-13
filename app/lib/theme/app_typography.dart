import 'package:flutter/material.dart';

import '../core/fonts/font_tokens.dart';

/// 字阶 token（v1.4 令牌化：字号/行高/字重/字距固定，family 全部来自字体槽解析结果）。
///
/// 出处：`docs/设计系统-Claude-v1.4.md` §2.2（规格 = 字号/行高 · 字重 · 字体槽）、§2.3（富文本正文行高 27）。
/// 颜色不由本 token 承载：由 BookTheme 组装 textTheme 时统一注入（§5.2 治理）。
///
/// 字体策略（v1.4）：本文件不再声明任何家族字面量。默认全部走平台系统字体
/// （family=null），等宽角色走 [FontFamily.monospace]；用户导入字体后由
/// FontService 解析出 [FontFamilySet]，经 [AppTypography.resolve] 构建本扩展，
/// BookTheme 注入主题。层级美观靠字号/字重/字距 token，不依赖特定家族。
@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({
    required this.families,
    required this.display,
    required this.title,
    required this.headline,
    required this.cardTitle,
    required this.body,
    required this.bodyStrong,
    required this.bodyRich,
    required this.secondary,
    required this.caption,
    required this.label,
    required this.mono,
  });

  /// 十角色 family 解析结果（null = 平台系统默认；见 FontService._resolve）。
  final FontFamilySet families;

  /// `--text-display` 30/40 · 700：书聚合页书名、启动大字。
  final TextStyle display;

  /// `--text-title` 22/32 · 600：页面大标题。
  final TextStyle title;

  /// `--text-headline` 18/28 · 600：AppBar 标题、分区标题。
  final TextStyle headline;

  /// `--text-cardtitle` 16/26 · 600：卡片书名/帖名。
  final TextStyle cardTitle;

  /// `--text-body` 15/26 · 400：正文/楼层富文本。
  final TextStyle body;

  /// `--text-body-strong` 15/26 · 500：按钮/列表主文字（family 复用 body 槽，非独立角色）。
  final TextStyle bodyStrong;

  /// 楼层富文本正文 15/27 · 400（§2.3 v1.1：正文行高 body 26 / rich 27）。
  final TextStyle bodyRich;

  /// `--text-secondary` 13.5/21 · 400：摘要/次级。
  final TextStyle secondary;

  /// `--text-caption` 12/17 · 400：元信息/日期。
  final TextStyle caption;

  /// `--text-label` 11/14 · 500：徽标/导航/全大写分区（letter-spacing .14em = 1.54px）。
  final TextStyle label;

  /// 等宽：日志流/水位（§1 字体策略「日志/水位：等宽」），档位对齐 caption。
  final TextStyle mono;

  /// 由字体槽解析结果构建字阶：数值 token 固定（§2.2），family 逐角色注入。
  static AppTypography resolve(FontFamilySet families) => AppTypography(
    families: families,
    display: TextStyle(
      fontFamily: families.display,
      fontSize: 30,
      height: 40 / 30,
      fontWeight: FontWeight.w700,
    ),
    title: TextStyle(
      fontFamily: families.title,
      fontSize: 22,
      height: 32 / 22,
      fontWeight: FontWeight.w600,
    ),
    headline: TextStyle(
      fontFamily: families.headline,
      fontSize: 18,
      height: 28 / 18,
      fontWeight: FontWeight.w600,
    ),
    cardTitle: TextStyle(
      fontFamily: families.cardTitle,
      fontSize: 16,
      height: 26 / 16,
      fontWeight: FontWeight.w600,
    ),
    body: TextStyle(fontFamily: families.body, fontSize: 15, height: 26 / 15),
    bodyStrong: TextStyle(
      fontFamily: families.body, // bodyStrong 复用 body 槽（十角色之外的派生档位）
      fontSize: 15,
      height: 26 / 15,
      fontWeight: FontWeight.w500,
    ),
    bodyRich: TextStyle(fontFamily: families.bodyRich, fontSize: 15, height: 27 / 15),
    secondary: TextStyle(fontFamily: families.secondary, fontSize: 13.5, height: 21 / 13.5),
    caption: TextStyle(fontFamily: families.caption, fontSize: 12, height: 17 / 12),
    label: TextStyle(
      fontFamily: families.label,
      fontSize: 11,
      height: 14 / 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.54,
    ),
    mono: TextStyle(fontFamily: families.mono, fontSize: 12, height: 17 / 12),
  );

  /// 默认字阶：全 system 槽（零自定义字体加载）。
  static final AppTypography standard = resolve(FontFamilySet.standard);

  /// 等宽数字（§2.2：计数类——命中数/采集计数/进度% 一律 tabular-nums，防布局跳动）。
  static TextStyle tabular(TextStyle style) =>
      style.copyWith(fontFeatures: const <FontFeature>[FontFeature.tabularFigures()]);

  static AppTypography of(BuildContext context) => Theme.of(context).extension<AppTypography>()!;

  @override
  AppTypography copyWith({
    FontFamilySet? families,
    TextStyle? display,
    TextStyle? title,
    TextStyle? headline,
    TextStyle? cardTitle,
    TextStyle? body,
    TextStyle? bodyStrong,
    TextStyle? bodyRich,
    TextStyle? secondary,
    TextStyle? caption,
    TextStyle? label,
    TextStyle? mono,
  }) {
    return AppTypography(
      families: families ?? this.families,
      display: display ?? this.display,
      title: title ?? this.title,
      headline: headline ?? this.headline,
      cardTitle: cardTitle ?? this.cardTitle,
      body: body ?? this.body,
      bodyStrong: bodyStrong ?? this.bodyStrong,
      bodyRich: bodyRich ?? this.bodyRich,
      secondary: secondary ?? this.secondary,
      caption: caption ?? this.caption,
      label: label ?? this.label,
      mono: mono ?? this.mono,
    );
  }

  @override
  AppTypography lerp(covariant AppTypography? other, double t) {
    if (other == null) {
      return this;
    }
    return AppTypography(
      // family 不可插值：过半程整体切换（主题 crossfade 下视觉即淡入新字体）。
      families: t < 0.5 ? families : other.families,
      display: TextStyle.lerp(display, other.display, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      headline: TextStyle.lerp(headline, other.headline, t)!,
      cardTitle: TextStyle.lerp(cardTitle, other.cardTitle, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      bodyStrong: TextStyle.lerp(bodyStrong, other.bodyStrong, t)!,
      bodyRich: TextStyle.lerp(bodyRich, other.bodyRich, t)!,
      secondary: TextStyle.lerp(secondary, other.secondary, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      mono: TextStyle.lerp(mono, other.mono, t)!,
    );
  }
}
