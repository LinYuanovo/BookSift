/// 更新服务层测试（plain test()；TESTING.md §3.2 真实事件循环 + 脚本化 dio，零真实网络）。
///
/// 覆盖：GitHub 主源解析（含 .sha256 资产二次请求 / 约定名回退 / 免 token 守卫）、
/// version.json 备源解析、双源切换状态机（403/限流/超时/坏载荷 → 切源；双败 → failed
/// 静默）、version_code 与 semver 比对边界、min_force 强更闸门。
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/update/update_service.dart';

import 'support.dart';

/// 便捷组装：单 dio 双源（adapter 按 URL 分流）。
UpdateChecker checker({
  required ScriptedAdapter adapter,
  String? fallbackUrl = kTestFallbackUrl,
  LocalVersion local = const LocalVersion(version: '1.0.0', buildNumber: 100),
}) {
  final Dio dio = scriptedDio(adapter);
  return UpdateChecker(
    primary: testGithubSource(dio),
    fallback: fallbackUrl == null ? null : StaticJsonSource(url: fallbackUrl, dio: dio),
    local: local,
  );
}

UpdateInfo remoteInfo({String version = '1.1.0', int? code, String? minForce}) => UpdateInfo(
  version: version,
  versionCode: code,
  minForce: minForce,
  source: UpdateSourceKind.staticJson,
);

void main() {
  group('GitHub 主源解析', () {
    test('200 + 约定名资产：版本剥 v 前缀 / notes=body / apk 直链 / sha256 二次请求', () async {
      final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
        kTestGithubUrl: ScriptedResponse(githubReleaseJson()),
        kTestSha256AssetUrl: ScriptedResponse('$kTestSha256  app-v1.1.0.apk\n'),
      });
      final UpdateInfo info = await testGithubSource(scriptedDio(adapter)).fetch();
      expect(info.version, '1.1.0');
      expect(info.notes, '修复若干问题');
      expect(info.apkUrl, kTestApkUrl);
      expect(info.apkSha256, kTestSha256);
      expect(info.versionCode, isNull); // GitHub 源无 version_code → 走 semver
      expect(info.iosUrl, isNull);
      expect(info.minForce, isNull);
      expect(info.source, UpdateSourceKind.github);
      expect(adapter.requestedUrls, <String>[kTestGithubUrl, kTestSha256AssetUrl]);
    });

    test('免 token 守卫：任何请求头都不携带 Authorization', () async {
      final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
        kTestGithubUrl: ScriptedResponse(githubReleaseJson()),
        kTestSha256AssetUrl: ScriptedResponse(kTestSha256),
      });
      await testGithubSource(scriptedDio(adapter)).fetch();
      expect(adapter.requests, isNotEmpty);
      for (final RequestOptions req in adapter.requests) {
        final bool hasAuth = req.headers.keys.any((String k) => k.toLowerCase() == 'authorization');
        expect(hasAuth, isFalse, reason: '§10.1/§11.1 教训 #1：绝不携带 token → ${req.uri}');
      }
    });

    test('无 .sha256 资产 → apkSha256 null，单请求不失败', () async {
      final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
        kTestGithubUrl: ScriptedResponse(githubReleaseJson(withSha256Asset: false)),
      });
      final UpdateInfo info = await testGithubSource(scriptedDio(adapter)).fetch();
      expect(info.apkSha256, isNull);
      expect(info.apkUrl, kTestApkUrl);
      expect(adapter.requestedUrls, <String>[kTestGithubUrl]);
    });

    test('.sha256 资产请求失败 → 只丢 sha256，不失败整检查（best-effort）', () async {
      final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
        kTestGithubUrl: ScriptedResponse(githubReleaseJson()),
        kTestSha256AssetUrl: ScriptedResponse.networkError(),
      });
      final UpdateInfo info = await testGithubSource(scriptedDio(adapter)).fetch();
      expect(info.apkSha256, isNull);
      expect(info.version, '1.1.0');
    });

    test('tag 无 v 前缀 + 约定名未命中 → 回退第一个 .apk 资产', () async {
      final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
        // 资产名 app-1.2.0.apk ≠ 约定名 app-v1.2.0.apk → 触发 .apk 后缀回退。
        kTestGithubUrl: ScriptedResponse(githubReleaseJson(tag: '1.2.0', withSha256Asset: false)),
      });
      final UpdateInfo info = await testGithubSource(scriptedDio(adapter)).fetch();
      expect(info.version, '1.2.0');
      expect(info.apkUrl, kTestApkUrl);
    });

    test('失败分类：403/429/404/连接/超时/坏 JSON/缺 tag_name', () async {
      Future<UpdateFetchException> failureOf(ScriptedResponse response) async {
        final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
          kTestGithubUrl: response,
        });
        try {
          await testGithubSource(scriptedDio(adapter)).fetch();
          fail('应抛 UpdateFetchException');
        } on UpdateFetchException catch (e) {
          return e;
        }
      }

      expect(
        (await failureOf(ScriptedResponse('{"message":"API rate limit exceeded"}', status: 403))).kind,
        UpdateFetchFailureKind.forbidden,
      );
      expect((await failureOf(const ScriptedResponse('{}', status: 429))).kind, UpdateFetchFailureKind.rateLimited);
      expect((await failureOf(const ScriptedResponse('{}', status: 404))).kind, UpdateFetchFailureKind.notFound);
      expect((await failureOf(const ScriptedResponse('{}', status: 500))).kind, UpdateFetchFailureKind.http);
      expect((await failureOf(ScriptedResponse.networkError())).kind, UpdateFetchFailureKind.network);
      expect(
        (await failureOf(ScriptedResponse.networkError(DioExceptionType.connectionTimeout))).kind,
        UpdateFetchFailureKind.timeout,
      );
      expect((await failureOf(const ScriptedResponse('not json'))).kind, UpdateFetchFailureKind.badPayload);
      expect((await failureOf(const ScriptedResponse('{"body":"x"}'))).kind, UpdateFetchFailureKind.badPayload);
    });
  });

  group('version.json 备源解析', () {
    test('app.* 全字段 → UpdateInfo（seed.* 忽略）', () async {
      final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
        kTestFallbackUrl: ScriptedResponse(versionJson(minForce: '1.0.5')),
      });
      final UpdateInfo info = await StaticJsonSource(url: kTestFallbackUrl, dio: scriptedDio(adapter)).fetch();
      expect(info.version, '1.2.0');
      expect(info.versionCode, 120);
      expect(info.notes, '备源更新日志');
      expect(info.minForce, '1.0.5');
      expect(info.apkUrl, 'https://cdn.example.com/app-v1.2.0.apk');
      expect(info.apkSha256, kTestSha256);
      expect(info.iosUrl, 'https://apps.apple.com/app/id123456');
      expect(info.source, UpdateSourceKind.staticJson);
    });

    test('缺 app 对象 / 缺 version / 非法 JSON → badPayload', () async {
      Future<UpdateFetchFailureKind> kindOf(String body) async {
        final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
          kTestFallbackUrl: ScriptedResponse(body),
        });
        try {
          await StaticJsonSource(url: kTestFallbackUrl, dio: scriptedDio(adapter)).fetch();
          fail('应抛 UpdateFetchException');
        } on UpdateFetchException catch (e) {
          return e.kind;
        }
      }

      expect(await kindOf('{"seed":{}}'), UpdateFetchFailureKind.badPayload);
      expect(await kindOf('{"app":{"version_code":1}}'), UpdateFetchFailureKind.badPayload);
      expect(await kindOf('<html>404 page</html>'), UpdateFetchFailureKind.badPayload);
    });
  });

  group('双源切换状态机（UpdateChecker）', () {
    test('主源 200 有新版 → available(github)，备源不发请求', () async {
      final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
        kTestGithubUrl: ScriptedResponse(githubReleaseJson(withSha256Asset: false)),
        kTestFallbackUrl: ScriptedResponse(versionJson()),
      });
      final UpdateCheckResult result = await checker(adapter: adapter).check();
      expect(result.outcome, UpdateOutcome.updateAvailable);
      expect(result.info?.source, UpdateSourceKind.github);
      expect(result.info?.version, '1.1.0');
      expect(result.forced, isFalse);
      expect(adapter.requestedUrls, <String>[kTestGithubUrl]);
    });

    test('主源 403（限流）→ 自动切备源 200 → available(staticJson)', () async {
      final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
        kTestGithubUrl: const ScriptedResponse('{"message":"API rate limit exceeded"}', status: 403),
        kTestFallbackUrl: ScriptedResponse(versionJson()),
      });
      final UpdateCheckResult result = await checker(adapter: adapter).check();
      expect(result.outcome, UpdateOutcome.updateAvailable);
      expect(result.info?.source, UpdateSourceKind.staticJson);
      expect(result.info?.versionCode, 120);
      expect(result.primaryFailure?.kind, UpdateFetchFailureKind.forbidden);
      expect(result.fallbackFailure, isNull);
      expect(adapter.requestedUrls, <String>[kTestGithubUrl, kTestFallbackUrl]);
    });

    test('主源超时 + 备源连接失败 → failed（双源失败 = 静默口径，不抛异常）', () async {
      final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
        kTestGithubUrl: ScriptedResponse.networkError(DioExceptionType.receiveTimeout),
        kTestFallbackUrl: ScriptedResponse.networkError(),
      });
      final UpdateCheckResult result = await checker(adapter: adapter).check();
      expect(result.outcome, UpdateOutcome.failed);
      expect(result.info, isNull);
      expect(result.primaryFailure?.kind, UpdateFetchFailureKind.timeout);
      expect(result.fallbackFailure?.kind, UpdateFetchFailureKind.network);
    });

    test('主源失败 + 备源未配置（出厂缺省）→ failed，fallbackFailure null', () async {
      final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
        kTestGithubUrl: ScriptedResponse.networkError(),
      });
      final UpdateCheckResult result = await checker(adapter: adapter, fallbackUrl: null).check();
      expect(result.outcome, UpdateOutcome.failed);
      expect(result.primaryFailure?.kind, UpdateFetchFailureKind.network);
      expect(result.fallbackFailure, isNull);
      expect(adapter.requestedUrls, <String>[kTestGithubUrl]);
    });

    test('主源坏载荷也切源（badPayload → 备源 200）', () async {
      final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
        kTestGithubUrl: const ScriptedResponse('{"no_tag":true}'),
        kTestFallbackUrl: ScriptedResponse(versionJson()),
      });
      final UpdateCheckResult result = await checker(adapter: adapter).check();
      expect(result.outcome, UpdateOutcome.updateAvailable);
      expect(result.primaryFailure?.kind, UpdateFetchFailureKind.badPayload);
    });

    test('version_code 相等 → upToDate；大于 → available（§10.1 数值判定）', () async {
      Future<UpdateCheckResult> runWithCode(int code) {
        final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
          kTestGithubUrl: const ScriptedResponse('{}', status: 403),
          kTestFallbackUrl: ScriptedResponse(versionJson(versionCode: code)),
        });
        return checker(adapter: adapter, local: const LocalVersion(version: '1.0.0', buildNumber: 100)).check();
      }

      expect((await runWithCode(100)).outcome, UpdateOutcome.upToDate);
      expect((await runWithCode(101)).outcome, UpdateOutcome.updateAvailable);
      expect((await runWithCode(99)).outcome, UpdateOutcome.upToDate);
    });

    test('min_force 高于本地 → forced；不高于 → 非强制', () async {
      Future<UpdateCheckResult> runWithForce(String? minForce, LocalVersion local) {
        final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
          kTestGithubUrl: const ScriptedResponse('{}', status: 403),
          kTestFallbackUrl: ScriptedResponse(versionJson(minForce: minForce)),
        });
        return checker(adapter: adapter, local: local).check();
      }

      final UpdateCheckResult forced = await runWithForce(
        '1.0.5',
        const LocalVersion(version: '1.0.0', buildNumber: 100),
      );
      expect(forced.outcome, UpdateOutcome.updateAvailable);
      expect(forced.forced, isTrue);

      final UpdateCheckResult notForced = await runWithForce(
        '1.0.0',
        const LocalVersion(version: '1.0.0', buildNumber: 100),
      );
      expect(notForced.forced, isFalse);
    });
  });

  group('版本比对边界（纯函数）', () {
    const LocalVersion local = LocalVersion(version: '1.0.0', buildNumber: 100);

    test('version_code 数值比较：> 判新；== / < 不弹', () {
      expect(isNewerThan(remoteInfo(code: 101), local), isTrue);
      expect(isNewerThan(remoteInfo(code: 100), local), isFalse);
      expect(isNewerThan(remoteInfo(code: 99), local), isFalse);
    });

    test('version_code 优先于 semver（远端 semver 更低但 code 更大仍以 code 判）', () {
      expect(isNewerThan(remoteInfo(version: '0.9.0', code: 101), local), isTrue);
    });

    test('任一侧缺数值构建号 → 回落 semver 比较', () {
      expect(isNewerThan(remoteInfo(version: '1.1.0'), local), isTrue); // 远端 code null（GitHub 源）
      expect(isNewerThan(remoteInfo(version: '1.0.0'), local), isFalse);
      expect(
        isNewerThan(remoteInfo(version: '1.1.0', code: 110), const LocalVersion(version: '1.0.0')),
        isTrue,
      ); // 本地 buildNumber null
    });

    test('semver 数值段比较（1.10.0 > 1.9.0；v 前缀；缺段补 0；预发布后缀剥离）', () {
      expect(compareVersions('1.10.0', '1.9.0'), 1);
      expect(compareVersions('v1.0.0', '1.0.0'), 0);
      expect(compareVersions('1.0', '1.0.0'), 0);
      expect(compareVersions('2.0.0', '1.99.99'), 1);
      expect(compareVersions('1.0.0-beta', '1.0.0'), 0);
      expect(compareVersions('abc', '0.0.0'), 0); // 非法段按 0，不抛异常
    });

    test('本地版本未知 → 永不判新也不判强更（静默）', () {
      expect(isNewerThan(remoteInfo(version: '9.9.9', code: 999), LocalVersion.unknown), isFalse);
      expect(
        isForcedUpdate(remoteInfo(version: '9.9.9', minForce: '9.9.8'), LocalVersion.unknown),
        isFalse,
      );
    });

    test('min_force 闸门：< 阈值强制，≥ 阈值非强制，无阈值不强制', () {
      expect(isForcedUpdate(remoteInfo(minForce: '1.0.5'), local), isTrue);
      expect(isForcedUpdate(remoteInfo(minForce: '1.0.0'), local), isFalse);
      expect(isForcedUpdate(remoteInfo(minForce: '0.9'), local), isFalse);
      expect(isForcedUpdate(remoteInfo(), local), isFalse);
    });
  });
}
