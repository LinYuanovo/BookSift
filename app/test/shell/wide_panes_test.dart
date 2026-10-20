import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/features/home/home_page.dart';
import 'package:booksift/features/profile/settings_page.dart';

import '../support/fake_book_repository.dart';
import '../support/harness.dart';

// 宽屏三栏「功能区」（用户口径）：
//   ① 三块功能区可**长按拖动**分隔条改占比；左侧功能区底部有收起 / 展开按钮；
//   ② 书聚合页 / 设置 / 关于 / 热门榜等页面不再全窗弹出，直接在**中间功能区**显示
//      （core/nav/center_slot.dart + AppShell 嵌套 Navigator）。
//
// 全部 testWidgets 零真实 IO（FakeBookRepository + harness 三哨兵，app/test/TESTING.md §3.1）。

/// 长按后拖动（分隔条只认长按手势：先按住 500ms 让 LongPress 成立，再位移）。
Future<void> longPressDrag(WidgetTester tester, Finder target, double dx) async {
  final TestGesture gesture = await tester.startGesture(tester.getCenter(target));
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.moveBy(Offset(dx, 0));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

/// 造一只测试鼠标（整条用例共用一个指针：TestPointer 对 mouse 恒用 device=1，
/// 同一用例里二次 addPointer 会触发 MouseTracker「Added 只能跟在 Removed 之后」断言）。
Future<TestGesture> createTestMouse(WidgetTester tester) async {
  final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  return mouse;
}

/// 鼠标拖动（桌面手感：按下即拖，不需要长按）——用于验证「方向跟手」。
Future<void> mouseDrag(WidgetTester tester, TestGesture mouse, Finder target, double dx) async {
  final Offset start = tester.getCenter(target);
  await mouse.moveTo(start); // hover 到分隔条（真实鼠标的进区动作）
  await tester.pump(const Duration(milliseconds: 16));
  await mouse.down(start);
  await tester.pump(const Duration(milliseconds: 16));
  const int steps = 6;
  for (int i = 0; i < steps; i++) {
    await mouse.moveBy(Offset(dx / steps, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await mouse.up();
  await tester.pumpAndSettle();
}

double railWidth(WidgetTester tester) => tester.getSize(find.byType(NavigationRail)).width;

double centerPaneWidth(WidgetTester tester) => tester.getSize(find.byType(HomePage)).width;

void main() {
  late FakeBookRepository repo;

  setUp(() => repo = FakeBookRepository());

  testWidgets('expanded：三栏就位，长按拖分隔条改导航栏宽度与详情栏占比', (WidgetTester tester) async {
    useSurface(tester, width: 1440, height: 900);
    await tester.pumpWidget(testApp(repo));
    await tester.pumpAndSettle();

    expect(railWidth(tester), 256, reason: 'extended Rail 展开宽');
    expect(find.text('选择左侧内容查看详情'), findsOneWidget, reason: '右侧详情槽常驻');
    final double center0 = centerPaneWidth(tester);

    // ① 拖导航栏分隔条：向右 60 → 导航栏宽 +60，中间功能区随之变窄（详情栏按比例分余量）。
    await longPressDrag(tester, find.byTooltip('拖动 · 调整导航栏宽度'), 60);
    expect(railWidth(tester), closeTo(316, 1));
    expect(centerPaneWidth(tester), lessThan(center0));

    // ② 拖中间 / 详情分隔条：分隔条**跟手** —— 向左 120 = 分隔条左移 120 = 详情栏变宽 120、
    //    中间功能区等量变窄（用户反馈修正：旧实现与指针反向）。
    final double center1 = centerPaneWidth(tester);
    final double splitter1 = tester.getCenter(find.byTooltip('拖动 · 调整详情栏占比')).dx;
    await longPressDrag(tester, find.byTooltip('拖动 · 调整详情栏占比'), -120);
    expect(tester.getCenter(find.byTooltip('拖动 · 调整详情栏占比')).dx, closeTo(splitter1 - 120, 2),
        reason: '分隔条跟着指针走（左拖 = 左移）');
    expect(centerPaneWidth(tester), closeTo(center1 - 120, 2), reason: '详情栏变宽 → 中间功能区等量变窄');

    // ③ 左侧功能区底部收起 / 展开钮。
    await tester.tap(find.byTooltip('收起导航栏'));
    await tester.pumpAndSettle();
    expect(railWidth(tester), 72);
    expect(find.byType(NavigationRail), findsOneWidget, reason: '收起只是变窄，不是隐藏');
    await tester.tap(find.byTooltip('展开导航栏'));
    await tester.pumpAndSettle();
    expect(railWidth(tester), closeTo(316, 1), reason: '展开回到收起前的宽度');
  });

  testWidgets('expanded：设置页在中间功能区原位显示（左导航与右详情槽保持可见）', (WidgetTester tester) async {
    useSurface(tester, width: 1440, height: 900);
    await tester.pumpWidget(testApp(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget, reason: '不再盖住整窗：左导航仍在');
    expect(find.text('选择左侧内容查看详情'), findsOneWidget, reason: '右详情槽仍在');
    // 页面在中间栏内：宽度明显窄于整窗（1440 - 256 导航 - 详情栏）。
    expect(tester.getSize(find.byType(SettingsPage)).width, lessThan(900));

    // 中间栈的返回钮（AppBar 自动返回）退栈 → 回到 Tab 内容。
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('鼠标按下即拖：分隔条跟手（导航栏左拖变窄 / 详情栏左拖变宽）', (WidgetTester tester) async {
    useSurface(tester, width: 1440, height: 900);
    await tester.pumpWidget(testApp(repo));
    await tester.pumpAndSettle();
    final double rail0 = railWidth(tester);
    final double center0 = centerPaneWidth(tester);
    final TestGesture mouse = await createTestMouse(tester);

    // 导航栏分隔条：右拖 +60 → 变宽 60；再左拖 -60 → 回到原宽。
    await mouseDrag(tester, mouse, find.byTooltip('拖动 · 调整导航栏宽度'), 60);
    expect(railWidth(tester), closeTo(rail0 + 60, 1.5), reason: '指针向右 → 分隔条向右（导航栏变宽）');
    await mouseDrag(tester, mouse, find.byTooltip('拖动 · 调整导航栏宽度'), -60);
    expect(railWidth(tester), closeTo(rail0, 1.5), reason: '指针向左 → 分隔条向左（导航栏变窄）');

    // 中间 | 详情分隔条：左拖 -120 → 分隔条左移 120 = 详情栏变宽 120（与左导航那条反向，
    // 因为详情栏在分隔条右侧）。
    final double splitter0 = tester.getCenter(find.byTooltip('拖动 · 调整详情栏占比')).dx;
    await mouseDrag(tester, mouse, find.byTooltip('拖动 · 调整详情栏占比'), -120);
    expect(tester.getCenter(find.byTooltip('拖动 · 调整详情栏占比')).dx, closeTo(splitter0 - 120, 2),
        reason: '指针向左 → 分隔条向左（跟手）');
    expect(centerPaneWidth(tester), closeTo(center0 - 120, 2), reason: '详情栏变宽 → 中间栏等量变窄');
    await mouseDrag(tester, mouse, find.byTooltip('拖动 · 调整详情栏占比'), 120);
    expect(tester.getCenter(find.byTooltip('拖动 · 调整详情栏占比')).dx, closeTo(splitter0, 2),
        reason: '指针向右 → 分隔条向右（回到原位）');
    expect(centerPaneWidth(tester), closeTo(center0, 2), reason: '中间栏回到原宽');
  });

  testWidgets('compact：同一入口仍是全窗页（无中间栏，行为不变）', (WidgetTester tester) async {
    useSurface(tester, width: 390, height: 844);
    await tester.pumpWidget(testApp(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.getSize(find.byType(SettingsPage)).width, 390);
  });
}
