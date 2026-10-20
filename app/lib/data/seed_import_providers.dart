import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../collector/collect_providers.dart';
import '../core/constants.dart';
import 'maintenance.dart';
import 'repo/database_provider.dart';
import 'repo/queries_providers.dart';
import 'seed_import.dart';

/// 种子导入机制单例（原型 §9.2；机制在 seed_import.dart，本文件只做 riverpod 装配）。
final Provider<SeedImporter> seedImporterProvider = Provider<SeedImporter>((Ref ref) {
  return DefaultSeedImporter(ref.watch(appDatabaseProvider));
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
/// 接线点：app.dart initState 首帧后调度（与启动更新检查同款模式）。
class SeedBootstrapController extends Notifier<SeedImportState> {
  bool _running = false;

  @override
  SeedImportState build() => const SeedImportState();

  Future<void> ensureStarted() async {
    if (_running || state.isImporting) {
      return;
    }
    _running = true;
    try {
      final SeedImporter importer = ref.read(seedImporterProvider);
      if (await importer.needsBasicImport()) {
        await for (final SeedImportState s in importer.importBasic()) {
          state = s;
        }
        if (state.phase == SeedImportPhase.error) {
          return; // 保留 error 态等待 UI 重试。
        }
      } else if (state.phase == SeedImportPhase.idle) {
        state = const SeedImportState(phase: SeedImportPhase.done, message: '种子已导入');
      }
      await _rebuildFtsInBackground(importer);
      await _runMaintenanceInBackground();
    } catch (e) {
      state = SeedImportState(phase: SeedImportPhase.error, message: '种子导入失败: $e');
    } finally {
      _running = false;
    }
  }

  Future<void> _rebuildFtsInBackground(SeedImporter importer) async {
    try {
      if (await importer.ftsRebuildDone()) {
        return;
      }
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

  /// 后台数据维护（best-effort，口径与 [_rebuildFtsInBackground] 一致）：
  /// FTS 后台重建之后依次跑 dedup → reclassify（maintenance.dart，后台 isolate，
  /// 各自闸门全部完成才落账）；有实际修改则 invalidate queriesProvider 让 UI
  /// 重新取数。失败只 debugPrint，不影响 done 态（下次启动按闸门自动续跑）。
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
