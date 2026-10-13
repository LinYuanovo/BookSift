import 'package:flutter/widgets.dart';

/// Material 3 窗口尺寸类（自适应骨架断点）。
///
/// 边界裁决（设计系统 v1.4 §9.1 / 原型 §14.1）：`w < 600 → compact; w <= 1024 → medium; else expanded`。
/// **1024dp 归 medium**——iPad 横屏逻辑宽恰为 1024，标准 Rail（80dp）比 extended（256dp）
/// 多保留约 22% 内容宽（QA ISSUE-1）。
enum WindowSizeClass {
  /// < 600dp：手机竖屏。
  compact,

  /// 600–1024dp（**含 1024**）：小平板/折叠屏展开/桌面窄窗。
  medium,

  /// > 1024dp：平板横屏/桌面宽屏。
  expanded,
}

/// 断点 token 与宽屏内容约束。
abstract final class WindowSize {
  /// compact / medium 分界：600dp（含 600 归 medium）。
  static const double mediumMinWidth = 600;

  /// medium / expanded 分界：1024dp（**含 1024 归 medium**，>1024 才是 expanded）。
  static const double expandedMinWidth = 1024;

  /// expanded 下阅读列最大宽度：内容 ≤720dp 居中，防超长行损害可读性。
  static const double maxContentWidth = 720;

  static WindowSizeClass fromWidth(double width) {
    if (width < mediumMinWidth) {
      return WindowSizeClass.compact;
    }
    if (width <= expandedMinWidth) {
      return WindowSizeClass.medium;
    }
    return WindowSizeClass.expanded;
  }

  /// 便捷读取（整窗宽度）；shell 内改用 LayoutBuilder 约束宽度判断，以兼容分屏/嵌入场景。
  static WindowSizeClass of(BuildContext context) => fromWidth(MediaQuery.sizeOf(context).width);
}

/// 阅读列约束容器：宽屏下内容按 [maxWidth]（默认 [WindowSize.maxContentWidth]）居中，窄于上限时占满。
class ConstrainedContent extends StatelessWidget {
  const ConstrainedContent({super.key, this.maxWidth = WindowSize.maxContentWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
    );
  }
}
