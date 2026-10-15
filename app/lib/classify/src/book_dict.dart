/// BookDict 的实现体：书名实体词典 trie 索引（= collect_poc.py 行 1074–1143
/// load_book_dict / find_dict_booknames 的同款语义）。
///
/// 数据结构选型（任务书允许 trie 或首字桶，报告 §9.4 第 12 条点名 trie）：
/// **压缩前 trie，扁平三并行数组**（childStart/childCount + 按 rune 升序的
/// edgeRune/edgeChild + termNameId）。理由：
///   · Python 首字桶是 O(文本长 × 桶均深 × startswith)；trie 逐位置下行是
///     O(文本长 × log 出度)，且天然拿"该位置最长命中"（G2 需要全部命中列表）；
///   · 对象图 `Map<int, Node>` 约 9.4MB（报告 §9.4 第 13 条实测口径），扁平
///     Int32Array ≈ 节点 12.3 万 × 3 数组 + 边 × 2 数组 ≈ 2.4MB；
///   · 构建期用单链表边表（免 per-node Map），22k 名 / 17.5 万 rune 实测
///     构建 + 压平在百毫秒量级（dict_test 有 sanity 上限）。
///
/// 匹配口径（与 Python 逐位等价，见 find_dict_booknames 行 1114–1137）：
///   · 文本先 v3NormText 归一化；trie 键与文本都走**真实码点**（词典匹配不经
///     py_regex 的 PUA 折叠——折叠只服务于正则量词计数，trie 是逐 rune 手动
///     比较，直接对齐 Python 的码点语义，含 emoji 书名）；
///   · 每位置只考虑该位置的最长命中，且其长度 ≥ 全局已见最长（Python 桶内
///     `len(cand) < longest: break` 的剪枝语义）；
///   · 命中去重、按（码点长度降序，首见序）稳定排序——Python list.sort 是
///     稳定排序，Dart List.sort 不保证稳定，故显式带下标比较。
///
/// G2 守卫（构建期一次完成，行 1098–1107）：名字自身命中 [v3EvidenceRe]
/// （雷术语+弱雷术语+雷词+负评词四表合并）的不进 trie，另存 [evidenceNames]
/// 供 engine 的循环证据作废（_v3_circular_pats）使用。
library;

import 'dart:typed_data';

import 'norm.dart';
import 'py_regex.dart';
import 'py_unicode.dart';
import 'rules.dart';

/// 词典索引核心（classifier.dart 的 BookDict 持有本对象）。
final class BookDictCore {
  BookDictCore._({
    required this.names,
    required this.termNameId,
    required this.childStart,
    required this.childCount,
    required this.edgeRune,
    required this.edgeChild,
    required this.anchorCount,
    required this.bucketCount,
    required this.evidenceNames,
  });

  /// 空词典：v3 退化为 v2 行为（Python load_book_dict 缺文件 → 空索引同款）。
  factory BookDictCore.empty() => BookDictCore._(
        names: const <String>[],
        termNameId: Int32List.fromList(<int>[-1]),
        childStart: Int32List(1),
        childCount: Int32List(1),
        edgeRune: Int32List(0),
        edgeChild: Int32List(0),
        anchorCount: 0,
        bucketCount: 0,
        evidenceNames: const <String>{},
      );

  /// 从词典行构建（= load_book_dict：strip → 过短剔除 → G2 分流 → 首字桶/trie）。
  factory BookDictCore.fromLines(Iterable<String> lines) {
    // ---- 构建期：单链表边表（nodeHead[node] → 边槽 → eNext 链） ----
    final List<int> nodeHead = <int>[-1]; // 节点 0 = 根
    final List<int> term = <int>[-1]; // 节点 → nameId（-1 = 非终结）
    final List<int> eRune = <int>[];
    final List<int> eNext = <int>[];
    final List<int> eChild = <int>[];
    final List<String> names = <String>[];
    final Set<String> ev = <String>{};
    var anchor = 0;

    for (final String raw in lines) {
      final String n = pyStrip(raw); // = Python ln.strip()（isspace 口径）
      final List<int> runes = n.runes.toList(growable: false);
      if (runes.length < v3DictMinLen) continue; // V3_DICT_MIN_LEN=2（码点数）
      if (v3EvidenceRe.hasMatch(foldText(n))) { // G2：名字自身即雷词/负评词
        ev.add(n);
        continue;
      }
      var node = 0;
      for (final int r in runes) {
        var found = -1;
        for (var e = nodeHead[node]; e != -1; e = eNext[e]) {
          if (eRune[e] == r) {
            found = eChild[e];
            break;
          }
        }
        if (found < 0) {
          found = nodeHead.length;
          nodeHead.add(-1);
          term.add(-1);
          eRune.add(r);
          eChild.add(found);
          eNext.add(nodeHead[node]);
          nodeHead[node] = eRune.length - 1;
        }
        node = found;
      }
      if (term[node] < 0) term[node] = names.length; // 同键冲突保留文件序前者
      names.add(n);
      anchor++;
    }

    // ---- 压平：每节点边按 rune 升序 → 二分查找 ----
    final int nodeCount = nodeHead.length;
    final Int32List childStart = Int32List(nodeCount);
    final Int32List childCount = Int32List(nodeCount);
    final Int32List edgeRuneS = Int32List(eRune.length);
    final Int32List edgeChildS = Int32List(eRune.length);
    var w = 0;
    for (var node = 0; node < nodeCount; node++) {
      childStart[node] = w;
      final List<int> slots = <int>[];
      for (var e = nodeHead[node]; e != -1; e = eNext[e]) {
        slots.add(e);
      }
      slots.sort((int a, int b) => eRune[a].compareTo(eRune[b]));
      childCount[node] = slots.length;
      for (final int e in slots) {
        edgeRuneS[w] = eRune[e];
        edgeChildS[w] = eChild[e];
        w++;
      }
    }

    return BookDictCore._(
      names: names,
      termNameId: Int32List.fromList(term),
      childStart: childStart,
      childCount: childCount,
      edgeRune: edgeRuneS,
      edgeChild: edgeChildS,
      anchorCount: anchor,
      bucketCount: childCount[0], // 首字桶数 = 根出度 = Python len(idx)
      evidenceNames: ev,
    );
  }

  final List<String> names;
  final Int32List termNameId;
  final Int32List childStart;
  final Int32List childCount;
  final Int32List edgeRune;
  final Int32List edgeChild;

  /// 可锚定名数量（G2 剔除后；= Python sum(len(b))，行 1108–1109 日志口径）。
  final int anchorCount;

  /// 首字桶数（= Python len(idx)）。
  final int bucketCount;

  /// G2 留出的「自身即雷词/负评词」书名集合（= _V3_EVIDENCE_NAMES）。
  final Set<String> evidenceNames;

  int get evidenceNameCount => evidenceNames.length;

  int _child(int node, int rune) {
    final int lo = childStart[node];
    final int hi = lo + childCount[node];
    var l = lo;
    var r = hi;
    while (l < r) {
      final int mid = (l + r) >> 1;
      final int m = edgeRune[mid];
      if (m < rune) {
        l = mid + 1;
      } else if (m > rune) {
        r = mid;
      } else {
        return edgeChild[mid];
      }
    }
    return -1;
  }

  /// 全部词典命中（去重、码点长度降序、同长按首见序稳定；[0] 即最长命中）。
  /// = find_dict_booknames（行 1114–1137）。
  List<String> findBooknames(String text) {
    if (anchorCount == 0) return const <String>[]; // 空索引短路（Python 同款）
    final List<int> runes =
        v3NormTextImpl(text).runes.toList(growable: false);
    final List<String> hits = <String>[];
    final Set<String> seen = <String>{};
    var longest = 0;
    for (var i = 0; i < runes.length; i++) {
      // 该位置的最长命中（trie 下行，记最深终结点）
      var node = 0;
      var lastTerm = -1;
      var lastLen = 0;
      for (var j = i; j < runes.length; j++) {
        final int next = _child(node, runes[j]);
        if (next < 0) break;
        node = next;
        final int t = termNameId[node];
        if (t >= 0) {
          lastTerm = t;
          lastLen = j - i + 1;
        }
      }
      // Python 剪枝：桶内 len(cand) < longest 即 break → 只有 ≥ longest 的
      // 位置级最长命中才被记录；相等也记（break 条件是严格小于）。
      if (lastTerm >= 0 && lastLen >= longest) {
        final String name = names[lastTerm];
        if (seen.add(name)) hits.add(name);
        if (lastLen > longest) longest = lastLen;
      }
    }
    // 稳定排序：长度（码点数）降序，同长保持插入序（= Python list.sort 稳定性）
    final List<int> lens = <int>[
      for (final String h in hits) h.runes.length,
    ];
    final List<int> order = <int>[for (var k = 0; k < hits.length; k++) k]
      ..sort((int a, int b) {
        final int d = lens[b].compareTo(lens[a]);
        return d != 0 ? d : a.compareTo(b);
      });
    return <String>[for (final int k in order) hits[k]];
  }

  /// 最长词典命中（无命中返回 ''）。= find_dict_bookname（行 1140–1143）。
  String findBookname(String text) {
    final List<String> hits = findBooknames(text);
    return hits.isEmpty ? '' : hits.first;
  }
}
