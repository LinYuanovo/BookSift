// 开发/测试用小型种子库生成器（M1-④）。
//
// 从 work/seed_pack/_build/seed_lite.db（桌面 ETL 产物，表结构对齐 App schema）分层抽样
// 2000 条 book_entries + 对应 posts/floors/images/book_groups，写入 app/test/fixtures/dev_seed.db。
// schema 由 drift onCreate 生成（与 lib/data/db/app_database.dart 恒同步，含 book_fts/floor_fts
// 与触发器、user_version=2），派生列按原型 §8.9：
//   - posts.post_kind：标题起首排雷意图词（R1 简化集）→ 排雷；否则取 post_type（扫书/求书/日常）
//   - posts.recommend_flag：扫书→+1 / 排雷→−1 / 求书·日常→0
//   - book_entries.category：R1 排雷帖的条目改标 排雷，其余沿用种子值（大佬条目语义另按 book_grade）
//   - origin：抽样内 12 个 yy小说吧 2025 帖标 collected、6 个大佬帖标 imported（覆盖三档徽标），余 builtin
//
// 运行：dart run tool/make_dev_seed.dart [seed_lite.db 路径]
// 仅供 widget 测试（test/features_test.dart），不进发行包。
import 'dart:io';

import 'package:drift/native.dart';
import 'package:saoshuhui/data/db/app_database.dart';

const int _entryTarget = 2000;

/// §8.9 R1：标题**起首**排雷意图词（简化为 LIKE 前缀集）。
const List<String> _avoidPrefixes = <String>['排雷', '避雷', '踩雷', '扫雷', '雷点', '毒点盘点', '慎入', '剧毒', '粪作'];

String get _avoidTitleSql => _avoidPrefixes.map((String w) => "p.title LIKE '$w%'").join(' OR ');

Future<void> main(List<String> args) async {
  final String seedPath =
      args.isNotEmpty ? args[0] : File('../work/seed_pack/_build/seed_lite.db').absolute.path;
  if (!File(seedPath).existsSync()) {
    stderr.writeln('seed_lite.db 不存在: $seedPath');
    exitCode = 1;
    return;
  }
  final File out = File('test/fixtures/dev_seed.db').absolute;
  out.parent.createSync(recursive: true);
  if (out.existsSync()) {
    out.deleteSync();
  }

  final AppDatabase db = AppDatabase(NativeDatabase(out));
  // 触发 onCreate：createAll + FTS5 虚拟表/触发器 + user_version=2。
  await db.customSelect('SELECT 1').get();
  await db.customStatement("ATTACH DATABASE '${seedPath.replaceAll("'", "''")}' AS seed");

  Future<void> exec(String sql) => db.customStatement(sql);
  Future<int> scalar(String sql) async =>
      ((await db.customSelect(sql).get()).single.data.values.first as num).toInt();

  // ── 抽样集合（TEMP 表，确定性排序：RANDOM() 换成 id 散列保证可复现）──
  const String hashOrder = '((id * 2654435761) % 4294967296)';
  await exec('CREATE TEMP TABLE sel_e (id INTEGER PRIMARY KEY)');
  await exec('CREATE TEMP TABLE sel_p (id INTEGER PRIMARY KEY)');

  // a) 排雷帖（R1 标题）的条目：UI 排雷红条/徽标与「类别=排雷」维度的真实语料。
  await exec('''
    INSERT OR IGNORE INTO sel_e
    SELECT be.id FROM seed.book_entries be JOIN seed.posts p ON p.id = be.post_ref
    WHERE $_avoidTitleSql LIMIT 300''');
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
    SELECT p.id FROM seed.posts p JOIN sel_p ON sel_p.id = p.id WHERE $_avoidTitleSql LIMIT 20''');
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

  final String kindSql = '''
    CASE
      WHEN $_avoidTitleSql THEN '排雷'
      WHEN p.post_type IN ('求书','日常') THEN p.post_type
      ELSE '扫书' END''';
  await exec('''
    INSERT INTO main.posts
      (id, tid, title, author, author_name, user_id, portrait, date, date_raw, channel, sub_channel,
       post_type, post_kind, recommend_flag, floor_count, image_count, origin, collected_at)
    SELECT p.id, p.tid, p.title, p.author, NULL, p.user_id, '', p.date, p.date_raw, p.channel, p.sub_channel,
      p.post_type,
      $kindSql,
      CASE $kindSql WHEN '扫书' THEN 1 WHEN '排雷' THEN -1 ELSE 0 END,
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
      CASE WHEN p.id IS NOT NULL AND ($_avoidTitleSql) THEN '排雷' ELSE be.category END,
      be.post_ref,
      CASE WHEN be.floor_ref IN (SELECT id FROM sel_f) THEN be.floor_ref ELSE NULL END,
      be.src_tid, be.src_url, be.word_count, be.book_grade, be.quality, be.content_hash, be.book_group_id,
      CASE
        WHEN be.post_ref IN (SELECT id FROM synth_c) THEN 'collected'
        WHEN be.post_ref IN (SELECT id FROM synth_i) THEN 'imported'
        ELSE 'builtin' END,
      CASE WHEN be.post_ref IN (SELECT id FROM synth_c) THEN strftime('%s', '2026-10-01') ELSE NULL END
    FROM seed.book_entries be
    JOIN sel_e ON sel_e.id = be.id
    LEFT JOIN seed.posts p ON p.id = be.post_ref''');

  // 查询索引（种子 ETL 预建同款，§7.4/§5.13）。
  await exec('CREATE INDEX IF NOT EXISTS idx_book_entries_date ON book_entries(date)');
  await exec('CREATE INDEX IF NOT EXISTS idx_book_entries_name_norm ON book_entries(name_norm)');
  await exec('CREATE INDEX IF NOT EXISTS idx_book_entries_category ON book_entries(category)');
  await exec('CREATE INDEX IF NOT EXISTS idx_book_entries_channel ON book_entries(channel)');
  await exec('CREATE INDEX IF NOT EXISTS idx_book_entries_postref ON book_entries(post_ref)');
  await exec('CREATE INDEX IF NOT EXISTS idx_book_entries_group ON book_entries(book_group_id)');
  await exec('CREATE INDEX IF NOT EXISTS idx_posts_date ON posts(date)');
  await exec('CREATE INDEX IF NOT EXISTS idx_posts_kind ON posts(post_kind)');

  await exec('DETACH DATABASE seed');
  await exec('VACUUM');

  final int userVersion = await scalar('PRAGMA user_version');
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

  stdout.writeln('dev_seed.db 生成完毕: $out.path (${(out.lengthSync() / 1048576).toStringAsFixed(2)} MB)');
  stdout.writeln('user_version=$userVersion (须为 2) selected=$selected');
  counts.forEach((String k, int v) => stdout.writeln('  $k = $v'));
  if (userVersion != 2 || counts['book_entries'] != _entryTarget) {
    exitCode = 1;
  }
}
