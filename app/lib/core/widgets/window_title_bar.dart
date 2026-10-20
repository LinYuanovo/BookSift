import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../constants.dart';
import '../icons.dart';
import '../window/window_frame.dart';

/// 自绘标题栏（Windows）：窗口顶部条走 App 的 design token，替掉系统原生标题栏。
///
/// 分工（见 core/window/window_frame.dart）：
/// - 拖动区（标题栏左侧到按钮簇之前）由 runner 判成 HTCAPTION → 拖动 / 双击最大化 /
///   右键系统菜单全交给系统，本组件不接这些指针事件；
/// - 右侧按钮簇（[WindowFrameMetrics.captionButtonsWidth] 宽）留 HTCLIENT →
///   点按与悬停反馈都在这儿做，动作经 `booksift/window` 通道落到原生窗口。
class WindowTitleBar extends StatelessWidget {
  const WindowTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    return Container(
      height: WindowFrameMetrics.titleBarHeight,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border, width: AppMetrics.hairline)),
      ),
      // 本组件挂在 Navigator 之上（MaterialApp.builder）：既没有 Material 祖先，也就
      // 会拿到 MaterialApp 的兜底 DefaultTextStyle（monospace / w900 / 黄色双下划线）——
      // 必须自带 DefaultTextStyle，否则应用名会被画成黄下划线的等宽粗体。
      child: DefaultTextStyle(
        style: t.caption.copyWith(color: c.textSecondary, fontWeight: FontWeight.w600),
        child: Row(
          children: <Widget>[
            SizedBox(width: s.space3),
            // 品牌标记：与导航栏 rail-mark 同语义（accent 线稿 + 应用名）。
            AppIcon('book', size: 16, color: c.accent),
            SizedBox(width: s.space2),
            Text(AppConstants.appName),
            const Spacer(),
            _WindowButton(tooltip: '最小化', svgIcon: 'minus', onTap: WindowFrame.minimize),
            ValueListenableBuilder<bool>(
              valueListenable: WindowFrame.maximized,
              builder: (BuildContext context, bool maximized, Widget? child) => _WindowButton(
                tooltip: maximized ? '向下还原' : '最大化',
                svgIcon: maximized ? 'restore' : 'maximize',
                onTap: WindowFrame.toggleMaximize,
              ),
            ),
            _WindowButton(
              tooltip: '关闭',
              svgIcon: 'close',
              danger: true,
              onTap: WindowFrame.close,
            ),
          ],
        ),
      ),
    );
  }
}

/// 单颗窗口控制钮（46×36 固定格，悬停底色走 token；关闭档用 danger 语义）。
class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.tooltip,
    required this.svgIcon,
    required this.onTap,
    this.danger = false,
  });

  final String tooltip;
  final String svgIcon;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppMotionTheme motion = AppMotionTheme.of(context);
    // 常态透明底：用 token 的 0 透明（主题目录外禁止硬编码色值，见 theme_tokens_test）。
    final Color background = !_hover
        ? c.surfaceSunken.withValues(alpha: 0)
        : (widget.danger ? c.dangerSoft : c.surfaceSunken);
    final Color foreground = widget.danger
        ? (_hover ? c.danger : c.textSecondary)
        : (_hover ? c.text : c.textSecondary);
    // 不挂 Tooltip：本组件挂在 MaterialApp.builder 里（Navigator 之上）→ 没有 Overlay
    // 祖先，RawTooltip 会直接断言失败（app_shell 测试实测）。窗口按钮是通用图形，
    // 语义名交给 Semantics（读屏仍能报「最小化/最大化/关闭」）。
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: SizedBox(
            width: WindowFrameMetrics.captionButtonWidth,
            height: WindowFrameMetrics.titleBarHeight,
            child: AnimatedContainer(
              duration: motion.instant,
              curve: motion.standard,
              color: background,
              child: Center(child: AppIcon(widget.svgIcon, size: 16, color: foreground)),
            ),
          ),
        ),
      ),
    );
  }
}
