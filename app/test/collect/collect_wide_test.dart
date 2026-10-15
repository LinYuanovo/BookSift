import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/collector/collect_state.dart';
import 'package:booksift/features/collect/collect_page.dart';
import 'package:booksift/features/collect/stat_grid.dart';
import 'package:booksift/features/collect/wide_dashboard.dart';

import '../support/fake_book_repository.dart';
import '../support/fake_collect.dart';
import '../support/harness.dart';

// 采集仪表盘宽屏（W5t medium 1024×768 → 2 列 index.html:2806–2905；
// W5d expanded 1440×900 → 3 列 index.html:3400–3495）。
// 直接 pump CollectPage（home: 形态，取整窗宽度），运行态 = 演示快照。
// ⚠️ pulse 无限动画 → 定步长 pump，禁 pumpAndSettle。

void main() {
  late FakeBookRepository repo;

  setUp(() => repo = FakeBookRepository());

  Future<void> pumpWide(WidgetTester tester, {required double width, required double height}) async {
    useSurface(tester, width: width, height: height);
    await tester.pumpWidget(
      testApp(
        repo,
        home: const CollectPage(),
        extraOverrides: collectTestOverrides(
          notifier: FakeCollectRunNotifier(initial: demoRunState()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('medium 1024×768：2 列 dash 六卡 + stats 3 列 + dtable 表头五列', (WidgetTester tester) async {
    await pumpWide(tester, width: 1024, height: 768);

    // 六张 dash 卡的标题/面板头（grid areas：ring forums / stats stats / steps wm / log log）。
    expect(find.byType(CollectWideDashboard), findsOneWidget);
    expect(find.text('总进度'), findsNWidgets(2)); // 卡头 b + ring 中心 small
    expect(find.text('步骤 ②/④'), findsOneWidget); // dash-ring badge kind
    expect(find.text('并发吧 · 2'), findsOneWidget);
    expect(find.text('匿名 · 并发 2'), findsOneWidget); // badge origin-self
    expect(find.text('四步流水'), findsOneWidget);
    expect(find.text('实时日志 · 表格变体（宽屏）'), findsOneWidget);
    // dash-wm 卡（watermark 透明变体 + sub）。
    expect(find.textContaining('2026-10-11 18:32', findRichText: true), findsOneWidget);
    expect(find.text('完成后自动重建 FTS 增量索引 · 约 3s'), findsOneWidget);
    // dash-forums 卡底 sub。
    expect(find.text('各吧水位独立推进 · 杀进程 / 断网 / 取消 三态可重入'), findsOneWidget);
    // medium 下 stat-grid c6 降为 3 列 ×2 行（index.html:994）。
    expect(tester.widget<StatGrid>(find.byType(StatGrid)).columns, 3);
    // dtable 表头五列（index.html:2890）。
    for (final String th in <String>['时间', '来源', '事件', '详情', '状态']) {
      expect(find.text(th), findsOneWidget, reason: 'dtable 表头列 $th 缺失');
    }
    // dtable 行内容 + 状态徽标六语义（进行中/扫书/排雷/已入库/冷却中/已启动）。
    expect(find.text('pn=12/18 · 新帖 3'), findsOneWidget);
    expect(find.text('tid=11097754039 → 扫书 (书名数=3≥3)'), findsOneWidget);
    expect(find.text('进行中'), findsOneWidget);
    expect(find.text('扫书'), findsOneWidget);
    expect(find.text('排雷'), findsNWidgets(2));
    expect(find.text('已入库'), findsOneWidget);
    expect(find.text('冷却中'), findsOneWidget);
    expect(find.text('已启动'), findsOneWidget);
    // 并发吧行：冷却 badge '429 · 冷却 48m' + 不阻塞 sub。
    expect(find.textContaining('429 · 冷却 48m'), findsOneWidget);
    expect(find.textContaining('不阻塞其余吧'), findsOneWidget);
    // medium appbar 无 '并发 · 仅 WiFi' badge（W5t 仅 gear，index.html:2826–2832）。
    expect(find.textContaining('仅 WiFi'), findsNothing);
  });

  testWidgets('expanded 1440×900：3 列 dash + stats c6 一行 + appbar 并发 badge + 立即采集', (WidgetTester tester) async {
    await pumpWide(tester, width: 1440, height: 900);

    expect(find.byType(CollectWideDashboard), findsOneWidget);
    // expanded：stats c6 = 一行六格（index.html:993）。
    expect(tester.widget<StatGrid>(find.byType(StatGrid)).columns, 6);
    // W5d appbar 增量：'并发 2 · 仅 WiFi' badge kind + 立即采集 btn-accent btn-sm（index.html:3420–3422）。
    expect(find.text('并发 2 · 仅 WiFi'), findsOneWidget);
    expect(find.text('立即采集'), findsOneWidget);
    // 三列行仍在：ring / forums / steps / wm / log。
    expect(find.text('并发吧 · 2'), findsOneWidget);
    expect(find.text('四步流水'), findsOneWidget);
    expect(find.text('实时日志 · 表格变体（宽屏）'), findsOneWidget);
    for (final String th in <String>['时间', '来源', '事件', '详情', '状态']) {
      expect(find.text(th), findsOneWidget);
    }
  });

  testWidgets('dash 卡片壳：raised + hairline 描边 + radius-lg（index.html:987）', (WidgetTester tester) async {
    await pumpWide(tester, width: 1024, height: 768);
    // ring/forums/steps/wm/log 五张 dash-card（stats 无卡壳，index.html:992）。
    expect(find.byType(DashCard), findsNWidgets(5));
  });

  testWidgets('空闲态宽屏：双栏（左 = 账号+关注吧+操作，右 = 最近日志），不仪表盘化', (WidgetTester tester) async {
    useSurface(tester, width: 1024, height: 768);
    await tester.pumpWidget(
      testApp(
        repo,
        home: const CollectPage(),
        extraOverrides: collectTestOverrides(notifier: FakeCollectRunNotifier()),
      ),
    );
    await tester.pump();
    await tester.pump();
    // 左栏：账号卡 + 关注吧 + 立即采集；右栏：最近日志。
    // '匿名模式' 出现两处：AppBar 徽标（演示态入口）+ 账号卡。
    expect(find.text('匿名模式'), findsNWidgets(2));
    expect(find.text('关注吧'), findsOneWidget);
    expect(find.text('立即采集（预计2分钟）'), findsOneWidget);
    expect(find.text('最近日志'), findsOneWidget);
    expect(find.text('yy小说吧'), findsNWidgets(2)); // 吧卡片 + 日志行
    // 空闲态不出现仪表盘卡。
    expect(find.byType(DashCard), findsNothing);
  });

  // ── 灰柱回归（真机瞬时巨柱 bug）──
  // 根因链：expanded 首行 IntrinsicHeight > Row(stretch)，行高 = 各卡固有高度最大值；
  // _DashForums 卡高度 ≈ 吧数 × 行高（_publish 快照含全部启用吧），吧数一多行高即病态；
  // StatGrid(stretch: true) 被拉伸成整列巨柱（_StatCell 顶对齐 → 柱顶 +N）。
  // 修复：统计条在各断点一律自然高度（expanded 不再参与同行等高）。
  CollectRunState manyForumsState(int n) => demoRunState().copyWith(
        forums: <ForumRunState>[
          for (int i = 0; i < n; i++)
            ForumRunState(
              fname: '回归测试吧$i',
              status: ForumStatus.parsing,
              step: CollectStep.parse,
              stepDetail: 'pn 1/5',
              overallProgress: 0.3,
            ),
        ],
      );

  // StatGrid 自然高度 ≈ 数字行 24 + gap 4 + label ~16 + 纵向 padding 32 + 描边 ≈ 78dp；
  // 病态拉伸时与并发吧卡等高（12 吧 ≈ 700+）。阈值 200 明确二分两种形态。
  testWidgets('expanded 回归：12 吧运行时 StatGrid 保持自然高度，不被同行卡拉成巨柱', (WidgetTester tester) async {
    useSurface(tester, width: 1440, height: 900);
    await tester.pumpWidget(
      testApp(
        repo,
        home: const CollectPage(),
        extraOverrides: collectTestOverrides(
          notifier: FakeCollectRunNotifier(initial: manyForumsState(12)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(CollectWideDashboard), findsOneWidget);
    expect(tester.widget<StatGrid>(find.byType(StatGrid)).columns, 6);
    final double statsHeight = tester.getSize(find.byType(StatGrid)).height;
    expect(statsHeight, lessThan(200), reason: 'StatGrid 被 IntrinsicHeight 同行卡拉伸：height=$statsHeight');
  });

  testWidgets('medium 免疫对照：同一 12 吧运行态，1024×768 StatGrid 独占行自然高', (WidgetTester tester) async {
    useSurface(tester, width: 1024, height: 768);
    await tester.pumpWidget(
      testApp(
        repo,
        home: const CollectPage(),
        extraOverrides: collectTestOverrides(
          notifier: FakeCollectRunNotifier(initial: manyForumsState(12)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(CollectWideDashboard), findsOneWidget);
    // medium 下 stats 不在任何 IntrinsicHeight 行内（独占一行），构造上免疫拉伸。
    expect(tester.widget<StatGrid>(find.byType(StatGrid)).columns, 3);
    final double statsHeight = tester.getSize(find.byType(StatGrid)).height;
    expect(statsHeight, lessThan(200), reason: 'medium StatGrid 异常：height=$statsHeight');
  });

  testWidgets('compact 免疫对照：同一 12 吧运行态，竖屏 StatGrid 恒为自然高度', (WidgetTester tester) async {
    useSurface(tester, width: 390, height: 844);
    await tester.pumpWidget(
      testApp(
        repo,
        home: const CollectPage(),
        extraOverrides: collectTestOverrides(
          notifier: FakeCollectRunNotifier(initial: manyForumsState(12)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(CollectWideDashboard), findsNothing); // compact 走 ListView 自然高
    final double statsHeight = tester.getSize(find.byType(StatGrid)).height;
    expect(statsHeight, lessThan(200), reason: 'compact StatGrid 异常：height=$statsHeight');
  });
}
