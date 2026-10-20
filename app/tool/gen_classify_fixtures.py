# -*- coding: utf-8 -*-
"""Dart v3 分类器移植的 Python 侧生成器（只读访问 work/ 与 app/assets）。

两个模式：
    python gen_classify_fixtures.py tables
        重新生成 app/lib/classify/src/unicode_tables.dart（NFKC-lite / lower /
        规范组合对 / 字符集区间表；数据源 = 本机 Python unicodedata，与
        collect_poc.py 运行时同一实现）。
    python gen_classify_fixtures.py fixtures
        生成 app/test/classify/fixtures/ 下四份 parity 夹具：
          patterns.json    collect_poc 全部 v2/v3 规则常量 dump（守卫 Dart 转录零漂移）
          dict_meta.json   load_book_dict 统计（anchor/bucket/evidence）+ find 语义探针
          norm_parity.json ≥2000 条语料/构造串 → v3_norm_text 输出
          parity.json      ≥1500 条真实帖 (title, first_floor, full_text, booknames)
                           → classify(v3) 终判期望 {kind, flag, hit_rules, dict_anchor}
    python gen_classify_fixtures.py            # tables + fixtures

数据源（全程只读）：
    work/collector_poc/collect_poc.py        规则本体（import 复用，绝不复制逻辑）
    work/collector_poc/book_dict.txt         词典（须与 app/assets/dict/book_dict.txt 同 sha256）
    work/collector_poc/collected_full.db     9219 帖全量采集库（post/floor 表）
    work/collector_poc/eval_candidates.db    420 条评测候选（title/first_floor_text/page1_text）

import collect_poc 的副作用处理：模块级 LOG = setup_logging() 会建 collect.log 的
FileHandler——先把 logging.FileHandler 桩成 NullHandler 再 import，不触碰 work/ 任何文件。
"""
from __future__ import annotations

import hashlib
import io
import json
import logging
import os
import re
import sqlite3
import sys
import time
import unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))          # app/tool
APP = os.path.abspath(os.path.join(HERE, os.pardir))       # app/
REPO = os.path.abspath(os.path.join(APP, os.pardir))       # 仓库根
POC = os.path.join(REPO, "work", "collector_poc")
FIXTURE_DIR = os.path.join(APP, "test", "classify", "fixtures")
TABLES_OUT = os.path.join(APP, "lib", "classify", "src", "unicode_tables.dart")
ASSET_DICT = os.path.join(APP, "assets", "dict", "book_dict.txt")
WORK_DICT = os.path.join(POC, "book_dict.txt")

sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def import_collect_poc():
    """带 FileHandler 桩导入 collect_poc（不写 collect.log，不触网，不碰 DB）。"""
    sys.path.insert(0, POC)

    class _NullFH(logging.NullHandler):
        def __init__(self, *a, **k):
            super().__init__()

        def setFormatter(self, *a, **k):
            pass

    orig = logging.FileHandler
    logging.FileHandler = _NullFH
    try:
        import collect_poc as cp  # noqa: PLC0415
    finally:
        logging.FileHandler = orig
    return cp


# ============================================================================
# tables 模式：unicode_tables.dart
# ============================================================================
MAXCP = 0x110000


def _esc_cp(cp: int) -> str:
    """码点 → ECMAScript 正则类内字面量（Dart raw string 承载，故用正则级转义）。"""
    assert cp <= 0xFFFF, "非 BMP 码点不得进正则类（文本折叠后不存在；ES 无 u 标志不支持 \\u{...}）"
    if cp < 0x80:
        ch = chr(cp)
        if ch in "-]^\\":
            return "\\" + ch
        if cp < 0x20 or cp == 0x7F:
            return "\\x%02X" % cp
        return ch
    return "\\u%04X" % cp


def _ranges_of(pred) -> list:
    rs = []
    cp = 0
    while cp < MAXCP:
        if 0xD800 <= cp <= 0xDFFF:
            cp = 0xE000
            continue
        if pred(cp):
            start = cp
            while cp + 1 < MAXCP and not (0xD800 <= cp + 1 <= 0xDFFF) and pred(cp + 1):
                cp += 1
            rs.append((start, cp))
        cp += 1
    return rs


def _class_body(rs: list) -> str:
    parts = []
    for a, b in rs:
        parts.append(_esc_cp(a) if a == b else "%s-%s" % (_esc_cp(a), _esc_cp(b)))
    return "".join(parts)


def _dart_str(v: str) -> str:
    """Python str → Dart 双引号字符串字面量（json 转义 + $ 转义防 Dart 插值）。"""
    return json.dumps(v, ensure_ascii=True).replace("$", "\\$")


def _to_ranges(s: set) -> list:
    rs = []
    for x in sorted(s):
        if rs and x == rs[-1][1] + 1:
            rs[-1][1] = x
        else:
            rs.append([x, x])
    return [tuple(r) for r in rs]


def gen_tables(cp) -> None:
    t0 = time.time()
    log = lambda *a: print("[%5.1fs]" % (time.time() - t0), *a)

    # 1) NFKC 单字符表（全码点）
    nfkc = {}
    for c in range(MAXCP):
        if 0xD800 <= c <= 0xDFFF:
            continue
        n = unicodedata.normalize("NFKC", chr(c))
        if n != chr(c):
            nfkc[c] = n
    log("NFKC diff:", len(nfkc))

    # 等差单字符 run 压缩
    nfkc_ranges, singles = [], {}
    cps = sorted(nfkc)
    i = 0
    while i < len(cps):
        c = cps[i]
        v = nfkc[c]
        if len(v) == 1:
            d = ord(v) - c
            j = i + 1
            while (j < len(cps) and cps[j] == cps[j - 1] + 1 and len(nfkc[cps[j]]) == 1
                   and ord(nfkc[cps[j]]) - cps[j] == d):
                j += 1
            if j - i >= 8:
                nfkc_ranges.append((c, cps[j - 1], d))
                i = j
                continue
        singles[c] = v
        i += 1
    log("NFKC ranges:", len(nfkc_ranges), "singles:", len(singles))

    # 2) 规范组合对（NFC 二次组合；Hangul 音节除外——Dart 侧算法合成）
    compose = {}
    for c in range(MAXCP):
        if 0xD800 <= c <= 0xDFFF or 0xAC00 <= c <= 0xD7A3:
            continue
        d = unicodedata.decomposition(chr(c))
        if not d or d.startswith("<"):
            continue
        parts = d.split()
        if len(parts) != 2:
            continue
        b, m = int(parts[0], 16), int(parts[1], 16)
        if unicodedata.normalize("NFC", chr(b) + chr(m)) == chr(c):
            compose[b * MAXCP + m] = c
    log("compose pairs:", len(compose))

    # 3) lower 全映射差异表（Final_Sigma 上下文另由 Dart 侧实现）
    lower = {}
    for c in range(MAXCP):
        if 0xD800 <= c <= 0xDFFF:
            continue
        l = chr(c).lower()
        if l != chr(c):
            lower[c] = l
    log("lower diff:", len(lower))

    # 4) Cased / Case_Ignorable（Final_Sigma 条件）
    cased_rs = _ranges_of(lambda c: chr(c).islower() or chr(c).isupper() or chr(c).istitle())
    wb_mid = {0x27, 0x2E, 0x3A, 0xB7, 0x387, 0x58A, 0x5F4, 0x2018, 0x2019, 0x2024,
              0x2027, 0xFE52, 0xFE55, 0xFF07, 0xFF0E, 0xFF1A}
    ci_rs = _ranges_of(lambda c: unicodedata.category(chr(c)) in ("Mn", "Me", "Cf", "Lm", "Sk")
                       or c in wb_mid)
    log("cased ranges:", len(cased_rs), "case-ignorable ranges:", len(ci_rs))

    # 5) Python re \s、V3_NORM_WS/PUNCT 成员（用 collect_poc 的正则实测，非手抄）
    ws_rs = _ranges_of(lambda c: chr(c).isspace())
    norm_ws = {c for c in range(0x10000) if cp.V3_NORM_WS_RE.fullmatch(chr(c))}
    norm_punct = {c for c in range(0x10000) if cp.V3_NORM_PUNCT_RE.fullmatch(chr(c))}
    ws_set = set().union(*(set(range(a, b + 1)) for a, b in ws_rs))
    assert norm_ws >= {0xFEFF} and (norm_ws - {0xFEFF}) == ws_set, "norm_ws != \\s + FEFF"
    log("norm_ws:", len(norm_ws), "norm_punct:", len(norm_punct))

    # 6) Nd 类（Python \d 语义；仅 BMP——折叠后文本不含非 BMP 码点）
    nd_rs = [(a, min(b, 0xFFFF)) for a, b in
             _ranges_of(lambda c: unicodedata.category(chr(c)) == "Nd") if a <= 0xFFFF]
    nd_body = _class_body(nd_rs)
    ws_body = _class_body(ws_rs)

    # 7) 规范组合序 CCC 表（非零 combining class 的等值 run 压缩；
    #    Dart 侧组合前对标记 run 做稳定升序重排 + 阻塞规则）
    ccc_rs = []
    for c in range(MAXCP):
        if 0xD800 <= c <= 0xDFFF:
            continue
        v = unicodedata.combining(chr(c))
        if v:
            if ccc_rs and c == ccc_rs[-1][1] + 1 and ccc_rs[-1][2] == v:
                ccc_rs[-1][1] = c
            else:
                ccc_rs.append([c, c, v])
    ccc_rs = [tuple(r) for r in ccc_rs]
    log("ccc runs:", len(ccc_rs))

    pairs = lambda rs: "[" + ", ".join("[%d, %d]" % (a, b) for a, b in rs) + "]"
    triples = lambda rs: "[" + ", ".join("[%d, %d, %d]" % r for r in rs) + "]"

    buf = io.StringIO()
    w = buf.write
    w("// 生成物 —— 勿手改。v3 分类器 NFKC-lite / lower / 组合 / 字符集数据表。\n")
    w("//\n")
    w("// 生成命令（数据源 = 本机 Python %s 的 unicodedata，与 collect_poc.py 运行时同实现）：\n"
      % sys.version.split()[0])
    w("//   & \"C:\\ProgramData\\anaconda3\\python.exe\" app\\tool\\gen_classify_fixtures.py tables\n")
    w("//\n")
    w("// 各表语义（与 Python unicodedata.normalize('NFKC'/'NFC') 与 str.lower() 逐码点对齐）：\n")
    w("// - nfkcRanges：等差单字符兼容折叠 run [start, end, delta]（dst = src + delta）。\n")
    w("// - nfkcSingles：其余单字符/1→多 兼容折叠（值 = NFKC(chr(cp)) 全量结果）。\n")
    w("// - composePairs：规范组合对，键 = base * 0x110000 + mark（Hangul 音节除外，算法合成）。\n")
    w("// - cccRanges：非零 Canonical Combining Class 区间 [start, end, ccc]，\n")
    w("//   组合前对标记 run 做规范重排（稳定升序）+ 阻塞规则（UAX #15）。\n")
    w("// - lowerSingles：Python str.lower() 的全量差异表（含 1→多 展开；U+03A3 的\n")
    w("//   Final_Sigma 上下文规则不在表内，由 py_unicode.dart 依 cased/caseIgnorable 实现）。\n")
    w("// - casedRanges / caseIgnorableRanges：Final_Sigma 条件的 Unicode 属性区间。\n")
    w("// - normWsRanges / normPunctRanges：V3_NORM_WS_RE / V3_NORM_PUNCT_RE 的成员区间\n")
    w("//   （由 collect_poc.py 的两个正则 fullmatch 逐码点实测导出，非手抄）。\n")
    w("// - pyWsClassBody / ndClassBody：Python re 的 \\s / \\d（Unicode 语义）等价类体，\n")
    w("//   拼接进 Dart RegExp 源码（ECMAScript \\s/\\d 语义不同，见 py_regex.dart）。\n")
    w("// ignore_for_file: prefer_single_quotes, lines_longer_than_80_chars\n")
    w("library;\n\n")
    w("/// NFKC 等差折叠 run：dst = src + delta（单字符结果）。\n")
    w("const List<List<int>> nfkcRanges = %s;\n\n" % triples(nfkc_ranges))
    w("/// NFKC 其余折叠（含 1→多 展开）。\n")
    w("const Map<int, String> nfkcSingles = {\n")
    for c in sorted(singles):
        w("  %d: %s,\n" % (c, _dart_str(singles[c])))
    w("};\n\n")
    w("/// 规范组合对：键 = base * 0x110000 + mark → 组合结果。\n")
    w("const Map<int, int> composePairs = {\n")
    for k in sorted(compose):
        b, m = divmod(k, MAXCP)
        w("  0x%X * 0x110000 + 0x%X: 0x%X,\n" % (b, m, compose[k]))
    w("};\n\n")
    w("/// 非零 Canonical Combining Class 区间 [start, end, ccc]（组合前重排标记 run 用）。\n")
    w("const List<List<int>> cccRanges = %s;\n\n" % triples(ccc_rs))
    w("/// Python str.lower() 差异表（值 = 完整小写映射，可能多字符）。\n")
    w("const Map<int, String> lowerSingles = {\n")
    for c in sorted(lower):
        w("  %d: %s,\n" % (c, _dart_str(lower[c])))
    w("};\n\n")
    w("/// Cased 属性区间（Lowercase|Uppercase|Lt）。\n")
    w("const List<List<int>> casedRanges = %s;\n\n" % pairs(cased_rs))
    w("/// Case_Ignorable 属性区间（Mn/Me/Cf/Lm/Sk + MidLetter/MidNumLet/Single_Quote）。\n")
    w("const List<List<int>> caseIgnorableRanges = %s;\n\n" % pairs(ci_rs))
    w("/// V3_NORM_WS_RE 成员区间（= Python re \\s + U+FEFF）。\n")
    w("const List<List<int>> normWsRanges = %s;\n\n" % pairs(_to_ranges(norm_ws)))
    w("/// V3_NORM_PUNCT_RE 成员区间。\n")
    w("const List<List<int>> normPunctRanges = %s;\n\n" % pairs(_to_ranges(norm_punct)))
    w("/// Python re \\s 等价类体（拼进 Dart RegExp 字符类）。\n")
    w("const String pyWsClassBody = r'%s';\n\n" % ws_body)
    w("/// Python re \\d（Unicode Nd）等价类体（仅 BMP：待匹配文本已折叠，非 BMP 数字\n")
    w("/// 在 Dart 侧不可达；数学字母数字区 U+1D7CE+ 一类属文档化的接受边界）。\n")
    w("const String ndClassBody = r'%s';\n" % nd_body)

    os.makedirs(os.path.dirname(TABLES_OUT), exist_ok=True)
    with open(TABLES_OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(buf.getvalue())
    log("→", os.path.relpath(TABLES_OUT, REPO), os.path.getsize(TABLES_OUT), "bytes")


# ============================================================================
# fixtures 模式
# ============================================================================
def dump_patterns(cp) -> dict:
    """collect_poc 全部 v2/v3 规则常量的 verbatim dump（patterns_parity_test 守卫）。"""
    return {
        "classifier_version": cp.CLASSIFIER_VERSION,
        "kind_flag": cp.KIND_FLAG,
        "bookname_re": cp.BOOKNAME_RE.pattern,
        "v2_mine_title_prefix": cp.V2_MINE_TITLE_PREFIX.pattern,
        "v2_seek_title_patterns": [[n, p] for n, p in cp.V2_SEEK_TITLE_PATTERNS],
        "v2_share_title": cp.V2_SHARE_TITLE.pattern,
        "v2_seek_weak_rules": sorted(cp.V2_SEEK_WEAK_RULES),
        "v2_seek_title_block": cp.V2_SEEK_TITLE_BLOCK.pattern,
        "v2_seek_pattern_excludes": {k: v.pattern for k, v in cp.V2_SEEK_PATTERN_EXCLUDES.items()},
        "v2_mine_title_any": [[n, p] for n, p in cp.V2_MINE_TITLE_ANY],
        "v2_mine_title_terms": [[n, p] for n, p in cp.V2_MINE_TITLE_TERMS],
        "v2_title_question": cp.V2_TITLE_QUESTION.pattern,
        "v2_scan_title_patterns": [[n, p] for n, p in cp.V2_SCAN_TITLE_PATTERNS],
        "v2_mine_defensive": list(cp.V2_MINE_DEFENSIVE),
        "v2_mine_structural": list(cp.V2_MINE_STRUCTURAL),
        "v2_mine_terms": list(cp.V2_MINE_TERMS),
        "v2_mine_terms_weak": list(cp.V2_MINE_TERMS_WEAK),
        "v2_mine_words": list(cp.V2_MINE_WORDS),
        "v2_neg_words": list(cp.V2_NEG_WORDS),
        "v2_anchor_re": cp.V2_ANCHOR_RE.pattern,
        "v2_meta_title": cp.V2_META_TITLE.pattern,
        "v2_meta_content": cp.V2_META_CONTENT.pattern,
        "v2_scan_template": list(cp.V2_SCAN_TEMPLATE),
        "v2_scan_fields": list(cp.V2_SCAN_FIELDS),
        "v2_scan_field_min": cp.V2_SCAN_FIELD_MIN,
        "v2_scan_field_strong": cp.V2_SCAN_FIELD_STRONG,
        "v2_line_book_min": cp.V2_LINE_BOOK_MIN,
        "v2_line_book_re": cp.V2_LINE_BOOK_RE.pattern,
        "v2_scan_selfdecl": list(cp.V2_SCAN_SELFDECL),
        "v2_seek_content": list(cp.V2_SEEK_CONTENT),
        "v2_bookname_min": cp.V2_BOOKNAME_MIN,
        "v2_single_share_cue": list(cp.V2_SINGLE_SHARE_CUE),
        "v2_single_share_max_books": cp.V2_SINGLE_SHARE_MAX_BOOKS,
        "v2_single_share_max_title": cp.V2_SINGLE_SHARE_MAX_TITLE,
        "v2_question_min_marks": cp.V2_QUESTION_MIN_MARKS,
        "v2_question_max_chars": cp.V2_QUESTION_MAX_CHARS,
        "v2_question_tokens": cp.V2_QUESTION_TOKENS.pattern,
        # _v2_question 的两条内联 findall（行 1048–1049，字面转录——parity 夹具兜底）
        "question_tail_re": r"[吗呢么][?？。！!~\s]*$",
        "question_mid_re": r"[，。？?！!]\s*(有没有|有无|是不是|能不能|好不好看|怎么样)",
        "title_rstrip_chars": "。.！!~ ",
        "v3_dict_min_len": cp.V3_DICT_MIN_LEN,
        "v3_evidence_re": cp._v3_evidence_re().pattern,
        "v3_norm_ws_chars": sorted(c for c in range(0x10000) if cp.V3_NORM_WS_RE.fullmatch(chr(c))),
        "v3_norm_punct_chars": sorted(c for c in range(0x10000) if cp.V3_NORM_PUNCT_RE.fullmatch(chr(c))),
    }


def dump_dict_meta(cp) -> dict:
    idx = cp.load_book_dict(rebuild=True)
    names = [n for b in idx.values() for n in b]
    with open(ASSET_DICT, encoding="utf-8") as f:
        asset_sha = hashlib.sha256(f.read().encode("utf-8")).hexdigest()
    work_sha = sha256_file(WORK_DICT)
    assert asset_sha == work_sha, "app/assets 与 work 词典不同源！"

    # 词典内部结构探针：短名/包含对/evidence 名/emoji 名（期望值 = Python 实测）
    contain_pair = None
    by_len = sorted(names, key=len)
    name_set = set(names)
    for n in by_len:
        if len(n) < 4:
            continue
        for k in (2, 3):
            if n[:k] in name_set:
                contain_pair = (n, n[:k])
                break
        if contain_pair:
            break
    probes_text = [
        "遮天",
        "《遮天》好看吗",
        "类似逆天邪神一样的传统玄幻",
        "上品寒士。",
        "从前有座寻仙山",
        "斗破苍穹更新了吗",
        "吐槽一下天蚕土豆",
        "男主🌞了好几个女主的角色但因为不是c所以没交代",
        "江山风月🗡",
        "五年捂嘴三年当💩从训练家到孝天帝の速成攻略",
        "这是死女吗",
        "ＩＩＩ穿越之全角测试",
        "①号选手请求出战",
        "看韩轻好几年了，跨物种妻子那作者写的书都有一股🐢味",
    ]
    if contain_pair:
        probes_text.append(contain_pair[0])          # 长名命中 → 内部短名被 longest 剪枝
        probes_text.append("前缀" + contain_pair[1] + "后缀")
    probes = [{"text": t,
               "find_all": cp.find_dict_booknames(t),
               "find": cp.find_dict_bookname(t)} for t in probes_text]

    return {
        "anchor_count": sum(len(b) for b in idx.values()),
        "bucket_count": len(idx),
        "evidence_count": len(cp._V3_EVIDENCE_NAMES),
        "evidence_names_sample": sorted(cp._V3_EVIDENCE_NAMES)[:40],
        "dict_sha256": asset_sha,
        "max_name_len": max(len(n) for n in names),
        "contain_pair": list(contain_pair) if contain_pair else None,
        "probes": probes,
    }


NORM_PROBES = [
    # NFKC 各类兼容形态
    "ＡＢＣａｂｃ１２３　全角", "①②③⑩⑳⑴ⒶⒷⓐ", "㈱㍿㎡№™℡㏿", "ⅫⅻⅰⅠ",
    "ﬁﬂﬀ︴", "½¼⅓⅔", "¹²³⁰₁₂", "\uF900\uF901\uFA0C", "\u2F00\u2F08\u2FDF",
    "\U0002F800\U0002F801\U0002FA1D", "ｶﾞﾊﾟﾋﾟﾌﾟｦﾝｰｶ", "ﾵﾰㅎ", "\u1100\u1161\u11A8",
    "한국어 한글", "🐢🌞💩🗡🍅😋🤮", "\uE000\uE001\uF8FF",
    "\uFEFF\u200B\u00A0\u3000\t\r\n ", "٠١٢۹", "०१২", "\U0001D7D9\U0001D7CE",
    # lower / Final_Sigma
    "İıI i", "ΑΣ ΟΔΟΣ ΣΑ Σσς", "МОСКВА", "ǅǄǆ", "ẞß", "ＭＩＸＥＤ大小写Title",
    # 组合与分解
    "e\u0301 a\u0327\u0301 a\u0301\u0327 \u00E9", "ヴ\u3099\u309A",
    # 全字符集探针（ws/punct 表成员逐一验证剥离）
    "".join(chr(c) for c in sorted(
        {c for c in range(0x10000) if chr(c).isspace()})),
    "，。、；：！？“”‘’（）《》〈〉【】「」『』—…·～-~*_=+/|<>.,;:!?()[]{}\"'`",
    "字with标点，混排test。", "by：作者BY:By", "NTR ntl ntr Ntl",
    # 真实形态
    "求几本类似《斗破苍穹》的小说", "排雷：这本女主送女漏女，剧毒慎入",
    "书名：《遮天》 作者：辰东 进度：已完结", "1.《A》 2.《B》 3.《C》",
]


def gen_fixtures(cp) -> None:
    t0 = time.time()
    log = lambda *a: print("[%5.1fs]" % (time.time() - t0), *a)
    os.makedirs(FIXTURE_DIR, exist_ok=True)

    def dump(name: str, obj) -> int:
        path = os.path.join(FIXTURE_DIR, name)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(obj, f, ensure_ascii=False, separators=(",", ":"))
        size = os.path.getsize(path)
        log("→", name, f"{size:,} B")
        assert size < 8 * 1024 * 1024, f"{name} 超过 8MB 上限"
        return size

    # ---------- patterns.json ----------
    dump("patterns.json", dump_patterns(cp))

    # ---------- dict_meta.json ----------
    dict_meta = dump_dict_meta(cp)
    dump("dict_meta.json", dict_meta)
    log("词典: anchor=%(anchor_count)s bucket=%(bucket_count)s evidence=%(evidence_count)s"
        % dict_meta)

    # ---------- 语料重建 ----------
    def make(title: str, ff: str, full: str, src: str, tid: int | None) -> dict:
        bns = cp.extract_booknames(full)
        res = cp.classify(title, ff, full, bns)
        rec = {
            "src": src, "title": title, "first_floor": ff, "full_text": full,
            "booknames": bns,
            "exp": {"kind": res.kind, "flag": res.flag,
                    "hit_rules": res.hit_rules, "dict_anchor": res.dict_anchor},
        }
        if tid is not None:
            rec["tid"] = tid
        return rec

    # eval_candidates.db：420 条（_eval.py 同款实参：title, first_floor_text, page1_text）
    eval_recs = []
    con = sqlite3.connect(f"file:{os.path.join(POC, 'eval_candidates.db')}?mode=ro", uri=True)
    for tid, title, ff, p1 in con.execute(
            "SELECT tid, title, first_floor_text, page1_text FROM candidate ORDER BY tid"):
        eval_recs.append(make(title or "", ff or "", p1 or "", "eval", int(tid)))
    con.close()
    log("eval 候选:", len(eval_recs))

    # collected_full.db：9219 帖，full_text = title + 全部楼层（seq 升序）重建
    #（与 collect_full.py 行 537–554 的终判实参同构；离线重建自洽——期望值
    #  就是 Python 对同一实参的现算结果，与当初采集时判定是否一致不影响 parity 效力）
    con = sqlite3.connect(f"file:{os.path.join(POC, 'collected_full.db')}?mode=ro", uri=True)
    floors: dict[int, list[tuple[int, str]]] = {}
    for pid, seq, text in con.execute("SELECT post_id, seq, text FROM floor"):
        floors.setdefault(pid, []).append((seq, text or ""))
    posts = list(con.execute(
        "SELECT id, tid, title, post_kind FROM post ORDER BY id"))
    con.close()
    log("full 库: posts=%d floors=%d" % (len(posts), sum(len(v) for v in floors.values())))

    pool = []           # (rec, kind, anchor, circular, rule0)
    FULL_CAP = 8000     # 超长全文样本不进池（控制夹具体积；平均 622 字，命中极少）
    for pid, tid, title, kind in posts:
        fl = sorted(floors.get(pid, []))
        if not fl:
            continue
        title = title or ""
        ff = fl[0][1]
        full = "\n".join([title] + [t for _, t in fl])
        if len(full) > FULL_CAP:
            continue
        rec = make(title, ff, full, "full", int(tid))
        anchor = rec["exp"]["dict_anchor"]
        circular = bool(cp._v3_circular_pats(cp.v3_norm_text(title + "\n" + ff)))
        rule0 = (rec["exp"]["hit_rules"] or [""])[0]
        pool.append((rec, kind, anchor, circular, rule0))
    log("full 分类完成:", len(pool))

    # ---------- 选样 ----------
    # 必选：G2 循环证据命中、词典锚点路径规则（T2a …词典锚点…，含让位/回流）、结构证据
    picked: dict[int, tuple] = {}

    def pick(item, why):
        picked.setdefault(id(item), (item, why))

    circular_items = [it for it in pool if it[3]]
    dict_rule_items = [it for it in pool if "词典锚点" in it[4]]
    anchor_mine_items = [it for it in pool if it[2] and it[1] == "排雷"]
    for it in circular_items[:40]:
        pick(it, "circular")
    for it in dict_rule_items[:40]:
        pick(it, "dict_rule")
    for it in anchor_mine_items[:60]:
        pick(it, "anchor_mine")

    # 规则桶补全：每个 T* 前缀至少 6 条（不足则全收）
    by_rule: dict[str, list] = {}
    for it in pool:
        by_rule.setdefault(it[4].split("~")[0], []).append(it)
    for rule0, items in sorted(by_rule.items()):
        have = sum(1 for i, _ in picked.values() if i[4].split("~")[0] == rule0)
        for it in items[: max(0, 6 - have)]:
            pick(it, "rule_cov")

    # 分层步进抽样到目标量（每 kind ≈520，确定性：按 id 序等距）
    TARGET_PER_KIND = 520
    for kind in ("扫书", "排雷", "求书"):
        sub = [it for it in pool if it[1] == kind]
        if not sub:
            continue
        stride = max(1, len(sub) // TARGET_PER_KIND)
        for it in sub[::stride][:TARGET_PER_KIND]:
            pick(it, "stride")

    records = list(eval_recs)
    records += [item[0] for _, (item, why) in sorted(picked.items(),
                                                      key=lambda kv: kv[1][0][0]["tid"])]
    # kind=null 覆盖：eval 里的闲聊（collected_full.post 只存有价值类）
    kinds = {}
    for r in records:
        kinds[r["exp"]["kind"]] = kinds.get(r["exp"]["kind"], 0) + 1
    n_anchor = sum(1 for r in records if r["exp"]["dict_anchor"])
    n_circular = sum(1 for r in records
                     if cp._v3_circular_pats(cp.v3_norm_text(
                         r["title"] + "\n" + r["first_floor"])))
    cov = {"total": len(records), "kinds": kinds,
           "dict_anchor_nonempty": n_anchor, "g2_circular_nonempty": n_circular,
           "why": {}}
    for _, why in picked.values():
        cov["why"][why] = cov["why"].get(why, 0) + 1
    log("覆盖:", json.dumps(cov, ensure_ascii=False))

    assert len(records) >= 1500, "夹具总量不足 1500"
    assert all(k in kinds for k in ("扫书", "排雷", "求书", None)), f"四类不齐: {kinds}"
    assert n_anchor >= 100, f"dict_anchor 非空不足 100: {n_anchor}"
    assert n_circular >= 20, f"G2 循环证据命中不足 20: {n_circular}"

    dump("parity.json", {
        "generated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "python": sys.version.split()[0],
        "dict_sha256": dict_meta["dict_sha256"],
        "coverage": cov,
        "records": records,
    })

    # ---------- norm_parity.json ----------
    seen = set()
    uniq = []

    def add_norm(s: str):
        if s and s not in seen:
            seen.add(s)
            uniq.append(s)

    for s in NORM_PROBES:
        add_norm(s)
    for r in eval_recs:
        add_norm(r["title"])
        add_norm(r["first_floor"][:400])
    for it in pool:
        if len(uniq) >= 2200:
            break
        add_norm(it[0]["title"][:400])
        add_norm(it[0]["first_floor"][:400])
    pairs = [[s, cp.v3_norm_text(s)] for s in uniq]
    assert len(pairs) >= 2000, f"norm 语料不足 2000: {len(pairs)}"
    dump("norm_parity.json", {"count": len(pairs), "pairs": pairs})
    log("完成")


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    cp = import_collect_poc()
    if mode in ("tables", "all"):
        gen_tables(cp)
    if mode in ("fixtures", "all"):
        gen_fixtures(cp)


if __name__ == "__main__":
    main()
