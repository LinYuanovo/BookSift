import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/app.dart';
import 'package:booksift/app_shell.dart';
import 'package:booksift/features/content/content_detail_page.dart';
import 'package:booksift/features/content/detail_slot.dart';
import 'package:booksift/features/home/home_page.dart';
import 'package:booksift/theme/app_motion.dart';
import 'package:booksift/theme/appearance_settings.dart';
import 'package:booksift/theme/book_theme.dart';

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

  testWidgets('主题切换时长受减弱动效设置控制', (WidgetTester tester) async {
    await pumpShell(
      tester,
      repo,
      width: 390,
      height: 844,
      extraOverrides: <Override>[
        appearanceSettingsProvider.overrideWith(
          (Ref ref) async => const AppearanceSettings(reduceMotion: true),
        ),
      ],
    );

    final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp).first);
    expect(app.themeAnimationDuration, AppMotionTheme.reducedTokens.transition.duration);
    expect(app.themeAnimationCurve, AppMotionTheme.reducedTokens.transition.curve);
  });

  testWidgets('系统关闭动画偏好变化会即时更新主题转场时长', (WidgetTester tester) async {
    addTearDown(tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpShell(tester, repo, width: 390, height: 844);
    MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp).first);
    expect(app.themeAnimationDuration, AppMotionTheme.standardTokens.transition.duration);

    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pump(const Duration(milliseconds: 1));
    app = tester.widget<MaterialApp>(find.byType(MaterialApp).first);
    expect(app.themeAnimationDuration, AppMotionTheme.reducedTokens.transition.duration);
  });

  testWidgets('expanded 详情槽标准模式使用轻微缩放反馈', (WidgetTester tester) async {
    await pumpShell(tester, repo, width: 1440, height: 900);
    final ProviderContainer container = containerOf(tester, find.byType(HomePage));

    container.read(detailSelectionProvider.notifier).state = const PostSelection(postId: 7);
    await tester.pumpAndSettle();

    final AnimatedSwitcher switcher = tester.widget<AnimatedSwitcher>(
      find.byKey(const ValueKey<String>('right-detail-slot')),
    );
    expect(switcher.duration, AppMotionTheme.standardTokens.enter.duration);
    expect(
      find.byKey(const ValueKey<String>('detail-slot-scale')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(find.byType(ContentDetailPage), findsOneWidget);
  });

  testWidgets('expanded 详情槽减弱动效时只淡入、不缩放', (WidgetTester tester) async {
    await pumpShell(
      tester,
      repo,
      width: 1440,
      height: 900,
      extraOverrides: <Override>[
        appearanceSettingsProvider.overrideWith(
          (Ref ref) async => const AppearanceSettings(reduceMotion: true),
        ),
      ],
    );
    final ProviderContainer container = containerOf(tester, find.byType(HomePage));

    container.read(detailSelectionProvider.notifier).state = const PostSelection(postId: 7);
    await tester.pump();

    final Finder slot = find.byKey(const ValueKey<String>('right-detail-slot'));
    final AnimatedSwitcher switcher = tester.widget<AnimatedSwitcher>(slot);
    expect(switcher.duration, AppMotionTheme.reducedTokens.enter.duration);
    expect(
      find.byKey(const ValueKey<String>('detail-slot-scale')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('detail-slot-fade')),
      findsWidgets,
    );
  });

  testWidgets('详情切换进行中再次选择内容时保留新选择且不触发重复键异常', (WidgetTester tester) async {
    await pumpShell(tester, repo, width: 1440, height: 900);
    final ProviderContainer container = containerOf(tester, find.byType(HomePage));

    container.read(detailSelectionProvider.notifier).state = const PostSelection(postId: 7);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    container.read(detailSelectionProvider.notifier).state = const PostSelection(postId: 8);
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(find.byType(ContentDetailPage), findsOneWidget);
    expect(container.read(detailSelectionProvider)?.postId, 8);
  });

  testWidgets('详情转场中的旧页面不可点击且不出现在语义树', (WidgetTester tester) async {
    const Widget current = Text('B', key: ValueKey<String>('detail-b'));
    const Widget previous = Text('A', key: ValueKey<String>('detail-a'));
    await tester.pumpWidget(
      MaterialApp(
        theme: BookTheme.light,
        home: Scaffold(
            body: buildDetailSlotLayout(
            current,
            const <Widget>[previous],
          ),
        ),
      ),
    );
    await tester.pump();
    final Finder oldPage = find.byKey(const ValueKey<String>('detail-a'));
    expect(oldPage, findsOneWidget);
    expect(find.byKey(const ValueKey<String>('detail-b')), findsOneWidget);
    expect(
      find.ancestor(
        of: oldPage,
        matching: find.byKey(const ValueKey<String>('detail-slot-outgoing')),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: oldPage,
        matching: find.byKey(const ValueKey<String>('detail-slot-outgoing-focus')),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: oldPage,
        matching: find.byKey(const ValueKey<String>('detail-slot-outgoing-semantics')),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey<String>('detail-b')),
        matching: find.byType(ExcludeSemantics),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('详情播放中切到减弱动效会立即完成当前转场', (WidgetTester tester) async {
    final ValueNotifier<AppMotionTheme> motion = ValueNotifier<AppMotionTheme>(
      AppMotionTheme.standardTokens,
    );
    addTearDown(motion.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<AppMotionTheme>(
        valueListenable: motion,
        builder: (BuildContext context, AppMotionTheme value, Widget? child) => MaterialApp(
          theme: BookTheme.light,
          home: Scaffold(
            body: DetailSlotSwitcher(
              motion: value,
              child: Text(
                value.reduceMotion ? '减弱' : '标准',
                key: ValueKey<bool>(value.reduceMotion),
              ),
            ),
          ),
        ),
      ),
    );
    motion.value = AppMotionTheme.reducedTokens;
    await tester.pump();

    final AnimatedSwitcher switcher = tester.widget<AnimatedSwitcher>(
      find.byKey(const ValueKey<String>('right-detail-slot')),
    );
    expect(switcher.duration, AppMotionTheme.reducedTokens.enter.duration);
    await tester.pump(AppMotionTheme.reducedTokens.enter.duration);
    await tester.pump();
    expect(find.text('减弱'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
  });
}
