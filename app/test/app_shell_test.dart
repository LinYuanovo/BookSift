import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/app.dart';

import 'support/fake_book_repository.dart';
import 'support/fake_collect.dart';
import 'support/harness.dart';

// 自适应骨架三档形态（M1-②）。
//
// 全内存挂具：BookSiftApp 会经 fontServiceProvider / queriesProvider 触到 drift 与
// path_provider（都是真实异步），在 testWidgets 假时钟区内必挂死；故一律用 harness.dart
// 的 overrides 注入 fake（见 app/test/TESTING.md §1/§3）。
//
// M2-①：采集 Tab 改为消费 DB-backed 契约 provider（collectForumsProvider /
// recentCollectLogsProvider），按任务规约「widget 测试里必须 override」——凡渲染采集页的
// 用例须叠加 collectTestOverrides（否则哨兵 appDatabaseProvider 抛错并经 Riverpod 上报
// zone，takeException 判红）。

Future<void> pumpShell(
  WidgetTester tester,
  FakeBookRepository repo, {
  required double width,
  required double height,
  List<Override> extraOverrides = const <Override>[],
}) async {
  useSurface(tester, width: width, height: height);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[...testOverrides(repo), ...extraOverrides],
      child: const BookSiftApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late FakeBookRepository repo;

  setUp(() => repo = FakeBookRepository());

  testWidgets('compact(<600dp)：底部 NavigationBar 4 Tab，无 Rail', (WidgetTester tester) async {
    await pumpShell(tester, repo, width: 390, height: 844);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    for (final String label in <String>['首页', '搜索', '采集', '我的']) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('medium(600–1024dp]：NavigationRail 非 extended，无底栏', (WidgetTester tester) async {
    await pumpShell(tester, repo, width: 800, height: 1000);
    expect(find.byType(NavigationBar), findsNothing);
    final NavigationRail rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(rail.destinations, hasLength(4));
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

  testWidgets('Tab 切换：四档全走 fake 仓，无任何真库读取', (WidgetTester tester) async {
    // 采集 Tab 的 DB-backed 契约 provider 按规约 override 为纯内存数据（M2-①）。
    // collectTestOverrides 的 demoForums/demoLogs 是纯数据构造，不触 DB。
    await pumpShell(
      tester,
      repo,
      width: 390,
      height: 844,
      extraOverrides: collectTestOverrides(notifier: FakeCollectRunNotifier()),
    );
    for (final String tab in <String>['搜索', '采集', '我的', '首页']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
    }
    // appDatabaseProvider 被换成「一读就抛」的哨兵：能跑完四档即证明无组件路径漏走真库。
    expect(repo.calls['timelinePosts'], greaterThanOrEqualTo(1));
    expect(tester.takeException(), isNull);
  });
}
