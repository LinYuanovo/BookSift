import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import '../support/harness.dart';

// 任务 5：头部元信息「原帖 ↗」改走外链统一出口 openThreadExternallyWithFeedback
// （贴吧 App 优先、未装回落浏览器、失败 SnackBar 如实告知），不再复制链接；
// 选择模式下手势暂停逻辑保留（与书名/URL 同口径）。
//
// 平台通道必须 mock（TESTING.md §1：未注册通道在假时钟区**永不返回**，失败提示
// 不会出现）：
//   · booksift/external_launch → false（等价无原生宿主，落浏览器兜底路径；
//     该分支仅在 defaultTargetPlatform == android 时走到，mock 后两平台口径一致）；
//   · plugins.flutter.io/url_launcher → canLaunch=false（url_launcher_platform_interface
//     2.3.2 缺省 MethodChannelUrlLauncher 的通道/方法名）→ openThreadExternally 恒 false。

/// 注册两条通道 mock（返回体完成于微任务，FakeAsync 可冲刷），teardown 自动摘除。
void _mockExternalLaunch(WidgetTester tester) {
  const MethodChannel external = MethodChannel('booksift/external_launch');
  const MethodChannel launcher = MethodChannel('plugins.flutter.io/url_launcher');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    external,
    (MethodCall call) async => false,
  );
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    launcher,
    (MethodCall call) async => call.method == 'canLaunch' ? false : null,
  );
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(external, null);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(launcher, null);
  });
}

/// 捕获 Clipboard.setData（同 online_post_page_test 口径）：断言「不再复制」。
List<String> _mockClipboard(WidgetTester tester) {
  final List<String> copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map<dynamic, dynamic>)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}

/// 头部「原帖」链接的 GestureDetector（Text('原帖') 的最近 GD 祖先）。
Finder threadLink() => find
    .ancestor(of: find.text('原帖'), matching: find.byType(GestureDetector))
    .first;

void main() {
  late FakeBookRepository repo;
  setUp(() => repo = FakeBookRepository(library: demoLibrary()));

  testWidgets('点原帖 → 外部打开（无可用应用 → 如实 SnackBar，不再复制剪贴板）', (
    WidgetTester tester,
  ) async {
    _mockExternalLaunch(tester);
    final List<String> copied = _mockClipboard(tester);
    useSurface(tester);
    await tester.pumpWidget(testApp(repo, initial: '/post/7'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('原帖'));
    await tester.pumpAndSettle();

    expect(find.text('没有可打开原帖的应用'), findsOneWidget);
    expect(copied, isEmpty, reason: '任务 5：外链口径替代「复制链接」');
    await dismissSnackBars(tester);
  });

  testWidgets('选择模式下原帖链接手势暂停（onTap null），退出恢复', (WidgetTester tester) async {
    useSurface(tester);
    await tester.pumpWidget(testApp(repo, initial: '/post/7'));
    await tester.pumpAndSettle();

    expect(tester.widget<GestureDetector>(threadLink()).onTap, isNotNull);

    await tester.tap(find.byTooltip('自由复制'));
    await tester.pumpAndSettle();
    expect(tester.widget<GestureDetector>(threadLink()).onTap, isNull);

    await tester.tap(find.byTooltip('退出自由复制'));
    await tester.pumpAndSettle();
    expect(tester.widget<GestureDetector>(threadLink()).onTap, isNotNull);
    await dismissSnackBars(tester);
  });

  testWidgets('点帖子详情作者名 → 以其为关键词搜索（携 q= 出结果）', (WidgetTester tester) async {
    useSurface(tester);
    await tester.pumpWidget(testApp(repo, initial: '/post/7'));
    await tester.pumpAndSettle();

    // 帖 7 作者 = 扫书人甲（demo_data）。
    final Finder author = find.ancestor(
      of: find.text('扫书人甲'),
      matching: find.byType(GestureDetector),
    ).first;
    expect(tester.widget<GestureDetector>(author).onTap, isNotNull);

    await tester.tap(find.text('扫书人甲'));
    await tester.pumpAndSettle();

    // 落到搜索页并以作者名为检索词（结果头行显示该词）。
    expect(find.text('"扫书人甲"'), findsOneWidget);
  });
}
