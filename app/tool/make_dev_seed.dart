// 开发/测试用小型种子库生成器（M1-④）。
//
// 从 work/seed_pack/_build/seed_lite.db（**发行包同源**的清洗库：comment≤300、已去重、
// posts 带 v3 post_kind/recommend_flag、category 已镜像同步；由 app/tool/bake_clean_seed.dart
// 就地清洗产出）分层抽样 2000 条 book_entries + 对应 posts/floors/images/book_groups，
// 写入 app/test/fixtures/dev_seed.db。
// schema 由 drift onCreate 生成（与 lib/data/db/app_database.dart 恒同步，含 book_fts/floor_fts
// 与触发器、v4 起的查询索引、user_version = 当期 schemaVersion），派生列口径：
//   - posts.post_kind / recommend_flag：**直迁源库的 v3 分类结果**。源库缺这两列即硬失败
//     （不再用 R1 标题前缀启发式自派生——那会盖掉 v3 成果、与发行包口径不一致）
//   - book_entries.category：**直迁源库值**。源库的 category 已由 maintenance 的 v3 回填镜像成
//     所属帖的 post_kind，故 fixture 与发行包同口径，本地不必再改标（此前按帖 kind 改标，
//     是当年源库 category 尚未同步时的补丁）
//   - origin：抽样内 15 个 yy小说吧帖标 collected、10 个大佬帖标 imported（覆盖三档徽标），余 builtin
//
// 运行：dart run tool/make_dev_seed.dart [源库路径]
// 仅供 widget 测试（test/features_test.dart、test/rank/rank_queries_test.dart），不进发行包。
import 'dart:io';

import 'package:drift/drift.dart' show QueryRow;
import 'package:drift/native.dart';
import 'package:booksift/data/db/app_database.dart';

const int _entryTarget = 2000;

/// 缺省源库：发行包同源的清洗库（打包输入，见 work/seed_pack/种子包说明.md §12）。
const String _defaultSeed = '../work/seed_pack/_build/seed_lite.db';

Future<void> main(List<String> args) async {
  final String seedPath = args.isNotEmpty ? args[0] : File(_defaultSeed).absolute.path;
  if (!File(seedPath).existsSync()) {
    stderr.writeln('源库不存在: $seedPath'
        '（先在 app/ 下跑 dart run tool/bake_clean_seed.dart）');
    exitCode = 1;
    return;
  }
  final File out = File('test/fixtures/dev_seed.db').absolute;
  out.parent.createSync(recursive: true);
  if (out.existsSync()) {
    out.deleteSync();
  }

  final AppDatabase db = AppDatabase(NativeDatabase(out));
  // 触发 onCreate：createAll + FTS5 虚拟表/触发器 + user_version = schemaVersion。
  await db.customSelect('SELECT 1').get();
  await db.customStatement("ATTACH DATABASE '${seedPath.replaceAll("'", "''")}' AS seed");

  Future<void> exec(String sql) => db.customStatement(sql);
  Future<int> scalar(String sql) async =>
      ((await db.customSelect(sql).get()).single.data.values.first as num).toInt();

  // 源库必须已带 v3 分类列（= 清洗库形态）；缺列说明传了未清洗的 seed_lite.db，
  // 继续下去会静默退回粗分类，故硬失败而不是兜底派生。
  final List<QueryRow> seedPostCols =
      await db.customSelect('PRAGMA seed.table_info(posts)').get();
  final Set<String> colNames =
      seedPostCols.map((QueryRow r) => r.data['name'] as String).toSet();
  if (!colNames.contains('post_kind') || !colNames.contains('recommend_flag')) {
    stderr.writeln('源库 posts 缺 post_kind/recommend_flag：$seedPath\n'
        '本工具直迁 v3 分类结果，请先跑 dart run tool/bake_clean_seed.dart 生成清洗库。');
    await db.close();
    exitCode = 1;
    return;
  }

  // ── 抽样集合（TEMP 表，确定性排序：RANDOM() 换成 id 散列保证可复现）──
  const String hashOrder = '((id * 2654435761) % 4294967296)';
  await exec('CREATE TEMP TABLE sel_e (id INTEGER PRIMARY KEY)');
  await exec('CREATE TEMP TABLE sel_p (id INTEGER PRIMARY KEY)');

  // a) v3 判定为排雷的帖，其条目：UI 排雷红条/徽标与「类别=排雷」维度的真实语料。
  await exec('''
    INSERT OR IGNORE INTO sel_e
    SELECT be.id FROM seed.book_entries be JOIN seed.posts p ON p.id = be.post_ref
    WHERE p.post_kind = '排雷' LIMIT 300''');
  // b) 大佬评级三档（book_grade → recommend_flag 映射的展示来源）。
  await exec("INSERT OR IGNORE INTO sel_e SELECT id FROM seed.book_entries WHERE book_grade='#FF0000' ORDER BY date DESC LIMIT 120");
  await exec("INSERT OR IGNORE INTO sel_e SELECT id FROM seed.book_entries WHERE book_grade='#11850A' ORDER BY date DESC LIMIT 120");
  await exec("INSERT OR IGNORE INTO sel_e SELECT id FROM seed.book_entries WHERE book_grade='#000000' ORDER BY date DESC LIMIT 80");
  // c) 求书/日常类别。
  await exec("INSERT OR IGNORE INTO sel_e SELECT id FROM seed.book_entries WHERE category='求书' LIMIT 120");
  await exec("INSERT OR IGNORE INTO sel_e SELECT id FROM seed.book_entries WHERE category='日常' LIMIT 120");
  // d) 稀有渠道全量（两吧/龙空论坛）+ 丫丫书屋抽样。
  await exec("INSERT OR IGNORE INTO sel_e SELECT id FROM seed.book_entries WHERE channel='两吧'");
  await exec("INSERT OR IGNORE INTO sel_e SELECT id FROM seed.book_entries WHERE channel='龙空论坛'");
  await exec("INSERT OR IGNORE INTO sel_e SELECT id FROM seed.book_entries WHERE channel='丫丫书屋' LIMIT 100");
  // e) Top 热门书组（≥40 条）各取 ≤15 条：热门榜/搜索组卡计数语料（世子很凶 188 等）。
  await exec('''
    INSERT OR IGNORE INTO sel_e
    SELECT id FROM (
      SELECT be.id,
             ROW_NUMBER() OVER (PARTITION BY be.book_group_id ORDER BY be.date DESC, be.id) AS rn,
             COUNT(*) OVER (PARTITION BY be.book_group_id) AS cnt
      FROM seed.book_entries be WHERE be.book_group_id IS NOT NULL
    ) WHERE rn <= 15 AND cnt >= 40 ORDER BY cnt DESC LIMIT 450''');
  // f) 近期条目（2025-03 起）：热门榜「本年/本月/近30天」时段（锚 2025-04-30）语料。
  await exec("INSERT OR IGNORE INTO sel_e SELECT id FROM seed.book_entries WHERE date >= '2025-03-01' ORDER BY date DESC LIMIT 250");
  // g) 富推荐语条目（书聚合页评价卡语料）。
  await exec('''
    INSERT OR IGNORE INTO sel_e
    SELECT id FROM seed.book_entries
    WHERE comment IS NOT NULL AND length(comment) BETWEEN 40 AND 400 AND author IS NOT NULL AND author != ''
    ORDER BY $hashOrder LIMIT 400''');

  // 修到恰好 2000：超出按插入序裁剪，不足随机补满。
  int selected = await scalar('SELECT COUNT(*) FROM sel_e');
  if (selected > _entryTarget) {
    await exec('DELETE FROM sel_e WHERE id NOT IN (SELECT id FROM sel_e ORDER BY rowid LIMIT $_entryTarget)');
  } else if (selected < _entryTarget) {
    await exec('''
      INSERT OR IGNORE INTO sel_e
      SELECT id FROM seed.book_entries WHERE id NOT IN (SELECT id FROM sel_e)
      ORDER BY $hashOrder LIMIT ${_entryTarget - selected}''');
  }
  selected = await scalar('SELECT COUNT(*) FROM sel_e');

  // 条目引用的帖 + 60 个 2025 帖兜底（首页时间线多日期分组）。
  await exec('''
    INSERT OR IGNORE INTO sel_p
    SELECT DISTINCT be.post_ref FROM seed.book_entries be
    JOIN sel_e ON sel_e.id = be.id WHERE be.post_ref IS NOT NULL''');
  await exec('''
    INSERT OR IGNORE INTO sel_p
    SELECT id FROM seed.posts WHERE date >= '2025-01-01' ORDER BY date DESC LIMIT 60''');

  // 楼层抽样（floor_fts trigram 索引 ≈ 10× 文本，控制 fixture 体积）：
  // 全部帖首楼 + 40 个详情样本帖（20 排雷 + 20 最新）深楼层 + 条目引用楼层 + URL 楼层。
  await exec('CREATE TEMP TABLE sel_dp (id INTEGER PRIMARY KEY)');
  await exec('''
    INSERT OR IGNORE INTO sel_dp
    SELECT p.id FROM seed.posts p JOIN sel_p ON sel_p.id = p.id
    WHERE p.post_kind = '排雷' LIMIT 20''');
  await exec('''
    INSERT OR IGNORE INTO sel_dp
    SELECT p.id FROM seed.posts p JOIN sel_p ON sel_p.id = p.id
    WHERE p.date IS NOT NULL ORDER BY p.date DESC LIMIT 20''');
  await exec('CREATE TEMP TABLE sel_f (id INTEGER PRIMARY KEY)');
  // 每帖一条首楼（seed 中同帖存在多条 seq=1 聚合卡，取信息量最高一条；时间线卡片语料）。
  await exec('''
    INSERT OR IGNORE INTO sel_f
    SELECT id FROM (
      SELECT f.id, ROW_NUMBER() OVER (PARTITION BY f.post_id ORDER BY f.char_count DESC, f.id) AS rn
      FROM seed.floors f JOIN sel_p ON sel_p.id = f.post_id
      WHERE f.seq = 1 AND f.char_count BETWEEN 20 AND 600
    ) WHERE rn = 1''');
  await exec('''
    INSERT OR IGNORE INTO sel_f
    SELECT f.id FROM seed.floors f JOIN sel_dp ON sel_dp.id = f.post_id
    WHERE f.seq <= 8 AND f.char_count <= 1000''');
  await exec('''
    INSERT OR IGNORE INTO sel_f
    SELECT f.id FROM seed.floors f JOIN sel_p ON sel_p.id = f.post_id
    WHERE f.text LIKE '%http%' AND f.char_count <= 1000 LIMIT 100''');
  await exec('''
    INSERT OR IGNORE INTO sel_f
    SELECT f.id FROM seed.floors f
    JOIN seed.book_entries be ON be.floor_ref = f.id JOIN sel_e ON sel_e.id = be.id
    WHERE f.char_count <= 600 LIMIT 600''');
  await exec('CREATE TEMP TABLE sel_i (id INTEGER PRIMARY KEY)');
  await exec('INSERT OR IGNORE INTO sel_i SELECT i.id FROM seed.images i JOIN sel_f ON sel_f.id = i.floor_id');
  await exec('CREATE TEMP TABLE sel_g (id INTEGER PRIMARY KEY)');
  await exec('''
    INSERT OR IGNORE INTO sel_g
    SELECT DISTINCT be.book_group_id FROM seed.book_entries be
    JOIN sel_e ON sel_e.id = be.id WHERE be.book_group_id IS NOT NULL''');

  // 合成 origin 样本：选被抽条目最多的 yy小说吧/大佬贴吧扫书 帖标 collected/imported
  // （覆盖三档 origin 徽标；M2 自采与 P2-5 导入形态前置）。
  await exec('CREATE TEMP TABLE synth_c (id INTEGER PRIMARY KEY)');
  await exec('''
    INSERT OR IGNORE INTO synth_c
    SELECT be.post_ref FROM seed.book_entries be
    JOIN sel_e ON sel_e.id = be.id JOIN seed.posts p ON p.id = be.post_ref
    WHERE p.channel = 'yy小说吧' AND be.post_ref IS NOT NULL
    GROUP BY be.post_ref ORDER BY COUNT(*) DESC LIMIT 15''');
  await exec('CREATE TEMP TABLE synth_i (id INTEGER PRIMARY KEY)');
  await exec('''
    INSERT OR IGNORE INTO synth_i
    SELECT be.post_ref FROM seed.book_entries be
    JOIN sel_e ON sel_e.id = be.id JOIN seed.posts p ON p.id = be.post_ref
    WHERE p.channel = '大佬贴吧扫书' AND be.post_ref IS NOT NULL
    GROUP BY be.post_ref ORDER BY COUNT(*) DESC LIMIT 10''');

  // ── 装载（main = drift schema；trigger 同步维护 book_fts/floor_fts）──
  await exec('''
    INSERT INTO main.book_groups
      (id, name_norm, author_eff_norm, name_display, author_display, entry_total,
       distinct_comment, channels, date_min, date_max, word_count_max)
    SELECT g.id, g.name_norm, g.author_eff_norm, g.name_display, g.author_display, g.entry_total,
           g.distinct_comment, g.channels, g.date_min, g.date_max, g.word_count_max
    FROM seed.book_groups g JOIN sel_g ON sel_g.id = g.id''');

  // post_kind / recommend_flag 直迁源库的 v3 分类结果（口径与 seed_import.dart
  // `_copyInTransaction` 检测到分类列时的直迁分支一致）。
  await exec('''
    INSERT INTO main.posts
      (id, tid, title, author, author_name, user_id, portrait, date, date_raw, channel, sub_channel,
       post_type, post_kind, recommend_flag, floor_count, image_count, origin, collected_at)
    SELECT p.id, p.tid, p.title, p.author, NULL, p.user_id, '', p.date, p.date_raw, p.channel, p.sub_channel,
      p.post_type,
      p.post_kind,
      p.recommend_flag,
      (SELECT COUNT(*) FROM seed.floors sf WHERE sf.post_id = p.id AND sf.id IN (SELECT id FROM sel_f)),
      (SELECT COUNT(*) FROM seed.images si JOIN seed.floors sf2 ON sf2.id = si.floor_id
        WHERE sf2.post_id = p.id AND si.id IN (SELECT id FROM sel_i)),
      CASE
        WHEN p.id IN (SELECT id FROM synth_c) THEN 'collected'
        WHEN p.id IN (SELECT id FROM synth_i) THEN 'imported'
        ELSE 'builtin' END,
      CASE WHEN p.id IN (SELECT id FROM synth_c) THEN strftime('%s', '2026-10-01') ELSE NULL END
    FROM seed.posts p JOIN sel_p ON sel_p.id = p.id''');

  await exec('''
    INSERT INTO main.floors (id, post_id, seq, pid, text, text_norm_hash, char_count, created_at, author_id)
    SELECT f.id, f.post_id, f.seq, f.pid, f.text, f.text_norm_hash, f.char_count, f.created_at, f.author_id
    FROM seed.floors f JOIN sel_f ON sel_f.id = f.id''');

  await exec('''
    INSERT INTO main.images (id, floor_id, url_original, url_permanent, width, height)
    SELECT i.id, i.floor_id, i.url_original, i.url_permanent, i.width, i.height
    FROM seed.images i JOIN sel_i ON sel_i.id = i.id''');

  await exec('''
    INSERT INTO main.book_entries
      (id, name, name_norm, author, author_norm, author_kind, recommender, comment, comment_src,
       comment_norm_hash, date, date_raw, channel, sub_channel, category, post_ref, floor_ref,
       src_tid, src_url, word_count, book_grade, quality, content_hash, book_group_id, origin, collected_at)
    SELECT be.id, be.name, be.name_norm, be.author, be.author_norm, be.author_kind, be.recommender,
      CASE WHEN length(be.comment) > 220 AND (be.id % 5) != 0
        THEN substr(be.comment, 1, 200) || '…' ELSE be.comment END,
      be.comment_src, be.comment_norm_hash, be.date, be.date_raw, be.channel, be.sub_channel,
      be.category,
      be.post_ref,
      CASE WHEN be.floor_ref IN (SELECT id FROM sel_f) THEN be.floor_ref ELSE NULL END,
      be.src_tid, be.src_url, be.word_count, be.book_grade, be.quality, be.content_hash, be.book_group_id,
      CASE
        WHEN be.post_ref IN (SELECT id FROM synth_c) THEN 'collected'
        WHEN be.post_ref IN (SELECT id FROM synth_i) THEN 'imported'
        ELSE 'builtin' END,
      CASE WHEN be.post_ref IN (SELECT id FROM synth_c) THEN strftime('%s', '2026-10-01') ELSE NULL END
    FROM seed.book_entries be
    JOIN sel_e ON sel_e.id = be.id''');

  // 索引不再手建：drift schema v4 起由 app_database.dart `_createQueryIndexes` 在 onCreate 建齐
  // （此前这里手建 8 个，其中 5 个与 schema 内的同列异名 → fixture 会并存两套重叠索引）。

  await exec('DETACH DATABASE seed');
  await exec('VACUUM');

  final int userVersion = await scalar('PRAGMA user_version');
  // fixture 的 user_version 必须等于当期 drift schemaVersion，否则测试跑在过期 schema 上。
  // 从 AppDatabase 实例读而不是写死数字：本文件曾写死「须为 2」，schema 升到 3 后就静默失效。
  final AppDatabase probe = AppDatabase(NativeDatabase.memory());
  final int expectedVersion = probe.schemaVersion;
  await probe.close();
  final Map<String, int> counts = <String, int>{
    'book_entries': await scalar('SELECT COUNT(*) FROM book_entries'),
    'posts': await scalar('SELECT COUNT(*) FROM posts'),
    'floors': await scalar('SELECT COUNT(*) FROM floors'),
    'images': await scalar('SELECT COUNT(*) FROM images'),
    'book_groups': await scalar('SELECT COUNT(*) FROM book_groups'),
    'kind_排雷': await scalar("SELECT COUNT(*) FROM posts WHERE post_kind='排雷'"),
    'cat_排雷': await scalar("SELECT COUNT(*) FROM book_entries WHERE category='排雷'"),
    'cat_求书': await scalar("SELECT COUNT(*) FROM book_entries WHERE category='求书'"),
    'cat_日常': await scalar("SELECT COUNT(*) FROM book_entries WHERE category='日常'"),
    'origin_collected': await scalar("SELECT COUNT(*) FROM book_entries WHERE origin='collected'"),
    'origin_imported': await scalar("SELECT COUNT(*) FROM book_entries WHERE origin='imported'"),
    'fts_rows': await scalar('SELECT COUNT(*) FROM book_fts'),
    'floor_fts_rows': await scalar('SELECT COUNT(*) FROM floor_fts'),
    'fts_3gram_hits': await scalar("SELECT COUNT(*) FROM book_fts WHERE book_fts MATCH '\"十日终焉\"'"),
    'entries_2025_04': await scalar("SELECT COUNT(*) FROM book_entries WHERE date >= '2025-04-01' AND date < '2025-05-01'"),
    'date_groups': await scalar('SELECT COUNT(DISTINCT date) FROM posts WHERE date IS NOT NULL'),
  };
  await db.close();

  stdout.writeln('dev_seed.db 生成完毕: ${out.path} (${(out.lengthSync() / 1048576).toStringAsFixed(2)} MB)');
  stdout.writeln('user_version=$userVersion (须为 $expectedVersion) selected=$selected');
  counts.forEach((String k, int v) => stdout.writeln('  $k = $v'));
  if (userVersion != expectedVersion || counts['book_entries'] != _entryTarget) {
    exitCode = 1;
  }
}
