/// 应用级常量（单一出处）。
abstract final class AppConstants {
  static const String appName = '扫书汇';

  /// drift 单库名（原型 §7.1：内容表与用户表同库 app.db；drift_flutter 落盘为 `<name>`.sqlite）。
  static const String databaseName = 'app';
}

/// settings 表（KV）键名（原型 §7.2 Settings.key 注释 / §7.5 版本闸门 / §9.2）。
abstract final class SettingsKeys {
  static const String seedVersion = 'seed_version';
  static const String seedFullVersion = 'seed_full_version';
  static const String theme = 'theme';
  static const String reduceMotion = 'reduce_motion';
  static const String sortDirection = 'sort_dir';
  static const String wifiOnly = 'wifi_only';
  static const String concurrentForums = 'concurrent_forums';
  static const String classifierVersion = 'classifier_version';
}

/// origin 徽标取值（§7.2 origin 字段 / 设计系统 §4：内置灰 / 自采绿 / 导入蓝）。
abstract final class Origin {
  static const String builtin = 'builtin';

  /// 种子包导入行（lib/data/seed_import.dart 的 `SeedImporter.seedOrigin`）。
  /// 语义等同 builtin —— 徽标同归「内置」灰档，只有 collected/imported 两档另着色。
  static const String seed = 'seed';
  static const String collected = 'collected';
  static const String imported = 'imported';
}
