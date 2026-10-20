import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import 'page_transition.dart';

// 中间功能区页面栈（用户口径：书聚合页 / 设置 / 关于 / 热门榜 / 在线帖 等
// 「单独弹出的页面」在 expanded 三栏下不再盖住整窗，直接显示在**中间功能区**）。
//
// 实现：expanded 时 AppShell 在中间栏里叠一个嵌套 [Navigator]（app_shell.dart
// _CenterPane），本文件负责它的键、压栈工厂与「回根」出口。compact/medium 没有中间栏，
// [openCenterPage] 自动退化为全窗 push（与旧 go_router push 观感一致）。

/// 中间功能区嵌套 Navigator 的键；`currentState != null` 即「中间栏在场」。
///
/// 只由 app_shell.dart 挂载，其余代码只读（判在场 / 压栈 / 回根）。
final GlobalKey<NavigatorState> centerSlotNavigatorKey = GlobalKey<NavigatorState>();

/// 中间功能区是否在场（expanded 三栏骨架已挂载）。
bool centerSlotMounted() => centerSlotNavigatorKey.currentState != null;

/// 打开一个页面：中间栏在场 → 压入中间功能区；否则全窗显示（compact/medium 原行为）。
///
/// [type] 沿用各路由原有的 SharedAxis 语义：设置/关于/热门榜 = vertical（父→子），
/// 书聚合页/在线帖 = horizontal（列表→详情）。转场时长走 motion token，不碰裸值。
///
/// [fullScreen]：窄屏档要保留**原路由**语义（/book/:id、/online/:id 这类可回溯 URL）时传入，
/// 例如 `() => context.push('/book/$id', extra: args)`；不传则退化为直接 `Navigator.push`
/// 同一个页面 widget（观感一致，只是不走路由表）。
void openCenterPage(
  BuildContext context,
  Widget page, {
  SharedAxisTransitionType type = SharedAxisTransitionType.vertical,
  VoidCallback? fullScreen,
}) {
  final NavigatorState? center = centerSlotNavigatorKey.currentState;
  if (center != null) {
    center.push(_centerRoute(context, page, type));
    return;
  }
  if (fullScreen != null) {
    fullScreen();
    return;
  }
  Navigator.of(context).push(_centerRoute(context, page, type));
}

/// 中间栈回到根（离开当前页）：切 Tab / 换搜索条件等「换页」时机由 AppShell 调。
void popCenterToRoot() {
  centerSlotNavigatorKey.currentState?.popUntil((Route<dynamic> r) => r.isFirst);
}

/// 页面工厂：与 app_router.dart `_sharedAxisPage` 同族转场，独立成路由后
/// 页内 `Navigator.maybePop()` / AppBar 返回钮天然可用。
Route<void> _centerRoute(
  BuildContext context,
  Widget page,
  SharedAxisTransitionType type,
) {
  return MotionPage<void>(child: page, type: type).createRoute(context);
}
