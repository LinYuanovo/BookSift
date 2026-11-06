import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.helper,
    this.obscureText = false,
    this.onSubmitted,
    this.action,
    this.textInputAction,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;
  final Widget? action;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AppSpacing spacing = AppSpacing.of(context);
    final AppTypography typography = AppTypography.of(context);
    final AppMotionTheme motion = AppMotionTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          widget.label,
          style: typography.secondary.copyWith(color: colors.textSecondary),
        ),
        SizedBox(height: spacing.space2),
        Focus(
          onFocusChange: (focused) => setState(() => _focused = focused),
          child: AnimatedContainer(
            duration: motion.fast,
            curve: motion.standard,
            constraints: const BoxConstraints(
              minHeight: AppMetrics.inputHeight,
            ),
            padding: EdgeInsets.symmetric(horizontal: spacing.inputPaddingH),
            decoration: BoxDecoration(
              color: colors.surfaceRaised,
              borderRadius: AppRadius.xlBorder,
              border: Border.all(
                color: _focused ? colors.accent : colors.borderStrong,
                width: AppMetrics.hairline,
              ),
              boxShadow: _focused
                  ? <BoxShadow>[
                      BoxShadow(
                        color: colors.accent.withValues(alpha: 0.18),
                        spreadRadius: 3,
                      ),
                    ]
                  : const <BoxShadow>[],
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    obscureText: widget.obscureText,
                    autocorrect: false,
                    enableSuggestions: !widget.obscureText,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    onSubmitted: widget.onSubmitted,
                    style: typography.body.copyWith(color: colors.text),
                    cursorColor: colors.accent,
                    decoration: InputDecoration(
                      hintText: widget.label,
                      hintStyle: typography.body.copyWith(
                        color: colors.textMuted,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: spacing.space2,
                      ),
                    ),
                  ),
                ),
                if (widget.action != null) ...<Widget>[
                  SizedBox(width: spacing.space2),
                  widget.action!,
                ],
              ],
            ),
          ),
        ),
        if (widget.helper != null) ...<Widget>[
          SizedBox(height: spacing.space2),
          Text(
            widget.helper!,
            style: typography.caption.copyWith(color: colors.textMuted),
          ),
        ],
      ],
    );
  }
}
