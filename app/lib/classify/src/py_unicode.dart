/// Python Unicode 语义等价层（一）：NFKC-lite 折叠、规范组合、lower 全映射、
/// str.strip()/isspace() 字符集。数据表见 [unicode_tables.dart]（生成物）。
///
/// 为什么需要本文件：Dart 没有内置 NFKC，且 `String.toLowerCase()` 与 Python
/// `str.lower()` 存在两处实测差异（探针 2026-10-13）：
///   · `İ`(U+0130)：Python → `i̇`(U+0069 U+0307，1→2 字符)；Dart → `i`(单字符)；
///   · 希腊词尾 sigma：Python `ΑΣ`.lower() → `ας`(U+03C2)；Dart → `ασ`(U+03C3)。
/// 故 lower 也走生成表 + Final_Sigma 上下文规则，保证 v3_norm_text 与
/// collect_poc.py:v3_norm_text 逐码点一致（norm_parity 夹具 100% 兜底）。
library;

import 'dart:typed_data';

import 'unicode_tables.dart';

/// 排好序的码点区间集合（二分查找）。区间由生成器保证有序、不相交。
final class RangeSet {
  RangeSet(List<List<int>> ranges)
      : starts = Int32List.fromList(<int>[for (final List<int> r in ranges) r[0]]),
        ends = Int32List.fromList(<int>[for (final List<int> r in ranges) r[1]]);

  final Int32List starts;
  final Int32List ends;

  bool contains(int cp) {
    // 找最后一个 start <= cp 的区间
    var lo = 0;
    var hi = starts.length - 1;
    var ans = -1;
    while (lo <= hi) {
      final int mid = (lo + hi) >> 1;
      if (starts[mid] <= cp) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans >= 0 && cp <= ends[ans];
  }
}

/// V3_NORM_WS_RE 成员（= Python re \s + U+FEFF），生成器从正则 fullmatch 实测导出。
final RangeSet normWsSet = RangeSet(normWsRanges);

/// V3_NORM_PUNCT_RE 成员，同上。
final RangeSet normPunctSet = RangeSet(normPunctRanges);

/// Python `str.isspace()` / re `\s` 集合（= normWsSet − U+FEFF：'\ufeff'.isspace()
/// 为 False，str.strip() 不剥 BOM，但 V3_NORM_WS_RE 显式含 \ufeff——两套集合不可混用）。
final RangeSet pyWsSet = RangeSet(<List<int>>[
  for (final List<int> r in normWsRanges)
    if (r[0] != 0xFEFF) r, // FEFF 单独成区间（生成器保证），整体剔除
]);

/// Final_Sigma 条件用：Cased（Lowercase|Uppercase|Lt）与 Case_Ignorable。
final RangeSet casedSet = RangeSet(casedRanges);
final RangeSet caseIgnorableSet = RangeSet(caseIgnorableRanges);

/// NFKC 等差 run 查找表（starts 升序）。
final Int32List _nfkcStarts =
    Int32List.fromList(<int>[for (final List<int> r in nfkcRanges) r[0]]);

int? _nfkcRangeDelta(int cp) {
  var lo = 0;
  var hi = _nfkcStarts.length - 1;
  var ans = -1;
  while (lo <= hi) {
    final int mid = (lo + hi) >> 1;
    if (_nfkcStarts[mid] <= cp) {
      ans = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  if (ans < 0) return null;
  final List<int> r = nfkcRanges[ans];
  if (cp > r[1]) return null;
  return r[2];
}

/// 非零 Canonical Combining Class 查找（cccRanges 二分；缺省 0 = starter）。
int cccOf(int cp) {
  var lo = 0;
  var hi = cccRanges.length - 1;
  while (lo <= hi) {
    final int mid = (lo + hi) >> 1;
    final List<int> r = cccRanges[mid];
    if (cp < r[0]) {
      hi = mid - 1;
    } else if (cp > r[1]) {
      lo = mid + 1;
    } else {
      return r[2];
    }
  }
  return 0;
}

/// 规范组合（NFC 的组合半程，UAX #15）：
///   · Hangul L+V(+T) / LV+T 算法合成（jamo 均 CCC=0，不进标记 run）；
///   · CCC=0 后继：相邻组合对查表（Bengali 系双部件元音等 41 对）；
///   · CCC>0 标记 run：按 CCC 稳定升序**规范重排**后逐标记组合，
///     阻塞规则 = 只有 lastCcc < ccc(M) 且组合对存在时 M 并入 starter
///     （并入后 lastCcc 不变——该标记已消失，不再阻塞后续）。
/// 与 unicodedata.normalize('NFC', …) 逐码点对齐（组合对表/CCC 表均由
/// Python 实测生成；探针验证 "a◌̧◌́"/"a◌́◌̧" → "á◌̧" 两序同果）。
List<int> composeRunes(List<int> rs) {
  final List<int> out = <int>[];
  var i = 0;
  while (i < rs.length) {
    var s = rs[i];
    i++;
    // Hangul L + V (+ T)
    if (s >= 0x1100 && s <= 0x1112 && i < rs.length) {
      final int v = rs[i];
      if (v >= 0x1161 && v <= 0x1175) {
        var syl = 0xAC00 + (s - 0x1100) * 588 + (v - 0x1161) * 28;
        i++;
        if (i < rs.length && rs[i] >= 0x11A8 && rs[i] <= 0x11C2) {
          syl += rs[i] - 0x11A7;
          i++;
        }
        out.add(syl);
        continue;
      }
    }
    // 收集 s 后的非 starter 标记 run（CCC>0）
    final int runStart = i;
    while (i < rs.length && cccOf(rs[i]) > 0) {
      i++;
    }
    if (i == runStart) {
      // 无标记 run：CCC=0 后继只查相邻组合对（Hangul LV+T 与 Indic 双部件）
      if (i < rs.length) {
        if (s >= 0xAC00 &&
            s <= 0xD7A3 &&
            (s - 0xAC00) % 28 == 0 &&
            rs[i] >= 0x11A8 &&
            rs[i] <= 0x11C2) {
          out.add(s + rs[i] - 0x11A7); // LV + T
          i++;
          continue;
        }
        final int? c = composePairs[s * 0x110000 + rs[i]];
        if (c != null) {
          out.add(c);
          i++;
          continue;
        }
      }
      out.add(s);
      continue;
    }
    // 规范重排（CCC 稳定升序）+ 阻塞规则组合
    final List<int> run = rs.sublist(runStart, i);
    if (run.length > 1) {
      final List<int> order = <int>[for (var k = 0; k < run.length; k++) k]
        ..sort((int a, int b) {
          final int d = cccOf(run[a]).compareTo(cccOf(run[b]));
          return d != 0 ? d : a.compareTo(b); // 稳定：同 CCC 保序
        });
      final List<int> sorted = <int>[for (final int k in order) run[k]];
      run
        ..clear()
        ..addAll(sorted);
    }
    var lastCcc = 0;
    final List<int> kept = <int>[];
    for (final int m in run) {
      final int c = cccOf(m);
      final int? comp = lastCcc < c ? composePairs[s * 0x110000 + m] : null;
      if (comp != null) {
        s = comp; // lastCcc 不变：m 已并入 starter
      } else {
        kept.add(m);
        lastCcc = c;
      }
    }
    out.add(s);
    out.addAll(kept);
  }
  return out;
}

/// NFKC-lite：逐码点兼容折叠（等差 run + 单点表）→ 规范组合。
/// 与 `unicodedata.normalize('NFKC', s)` 逐码点对齐（表由同一 unicodedata 生成）。
List<int> nfkcRunes(String s) {
  final List<int> out = <int>[];
  for (final int r in s.runes) {
    final int? d = _nfkcRangeDelta(r);
    if (d != null) {
      out.add(r + d);
      continue;
    }
    final String? m = nfkcSingles[r];
    if (m != null) {
      out.addAll(m.runes);
      continue;
    }
    out.add(r);
  }
  return composeRunes(out); // 组合跨字符进行（半角假名+浊点等），自带快路径
}

/// Final_Sigma 条件（Unicode SpecialCasing）：After_Cased 且非 Before_Cased。
bool _isFinalSigma(List<int> rs, int i) {
  var j = i - 1;
  while (j >= 0 && caseIgnorableSet.contains(rs[j])) {
    j--;
  }
  if (j < 0 || !casedSet.contains(rs[j])) return false; // 非 After_Cased
  j = i + 1;
  while (j < rs.length && caseIgnorableSet.contains(rs[j])) {
    j++;
  }
  return !(j < rs.length && casedSet.contains(rs[j])); // 非 Before_Cased
}

/// Python `str.lower()` 等价：生成表全映射（含 1→多 展开）+ Final_Sigma 上下文。
/// 上下文按**小写化前**的原串判定（CPython 同款）。
List<int> pyLowerRunes(List<int> rs) {
  final List<int> out = <int>[];
  for (var i = 0; i < rs.length; i++) {
    final int r = rs[i];
    if (r == 0x3A3 && _isFinalSigma(rs, i)) {
      out.add(0x3C2); // ς
      continue;
    }
    final String? m = lowerSingles[r];
    if (m != null) {
      out.addAll(m.runes);
      continue;
    }
    out.add(r);
  }
  return out;
}

bool isPyWs(int cp) => pyWsSet.contains(cp);

/// Python `str.strip()` 等价（剥两端 isspace 字符；**不含** U+FEFF）。
String pyStrip(String s) {
  final List<int> rs = s.runes.toList(growable: false);
  var a = 0;
  var b = rs.length;
  while (a < b && pyWsSet.contains(rs[a])) {
    a++;
  }
  while (b > a && pyWsSet.contains(rs[b - 1])) {
    b--;
  }
  if (a == 0 && b == rs.length) return s;
  return String.fromCharCodes(rs, a, b); // fromCharCodes 第三参 = end 下标
}

/// Python `re.sub(r"\s+", "", s)` 等价（删全部 isspace 字符）。
String pyRemoveAllWs(String s) {
  if (!s.runes.any(pyWsSet.contains)) return s;
  return String.fromCharCodes(s.runes.where((int r) => !pyWsSet.contains(r)));
}

/// Python `s.rstrip(chars)` 等价（chars 为 BMP 字符集；按码点剥尾）。
String pyRstrip(String s, Set<int> chars) {
  final List<int> rs = s.runes.toList(growable: false);
  var b = rs.length;
  while (b > 0 && chars.contains(rs[b - 1])) {
    b--;
  }
  if (b == rs.length) return s;
  return String.fromCharCodes(rs, 0, b);
}
