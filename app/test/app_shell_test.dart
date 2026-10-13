import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saoshuhui/app.dart';

import 'support/fake_book_repository.dart';
import 'support/harness.dart';

// 自适应骨架三档形态（M1-②）。
//
// 全内存挂具：SaoshuhuiApp 会经 fontServiceProvider / queriesProvider 触到 drift 与
// path_provider（都是真实异步），在 testWidgets 假时钟区内必挂死；故一律用 harness.dart
// 的 overrides 注入 fake（见 app/test/TESTING.md §1/§3）。

Future<void> pumpShell(WidgetTester tester, FakeBookRepository repo, {required double width, required double height}) async {
  useSurface(tester, width: width, height: height);
  await tester.pumpWidget(ProviderScope(overrides: testOverrides(repo), child: const SaoshuhuiApp()));
  await tester.pumpAndSettle();
}

void main() {
  late FakeBookRepository repo;

  setUp(() => repo = FakeBookRepository());

  testWidgets('compact(<600dp)：底部 NavigationBar 5 Tab，无 Rail', (WidgetTester tester) async {
    await pumpShell(tester, repo, width: 390, height: 844);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    for (final String label in <String>['首页', '分类', '搜索', '采集', '我的']) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('medium(600–1024dp]：NavigationRail 非 extended，无底栏', (WidgetTester tester) async {
    await pumpShell(tester, repo, width: 800, height: 1000);
    expect(find.byType(NavigationBar), findsNothing);
    final NavigationRail rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(rail.destinations, hasLength(5));
  });

  testWidgets('1024dp 边界归 medium（QA ISSUE-1，设计系统 §9.1 边界裁决）', (WidgetTester tester) async {
    await pumpShell(tester, repo, width: 1024, height: 768);
    final NavigationRail rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse, reason: '1024dp 仍是 medium：Rail 非 extended、单栏');
    expect(find.text('选择左侧内容查看详情'), findsNothing, reason: 'medium 无 list-detail 右槽');
  });

  testWidgets('expanded(>1024dp)：extended Rail 全宽胶囊 + 品牌头 + list-detail 详情槽位', (WidgetTester tester) async {
    await pumpShell(tester, repo, width: 1440, height: 900);
    final NavigationRail rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
    expect(find.text('选择左侧内容查看详情'), findsOneWidget);
    // ISSUE-3：extended Rail 品牌头（品牌名 + 库容量 caption）。
    expect(find.text('扫书汇'), findsWidgets);
    expect(find.textContaining('内置库'), findsWidgets);
  });

  testWidgets('Tab 切换：点击「分类」进入分类分支', (WidgetTester tester) async {
    await pumpShell(tester, repo, width: 390, height: 844);
    await tester.tap(find.text('分类'));
    await tester.pumpAndSettle();
    expect(find.textContaining('按维度浏览'), findsOneWidget);
    expect(repo.calls['dimensionCounts'], greaterThanOrEqualTo(1));
  });

  testWidgets('Tab 切换：五档全走 fake 仓，无任何真库读取', (WidgetTester tester) async {
    await pumpShell(tester, repo, width: 390, height: 844);
    for (final String tab in <String>['分类', '搜索', '采集', '我的', '首页']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
    }
    // appDatabaseProvider 被换成「一读就抛」的哨兵：能跑完五档即证明无组件路径漏走真库。
    expect(repo.calls['timelinePosts'], greaterThanOrEqualTo(1));
    expect(repo.calls['dimensionCounts'], greaterThanOrEqualTo(1));
    expect(tester.takeException(), isNull);
  });
}
