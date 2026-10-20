import 'package:flutter/material.dart';

import '../../core/icons.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class CollectStatusBanner extends StatelessWidget {
  const CollectStatusBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AppTypography typography = AppTypography.of(context);
    final AppSpacing spacing = AppSpacing.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: spacing.space4, vertical: spacing.space3),
      decoration: BoxDecoration(color: colors.dangerSoft, borderRadius: AppRadius.mdBorder),
      child: Row(
        children: <Widget>[
          AppIcon('alert', size: 18, color: colors.danger),
          SizedBox(width: spacing.space3),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(text, style: typography.secondary.copyWith(color: colors.danger)),
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedCollectStatusBanner extends StatelessWidget {
  const AnimatedCollectStatusBanner({
    super.key,
    required this.text,
    this.bottomSpacing = 0,
  });

  final String? text;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    final AppMotionTheme motion = AppMotionTheme.of(context);
    return AnimatedSwitcher(
      key: ValueKey<String>('collect-status-switcher-${motion.reduceMotion}'),
      duration: motion.fast,
      switchInCurve: motion.decelerate,
      switchOutCurve: motion.exit.curve,
      transitionBuilder: (Widget child, Animation<double> animation) {
        final Widget fade = FadeTransition(opacity: animation, child: child);
        if (motion.reduceMotion) return fade;
        return SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1,
          child: fade,
        );
      },
      child: text == null
          ? const SizedBox.shrink(key: ValueKey<String>('collect-status-empty'))
          : Padding(
              key: ValueKey<String>(text!),
              padding: EdgeInsets.only(bottom: bottomSpacing),
              child: CollectStatusBanner(text: text!),
            ),
    );
  }
}
