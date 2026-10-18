/// 设置页「关于」区 widget 测试（testWidgets；TESTING.md §3.1 全内存 fake：
/// 脚本化 dio + InMemory settings store + 固定本地版本 + 启动延迟归零，零真实网络/IO）。
///
/// 覆盖：关于区渲染与零请求、手动检查三态（检查中/已最新/失败）、更新卡片
/// （版本号+日志+来源+前往下载复制 apk/ios 链接）、min_force 强更形态、
/// 主源 403 → 备源切换呈现、备源 URL 编辑持久化与非法输入拒绝。
library;

import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart'
    show ByteData, FontLoader, MethodCall, Uint8List;
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/fonts/font_tokens.dart';
import 'package:booksift/core/update/update_controller.dart';
import 'package:booksift/core/update/update_download_controller.dart';
import 'package:booksift/core/update/update_downloader.dart';
import 'package:booksift/core/update/update_platform.dart';
import 'package:booksift/core/update/update_service.dart';
import 'package:booksift/features/profile/settings_page.dart';
import 'package:booksift/theme/book_theme.dart';

import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import '../support/harness.dart';
import 'support.dart';

bool get _wantShots => Platform.environment['SHOTS'] == 'true';

bool _fontsLoaded = false;
const String _shotFont = 'UpdateShotFont';

Future<void> _loadShotFont() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  final File file = File(r'C:\Windows\Fonts\simhei.ttf');
  if (!await file.exists()) return;
  final Uint8List bytes = await file.readAsBytes();
  final FontLoader loader = FontLoader(_shotFont)
    ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

Future<void> _captureUpdateCard(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  final Directory output = Directory('build/shots');
  await tester.runAsync(() async {
    if (!output.existsSync()) output.createSync(recursive: true);
    final RenderRepaintBoundary boundary = tester
        .renderObject<RenderRepaintBoundary>(find.byKey(key));
    final ui.Image image = await boundary.toImage(pixelRatio: 1.5);
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    if (data == null) return;
    await File(
      '${output.path}/$name.png',
    ).writeAsBytes(data.buffer.asUint8List());
  });
}

FontFamilySet get _shotFamilies => const FontFamilySet(
  display: _shotFont,
  title: _shotFont,
  headline: _shotFont,
  cardTitle: _shotFont,
  body: _shotFont,
  bodyRich: _shotFont,
  secondary: _shotFont,
  caption: _shotFont,
  label: _shotFont,
  mono: _shotFont,
);

String versionJsonWithPlatformUrls({Set<String> omitted = const <String>{}}) {
  final Map<String, Object?> json = (jsonDecode(versionJson()) as Map)
      .cast<String, Object?>();
  final Map<String, Object?> app = (json['app']! as Map)
      .cast<String, Object?>();
  app.addAll(<String, String>{
    'apk_url': 'https://cdn.example.com/android-v1.2.0.apk',
    'ios_url': 'https://cdn.example.com/ios-v1.2.0.ipa',
    'windows_url': 'https://cdn.example.com/windows-x64-v1.2.0.zip',
    'macos_url': 'https://cdn.example.com/macos-universal-v1.2.0.zip',
    'linux_url': 'https://cdn.example.com/linux-x64-v1.2.0.tar.gz',
  });
  for (final String key in omitted) {
    app.remove(key);
  }
  json['app'] = app;
  return jsonEncode(json);
}

UpdateInfo shotUpdateInfo() => UpdateInfo(
  version: '1.2.0',
  source: UpdateSourceKind.github,
  apkUrl: 'https://example.com/android-v1.2.0.apk',
  notes: '修复若干问题，并优化下载与安装体验。',
);

Future<void> pumpSettings(
  WidgetTester tester, {
  required ScriptedAdapter adapter,
  InMemoryUpdateSettingsStore? store,
  UpdateDownloader? downloader,
  UpdatePlatformPort? platform,
  LocalVersion local = const LocalVersion(version: '1.0.0', buildNumber: 100),
}) async {
  useTallSurface(tester);
  final List<Override> overrides = updateTestOverrides(
    adapter: adapter,
    local: local,
    store: store,
  );
  if (downloader != null) {
    overrides.add(updateDownloaderProvider.overrideWithValue(downloader));
  }
  if (platform != null) {
    overrides.add(updatePlatformProvider.overrideWithValue(platform));
  }
  await tester.pumpWidget(
    testApp(
      FakeBookRepository(library: demoLibrary()),
      home: const SettingsPage(),
      extraOverrides: overrides,
    ),
  );
  await tester.pumpAndSettle();
}

final class FakeUpdateDownloader implements UpdateDownloader {
  FakeUpdateDownloader({this.waitForCancel = false});

  final bool waitForCancel;
  int calls = 0;
  UpdateDownloadRequest? lastRequest;

  @override
  Future<UpdateDownloadResult> download(
    UpdateDownloadRequest request, {
    void Function(UpdateDownloadProgress progress)? onProgress,
    CancelToken? cancelToken,
  }) {
    calls++;
    lastRequest = request;
    onProgress?.call(
      const UpdateDownloadProgress(
        downloadedBytes: 512,
        totalBytes: 1024,
        completedChunks: 0,
        totalChunks: 1,
        activeChunks: 1,
      ),
    );
    final UpdateDownloadResult result = UpdateDownloadResult(
      file: File('/fake/update.apk'),
      bytes: 1024,
      sha256: 'a' * 64,
      reusedCache: false,
      resumed: false,
    );
    if (!waitForCancel) return Future<UpdateDownloadResult>.value(result);
    final Completer<UpdateDownloadResult> completer =
        Completer<UpdateDownloadResult>();
    cancelToken!.whenCancel.then<void>((DioException error) {
      if (!completer.isCompleted) completer.completeError(error);
    });
    return completer.future;
  }
}

final class FakeUpdatePlatform implements UpdatePlatformPort {
  final List<(String, TargetPlatform)> openedFiles =
      <(String, TargetPlatform)>[];

  @override
  Future<Directory> getApplicationCacheDirectory() async =>
      Directory('/fake/cache');

  @override
  Future<Directory> getApplicationSupportDirectory() async =>
      Directory('/fake/support');

  @override
  Future<bool> openDownloadedFile(String path, TargetPlatform target) async {
    openedFiles.add((path, target));
    return true;
  }

  @override
  Future<bool> installDownloadedFile(String path, TargetPlatform target) async {
    openedFiles.add((path, target));
    return true;
  }

  @override
  Future<bool> openExternalUrl(String url) async => true;
}

void main() {
  testWidgets('关于区渲染：版本号 + idle 文案 + 备源缺省；渲染本身零请求', (
    WidgetTester tester,
  ) async {
    final ScriptedAdapter adapter = ScriptedAdapter(
      <String, ScriptedResponse>{},
    );
    await pumpSettings(tester, adapter: adapter);

    expect(find.text('关于'), findsOneWidget);
    expect(find.text('当前版本'), findsOneWidget);
    expect(find.text('v1.0.0 (100)'), findsOneWidget);
    expect(find.text('GitHub 主源和静态备源 · 主源失败时自动切换'), findsOneWidget);
    expect(find.text('更新备源'), findsOneWidget);
    expect(find.text('默认设置 · 仅检查 GitHub 主源'), findsOneWidget);
    expect(adapter.requests, isEmpty); // 打开设置页不发任何检查请求（静默检查只由 app 接线调度）
  });

  testWidgets('本地版本未知（package_info 失败回落）→ 显示「版本未知」', (
    WidgetTester tester,
  ) async {
    await pumpSettings(
      tester,
      adapter: ScriptedAdapter(<String, ScriptedResponse>{}),
      local: LocalVersion.unknown,
    );
    expect(find.text('版本未知'), findsOneWidget);
  });

  testWidgets('手动检查：检查中 → 更新卡片 → 前往下载复制 apk 链接 + SnackBar', (
    WidgetTester tester,
  ) async {
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
    expect(clipboardTexts(clipboard), <String>[
      kTestApkUrl,
    ]); // Android 平台缺省 → apk_url
    expect(find.text('下载链接已复制'), findsOneWidget);
    await dismissSnackBars(tester);
  });

  testWidgets('下载更新：显示进度并在校验完成后打开当前平台文件', (WidgetTester tester) async {
    final FakeUpdateDownloader downloader = FakeUpdateDownloader();
    final FakeUpdatePlatform platform = FakeUpdatePlatform();
    await pumpSettings(
      tester,
      adapter: ScriptedAdapter(<String, ScriptedResponse>{
        kControllerGithubUrl: ScriptedResponse(
          githubReleaseJson(withSha256Asset: false),
        ),
      }),
      downloader: downloader,
      platform: platform,
    );

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下载更新'));
    await tester.pumpAndSettle();

    expect(downloader.calls, 1);
    expect(downloader.lastRequest?.fileName, 'android-v1.1.0.apk');
    expect(find.text('更新包已就绪 · 1.0 KB'), findsOneWidget);
    expect(find.text('安装更新'), findsOneWidget);
    expect(find.text('将唤起系统安装器；首次安装需允许“安装未知应用”'), findsOneWidget);
    expect(platform.openedFiles, <(String, TargetPlatform)>[
      ('/fake/update.apk', TargetPlatform.android),
    ]);
  });

  testWidgets('截图：Android 下载完成状态面板', (WidgetTester tester) async {
    await tester.runAsync(_loadShotFont);
    await tester.binding.setSurfaceSize(const Size(720, 620));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final GlobalKey boundaryKey = GlobalKey(debugLabel: 'update-shot');
    final UpdateInfo info = shotUpdateInfo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          updateDownloaderProvider.overrideWithValue(FakeUpdateDownloader()),
          updatePlatformProvider.overrideWithValue(FakeUpdatePlatform()),
        ],
        child: MaterialApp(
          theme: BookTheme.of(Brightness.light, _shotFamilies),
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: UpdateDialog(
                  info: info,
                  forced: false,
                  onCopy: (_) {},
                  onDownload: (WidgetRef ref) async {
                    await ref
                        .read(updateDownloadControllerProvider.notifier)
                        .download(info, target: TargetPlatform.android);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('下载更新'));
    await tester.pumpAndSettle();
    await _captureUpdateCard(tester, boundaryKey, 'update-download-ready');
  }, skip: !_wantShots);

  testWidgets('下载状态面板按五个平台显示各自包与安装动作', (WidgetTester tester) async {
    const List<(TargetPlatform, String, String, String)> routes =
        <(TargetPlatform, String, String, String)>[
          (
            TargetPlatform.android,
            'android-v1.2.0.apk',
            '安装更新',
            '将唤起系统安装器；首次安装需允许“安装未知应用”',
          ),
          (
            TargetPlatform.iOS,
            'ios-v1.2.0.ipa',
            '打开文件位置',
            '将打开系统文件面板；IPA 仍需自行签名安装',
          ),
          (
            TargetPlatform.windows,
            'windows-x64-v1.2.0.zip',
            '安装更新',
            '将自动解压、备份并替换当前安装，然后重新启动',
          ),
          (
            TargetPlatform.macOS,
            'macos-universal-v1.2.0.zip',
            '打开更新包',
            '将打开 macOS 程序包；未签名包可能被 Gatekeeper 拦截',
          ),
          (
            TargetPlatform.linux,
            'linux-x64-v1.2.0.tar.gz',
            '安装更新',
            '将自动解压、备份并替换当前安装，然后重新启动',
          ),
        ];
    final InMemoryUpdateSettingsStore store = InMemoryUpdateSettingsStore()
      ..values[kUpdateFallbackUrlKey] = kTestFallbackUrl;
    try {
      for (final (
            TargetPlatform platform,
            String fileName,
            String action,
            String hint,
          )
          in routes) {
        debugDefaultTargetPlatformOverride = platform;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        final FakeUpdateDownloader downloader = FakeUpdateDownloader();
        await pumpSettings(
          tester,
          adapter: ScriptedAdapter(<String, ScriptedResponse>{
            kControllerGithubUrl: const ScriptedResponse('{}', status: 403),
            kTestFallbackUrl: ScriptedResponse(versionJsonWithPlatformUrls()),
          }),
          store: store,
          downloader: downloader,
          platform: FakeUpdatePlatform(),
        );

        await tester.tap(find.text('检查更新'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(fileName),
          findsOneWidget,
          reason: '$platform 应显示本平台更新包',
        );
        await tester.tap(find.text('下载更新'));
        await tester.pumpAndSettle();

        expect(downloader.lastRequest?.fileName, fileName);
        expect(find.text(action), findsOneWidget);
        expect(find.text(hint), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('取消下载：状态保留在卡片并提示可以续传', (WidgetTester tester) async {
    final FakeUpdateDownloader downloader = FakeUpdateDownloader(
      waitForCancel: true,
    );
    await pumpSettings(
      tester,
      adapter: ScriptedAdapter(<String, ScriptedResponse>{
        kControllerGithubUrl: ScriptedResponse(
          githubReleaseJson(withSha256Asset: false),
        ),
      }),
      downloader: downloader,
      platform: FakeUpdatePlatform(),
    );

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下载更新'));
    await tester.pump();
    expect(find.text('取消下载'), findsOneWidget);

    await tester.tap(find.text('取消下载'));
    await tester.pumpAndSettle();
    expect(find.text('已取消下载 · 缓存已保留'), findsOneWidget);
    expect(find.text('重新下载'), findsOneWidget);
  });

  testWidgets('手动检查：已最新 → SnackBar「当前已是最新版本」，无弹窗', (WidgetTester tester) async {
    final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
      kControllerGithubUrl: ScriptedResponse(
        githubReleaseJson(tag: 'v1.0.0', withSha256Asset: false),
      ),
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
    expect(adapter.requestedUrls, <String>[
      kControllerGithubUrl,
      kTestFallbackUrl,
    ]);
    await dismissSnackBars(tester);
  });

  testWidgets('主源 403 → 自动切备源：更新卡片标注静态备源', (WidgetTester tester) async {
    final InMemoryUpdateSettingsStore store = InMemoryUpdateSettingsStore()
      ..values[kUpdateFallbackUrlKey] = kTestFallbackUrl;
    final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
      kControllerGithubUrl: const ScriptedResponse(
        '{"message":"API rate limit exceeded"}',
        status: 403,
      ),
      kTestFallbackUrl: ScriptedResponse(versionJson()),
    });
    await pumpSettings(tester, adapter: adapter, store: store);

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('v1.2.0'), findsOneWidget);
    expect(find.text('来源 静态备源'), findsOneWidget);
    expect(find.text('备源更新日志'), findsOneWidget);
    expect(adapter.requestedUrls, <String>[
      kControllerGithubUrl,
      kTestFallbackUrl,
    ]);

    await tester.tap(find.text('稍后'));
    await tester.pumpAndSettle();
    expect(find.text('发现新版本 v1.2.0'), findsOneWidget); // 行内保留提示
  });

  testWidgets('min_force 强更：卡片无「稍后」并标注强制更新（GitHub 源无 min_force，走备源呈现）', (
    WidgetTester tester,
  ) async {
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
    expect(clipboardTexts(clipboard), <String>[
      'https://cdn.example.com/android-v1.2.0.apk',
    ]);
    await dismissSnackBars(tester);
  });

  testWidgets('五个平台只复制各自的更新链接', (WidgetTester tester) async {
    final List<MethodCall> clipboard = mockClipboard(tester);
    final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
      kControllerGithubUrl: const ScriptedResponse('{}', status: 403),
      kTestFallbackUrl: ScriptedResponse(versionJsonWithPlatformUrls()),
    });
    final InMemoryUpdateSettingsStore store = InMemoryUpdateSettingsStore()
      ..values[kUpdateFallbackUrlKey] = kTestFallbackUrl;
    await pumpSettings(tester, adapter: adapter, store: store);

    const List<(TargetPlatform, String)> routes = <(TargetPlatform, String)>[
      (TargetPlatform.android, 'https://cdn.example.com/android-v1.2.0.apk'),
      (TargetPlatform.iOS, 'https://cdn.example.com/ios-v1.2.0.ipa'),
      (
        TargetPlatform.windows,
        'https://cdn.example.com/windows-x64-v1.2.0.zip',
      ),
      (
        TargetPlatform.macOS,
        'https://cdn.example.com/macos-universal-v1.2.0.zip',
      ),
      (TargetPlatform.linux, 'https://cdn.example.com/linux-x64-v1.2.0.tar.gz'),
    ];
    try {
      for (final (TargetPlatform platform, String expectedUrl) in routes) {
        debugDefaultTargetPlatformOverride = platform;
        await tester.tap(find.text('检查更新'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('前往下载'));
        await tester.pumpAndSettle();
        expect(
          clipboardTexts(clipboard).last,
          expectedUrl,
          reason: '$platform 必须选择自己的下载链接',
        );
        await dismissSnackBars(tester);
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('五个平台缺少本端链接时不复制其他平台链接', (WidgetTester tester) async {
    final List<MethodCall> clipboard = mockClipboard(tester);
    final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
      kControllerGithubUrl: const ScriptedResponse('{}', status: 403),
      kTestFallbackUrl: ScriptedResponse(versionJson()),
    });
    final InMemoryUpdateSettingsStore store = InMemoryUpdateSettingsStore()
      ..values[kUpdateFallbackUrlKey] = kTestFallbackUrl;
    await pumpSettings(tester, adapter: adapter, store: store);

    const List<(TargetPlatform, String)> missingRoutes =
        <(TargetPlatform, String)>[
          (TargetPlatform.android, 'apk_url'),
          (TargetPlatform.iOS, 'ios_url'),
          (TargetPlatform.windows, 'windows_url'),
          (TargetPlatform.macOS, 'macos_url'),
          (TargetPlatform.linux, 'linux_url'),
        ];
    try {
      for (final (TargetPlatform platform, String field) in missingRoutes) {
        adapter.routes[kTestFallbackUrl] = ScriptedResponse(
          versionJsonWithPlatformUrls(omitted: <String>{field}),
        );
        debugDefaultTargetPlatformOverride = platform;
        await tester.tap(find.text('检查更新'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('前往下载'));
        await tester.pumpAndSettle();
        expect(
          clipboardTexts(clipboard),
          isEmpty,
          reason: '$platform 缺少 $field 时不得复制其他平台链接',
        );
        expect(find.text('该版本未提供下载链接'), findsOneWidget);
        await dismissSnackBars(tester);
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('备源 URL 编辑：保存 → 写入 settings 键并回显', (WidgetTester tester) async {
    final InMemoryUpdateSettingsStore store = InMemoryUpdateSettingsStore();
    await pumpSettings(
      tester,
      adapter: ScriptedAdapter(<String, ScriptedResponse>{}),
      store: store,
    );

    await tester.tap(find.text('更新备源'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'https://cdn.example.com/version.json',
    );
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(
      store.values[kUpdateFallbackUrlKey],
      'https://cdn.example.com/version.json',
    );
    expect(find.text('备源已保存'), findsOneWidget);
    expect(
      find.text('https://cdn.example.com/version.json'),
      findsOneWidget,
    ); // 行副标题回显
    await dismissSnackBars(tester);
  });

  testWidgets('备源 URL 非法（非 http(s)）→ 拒绝写入并提示', (WidgetTester tester) async {
    final InMemoryUpdateSettingsStore store = InMemoryUpdateSettingsStore();
    await pumpSettings(
      tester,
      adapter: ScriptedAdapter(<String, ScriptedResponse>{}),
      store: store,
    );

    await tester.tap(find.text('更新备源'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'ftp://x.example/version.json',
    );
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(store.values, isEmpty);
    expect(find.text('请输入合法的 http(s) 地址'), findsOneWidget);
    expect(find.text('默认设置 · 仅检查 GitHub 主源'), findsOneWidget);
    await dismissSnackBars(tester);
  });

  testWidgets('备源 URL 编辑：取消不落库', (WidgetTester tester) async {
    final InMemoryUpdateSettingsStore store = InMemoryUpdateSettingsStore()
      ..values[kUpdateFallbackUrlKey] = kTestFallbackUrl;
    await pumpSettings(
      tester,
      adapter: ScriptedAdapter(<String, ScriptedResponse>{}),
      store: store,
    );
    expect(find.text(kTestFallbackUrl), findsOneWidget); // 已配置回显

    await tester.tap(find.text('更新备源'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'https://other.example/v.json',
    );
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    expect(store.values[kUpdateFallbackUrlKey], kTestFallbackUrl); // 原值不动
    expect(find.text(kTestFallbackUrl), findsOneWidget);
  });
}
