/// 应用级常量（单一出处）。
abstract final class AppConstants {
  static const String appName = '扫书汇';

  /// CLI 与桌面更新提示共用的应用版本（发布时与 pubspec.yaml 对齐）。
  static const String appVersion = '1.0.1';

  /// drift 单库名（原型 §7.1：内容表与用户表同库 app.db；drift_flutter 落盘为 `<name>`.sqlite）。
  static const String databaseName = 'app';

  /// 正文预览统一截断字数（用户口径：所有正文预览 100 字截断，超出补「…」）。
  /// 消费方：queries.summarizeCardText（首页帖卡/书卡摘要）与 collector/tieba_search（在线结果行）。
  static const int previewMaxChars = 100;
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

  /// book_entries 去重维护完成标记（lib/data/maintenance.dart；'1' = 已完成，
  /// 中断/失败不写，下次启动重跑——重跑幂等应 0 删除）。
  static const String dedupVersion = 'dedup_version';

  /// 种子包升级后 post 引用一次性修复完成标记（lib/data/maintenance.dart 的
  /// repairPostReferences；'1' = 已完成，中断/失败不写，下次启动重跑——重跑幂等）。
  static const String postRefRepairVersion = 'post_ref_repair_v1';

  /// 搜索结果浏览位置（features/search/search_state.dart 的 SearchPositionStore）。
  /// 值 = JSON map「条件签名 → 结果列表滚动偏移 px」，LRU 上限 32 条（关 App 重开仍在）。
  static const String searchPositions = 'search_positions';

  /// 搜索结果**目录弹层**自身的浏览位置（同上存储，键 = 条件签名，值 = 目录列表偏移 px）。
  /// 用户口径：不变更搜索词时，关掉目录/关 App 再打开都要回到上次目录位置。
  static const String searchTocPositions = 'search_toc_positions';

  /// 搜索台草稿（features/search/search_state.dart 的 SearchDraftStore）：关 App 重开后
  /// 恢复上次搜索词 + 六维筛选 + 排序 + 是否已提交（可见结果区），浏览位置记忆据此恢复。
  /// 值 = JSON map（SearchFilter.toUriParams 的内容 + submitted）。
  static const String searchDraft = 'search_draft';

  /// 三栏「功能区」布局记忆（app_shell.dart 的 ShellLayoutStore，expanded 档）：
  /// 导航栏当前宽 / 收起前展开宽（逻辑 px）+ 右侧详情槽占「中间 + 详情」的比例。
  /// 用户口径：拖定的占比与收起状态要跨重启记住（否则重开一次就要重调一遍）。
  static const String railWidth = 'rail_width';
  static const String railWidthExpanded = 'rail_width_expanded';
  static const String detailFraction = 'detail_fraction';

  /// FTS 索引期望档位：`off` | `book` | `full`（lib/data/fts_index.dart 的 FtsMode）。
  /// 缺失 = 老库，按实际能力回填（见 FtsIndexBootstrap），不弹首启框、不重建。
  static const String ftsMode = 'fts_mode';

  /// 实际已建成的档位（启动自愈 / 中断续跑判据；由 FtsIndexService 落账）。
  static const String ftsBuiltMode = 'fts_built_mode';
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
