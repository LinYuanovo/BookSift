import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// 全仓结构图标单一出口（M2-①）。
///
/// 资产：`assets/icons/*.svg`，提取自设计稿 `work/ui_design/claude/index.html` 的
/// `<symbol>` sprite（设计规范 §图标：stroke 1.7 线性 / xs 档 stroke 2，viewBox 24）。
/// 双档文件：`name.svg`（stroke 1.7）与 `name-s.svg`（stroke 2，供 13px 及以下小尺寸，
/// 对应设计 `.ic.xs{width:13px;stroke-width:2}` index.html:138）。
///
/// 尺寸档位（设计规范 v1.1 §阴影/描边/图标统一策略）：24（导航）/ 20（base）/ 16（sm）/ 13（xs）。
/// 原始 SVG 为纯黑 stroke，运行时用 [ColorFilter] sourceIn 染色到语义色 token。
class AppIcon extends StatelessWidget {
  const AppIcon(this.name, {super.key, this.size = 20, this.color});

  /// symbol 名（不带 `i-` 前缀 / 不带扩展名），如 `home`、`check`、`clock`。
  final String name;

  /// 边长（设计档位 24/20/16/13；≤13 自动选 `-s` stroke2 变体）。
  final double size;

  /// 染色；null 时回退环境 IconTheme 色，再回退主文字色 token。
  final Color? color;

  /// 解析出的资产路径（13px 及以下 → stroke2 的 `-s` 档，index.html:138）。
  String get assetName => 'assets/icons/${size <= 13 ? '$name-s' : name}.svg';

  @override
  Widget build(BuildContext context) {
    final Color resolved = color ?? IconTheme.of(context).color ?? AppColors.of(context).text;
    return SvgPicture.asset(
      assetName,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(resolved, BlendMode.srcIn),
    );
  }
}
