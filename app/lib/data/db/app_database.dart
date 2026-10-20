import 'package:drift/drift.dart';

import 'fts_schema.dart';

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
  IntColumn get postId =>
      integer().references(Posts, #id, onDelete: KeyAction.cascade)();

  /// 楼层号（1=楼主）。
  IntColumn get seq => integer()();

  /// 贴吧楼层 pid。
  IntColumn get pid => integer().nullable()();

  /// 楼层正文。SQL 列名保持 text（§7.2/§7.3 FTS 触发器约定）；
  /// Dart 名用 content 以避开 drift Table.text() 构建器的同名冲突。
  TextColumn get content =>
      text().named('text').withDefault(const Constant(''))();

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
  IntColumn get floorId =>
      integer().references(Floors, #id, onDelete: KeyAction.cascade)();

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
  IntColumn get postRef => integer().nullable().references(
    Posts,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get floorRef => integer().nullable().references(
    Floors,
    #id,
    onDelete: KeyAction.setNull,
  )();
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

  /// 帖子内阅读楼层号（书签恢复时定位；v3 新增，旧书签为 NULL = 无楼层记忆）。
  IntColumn get floorSeq => integer().nullable()();

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
  IntColumn get consecutiveFailures =>
      integer().withDefault(const Constant(0))();
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

  /// v4 = 现行 schema：在 v3（书签楼层位置 bookmarks.floor_seq）之上补齐查询索引
  /// （[_createQueryIndexes]）。此前真机 app.sqlite 全程无索引，检索/榜单/时间线/去重
  /// 均在全表扫（book_entries 5.3 万、floors 16.5 万行）。
  /// 新装用户由 onCreate 直接落 v4；v1→v2→v3→v4 迁移链：v2/v3 逐级加列（带 DEFAULT/
  /// 可空列的 O(1) 元数据操作），v4 仅 CREATE INDEX IF NOT EXISTS，均无存量回填负担。
  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      // references 的级联/置空语义依赖外键约束开启。
      await customStatement('PRAGMA foreign_keys = ON');
    },
    onCreate: (m) async {
      await m.createAll();
      await _createFts(customStatement);
      await _createQueryIndexes(customStatement);
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v1→v2：分类体系（P0-13，§7.6）。两新列均带 DEFAULT → addColumn 为 O(1) 元数据操作。
        // 存量回填不进迁移事务：置 settings.classifier_version=0 标记待回填，
        // 由后台 isolate 按 §8.9 规则分批重算（每 2000 行 yield，可中断续跑）。
        await m.addColumn(posts, posts.postKind);
        await m.addColumn(posts, posts.recommendFlag);
      }
      if (from < 3) {
        // v2→v3：书签楼层位置（bookmarks.floor_seq，可空 → 旧书签自然为 NULL）。
        await m.addColumn(bookmarks, bookmarks.floorSeq);
      }
      if (from < 4) {
        // v3→v4：补齐查询索引（真机 app.sqlite 此前全程无索引 → 检索/榜单/去重全表扫）。
        // 纯 CREATE INDEX IF NOT EXISTS，幂等；不改列，无存量回填。
        await _createQueryIndexes(customStatement);
      }
    },
  );
}

/// FTS5 trigram 虚拟表 + external-content 同步触发器（原型 §7.3）。
///
/// sqlite3_flutter_libs 捆绑 SQLite ≥3.34，trigram 可用，不受 Android 系统 SQLite 版本影响；
/// 检索策略（≥3 字走 FTS、2 字词 LIKE 兜底）属 M1-④ SearchRepository。
///
/// 表结构/触发器 DDL 的单一出处是 `fts_schema.dart`（`data/fts_index.dart` 亦复用同一份，
/// 保证「首建 / 重建 / 删除」三处逐字一致）。
Future<void> _createFts(Future<void> Function(String) exec) => createAllFts(exec);

/// 查询索引（schema v4）：服务 queries.dart 检索/榜单/时间线/五维计数、maintenance.dart
/// 去重、ingest.dart 聚合重算的实际 WHERE/ORDER BY/GROUP BY 列。真机 app.sqlite 此前
/// 全程无索引（onCreate 只建表 + FTS，seed_import 的 INSERT…SELECT 又不迁移索引对象），
/// book_entries 5.3 万 / floors 16.5 万行全在全表扫。
///
/// 全部 `CREATE INDEX IF NOT EXISTS`，命名与种子 ETL（work/seed_pack/make_seed_pack.py
/// `INDEX_DDL` 的 15 个 `idx_*`）及 app/tool/make_dev_seed.dart 手建索引**逐字对齐**——
/// 种子包库里已有同名 ETL 索引，打包工具用 drift 打开做迁移时 `IF NOT EXISTS` 直接 no-op，
/// 不会堆出两套重叠索引白白撑大发行包。
///
/// 取舍（数量克制，只建**有查询依据**的列）：
/// - 收录 ETL 15 个中确有运行时命中的 10 个（列序与 ETL 一致，含 idx_be_channel 的
///   `(channel, sub_channel)` 复合）；
/// - ETL 未覆盖、但确有查询依据的 2 列用 dev_seed 既有名（idx_book_entries_category /
///   idx_posts_kind）；
/// - ETL 的 idx_posts_channel / idx_posts_type / idx_floors_hash / idx_be_author /
///   idx_be_srctid **不建**：运行时无 WHERE/ORDER/GROUP 命中（post_type「不参与产品逻辑」、
///   text_norm_hash/src_tid 只写不查、author_norm 仅 `LIKE '%…%'` 前缀通配用不上 B-tree、
///   posts.channel 无过滤查询）。
Future<void> _createQueryIndexes(Future<void> Function(String) exec) async {
  // ── book_entries（检索/榜单/分类/去重主战场）──
  // 热门榜/字数榜 GROUP BY name_norm + LEFT JOIN book_groups ON name_norm
  // （queries.dart rankRows / wordRankRows）；去重按名取组成员
  // （maintenance.dart _fetchDupMembers WHERE name_norm=?，此前每组一次全表扫）。
  await exec('CREATE INDEX IF NOT EXISTS idx_be_name ON book_entries(name_norm)');
  // 书聚合详情/评价列表 WHERE book_group_id=?（queries.dart bookDetail / bookEntries）；
  // 组聚合重算子查询 WHERE book_group_id=?1（ingest.dart / maintenance.dart _refreshGroupAggregates）。
  await exec('CREATE INDEX IF NOT EXISTS idx_be_group ON book_entries(book_group_id)');
  // 首页时间线关联书名 WHERE post_ref IN(…)（queries.dart timelinePosts）；
  // 帖内推荐/排雷计数 WHERE post_ref=?（queries.dart postDetail）。
  await exec('CREATE INDEX IF NOT EXISTS idx_be_postref ON book_entries(post_ref)');
  // 榜单时段过滤 WHERE date>=?（rankRows/wordRankRows）、数据截至 MAX(date)（dataCutoff）、
  // 五维计数 WHERE date IS NOT NULL GROUP BY substr(date,…)（dimensionCounts）、
  // 分类预览 ORDER BY date DESC（categoryPreview）。
  await exec('CREATE INDEX IF NOT EXISTS idx_be_date ON book_entries(date)');
  // 来源维计数 GROUP BY channel（dimensionCounts）、六维搜索来源筛选 WHERE channel IN/= ?
  // （queries.dart _dimClauses）；含 sub_channel，列序与 ETL idx_be_channel 一致。
  await exec('CREATE INDEX IF NOT EXISTS idx_be_channel ON book_entries(channel, sub_channel)');
  // 来源维「自采」WHERE origin='collected'（queries.dart _dimClauses）；
  // 种子导入清理/对账 DELETE|COUNT WHERE origin（seed_import.dart）。
  await exec('CREATE INDEX IF NOT EXISTS idx_be_origin ON book_entries(origin)');
  // 类别维计数 GROUP BY category（dimensionCounts）、随机书荒 WHERE category=?（randomBooks）、
  // 六维搜索类别筛选 WHERE category=?（_dimClauses）。ETL 无此索引，用 dev_seed 既有名。
  await exec('CREATE INDEX IF NOT EXISTS idx_book_entries_category ON book_entries(category)');

  // ── posts（首页时间线）──
  // 时间线 WHERE date IS NOT NULL ORDER BY date DESC, id DESC（queries.dart timelinePosts）。
  await exec('CREATE INDEX IF NOT EXISTS idx_posts_date ON posts(date)');
  // 时间线 WHERE post_kind IN(扫书,排雷)（queries.dart timelinePosts）。ETL 无此索引，用 dev_seed 既有名。
  await exec('CREATE INDEX IF NOT EXISTS idx_posts_kind ON posts(post_kind)');
  // 种子导入清理/对账 DELETE|COUNT WHERE origin（seed_import.dart）。
  await exec('CREATE INDEX IF NOT EXISTS idx_posts_origin ON posts(origin)');

  // ── floors / images（帖详情楼层流）──
  // 帖详情 WHERE post_id=? ORDER BY seq（queries.dart postDetail）；入库/刷新/回填取楼层
  // WHERE post_id（ingest.dart ingestThread、post_refresh.dart、maintenance.dart _fetchBatchFloors）。
  await exec('CREATE INDEX IF NOT EXISTS idx_floors_post ON floors(post_id)');
  // 帖详情取图 WHERE floor_id IN(…)（queries.dart postDetail）；楼层改图先删 / 图链回写
  // WHERE floor_id=?（ingest.dart、post_refresh.dart）。
  await exec('CREATE INDEX IF NOT EXISTS idx_images_floor ON images(floor_id)');
}
