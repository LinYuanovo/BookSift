/// 帖子分类器 v3（原型 §8.9，规则本体移植自 work/collector_poc/collect_poc.py）。
///
/// **契约文件**：本文件的公开 API 由主控冻结，实现由 v3 词典移植任务落地
/// （Dart trie/首字桶 + v2 两级规则 + v3 词典锚点，纯 Dart、无 IO、可在 Isolate.run 内执行）。
/// 语义与 Python 侧 classify_v3 完全一致（parity 夹具验收），要点：
///
/// - v3 = v2 规则冻结复用 + 书名实体词典锚点（词典命中只解除 2a 作品锚点门控，
///   仍须叠加负评·雷语义才判排雷 = G1）；
/// - G2 循环证据：帖内提到的书名自身即雷词/负评词时，这些词作废不作证据；
/// - G4 软证据让位求书；
/// - 空词典（[BookDict.empty]）时 v3 退化为 v2 行为（Python load_book_dict 缺失文件同款语义）；
/// - 判定顺序 R1..R8 命中即止，排雷优先于扫书。
library;

import 'src/book_dict.dart';
import 'src/engine.dart';
import 'src/norm.dart';
import 'src/py_regex.dart' show foldText;
import 'src/rules.dart' show v2MineTitleAny, v2MineTitlePrefix;
import 'src/py_regex.dart' show Rule;

export 'src/engine.dart' show explicitManualKind, kRecommendKind;

/// settings.classifier_version 落库的门禁版本。
///
/// [classifierCoreVersion] 是 Python 冻结核心的 v3 夹具版本；此值在核心之上叠加
/// “明确推书/无雷字段/毒点罗列”等生产校正，必须独立递增，才能让已安装库越过
/// `needsReclassify` 闸门重新回填。
const int classifierVersion = 4;

/// Python classify_v3 冻结核心版本（parity 夹具锁定值，不随生产校正递增）。
const int classifierCoreVersion = 3;

/// post_kind → recommend_flag 映射（§8.9 表：扫书+1 / 排雷-1 / 求书0；日常=null 丢弃）。
const Map<String, int> kindFlag = <String, int>{'扫书': 1, '排雷': -1, '求书': 0};

/// post_kind 枚举值（日常闲聊 kind=null，采集端丢弃不入库）。
abstract final class PostKind {
  static const String scan = '扫书';
  static const String mine = '排雷';
  static const String seek = '求书';
}

/// 分类结果（对齐 Python ClassifyResult dataclass）。
class ClassifyResult {
  const ClassifyResult({
    required this.kind,
    required this.flag,
    required this.hitRules,
    required this.booknames,
    this.dictAnchor = '',
  });

  /// 扫书/排雷/求书；null = 日常闲聊（丢弃）。
  final String? kind;

  /// recommend_flag：1/-1/0（闲聊为 0）。
  final int flag;

  /// 命中规则名（';' 连接后落 posts.hit_rules 语义位，展示用）。
  final List<String> hitRules;

  /// 《》抽取的书名（保序去重）。
  final List<String> booknames;

  /// v3 词典锚点：命中的最长词典书名（归一化形）；未命中为 ''。
  final String dictAnchor;
}

/// 书名实体词典索引（v3 锚点，22,001 归一化书名，assets/dict/book_dict.txt 随包分发）。
///
/// 实现要求（Python load_book_dict/find_dict_booknames 同款语义）：
/// - 构建时做 G2 守卫：名字自身命中雷术语/弱雷术语/雷词/负评词四表的不进锚点索引，
///   另存证据名集合供循环证据识别；
/// - 匹配口径：文本先 [v3NormText] 归一化，逐位置**最长匹配**，返回全部命中（去重、长度降序）；
/// - 数据结构不限（trie 或首字桶+长度降序），复杂度须达 Python 实测水平（420 帖 0.36s）。
///
/// 实现：扁平数组 trie（选型理由见 src/book_dict.dart 库注释）。
class BookDict {
  BookDict._(this._core);

  /// 空词典：v3 退化为 v2 行为（锚点门控只认《》/指代词/作者：/N章）。
  factory BookDict.empty() => BookDict._(BookDictCore.empty());

  /// 从词典行构建（每行一个归一化书名；过短行与 G2 证据名剔除）。
  factory BookDict.fromLines(Iterable<String> lines) =>
      BookDict._(BookDictCore.fromLines(lines));

  final BookDictCore _core;

  /// 全部词典命中（去重、长度降序；[0] 即最长命中）。
  List<String> findBooknames(String text) => _core.findBooknames(text);

  /// 最长词典命中（无命中返回 ''）。
  String findBookname(String text) => _core.findBookname(text);

  /// 可锚定名数量（G2 剔除后）。
  int get anchorCount => _core.anchorCount;

  /// G2 守卫留出的「自身即雷词/负评词」书名数。
  int get evidenceNameCount => _core.evidenceNameCount;

  bool get isEmpty => anchorCount == 0;
}

/// 仅用于 parity 测试直接驱动冻结核心；生产调用仍走 [classifyV3]。
BookDictCore bookDictCoreForTest(BookDict dict) => dict._core;

/// v3 分类主入口（= Python classify_v3）。
///
/// [booknames] 为《》抽取结果（调用方先跑 [extractBooknames]，与 Python 管线一致：
/// prelim 用 title+首楼，终判用全文——由调用方决定传哪份，本函数不重复抽取）。
/// [dict] 为词典索引；传 [BookDict.empty] 即 v2 行为。
ClassifyResult classifyV3({
  required String title,
  required String firstFloor,
  required String fullText,
  required List<String> booknames,
  required BookDict dict,
}) {
  final ClassifyResult base = classifyV3Core(
    title: title,
    firstFloor: firstFloor,
    fullText: fullText,
    booknames: booknames,
    dict: dict._core,
  );
  // 生产口径校正：明确写“雷点/毒点/郁闷：无”的扫书帖，不因字段名被冻结规则升格排雷。
  final String foldedTitle = foldText(title);
  final String foldedFloor = foldText(firstFloor);
  final bool titleNeutralField = _neutralMineField.hasMatch(foldedTitle);
  final bool titleNegative =
      !titleNeutralField &&
      (v2MineTitlePrefix.hasMatch(foldedTitle) ||
          v2MineTitleAny.any((Rule r) => r.hasMatch(foldedTitle)));
  // 标题/首楼只写“雷点/毒点/郁闷：无”时，字段名本身不是排雷证据。
  if (base.kind == PostKind.mine &&
      !titleNegative &&
      (titleNeutralField ||
          (_neutralMineField.hasMatch(foldedFloor) &&
              !_strongNegative.hasMatch(foldedFloor)))) {
    return ClassifyResult(
      kind: PostKind.scan,
      flag: kindFlag[PostKind.scan]!,
      hitRules: const <String>['T2a:明确无雷字段'],
      booknames: base.booknames,
      dictAnchor: base.dictAnchor,
    );
  }
  // 扫书模板可能先于负评规则命中；“毒点很多，劝退/弃书”等明确结论仍是排雷。
  if (base.kind == PostKind.scan &&
      !titleNegative &&
      _explicitNegativeConclusion.hasMatch(foldedFloor)) {
    return ClassifyResult(
      kind: PostKind.mine,
      flag: kindFlag[PostKind.mine]!,
      hitRules: const <String>['T2a:明确负评结论'],
      booknames: base.booknames,
      dictAnchor: base.dictAnchor,
    );
  }
  // `毒点/郁闷` 只是字段名或观察项，单独出现不构成“排雷”结论；
  // 只有伴随劝退/弃书等明确评价时才走上面的升格。
  if (base.kind == PostKind.mine &&
      !titleNegative &&
      !_explicitNegativeConclusion.hasMatch(foldedFloor) &&
      !_strongNegative.hasMatch(foldedFloor) &&
      _bareMineField.hasMatch(foldedFloor)) {
    return ClassifyResult(
      kind: PostKind.scan,
      flag: kindFlag[PostKind.scan]!,
      hitRules: const <String>['T2a:罗列毒点/郁闷不判排雷'],
      booknames: base.booknames,
      dictAnchor: base.dictAnchor,
    );
  }
  // 扫书总览（书名/作者/平台/字数/文笔等字段）中的毒点段落只是观察项；
  // 没有明确劝退结论时不把整帖升格为排雷。
  if (base.kind == PostKind.mine &&
      !titleNegative &&
      _scanOverviewField.hasMatch(foldedFloor)) {
    return ClassifyResult(
      kind: PostKind.scan,
      flag: kindFlag[PostKind.scan]!,
      hitRules: const <String>['T2a:扫书总览字段'],
      booknames: base.booknames,
      dictAnchor: base.dictAnchor,
    );
  }
  if (base.kind == null && booknames.isNotEmpty) {
    return ClassifyResult(
      kind: PostKind.scan,
      flag: kindFlag[PostKind.scan]!,
      hitRules: const <String>['T2b:书目评价兜底'],
      booknames: base.booknames,
      dictAnchor: base.dictAnchor,
    );
  }
  return base;
}

final RegExp _neutralMineField = RegExp(
  r'(?:雷点|毒点|郁闷(?:点)?)[:：]\s*'
  r'(?:无|没有|没|没什么|不多|较少|极少|基本没有|全无)',
);

final RegExp _strongNegative = RegExp(
  r'劝退|慎入|毒点如下|毒点盘点|剧毒|弃书|弃了|看不下去|忍不了|恶心|降智',
);

final RegExp _explicitNegativeConclusion = RegExp(
  r'(?:毒点|郁闷)[^。\n]{0,24}'
  r'(?:真劝退|劝退|弃书|弃了|看不下去|忍不了|没法忍)',
);

final RegExp _bareMineField = RegExp(r'(?:毒点|郁闷(?:点)?)[:：]');

final RegExp _scanOverviewField = RegExp(
  r'书名[:：].*作者[:：]|平台[:：].*字数[:：]|文笔[:：].*(?:毒点|郁闷)',
  dotAll: true,
);

/// 提取《》内书名，保序去重（Python extract_booknames 同款：BOOKNAME_RE=《([^《》\r\n]{1,40})》，
/// 去重键 = 去空白后的名字）。
List<String> extractBooknames(String text) => extractBooknamesImpl(text);

/// 词典匹配用归一化：NFKC → 去空白 → 去标点 → 小写
/// （必须与 _build_book_dict.py 的 norm_name 同口径，否则词典键对不上正文）。
String v3NormText(String s) => v3NormTextImpl(s);
