/// 归一化四函数移植（口径 = work/unified/merge_etl.py:59-92，§8.7 要求）。
///
/// **同口径保证**：自采条目的 name_norm/author_norm/content_hash 与种子数据
/// （unified.db）落在同一键空间，同书自动聚合进同一 book_group（§8.7）。
///
/// 与 Python 的两处已知差异（均有界，报告有记录）：
/// 1. **NFKC 子集**：纯 Dart 无 ICU，[nfkc] 只覆盖全角 ASCII/汉字宽度区
///    （U+FF01–U+FF5E → 半角、U+3000 → 空格）；①/㎡/半角假名等其余兼容映射
///    不做——书名/作者键上出现此类字符概率极低，且出现时仅影响该条聚合。
/// 2. **BOOK_WRAP_RE 不复刻**：merge_etl.py:52 的 BOOK_WRAP_RE 因字符类转义
///    （`\\[`/`\\]`）在 Python 中实际近似 no-op（实测：`《Ａ［１］「b」` 原样保留，
///    真正剥《》的是 PUNCT_RE）。其预期剥离的包裹符全部已含于 [_punctRe]，
///    故 Dart 侧直接省略该步，输出与 Python 实测逐向量一致
///    （test/collector/normalization_test.dart 的期望值由 CPython 3.12 实算固化）。
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 空白类（merge_etl.py:49 WS_RE；Dart 的 \s 已含 \u00a0/\u3000/\ufeff，显式重复无害）。
final RegExp _wsRe = RegExp(r'[\s\u3000\u00a0\ufeff]+');

/// 标点类（merge_etl.py:50-52 PUNCT_RE 逐字符对齐，含全角/弯引号/破折号/省略号）。
final RegExp _punctRe = RegExp(
  '[，。、；：！？“”‘’（）《》〈〉【】「」『』—…·～\\-~*_=+/|<>.,;:!?()\\[\\]{}"\'`]',
);

/// 占位值集合（merge_etl.py:56 NULLISH）——norm_person 命中即归空。
const Set<String> _nullish = <String>{
  '', '无', '不详', '未知', 'null', 'None', 'NULL', '-', '——', 'N/A', 'n/a',
};

/// NFKC 兼容子集：全角 ASCII（U+FF01–U+FF5E）→ 半角；表意空格（U+3000）→ 空格。
/// 见库注释差异 1。
String nfkc(String s) {
  if (s.isEmpty) return '';
  final StringBuffer out = StringBuffer();
  for (final int code in s.runes) {
    if (code >= 0xFF01 && code <= 0xFF5E) {
      out.writeCharCode(code - 0xFEE0);
    } else if (code == 0x3000) {
      out.write(' ');
    } else {
      out.writeCharCode(code);
    }
  }
  return out.toString();
}

/// 跨库正文比对归一化（merge_etl.py:59 norm_text）：
/// NFKC → 去所有空白 → 去常见标点 → 小写。
String normText(String s) {
  if (s.isEmpty) return '';
  return nfkc(s)
      .replaceAll(_wsRe, '')
      .replaceAll(_punctRe, '')
      .toLowerCase();
}

/// 书名归一化（merge_etl.py:66 norm_name）：NFKC → 剥离包裹符与空白 → 去标点 → 小写。
/// （包裹符剥离由 [_punctRe] 承担，见库注释差异 2。）
String normName(String s) {
  if (s.isEmpty) return '';
  return nfkc(s)
      .replaceAll(_wsRe, '')
      .replaceAll(_punctRe, '')
      .toLowerCase();
}

/// 人名归一化（merge_etl.py:74 norm_person）：NFKC → 去空白 → 小写；
/// 保留符号（贴吧 ID 常含特殊字符）；命中 [_nullish] 归空串。
String normPerson(String s) {
  if (s.isEmpty) return '';
  final String t = nfkc(s).replaceAll(_wsRe, '');
  return _nullish.contains(t) ? '' : t.toLowerCase();
}

/// sha1 前 16 hex（merge_etl.py:86 h16）。
String h16(String s) => sha1.convert(utf8.encode(s)).toString().substring(0, 16);

/// book_entries.content_hash，两种口径：
///
/// - **旧三参口径**（[postRef] 缺省；merge_etl.py:1042/1074 同款拼接，种子导入
///   路径沿用）：`sha1(name_norm + 0x1f + author_norm + 0x1f + comment_norm_hash)[:16]`；
///   author_norm / comment_norm_hash 缺省按空串参与（Python 侧 COALESCE 口径）。
/// - **按帖口径**（[postRef] 非空；自采入库）：旧口径尾部追加 `0x1f + post_ref`，即
///   `sha1(name_norm + 0x1f + author_norm + 0x1f + comment_norm_hash + 0x1f + post_ref)[:16]`。
///   同一本书被不同帖推荐（即使推荐语相同/皆空）hash 互异 → 各记一条推荐
///   （rankRows COUNT(*) 按帖计数）；同帖重采 hash 不变 → 幂等跳过；
///   与种子行（旧口径 hash）在 content_hash UNIQUE 约束下不冲突。
String entryContentHash({
  required String nameNorm,
  required String authorNorm,
  required String commentNormHash,
  int? postRef,
}) =>
    h16(postRef == null
        ? '$nameNorm\u001f$authorNorm\u001f$commentNormHash'
        : '$nameNorm\u001f$authorNorm\u001f$commentNormHash\u001f$postRef');
