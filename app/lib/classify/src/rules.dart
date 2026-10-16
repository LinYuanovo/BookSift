/// v2/v3 规则常量（逐字符转录自 work/collector_poc/collect_poc.py 行 91–542，
/// 每条标注 Python 行号；语义注释以 Python 源文件为准，此处只留移植所需的要点）。
///
/// **source 字符串会被原样嵌进 hit_rules 规则名**（如 `T2a:首楼负评词(锚点)~别[看读追]`），
/// 与 Python f-string 输出逐字符对齐——`test/classify/patterns_parity_test.dart`
/// 用 Python 侧 dump 的 patterns.json 守卫全部常量，禁止手改漂移。
///
/// 相邻字符串字面量拼接与 Python 隐式拼接同义（多行 pattern 的断点位置不影响结果，
/// 但为便于对照 Python 源码，断点保持原样）。
library;

import 'py_regex.dart';

// ============ 书名抽取（collect_poc.py 行 91） ============
// BOOKNAME_RE = 《([^《》\r\n]{1,40})》——Dart 侧用 rune 扫描器等价实现
// （见 engine.dart extractBooknames；{1,40} 的码点计数语义由扫描器直接保证）。
// source 仅供 patterns.json 对拍。
const String booknameReSource = r'《([^《》\r\n]{1,40})》';

// ============ v2 第一级：标题意图 ============

/// 1A 标题起首排雷（行 121–123）。group(1) = 命中的雷词（T1a 归因段）。
final PyRegex v2MineTitlePrefix = PyRegex(
    r'^[\s【\[（(「『|·、,，。!！?？~～\-—=＝]{0,4}'
    r'(排雷|避雷|踩雷|扫雷|毒点盘点|慎入|劝退|雷书)');

/// 1B 标题求书意图（行 128–201，39 条，顺序即判定顺序）。
final List<Rule> v2SeekTitlePatterns = <Rule>[
  Rule('求书', r'求书'),
  Rule('求文', r'求文'),
  Rule('求推荐', r'求推荐'),
  Rule('书荒', r'书荒'),
  Rule('跪求', r'跪求'),
  Rule('找书', r'找书'),
  Rule('求推', r'求推'),
  Rule('求扫', r'求扫'),
  Rule('求排雷', r'求排雷'),
  Rule('找一本', r'找一?[个本册部][^，。]{0,12}(小说|书|文|漫剧|作品)'),
  Rule('找X书', r'找[^，。]{0,8}(小说|书|文)'),
  Rule('有没有', r'有没有'),
  Rule('有无', r'有无'),
  Rule('有木有', r'有木有'),
  Rule('谁有', r'谁有'),
  Rule('哪有', r'哪[里儿]?有'),
  Rule('蹲', r'蹲一?[个本只]?'),
  Rule('求量词本', r'求[几一两三数\d]?[本个部册篇]'),
  Rule('想看', r'想看[^，。]{0,18}(小说|书|文|漫剧|作品|的)'),
  Rule('类似', r'类似[^，。]{0,12}(小说|文|书|的|吗|设定)'),
  Rule('有X推荐', r'有[^，。]{0,12}(推荐|推[点几])[吗么呗吧？?]'),
  Rule('有X文吗', r'有[^，。]{1,16}(文|书|小说|漫剧|作品|同人|粮)[吗么？?]'),
  Rule('求X书', r'求[^生]{0,16}(小说|漫剧|作品|书|文|粮|好文)'),
  Rule('求书名资源', r'求[^生]{0,25}(书名|资源|txt|TXT|zy|完整版|未删减)'),
  Rule('来点', r'来[点些个儿][^，。]{0,14}(文|书|小说|漫剧|作品|粮|推荐|的)'),
  Rule('给我推', r'(给我|帮我|替我)[^，。]{0,6}推'),
  Rule('能不能推', r'能不能[^，。]{0,10}(推荐|推[个点位本])'),
  Rule('推点X吧', r'推[点几些][^，。]{0,10}[吧呗啊呀嘛看]'),
  Rule('大佬推荐',
      r'(大佬|吧友|各位|老哥|老哥们|兄弟们|兄弟|大伙|来人|8u|吧u|xdm|XDM|书友)[^，。]{0,8}(推荐|推[点几]|推推|救救|给[几点推]|发挥|爆点)'),
  Rule('求评估',
      r'(有人|没有人|没人|有没有人|有木有|谁|哪位|大伙|吧友|大佬)[^，。]{0,10}(看过|看看|读过|扫过|排过|扫[吗么])'),
  Rule('求评估2',
      r'(能看|好看|怎么样|咋样|如何|值[得不]|有毒|有雷|是绿文)[吗么？?]'
      r'|(这本书|这书|此书|该书|本作|《[^》]{1,40}》)[^。]{0,6}(怎么样|咋样|如何|好不好看)'),
  Rule('还有X吗', r'还有[^，。]{0,16}(小说|书|文|作品|同人|历史|后宫|粮)[吗么？?]'),
  Rule('询问贴', r'(询问|问个|问下|问一下)[贴帖书]'),
  Rule('神农', r'神农'),
  Rule('求求', r'求求'),
  Rule('写过啥', r'写过[^，。]{0,6}(啥|什么|哪些)'),
  Rule('求资源', r'(资源|zy|txt|TXT)[^，。]{0,8}(求|发|给|分享|有没有|哪|吗)'),
  Rule('找不到资源',
      r'(找不到|搜不到)[^，。]{0,10}(资源|zy|txt|TXT|完整版|版本|书名|哪|平台)'
      r'|(找不到|搜不到)[^，。]{0,4}[吗么？?]$'
      r'|哪里有|哪有|在哪[里儿个]?看|哪个平台看|什么平台看'),
  Rule('请教吧友', r'请教[^，。]{0,8}(吧友|大佬|各位|老哥|大伙)'),
];

/// 1B 弱式门控：自述分享标题（行 206–207）。
final PyRegex v2ShareTitle = PyRegex(
    r'(在追|追的|看过的|读过的|看完的|我在看|本人|楼主|自己看|我的书|扫过的|分享)');

/// 受 [v2ShareTitle] 门控的 1B 弱式规则名（行 210）。
const Set<String> v2SeekWeakRules = <String>{
  '推点X吧', '大佬推荐', '有X推荐', '能不能推', '求求',
};

/// 1B/1D 门控：信息型/技术型疑问标题（行 216–220）。
final PyRegex v2SeekTitleBlock = PyRegex(
    r'(有没有|有无|有木有|谁|哪位)?人?(知道|懂|清楚|明白|了解|告诉|教我|能教)'
    r'[^。]{0,20}(怎么|为什么|为啥|如何|啥时候|什么时候|过审|审核|签约|上架|删评|被封|版规|区别|定义)'
    r'|(为什么|为啥|如何|怎么|咋)[^。]{0,14}(太监|虐主|烂尾|过审|审核|签约|上架|发书|投稿|下载|安装)'
    r'|(书源|图源|txt下载|下载器)');

/// 1B 个别模式的例外排除（行 223–225）。
final Map<String, PyRegex> v2SeekPatternExcludes = <String, PyRegex>{
  '求书': PyRegex(r'求书友[^，。]{0,2}(帮顶|顶帖|助力)'),
};

/// 1C 标题任意位置排雷词（行 233–241，顺序即判定顺序，首中即返回）。
final List<Rule> v2MineTitleAny = <Rule>[
  Rule('排雷', r'排雷'),
  Rule('避雷', r'避雷'),
  Rule('踩雷', r'踩雷'),
  Rule('扫雷', r'扫雷'),
  Rule('雷点', r'雷点'),
  Rule('毒点', r'毒点'),
  Rule('慎入', r'慎入'),
  Rule('劝退', r'劝退'),
  Rule('坑品', r'坑品'),
  Rule('雷书', r'雷书'),
  Rule('大雷', r'大雷'),
  Rule('爆雷', r'爆雷'),
  Rule('巨雷', r'巨雷'),
  Rule('天雷', r'天雷'),
  Rule('剧毒', r'剧毒'),
  Rule('全是毒', r'全是毒'),
  Rule('太毒', r'太毒'),
  Rule('千万别', r'千万别'),
  Rule('别[看读追]', r'别[看读追]'),
  Rule('注意些', r'(书友|读者|不喜欢的?)[^。]{0,6}注意[些点]|不喜勿入'),
];

/// 1C 社区雷术语（标题级，受疑问标题门控；行 245–248）。
final List<Rule> v2MineTitleTerms = <Rule>[
  Rule('漏女', r'漏女'),
  Rule('送女', r'送女'),
  Rule('死女', r'死女'),
  Rule('卖腐', r'卖腐'),
  Rule('查无此人', r'查无此人'),
  Rule('接盘侠', r'接盘侠'),
  Rule('龟龟', r'龟龟'),
];

/// 疑问型标题（行 249；$ 的「结尾\n 之前」语义由方言转换器处理）。
final PyRegex v2TitleQuestion = PyRegex(
    r'([吗么？?][\s。！!？?]*$|(算|是|叫)[^，。]{0,10}[吗么？?])');

/// 标题推书意图（展示三分用，不进 v2 判定顺序——判定仍把推书并进扫书，见 v2ScanTitlePatterns）。
/// 与 1D 的推书规则同词表，单独成表只为书卡计数能把「推书帖里的条目」和「扫书帖」分开。
final List<Rule> recommendTitlePatterns = <Rule>[
  Rule('推书', r'推书'),
  Rule('推文', r'推文'),
  Rule('推扫', r'推[＋+]?扫'),
  Rule('推荐', r'推荐'),
  Rule('推N本', r'推[^，。]{0,3}[本点些]'),
  Rule('安利', r'安利'),
  Rule('种草', r'种草'),
];

/// 1D 标题扫书意图（行 253–282；收集全部命中后一次性返回）。
final List<Rule> v2ScanTitlePatterns = <Rule>[
  Rule('扫书', r'扫书'),
  Rule('扫过', r'扫过'),
  Rule('详扫略扫', r'[详略简自]扫'),
  Rule('扫一下', r'扫一?下'),
  Rule('扫漫扫榜', r'扫[漫榜个]'),
  Rule('月扫周扫', r'[月周]扫'),
  Rule('推书', r'推书'),
  Rule('推文', r'推文'),
  Rule('推扫', r'推[＋+]?扫'),
  Rule('推荐', r'推荐'),
  Rule('推N本', r'推[^，。]{0,3}[本点些]'),
  Rule('书单', r'书单'),
  Rule('安利', r'安利'),
  Rule('种草', r'种草'),
  Rule('盘点', r'盘点'),
  Rule('汇总', r'汇总'),
  Rule('合集', r'合集'),
  Rule('整理', r'整理'),
  Rule('统计', r'统计'),
  Rule('分享书', r'分享[^，。]{0,8}(书|小说|文|书单|书架|粮)'),
  Rule('书分享', r'(书|小说|书单|书架|好文|粮)[^，。]{0,4}分享'),
  Rule('好书', r'好书'),
  Rule('粮单', r'粮单'),
  Rule('必吃榜', r'必吃榜'),
  Rule('仙草', r'仙草'),
  Rule('书评', r'书评'),
  Rule('简评', r'简评'),
  Rule('吐槽集', r'(吐槽|作品|读书)集'),
  Rule('在追的书', r'(在追|追的|看过的|读过的|看完的)[^，。]{0,4}(书|小说|文|作品)'),
  Rule('可以去看看', r'(可以|值得|建议)(去)?(看看|瞅瞅|看一下|一试|读读)'),
  Rule('感觉可以', r'感觉(可以|不错|挺好|还行)'),
  Rule('补档', r'补档'),
];

// ============ v2 第二级：正文特征兜底 ============

/// 2a 防御性/偏好性表述（极性过滤黑名单；行 300–318，全部剔除完再匹配雷词）。
final List<PyRegex> v2MineDefensive = <PyRegex>[
  PyRegex(r'无雷'),
  PyRegex(r'没雷'),
  PyRegex(r'不雷'),
  PyRegex(r'无大雷'),
  PyRegex(r'没大雷'),
  PyRegex(r'不含雷'),
  PyRegex(r'没有雷'),
  PyRegex(r'不会踩雷'),
  PyRegex(r'不踩雷'),
  PyRegex(r'不会雷'),
  PyRegex(r'雷少'),
  PyRegex(r'少雷'),
  PyRegex(r'雷不多'),
  PyRegex(r'不要雷'),
  PyRegex(r'没什么雷'),
  PyRegex(r'无毒点?'),
  PyRegex(r'没毒点?'),
  PyRegex(r'毒点少'),
  PyRegex(r'少毒点?'),
  PyRegex(r'没多少毒'),
  PyRegex(r'无明显毒点'),
  PyRegex(r'低毒'),
  PyRegex(r'无坑'),
  PyRegex(r'不坑'),
  PyRegex(r'没坑'),
  PyRegex(r'不太监'),
  PyRegex(r'无太监'),
  PyRegex(r'已排雷'),
  PyRegex(r'已避雷'),
  PyRegex(r'排雷完毕'),
  PyRegex(r'避雷成功'),
  PyRegex(r'避雷意识'),
  PyRegex(r'避雷良好'),
  PyRegex(r'避雷很强'),
  PyRegex(r'避雷到位'),
  PyRegex(r'避雷[^。]{0,3}(不错|很好|挺好)'),
  PyRegex(r'放心(食用|入|看|读|追)'),
  PyRegex(r'雷点.{0,4}(会|都|均|已|可能).{0,4}(标|因人而异)'),
  PyRegex(r'(除了|不接受|不能接受|接受不了|不要|不吃|严禁|拒绝|无|没)[^。]{0,10}'
      r'(死女|送女|漏女|绿帽|ntr|NTR|ntl|NTL|太监|虐主|白给)'),
  PyRegex(r'(没有|没什么|不太|不是很|不|无|没)[^。，]{0,2}'
      r'(降智|缺智|恶心|膈应|逆天|难绷|绷不住|烂|毒|雷|弱智)'),
  PyRegex(r'不是[^。，]{0,4}(龟龟|龟男|绿帽|绿|ntr|NTR|ntl|NTL|太监|漏女|送女|死女|虐主)'),
];

/// 2a 结构性排雷证据（最强，不受 meta 抑制；行 321–325）。
final List<PyRegex> v2MineStructural = <PyRegex>[
  PyRegex(r'排雷结果'),
  PyRegex(r'雷点如下'),
  PyRegex(r'踩雷名单'),
  PyRegex(r'避雷名单'),
  PyRegex(r'毒点如下'),
  PyRegex(r'毒点盘点'),
  PyRegex(r'以下[^。]{0,6}(雷点|毒点|踩雷|避雷)'),
  PyRegex(r'(排雷|避雷|雷点|毒点|踩雷)[:：]'),
  PyRegex(r'(排雷|避雷|踩雷|扫雷|劝退)《'),
];

/// 2a 社区雷术语（需锚点；行 328–332）。🐢 是全表唯一非 BMP 字面量（折叠槽位 E001）。
final List<PyRegex> v2MineTerms = <PyRegex>[
  PyRegex(r'漏女'),
  PyRegex(r'送女'),
  PyRegex(r'死女'),
  PyRegex(r'绿帽'),
  PyRegex(r'[Nn][Tt][Rr]'),
  PyRegex(r'[Nn][Tt][Ll]'),
  PyRegex(r'龟龟'),
  PyRegex(r'龟男'),
  PyRegex(r'🐢味?'),
  PyRegex(r'卖腐'),
  PyRegex(r'接盘'),
  PyRegex(r'自绿'),
  PyRegex(r'查无此人'),
  PyRegex(r'神隐'),
  PyRegex(r'前科'),
  PyRegex(r'虐主'),
  PyRegex(r'猥亵'),
  PyRegex(r'雷书'),
  PyRegex(r'大雷'),
  PyRegex(r'爆雷'),
  PyRegex(r'巨雷'),
  PyRegex(r'天雷'),
  PyRegex(r'分身雷'),
];

/// 2a 弱雷术语（完成态语境；行 337）。
final List<PyRegex> v2MineTermsWeak = <PyRegex>[
  PyRegex(r'太监了'),
  PyRegex(r'是太监'),
  PyRegex(r'烂尾了'),
  PyRegex(r'已烂尾'),
  PyRegex(r'结局烂尾'),
  PyRegex(r'直接烂尾'),
];

/// 2a 普通雷词（需锚点 + 非 meta + 极性过滤后；行 340–343）。
final List<PyRegex> v2MineWords = <PyRegex>[
  PyRegex(r'排雷'),
  PyRegex(r'避雷'),
  PyRegex(r'踩雷'),
  PyRegex(r'扫雷'),
  PyRegex(r'雷点'),
  PyRegex(r'毒点'),
  PyRegex(r'慎入'),
  PyRegex(r'劝退'),
  PyRegex(r'很雷'),
  PyRegex(r'太雷'),
  PyRegex(r'有点雷'),
  PyRegex(r'全是毒'),
  PyRegex(r'剧毒'),
  PyRegex(r'坑品'),
];

/// 2a 负评词（需锚点 + 非 meta；行 351–358）。
final List<PyRegex> v2NegWords = <PyRegex>[
  PyRegex(r'恶心'),
  PyRegex(r'难绷'),
  PyRegex(r'难蚌'),
  PyRegex(r'绷不住'),
  PyRegex(r'膈应'),
  PyRegex(r'无语'),
  PyRegex(r'忍不了'),
  PyRegex(r'没法忍'),
  PyRegex(r'看不下去'),
  PyRegex(r'弃书'),
  PyRegex(r'弃了'),
  PyRegex(r'千万别'),
  PyRegex(r'别[看读追]'),
  PyRegex(r'拉完了'),
  PyRegex(r'拉了[一泡]'),
  PyRegex(r'一泻千里'),
  PyRegex(r'[太真好]毒'),
  PyRegex(r'降智'),
  PyRegex(r'缺智'),
  PyRegex(r'不合理'),
  PyRegex(r'问题一大把'),
  PyRegex(r'逆天'),
  PyRegex(r'抽象至极'),
  PyRegex(r'很烂'),
  PyRegex(r'太烂'),
  PyRegex(r'烂活'),
  PyRegex(r'败笔'),
  PyRegex(r'没活了'),
  PyRegex(r'差评'),
  PyRegex(r'[一两二]颗星'),
  PyRegex(r'打一星'),
  PyRegex(r'虎头蛇尾'),
  PyRegex(r'ex到'),
  PyRegex(r'气死'),
  PyRegex(r'弱智'),
  PyRegex(r'腹泻式填坑'),
  PyRegex(r'狂喷'),
  PyRegex(r'劝退'),
];

/// 2a 作品锚点（行 364–371）。
final PyRegex v2AnchorRe = PyRegex(
    r'《[^》]{1,40}》'
    r'|(这[一两]?本|这书|该书|本书|此书|这部|本作|这本小说|这本书|这个漫剧|这本漫剧|这部漫剧|这作者|该作者)'
    r'|(观感|读后感|书评|详扫|略扫)'
    r'|(作者|by|BY|By)[:：]'
    r'|进度[是:：]'
    r'|[0-9]{1,5}[多几]?章'
    r'|[一二三四五六七八九十两]{1,4}[多几]?章');

/// 2a/2f 元讨论抑制（标题级；行 377–382）。
final PyRegex v2MetaTitle = PyRegex(
    r'(规定|版规|吧务|被屏蔽|被删|删帖|被封|封号|隐藏|记得先|什么水平|如何评价|怎么看'
    r'|什么时候|啥时候|平替|app|APP|软件|书源|图源|下载器|短剧|经验|方法论|投票|举报|签到'
    r'|自己写|我在写|正在写|我写的|写个小说|创作|可不可行|接受度|怎么定义|是啥情况|什么意思'
    r'|求图|助力|顶帖|算[^。]{0,4}避雷|避雷好吗|解释一下|科普'
    r'|(为什么|为啥|怎么|如何)(会有|没人|这么|没什么|不去|区分|定义|评价))');

/// 2a 元讨论抑制（正文级；行 389–398）。
final PyRegex v2MetaContent = PyRegex(
    r'(排雷帖|排雷贴|避雷帖|避雷贴|推书帖|推书贴|避雷评论|这些避雷|这种避雷|感谢[^。]{0,6}(排雷|避雷)'
    r'|雷点都写|将雷点|把雷点|雷点爽点|算避雷|避雷好吗|无意义避雷'
    r'|自己写|我在写|正在写|写梗概|创作中|激情创作|求吧友指点|我写的书|拙作|自己的书'
    r'|写的大纲|开始写|写起来|自推贴|楼主写的|我写的文'
    r'|各位作者|作者不会以为|求各位作者|那种[^。]{0,8}操作'
    r'|对我来说算毒点|算毒点|个人毒点'
    r'|(账号|号|帖子?|我|楼主)被封|被封号|封号|版规|吧务|被屏蔽|被系统毙|举报'
    r'|接受度|怎么定义|是如何定义|受众程度|圈地|团建'
    r'|解释一下[^。]{0,12}(雷点|雷|那些|这些|为什么|为啥|什么)|科普|雷区预警|不喜勿入，因为)');

/// 2b 扫书模板（行 408–412）。
final List<PyRegex> v2ScanTemplate = <PyRegex>[
  PyRegex(r'书名[:：]\s*《'),
  PyRegex(r'《[^》]{1,40}》\s*[(（]?\s*(作者|by|BY|By)'),
  PyRegex(r'(作者|by|BY)[:：][^\r\n]{1,20}'),
];

/// 2b 结构化书评字段（行 419–426；命中计数用）。
final List<PyRegex> v2ScanFields = <PyRegex>[
  PyRegex(r'坐标[:：]'),
  PyRegex(r'平台[:：]'),
  PyRegex(r'作者[:：]'),
  PyRegex(r'进度[:：]'),
  PyRegex(r'阅读进度[:：]'),
  PyRegex(r'主线[:：]'),
  PyRegex(r'女主[:：]'),
  PyRegex(r'女主情况[:：]'),
  PyRegex(r'女配[:：]'),
  PyRegex(r'男主[:：]'),
  PyRegex(r'字数[:：]'),
  PyRegex(r'状态[:：]'),
  PyRegex(r'总评[:：]'),
  PyRegex(r'简评[:：]'),
  PyRegex(r'情节[:：]'),
  PyRegex(r'文笔[:：]'),
  PyRegex(r'感情[:：]'),
  PyRegex(r'人物刻画[:：]'),
  PyRegex(r'爽度[:：]'),
  PyRegex(r'新意[:：]'),
  PyRegex(r'压抑度[:：]'),
  PyRegex(r'车速[:：]'),
  PyRegex(r'评分[:：]'),
  PyRegex(r'推荐指数[:：]'),
  PyRegex(r'看点[:：]'),
  PyRegex(r'槽点[:：]'),
  PyRegex(r'简介[:：]'),
  PyRegex(r'别名[:：]'),
  PyRegex(r'书名[:：]'),
  PyRegex(r'进度[是]'),
];

const int v2ScanFieldMin = 2; // 行 427
const int v2ScanFieldStrong = 3; // 行 428
const int v2LineBookMin = 2; // 行 430

/// 2b弱 行首书名行（行 431；唯一 (?m) 模式，^ 由转换器改写为消耗式 (?:\n|^)，
/// 只用于 findall 计数——与 Python 计数一一对应，见 py_regex.dart 库注释第 5 条）。
final PyRegex v2LineBookRe =
    PyRegex(r'(?m)^\s*[0-9]{0,3}\s*[\.、)）:：]?\s*《[^》]{1,40}》');

/// 2b 楼主自述推荐帖（行 434–438）。
final List<PyRegex> v2ScanSelfdecl = <PyRegex>[
  PyRegex(r'本帖[^。]{0,12}(推荐|扫书|书单|汇总|专门|整理)'),
  PyRegex(r'(楼下|下面|后续|慢慢|稍后|二楼)[^。]{0,8}(推荐|补|更新|扫|放|列)'),
  PyRegex(r'开[个一]?[帖贴][^。]{0,8}(推荐|扫书|分享|整理)'),
];

/// 2c 首楼求书内容兜底（行 441–471，26 条）。
final List<PyRegex> v2SeekContent = <PyRegex>[
  PyRegex(r'求推荐'),
  PyRegex(r'求书'),
  PyRegex(r'求文'),
  PyRegex(r'求推'),
  PyRegex(r'跪求'),
  PyRegex(r'书荒'),
  PyRegex(r'求扫'),
  PyRegex(r'求排雷'),
  PyRegex(r'神农'),
  PyRegex(r'(有没有|有无|有木有)[^。]{0,40}(小说|书|文|漫剧|作品|推荐|粮)'),
  PyRegex(r'想找[^。]{0,10}(小说|书|文)'),
  PyRegex(r'想看[^。]{0,12}(小说|书|文|的)'),
  PyRegex(r'(大佬|吧友|各位|老哥|兄弟们|大伙|8u|吧u)[^。]{0,8}(推荐|推[点几]|救救|爆点)'),
  PyRegex(r'推荐[^。]{0,4}(几本|一些|点书|本书)'),
  PyRegex(r'谁有[^。]{0,10}(小说|书|文|资源)'),
  PyRegex(r'来[点些个][^。]{0,12}(好书|书|小说|文|粮|推荐)'),
  PyRegex(r'(求|推|爆)[点几些][^。]{0,8}(书|好书|小说|文|粮)'),
  PyRegex(r'(有人|没有人|没人|谁|哪位)[^。]{0,10}(看过|看看|读过|扫过|排过|扫)[^。]{0,40}(吗|么|没|怎样|咋样|如何|可以说|不)'),
  PyRegex(r'(吧友|大佬|有人|哪位|大伙|8u|兄弟们)[^。]{0,8}(介绍|推荐|说[几两]本|推[点几])'),
  PyRegex(r'(找不到|搜不到)[^。]{0,10}(资源|zy|txt|TXT|完整版|版本|书名|哪|平台)'
      r'|(找不到|搜不到)[。？?！!，]*$'),
  PyRegex(r'哪里有|哪有|在哪[里儿个]?看|哪个平台看|什么平台看|在哪个平台'),
  PyRegex(r'(完整|未删减|无删减|删减|整理)[^。]{0,6}(资源|版本)'),
  PyRegex(r'(资源|zy|txt|TXT)[^。]{0,8}(发|求|给|分享|有没有|哪)'),
  PyRegex(r'写过[^。]{0,6}(啥|什么|哪些)'),
  PyRegex(r'(询问|问个|问下|问一下)[^。]{0,4}(书|这本|贴|帖)'),
  PyRegex(r'(类似|相似)[^。]{0,12}(小说|书|文|设定|的)[^。]{0,8}(推荐|吗|有)'),
];

const int v2BooknameMin = 3; // 行 479（2d 书名数阈值）

/// 2e 单本正向分享线索（行 485–492）。
final List<PyRegex> v2SingleShareCue = <PyRegex>[
  PyRegex(r'个人(觉得|感觉|认为)[^。]{0,10}(好看|不错|推荐|可以)'),
  PyRegex(r'值得一看'),
  PyRegex(r'值得看'),
  PyRegex(r'强烈推荐'),
  PyRegex(r'强推'),
  PyRegex(r'力推'),
  PyRegex(r'很推荐'),
  PyRegex(r'超推荐'),
  PyRegex(r'真推荐'),
  PyRegex(r'安利'),
  PyRegex(r'神作'),
  PyRegex(r'精品'),
  PyRegex(r'找不到代餐'),
  PyRegex(r'都该(来|看|试)'),
  PyRegex(r'推荐任何'),
  PyRegex(r'[试看]一下这本书'),
  PyRegex(r'推荐[^。]{0,10}这本书'),
  PyRegex(r'可以去看看'),
  PyRegex(r'感觉可以'),
  PyRegex(r'挺好看'),
  PyRegex(r'很好看'),
  PyRegex(r'非常不错'),
  PyRegex(r'写的?很不错'),
  PyRegex(r'文笔(挺|很|不错|可以)'),
  PyRegex(r'还可以'),
  PyRegex(r'写的?都?还可以'),
  PyRegex(r'值得追'),
];

const int v2SingleShareMaxBooks = 2; // 行 497
const int v2SingleShareMaxTitle = 24; // 行 498（Python len=码点数；Dart 用折叠串长度）

const int v2QuestionMinMarks = 2; // 行 506
const int v2QuestionMaxChars = 150; // 行 507

/// 2f 疑问句请求词素门控（行 508–509）。
final PyRegex v2QuestionTokens = PyRegex(
    r'(有没有|有无|有木有|求|推荐|类似|相似|想看|想找|书荒|来点|来些)');

/// _v2_question 的两条 findall 计数模式（行 1048–1049）。
final PyRegex v2QuestionTailRe = PyRegex(r'[吗呢么][?？。！!~\s]*$');
final PyRegex v2QuestionMidRe =
    PyRegex(r'[，。？?！!]\s*(有没有|有无|是不是|能不能|好不好看|怎么样)');

/// title.rstrip("。.！!~ ") 的字符集（行 1208）。
const Set<int> titleRstripChars = <int>{
  0x3002, // 。
  0x2E, // .
  0xFF01, // ！
  0x21, // !
  0x7E, // ~
  0x20, // 空格
};

// ============ v3 词典锚点 ============

const int v3DictMinLen = 2; // 行 537（归一化名参与匹配的最短码点数）

/// G2 守卫：雷术语+弱雷术语+雷词+负评词四表合并正则（行 1065–1071，
/// 只在词典加载与循环证据识别时跑）。
final PyRegex v3EvidenceRe = PyRegex(<String>[
  for (final List<PyRegex> group in <List<PyRegex>>[
    v2MineTerms, v2MineTermsWeak, v2MineWords, v2NegWords,
  ])
    for (final PyRegex p in group) '(?:${p.source})',
].join('|'));
