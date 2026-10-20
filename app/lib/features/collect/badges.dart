import 'package:flutter/material.dart';

import '../../core/icons.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 徽标变体（设计稿 `.badge` 六色映射，index.html:275–287）。
enum CollectBadgeVariant {
  /// 推荐/扫书（recommend-soft 底 + recommend 字）。
  rec,

  /// 排雷/冷却/失败（danger-soft 底 + danger 字）。
  avoid,

  /// 求书/中性弱标记（sunken 底 + muted 字）。
  ask,

  /// 类别/进行态（accent-soft 底 + accent-strong 字）。
  kind,

  /// 自采/匿名模式（recommend-soft 底 + recommend 字）。
  originSelf,

  /// 导入（info-soft 底 + info 字）。
  originImport,

  /// 内置（sunken 底 + secondary 字）。
  originBuiltin,
}

/// 通用徽标（h24 pill · 600 字 · padding 0 10，index.html:275–287）。
/// dtable 状态列用 [height] 20 的紧凑档（index.html:2892 内联 height:20px）。
class CollectBadge extends StatelessWidget {
  const CollectBadge({super.key, required this.label, required this.variant, this.height = 24});

  final String label;
  final CollectBadgeVariant variant;

  /// 24 = 常规（AppMetrics.badgeHeight 同值）；20 = dtable 状态列。
  final double height;

  (Color, Color) _colors(BuildContext context) {
    final AppColors c = AppColors.of(context);
    return switch (variant) {
      CollectBadgeVariant.rec => (c.recommendSoft, c.recommend),
      CollectBadgeVariant.avoid => (c.dangerSoft, c.danger),
      CollectBadgeVariant.ask => (c.surfaceSunken, c.textMuted),
      CollectBadgeVariant.kind => (c.accentSoft, c.accentStrong),
      CollectBadgeVariant.originSelf => (c.recommendSoft, c.recommend),
      CollectBadgeVariant.originImport => (c.infoSoft, c.info),
      CollectBadgeVariant.originBuiltin => (c.surfaceSunken, c.textSecondary),
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppTypography t = AppTypography.of(context);
    final (Color bg, Color fg) = _colors(context);
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10), // index.html:277 padding 0 10px
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.pillBorder),
      // 居中用 Center(factor 1) 而非 Container.alignment —— 后者在有界约束下膨胀到整宽。
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          label,
          style: t.label.copyWith(fontWeight: FontWeight.w600, color: fg, letterSpacing: 0),
        ),
      ),
    );
  }
}

/// 面板标题（`.panel-title`，index.html:912–914：label 字阶 + 13px stroke2 图标 +
/// letterSpacing .14em（token label 同值 1.54px）+ 发丝延伸线）。
class PanelTitle extends StatelessWidget {
  const PanelTitle({super.key, required this.label, required this.iconName, this.marginBottom});

  final String label;
  final String iconName;

  /// 缺省 space-3（index.html:912 margin-bottom:var(--space-3)）；dash 卡内按需 0/space-2。
  final double? marginBottom;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: marginBottom ?? s.space3),
      child: Row(
        children: <Widget>[
          // index.html:914 `.panel-title .ic{width:13px;stroke-width:2}` → AppIcon 13 自动 -s 档。
          AppIcon(iconName, size: 13, color: c.textMuted),
          SizedBox(width: s.space2),
          Text(label, style: t.label.copyWith(color: c.textMuted)),
          SizedBox(width: s.space2),
          Expanded(child: Container(height: AppMetrics.hairline, color: c.border)),
        ],
      ),
    );
  }
}
