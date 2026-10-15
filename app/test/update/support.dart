/// 更新检查测试挂具（M3 §10.1；TESTING.md §3：widget 测试零真实网络/零真实 IO）。
///
/// - [ScriptedAdapter]：按 URL 精确匹配的脚本化 dio HttpClientAdapter —— 未脚本化
///   URL 一律抛 connectionError（任何漏网请求快速失败，绝不触真 socket）；
/// - [InMemoryUpdateSettingsStore]：备源 URL KV 内存 fake；
/// - [updateTestOverrides]：widget/plain 通用的四件套 override（dio / 本地版本 /
///   settings store / 启动延迟归零）；
/// - fixture 构造器：[githubReleaseJson] / [versionJson]（§10.1 结构）。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodCall, SystemChannels;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/update/update_controller.dart';
import 'package:booksift/core/update/update_service.dart';

// ── 常量（service 层测试 owner/repo = o/r；controller/widget 层走生产常量） ──

const String kTestGithubUrl = 'https://api.github.com/repos/o/r/releases/latest';

/// UpdateController 生产常量（kUpdateGithubOwner/kUpdateGithubRepo）拼出的 latest 端点：
/// controller/widget 级测试必须脚本化这个 URL（controller 内部自建 source）。
final String kControllerGithubUrl =
    'https://api.github.com/repos/$kUpdateGithubOwner/$kUpdateGithubRepo/releases/latest';

const String kTestApkUrl = 'https://github.com/o/r/releases/download/v1.1.0/app-v1.1.0.apk';
const String kTestSha256AssetUrl = 'https://github.com/o/r/releases/download/v1.1.0/app-v1.1.0.apk.sha256';
const String kTestSha256 = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';
const String kTestFallbackUrl = 'https://cdn.example.com/booksift/version.json';

/// GitHub latest-release 端点（owner=o / repo=r，与测试常量一致）。
GithubReleaseSource testGithubSource(Dio dio) => GithubReleaseSource(owner: 'o', repo: 'r', dio: dio);

// ── 脚本化 dio ──────────────────────────────────────────────────────────

/// 单条脚本：status+body，或注入 [DioExceptionType]（模拟不可达/超时，无真实等待）；
/// [delay] = 响应前等待（widget 测试用假时钟 Timer 定格「检查中」态；plain 测试为真实短等）。
final class ScriptedResponse {
  const ScriptedResponse(this.body, {this.status = 200, this.delay}) : errorType = null;

  const ScriptedResponse.networkError([DioExceptionType type = DioExceptionType.connectionError])
    : body = '',
      status = 0,
      delay = null,
      errorType = type;

  final String body;
  final int status;
  final Duration? delay;
  final DioExceptionType? errorType;
}

/// URL 精确匹配 → 脚本响应；记录全部请求（含 headers，供免 token 守卫断言）。
final class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter(this.routes);

  final Map<String, ScriptedResponse> routes;
  final List<RequestOptions> requests = <RequestOptions>[];

  List<String> get requestedUrls => requests.map((RequestOptions r) => r.uri.toString()).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final ScriptedResponse? scripted = routes[options.uri.toString()];
    if (scripted == null) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: '未脚本化的 URL：${options.uri}（更新检查测试零真实网络）',
      );
    }
    final DioExceptionType? errorType = scripted.errorType;
    if (errorType != null) {
      throw DioException(requestOptions: options, type: errorType, error: errorType.name);
    }
    final Duration? delay = scripted.delay;
    if (delay != null) {
      await Future<void>.delayed(delay);
    }
    return ResponseBody.fromString(
      scripted.body,
      scripted.status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 生产同款超时配置的 dio + 脚本化 adapter（覆盖真实传输层，不触 socket）。
Dio scriptedDio(ScriptedAdapter adapter) =>
    Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),
    )..httpClientAdapter = adapter;

// ── fixture JSON（§10.1 结构） ──────────────────────────────────────────

/// GitHub latest release 响应；资产名走 `app-v{version}.apk[.sha256]` 约定。
String githubReleaseJson({
  String tag = 'v1.1.0',
  String body = '修复若干问题',
  bool withApk = true,
  bool withSha256Asset = true,
}) => jsonEncode(<String, Object?>{
  'tag_name': tag,
  'name': tag,
  'body': body,
  'assets': <Map<String, Object?>>[
    if (withApk) <String, Object?>{'name': 'app-$tag.apk', 'browser_download_url': kTestApkUrl},
    if (withSha256Asset)
      <String, Object?>{'name': 'app-$tag.apk.sha256', 'browser_download_url': kTestSha256AssetUrl},
  ],
});

/// 静态备源 version.json（app.* 全字段 + seed.* 干扰项——服务层必须忽略 seed）。
String versionJson({
  String version = '1.2.0',
  int versionCode = 120,
  String notes = '备源更新日志',
  String? minForce,
  String apkUrl = 'https://cdn.example.com/app-v1.2.0.apk',
  String apkSha256 = kTestSha256,
  String iosUrl = 'https://apps.apple.com/app/id123456',
}) => jsonEncode(<String, Object?>{
  'app': <String, Object?>{
    'version': version,
    'version_code': versionCode,
    'notes': notes,
    'min_force': ?minForce,
    'apk_url': apkUrl,
    'apk_sha256': apkSha256,
    'ios_url': iosUrl,
  },
  'seed': <String, Object?>{
    'basic_version': 3,
    'full_version': 3,
    'full_urls': <String>['https://cdn.example.com/seed_full_v3.db.zip'],
    'full_size': 188743680,
  },
});

// ── settings KV 内存 fake ───────────────────────────────────────────────

final class InMemoryUpdateSettingsStore implements UpdateSettingsStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

// ── Provider overrides（widget / ProviderContainer 通用） ───────────────

List<Override> updateTestOverrides({
  required ScriptedAdapter adapter,
  LocalVersion local = const LocalVersion(version: '1.0.0', buildNumber: 100),
  InMemoryUpdateSettingsStore? store,
}) => <Override>[
  updateDioProvider.overrideWithValue(scriptedDio(adapter)),
  localVersionProvider.overrideWith((Ref ref) async => local),
  updateSettingsStoreProvider.overrideWithValue(store ?? InMemoryUpdateSettingsStore()),
  // 启动静默延迟归零：widget 测试不留 5s pending timer（TESTING.md §1/§3.5）。
  updateStartupDelayProvider.overrideWithValue(Duration.zero),
];

// ── widget 测试小工具 ───────────────────────────────────────────────────

/// 高视口（设置页为 ListView，「关于」区在屏外；同 font_ui_test 的做法）。
void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// mock 系统剪贴板通道（Clipboard.setData 走 SystemChannels.platform），返回调用记录。
List<MethodCall> mockClipboard(WidgetTester tester) {
  final List<MethodCall> calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
    calls.add(call);
    return null;
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return calls;
}

/// 取全部 Clipboard.setData 的 text 参数。
List<String> clipboardTexts(List<MethodCall> calls) => calls
    .where((MethodCall c) => c.method == 'Clipboard.setData')
    .map((MethodCall c) => (c.arguments! as Map<Object?, Object?>)['text']! as String)
    .toList();
