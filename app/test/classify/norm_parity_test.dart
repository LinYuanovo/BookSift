// v3NormText 归一化 parity：2200+ 条语料/构造串与 Python v3_norm_text 输出
// 100% 一致（NFKC-lite 折叠表 + 组合 + lower 全映射 + Final_Sigma 的验收兜底，
// 任务书移植要点第 1 条）。
//
// plain test()（真实文件 IO）；夹具再生成见 gen_classify_fixtures.py。
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/classify/classifier.dart';

import 'support.dart';

void main() {
  group('v3NormText parity', () {
    late List<dynamic> pairs;

    setUpAll(() {
      final Map<String, dynamic> fixture = loadFixtureJson('norm_parity.json');
      pairs = fixture['pairs'] as List<dynamic>;
    });

    test('语料规模 ≥2000', () {
      expect(pairs.length, greaterThanOrEqualTo(2000));
    });

    test('全部语料归一化输出与 Python 100% 一致', () {
      int ok = 0;
      final List<String> mismatches = <String>[];
      for (var i = 0; i < pairs.length; i++) {
        final List<dynamic> pair = pairs[i] as List<dynamic>;
        final String input = pair[0] as String;
        final String expected = pair[1] as String;
        final String actual = v3NormText(input);
        if (actual == expected) {
          ok++;
        } else if (mismatches.length < 30) {
          mismatches.add('#$i input=${_dump(input)}\n'
              '  dart=${_dump(actual)}\n  py  =${_dump(expected)}');
        }
      }
      if (mismatches.isNotEmpty) {
        stderr.writeln('[norm] 不一致明细（前 ${mismatches.length} 条）:');
        for (final String m in mismatches) {
          stderr.writeln(m);
        }
      }
      stderr.writeln('[norm] 一致率 $ok/${pairs.length}');
      expect(ok, pairs.length, reason: 'v3NormText 必须与 Python v3_norm_text 逐字符一致');
    });

    test('空串与纯符号边界', () {
      expect(v3NormText(''), '');
      expect(v3NormText('，。！？'), ''); // 纯标点 → 空
      expect(v3NormText(' \t\r\n\u3000\uFEFF '), ''); // 纯空白（含 BOM）→ 空
    });
  });
}

/// 调试输出：不可见字符显式转义，便于定位归一化差异。
String _dump(String s) {
  final StringBuffer sb = StringBuffer();
  for (final int r in s.runes) {
    if (r >= 0x21 && r <= 0x7E) {
      sb.writeCharCode(r);
    } else {
      sb.write('\\u{${r.toRadixString(16)}}');
    }
  }
  return sb.toString();
}
