/// Python Unicode 语义等价层（二）：re → RegExp 方言转换 + 非 BMP 折叠。
///
/// collect_poc.py 规则区承诺的正则子集（源文件行 85–87）：只用「字面量 / 字符类 /
/// 交替 / 量词 / (?!...) 前瞻」，无后顾断言、无 \b、无命名组、无内联 (?i)。
/// 全表 329 条 pattern 已逐条审计（2026-10-13 探针），需要转换的方言差异恰好五类：
///
///   1. `\d`：Python3 str 模式 = Unicode Nd（含全角１２３）；ECMAScript = ASCII。
///      → 展开成 [ndClassBody]（生成表，仅 BMP；文本已折叠故非 BMP 数字不可达）。
///      全表仅 1 处（求量词本，行 151）。
///   2. `\s`：Python = isspace()（多出 \x1C-\x1F、\x85）；ECMAScript = 多出 \uFEFF。
///      → 展开成 [pyWsClassBody]（实测集合）。全表 5 处。
///   3. `.`：Python 只排除 \n；ECMAScript 还排除 \r \u2028 \u2029。
///      → 替换为 [^\n]。全表 1 处（雷点.{0,4}…，V2_MINE_DEFENSIVE 行 307）。
///   4. `$`（无 re.M）：Python 还匹配「结尾 \n 之前」；ECMAScript 只匹配结尾。
///      → 替换为 (?:$|\n$)。全表 3 处（V2_TITLE_QUESTION、找不到资源、V2_SEEK_CONTENT）。
///   5. `(?m)^`：Python 的行首 = 串首或 \n 后；ECMAScript multiLine 的行首还包括
///      \r/\u2028/\u2029 之后（超集，会多命中）。全表 1 处（V2_LINE_BOOK_RE，只做
///      findall 计数）→ 不设 multiLine，把 ^ 改写成消耗式的 (?:\n|^)：与前一个匹配
///      结束位（必为 》）之间的 \n 不会被吃进上一个匹配，计数与 Python 一一对应。
///
/// 量词计数单位：Python 按码点，Dart 按 UTF-16 码元。语料 emoji 极多（🍅🐢😋🤮），
/// [^，。]{0,N} 一类窗口跨过 emoji 时两侧计数不同 → 匹配前对文本跑 [foldText]：
/// 每个非 BMP 码点折成单个 PUA 字符（🐢 是全表唯一非 BMP 字面量，专属槽位
/// \uE001；其余 → \uE000）。折叠是 1 码点 → 1 码元的保序双射，因此折叠串上的
/// 一切量词计数、`^$` 锚位、类成员判定与 Python 原文逐位等价（PUA 字符不在任何
/// 模式的正/负类枚举里，与 emoji 在 Python 侧的"任意非类字符"行为一致；语料/词典
/// 实测 0 个字面 PUA，见 dict_meta）。pattern 侧用同一映射折叠（[compilePyRegex]）。
///
/// re.sub 全局替换 → [PyRegex.removeAll]（同为最左不重叠；防御性 24 条均含字面量
/// 核心，无零长匹配歧义）。re.search → hasMatch/firstMatch。re.findall 计数 →
/// [PyRegex.countMatches]（本引擎所有 findall 只用 len()，不用捕获内容）。
library;

import 'unicode_tables.dart';

/// 文本/pattern 折叠槽位（见库注释）。新增非 BMP pattern 字面量时须在此登记
/// 专属槽位，[compilePyRegex] 对未登记者直接抛错（fail-fast）。
const Map<int, int> _patternNonBmpFolds = <int, int>{
  0x1F422: 0xE001, // 🐢（V2_MINE_TERMS 行 330）
};
const int _genericFold = 0xE000;
const int _literalShift = 0xE003; // 文本里的字面 PUA E001/E002 让位到 E003

/// 文本折叠：非 BMP 码点 → 单个 PUA 字符；字面 E001/E002 → E003（避免与折叠槽位
/// 撞车——pattern 从不引用 E000/E003，故 E000 与字面 PUA 的合流不影响任何判定）。
/// 折叠保持码点数不变 ⇒ `folded.length == 原文码点数 == Python len(s)`。
String foldText(String s) {
  if (!_needsFold(s)) return s; // 快路径：无代理对且无字面 PUA
  final StringBuffer sb = StringBuffer();
  for (final int r in s.runes) {
    if (r == 0xE001 || r == 0xE002) {
      sb.writeCharCode(_literalShift);
    } else if (r > 0xFFFF) {
      sb.writeCharCode(_patternNonBmpFolds[r] ?? _genericFold);
    } else {
      sb.writeCharCode(r);
    }
  }
  return sb.toString();
}

bool _needsFold(String s) {
  for (var i = 0; i < s.length; i++) {
    final int u = s.codeUnitAt(i);
    if ((u >= 0xD800 && u <= 0xDFFF) || u == 0xE001 || u == 0xE002) return true;
  }
  return false;
}

/// Python re 方言 → ECMAScript RegExp 源码（转换规则见库注释）。
/// 非法/不支持构造直接抛错——宁可编译期炸掉也不静默偏离 Python 语义。
String convertPyRegex(String src) {
  var multiLineCaret = false;
  if (src.startsWith('(?m)')) {
    multiLineCaret = true;
    src = src.substring(4);
  }
  final StringBuffer out = StringBuffer();
  var inClass = false;
  var classJustOpened = false;
  var i = 0;
  while (i < src.length) {
    final String c = src[i];
    if (c == r'\') {
      if (i + 1 >= src.length) throw FormatException('悬挂转义: $src');
      final String two = src.substring(i, i + 2);
      switch (two) {
        case r'\s':
          // 类内裸拼接（再套一层 [] 会提前闭合外层类）；类外包一层成组
          if (inClass) {
            out.write(pyWsClassBody);
          } else {
            out
              ..write('[')
              ..write(pyWsClassBody)
              ..write(']');
          }
        case r'\d':
          if (inClass) {
            out.write(ndClassBody);
          } else {
            out
              ..write('[')
              ..write(ndClassBody)
              ..write(']');
          }
        case r'\w':
        case r'\W':
        case r'\S':
        case r'\b':
        case r'\B':
        case r'\D':
        case r'\A':
        case r'\Z':
          throw UnsupportedError('Python 专有/语义分歧记号 $two 不可移植: $src');
        default:
          out.write(two); // \r \n \t \. \- \[ \] 等两侧同义，原样保留
      }
      i += 2;
      classJustOpened = false;
      continue;
    }
    if (!inClass && c == '[') {
      inClass = true;
      classJustOpened = true;
      out.write('[');
      i++;
      continue;
    }
    if (inClass && c == ']' && !classJustOpened) {
      // Python/ES 都允许 []] 与 [^]] 里首个 ] 作字面量；全表未用到，出现即拒绝。
      inClass = false;
      out.write(']');
      i++;
      continue;
    }
    if (inClass && c == ']' && classJustOpened) {
      throw UnsupportedError('类首 ] 字面量（[]] 形态）未支持: $src');
    }
    classJustOpened = false;
    if (!inClass && c == '.') {
      out.write(r'[^\n]'); // Python . 只排除 \n
      i++;
      continue;
    }
    if (!inClass && c == r'$') {
      if (multiLineCaret) {
        throw UnsupportedError('(?m) 模式里的 \$ 语义未支持: $src');
      }
      out.write(r'(?:$|\n$)'); // Python $ = 结尾 或 结尾\n 之前
      i++;
      continue;
    }
    if (!inClass && c == '^') {
      out.write(multiLineCaret ? r'(?:\n|^)' : '^');
      i++;
      continue;
    }
    if (inClass && c == '^') {
      out.write('^'); // 类首取反 / 类中字面量，两侧同义
      i++;
      continue;
    }
    final int u = src.codeUnitAt(i);
    if (u >= 0xD800 && u <= 0xDBFF && i + 1 < src.length) {
      final int lo = src.codeUnitAt(i + 1);
      final int r = 0x10000 + ((u - 0xD800) << 10) + (lo - 0xDC00);
      final int? slot = _patternNonBmpFolds[r];
      if (slot == null) {
        throw UnsupportedError(
            'pattern 含未登记的非 BMP 字面量 U+${r.toRadixString(16).toUpperCase()}，'
            '请先在 _patternNonBmpFolds 登记专属槽位: $src');
      }
      out.writeCharCode(slot);
      i += 2;
      continue;
    }
    if (u >= 0xE000 && u <= 0xE003) {
      throw StateError('pattern 含保留 PUA 槽位字符: $src');
    }
    out.write(c);
    i++;
  }
  if (inClass) throw FormatException('未闭合字符类: $src');
  return out.toString();
}

/// 预编译的 Python 正则（source 保留 Python 原文——hit_rules 规则串按原文嵌入，
/// 必须逐字符一致；[re] 是方言转换后的 ECMAScript 版本）。
///
/// **入参约定**：所有匹配方法接收的文本必须已经过 [foldText]（引擎侧统一折叠一次）。
class PyRegex {
  PyRegex(this.source);

  /// Python 源串（hit_rules 归因用，禁止改动）。
  final String source;

  late final RegExp re = RegExp(convertPyRegex(source));

  bool hasMatch(String foldedText) => re.hasMatch(foldedText);

  Match? firstMatch(String foldedText) => re.firstMatch(foldedText);

  /// re.findall(...) 的计数（本引擎只用计数，不用捕获内容）。
  int countMatches(String foldedText) => re.allMatches(foldedText).length;

  /// re.sub(source, '', text) 全局替换。
  String removeAll(String foldedText) => foldedText.replaceAll(re, '');
}

/// 具名规则（V2_* 表里的 (name, pattern) 二元组）。
class Rule extends PyRegex {
  Rule(this.name, String source) : super(source);

  /// 规则名（T1b/T1c/T1d 归因段）。
  final String name;
}
