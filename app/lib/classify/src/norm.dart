/// v3_norm_text 的 Dart 实现（= collect_poc.py 行 1056–1062）。
///
/// 管线：NFKC（[nfkcRunes]，生成表全量折叠 + 规范组合）→ 去空白（V3_NORM_WS_RE
/// 成员集）→ 去标点（V3_NORM_PUNCT_RE 成员集）→ 小写（[pyLowerRunes]，Python
/// str.lower() 全映射 + Final_Sigma）。两个成员集由 Python 正则 fullmatch 逐码点
/// 实测导出（unicode_tables.dart），非手抄。
///
/// 与 _build_book_dict.py:norm_name 的关系：norm_name 多一步「剥《》等包裹符」
/// （BOOK_WRAP_RE），但那一步只作用于**词典构建期**的原始书名；运行时
/// v3_norm_text 不剥包裹符。词典文件（book_dict.txt）已是 norm_name 产物，
/// Dart 侧 fromLines 不再归一化——两侧口径因此对齐（报告 §9.4 第 15 条）。
library;

import 'py_unicode.dart';

/// 词典匹配用归一化（契约 API v3NormText 的实现体）。
String v3NormTextImpl(String s) {
  if (s.isEmpty) return '';
  final List<int> folded = nfkcRunes(s);
  final List<int> kept = <int>[
    for (final int r in folded)
      if (!normWsSet.contains(r) && !normPunctSet.contains(r)) r,
  ];
  return String.fromCharCodes(pyLowerRunes(kept));
}
