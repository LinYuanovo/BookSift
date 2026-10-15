/// 更新检查的 riverpod 装配 + 启动静默调度（M3 §10.1）。
///
/// 检查时机 = 启动后 5s 静默（[UpdateController.ensureStartupCheckScheduled]，
/// 由 app.dart 首帧回调接线；Timer 在控制器内、可随 provider 释放取消、
/// 测试经 [updateStartupDelayProvider] 注零）+ 关于页手动（[UpdateController.manualCheck]）。
/// 双源失败一律落 `failed` 态静默不打扰；有新版本经 [updateAvailableProvider] 暴露。
///
/// 纯服务层（update_service.dart）不依赖 flutter；本文件负责 dio / package_info_plus /
/// settings 表 KV（键 `update_fallback_url`，按任务约定放本文件，不进 core/constants.dart）。
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/db/app_database.dart';
import '../../data/repo/database_provider.dart';
import 'update_service.dart';

/// 备源 URL 的 settings 表键（任务约定：放本文件，不动 core/constants.dart）。
const String kUpdateFallbackUrlKey = 'update_fallback_url';

/// GitHub 主源 `{owner}/{repo}`（§10.1：公开发布仓库，匿名访问）。
/// ⚠ 集成者 TODO：发布前替换为实际公开仓库；替换前主源必 404 → 走静默失败口径。
const String kUpdateGithubOwner = 'booksift-app';
const String kUpdateGithubRepo = 'booksift';

/// 启动静默检查延迟（§10.1「启动后 5s」；widget 测试 override 为零避免 pending timer）。
final Provider<Duration> updateStartupDelayProvider = Provider<Duration>(
  (Ref ref) => const Duration(seconds: 5),
);

/// 更新检查专用 dio（8s 连接/读取超时；无任何鉴权拦截器——免 token 铁律 §10.1）。
final Provider<Dio> updateDioProvider = Provider<Dio>((Ref ref) {
  final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      followRedirects: true,
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

/// settings 表 KV 端口（与 core/fonts/font_ports.dart 的 FontSettingsStore 同构；
/// 独立声明保持 update 目录零反向依赖，便于注入内存 fake）。
abstract interface class UpdateSettingsStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// drift settings 表实现（只 import lib/data，不修改）。
final class DriftUpdateSettingsStore implements UpdateSettingsStore {
  DriftUpdateSettingsStore(this._db);

  final AppDatabase _db;

  @override
  Future<String?> read(String key) async {
    final Setting? row =
        await (_db.select(_db.settings)..where((Settings t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> write(String key, String value) =>
      _db.into(_db.settings).insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
}

final Provider<UpdateSettingsStore> updateSettingsStoreProvider = Provider<UpdateSettingsStore>(
  (Ref ref) => DriftUpdateSettingsStore(ref.watch(appDatabaseProvider)),
);

/// 备源 URL（'' = 出厂缺省未配置 → 单主源）。
/// 读取失败（widget 测试的 appDatabaseProvider 哨兵 / 首启竞态）回落 ''，不阻断 UI
/// ——与 collectSettingsProvider 同口径。
final FutureProvider<String> updateFallbackUrlProvider = FutureProvider<String>((Ref ref) async {
  try {
    final String? value = await ref.watch(updateSettingsStoreProvider).read(kUpdateFallbackUrlKey);
    return (value ?? '').trim();
  } catch (_) {
    return '';
  }
});

/// 本地版本（package_info_plus 平台通道）。异常/测试环境回落 [LocalVersion.unknown]
/// → 检查永不判新（静默），UI 显示「版本未知」。
final FutureProvider<LocalVersion> localVersionProvider = FutureProvider<LocalVersion>((Ref ref) async {
  try {
    final PackageInfo info = await PackageInfo.fromPlatform();
    return LocalVersion(version: info.version, buildNumber: int.tryParse(info.buildNumber));
  } catch (_) {
    return LocalVersion.unknown;
  }
});

/// UI 五态（service 三态 [UpdateOutcome] + idle/checking 两个 UI 前置态）。
enum UpdateStatus { idle, checking, updateAvailable, upToDate, failed }

/// 检查状态快照（设置页「关于」区三态文案 + 更新卡片消费）。
final class UpdateCheckState {
  const UpdateCheckState.idle() : status = UpdateStatus.idle, result = null;
  const UpdateCheckState.checking() : status = UpdateStatus.checking, result = null;

  factory UpdateCheckState.done(UpdateCheckResult result) => UpdateCheckState._(
    switch (result.outcome) {
      UpdateOutcome.updateAvailable => UpdateStatus.updateAvailable,
      UpdateOutcome.upToDate => UpdateStatus.upToDate,
      UpdateOutcome.failed => UpdateStatus.failed,
    },
    result,
  );

  const UpdateCheckState._(this.status, this.result);

  final UpdateStatus status;
  final UpdateCheckResult? result;

  UpdateInfo? get info => result?.info;
}

/// 更新检查控制器：启动静默（幂等调度）/ 关于页手动 / 状态发布。
///
/// build() 无副作用（不自行起 Timer）——只有 app.dart 接线调用
/// [ensureStartupCheckScheduled] 才调度，既有 widget 测试渲染设置页不会
/// 产生 pending timer（TESTING.md §1）。
class UpdateController extends Notifier<UpdateCheckState> {
  Timer? _startupTimer;
  bool _startupScheduled = false;
  bool _disposed = false;

  @override
  UpdateCheckState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _startupTimer?.cancel();
    });
    return const UpdateCheckState.idle();
  }

  /// 启动静默检查调度（§10.1 启动后 5s；app.dart 首帧回调调用一次）。
  /// 幂等：已调度/已检查后重复调用 no-op；provider 释放时 Timer 一并取消。
  void ensureStartupCheckScheduled() {
    if (_startupScheduled || _disposed) return;
    _startupScheduled = true;
    _startupTimer = Timer(ref.read(updateStartupDelayProvider), () {
      if (_disposed) return;
      unawaited(silentCheck());
    });
  }

  /// 静默检查：不置 checking（不打扰）；失败只落 failed 态（关于页手动检查时有文案，
  /// 启动路径无任何弹窗）。
  Future<void> silentCheck() async {
    final UpdateCheckResult result = await _run();
    if (!_disposed) state = UpdateCheckState.done(result);
  }

  /// 手动检查（设置页「关于」区）：置 checking → 结果态；返回结果供 UI 分流
  /// （更新卡片 / SnackBar 三态文案）。
  Future<UpdateCheckResult> manualCheck() async {
    state = const UpdateCheckState.checking();
    final UpdateCheckResult result = await _run();
    if (!_disposed) state = UpdateCheckState.done(result);
    return result;
  }

  Future<UpdateCheckResult> _run() async {
    try {
      final Dio dio = ref.read(updateDioProvider);
      final LocalVersion local = await ref.read(localVersionProvider.future);
      final String fallbackUrl = await ref.read(updateFallbackUrlProvider.future);
      return await UpdateChecker(
        primary: GithubReleaseSource(owner: kUpdateGithubOwner, repo: kUpdateGithubRepo, dio: dio),
        // 备源 URL 未配置（出厂缺省）→ 单主源；配置后主源任何失败自动切换。
        fallback: fallbackUrl.isEmpty ? null : StaticJsonSource(url: fallbackUrl, dio: dio),
        local: local,
      ).check();
    } on Object catch (e) {
      // 兜底：源层之外的装配/设置读取异常也收敛为 failed（静默口径，绝不向启动路径抛）。
      return UpdateCheckResult.failed(primaryFailure: toUpdateFetchException(e));
    }
  }
}

final NotifierProvider<UpdateController, UpdateCheckState> updateControllerProvider =
    NotifierProvider<UpdateController, UpdateCheckState>(UpdateController.new);

/// 有新版本时非 null（全局挂载点；本轮 UI 消费方 = 设置页「关于」区，
/// 集成者可在 app_shell 级 listen 本 provider 做启动弹窗）。
final Provider<UpdateInfo?> updateAvailableProvider = Provider<UpdateInfo?>((Ref ref) {
  final UpdateCheckState state = ref.watch(updateControllerProvider);
  return state.status == UpdateStatus.updateAvailable ? state.info : null;
});

/// 备源 URL 写入（设置页消费；写 settings 表 → invalidate 读取侧）。
class UpdateSettingsController {
  const UpdateSettingsController(this._ref);

  final Ref _ref;

  /// url.trim()；空串 = 恢复出厂缺省（未配置）。
  Future<void> setFallbackUrl(String url) async {
    await _ref.read(updateSettingsStoreProvider).write(kUpdateFallbackUrlKey, url.trim());
    _ref.invalidate(updateFallbackUrlProvider);
  }
}

final Provider<UpdateSettingsController> updateSettingsControllerProvider =
    Provider<UpdateSettingsController>(UpdateSettingsController.new);

/// 备源 URL 校验：空 = 合法（恢复出厂缺省）；非空须为绝对 http(s) URL。
bool isValidFallbackUrl(String url) {
  final String trimmed = url.trim();
  if (trimmed.isEmpty) return true;
  final Uri? parsed = Uri.tryParse(trimmed);
  return parsed != null && parsed.isAbsolute && (parsed.scheme == 'http' || parsed.scheme == 'https');
}
