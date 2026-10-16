import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../collector/scheduler.dart' show kMaxConcurrencyBduss;
import '../../core/constants.dart';
import '../../data/db/app_database.dart';
import '../../data/repo/database_provider.dart';

/// 采集相关设置（settings 表 KV：`wifi_only` / `concurrent_forums`）。
///
/// 默认值出处：仅 WiFi 默认开（原型 §8.11 网络行「默认仅 WiFi，可关」）；
/// 并发默认 2、上限 3（匿名）/ 4（BDUSS 档，原型 §8.8 + 需求 5）。
/// 这里存的是**用户原值**（钳到 [2, 4]），按档生效的钳制走
/// `scheduler.effectiveConcurrency(value, bdussImported:)`（设置页/调度器共用）。
/// 读取失败（如 widget 测试的 appDatabaseProvider 哨兵、首启竞态）一律回落默认值，
/// 不阻断 UI。
class CollectSettings {
  const CollectSettings({this.wifiOnly = true, this.concurrentForums = 2});

  final bool wifiOnly;
  final int concurrentForums;
}

final FutureProvider<CollectSettings> collectSettingsProvider =
    FutureProvider<CollectSettings>((Ref ref) async {
      try {
        final AppDatabase db = ref.watch(appDatabaseProvider);
        Future<String?> read(String key) =>
            (db.select(db.settings)..where((Settings t) => t.key.equals(key)))
                .getSingleOrNull()
                .then((Setting? row) => row?.value);
        final String? wifi = await read(SettingsKeys.wifiOnly);
        final String? concurrent = await read(SettingsKeys.concurrentForums);
        return CollectSettings(
          wifiOnly: wifi == null ? true : wifi != 'false',
          concurrentForums:
              (int.tryParse(concurrent ?? '') ?? 2).clamp(2, kMaxConcurrencyBduss),
        );
      } catch (_) {
        return const CollectSettings();
      }
    });

/// 设置写入（settings 页「采集」小节消费；写后 invalidate 读取侧）。
class CollectSettingsController {
  const CollectSettingsController(this._ref);

  final Ref _ref;

  Future<void> setWifiOnly(bool value) =>
      _write(SettingsKeys.wifiOnly, value ? 'true' : 'false');

  Future<void> setConcurrentForums(int value) =>
      _write(SettingsKeys.concurrentForums, '${value.clamp(2, kMaxConcurrencyBduss)}');

  Future<void> _write(String key, String value) async {
    final AppDatabase db = _ref.read(appDatabaseProvider);
    await db
        .into(db.settings)
        .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
    _ref.invalidate(collectSettingsProvider);
  }
}

final Provider<CollectSettingsController> collectSettingsControllerProvider =
    Provider<CollectSettingsController>(CollectSettingsController.new);
