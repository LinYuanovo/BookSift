// 规则常量转录守卫：Dart 侧 rules.dart 的每条 (规则名, pattern 源串) 与
// Python collect_poc.py 常量 dump（patterns.json，由 gen_classify_fixtures.py
// 从模块属性直接导出）逐字符、逐顺序一致。
//
// 为什么要这道守卫：pattern 源串会被原样嵌进 hit_rules（T2a:首楼负评词(锚点)~…），
// 一个字符的转录漂移都会让 parity 夹具炸得莫名其妙——这里先把漂移钉死在常量层。
// 同时守卫 V3_NORM_WS/PUNCT 字符集与 Python 正则 fullmatch 实测成员一致。
@Timeout(Duration(minutes: 2))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/classify/classifier.dart';
import 'package:booksift/classify/src/py_regex.dart';
import 'package:booksift/classify/src/py_unicode.dart';
import 'package:booksift/classify/src/rules.dart';

import 'support.dart';

void main() {
  group('规则常量 patterns parity', () {
    late Map<String, dynamic> p;

    setUpAll(() {
      p = loadFixtureJson('patterns.json');
    });

    void checkNamed(String key, List<Rule> rules) {
      final List<dynamic> expected = p[key] as List<dynamic>;
      expect(rules.length, expected.length, reason: '$key 条数');
      for (var i = 0; i < rules.length; i++) {
        final List<dynamic> e = expected[i] as List<dynamic>;
        expect(rules[i].name, e[0] as String, reason: '$key[$i].name');
        expect(rules[i].source, e[1] as String, reason: '$key[$i].pattern');
      }
    }

    void checkSources(String key, List<PyRegex> pats) {
      final List<dynamic> expected = p[key] as List<dynamic>;
      expect(pats.length, expected.length, reason: '$key 条数');
      for (var i = 0; i < pats.length; i++) {
        expect(pats[i].source, expected[i] as String, reason: '$key[$i]');
      }
    }

    void checkSingle(String key, PyRegex re) {
      expect(re.source, p[key] as String, reason: key);
    }

    test('版本 / kindFlag / PostKind', () {
      expect(classifierVersion, p['classifier_version'] as int);
      final Map<String, dynamic> kf = p['kind_flag'] as Map<String, dynamic>;
      expect(kindFlag.length, kf.length);
      kf.forEach((String k, dynamic v) => expect(kindFlag[k], v as int));
      expect(PostKind.scan, '扫书');
      expect(PostKind.mine, '排雷');
      expect(PostKind.seek, '求书');
    });

    test('书名抽取 / 标题级 pattern 单例', () {
      expect(booknameReSource, p['bookname_re'] as String);
      checkSingle('v2_mine_title_prefix', v2MineTitlePrefix);
      checkSingle('v2_share_title', v2ShareTitle);
      checkSingle('v2_seek_title_block', v2SeekTitleBlock);
      checkSingle('v2_title_question', v2TitleQuestion);
      checkSingle('v2_anchor_re', v2AnchorRe);
      checkSingle('v2_meta_title', v2MetaTitle);
      checkSingle('v2_meta_content', v2MetaContent);
      checkSingle('v2_line_book_re', v2LineBookRe);
      checkSingle('v2_question_tokens', v2QuestionTokens);
      checkSingle('question_tail_re', v2QuestionTailRe);
      checkSingle('question_mid_re', v2QuestionMidRe);
      checkSingle('v3_evidence_re', v3EvidenceRe);
    });

    test('具名规则表（顺序 + 规则名 + 源串）', () {
      checkNamed('v2_seek_title_patterns', v2SeekTitlePatterns);
      checkNamed('v2_mine_title_any', v2MineTitleAny);
      checkNamed('v2_mine_title_terms', v2MineTitleTerms);
      checkNamed('v2_scan_title_patterns', v2ScanTitlePatterns);
    });

    test('匿名 pattern 表（顺序 + 源串）', () {
      checkSources('v2_mine_defensive', v2MineDefensive);
      checkSources('v2_mine_structural', v2MineStructural);
      checkSources('v2_mine_terms', v2MineTerms);
      checkSources('v2_mine_terms_weak', v2MineTermsWeak);
      checkSources('v2_mine_words', v2MineWords);
      checkSources('v2_neg_words', v2NegWords);
      checkSources('v2_scan_template', v2ScanTemplate);
      checkSources('v2_scan_fields', v2ScanFields);
      checkSources('v2_scan_selfdecl', v2ScanSelfdecl);
      checkSources('v2_seek_content', v2SeekContent);
      checkSources('v2_single_share_cue', v2SingleShareCue);
    });

    test('弱式门控集合 / 例外排除表', () {
      final List<dynamic> weak = p['v2_seek_weak_rules'] as List<dynamic>;
      expect(v2SeekWeakRules, weak.cast<String>().toSet());
      final Map<String, dynamic> exc =
          p['v2_seek_pattern_excludes'] as Map<String, dynamic>;
      expect(v2SeekPatternExcludes.length, exc.length);
      exc.forEach((String k, dynamic v) {
        expect(v2SeekPatternExcludes[k]?.source, v as String, reason: k);
      });
    });

    test('标量阈值', () {
      expect(v2ScanFieldMin, p['v2_scan_field_min'] as int);
      expect(v2ScanFieldStrong, p['v2_scan_field_strong'] as int);
      expect(v2LineBookMin, p['v2_line_book_min'] as int);
      expect(v2BooknameMin, p['v2_bookname_min'] as int);
      expect(v2SingleShareMaxBooks, p['v2_single_share_max_books'] as int);
      expect(v2SingleShareMaxTitle, p['v2_single_share_max_title'] as int);
      expect(v2QuestionMinMarks, p['v2_question_min_marks'] as int);
      expect(v2QuestionMaxChars, p['v2_question_max_chars'] as int);
      expect(v3DictMinLen, p['v3_dict_min_len'] as int);
    });

    test('title.rstrip 字符集', () {
      final String chars = p['title_rstrip_chars'] as String;
      expect(titleRstripChars, chars.runes.toSet());
    });

    test('V3_NORM_WS/PUNCT 字符集与 Python 正则成员全等（BMP 全域扫描）', () {
      final Set<int> wsPy = (p['v3_norm_ws_chars'] as List<dynamic>)
          .cast<int>()
          .toSet();
      final Set<int> punctPy = (p['v3_norm_punct_chars'] as List<dynamic>)
          .cast<int>()
          .toSet();
      final List<String> diff = <String>[];
      for (var c = 0; c <= 0xFFFF; c++) {
        if (c >= 0xD800 && c <= 0xDFFF) continue; // 代理项不是字符
        if (normWsSet.contains(c) != wsPy.contains(c)) {
          diff.add('ws U+${c.toRadixString(16)}');
        }
        if (normPunctSet.contains(c) != punctPy.contains(c)) {
          diff.add('punct U+${c.toRadixString(16)}');
        }
      }
      expect(diff, isEmpty, reason: '字符集成员差异: ${diff.take(20).toList()}');
      // pyWsSet = normWs − U+FEFF（str.strip()/isspace 不剥 BOM）
      expect(pyWsSet.contains(0xFEFF), isFalse);
      expect(normWsSet.contains(0xFEFF), isTrue);
    });
  });
}
