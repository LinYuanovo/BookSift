import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AppSpacing spacing = AppSpacing.of(context);
    final AppTypography typography = AppTypography.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(
        title,
        style: typography.headline.copyWith(color: colors.text),
      ),
      titlePadding: EdgeInsets.all(spacing.cardPadding),
      contentPadding: EdgeInsets.fromLTRB(
        spacing.cardPadding,
        0,
        spacing.cardPadding,
        spacing.space4,
      ),
      actionsPadding: EdgeInsets.fromLTRB(
        spacing.cardPadding,
        0,
        spacing.cardPadding,
        spacing.cardPadding,
      ),
      content: SizedBox(
        width: AppMetrics.contentDialogWidth,
        child: DefaultTextStyle(
          style: typography.body.copyWith(color: colors.textSecondary),
          child: content,
        ),
      ),
      actions: <Widget>[
        Wrap(
          alignment: WrapAlignment.end,
          spacing: spacing.space2,
          runSpacing: spacing.space2,
          children: actions,
        ),
      ],
    );
  }
}
