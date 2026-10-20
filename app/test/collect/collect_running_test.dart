import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/collector/collect_state.dart';
import 'package:booksift/features/collect/collect_page.dart';
import 'package:booksift/features/collect/stat_grid.dart';
import 'package:booksift/features/collect/steps_timeline.dart';
import 'package:booksift/theme/app_colors.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../support/fake_book_repository.dart';
import '../support/fake_collect.dart';
import '../support/harness.dart';
import 'collect_idle_test.dart' show findSpan;

// 采集中心 · 运行态手机（设计稿 06 采集进度页 index.html:1584–1660 逐块复刻）。
//
// ⚠️ 常规运行态用例**一律 tester.pump 定步长**，禁 pumpAndSettle：
// active 步骤点 pulseRing 是 1.6s 无限动画，pumpAndSettle 永不收敛（TESTING.md 教训；
// reduceMotion 收敛用例见 collect_motion_icons_test.dart）。

void main() {
  late FakeBookRepository repo;

  setUp(() => repo = FakeBookRepository());

  Future<void> pumpRunning(WidgetTester tester, CollectRunState state) async {
    useSurface(tester, height: 1700);
    await tester.pumpWidget(
      testApp(
        repo,
        home: const CollectPage(),
        extraOverrides: collectTestOverrides(
          notifier: FakeCollectRunNotifier(initial: state),
        ),
      ),
    );
    await tester.pump(); // FutureProvider（settings）微任务冲刷
    await tester.pump(const Duration(milliseconds: 700)); // ring slow 500ms + 计数 normal 300ms 收敛
  }

  testWidgets('06 屏主卡：ring 68% + 主吧 headline + 步骤 caption + 冷却吧 danger 行', (WidgetTester tester) async {
    await pumpRunning(tester, demoRunState());

    // 进度环中心：serif 600 tabular 百分比 + '总进度'。
    expect(find.text('68%'), findsOneWidget);
    expect(find.text('总进度'), findsOneWidget);
    // 主吧 = 第一个非冷却吧。
    expect(find.text('yy小说吧'), findsOneWidget);
    expect(find.text('步骤 ② 解析楼层 + 分类 · pn 12/18 · 并发 2'), findsOneWidget);
    // 冷却吧行：'{fname} · 接口 429 · 冷却中 48m'，danger 语义色（token 断言）。
    final TextSpan? cooldown = findSpan(tester, '接口 429 · 冷却中 48m');
    expect(cooldown, isNotNull);
    expect(cooldown!.style?.color, AppColors.light.danger);
  });

  testWidgets('stat-grid 六格：+37/+212/+58/12/4/9 与绿/灰语义色', (WidgetTester tester) async {
    await pumpRunning(tester, demoRunState());

    // 限定在 StatGrid 内断言（步骤点数字 '3'/'4' 等会与裸数字撞名）。
    final Finder grid = find.byType(StatGrid);
    for (final String v in <String>['+37', '+212', '+58', '12', '4', '9']) {
      expect(find.descendant(of: grid, matching: find.text(v)), findsOneWidget, reason: 'stat 格 $v 缺失');
    }
    for (final String label in <String>['帖', '楼层', '书目', '跳过重复', '丢弃闲聊', '排雷帖']) {
      expect(find.descendant(of: grid, matching: find.text(label)), findsOneWidget, reason: 'stat label $label 缺失');
    }
    // 绿 = recommend（+N 帖）；灰 = textMuted（跳过重复/丢弃闲聊）；正文色 = text。
    expect(tester.widget<Text>(find.descendant(of: grid, matching: find.text('+37'))).style?.color, AppColors.light.recommend);
    expect(tester.widget<Text>(find.descendant(of: grid, matching: find.text('12'))).style?.color, AppColors.light.textMuted);
    expect(tester.widget<Text>(find.descendant(of: grid, matching: find.text('4'))).style?.color, AppColors.light.textMuted);
    expect(tester.widget<Text>(find.descendant(of: grid, matching: find.text('+212'))).style?.color, AppColors.light.text);
    expect(tester.widget<Text>(find.descendant(of: grid, matching: find.text('9'))).style?.color, AppColors.light.text);
  });

  testWidgets('watermark 卡：水位 → 推进至（mono 值）+（取消可重入）', (WidgetTester tester) async {
    await pumpRunning(tester, demoRunState());
    expect(find.textContaining('2026-10-11 18:32', findRichText: true), findsOneWidget);
    expect(find.textContaining('2026-10-12 08:12', findRichText: true), findsOneWidget);
    expect(findSpan(tester, '（取消可重入）'), isNotNull);
    // 水位值 = mono 11.5 w500 text 色（index.html:700）。
    final TextSpan? value = findSpan(tester, '2026-10-11 18:32');
    expect(value!.style?.color, AppColors.light.text);
    expect(value.style?.fontWeight, FontWeight.w500);
  });

  testWidgets('steps 四步：done 勾 / active 数字 / pending 灰，连接线结构', (WidgetTester tester) async {
    await pumpRunning(tester, demoRunState());

    expect(find.text('① 拉帖列表'), findsOneWidget);
    expect(find.text('② 解析楼层 + 分类'), findsOneWidget);
    expect(find.text('③ 入库 / 重建 FTS'), findsOneWidget);
    expect(find.text('④ 完成汇总'), findsOneWidget);
    // done 点小标题 = 设计稿静态行；active 步注入运行态 stepDetail。
    expect(find.text('get_threads · pn 1→18 · 增量 tid > 水位'), findsOneWidget);
    expect(find.text('PbContent 拼装 · post_kind 分类器 · pn 12/18'), findsOneWidget);
    expect(find.text('drift 事务 · trigram 索引增量'), findsOneWidget);
    expect(find.text('首页出现「自采」徽标新扫书'), findsOneWidget);
    // active 点 = 数字 2；pending 点 = 3/4（限定 steps 内，避开 stat 裸数字）；done 点 = check SVG（-s stroke2 档）。
    final Finder steps = find.byType(StepsTimeline);
    expect(find.descendant(of: steps, matching: find.text('2')), findsOneWidget);
    expect(find.descendant(of: steps, matching: find.text('3')), findsOneWidget);
    expect(find.descendant(of: steps, matching: find.text('4')), findsOneWidget);
    expect(
      find.descendant(of: steps, matching: find.byType(SvgPicture)),
      findsOneWidget,
      reason: 'done 点白勾走 assets/icons SVG',
    );
  });

  testWidgets('logbox：7 行示例文案 + 级别语义色（ok 绿 / warn 红 / acc 强调）', (WidgetTester tester) async {
    await pumpRunning(tester, demoRunState());

    expect(find.textContaining('08:12:44', findRichText: true), findsOneWidget);
    expect(find.textContaining('08:00:00', findRichText: true), findsOneWidget);
    // 时间列 muted（index.html:511 .t）。
    expect(findSpan(tester, '08:12:44')!.style?.color, AppColors.light.textMuted);
    // ok = recommend / warn = danger / accent = accentStrong（index.html:512–514）。
    expect(findSpan(tester, 'tid=11097754039')!.style?.color, AppColors.light.recommend);
    expect(findSpan(tester, 'tid=11098706149')!.style?.color, AppColors.light.danger);
    expect(findSpan(tester, '并发=2 · 匿名 · 仅WiFi')!.style?.color, AppColors.light.accentStrong);
    // info 行 = 正文 secondary。
    expect(findSpan(tester, '+9 楼层 → book_entry ×4')!.style?.color, AppColors.light.textSecondary);
  });

  testWidgets('取消按钮 → controller.cancel', (WidgetTester tester) async {
    final FakeCollectRunNotifier fake = FakeCollectRunNotifier(initial: demoRunState());
    useSurface(tester, height: 1700);
    await tester.pumpWidget(
      testApp(repo, home: const CollectPage(), extraOverrides: collectTestOverrides(notifier: fake)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.text('取消采集（水位不推进）'));
    await tester.pump();
    expect(fake.cancelCalls, 1);
  });

  testWidgets('stopping：按钮禁用为「正在停止…」，点击不触达控制器', (WidgetTester tester) async {
    // 独立用例：ProviderScope 的 overrides 不随 pumpWidget 复用热替换，须全新树。
    final FakeCollectRunNotifier fake = FakeCollectRunNotifier(
      initial: demoRunState().copyWith(phase: CollectPhase.stopping),
    );
    useSurface(tester, height: 1700);
    await tester.pumpWidget(
      testApp(repo, home: const CollectPage(), extraOverrides: collectTestOverrides(notifier: fake)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('正在停止…'), findsOneWidget);
    expect(find.text('取消采集（水位不推进）'), findsNothing);
    await tester.tap(find.text('正在停止…'), warnIfMissed: false);
    await tester.pump();
    expect(fake.cancelCalls, 0);
  });

  testWidgets('降级横幅：state.banner 非空 → 顶部 danger-soft 横幅（§8.12）', (WidgetTester tester) async {
    await pumpRunning(tester, demoRunState().copyWith(banner: '贴吧接口似乎已变更'));
    final Finder banner = find.text('贴吧接口似乎已变更');
    expect(banner, findsOneWidget);
    expect(tester.widget<Text>(banner).style?.color, AppColors.light.danger);
  });

  testWidgets('图标守卫：运行态页内零 Material Icon（齿轮/时钟/勾/播放全 SVG）', (WidgetTester tester) async {
    await pumpRunning(tester, demoRunState());
    final Finder page = find.byType(CollectPage);
    expect(find.descendant(of: page, matching: find.byType(Icon)), findsNothing);
    // gear（appbar）+ clock（watermark）+ check（done 点）+ play（无——compact 运行态无立即采集钮）。
    expect(find.descendant(of: page, matching: find.byType(SvgPicture)), findsWidgets);
  });
}
