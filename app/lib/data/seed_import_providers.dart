import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../collector/collect_providers.dart';
import '../core/constants.dart';
import 'fts_index.dart';
import 'maintenance.dart';
import 'repo/database_provider.dart';
import 'repo/queries_providers.dart';
import 'seed_import.dart';

/// 种子导入机制单例（原型 §9.2；机制在 seed_import.dart，本文件只做 riverpod 装配）。
final Provider<SeedImporter> seedImporterProvider = Provider<SeedImporter>((Ref ref) {
  return DefaultSeedImporter(ref.watch(appDatabaseProvider));
});

/// FTS 索引档位服务单例（切档/删除/重建；路径与 DefaultSeedImporter._databasePath 同口径）。
final FutureProvider<FtsIndexService> ftsIndexServiceProvider = FutureProvider<FtsIndexService>((Ref ref) async {
  final String dbPath = p.join(
    (await getApplicationDocumentsDirectory()).path,
    '${AppConstants.databaseName}.sqlite',
  );
  return DefaultFtsIndexService(dbPath);
});

/// 后台数据维护总开关（book_entries 去重 + 存量帖 v3 分类回填，机制在 maintenance.dart）。
///
/// 默认在 `flutter test` 环境关闭——flutter_tools 会给测试进程注入环境变量
/// FLUTTER_TEST=true（Platform.environment 同步读取，FakeAsync 区内亦安全）；
/// widget/plain 测试因此不会触碰真实维护（路径解析 / 词典读取 / isolate 全是真实
/// 异步，见 test/TESTING.md §1）。集成测试可 override 本 provider 显式打开。
final Provider<bool> maintenanceEnabledProvider = Provider<bool>(
  (Ref ref) => Platform.environment['FLUTTER_TEST'] != 'true',
);

/// 首启种子导入引导（P0-1，原型 §9.2 seedImportControllerProvider 状态机）。
///
/// [ensureStarted] 幂等：版本闸门通过 → importBasic 流直接映射为状态；导入完成
/// （或早已导入）后 FTS 未就绪时**静默后台重建/续跑**——done 态不被 FTS 进度覆盖，
/// 检索层对 FTS 缺失已有 LIKE 降级 + 诚实提示，无需阻塞界面。
/// 失败仅在导入本体异常时置 error（UI 重试 = 再次 [ensureStarted]）；FTS 后台
/// 失败只记日志（best-effort，重启自动续跑）。
///
/// FTS 档位（docs/2026-10-20_FTS索引可选化改造方案.md）：
/// - 首次导入前进入 [SeedImportPhase.awaitingChoice]，由 UI 调用 [chooseFtsMode]；
/// - 老库（无 settings.fts_mode）启动时按实际能力回填，**不弹框、不重建**；
/// - 之后每次启动只做 `built != desired` 的后台自愈。
///
/// 接线点：app.dart initState 首帧后调度（与启动更新检查同款模式）。
class SeedBootstrapController extends Notifier<SeedImportState> {
  bool _running = false;

  @override
  SeedImportState build() => const SeedImportState();

  /// 老库回填 + 启动自愈（幂等）。
  Future<void> ensureStarted() async {
    if (_running || state.isImporting) {
      return;
    }
    _running = true;
    try {
      final SeedImporter importer = ref.read(seedImporterProvider);
      final bool needsImport = await importer.needsBasicImport();
      FtsMode? desired = await importer.readFtsMode();
      if (desired == null) {
        if (needsImport) {
          // 首启：先让用户选档位；不选不导入（关掉弹框 = off，由 UI 写）。
          state = const SeedImportState(phase: SeedImportPhase.awaitingChoice);
          return;
        }
        // 老库（已导入、无 fts_mode）：按实际能力回填，不弹框、不改表。
        desired = await _backfillFtsMode(importer);
      }
      if (needsImport) {
        await for (final SeedImportState s in importer.importBasic()) {
          state = s;
        }
        if (state.phase == SeedImportPhase.error) {
          return; // 保留 error 态等待 UI 重试。
        }
      } else if (state.phase == SeedImportPhase.idle) {
        state = const SeedImportState(phase: SeedImportPhase.done, message: '种子已导入');
      }
      await _ensureIndexForDesiredMode(importer, desired);
      await _runMaintenanceInBackground();
    } catch (e) {
      state = SeedImportState(phase: SeedImportPhase.error, message: '种子导入失败: $e');
    } finally {
      _running = false;
    }
  }

  /// 首启弹框选择结果：写 settings 后继续导入（`off` 也照常导入内容）。
  Future<void> chooseFtsMode(FtsMode mode) async {
    await ref.read(seedImporterProvider).writeFtsMode(mode);
    state = const SeedImportState(phase: SeedImportPhase.idle);
    await ensureStarted();
  }

  // ───────────────────────────── FTS 档位 ─────────────────────────────

  /// 读期望档位（null = 老库尚未回填）。设置页首帧读取用。
  Future<FtsMode?> readFtsMode() => ref.read(seedImporterProvider).readFtsMode();

  /// 老库（无 `fts_mode`）按实际能力回填；只写 settings，不触表。
  Future<FtsMode> _backfillFtsMode(SeedImporter importer) async {
    if (!ref.read(maintenanceEnabledProvider)) {
      // 测试环境（无真实库）：按缺省 full 回填，避免 UI 常驻 awaitingChoice。
      await importer.writeFtsMode(FtsMode.full, built: FtsMode.full);
      return FtsMode.full;
    }
    final FtsIndexService service = await ref.read(ftsIndexServiceProvider.future);
    final FtsCapability cap = await service.detect();
    final FtsMode mode = cap.mode;
    await importer.writeFtsMode(mode, built: mode);
    return mode;
  }

  /// `built != desired` → 后台补建 / 删除（幂等；`off` 不会被自动建回来）。
  ///
  /// 走 [SeedImporter.rebuildFts]（模式感知、原生支持测试 fake）；
  /// 设置页的显式「切换 / 删除 / 重建」才用 [FtsIndexService]（带 VACUUM 与进度 UI）。
  Future<void> _ensureIndexForDesiredMode(SeedImporter importer, FtsMode desired) async {
    final FtsMode? built = await importer.readFtsBuiltMode();
    // off 只认 built：删除后不再自动建回；book/full 还需旧键确认完成（中断续跑）。
    final bool ready = built == desired &&
        (desired == FtsMode.off || await importer.ftsRebuildDone());
    if (ready) {
      return;
    }
    try {
      await for (final SeedImportState s in importer.rebuildFts()) {
        if (s.phase == SeedImportPhase.error) {
          debugPrint('seed_fts: ${s.message}');
          return;
        }
      }
    } catch (e) {
      debugPrint('seed_fts 重建失败（非致命，搜索降级 LIKE，重启自动续跑）: $e');
    }
  }

  /// 设置页/首启共用：切档或重建。成功后 invalidate 检索层。
  Future<FtsProgress> applyFtsMode(FtsMode target, {bool rebuild = false}) =>
      _applyFtsMode(target, rebuild: rebuild);

  /// 删除索引（设置页「删除索引」）。
  Future<FtsProgress> dropFtsIndex() => applyFtsMode(FtsMode.off);

  Future<FtsProgress> _applyFtsMode(FtsMode target, {required bool rebuild}) async {
    final FtsIndexService service = await ref.read(ftsIndexServiceProvider.future);
    FtsProgress last = FtsProgress(target: target, message: '准备索引…');
    await for (final FtsProgress progress in service.apply(target, rebuild: rebuild)) {
      last = progress;
    }
    ref.invalidate(ftsModeProvider);
    ref.invalidate(queriesProvider);
    return last;
  }

  Future<void> _runMaintenanceInBackground() async {
    if (!ref.read(maintenanceEnabledProvider)) {
      return;
    }
    try {
      // 库文件路径与 DefaultSeedImporter._databasePath 同口径（drift_flutter
      // 默认落盘 getApplicationDocumentsDirectory()/`<name>`.sqlite）。
      final String dbPath =
          p.join((await getApplicationDocumentsDirectory()).path, '${AppConstants.databaseName}.sqlite');
      // 词典行在主 isolate 经 rootBundle 读入再传入维护 isolate（一次构建复用，
      // 同 collect_providers.dart bookDictLinesProvider 的做法）；缺失 → 空表 →
      // BookDict.empty → v3 退化 v2。
      final List<String> dictLines = await ref.read(bookDictLinesProvider.future);
      var didWork = false;
      await for (final MaintenanceEvent e in runMaintenance(dbPath: dbPath, dictLines: dictLines)) {
        switch (e.kind) {
          case MaintenanceEventKind.done:
            didWork = e.didWork && !e.cancelled;
          case MaintenanceEventKind.failed:
            debugPrint('seed_maintenance: ${e.message}');
            return;
          case MaintenanceEventKind.ready:
          case MaintenanceEventKind.progress:
            break; // 静默：后台维护不进 UI 状态机
        }
      }
      if (didWork) {
        ref.invalidate(queriesProvider);
      }
    } catch (e) {
      debugPrint('seed_maintenance 失败（非致命，下次启动自动续跑）: $e');
    }
  }
}

final NotifierProvider<SeedBootstrapController, SeedImportState> seedBootstrapProvider =
    NotifierProvider<SeedBootstrapController, SeedImportState>(SeedBootstrapController.new);
