import 'package:saoshuhui/core/constants.dart';
import 'package:saoshuhui/data/db/app_database.dart';
import 'package:saoshuhui/data/repo/queries.dart';

import 'fake_book_repository.dart';

// widget 测试演示语料（纯内存构造，零 IO）。
//
// 数据形状刻意覆盖 M1-④ 的验收点：
//   · 排雷帖（post_kind=排雷 / recommend_flag=-1 / 楼层含《书名》）→ 语义徽标 + 风险提示横幅
//   · 首楼含《篡水浒》→ 书名点击跳搜索预填（§5.6 闭环）
//   · 楼层含 URL → 富文本链接 span（§5.6 渲染管线 2）
//   · 热门榜：全时段榜首「世子很凶」(5) 在 2025-04 无条目 → 切「本月」重排为
//     「我不想和你一起重生」(3)（§5.13 时段切换的可判定断言）
//   · 五维计数：3 个年份 / 12 个月槽 / 4 类 / 4 渠道具名 + 其他
//   · origin 三档：builtin / collected / imported → 徽标映射
//   · 书聚合：逍遥小书生 1 推荐 + 1 排雷 → 计数对比与语义筛选
//   · 求书帖 post_kind=求书 → 不进时间线（timelinePosts 只取 扫书/排雷）

Post _post({
  required int id,
  required String date,
  required String title,
  required String channel,
  required String postKind,
  required int flag,
  String author = '',
  String subChannel = '',
  String origin = Origin.builtin,
  int tid = 0,
}) {
  return Post(
    id: id,
    tid: tid == 0 ? null : tid,
    title: title,
    author: author.isEmpty ? null : author,
    portrait: '',
    date: date,
    channel: channel,
    subChannel: subChannel.isEmpty ? null : subChannel,
    postType: postKind,
    postKind: postKind,
    recommendFlag: flag,
    floorCount: 1,
    imageCount: 0,
    origin: origin,
  );
}

FloorData _floor(int id, int postId, int seq, String text) {
  return FloorData(
    floor: Floor(id: id, postId: postId, seq: seq, content: text, charCount: text.length),
    images: const <FloorImage>[], // 语料无图：避免 CachedNetworkImage 触发真实网络/磁盘缓存
  );
}

EntryRow _entry({
  required int id,
  required String nameNorm,
  required int groupId,
  required String date,
  required String channel,
  required String category,
  int? postRef,
  String? author,
  String? comment,
  String? bookGrade,
  String origin = Origin.builtin,
  int quality = 2,
  int wordCount = 120000,
}) {
  return EntryRow(
    id: id,
    name: '《$nameNorm》',
    nameNorm: nameNorm,
    author: author,
    recommender: '推荐人$id',
    comment: comment,
    date: date,
    channel: channel,
    category: category,
    bookGrade: bookGrade,
    origin: origin,
    quality: quality,
    wordCount: wordCount,
    postRef: postRef,
    bookGroupId: groupId,
  );
}

BookGroup _group({
  required int id,
  required String nameNorm,
  String? author,
  required int entryTotal,
  String? dateMin,
  String? dateMax,
}) {
  return BookGroup(
    id: id,
    nameNorm: nameNorm,
    authorEffNorm: author ?? '',
    nameDisplay: nameNorm,
    authorDisplay: author,
    entryTotal: entryTotal,
    distinctComment: 1,
    channels: '["yy小说吧"]',
    dateMin: dateMin,
    dateMax: dateMax,
  );
}

/// M1-④ widget 测试标准语料（14 条目 / 6 帖 / 6 书组）。
FakeLibrary demoLibrary() {
  final List<Post> posts = <Post>[
    _post(id: 7, date: '2025-04-28', title: '【扫书】yy小说吧四月下旬合集', channel: 'yy小说吧',
        postKind: CategoryKind.scan, flag: 1, author: '扫书人甲', tid: 11097754039),
    // 与 7 同日 → 首页时间线须**合到同一个日期组头**下（§5.2 同日合组）。
    _post(id: 8, date: '2025-04-28', title: '【扫书】哀伤雪刃四月补档', channel: '哀伤雪刃',
        postKind: CategoryKind.scan, flag: 1, author: '扫书人丙', tid: 11097754040),
    _post(id: 14403, date: '2025-04-20', title: '排雷：这几本千万别踩', channel: '哀伤雪刃',
        postKind: CategoryKind.avoid, flag: -1, author: '避雷使者', tid: 11097000001),
    _post(id: 18293, date: '2025-04-15', title: '【扫书】雪群推书四月精选', channel: '雪群推书',
        postKind: CategoryKind.scan, flag: 1, author: '雪群管理员', origin: Origin.collected, tid: 11097000002),
    _post(id: 20001, date: '2025-04-02', title: '【扫书】月初新书快报', channel: 'yy小说吧',
        postKind: CategoryKind.scan, flag: 1, author: '扫书人乙', tid: 11097000003),
    _post(id: 20002, date: '2024-12-05', title: '【扫书】大佬专栏年度盘点', channel: '大佬专栏',
        postKind: CategoryKind.scan, flag: 1, author: '大佬', origin: Origin.imported, tid: 11097000004),
    _post(id: 20003, date: '2024-06-11', title: '求书：有没有类似世子很凶的', channel: 'yy小说吧',
        postKind: CategoryKind.ask, flag: 0, author: '书荒人', tid: 11097000005),
  ];

  final Map<int, List<FloorData>> floors = <int, List<FloorData>>{
    7: <FloorData>[
      _floor(7001, 7, 1, '本期主推《篡水浒》，另有《十日终焉》值得一看，都是稳更的长篇。'),
      _floor(7002, 7, 2, '原帖备份：https://tieba.baidu.com/p/11097754039 欢迎楼下补充。'),
    ],
    8: <FloorData>[
      _floor(8001, 8, 1, '补档一帖，内容以纯文字讨论为主，暂无新增书目。'),
    ],
    14403: <FloorData>[
      _floor(14403001, 14403, 1, '排雷《毒书一号》：剧情崩坏、人设崩塌，看到三十章弃了。'),
    ],
    18293: <FloorData>[
      _floor(18293001, 18293, 1, '强烈推荐《世子很凶》，文笔老练、节奏稳，权谋线扎实。'),
    ],
    20001: <FloorData>[
      _floor(20001001, 20001, 1, '新书《我不想和你一起重生》开局不错，轻松向。'),
    ],
    20002: <FloorData>[
      _floor(20002001, 20002, 1, '年度盘点，收录《逍遥小书生》等佳作，附长评。'),
    ],
    20003: <FloorData>[
      _floor(20003001, 20003, 1, '求类似《世子很凶》的书，最近书荒得厉害。'),
    ],
  };

  const String scan = CategoryKind.scan;
  const String avoid = CategoryKind.avoid;
  final List<EntryRow> entries = <EntryRow>[
    // 世子很凶：5 条跨 2023–2025.02 → 全时段榜首；2025-04 无条目 → 本月榜缺席。
    _entry(id: 2001, nameNorm: '世子很凶', groupId: 842, date: '2023-05-01', channel: 'yy小说吧',
        category: scan, quality: 3, author: '饺子', comment: '老练的权谋文，节奏稳，人物立得住，越写越好。'),
    _entry(id: 2002, nameNorm: '世子很凶', groupId: 842, date: '2023-11-02', channel: '雪群推书',
        category: scan, postRef: 18293, origin: Origin.collected, author: '饺子'),
    _entry(id: 2003, nameNorm: '世子很凶', groupId: 842, date: '2024-03-03', channel: 'yy小说吧',
        category: scan, author: '饺子'),
    _entry(id: 2004, nameNorm: '世子很凶', groupId: 842, date: '2024-09-04', channel: '哀伤雪刃',
        category: scan, quality: 3, author: '饺子'),
    _entry(id: 2005, nameNorm: '世子很凶', groupId: 842, date: '2025-02-05', channel: 'yy小说吧',
        category: scan, author: '饺子'),
    // 我不想和你一起重生：3 条全在 2025-04 → 本月榜首。
    _entry(id: 2006, nameNorm: '我不想和你一起重生', groupId: 900, date: '2025-04-02', channel: 'yy小说吧',
        category: scan, postRef: 20001, quality: 3, author: '咸鱼军师',
        comment: '重生加恋爱游戏设定，前期笑点密集，节奏轻快不拖沓。'),
    _entry(id: 2007, nameNorm: '我不想和你一起重生', groupId: 900, date: '2025-04-10',
        channel: '雪群推书', category: scan, postRef: 18293, author: '咸鱼军师'),
    _entry(id: 2008, nameNorm: '我不想和你一起重生', groupId: 900, date: '2025-04-22', channel: 'yy小说吧',
        category: scan, postRef: 7, author: '咸鱼军师'),
    // 十日终焉：搜索台 FTS（≥3 字）主用例。
    _entry(id: 2009, nameNorm: '十日终焉', groupId: 901, date: '2025-04-28', channel: 'yy小说吧',
        category: scan, postRef: 7, quality: 3, author: '杀虫队队员',
        comment: '无限流佳作，副本设计很有想法，群像写得扎实。'),
    _entry(id: 2010, nameNorm: '十日终焉', groupId: 901, date: '2024-12-05', channel: '大佬专栏',
        category: scan, postRef: 20002, origin: Origin.imported, author: '杀虫队队员'),
    // 篡水浒：书名点击 → 搜索预填用例。
    _entry(id: 2011, nameNorm: '篡水浒', groupId: 902, date: '2025-04-28', channel: 'yy小说吧',
        category: scan, postRef: 7, author: '庚新'),
    // 毒书一号：排雷帖内条目（book_grade 红 → flag -1）。
    _entry(id: 2012, nameNorm: '毒书一号', groupId: 903, date: '2025-04-20', channel: '哀伤雪刃',
        category: avoid, postRef: 14403, quality: 1, bookGrade: '#FF0000'),
    // 逍遥小书生：1 推荐 + 1 排雷 → 书聚合页计数对比与语义筛选。
    _entry(id: 2013, nameNorm: '逍遥小书生', groupId: 904, date: '2025-03-30', channel: 'yy小说吧',
        category: scan, quality: 3, author: '荣荣',
        comment: '轻松日常向，主角讨喜，适合下饭，更新也稳定。'),
    _entry(id: 2014, nameNorm: '逍遥小书生', groupId: 904, date: '2024-06-11', channel: '哀伤雪刃',
        category: avoid, postRef: 20003, bookGrade: '#FF0000', author: '荣荣'),
  ];

  final List<BookGroup> groups = <BookGroup>[
    _group(id: 842, nameNorm: '世子很凶', author: '饺子', entryTotal: 5, dateMin: '2023-05-01', dateMax: '2025-02-05'),
    _group(id: 900, nameNorm: '我不想和你一起重生', author: '咸鱼军师', entryTotal: 3, dateMin: '2025-04-02', dateMax: '2025-04-22'),
    _group(id: 901, nameNorm: '十日终焉', author: '杀虫队队员', entryTotal: 2, dateMin: '2024-12-05', dateMax: '2025-04-28'),
    _group(id: 902, nameNorm: '篡水浒', author: '庚新', entryTotal: 1, dateMin: '2025-04-28', dateMax: '2025-04-28'),
    _group(id: 903, nameNorm: '毒书一号', entryTotal: 1, dateMin: '2025-04-20', dateMax: '2025-04-20'),
    _group(id: 904, nameNorm: '逍遥小书生', author: '荣荣', entryTotal: 2, dateMin: '2024-06-11', dateMax: '2025-03-30'),
  ];

  return FakeLibrary(posts: posts, floors: floors, entries: entries, groups: groups, newContentCount: 0);
}
