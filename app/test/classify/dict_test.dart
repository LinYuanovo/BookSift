// BookDict（trie 索引）与 Python load_book_dict / find_dict_booknames 的统计与
// 语义对拍：anchorCount / evidenceNameCount / 首字桶数 == dict_meta.json
// （= Python 日志行「21913 个可锚点名 / 1597 个首字桶 / G2 另留 88 个」），
// find 探针逐条一致（最长命中、longest 剪枝、G2 证据名不锚定、emoji 书名）。
//
// plain test()（真实文件 IO）。
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/classify/classifier.dart';
import 'package:booksift/classify/src/book_dict.dart';

import 'support.dart';

void main() {
  group('BookDict', () {
    late Map<String, dynamic> meta;
    late BookDictCore core;
    late int buildMs;

    setUpAll(() {
      meta = loadFixtureJson('dict_meta.json');
      final Stopwatch sw = Stopwatch()..start();
      core = buildDictCoreFromAsset();
      sw.stop();
      buildMs = sw.elapsedMilliseconds;
      stderr.writeln('[dict] 构建耗时 ${buildMs}ms (JIT)');
    });

    test('统计与 Python load_book_dict 对齐（dict_meta.json）', () {
      expect(core.anchorCount, meta['anchor_count'],
          reason: '可锚定名数必须与 Python 一致（G2 剔除后）');
      expect(core.evidenceNameCount, meta['evidence_count'],
          reason: 'G2 证据名数必须与 Python 一致');
      expect(core.bucketCount, meta['bucket_count'],
          reason: '首字桶数必须与 Python len(idx) 一致');
      // 报告 §9.1 的公开口径交叉验证
      expect(core.anchorCount, 21913);
      expect(core.evidenceNameCount, 88);
      expect(core.bucketCount, 1597);
    });

    test('构建性能 sanity（Python 侧 30ms，JIT 放宽到 5s）', () {
      expect(buildMs, lessThan(5000));
    });

    test('契约面 BookDict.fromLines 与核心统计一致', () {
      final BookDict dict = buildDictFromAsset();
      expect(dict.anchorCount, core.anchorCount);
      expect(dict.evidenceNameCount, core.evidenceNameCount);
      expect(dict.isEmpty, isFalse);
    });

    test('find 探针与 Python find_dict_booknames/find_dict_bookname 逐条一致', () {
      final List<dynamic> probes = meta['probes'] as List<dynamic>;
      expect(probes.length, greaterThanOrEqualTo(14));
      for (final dynamic probe in probes) {
        final Map<String, dynamic> pr = probe as Map<String, dynamic>;
        final String text = pr['text'] as String;
        final List<String> expectAll =
            (pr['find_all'] as List<dynamic>).cast<String>();
        final String expectOne = pr['find'] as String;
        expect(core.findBooknames(text), expectAll, reason: 'text=$text');
        expect(core.findBookname(text), expectOne, reason: 'text=$text');
      }
    });

    test('最长匹配语义抽查（长名优先 + longest 全局剪枝）', () {
      // contain_pair = [长名, 长名前缀短名]（两者都在词典里，生成器实测挑出）
      final List<dynamic>? pair = (meta['contain_pair'] as List<dynamic>?)?.cast<dynamic>();
      if (pair != null) {
        final String longName = pair[0] as String;
        final String shortName = pair[1] as String;
        final List<String> hits = core.findBooknames(longName);
        expect(hits.first, longName, reason: '最长命中必须是长名');
        // Python 剪枝：位置 0 命中长名后，内部短名（len < longest）被 break 跳过
        expect(hits.contains(shortName), isFalse,
            reason: 'longest 剪枝：更短的内部名不得出现在命中列表');
      }
      // 2 字名「遮天」是 G3 过滤后保留的真书名（报告 §9.1）
      expect(core.findBookname('遮天'), '遮天');
      // G2：证据名（Python 侧实测样本，dict_meta.evidence_names_sample）
      // 必须同样被 Dart 侧剔除——自身永远不出现在命中列表里
      // （证据名的子串可能恰是别的可锚定名，findBookname 结果不做额外假设）
      final List<dynamic> evSample =
          (meta['evidence_names_sample'] as List<dynamic>);
      expect(evSample, isNotEmpty);
      for (final dynamic name in evSample) {
        final String n = name as String;
        expect(core.evidenceNames.contains(n), isTrue, reason: 'G2 证据名 $n');
        expect(core.findBooknames(n).contains(n), isFalse,
            reason: '证据名自身不得进锚点索引: $n');
      }
      // 空词典
      final BookDictCore empty = BookDictCore.empty();
      expect(empty.anchorCount, 0);
      expect(empty.findBooknames('遮天'), isEmpty);
    });
  });
}
