/// 采集服务新增的 settings 键（§8.11 每日预算本地计数）。
///
/// 既有键（wifi_only / concurrent_forums / classifier_version）在
/// `core/constants.dart` 的 [SettingsKeys]（禁改，直接引用）。
library;

abstract final class CollectSettingsKeys {
  /// 每日请求预算计数所属日期（'YYYY-MM-DD'，设备本地日；跨日重置，§8.11）。
  static const String budgetDate = 'collect_budget_date';

  /// 当日已消耗请求数（匿名档预算 ≤300，§8.11）。
  static const String budgetCount = 'collect_budget_count';
}
