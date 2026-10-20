/// FTS 索引档位（纯 Dart；Queries / 设置 / 导入共用）。
///
/// 单独成文件的原因：`queries.dart` 必须保持纯 Dart 且不引入 sqlite3 依赖，
/// 而档位枚举是检索分路的唯一输入。
library;

/// 索引档位。
enum FtsMode {
  off('off', '关闭'),
  book('book', '基础'),
  full('full', '完整');

  const FtsMode(this.wire, this.label);

  /// settings / JSON 落盘值。
  final String wire;

  /// 设置页分段标签（2 字，窄屏不溢出）。
  final String label;
}

/// 解析 settings 值；未知/缺失返回 null（由调用方决定回填策略）。
FtsMode? ftsModeFromWire(String? value) {
  for (final FtsMode mode in FtsMode.values) {
    if (mode.wire == value) {
      return mode;
    }
  }
  return null;
}
