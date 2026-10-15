import 'package:flutter/material.dart';

import '../../core/icons.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 按钮变体（设计稿 `.btn` 族，index.html:315–333）。
enum CollectButtonKind {
  /// `.btn-accent`：accent 底 + on-accent 字 + 600（index.html:324）。
  accent,

  /// `.btn-danger-soft`：danger-soft 底 + danger 字 + 600（index.html:330）。
  dangerSoft,

  /// `.btn-outline`：1px border-strong 描边透明底（index.html:326）。
  outline,
}

/// 采集中心按钮（h48 r14 / btn-sm h40；`.btn-block` 全宽；disabled opacity .4，index.html:332）。
class CollectButton extends StatelessWidget {
  const CollectButton({
    super.key,
    required this.label,
    this.onPressed,
    this.kind = CollectButtonKind.accent,
    this.block = false,
    this.small = false,
    this.iconName,
  });

  final String label;
  final VoidCallback? onPressed;
  final CollectButtonKind kind;

  /// `.btn-block{width:100%}`（index.html:333）。
  final bool block;

  /// `.btn-sm`：h40 · padding 0 space-5 · 13.5px（index.html:331）。
  final bool small;

  /// 可选前缀图标（symbol 名，16px；§5.9 '▶ 立即采集'）。
  final String? iconName;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final (Color? bg, Color fg, BoxBorder? border) = switch (kind) {
      CollectButtonKind.accent => (c.accent, c.onAccent, null),
      CollectButtonKind.dangerSoft => (c.dangerSoft, c.danger, null),
      CollectButtonKind.outline => (null, c.text, Border.all(color: c.borderStrong, width: AppMetrics.hairline)),
    };
    final bool enabled = onPressed != null;
    final TextStyle textStyle = (small ? t.secondary : t.bodyStrong).copyWith(
      color: fg,
      fontWeight: kind == CollectButtonKind.outline ? FontWeight.w500 : FontWeight.w600,
      letterSpacing: 0.3, // index.html:318 `.btn{letter-spacing:.02em}`（15px × .02）
    );
    final Widget content = Container(
      height: small ? AppMetrics.buttonHeightSmall : AppMetrics.buttonHeight,
      padding: EdgeInsets.symmetric(horizontal: small ? s.buttonSmallPaddingH : s.buttonPaddingH),
      decoration: BoxDecoration(borderRadius: AppRadius.mdBorder, border: border),
      // 居中由 Row（min 裹内容 / max 全宽）+ 固定高度内 crossAxisAlignment.center 承担；
      // 不得用 Container.alignment —— 其会把非 block 按钮膨胀到整宽（设计 btn 裹内容）。
      child: Row(
        mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (iconName != null) ...<Widget>[
            AppIcon(iconName!, size: 16, color: fg),
            SizedBox(width: s.space2),
          ],
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: textStyle)),
        ],
      ),
    );
    final Widget ink = bg == null
        ? Material(
            type: MaterialType.transparency,
            child: InkWell(onTap: onPressed, borderRadius: AppRadius.mdBorder, child: content),
          )
        : Material(
            color: bg,
            borderRadius: AppRadius.mdBorder,
            child: InkWell(onTap: onPressed, borderRadius: AppRadius.mdBorder, child: content),
          );
    final Widget sized = block ? SizedBox(width: double.infinity, child: ink) : ink;
    // `.btn[disabled]{opacity:.4;pointer-events:none}`（index.html:332）。
    return enabled ? sized : Opacity(opacity: 0.4, child: sized);
  }
}
