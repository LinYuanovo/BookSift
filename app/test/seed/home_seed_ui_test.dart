// 首页 × 种子导入状态接线测试（P0-1；与 bootstrap_controller_test.dart 配套）。
//
// 守卫四件事：
//  1. idle（导入未开始/无需导入）→ 正常时间线，不出现进度/失败面板（回归）；
//  2. importing → feed 区显示进度面板（阶段文案+百分比），而非误导性空态/骨架屏；
//  3. error → 失败面板 + 消息 + 「重试导入」按钮可再触发 ensureStarted；
//  4. done 迁移 → 级联失效 queriesProvider → 时间线重查（导入完成后界面自动活过来）。
//
// testWidgets 全内存：harness fake 仓 + ScriptedSeedController（零真实 IO，TESTING.md §1）。
// 进度一律用 determinate 值（indeterminate 是无限动画，pumpAndSettle 会挂）。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/data/seed_import.dart';
import 'package:booksift/data/seed_import_providers.dart';
import 'package:booksift/features/home/home_page.dart';

import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import '../support/harness.dart';

/// 测试驱动版控制器：手动 emit 状态；ensureStarted 只计数（不跑真导入）。
class ScriptedSeedController extends SeedBootstrapController {
  int startCalls = 0;

  void emit(SeedImportState s) => state = s;

  @override
  Future<void> ensureStarted() async {
    startCalls++;
  }
}

void main() {
  late FakeBookRepository repo;

  setUp(() => repo = FakeBookRepository(library: demoLibrary()));

  Future<ScriptedSeedController> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(testApp(
      repo,
      initial: '/home',
      extraOverrides: <Override>[seedBootstrapProvider.overrideWith(ScriptedSeedController.new)],
    ));
    await tester.pumpAndSettle();
    return containerOf(tester, find.byType(HomePage)).read(seedBootstrapProvider.notifier)
        as ScriptedSeedController;
  }

  testWidgets('idle：正常时间线，无进度/失败面板（默认路径回归）', (WidgetTester tester) async {
    await pumpHome(tester);
    expect(find.text('首次启动 · 正在导入内置书库'), findsNothing);
    expect(find.text('种子包导入失败'), findsNothing);
    expect(find.text('书库为空'), findsNothing, reason: 'demo 仓有数据，应显示时间线');
    expect(find.text('最新扫书'), findsOneWidget);
  });

  testWidgets('importing：显示进度面板（阶段文案+百分比），不显示空态', (WidgetTester tester) async {
    final ScriptedSeedController ctl = await pumpHome(tester);
    ctl.emit(const SeedImportState(
      phase: SeedImportPhase.importing,
      progress: 0.4,
      message: '导入内容表…',
    ));
    await tester.pumpAndSettle();
    expect(find.text('首次启动 · 正在导入内置书库'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('导入内容表…'), findsOneWidget);
    expect(find.text('书库为空'), findsNothing);
  });

  testWidgets('error：失败面板 + 消息 + 重试按钮再触发 ensureStarted', (WidgetTester tester) async {
    final ScriptedSeedController ctl = await pumpHome(tester);
    ctl.emit(const SeedImportState(phase: SeedImportPhase.error, message: 'zip sha256 不符'));
    await tester.pumpAndSettle();
    expect(find.text('种子包导入失败'), findsOneWidget);
    expect(find.text('zip sha256 不符'), findsOneWidget);
    await tester.tap(find.text('重试导入'));
    await tester.pumpAndSettle();
    expect(ctl.startCalls, 1);
  });

  testWidgets('done 迁移：级联失效 queriesProvider → 时间线重查', (WidgetTester tester) async {
    final ScriptedSeedController ctl = await pumpHome(tester);
    final int before = repo.calls['timelinePosts'] ?? 0;
    expect(before, greaterThan(0), reason: '首帧应已查过一次时间线');
    ctl.emit(const SeedImportState(phase: SeedImportPhase.done, progress: 1, message: '导入完成'));
    await tester.pumpAndSettle();
    expect(repo.calls['timelinePosts'], greaterThan(before), reason: 'done 迁移应触发重查');
  });
}
