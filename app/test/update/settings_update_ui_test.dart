/// 设置页「关于」区 widget 测试（testWidgets；TESTING.md §3.1 全内存 fake：
/// 脚本化 dio + InMemory settings store + 固定本地版本 + 启动延迟归零，零真实网络/IO）。
///
/// 覆盖：关于区渲染与零请求、手动检查三态（检查中/已最新/失败）、更新卡片
/// （版本号+日志+来源+前往下载复制 apk/ios 链接）、min_force 强更形态、
/// 主源 403 → 备源切换呈现、备源 URL 编辑持久化与非法输入拒绝。
library;

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodCall;
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/update/update_controller.dart';
import 'package:booksift/core/update/update_service.dart';
import 'package:booksift/features/profile/settings_page.dart';

import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import '../support/harness.dart';
import 'support.dart';

Future<void> pumpSettings(
  WidgetTester tester, {
  required ScriptedAdapter adapter,
  InMemoryUpdateSettingsStore? store,
  LocalVersion local = const LocalVersion(version: '1.0.0', buildNumber: 100),
}) async {
  useTallSurface(tester);
  await tester.pumpWidget(
    testApp(
      FakeBookRepository(library: demoLibrary()),
      home: const SettingsPage(),
      extraOverrides: updateTestOverrides(adapter: adapter, local: local, store: store),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('关于区渲染：版本号 + idle 文案 + 备源缺省；渲染本身零请求', (WidgetTester tester) async {
    final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{});
    await pumpSettings(tester, adapter: adapter);

    expect(find.text('关于'), findsOneWidget);
    expect(find.text('当前版本'), findsOneWidget);
    expect(find.text('v1.0.0 (100)'), findsOneWidget);
    expect(find.text('GitHub 主源 + 静态备源 · 主源失败自动切换'), findsOneWidget);
    expect(find.text('更新备源'), findsOneWidget);
    expect(find.text('未配置 · 出厂缺省（仅主源）'), findsOneWidget);
    expect(adapter.requests, isEmpty); // 打开设置页不发任何检查请求（静默检查只由 app 接线调度）
  });

  testWidgets('本地版本未知（package_info 失败回落）→ 显示「版本未知」', (WidgetTester tester) async {
    await pumpSettings(tester, adapter: ScriptedAdapter(<String, ScriptedResponse>{}), local: LocalVersion.unknown);
    expect(find.text('版本未知'), findsOneWidget);
  });

  testWidgets('手动检查：检查中 → 更新卡片 → 前往下载复制 apk 链接 + SnackBar', (WidgetTester tester) async {
    final List<MethodCall> clipboard = mockClipboard(tester);
    final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
      // 50ms 假时钟延迟定格「检查中」帧（响应本身仍是内存脚本，零网络）。
      kControllerGithubUrl: ScriptedResponse(
        githubReleaseJson(withSha256Asset: false),
        delay: const Duration(milliseconds: 50),
      ),
    });
    await pumpSettings(tester, adapter: adapter);

    await tester.tap(find.text('检查更新'));
    await tester.pump();
    expect(find.text('检查中…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    // 更新卡片：版本号 + 更新日志 + 来源 + 按钮（§10.1 弹更新卡片）。
    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('v1.1.0'), findsOneWidget);
    expect(find.text('修复若干问题'), findsOneWidget);
    expect(find.text('来源 GitHub Releases'), findsOneWidget);
    expect(find.text('前往下载'), findsOneWidget);
    expect(find.text('稍后'), findsOneWidget);

    await tester.tap(find.text('前往下载'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing); // 卡片已关
    expect(clipboardTexts(clipboard), <String>[kTestApkUrl]); // Android 平台缺省 → apk_url
    expect(find.text('下载链接已复制'), findsOneWidget);
    await dismissSnackBars(tester);
  });

  testWidgets('手动检查：已最新 → SnackBar「当前已是最新版本」，无弹窗', (WidgetTester tester) async {
    final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
      kControllerGithubUrl: ScriptedResponse(githubReleaseJson(tag: 'v1.0.0', withSha256Asset: false)),
    });
    await pumpSettings(tester, adapter: adapter);

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('当前已是最新版本'), findsOneWidget); // SnackBar
    expect(find.text('已是最新版本'), findsOneWidget); // 行内三态文案
    await dismissSnackBars(tester);
  });

  testWidgets('手动检查：双源失败 → 「检查失败」文案，无弹窗（静默口径）', (WidgetTester tester) async {
    final InMemoryUpdateSettingsStore store = InMemoryUpdateSettingsStore()
      ..values[kUpdateFallbackUrlKey] = kTestFallbackUrl;
    final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
      kControllerGithubUrl: ScriptedResponse.networkError(),
      kTestFallbackUrl: const ScriptedResponse('{}', status: 404),
    });
    await pumpSettings(tester, adapter: adapter, store: store);

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('检查失败，请稍后再试'), findsOneWidget); // SnackBar（手动检查必须给反馈）
    expect(find.text('检查失败 · 双源均不可达'), findsOneWidget); // 行内文案
    expect(adapter.requestedUrls, <String>[kControllerGithubUrl, kTestFallbackUrl]);
    await dismissSnackBars(tester);
  });

  testWidgets('主源 403 → 自动切备源：更新卡片标注静态备源', (WidgetTester tester) async {
    final InMemoryUpdateSettingsStore store = InMemoryUpdateSettingsStore()
      ..values[kUpdateFallbackUrlKey] = kTestFallbackUrl;
    final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
      kControllerGithubUrl: const ScriptedResponse('{"message":"API rate limit exceeded"}', status: 403),
      kTestFallbackUrl: ScriptedResponse(versionJson()),
    });
    await pumpSettings(tester, adapter: adapter, store: store);

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('v1.2.0'), findsOneWidget);
    expect(find.text('来源 静态备源'), findsOneWidget);
    expect(find.text('备源更新日志'), findsOneWidget);
    expect(adapter.requestedUrls, <String>[kControllerGithubUrl, kTestFallbackUrl]);

    await tester.tap(find.text('稍后'));
    await tester.pumpAndSettle();
    expect(find.text('发现新版本 v1.2.0'), findsOneWidget); // 行内保留提示
  });

  testWidgets('min_force 强更：卡片无「稍后」并标注强制更新（GitHub 源无 min_force，走备源呈现）', (WidgetTester tester) async {
    final List<MethodCall> clipboard = mockClipboard(tester);
    final InMemoryUpdateSettingsStore store = InMemoryUpdateSettingsStore()
      ..values[kUpdateFallbackUrlKey] = kTestFallbackUrl;
    final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
      kControllerGithubUrl: ScriptedResponse.networkError(),
      kTestFallbackUrl: ScriptedResponse(versionJson(minForce: '1.0.5')),
    });
    await pumpSettings(tester, adapter: adapter, store: store);

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    expect(find.text('低于 v1.0.5 的版本需强制更新'), findsOneWidget);
    expect(find.text('稍后'), findsNothing); // 强更无「稍后」
    await tester.tap(find.text('前往下载'));
    await tester.pumpAndSettle();
    expect(clipboardTexts(clipboard), <String>['https://cdn.example.com/app-v1.2.0.apk']);
    await dismissSnackBars(tester);
  });

  testWidgets('iOS 平台分流：前往下载复制 ios_url（§10.3 跳商店链接）', (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final List<MethodCall> clipboard = mockClipboard(tester);
    final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
      kControllerGithubUrl: const ScriptedResponse('{}', status: 403),
      kTestFallbackUrl: ScriptedResponse(versionJson()),
    });
    final InMemoryUpdateSettingsStore store = InMemoryUpdateSettingsStore()
      ..values[kUpdateFallbackUrlKey] = kTestFallbackUrl;
    await pumpSettings(tester, adapter: adapter, store: store);

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('前往下载'));
    await tester.pumpAndSettle();
    // binding 在测试体结束时校验 foundation 调试变量已复位（早于 addTearDown），
    // 必须在体内手动归 null。
    debugDefaultTargetPlatformOverride = null;

    expect(clipboardTexts(clipboard), <String>['https://apps.apple.com/app/id123456']);
    await dismissSnackBars(tester);
  });

  testWidgets('备源 URL 编辑：保存 → 写入 settings 键并回显', (WidgetTester tester) async {
    final InMemoryUpdateSettingsStore store = InMemoryUpdateSettingsStore();
    await pumpSettings(tester, adapter: ScriptedAdapter(<String, ScriptedResponse>{}), store: store);

    await tester.tap(find.text('更新备源'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'https://cdn.example.com/version.json');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(store.values[kUpdateFallbackUrlKey], 'https://cdn.example.com/version.json');
    expect(find.text('备源已保存'), findsOneWidget);
    expect(find.text('https://cdn.example.com/version.json'), findsOneWidget); // 行副标题回显
    await dismissSnackBars(tester);
  });

  testWidgets('备源 URL 非法（非 http(s)）→ 拒绝写入并提示', (WidgetTester tester) async {
    final InMemoryUpdateSettingsStore store = InMemoryUpdateSettingsStore();
    await pumpSettings(tester, adapter: ScriptedAdapter(<String, ScriptedResponse>{}), store: store);

    await tester.tap(find.text('更新备源'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ftp://x.example/version.json');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(store.values, isEmpty);
    expect(find.text('请输入合法的 http(s) 地址'), findsOneWidget);
    expect(find.text('未配置 · 出厂缺省（仅主源）'), findsOneWidget);
    await dismissSnackBars(tester);
  });

  testWidgets('备源 URL 编辑：取消不落库', (WidgetTester tester) async {
    final InMemoryUpdateSettingsStore store = InMemoryUpdateSettingsStore()
      ..values[kUpdateFallbackUrlKey] = kTestFallbackUrl;
    await pumpSettings(tester, adapter: ScriptedAdapter(<String, ScriptedResponse>{}), store: store);
    expect(find.text(kTestFallbackUrl), findsOneWidget); // 已配置回显

    await tester.tap(find.text('更新备源'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'https://other.example/v.json');
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    expect(store.values[kUpdateFallbackUrlKey], kTestFallbackUrl); // 原值不动
    expect(find.text(kTestFallbackUrl), findsOneWidget);
  });
}
