import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/icons.dart';
import 'package:booksift/features/collect/collect_page.dart';

import '../support/fake_book_repository.dart';
import '../support/fake_collect.dart';
import '../support/harness.dart';

// reduceMotion 收敛 / 调试演示态注入 / AppIcon 档位守卫 / 导航图标 SVG 化。

void main() {
  late FakeBookRepository repo;

  setUp(() => repo = FakeBookRepository());

  testWidgets('reduceMotion：active 脉冲关闭 → pumpAndSettle 可收敛（§6.8）', (WidgetTester tester) async {
    useSurface(tester, height: 1700);
    await tester.pumpWidget(
      testApp(
        repo,
        home: Builder(
          builder: (BuildContext context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const CollectPage(),
          ),
        ),
        extraOverrides: collectTestOverrides(
          notifier: FakeCollectRunNotifier(initial: demoRunState()),
        ),
      ),
    );
    // 关键断言：常规态会因 pulseRing 无限动画挂死；reduceMotion 通道必须能 settle。
    await tester.pumpAndSettle();
    expect(find.text('68%'), findsOneWidget);
    expect(find.text('② 解析楼层 + 分类'), findsOneWidget);
  });

  testWidgets('调试演示态：长按「匿名模式」徽标注入设计稿快照，取消退出（kDebugMode 限定）', (WidgetTester tester) async {
    useSurface(tester, height: 1400);
    final FakeCollectRunNotifier fake = FakeCollectRunNotifier(); // 真实态 = idle
    await tester.pumpWidget(
      testApp(repo, home: const CollectPage(), extraOverrides: collectTestOverrides(notifier: fake)),
    );
    await tester.pump();
    await tester.pump();
    // 空闲态起点。
    expect(find.text('立即采集（预计2分钟）'), findsOneWidget);

    await tester.longPress(find.byKey(const ValueKey<String>('collect-anon-badge')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    // 演示快照 = 设计稿 06 屏（68% / yy小说吧 / 哀伤雪刃冷却）。
    expect(find.text('68%'), findsOneWidget);
    expect(find.text('yy小说吧'), findsOneWidget);
    expect(find.textContaining('冷却中 48m', findRichText: true), findsOneWidget);

    // 演示态取消 = 退出演示回空闲，不触真实控制器。
    await tester.tap(find.text('取消采集（水位不推进）'));
    await tester.pump();
    await tester.pump();
    expect(find.text('立即采集（预计2分钟）'), findsOneWidget);
    expect(fake.cancelCalls, 0);
  });

  test('AppIcon 档位：≤13px 自动选 -s（stroke2）文件，24/20/16 用常规档', () {
    expect(const AppIcon('check', size: 12).assetName, 'assets/icons/check-s.svg');
    expect(const AppIcon('list', size: 13).assetName, 'assets/icons/list-s.svg');
    expect(const AppIcon('clock', size: 16).assetName, 'assets/icons/clock.svg');
    expect(const AppIcon('gear', size: 20).assetName, 'assets/icons/gear.svg');
    expect(const AppIcon('home', size: 24).assetName, 'assets/icons/home.svg');
  });

  testWidgets('图标守卫：底部导航 4 图标全为设计稿 SVG，NavigationBar 内零 Material Icon', (WidgetTester tester) async {
    useSurface(tester);
    await tester.pumpWidget(
      testApp(
        repo,
        initial: '/collect',
        extraOverrides: collectTestOverrides(notifier: FakeCollectRunNotifier()),
      ),
    );
    await tester.pump();
    await tester.pump();
    final Finder nav = find.byType(NavigationBar);
    expect(nav, findsOneWidget);
    // 4 Tab 图标 = 设计稿 SVG（NavigationBar 同一时刻每 destination 渲染一个 icon 实例）。
    expect(find.descendant(of: nav, matching: find.byType(SvgPicture)), findsWidgets);
    expect(find.descendant(of: nav, matching: find.byType(Icon)), findsNothing);
  });
}
