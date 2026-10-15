import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../icons.dart';

/// 滚动套装：可滚动区域的统一增强外壳。
///
/// - 常驻细滚动条（可拖拽，内容不可滚动时自动隐藏）；
/// - 右侧悬浮「跳到顶部 / 跳到底部」按钮：**滚动中显示，停留约 1.6s 后隐藏**
///   （此处停留时长是输入时序参数而非动效 token，与 search_state.suggestDebounce 同口径）。
///
/// 用法（调用方持有同一个 [ScrollController] 并传给内部滚动组件）：
/// ```dart
/// final ScrollController controller = ScrollController();
/// ScrollChrome(
///   controller: controller,
///   child: ListView(controller: controller, ...),
/// )
/// ```
class ScrollChrome extends StatefulWidget {
  const ScrollChrome({
    super.key,
    required this.controller,
    required this.child,
    this.scrollbar = true,
    this.jumpButtons = true,
  });

  /// 与内部滚动组件共享的控制器。
  final ScrollController controller;
  final Widget child;

  /// 是否显示常驻滚动条。
  final bool scrollbar;

  /// 是否显示跳顶/跳底悬浮按钮。
  final bool jumpButtons;

  @override
  State<ScrollChrome> createState() => _ScrollChromeState();
}

class _ScrollChromeState extends State<ScrollChrome> {
  /// 停留隐藏计时（输入时序参数，非动效 token）。
  static const Duration _idleHide = Duration(milliseconds: 1600);

  bool _canScroll = false;
  bool _jumpVisible = false;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  bool _handleNotification(ScrollNotification n) {
    final bool canScroll = n.metrics.maxScrollExtent > 0;
    if (canScroll != _canScroll) {
      setState(() => _canScroll = canScroll);
      if (!canScroll) return false;
    }
    if (canScroll && (n is ScrollStartNotification || n is ScrollUpdateNotification)) {
      _showJumpTemporarily();
    }
    return false;
  }

  void _showJumpTemporarily() {
    if (!_jumpVisible) {
      setState(() => _jumpVisible = true);
    }
    _hideTimer?.cancel();
    _hideTimer = Timer(_idleHide, () {
      if (mounted) {
        setState(() => _jumpVisible = false);
      }
    });
  }

  void _jumpTo(double offset) {
    final AppMotionTheme motion = AppMotionTheme.of(context);
    widget.controller.animateTo(
      offset,
      duration: motion.slow,
      curve: motion.emphasize,
    );
    _showJumpTemporarily();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final AppMotionTheme motion = AppMotionTheme.of(context);
    Widget child = widget.child;
    if (widget.scrollbar) {
      child = Scrollbar(
        controller: widget.controller,
        interactive: true,
        thumbVisibility: _canScroll,
        thickness: 4,
        radius: const Radius.circular(AppRadius.pill),
        child: child,
      );
    }
    child = NotificationListener<ScrollNotification>(
      onNotification: _handleNotification,
      child: child,
    );
    if (!widget.jumpButtons) {
      return child;
    }
    return Stack(
      children: <Widget>[
        child,
        Positioned(
          right: s.space2,
          bottom: s.space8,
          child: AnimatedOpacity(
            opacity: _jumpVisible ? 1 : 0,
            duration: motion.fast,
            curve: motion.standard,
            child: IgnorePointer(
              ignoring: !_jumpVisible,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _JumpButton(
                    tooltip: '跳到顶部',
                    onTap: () => _jumpTo(0),
                    icon: RotatedBox(
                      quarterTurns: 2,
                      child: AppIcon('chev', size: 20, color: c.textSecondary),
                    ),
                  ),
                  SizedBox(height: s.space2),
                  _JumpButton(
                    tooltip: '跳到底部',
                    onTap: () => _jumpTo(widget.controller.position.maxScrollExtent),
                    icon: AppIcon('chev', size: 20, color: c.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 圆形悬浮按钮（44px 触控目标，surface 底 + 发丝描边 + 浮层阴影 token）。
class _JumpButton extends StatelessWidget {
  const _JumpButton({required this.tooltip, required this.onTap, required this.icon});

  final String tooltip;
  final VoidCallback onTap;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: c.shadowOverlay,
              offset: const Offset(0, AppMetrics.shadowOverlayOffsetY),
              blurRadius: AppMetrics.shadowOverlayBlur,
            ),
          ],
        ),
        child: Material(
          color: c.surface,
          shape: CircleBorder(side: BorderSide(color: c.border, width: AppMetrics.hairline)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: AppMetrics.minTouchTarget,
              height: AppMetrics.minTouchTarget,
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );
  }
}
