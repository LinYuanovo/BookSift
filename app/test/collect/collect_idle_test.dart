import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/collector/collect_controller.dart';
import 'package:booksift/collector/collect_settings_keys.dart';
import 'package:booksift/collector/collect_state.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/features/collect/collect_page.dart';
import 'package:booksift/features/collect/collect_settings.dart';
import 'package:booksift/theme/app_colors.dart';

import '../support/fake_book_repository.dart';
import '../support/fake_collect.dart';
import '../support/harness.dart';

// 采集中心 · 空闲态（原型 §5.9）：吧卡片 / 水位 / 上次结果 / 启用开关 / 冷却倒计时 /
// 添加吧对话框错误路径 / 立即采集调用记录 / 最近日志列表 / 空态引导。
// 全内存：契约 Notifier 用 FakeCollectRunNotifier，DB 数据用 override 注入（TESTING.md §3.1）。

/// 在全树 RichText（含 Text.rich）中找包含 [needle] 的 TextSpan，用于断言语义色。
TextSpan? findSpan(WidgetTester tester, String needle) {
  for (final RichText rt in tester.widgetList<RichText>(find.byType(RichText))) {
    TextSpan? hit;
    rt.text.visitChildren((InlineSpan span) {
      if (hit == null && span is TextSpan && (span.text ?? '').contains(needle)) {
        hit = span;
      }
      return true;
    });
    if (hit != null) {
      return hit;
    }
  }
  return null;
}

void main() {
  late FakeBookRepository repo;
  late FakeCollectRunNotifier fake;

  setUp(() {
    repo = FakeBookRepository();
    fake = FakeCollectRunNotifier();
  });

  Future<void> pumpIdle(WidgetTester tester, {List<Override> Function()? overrides}) async {
    useSurface(tester, height: 1400);
    await tester.pumpWidget(
      testApp(
        repo,
        initial: '/collect',
        extraOverrides: overrides?.call() ?? collectTestOverrides(notifier: fake),
      ),
    );
    // FutureProvider 微任务级完成：两次定步 pump 冲刷（不用 pumpAndSettle，避免依赖收敛假设）。
    await tester.pump();
    await tester.pump();
  }

  testWidgets('吧卡片：吧名/水位/上次结果/启用开关/冷却倒计时 danger 色', (WidgetTester tester) async {
    await pumpIdle(tester);

    // 吧名出现两处：关注吧卡片 + 最近日志行（demoLogs 同源吧名）。
    expect(find.text('yy小说吧'), findsNWidgets(2));
    expect(find.text('哀伤雪刃'), findsNWidgets(2));
    // 水位行：epoch 秒 → 'YYYY-MM-DD HH:mm'（0 → '未采集'）；值在 Text.rich 内（整串 = '水位 …'）。
    expect(find.textContaining('2026-10-11 18:32', findRichText: true), findsOneWidget);
    expect(find.textContaining('2026-10-10 09:15', findRichText: true), findsOneWidget);
    // 上次结果行：ok → 成功 + 累计 + 相对时间。
    expect(findSpan(tester, '成功'), isNotNull);
    expect(findSpan(tester, '累计 37 帖'), isNotNull);
    expect(findSpan(tester, '2小时前'), isNotNull);
    // rate_limited → 「冷却中」标签 + 倒计时，均 danger 色（token 断言）；文案不重复「冷却中 冷却中」。
    final TextSpan? cooldown = findSpan(tester, '冷却中');
    expect(cooldown, isNotNull);
    expect(cooldown!.style?.color, AppColors.light.danger);
    final TextSpan? remain = findSpan(tester, '48m');
    expect(remain, isNotNull);
    expect(remain!.style?.color, AppColors.light.danger);
    // 启用开关渲染且值正确。
    final List<Switch> switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches, hasLength(2));
    expect(switches.first.value, isTrue);
  });

  testWidgets('启用开关：切换记录到 controller.setForumEnabled', (WidgetTester tester) async {
    await pumpIdle(tester);
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    await tester.pump();
    expect(fake.enabledCalls, contains(('yy小说吧', false)));
  });

  testWidgets('立即采集大按钮 → controller.startAll 调用记录', (WidgetTester tester) async {
    await pumpIdle(tester);
    expect(find.text('立即采集（预计2分钟）'), findsOneWidget);
    await tester.tap(find.text('立即采集（预计2分钟）'));
    await tester.pump();
    expect(fake.startAllCalls, 1);
  });

  testWidgets('启动前采集受阻仍在空闲页显示原因', (WidgetTester tester) async {
    final FakeCollectRunNotifier blocked = FakeCollectRunNotifier(
      initial: const CollectRunState(
        banner: '当前非 WiFi 网络，已按设置暂停采集（设置页可关闭「仅 WiFi」）',
      ),
    );
    await pumpIdle(tester, overrides: () => collectTestOverrides(notifier: blocked));

    expect(
      find.text('当前非 WiFi 网络，已按设置暂停采集（设置页可关闭「仅 WiFi」）'),
      findsOneWidget,
    );
    expect(find.text('立即采集（预计2分钟）'), findsOneWidget);
  });

  test('旧式 Wi-Fi 设置值在设置模型中与采集门控口径一致', () {
    for (final String value in <String>['0', 'false']) {
      expect(wifiOnlyFromSetting(value), isFalse);
    }
    for (final String value in <String>['1', 'true']) {
      expect(wifiOnlyFromSetting(value), isTrue);
    }
    expect(const CollectSettings().wifiOnly, isTrue);
  });

  testWidgets('添加吧对话框：CollectAddForumException.reason 以 danger 文案显示在对话框内', (WidgetTester tester) async {
    final FakeCollectRunNotifier failing = FakeCollectRunNotifier(
      addForumError: const CollectAddForumException('吧不存在'),
    );
    await pumpIdle(tester, overrides: () => collectTestOverrides(notifier: failing));

    await tester.tap(find.text('添加贴吧'));
    await tester.pumpAndSettle(); // 对话框转场（有限动画，可 settle）
    expect(find.text('添加贴吧'), findsNWidgets(2)); // 按钮 + 对话框标题

    await tester.enterText(find.byType(TextField), '不存在的吧');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    // 错误路径：对话框不关闭，reason 以 danger 色显示。
    final Finder errorText = find.text('吧不存在');
    expect(errorText, findsOneWidget);
    expect(tester.widget<Text>(errorText).style?.color, AppColors.light.danger);
    expect(failing.addedForums, isEmpty);
  });

  testWidgets('添加吧对话框：成功路径关闭并记录 addForum', (WidgetTester tester) async {
    await pumpIdle(tester);
    await tester.tap(find.text('添加贴吧'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '雪群推书');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(fake.addedForums, <String>['雪群推书']);
    expect(find.text('添加贴吧'), findsOneWidget, reason: '对话框已关闭，只剩入口按钮');
  });

  testWidgets('最近日志：时间 mono + fname + +N帖/N楼 + 状态徽标', (WidgetTester tester) async {
    await pumpIdle(tester);
    expect(find.text('最近日志'), findsOneWidget);
    expect(find.text('10-12 08:00'), findsOneWidget);
    expect(find.text('+37帖/12楼'), findsOneWidget);
    expect(find.text('成功'), findsOneWidget);
    expect(find.text('10-11 20:00'), findsOneWidget);
    expect(find.text('接口异常'), findsOneWidget);
  });

  testWidgets('空态（无关注吧）：引导添加默认两吧', (WidgetTester tester) async {
    await pumpIdle(tester, overrides: () => collectTestOverrides(notifier: fake, forums: <CollectionStateEntry>[]));
    expect(find.text('还没有关注吧'), findsOneWidget);
    expect(find.text('添加默认关注吧'), findsOneWidget);
  });

  testWidgets('图标守卫：空闲态采集页内零 Material Icon，图标全走 assets/icons SVG', (WidgetTester tester) async {
    await pumpIdle(tester);
    final Finder page = find.byType(CollectPage);
    expect(page, findsOneWidget);
    // 设计稿 SVG 图标（AppIcon → SvgPicture）在页内出现（账号卡 user / 添加 plus / 立即采集 play）。
    expect(
      find.descendant(of: page, matching: find.byType(SvgPicture)),
      findsWidgets,
    );
    // 被替换的 Material 默认图标不得出现（齿轮/加号/播放等一律 SVG）。
    expect(
      find.descendant(of: page, matching: find.byType(Icon)),
      findsNothing,
    );
  });
}
