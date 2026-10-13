import 'package:drift/drift.dart';

part 'app_database.g.dart';

// 表结构逐值搬运自原型文档 §7.2（drift schema），列注释即文档原注。

/// 帖子（真实线程粒度；种子导入时同 tid 的楼层卡片已聚合为一行）。
class Posts extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 贴吧主题 id；非贴吧来源为 NULL。
  IntColumn get tid => integer().nullable().unique()();
  TextColumn get title => text().nullable()();

  /// 发帖人昵称（显示名）。
  TextColumn get author => text().nullable()();

  /// 发帖人 user_name（唯一标识）。
  TextColumn get authorName => text().nullable()();
  IntColumn get userId => integer().nullable()();
  TextColumn get portrait => text().withDefault(const Constant(''))();

  /// 'YYYY-MM-DD'，入库前校验合法性。
  TextColumn get date => text().nullable()();

  /// 非法/原始日期留档（对标 unified date_raw）。
  TextColumn get dateRaw => text().nullable()();

  /// yy小说吧/哀伤雪刃/雪群推书/大佬贴吧扫书/…
  TextColumn get channel => text()();

  /// 扫书人 ID / 尾标。
  TextColumn get subChannel => text().nullable()();

  /// 源分类留档（unified 直迁）：扫书/求书/日常，不参与产品逻辑。
  TextColumn get postType => text().withDefault(const Constant('扫书'))();

  /// 产品分类（§8.9 classifier）：扫书/排雷/求书/日常；日常闲聊采集端丢弃不入库。
  TextColumn get postKind => text().withDefault(const Constant('扫书'))();

  /// 推荐语义：+1=推荐 / -1=排雷 / 0=中性；由 post_kind 派生，大佬存量按 book_grade 映射。
  IntColumn get recommendFlag => integer().withDefault(const Constant(0))();
  IntColumn get floorCount => integer().withDefault(const Constant(0))();
  IntColumn get imageCount => integer().withDefault(const Constant(0))();

  /// builtin/collected/imported。
  TextColumn get origin => text().withDefault(const Constant('builtin'))();
  DateTimeColumn get collectedAt => dateTime().nullable()();
}

/// 楼层（一楼一行）。
class Floors extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get postId => integer().references(Posts, #id, onDelete: KeyAction.cascade)();

  /// 楼层号（1=楼主）。
  IntColumn get seq => integer()();

  /// 贴吧楼层 pid。
  IntColumn get pid => integer().nullable()();
  /// 楼层正文。SQL 列名保持 text（§7.2/§7.3 FTS 触发器约定）；
  /// Dart 名用 content 以避开 drift Table.text() 构建器的同名冲突。
  TextColumn get content => text().named('text').withDefault(const Constant(''))();

  /// sha1(norm_text)[:16]，去重用。
  TextColumn get textNormHash => text().nullable()();
  IntColumn get charCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  IntColumn get authorId => integer().nullable()();
}

/// 楼层图片。
@DataClassName('FloorImage')
class Images extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get floorId => integer().references(Floors, #id, onDelete: KeyAction.cascade)();

  /// 接口原始链（cdn_src/origin_src）。
  TextColumn get urlOriginal => text().nullable()();

  /// imgsrc 归一化永久链。
  TextColumn get urlPermanent => text().nullable()();
  IntColumn get width => integer().withDefault(const Constant(0))();
  IntColumn get height => integer().withDefault(const Constant(0))();
}

/// 书目条目（一行=一条独立推荐；种子只导入 unified dup_status='kept' 行）。
class BookEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 书名（含《》原样或裸名，存原值）。
  TextColumn get name => text()();

  /// 归一化书名（检索/聚合键）。
  TextColumn get nameNorm => text()();

  /// 小说作者。
  TextColumn get author => text().nullable()();
  TextColumn get authorNorm => text().nullable()();

  /// novel_author/inferred/parsed。
  TextColumn get authorKind => text().nullable()();

  /// 推荐人（发帖人/大佬名）。
  TextColumn get recommender => text().nullable()();

  /// 推荐语。
  TextColumn get comment => text().nullable()();

  /// clist_item/saoshu_floor_single/dalao_review/collected_floor。
  TextColumn get commentSrc => text().nullable()();
  TextColumn get commentNormHash => text().nullable()();

  /// 'YYYY-MM-DD'，CHECK 同 unified。
  TextColumn get date => text().nullable()();
  TextColumn get dateRaw => text().nullable()();
  TextColumn get channel => text()();
  TextColumn get subChannel => text().nullable()();

  /// 冗余自 posts.post_kind（扫书/排雷/求书/日常），避免搜索 join；排雷筛选维度走此列。
  TextColumn get category => text().withDefault(const Constant('扫书'))();
  IntColumn get postRef => integer().nullable().references(Posts, #id, onDelete: KeyAction.setNull)();
  IntColumn get floorRef => integer().nullable().references(Floors, #id, onDelete: KeyAction.setNull)();
  IntColumn get srcTid => integer().nullable()();
  TextColumn get srcUrl => text().nullable()();
  IntColumn get wordCount => integer().nullable()();

  /// 大佬评级 hex（#11850A/#FF0000/#000000）。
  TextColumn get bookGrade => text().nullable()();

  /// 3=作者+推荐语 2=推荐语 1=仅推荐人。
  IntColumn get quality => integer().withDefault(const Constant(2))();

  /// sha1(nameNorm+0x1f+authorNorm+0x1f+commentNormHash)[:16] 去重键。
  TextColumn get contentHash => text().unique()();
  IntColumn get bookGroupId => integer().nullable()();
  TextColumn get origin => text().withDefault(const Constant('builtin'))();
  DateTimeColumn get collectedAt => dateTime().nullable()();
}

/// 书聚合（书+作者维度；简化：与 book_name 合并，17 组作者歧义可忽略）。
class BookGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nameNorm => text().unique()();
  TextColumn get authorEffNorm => text().withDefault(const Constant(''))();
  TextColumn get nameDisplay => text().nullable()();
  TextColumn get authorDisplay => text().nullable()();
  IntColumn get entryTotal => integer().withDefault(const Constant(0))();
  IntColumn get distinctComment => integer().withDefault(const Constant(0))();

  /// JSON 数组：渠道集合。
  TextColumn get channels => text().nullable()();
  TextColumn get dateMin => text().nullable()();
  TextColumn get dateMax => text().nullable()();

  /// 榜单用。
  IntColumn get wordCountMax => integer().nullable()();
}

// 大佬档案(Experts)、名词词典(Nouns)、常用站点(SiteLinks) 三表不建（§7.2 注释）：
// 对应功能暂不做/不做；数据留存 unified.db，功能重启时按 §7.6 式迁移建表并重新打包种子。

/// 搜索历史（六维快照）。
@DataClassName('SearchHistoryEntry')
class SearchHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get query => text().withDefault(const Constant(''))();

  /// '2024' / 'early'(更早) / null=全部。
  TextColumn get year => text().nullable()();

  /// '1'..'12' / null。
  TextColumn get month => text().nullable()();

  /// 'upper'/'middle'/'lower' / null。
  TextColumn get tenDay => text().nullable()();
  TextColumn get channel => text().nullable()();

  /// 扫书/排雷/求书/日常。
  TextColumn get category => text().nullable()();
  TextColumn get sort => text().withDefault(const Constant('time_desc'))();
  DateTimeColumn get searchedAt => dateTime()();
}

/// 书签（继承扫书：条目指针 + 完整搜索条件快照 + 列表位置）。
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 指向帖子。
  IntColumn get postRef => integer().nullable()();

  /// 或指向书目条目。
  IntColumn get entryRef => integer().nullable()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get channel => text().nullable()();

  /// 结果列表位置。
  IntColumn get position => integer().withDefault(const Constant(0))();

  // ── 六维搜索条件快照 ──
  TextColumn get snapQuery => text().nullable()();
  TextColumn get snapYear => text().nullable()();
  TextColumn get snapMonth => text().nullable()();
  TextColumn get snapTenDay => text().nullable()();
  TextColumn get snapChannel => text().nullable()();
  TextColumn get snapCategory => text().nullable()();
  TextColumn get snapSort => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

/// 收藏（书/帖子双粒度）。
class Favorites extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 'book_group' | 'post' | 'entry'。
  TextColumn get targetType => text()();
  IntColumn get targetId => integer()();
  TextColumn get title => text()();
  TextColumn get subtitle => text().nullable()();
  DateTimeColumn get addedAt => dateTime()();
}

/// 采集水位（每吧一行）。
@DataClassName('CollectionStateEntry')
class CollectionState extends Table {
  /// 吧名（主键）。
  TextColumn get fname => text()();
  IntColumn get fid => integer().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  /// 水位：已采最新 create_time（epoch 秒）。
  IntColumn get lastThreadTime => integer().withDefault(const Constant(0))();

  /// 水位：已采最大 tid。
  IntColumn get lastTid => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastRunAt => dateTime().nullable()();

  /// never/ok/partial/api_error/rate_limited/canceled。
  TextColumn get lastStatus => text().withDefault(const Constant('never'))();
  TextColumn get lastError => text().nullable()();
  IntColumn get consecutiveFailures => integer().withDefault(const Constant(0))();
  DateTimeColumn get cooldownUntil => dateTime().nullable()();

  /// 首页红点。
  IntColumn get newSinceVisit => integer().withDefault(const Constant(0))();
  IntColumn get totalThreads => integer().withDefault(const Constant(0))();
  IntColumn get totalFloors => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {fname};
}

/// 采集日志（滚动保留最近 200 条）。
class CollectionLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fname => text()();
  DateTimeColumn get runAt => dateTime()();
  TextColumn get status => text()();
  IntColumn get threadsAdded => integer().withDefault(const Constant(0))();
  IntColumn get floorsAdded => integer().withDefault(const Constant(0))();
  IntColumn get entriesAdded => integer().withDefault(const Constant(0))();
  IntColumn get skippedDup => integer().withDefault(const Constant(0))();
  TextColumn get detail => text().nullable()();
}

/// KV 设置（含种子版本闸门）。
class Settings extends Table {
  /// seed_version/theme/sort_dir/wifi_only/concurrent_forums/classifier_version/...
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Posts,
    Floors,
    Images,
    BookEntries,
    BookGroups,
    SearchHistory,
    Bookmarks,
    Favorites,
    CollectionState,
    CollectionLogs,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// v2 = 含分类字段（post_kind/recommend_flag）的现行 schema。
  /// 新装用户由 onCreate 直接落 v2（种子 ETL 已产出带分类字段的数据，§7.6）；
  /// v1→v2 迁移路径仅为文档契约保留（本项目尚无 v1 存量安装）。
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      // references 的级联/置空语义依赖外键约束开启。
      await customStatement('PRAGMA foreign_keys = ON');
    },
    onCreate: (m) async {
      await m.createAll();
      await _createFts(customStatement);
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v1→v2：分类体系（P0-13，§7.6）。两新列均带 DEFAULT → addColumn 为 O(1) 元数据操作。
        // 存量回填不进迁移事务：置 settings.classifier_version=0 标记待回填，
        // 由后台 isolate 按 §8.9 规则分批重算（每 2000 行 yield，可中断续跑）。
        await m.addColumn(posts, posts.postKind);
        await m.addColumn(posts, posts.recommendFlag);
      }
    },
  );
}

/// FTS5 trigram 虚拟表 + external-content 同步触发器（原型 §7.3）。
///
/// sqlite3_flutter_libs 捆绑 SQLite ≥3.34，trigram 可用，不受 Android 系统 SQLite 版本影响；
/// 检索策略（≥3 字走 FTS、2 字词 LIKE 兜底）属 M1-④ SearchRepository。
Future<void> _createFts(Future<void> Function(String) exec) async {
  // 书级索引：书名+作者+推荐人+推荐语
  await exec('''
    CREATE VIRTUAL TABLE IF NOT EXISTS book_fts USING fts5(
      name, author, recommender, comment,
      content='book_entries', content_rowid='id',
      tokenize='trigram'
    )''');
  // 楼层全文索引（帖级搜索）
  await exec('''
    CREATE VIRTUAL TABLE IF NOT EXISTS floor_fts USING fts5(
      text, content='floors', content_rowid='id', tokenize='trigram'
    )''');
  // external-content 同步触发器（采集/导入增量自动维护）
  await exec('''CREATE TRIGGER IF NOT EXISTS book_entries_ai AFTER INSERT ON book_entries BEGIN
    INSERT INTO book_fts(rowid,name,author,recommender,comment)
    VALUES (new.id,new.name,new.author,new.recommender,new.comment); END''');
  await exec('''CREATE TRIGGER IF NOT EXISTS book_entries_ad AFTER DELETE ON book_entries BEGIN
    INSERT INTO book_fts(book_fts,rowid,name,author,recommender,comment)
    VALUES ('delete',old.id,old.name,old.author,old.recommender,old.comment); END''');
  await exec('''CREATE TRIGGER IF NOT EXISTS book_entries_au AFTER UPDATE ON book_entries BEGIN
    INSERT INTO book_fts(book_fts,rowid,name,author,recommender,comment)
    VALUES ('delete',old.id,old.name,old.author,old.recommender,old.comment);
    INSERT INTO book_fts(rowid,name,author,recommender,comment)
    VALUES (new.id,new.name,new.author,new.recommender,new.comment); END''');
  await exec('''CREATE TRIGGER IF NOT EXISTS floors_ai AFTER INSERT ON floors BEGIN
    INSERT INTO floor_fts(rowid,text) VALUES (new.id,new.text); END''');
  await exec('''CREATE TRIGGER IF NOT EXISTS floors_ad AFTER DELETE ON floors BEGIN
    INSERT INTO floor_fts(floor_fts,rowid,text) VALUES ('delete',old.id,old.text); END''');
  await exec('''CREATE TRIGGER IF NOT EXISTS floors_au AFTER UPDATE ON floors BEGIN
    INSERT INTO floor_fts(floor_fts,rowid,text) VALUES ('delete',old.id,old.text);
    INSERT INTO floor_fts(rowid,text) VALUES (new.id,new.text); END''');
}
