/// 采集服务新增的 settings 键（§8.11 每日预算本地计数）。
///
/// 既有键（wifi_only / concurrent_forums / classifier_version）在
/// `core/constants.dart` 的 [SettingsKeys]（禁改，直接引用）。
library;

abstract final class CollectSettingsKeys {
  /// 每日请求预算计数所属日期（'YYYY-MM-DD'，设备本地日；跨日重置，§8.11）。
  static const String budgetDate = 'collect_budget_date';

  /// 当日已消耗请求数（匿名档 ≤300 / BDUSS 档 ≤600，§8.11；换档共享同一计数）。
  static const String budgetCount = 'collect_budget_count';
}

bool wifiOnlyFromSetting(String? value) => value != '0' && value != 'false';
