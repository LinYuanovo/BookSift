/// 双源版本检查服务（M3 §10.1，免 token）。
///
/// 主源 = GitHub Releases API `GET /repos/{owner}/{repo}/releases/latest`：
/// 公开仓库匿名访问、**绝不携带任何 access_token**（扫书 v1.3.0 教训 #1，原型 §11.1：
/// 个人令牌打进 APK 可被任意提取；60 req/h/IP 匿名限流对「每启动一次静默 + 手动」足够）。
/// 备源 = 可配置静态 `version.json`（结构见原型 §10.1；设置页键 `update_fallback_url`
/// 自定义，出厂缺省未配置）。主源不可达 / 403 / 限流 / 解析失败 → 自动切备源；
/// 双源均失败 → 返回 `failed`（调用方静默，不打扰用户）。
///
/// 本文件为纯 Dart（只依赖 dio），可 headless 复用；riverpod 装配、package_info_plus
/// 本地版本读取与启动静默调度见 update_controller.dart。
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

// ── 失败分类 ────────────────────────────────────────────────────────────

/// 单源抓取失败类别（§10.1「主源不可达/403/限流→切备源」的判定依据；
/// 任何类别都触发切源，类别仅用于诊断与手动检查文案）。
enum UpdateFetchFailureKind {
  /// 连接失败 / DNS / TLS 等不可达。
  network,

  /// 连接或读取超时。
  timeout,

  /// HTTP 403（GitHub 匿名限流即以 403 + rate limit message 返回）。
  forbidden,

  /// HTTP 429 显式限流。
  rateLimited,

  /// HTTP 404（仓库无 release / URL 配错）。
  notFound,

  /// 其余非 2xx HTTP 状态。
  http,

  /// 状态 2xx 但载荷不是合法 JSON / 缺必需字段。
  badPayload,
}

/// 源级抓取异常（[UpdateSource.fetch] 的唯一失败出口；[UpdateChecker] 捕获后切源）。
final class UpdateFetchException implements Exception {
  const UpdateFetchException(this.kind, this.message);

  final UpdateFetchFailureKind kind;
  final String message;

  @override
  String toString() => 'UpdateFetchException(${kind.name}, $message)';
}

/// 任意异常 → [UpdateFetchException] 归类（dio 异常形态 / 超时 / JSON 解析）。
UpdateFetchException toUpdateFetchException(Object error) {
  if (error is UpdateFetchException) return error;
  if (error is TimeoutException) {
    return const UpdateFetchException(UpdateFetchFailureKind.timeout, '请求超时');
  }
  if (error is FormatException) {
    return UpdateFetchException(
      UpdateFetchFailureKind.badPayload,
      '响应不是合法 JSON：${error.message}',
    );
  }
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const UpdateFetchException(
          UpdateFetchFailureKind.timeout,
          '请求超时',
        );
      case DioExceptionType.badResponse:
        final int? code = error.response?.statusCode;
        return switch (code) {
          403 => const UpdateFetchException(
            UpdateFetchFailureKind.forbidden,
            '403（匿名限流或禁止访问）',
          ),
          429 => const UpdateFetchException(
            UpdateFetchFailureKind.rateLimited,
            '429 限流',
          ),
          404 => const UpdateFetchException(
            UpdateFetchFailureKind.notFound,
            '404 不存在',
          ),
          _ => UpdateFetchException(
            UpdateFetchFailureKind.http,
            'HTTP ${code ?? '?'}',
          ),
        };
      case DioExceptionType.connectionError:
        return UpdateFetchException(
          UpdateFetchFailureKind.network,
          '连接失败：${error.message ?? error.error}',
        );
      case DioExceptionType.badCertificate:
        return const UpdateFetchException(
          UpdateFetchFailureKind.network,
          'TLS 证书校验失败',
        );
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return UpdateFetchException(
          UpdateFetchFailureKind.network,
          '网络异常：${error.message ?? error.error}',
        );
    }
  }
  return UpdateFetchException(UpdateFetchFailureKind.network, '未知异常：$error');
}

// ── 数据模型 ────────────────────────────────────────────────────────────

/// 更新源类别（UI「来源」标注用）。
enum UpdateSourceKind {
  github('GitHub Releases'),
  staticJson('静态备源');

  const UpdateSourceKind(this.label);

  final String label;
}

/// 远端更新信息（GitHub Release JSON / version.json `app` 对象解析产物）。
final class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.source,
    this.versionCode,
    this.notes = '',
    this.apkUrl,
    this.apkSha256,
    this.iosUrl,
    this.iosSha256,
    this.windowsUrl,
    this.windowsSha256,
    this.macosUrl,
    this.macosSha256,
    this.linuxUrl,
    this.linuxSha256,
    this.minForce,
  });

  /// 语义化版本号（'1.1.0'；GitHub tag `v1.1.0` 已剥前缀）。
  final String version;

  /// version.json `app.version_code`；GitHub 源无此字段 = null（走 semver 比对）。
  final int? versionCode;

  /// 更新日志（GitHub = release body；version.json = app.notes）。
  final String notes;

  /// Android APK 直链（GitHub = assets 里 `android-v{version}.apk` 约定名；§10.2 浏览器下载）。
  final String? apkUrl;

  /// APK sha256 公示值（§11.1 缺陷 #7 对策；GitHub 源 best-effort 取 `.apk.sha256` 资产，
  /// 取不到 = null，不因此失败）。
  final String? apkSha256;

  /// iOS 安装包 URL（GitHub Release）或 version.json `ios_url`。
  final String? iosUrl;

  /// iOS IPA 的 SHA256；GitHub 源 best-effort 解析 `.ipa.sha256` 资产。
  final String? iosSha256;

  /// Windows ZIP URL（GitHub Release）或 version.json `windows_url`。
  final String? windowsUrl;

  /// Windows ZIP 的 SHA256；GitHub 源 best-effort 解析 `.zip.sha256` 资产。
  final String? windowsSha256;

  /// macOS universal ZIP URL（GitHub Release）或 version.json `macos_url`。
  final String? macosUrl;

  /// macOS ZIP 的 SHA256；GitHub 源 best-effort 解析 `.zip.sha256` 资产。
  final String? macosSha256;

  /// Linux tar.gz URL（GitHub Release）或 version.json `linux_url`。
  final String? linuxUrl;

  /// Linux tar.gz 的 SHA256；GitHub 源 best-effort 解析 `.tar.gz.sha256` 资产。
  final String? linuxSha256;

  /// 强更阈值（version.json `app.min_force`）：本地版本 < 该值 → 强制更新。
  final String? minForce;

  /// 命中来源（github / staticJson）。
  final UpdateSourceKind source;
}

/// 本地版本（package_info_plus 由 controller 侧读取注入；本层纯数据）。
final class LocalVersion {
  const LocalVersion({required this.version, this.buildNumber});

  /// 未知/读取失败的哨兵值（version 空 → 永不判新，检查静默）。
  static const LocalVersion unknown = LocalVersion(version: '');

  /// '1.0.0'（pubspec version / Android versionName / iOS CFBundleShortVersionString）。
  final String version;

  /// 构建号（Android versionCode / iOS CFBundleVersion）；解析失败 = null → 走 semver。
  final int? buildNumber;

  bool get isKnown => version.isNotEmpty;
}

// ── 版本比对（纯函数） ──────────────────────────────────────────────────

/// semver 数值段比对：剥 `v` 前缀与 `-pre/+build` 后缀，缺段/非数值段按 0。
/// 1.10.0 > 1.9.0（数值段比较，非字典序）。
int compareVersions(String a, String b) {
  final List<int> pa = _numericParts(a);
  final List<int> pb = _numericParts(b);
  final int len = pa.length > pb.length ? pa.length : pb.length;
  for (int i = 0; i < len; i++) {
    final int va = i < pa.length ? pa[i] : 0;
    final int vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va < vb ? -1 : 1;
  }
  return 0;
}

List<int> _numericParts(String v) {
  String s = v.trim();
  if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
  final int cut = s.indexOf(RegExp(r'[-+]'));
  if (cut >= 0) s = s.substring(0, cut);
  return s.split('.').map((String p) => int.tryParse(p) ?? 0).toList();
}

/// 判新规则（§10.1：`version_code` 大于本地 → 弹更新卡片）：
/// 双方都有数值构建号（version.json `version_code` × package_info buildNumber）→ 数值比较；
/// 任一侧缺失（GitHub 源无 version_code / buildNumber 非数值）→ 回落 semver 比较。
/// 本地版本未知 → 永不判新（静默，避免误弹）。
bool isNewerThan(UpdateInfo remote, LocalVersion local) {
  if (!local.isKnown) return false;
  final int? rc = remote.versionCode;
  final int? lb = local.buildNumber;
  if (rc != null && lb != null) return rc > lb;
  return compareVersions(remote.version, local.version) > 0;
}

/// 强更闸门：本地版本 < `min_force` → true（UI 隐藏「稍后」、禁点遮罩关闭）。
bool isForcedUpdate(UpdateInfo remote, LocalVersion local) {
  final String? minForce = remote.minForce;
  if (minForce == null || minForce.isEmpty || !local.isKnown) return false;
  return compareVersions(local.version, minForce) < 0;
}

// ── 更新源抽象 ──────────────────────────────────────────────────────────

/// 单个更新源；失败一律抛 [UpdateFetchException]（由 [UpdateChecker] 捕获切源）。
abstract interface class UpdateSource {
  UpdateSourceKind get kind;

  Future<UpdateInfo> fetch();
}

String? _strOrNull(Object? v) => v is String && v.isNotEmpty ? v : null;

int? _intOrNull(Object? v) => switch (v) {
  num n => n.toInt(),
  String s => int.tryParse(s),
  _ => null,
};

/// 主源：GitHub Releases API（匿名，无 token）。
///
/// 解析约定：`tag_name` → 版本；`body` → 更新日志；五个平台资产按固定名称匹配，
/// 对应 `.sha256` 文件 best-effort 取内容首个 64 位 hex。缺失的资产保持 null，互不回退。
final class GithubReleaseSource implements UpdateSource {
  GithubReleaseSource({
    required this.owner,
    required this.repo,
    required Dio dio,
    this.timeout = const Duration(seconds: 10),
  }) : _dio = dio;

  final String owner;
  final String repo;
  final Dio _dio;
  final Duration timeout;

  @override
  UpdateSourceKind get kind => UpdateSourceKind.github;

  /// latest release 端点（公开仓库匿名可访问）。
  Uri get latestUri =>
      Uri.https('api.github.com', '/repos/$owner/$repo/releases/latest');

  @override
  Future<UpdateInfo> fetch() async {
    final Map<String, Object?> data = await _getJson(latestUri.toString());
    final String? tag = _strOrNull(data['tag_name']);
    if (tag == null) {
      throw const UpdateFetchException(
        UpdateFetchFailureKind.badPayload,
        'release 缺 tag_name',
      );
    }
    final String version = tag.startsWith('v') ? tag.substring(1) : tag;
    final String notes = _strOrNull(data['body']) ?? '';

    final List<Object?> assets = data['assets'] is List
        ? data['assets']! as List<Object?>
        : const <Object?>[];
    String? assetUrl(String name) {
      for (final Object? a in assets) {
        if (a is Map && _strOrNull(a['name']) == name) {
          final String? url = _strOrNull(a['browser_download_url']);
          if (url != null) return url;
        }
      }
      return null;
    }

    final String apkAssetName = 'android-v$version.apk';
    final String iosAssetName = 'ios-v$version.ipa';
    final String windowsAssetName = 'windows-x64-v$version.zip';
    final String macosAssetName = 'macos-universal-v$version.zip';
    final String linuxAssetName = 'linux-x64-v$version.tar.gz';

    final String? apkUrl = assetUrl(apkAssetName);
    final String? iosUrl = assetUrl(iosAssetName);
    final String? windowsUrl = assetUrl(windowsAssetName);
    final String? macosUrl = assetUrl(macosAssetName);
    final String? linuxUrl = assetUrl(linuxAssetName);

    final List<String?> hashes = await Future.wait<String?>(<Future<String?>>[
      _fetchSha256Asset(
        apkUrl == null ? null : assetUrl('$apkAssetName.sha256'),
      ),
      _fetchSha256Asset(
        iosUrl == null ? null : assetUrl('$iosAssetName.sha256'),
      ),
      _fetchSha256Asset(
        windowsUrl == null ? null : assetUrl('$windowsAssetName.sha256'),
      ),
      _fetchSha256Asset(
        macosUrl == null ? null : assetUrl('$macosAssetName.sha256'),
      ),
      _fetchSha256Asset(
        linuxUrl == null ? null : assetUrl('$linuxAssetName.sha256'),
      ),
    ]);

    return UpdateInfo(
      version: version,
      source: kind,
      notes: notes,
      apkUrl: apkUrl,
      apkSha256: hashes[0],
      iosUrl: iosUrl,
      iosSha256: hashes[1],
      windowsUrl: windowsUrl,
      windowsSha256: hashes[2],
      macosUrl: macosUrl,
      macosSha256: hashes[3],
      linuxUrl: linuxUrl,
      linuxSha256: hashes[4],
    );
  }

  /// `.sha256` 资产内容 = `<hex64>[  <filename>]`；取首个 64 位 hex，失败 → null（不失败整检查）。
  Future<String?> _fetchSha256Asset(String? url) async {
    if (url == null) return null;
    try {
      final Response<String> res = await _dio
          .get<String>(url, options: Options(responseType: ResponseType.plain))
          .timeout(timeout);
      final RegExpMatch? m = RegExp(
        r'[0-9a-fA-F]{64}',
      ).firstMatch(res.data ?? '');
      return m?[0]?.toLowerCase();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Object?>> _getJson(String url) async {
    final Response<String> res;
    try {
      res = await _dio
          .get<String>(
            url,
            options: Options(
              responseType:
                  ResponseType.plain, // 手动 jsonDecode：不依赖对端 content-type 正确性
              headers: <String, String>{
                'Accept': 'application/vnd.github+json',
                'X-GitHub-Api-Version': '2022-11-28',
                // ⚠ 免 token 铁律（§10.1/§11.1 教训 #1）：此处绝不附加 Authorization。
              },
            ),
          )
          .timeout(timeout);
    } catch (e) {
      throw toUpdateFetchException(e);
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(res.data ?? '');
    } on FormatException catch (e) {
      throw toUpdateFetchException(e);
    }
    if (decoded is! Map) {
      throw const UpdateFetchException(
        UpdateFetchFailureKind.badPayload,
        '响应不是 JSON 对象',
      );
    }
    return decoded.cast<String, Object?>();
  }
}

/// 备源：静态 version.json（可配置 URL；出厂缺省未配置 → 不参与检查）。
///
/// 结构：`{"app": {"version","version_code","notes","min_force",
/// "apk_url","apk_sha256","ios_url","ios_sha256","windows_url","windows_sha256",
/// "macos_url","macos_sha256","linux_url","linux_sha256"}, "seed": {...}}`
/// —— seed.* 属种子包分发，本服务忽略。
final class StaticJsonSource implements UpdateSource {
  StaticJsonSource({
    required this.url,
    required Dio dio,
    this.timeout = const Duration(seconds: 10),
  }) : _dio = dio;

  final String url;
  final Dio _dio;
  final Duration timeout;

  @override
  UpdateSourceKind get kind => UpdateSourceKind.staticJson;

  @override
  Future<UpdateInfo> fetch() async {
    final Response<String> res;
    try {
      res = await _dio
          .get<String>(url, options: Options(responseType: ResponseType.plain))
          .timeout(timeout);
    } catch (e) {
      throw toUpdateFetchException(e);
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(res.data ?? '');
    } on FormatException catch (e) {
      throw toUpdateFetchException(e);
    }
    if (decoded is! Map) {
      throw const UpdateFetchException(
        UpdateFetchFailureKind.badPayload,
        'version.json 不是 JSON 对象',
      );
    }
    final Object? app = decoded['app'];
    if (app is! Map) {
      throw const UpdateFetchException(
        UpdateFetchFailureKind.badPayload,
        'version.json 缺 app 对象',
      );
    }
    final String? version = _strOrNull(app['version']);
    if (version == null) {
      throw const UpdateFetchException(
        UpdateFetchFailureKind.badPayload,
        'version.json app.version 缺失',
      );
    }
    return UpdateInfo(
      version: version,
      source: kind,
      versionCode: _intOrNull(app['version_code']),
      notes: _strOrNull(app['notes']) ?? '',
      apkUrl: _strOrNull(app['apk_url']),
      apkSha256: _strOrNull(app['apk_sha256'])?.toLowerCase(),
      iosUrl: _strOrNull(app['ios_url']),
      iosSha256: _strOrNull(app['ios_sha256'])?.toLowerCase(),
      windowsUrl: _strOrNull(app['windows_url']),
      windowsSha256: _strOrNull(app['windows_sha256'])?.toLowerCase(),
      macosUrl: _strOrNull(app['macos_url']),
      macosSha256: _strOrNull(app['macos_sha256'])?.toLowerCase(),
      linuxUrl: _strOrNull(app['linux_url']),
      linuxSha256: _strOrNull(app['linux_sha256'])?.toLowerCase(),
      minForce: _strOrNull(app['min_force']),
    );
  }
}

// ── 双源编排 ────────────────────────────────────────────────────────────

/// 检查结论三态（idle/checking 属 UI 态，见 update_controller.dart 的 UpdateStatus）。
enum UpdateOutcome { updateAvailable, upToDate, failed }

/// 一次检查的结果（failed 携带双源各自的失败归类，供诊断/手动检查文案）。
final class UpdateCheckResult {
  const UpdateCheckResult(
    this.outcome, {
    this.info,
    this.forced = false,
    this.primaryFailure,
    this.fallbackFailure,
  });

  factory UpdateCheckResult.failed({
    UpdateFetchException? primaryFailure,
    UpdateFetchException? fallbackFailure,
  }) => UpdateCheckResult(
    UpdateOutcome.failed,
    primaryFailure: primaryFailure,
    fallbackFailure: fallbackFailure,
  );

  final UpdateOutcome outcome;

  /// available / upToDate 时非空（命中源的解析产物）。
  final UpdateInfo? info;

  /// available 且本地 < min_force（强更）。
  final bool forced;

  /// 主源失败归类：failed 时 = 主源失败原因；**经备源命中成功时也保留**
  /// （诊断「为何切了源」，如 403 限流）。主源直接成功 = null。
  final UpdateFetchException? primaryFailure;

  /// 备源未配置时恒为 null（无源可切）。
  final UpdateFetchException? fallbackFailure;
}

/// 双源切换状态机：主源任何失败（不可达/403/限流/超时/载荷非法）→ 切备源；
/// 备源也失败或未配置 → [UpdateCheckResult.failed]（调用方静默，不打扰）。
final class UpdateChecker {
  const UpdateChecker({
    required this.primary,
    required this.local,
    this.fallback,
  });

  final UpdateSource primary;

  /// null = 备源 URL 未配置（出厂缺省）→ 单主源。
  final UpdateSource? fallback;

  final LocalVersion local;

  Future<UpdateCheckResult> check() async {
    try {
      return _evaluate(await primary.fetch());
    } on Object catch (e) {
      final UpdateFetchException primaryFailure = toUpdateFetchException(e);
      final UpdateSource? fb = fallback;
      if (fb == null) {
        return UpdateCheckResult.failed(primaryFailure: primaryFailure);
      }
      try {
        // 备源命中也携带主源失败归类（诊断切源原因）。
        return _evaluate(await fb.fetch(), primaryFailure: primaryFailure);
      } on Object catch (e2) {
        return UpdateCheckResult.failed(
          primaryFailure: primaryFailure,
          fallbackFailure: toUpdateFetchException(e2),
        );
      }
    }
  }

  UpdateCheckResult _evaluate(
    UpdateInfo info, {
    UpdateFetchException? primaryFailure,
  }) {
    if (isNewerThan(info, local)) {
      return UpdateCheckResult(
        UpdateOutcome.updateAvailable,
        info: info,
        forced: isForcedUpdate(info, local),
        primaryFailure: primaryFailure,
      );
    }
    return UpdateCheckResult(
      UpdateOutcome.upToDate,
      info: info,
      primaryFailure: primaryFailure,
    );
  }
}
