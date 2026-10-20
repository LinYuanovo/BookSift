import 'package:flutter/material.dart';

/// 桌面端滚动行为：关闭框架自动叠加的桌面 [Scrollbar]。
///
/// 根因：Flutter 的 [Scrollable] 在桌面平台（`TargetPlatform.windows` / linux /
/// macOS）的**竖直**滚动视图上会自动包一层框架 [Scrollbar]
/// （见 flutter/lib/src/widgets/scrollable.dart `_configuration.buildScrollbar(...)`
/// 与 flutter/lib/src/material/app.dart `MaterialScrollBehavior.buildScrollbar`），
/// 与本项目 [ScrollChrome] 自绘的 4px 细滚动条叠加 → Windows 上出现两条滚动条。
///
/// 覆写 `buildScrollbar` 直接返回 child，只关掉「框架自动加的那条」，
/// 保留 [ScrollChrome] 自带的一条。Android/iOS 本来就不加桌面滚动条，
/// 本覆写不改变其行为（`MaterialScrollBehavior` 在移动端同样直接返回 child）。
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
}
