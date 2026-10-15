// test/classify 共享挂具：夹具加载 + 词典构建（plain test 专用，真实文件 IO；
// 不以 _test.dart 结尾，不会被当成 suite 执行——TESTING.md §5 同款约定）。
//
// 夹具由 `python app/tool/gen_classify_fixtures.py fixtures` 生成
// （期望值 = work/collector_poc/collect_poc.py 的 Python v3 现算结果）。
import 'dart:convert';
import 'dart:io';

import 'package:booksift/classify/classifier.dart';
import 'package:booksift/classify/src/book_dict.dart';

Map<String, dynamic> loadFixtureJson(String name) {
  final File f = File('test/classify/fixtures/$name');
  if (!f.existsSync()) {
    throw StateError('缺少夹具 ${f.absolute.path}：'
        '先跑 & "C:\\ProgramData\\anaconda3\\python.exe" '
        'app\\tool\\gen_classify_fixtures.py fixtures');
  }
  return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
}

/// 契约口径：BookDict.fromLines（app/assets 词典与 work 词典同 sha256，
/// dict_meta.json 里有守卫断言）。
BookDict buildDictFromAsset() {
  final List<String> lines = File('assets/dict/book_dict.txt').readAsLinesSync();
  return BookDict.fromLines(lines);
}

/// 内部核心口径（dict_test 需要 bucketCount 等 BookDict 未暴露的统计）。
BookDictCore buildDictCoreFromAsset() {
  final List<String> lines = File('assets/dict/book_dict.txt').readAsLinesSync();
  return BookDictCore.fromLines(lines);
}
