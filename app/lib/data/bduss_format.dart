/// BDUSS 凭证的纯 Dart 解析 / 掩码与存储键（**零 Flutter 依赖**）。
///
/// 抽出原因：headless CLI（`bin/booksift.dart collect --bduss`）与设置页需要
/// 同一套解析与掩码口径，而 [bduss.dart] 依赖 flutter_riverpod /
/// flutter_secure_storage，不能进纯 Dart 的 headless 层（AGENTS.md §7 维护约定）。
library;

/// 机密存储键：BDUSS 裸值（不含 `BDUSS=` 前缀）。
const String kSecretKeyBduss = 'bduss';

/// 机密存储键：凭证失效标记（'1' = 已失效并已自动降级匿名档；重新导入 / 清除即写 null）。
const String kSecretKeyBdussInvalid = 'bduss_invalid';

/// 粘贴容错解析：接受裸 BDUSS、`BDUSS=xxx`、`BDUSS=xxx; STOKEN=…` 这类 Cookie 片段
/// （也容忍首尾空白/引号/换行）。返回规范化后的 BDUSS；null = 看起来不是 BDUSS。
///
/// BDUSS 本身是 base64 风格长串（实测约 192 字符，字符集 `A-Za-z0-9-_=`）；这里只做
/// 「长度 + 字符集」两道粗校验——**不做网络校验**（校验请求会消耗配额且暴露凭证，
/// 有效性探测走设置页「测试」按钮或 CLI，属显式用户操作）。
String? parseBdussInput(String raw) {
  var s = raw.trim();
  if (s.isEmpty) {
    return null;
  }
  final RegExpMatch? m = RegExp(r'BDUSS\s*=\s*([^;\s]+)', caseSensitive: false).firstMatch(s);
  if (m != null) {
    s = m.group(1)!;
  }
  s = s.replaceAll(RegExp(r'''^["']+|["']+$'''), '').trim();
  if (s.length < 40 || s.length > 512) {
    return null;
  }
  if (!RegExp(r'^[A-Za-z0-9_\-=+/%]+$').hasMatch(s)) {
    return null;
  }
  return s;
}

/// 展示用掩码：保留头 6 / 尾 4，其余以 `……` 代替（设置页回显、CLI 日志用，
/// 避免全量回显凭证）。
String maskBduss(String value) {
  if (value.length <= 12) {
    return '……';
  }
  return '${value.substring(0, 6)}……${value.substring(value.length - 4)}';
}
