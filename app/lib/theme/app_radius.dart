import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 圆角 token（v1.1 收敛抬下限：sm10 / md14 / lg20 / xl24 / pill）。
///
/// 出处：`docs/设计系统-Claude-v1.2.md` §2.4。组件 → 圆角映射（同类同档）：
/// - lg20：卡片族（card/group-card/suggest/entry-tile/notice-card/logbox/watermark/stat-grid/空态外包）、手风琴容器与组头、榜单行 rank-row
/// - md14：按钮族（btn/btn-sm/actionbar act）、Snackbar、图片缩略图 thumb、骨架头像
/// - xl24：输入族（field 三态 / searchbar）
/// - pill：chip 全系（含书名 chip/快照标签/meta-chip）、徽标、seg、switch、nav 胶囊、Toast、进度轨
/// - sm10：骨架默认块、小色块（sw 格/tk-bar/kbd）
abstract final class AppRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 999;

  static const BorderRadius smBorder = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdBorder = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgBorder = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlBorder = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillBorder = BorderRadius.all(Radius.circular(pill));

  /// 同心圆角 helper（§2.4 同心圆角规则）：独立浮于容器内部的贴边元素，
  /// 内层圆角 = 外层圆角 − 贴边间距，下限 0；贴边满幅子元素优先靠外层
  /// `clipBehavior: Clip.antiAlias` 裁切自动同心（见 BookTheme.cardTheme），不另设圆角。
  static double innerRadius(double outer, double padding) => math.max(outer - padding, 0);

  /// [innerRadius] 的 BorderRadius 便捷构造。
  static BorderRadius innerBorderRadius(double outer, double padding) =>
      BorderRadius.all(Radius.circular(innerRadius(outer, padding)));
}
