import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// 间距 token（4/8 体系）。
///
/// 出处：`docs/设计系统-Claude-v1.2.md` §2.3：`--space-1..12` = 4/8/12/16/20/24/32/40/48；
/// v1.1 使用节奏（token 值不变、使用档位抬高）见下方派生 getter。
@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  const AppSpacing({
    required this.space1,
    required this.space2,
    required this.space3,
    required this.space4,
    required this.space5,
    required this.space6,
    required this.space8,
    required this.space10,
    required this.space12,
  });

  final double space1; // 4
  final double space2; // 8
  final double space3; // 12
  final double space4; // 16
  final double space5; // 20
  final double space6; // 24
  final double space8; // 32
  final double space10; // 40
  final double space12; // 48

  static const AppSpacing standard = AppSpacing(
    space1: 4,
    space2: 8,
    space3: 12,
    space4: 16,
    space5: 20,
    space6: 24,
    space8: 32,
    space10: 40,
    space12: 48,
  );

  // ── v1.1 使用节奏（§2.3 节奏表，全部由上方 token 派生，不新增散值）──

  /// 页面水平 padding 20。
  double get pagePadding => space5;

  /// 卡片内 padding 20。
  double get cardPadding => space5;

  /// 卡片之间 gap 16。
  double get cardGap => space4;

  /// section（sec-title）上间距 32。
  double get sectionGap => space8;

  /// chip 之间 gap 12。
  double get chipGap => space3;

  /// chip 行 padding 8。
  double get chipRowPadding => space2;

  /// 日期分组头 上 24。
  double get groupHeaderTop => space6;

  /// 日期分组头 下 12。
  double get groupHeaderBottom => space3;

  /// 按钮水平 padding 24。
  double get buttonPaddingH => space6;

  /// btn-sm 水平 padding 20。
  double get buttonSmallPaddingH => space5;

  /// 输入框水平 padding 20。
  double get inputPaddingH => space5;

  /// 空态容器垂直 padding 40。
  double get emptyStatePaddingV => space10;

  /// 空态容器水平 padding 24。
  double get emptyStatePaddingH => space6;

  static AppSpacing of(BuildContext context) => Theme.of(context).extension<AppSpacing>()!;

  @override
  AppSpacing copyWith({
    double? space1,
    double? space2,
    double? space3,
    double? space4,
    double? space5,
    double? space6,
    double? space8,
    double? space10,
    double? space12,
  }) {
    return AppSpacing(
      space1: space1 ?? this.space1,
      space2: space2 ?? this.space2,
      space3: space3 ?? this.space3,
      space4: space4 ?? this.space4,
      space5: space5 ?? this.space5,
      space6: space6 ?? this.space6,
      space8: space8 ?? this.space8,
      space10: space10 ?? this.space10,
      space12: space12 ?? this.space12,
    );
  }

  @override
  AppSpacing lerp(covariant AppSpacing? other, double t) {
    if (other == null) {
      return this;
    }
    return AppSpacing(
      space1: lerpDouble(space1, other.space1, t)!,
      space2: lerpDouble(space2, other.space2, t)!,
      space3: lerpDouble(space3, other.space3, t)!,
      space4: lerpDouble(space4, other.space4, t)!,
      space5: lerpDouble(space5, other.space5, t)!,
      space6: lerpDouble(space6, other.space6, t)!,
      space8: lerpDouble(space8, other.space8, t)!,
      space10: lerpDouble(space10, other.space10, t)!,
      space12: lerpDouble(space12, other.space12, t)!,
    );
  }
}

/// 组件级固定尺寸（不随明暗/密度变化）。
///
/// 出处：§2.3 v1.1 节奏表（行高/AppBar/底导航）、§4 组件规格、§7.2 触控下限。
abstract final class AppMetrics {
  /// 发丝线/描边全稿统一 1px（§4；focus ring 3px 为状态表达例外）。
  static const double hairline = 1;

  /// 主交互触控目标下限 44px（§7.2）。
  static const double minTouchTarget = 44;

  static const double appBarHeight = 60; // §2.3
  static const double bottomNavHeight = 88; // §2.3（含 home indicator 区）
  static const double navItemHeight = 56; // §2.3 导航项命中
  static const double listRowHeight = 60; // §2.3 row/hist-row
  static const double suggestionRowHeight = 52; // §2.3 sg 联想行
  static const double buttonHeight = 48; // §4 btn
  static const double buttonHeightSmall = 40; // §4 btn-sm
  static const double chipHeight = 44; // §4 筛选 chip
  static const double chipHeightCompact = 36; // §4 compact chip
  static const double bookChipHeight = 32; // §4 书名 chip
  static const double bookChipHeightBig = 40; // §4 chip-book.big
  static const double inputHeight = 48; // §4 field/searchbar
  static const double badgeHeight = 24; // §4 badge
  static const double switchWidth = 52; // §4 switch
  static const double switchHeight = 32; // §4 switch
  static const double accordionHeaderHeight = 60; // §4 手风琴组头（MI-8）
  static const double rankRowMinHeight = 64; // §4 榜单行
  static const double emptyStateIconSize = 64; // §4 空态线稿插画 64px

  /// 目录类底部弹层的高度上限系数（× 屏幕可用高度）：isScrollControlled 的弹层默认
  /// 可铺满全屏，长目录会顶到状态栏、丢掉「这是一层浮层」的视觉线索；短目录仍按内容收缩。
  static const double tocSheetHeightFactor = 0.7;

  /// 随机书荒面板固定高度系数（× 屏幕可用高度）。不随内容、不随拖拽变化。
  static const double randomSheetHeightFactor = 0.7;

  /// `--shadow-overlay` 几何：0 12px 32px（§2.1，仅浮层 Toast/Snackbar/弹层使用）。
  static const double shadowOverlayOffsetY = 12;
  static const double shadowOverlayBlur = 32;
}
