// v3 分类器 parity 主测试：2155 条真实帖夹具（eval_candidates 420 + collected_full
// 分层抽样），逐条断言 kind / flag / hitRules(有序) / dictAnchor 与 Python
// classify_v3 现算结果**逐字符一致**（目标 100%，不一致时打印明细）。
//
// plain test()（真实文件 IO，TESTING.md §3.2）；禁止 testWidgets。
// 夹具再生成：& "C:\ProgramData\anaconda3\python.exe" app\tool\gen_classify_fixtures.py fixtures
@Timeout(Duration(minutes: 8))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/classify/classifier.dart';

import 'support.dart';

void main() {
  group('v3 分类器 parity', () {
    late Map<String, dynamic> fixture;
    late List<dynamic> records;
    late BookDict dict;

    setUpAll(() {
      fixture = loadFixtureJson('parity.json');
      records = fixture['records'] as List<dynamic>;
      final Stopwatch sw = Stopwatch()..start();
      dict = buildDictFromAsset();
      stderr.writeln('[parity] 词典构建 ${sw.elapsedMilliseconds}ms '
          '(anchor=${dict.anchorCount}, evidence=${dict.evidenceNameCount})');
    });

    test('夹具规模与覆盖符合任务书要求', () {
      final Map<String, dynamic> cov =
          (fixture['coverage'] as Map<String, dynamic>);
      expect(records.length, greaterThanOrEqualTo(1500));
      expect(records.length, cov['total']);
      final Map<String, dynamic> kinds = cov['kinds'] as Map<String, dynamic>;
      // 四类结果都有（null = 闲聊，JSON 键为字符串 'null'）
      expect(kinds.containsKey('扫书'), isTrue);
      expect(kinds.containsKey('排雷'), isTrue);
      expect(kinds.containsKey('求书'), isTrue);
      expect(kinds.containsKey('null'), isTrue);
      expect(cov['dict_anchor_nonempty'] as int, greaterThanOrEqualTo(100));
      expect(cov['g2_circular_nonempty'] as int, greaterThanOrEqualTo(20));
    });

    test('全部夹具 kind/flag/hitRules/dictAnchor 与 Python 100% 一致', () {
      int kindOk = 0;
      int flagOk = 0;
      int rulesOk = 0;
      int anchorOk = 0;
      int booksOk = 0;
      final List<String> mismatches = <String>[];

      for (var i = 0; i < records.length; i++) {
        final Map<String, dynamic> r = records[i] as Map<String, dynamic>;
        final Map<String, dynamic> exp = r['exp'] as Map<String, dynamic>;
        final String title = r['title'] as String;
        final String firstFloor = r['first_floor'] as String;
        final String fullText = r['full_text'] as String;
        final List<String> booknames =
            (r['booknames'] as List<dynamic>).cast<String>();

        // booknames 实参一致性：Dart 侧《》抽取必须复现 Python extract_booknames
        final List<String> extracted = extractBooknames(fullText);
        if (_listEq(extracted, booknames)) {
          booksOk++;
        } else if (mismatches.length < 40) {
          mismatches.add('#$i tid=${r['tid']} [booknames]\n'
              '  dart=$extracted\n  py  =$booknames');
        }

        final ClassifyResult res = classifyV3(
          title: title,
          firstFloor: firstFloor,
          fullText: fullText,
          booknames: booknames,
          dict: dict,
        );

        final String? expKind = exp['kind'] as String?;
        final int expFlag = exp['flag'] as int;
        final List<String> expRules =
            (exp['hit_rules'] as List<dynamic>).cast<String>();
        final String expAnchor = exp['dict_anchor'] as String;

        if (res.kind == expKind) {
          kindOk++;
        } else if (mismatches.length < 40) {
          mismatches.add('#$i tid=${r['tid']} [kind] dart=${res.kind} py=$expKind'
              ' title=$title');
        }
        if (res.flag == expFlag) {
          flagOk++;
        } else if (mismatches.length < 40) {
          mismatches.add('#$i tid=${r['tid']} [flag] dart=${res.flag} py=$expFlag');
        }
        if (_listEq(res.hitRules, expRules)) {
          rulesOk++;
        } else if (mismatches.length < 40) {
          mismatches.add('#$i tid=${r['tid']} [hitRules]\n'
              '  dart=${res.hitRules}\n  py  =$expRules\n  title=$title');
        }
        if (res.dictAnchor == expAnchor) {
          anchorOk++;
        } else if (mismatches.length < 40) {
          mismatches.add('#$i tid=${r['tid']} [dictAnchor] '
              'dart=${res.dictAnchor} py=$expAnchor title=$title');
        }
      }

      final int n = records.length;
      if (mismatches.isNotEmpty) {
        stderr.writeln('[parity] 不一致明细（前 ${mismatches.length} 条）:');
        for (final String m in mismatches) {
          stderr.writeln(m);
        }
      }
      stderr.writeln('[parity] 一致率: kind=$kindOk/$n flag=$flagOk/$n '
          'hitRules=$rulesOk/$n dictAnchor=$anchorOk/$n booknames=$booksOk/$n');
      expect(kindOk, n, reason: 'kind 一致率必须 100%');
      expect(flagOk, n, reason: 'flag 一致率必须 100%');
      expect(rulesOk, n, reason: 'hitRules 一致率必须 100%（含顺序与 pattern 原文）');
      expect(anchorOk, n, reason: 'dictAnchor 一致率必须 100%');
      expect(booksOk, n, reason: 'extractBooknames 一致率必须 100%');
    });

    test('perf sanity：420 条 eval 分类 < 2s（Python 实测 0.36s，报告 §9.4）', () {
      final List<Map<String, dynamic>> evalRecords = records
          .cast<Map<String, dynamic>>()
          .where((Map<String, dynamic> r) => r['src'] == 'eval')
          .toList();
      expect(evalRecords.length, 420);
      final Stopwatch sw = Stopwatch()..start();
      for (final Map<String, dynamic> r in evalRecords) {
        classifyV3(
          title: r['title'] as String,
          firstFloor: r['first_floor'] as String,
          fullText: r['full_text'] as String,
          booknames: (r['booknames'] as List<dynamic>).cast<String>(),
          dict: dict,
        );
      }
      sw.stop();
      stderr.writeln('[parity] 420 条分类耗时 ${sw.elapsedMilliseconds}ms（JIT）');
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('空词典退化 v2：classifyV3(dict=BookDict.empty) 不抛、dictAnchor 恒空', () {
      final BookDict empty = BookDict.empty();
      expect(empty.isEmpty, isTrue);
      expect(empty.anchorCount, 0);
      expect(empty.evidenceNameCount, 0);
      expect(empty.findBooknames('遮天'), isEmpty);
      expect(empty.findBookname('遮天'), '');
      final ClassifyResult res = classifyV3(
        title: '排雷《测试书名》',
        firstFloor: '雷点：无',
        fullText: '排雷《测试书名》\n雷点：无',
        booknames: extractBooknames('排雷《测试书名》\n雷点：无'),
        dict: empty,
      );
      expect(res.dictAnchor, '');
      expect(res.kind, '排雷'); // 1A 标题起首，不依赖词典
    });
  });
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
