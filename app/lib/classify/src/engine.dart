/// v3 分类引擎（= collect_poc.py 行 858–1314：extract_booknames / classify_v3 /
/// _classify_core / _v2_* 辅助 / _v3_circular_pats 的逐函数移植）。
///
/// 移植总原则（分类规则迭代报告.md §7 + §9.4 第 12–17 条）：
///   · **判定顺序是规则本体**：1A > 1B > 1C > 1D > 2a > 2b强 > 2c > 2b弱 > 2d
///     > 2e > 2f > G4回流 > 闲聊，每处次序对应一个具体错例，禁止改写成打分制；
///   · 极性过滤（stripDefensive）必须**全部剔除完再匹配**，且用全局替换；
///   · 软证据让位（v2.1r3b）：让位时不 return，继续找硬证据；
///   · 长度/计数一律按**码点**（Python len 口径）：折叠串 1 码点 = 1 码元，
///     故 folded.length 即码点数（见 py_regex.dart foldText）；书名/词典长度用
///     runes.length；
///   · 所有正则匹配的输入必须是 foldText 后的折叠串（量词计数的码点对齐）；
///   · hit_rules 字符串与 Python f-string 逐字符一致（pattern 原文嵌入）。
///
/// v1 规则不移植（冻结仅供 Python 评测对比，且含后顾断言不可移植，行 84–87）。
/// fullText 参数与 Python _classify_core 一致——形参保留但不参与判定
/// （booknames 已由调用方在全文上抽取好）。
library;

import '../classifier.dart';
import 'book_dict.dart';
import 'norm.dart';
import 'py_regex.dart';
import 'py_unicode.dart';
import 'rules.dart';

// ============================================================================
// 书名抽取（= extract_booknames，行 858–869）
// ============================================================================

/// 《([^《》\r\n]{1,40})》 的 rune 扫描器等价实现：{1,40} 按码点计数；
/// 内容遇 《/》/\r/\n 即该起点失败（类排除字符，回溯也不可跨越）；
/// 成功后 finditer 从 》 之后继续。去重键 = 去空白后的名字（行 865）。
List<String> extractBooknamesImpl(String text) {
  final List<int> runes = text.runes.toList(growable: false);
  final List<String> out = <String>[];
  final Set<String> seen = <String>{};
  var i = 0;
  while (i < runes.length) {
    if (runes[i] != 0x300A) {
      // 《
      i++;
      continue;
    }
    var end = -1;
    var bad = false;
    // 》 最远可在 i+41（40 个内容码点之后）
    for (var j = i + 1; j <= i + 41 && j < runes.length; j++) {
      final int r = runes[j];
      if (r == 0x300B) {
        // 》
        end = j;
        break;
      }
      if (r == 0x300A || r == 0x0D || r == 0x0A) {
        // 《 \r \n
        bad = true;
        break;
      }
    }
    // 空内容（《》相邻）不满足 {1,40} → 该起点失败，从 i+1 重扫
    if (bad || end < 0 || end == i + 1) {
      i++;
      continue;
    }
    final String name = pyStrip(
      String.fromCharCodes(runes, i + 1, end),
    ); // .strip()
    i = end + 1;
    if (name.isEmpty) continue;
    final String key = pyRemoveAllWs(name); // re.sub(r"\s+", "", name)
    if (key.isNotEmpty && seen.add(key)) out.add(name);
  }
  return out;
}

// ============================================================================
// v2 辅助（行 920–1050）
// ============================================================================

/// 极性过滤：剔除防御性/偏好性表述（= _v2_strip_defensive，行 924–929）。
/// 24+ 条全部剔除完再返回（全局替换；边剔边判会出错，报告 §7 第 4 条）。
String _stripDefensive(String foldedText) {
  var t = foldedText;
  for (final PyRegex p in v2MineDefensive) {
    t = p.removeAll(t);
  }
  return t;
}

/// 返回第一个命中的 pattern（= _v2_first，行 932–940）。
/// [skip] 内的 pattern 跳过（v3 G2：循环证据作废）。
PyRegex? _firstHit(
  List<PyRegex> pats,
  String foldedText, [
  Set<String> skip = const <String>{},
]) {
  for (final PyRegex p in pats) {
    if (skip.contains(p.source)) continue;
    if (p.hasMatch(foldedText)) return p;
  }
  return null;
}

/// 2a 正文排雷判定结果（= _v2_content_mine 的四元组返回值中实际被消费的三项；
/// structural 位在 Python 里也未被调用方使用，行 1256 解包即弃）。
typedef _MineOutcome = ({bool mine, String rule, String deferred});

/// 2a 正文排雷判定（= _v2_content_mine，行 943–998）。
///
/// 证据强度：结构证据 > 雷术语 > 弱雷术语 > 雷词 > 负评词；三道门控
/// （meta 抑制 / 锚点门控[v3 含词典锚点] / 报告体让位）+ v3 两道专属守卫
/// （G2 循环证据作废、G4 软证据让位——deferred 由调用方在 2f 之后回流）。
///
/// [ft]/[ff] 为折叠后的标题/首楼；[rawTitle]/[rawFirstFloor] 为原文
/// （G2 的 v3_norm_text 输入必须是原文，行 975）。
_MineOutcome _contentMine(
  String ft,
  String ff,
  String rawTitle,
  String rawFirstFloor,
  bool meta,
  int nField,
  List<String> dictHits,
  BookDictCore dict,
) {
  final String t = _stripDefensive(ft);
  final String f = _stripDefensive(ff);
  PyRegex? pat = _firstHit(v2MineStructural, f);
  pat ??= _firstHit(v2MineStructural, t); // 行 966：先首楼后标题
  if (pat != null) {
    return (mine: true, rule: 'T2a:排雷结构~${pat.source}', deferred: '');
  }
  if (meta) return (mine: false, rule: '', deferred: ''); // 行 969–970
  final bool anchor = v2AnchorRe.hasMatch('$t\n$f'); // 行 971
  if (!anchor && dictHits.isEmpty) {
    return (mine: false, rule: '', deferred: ''); // 行 973–974（锚点门控）
  }
  // G2：锚点只来自词典时，帖内提到的"自身即雷词"书名对应的 pattern 作废（行 975）
  final Set<String> skip = anchor
      ? const <String>{}
      : _v3CircularPats(
          v3NormTextImpl('$rawTitle\n$rawFirstFloor'),
          dict.evidenceNames,
        );
  var deferred = '';
  // 行 977–980：四组证据按强度顺序
  for (final (List<PyRegex> group, String tag, bool soft)
      in <(List<PyRegex>, String, bool)>[
        (v2MineTerms, '雷术语', true),
        (v2MineTermsWeak, '弱雷术语', true),
        (v2MineWords, '雷词', false),
        (v2NegWords, '负评词', false),
      ]) {
    final PyRegex? p = _firstHit(group, f, skip);
    if (p == null) continue;
    // 报告体让位（行 989–991）：软证据在冒号字段≥3 时让位给 2b——
    // Python 的 soft_hit 记账是死变量（返回后无人消费），语义 = continue。
    // v2.1r3b：让位不 return，继续找硬证据（否则弱术语 preempt 掉劝退/难绷）。
    if (soft && nField >= v2ScanFieldStrong) continue;
    if (anchor) {
      return (
        mine: true,
        rule: 'T2a:首楼$tag(锚点)~${p.source}',
        deferred: '',
      ); // 行 992–993
    }
    if (soft) {
      // G4：仅词典锚点 + 术语级软证据 → 让位 2c/2f，记下待定规则（行 994–996）
      deferred = deferred.isEmpty
          ? 'T2a:首楼$tag(词典锚点·让位)~${p.source}~${dictHits.first}'
          : deferred;
      continue;
    }
    return (
      mine: true,
      rule: 'T2a:首楼$tag(词典锚点)~${p.source}~${dictHits.first}',
      deferred: '',
    ); // 行 997
  }
  return (mine: false, rule: '', deferred: deferred); // 行 998
}

/// 结构化书评字段（带冒号）计数（= _v2_scan_fields，行 1001–1003）。
int _scanFields(String ff) {
  var n = 0;
  for (final PyRegex p in v2ScanFields) {
    if (p.hasMatch(ff)) n++;
  }
  return n;
}

/// 首楼是否含任何负评/雷证据（极性过滤后）（= _v2_has_negative，行 1006–1013；
/// 注意组顺序与 _contentMine 不同：负评词在最前）。
bool _hasNegative(String ff) {
  final String f = _stripDefensive(ff);
  for (final List<PyRegex> group in <List<PyRegex>>[
    v2NegWords,
    v2MineTerms,
    v2MineTermsWeak,
    v2MineWords,
  ]) {
    if (_firstHit(group, f) != null) return true;
  }
  return false;
}

/// 2b 扫书模板判定结果（= _v2_scan_template 三元组）。
typedef _TplOutcome = ({bool tpl, String rule, bool weak});

/// 2b 扫书模板（= _v2_scan_template，行 1016–1034）。
/// 弱证据（行首书名行≥2）延后到 2c 之后判（修 #305 求书帖列举示例书名）。
_TplOutcome _scanTemplate(String ff, int nField, bool metaTitle) {
  final int nLineBooks = v2LineBookRe.countMatches(ff); // findall 计数
  final bool weak = nLineBooks >= v2LineBookMin;
  if (metaTitle) return (tpl: false, rule: '', weak: weak);
  for (final PyRegex p in v2ScanTemplate) {
    if (p.hasMatch(ff)) {
      return (tpl: true, rule: 'T2b:书单模板~${p.source}', weak: weak);
    }
  }
  if (nField >= v2ScanFieldMin && v2AnchorRe.hasMatch(ff)) {
    return (tpl: true, rule: 'T2b:结构化书评字段=$nField', weak: weak);
  }
  for (final PyRegex p in v2ScanSelfdecl) {
    if (p.hasMatch(ff)) {
      return (tpl: true, rule: 'T2b:自述推荐帖~${p.source}', weak: weak);
    }
  }
  return (tpl: false, rule: '', weak: weak);
}

/// 疑问信号计数：问号 + 句尾 吗/呢/么 + 标点后的疑问短语（= _v2_question，
/// 行 1045–1050）。问号计数按码元即码点（'?''？' 均 BMP）。
int _questionMarks(String foldedText) {
  var n = 0;
  for (var i = 0; i < foldedText.length; i++) {
    final int u = foldedText.codeUnitAt(i);
    if (u == 0x3F || u == 0xFF1F) n++; // ? ？
  }
  n += v2QuestionTailRe.countMatches(foldedText);
  n += v2QuestionMidRe.countMatches(foldedText);
  return n;
}

/// G2 循环证据作废（= _v3_circular_pats，行 1146–1160）：帖内提到的书名自身
/// 即雷词/负评词时（"类似逆天邪神一样的传统玄幻"），这些词作废不作负评证据。
/// 仅在"锚点只来自词典"时调用（《》锚点帖沿用 v2 口径）。
Set<String> _v3CircularPats(String textNorm, Set<String> evidenceNames) {
  if (evidenceNames.isEmpty) return const <String>{};
  final List<String> mentioned = evidenceNames
      .where(textNorm.contains)
      .toList(growable: false);
  if (mentioned.isEmpty) return const <String>{};
  final Set<String> bad = <String>{};
  for (final List<PyRegex> group in <List<PyRegex>>[
    v2MineTerms,
    v2MineTermsWeak,
    v2MineWords,
    v2NegWords,
  ]) {
    for (final PyRegex p in group) {
      if (mentioned.any((String n) => p.hasMatch(foldText(n)))) {
        bad.add(p.source);
      }
    }
  }
  return bad;
}

// ============================================================================
// 两级分类核心（= _classify_core，行 1184–1310）
// ============================================================================

ClassifyResult _result(
  String? kind,
  List<String> hitRules,
  List<String> booknames,
  String dictAnchor,
) {
  return ClassifyResult(
    kind: kind,
    flag: kind == null ? 0 : kindFlag[kind]!,
    hitRules: hitRules,
    booknames: booknames,
    dictAnchor: dictAnchor,
  );
}

/// 标题意图优先的两级分类（v2/v3 共用引擎）。[dictHits] 非空即 v3 词典锚点
/// 命中（只影响 2a 锚点门控）；空列表 = v2 行为。
///
/// meta 分两级（v2.1r2，行 1197–1199）：meta_title 压制 1B/1C/1D 与
/// 2b/2c/2e/2f；meta_content 只压制 2a 的术语/负评证据与 2e/2f。
ClassifyResult _classifyCore(
  String title,
  String firstFloor,
  List<String> booknames,
  List<String> dictHits,
  BookDictCore dict,
  String dictAnchor,
) {
  final String ft = foldText(title); // 折叠串：量词按码点计数，length=码点数
  final String ff = foldText(firstFloor);

  final bool metaTitle = v2MetaTitle.hasMatch(ft); // 行 1200
  final bool metaContent = v2MetaContent.hasMatch('$ft\n$ff'); // 行 1196/1201
  final bool meta = metaTitle || metaContent; // 行 1202
  final bool blocked = v2SeekTitleBlock.hasMatch(ft); // 行 1204
  final bool share = v2ShareTitle.hasMatch(ft); // 行 1206
  final bool questionTitle = v2TitleQuestion.hasMatch(
    pyRstrip(ft, titleRstripChars),
  ); // 行 1208
  final String titleClean = _stripDefensive(ft); // 行 1209

  // ---------- 第一级：标题意图 ----------
  // 1A 标题起首排雷（最强，行 1213–1216）
  final Match? m1a = v2MineTitlePrefix.firstMatch(titleClean);
  if (m1a != null) {
    return _result(
      PostKind.mine,
      <String>['T1a:标题起首~${m1a.group(1)}'],
      booknames,
      dictAnchor,
    );
  }

  if (!metaTitle) {
    // 1B 标题求书意图（先于 1C/1D；收集全部命中，行 1219–1231）
    if (!blocked) {
      final List<String> seekHits = <String>[];
      for (final Rule rule in v2SeekTitlePatterns) {
        if (share && v2SeekWeakRules.contains(rule.name)) continue;
        if (rule.hasMatch(ft)) {
          final PyRegex? exc = v2SeekPatternExcludes[rule.name];
          if (exc != null && exc.hasMatch(ft)) continue;
          seekHits.add('T1b:标题求书~${rule.name}');
        }
      }
      if (seekHits.isNotEmpty) {
        return _result(PostKind.seek, seekHits, booknames, dictAnchor);
      }
    }

    // 1C 标题任意位置排雷（极性过滤后匹配；首中即返回，行 1234–1237）
    for (final Rule rule in v2MineTitleAny) {
      if (rule.hasMatch(titleClean)) {
        return _result(
          PostKind.mine,
          <String>['T1c:标题含雷~${rule.name}'],
          booknames,
          dictAnchor,
        );
      }
    }
    if (!questionTitle) {
      // 1C 社区雷术语（疑问标题门控，行 1238–1242）
      for (final Rule rule in v2MineTitleTerms) {
        if (rule.hasMatch(titleClean)) {
          return _result(
            PostKind.mine,
            <String>['T1c:标题雷术语~${rule.name}'],
            booknames,
            dictAnchor,
          );
        }
      }
    }

    // 1D 标题扫书意图（收集全部命中，行 1245–1251）
    if (!blocked) {
      final List<String> scanHits = <String>[];
      for (final Rule rule in v2ScanTitlePatterns) {
        if (rule.hasMatch(ft)) scanHits.add('T1d:标题扫书~${rule.name}');
      }
      if (scanHits.isNotEmpty) {
        return _result(PostKind.scan, scanHits, booknames, dictAnchor);
      }
    }
  }

  // ---------- 第二级：正文特征兜底（行 1253–1310） ----------
  final int nField = _scanFields(ff); // 行 1254

  // 2a 排雷（结构证据 或 (《》/指代锚点 或 v3 词典锚点) + 极性过滤后的雷/负评词）
  final _MineOutcome mine = _contentMine(
    ft,
    ff,
    title,
    firstFloor,
    metaContent,
    nField,
    dictHits,
    dict,
  );
  if (mine.mine) {
    return _result(PostKind.mine, <String>[mine.rule], booknames, dictAnchor);
  }

  // 2b强 扫书模板（只受 meta_title 抑制，v2.1r3，行 1261–1266）
  final _TplOutcome tpl = _scanTemplate(ff, nField, metaTitle);
  if (tpl.tpl) {
    return _result(PostKind.scan, <String>[tpl.rule], booknames, dictAnchor);
  }

  // 2c 求书内容（先于弱书单证据，修 #305，行 1268–1273）
  if (!meta && !blocked) {
    final PyRegex? p = _firstHit(v2SeekContent, ff);
    if (p != null) {
      return _result(
        PostKind.seek,
        <String>['T2c:首楼求书~${p.source}'],
        booknames,
        dictAnchor,
      );
    }
  }

  // 2b弱 行首书名行≥2（行 1275–1277）
  if (tpl.weak && !metaTitle) {
    return _result(
      PostKind.scan,
      <String>['T2b:行首书名行≥2'],
      booknames,
      dictAnchor,
    );
  }

  // 2d 书名数≥阈值（意图门控，行 1279–1283）
  if (booknames.length >= v2BooknameMin) {
    return _result(
      PostKind.scan,
      <String>['T2d:书名数=${booknames.length}>=$v2BooknameMin'],
      booknames,
      dictAnchor,
    );
  }

  // 2e 单本正向分享（书名数≤2 + 《》起头或短标题 + 首楼无负评/雷证据，行 1285–1295）
  if (!meta &&
      booknames.length <= v2SingleShareMaxBooks &&
      (ft.startsWith('《') || ft.length <= v2SingleShareMaxTitle) &&
      !_hasNegative(ff)) {
    for (final PyRegex cue in v2SingleShareCue) {
      if (cue.hasMatch(ff)) {
        return _result(
          PostKind.scan,
          <String>['T2e:单本正向分享~${cue.source}'],
          booknames,
          dictAnchor,
        );
      }
    }
  }

  // 2f 疑问句兜底（短首楼 + 疑问信号≥2 + 请求词素，行 1297–1303）
  if (!meta &&
      !blocked &&
      ff.length <= v2QuestionMaxChars &&
      _questionMarks(ff) >= v2QuestionMinMarks &&
      v2QuestionTokens.hasMatch(ff)) {
    return _result(
      PostKind.seek,
      <String>['T2f:短首楼疑问句'],
      booknames,
      dictAnchor,
    );
  }

  // G4 回流：仅词典锚点 + 术语级软证据在 2b~2f 都没接管时，仍按排雷入库（行 1305–1308）
  if (mine.deferred.isNotEmpty) {
    return _result(
      PostKind.mine,
      <String>[mine.deferred],
      booknames,
      dictAnchor,
    );
  }

  // 闲聊（行 1310）
  return _result(
    null,
    <String>['闲聊:无命中(书名数=${booknames.length})'],
    booknames,
    dictAnchor,
  );
}

/// 条目三分类型（扫书 / 推书 / 排雷）：书卡「x扫书 x推荐 x排雷」计数与条目徽标共用。
///
/// 存量库没有 hit_rules，帖级 post_kind 又把推书并进扫书（分类链有 Python parity 夹具，
/// 推书并进扫书是冻结口径）——这里只用「颜色标记 + 帖标题 + 类别」还原三档：
///   ① 绿标(+1)   → 推书档（排雷帖里的绿标条目仍算推荐，标记优先，口径同 entryFlagOf）；
///   ② 红标(−1)   → 排雷档；
///   ③ 标题排雷词 → 排雷档（无标记的排雷帖条目靠这条归位）；
///   ④ 标题推书词 → 推书档（「推荐/推书/安利…」，修复「明确是推书仍显示为扫书」）；
///   ⑤ 类别=求书  → 求书（保留灰徽标语义）；⑥ 其余 → 扫书。
final RegExp _entryAvoidanceReview = RegExp(
  r'(?:作者|楼主|书友|读者)[^，,。！？!?；;]{0,6}(?:排雷|避雷)'
  r'(?:建议|说明|提醒|说法)?[^，,。！？!?；;]{0,6}'
  r'(?:不错|很好|挺好|很棒|靠谱|到位|专业|有用|准确|及时|负责|细致|不靠谱|不好|不行|不准确|不恰当|没用|无用|错误|太差|很差|离谱)',
);

final RegExp _entryPositiveAvoidanceReview = RegExp(
  r'(?:作者|楼主|书友|读者)[^，,。！？!?；;]{0,6}(?:排雷|避雷)'
  r'(?:建议|说明|提醒|说法)?[^，,。！？!?；;]{0,6}'
  r'(?:不错|很好|挺好|很棒|靠谱|到位|专业|有用|准确|及时|负责|细致)',
);

final RegExp _entryNegativeAvoidanceReview = RegExp(
  r'(?:作者|楼主|书友|读者)[^，,。！？!?；;]{0,6}(?:排雷|避雷)'
  r'(?:建议|说明|提醒|说法)?[^，,。！？!?；;]{0,6}'
  r'(?:不靠谱|不好|不行|不准确|不恰当|没用|无用|错误|太差|很差|离谱)',
);

final RegExp _entrySarcasticReview = RegExp(
  r'(?:不错|很好|挺好|很棒|靠谱|到位|专业|有用|准确|推荐|安利)[^，,。！？!?；;]{0,6}'
  r'(?:个鬼|才怪|才不是|才没有|别信|假的|呵呵|笑死)',
);

final RegExp _entryNegatedMineMention = RegExp(
  r'(?:并没有|没有|不是|并非|不算|无需|不需要|没必要|不打算|不想|不做|别|不必|不用|不|没|未)'
  r'[^，,。！？!?；;]{0,4}(?:排雷|避雷|踩雷|扫雷)(?:建议|帖|贴)?'
  r'|(?:排雷|避雷|踩雷|扫雷)[？?，,]?[^，,。！？!?；;]{0,6}'
  r'(?:才怪|才不是|才没有|不存在|是假的|都是假的)',
);

final RegExp _entryNonBookMineMention = RegExp(
  r'(?:反向|反着)(?:排雷|避雷|踩雷|扫雷)'
  r'|(?:作者|楼主|书友|读者)[^，,。！？!?；;]{0,6}'
  r'(?:排雷|避雷|踩雷|扫雷)(?:建议|说明|提醒|说法|清单|帖|贴)?'
  r'|(?:排雷|避雷|踩雷|扫雷)(?:这位|这个|该)?(?:作者|楼主|书友|读者)',
);

final RegExp _entryBookNegativeEvaluation = RegExp(
  r'(?:《[^》]{1,40}》|这本(?:书)?|本书|这部(?:小说|作品))'
  r'[^，,。！？!?；;]{0,12}(?:很|太|真|有点|非常|实在|简直)?'
  r'(?:雷|毒|烂|降智|恶心|难绷|难蚌|垃圾|劝退)(?:啊|了|至极)?'
    r'(?![^，,。！？!?；;]{0,4}(?:短|少|一般|还行|可以接受))',
);

final RegExp _entryNegatedBookNegativeEvaluation = RegExp(
  r'(?:《[^》]{1,40}》|这本(?:书)?|本书|这部(?:小说|作品))'
  r'[^，,。！？!?；;]{0,12}(?:不是|并非|不算|没那么|不怎么|不太)'
  r'(?:很|太|真|有点|非常|实在|简直)?'
  r'(?:雷|毒|烂|降智|恶心|难绷|难蚌|垃圾|劝退)',
);

final RegExp _entryExplicitNegativeConclusion = RegExp(
  r'(?:毒点|郁闷)[^。]{0,20}'
  r'(?:真劝退|劝退|弃书|弃了|看不下去|忍不了|没法忍)',
);

/// 首楼开头明确写出的帖子类型；只认人工标签，避免正文普通提及触发。
String? explicitManualKind(String firstFloor) {
  final String body = firstFloor.trimLeft();
  if (<String>['排雷', '避雷', '踩雷', '扫雷'].any(body.startsWith)) {
    return PostKind.mine;
  }
  if (<String>['推书', '推荐'].any(body.startsWith)) {
    return kRecommendKind;
  }
  return null;
}

String entryKindLabel({
  required String category,
  required int flag,
  String? title,
  String? bookGrade,
}) {
  // 条目级人工推书是显式事实；其余类别仍走标题/标记三分。
  if (category == kRecommendKind) {
    return kRecommendKind;
  }
  if (flag == 1) {
    return kRecommendKind;
  }
  final String ft = foldText(title ?? '');
  final String titleClean = _stripDefensive(ft);
  final bool avoidanceMeta =
      _entryAvoidanceReview.hasMatch(ft) ||
      _entryNegatedMineMention.hasMatch(ft) ||
      _entryNonBookMineMention.hasMatch(ft);
  final bool negativeAvoidanceReview =
      _entryNegativeAvoidanceReview.hasMatch(ft) ||
      (_entrySarcasticReview.hasMatch(ft) && avoidanceMeta);
  if (negativeAvoidanceReview) {
    return PostKind.mine;
  }
  if (flag == -1 && (bookGrade == '#FF0000' || !avoidanceMeta)) {
    return PostKind.mine;
  }
  if (ft.isNotEmpty) {
    // 避雷词可能在评价「作者的避雷建议」，或被否定/反向表达；先剔除这类
    // 非书籍排雷语境，再判断剩下的线索，避免一个词盖过标题里的真正对象。
    final String mineProbe = titleClean
        .replaceAll(_entryAvoidanceReview, '')
        .replaceAll(_entryNegatedMineMention, '')
        .replaceAll(_entryNonBookMineMention, '');
    final String bookReviewProbe = titleClean.replaceAll(
      _entryNegatedBookNegativeEvaluation,
      '',
    );
    final bool hasBookNegative = _entryBookNegativeEvaluation.hasMatch(
      bookReviewProbe,
    );
    if (hasBookNegative || v2MineTitlePrefix.hasMatch(mineProbe)) {
      return PostKind.mine;
    }
    if (_entryExplicitNegativeConclusion.hasMatch(titleClean)) {
      return PostKind.mine;
    }
    if (_entryPositiveAvoidanceReview.hasMatch(ft)) {
      return kRecommendKind;
    }
    for (final Rule rule in recommendTitlePatterns) {
      if (rule.hasMatch(ft)) {
        return kRecommendKind;
      }
    }
  }
  if (category == PostKind.seek) {
    return PostKind.seek;
  }
  return PostKind.scan;
}

/// 三分「推书」档的展示值（不是入库枚举：posts.post_kind 仍写扫书）。
const String kRecommendKind = '推书';

// ============================================================================
// 生产入口（= classify_v3，行 1163–1175）
// ============================================================================

/// v3 分类（契约 classifyV3 的实现体）：词典锚点只解除 2a 门控（G1），
/// 判定主体与 v2 完全共用 [_classifyCore]；dict_anchor = 最长词典命中。
ClassifyResult classifyV3Core({
  required String title,
  required String firstFloor,
  required String fullText,
  required List<String> booknames,
  required BookDictCore dict,
}) {
  final List<String> hits = dict.findBooknames('$title\n$firstFloor');
  return _classifyCore(
    title,
    firstFloor,
    booknames,
    hits,
    dict,
    hits.isEmpty ? '' : hits.first, // 行 1174：res.dict_anchor = hits[0]
  );
}
