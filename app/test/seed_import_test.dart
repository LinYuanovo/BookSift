// M1-③ 种子数据包导入测试。
//
// Fixture：测试内脚本化生成迷你 seed.db（sqlite3 直建，镜像 make_seed_pack.py 的种子 schema：
// 含 seed-only 溯源列、lite 形态无 FTS / full 形态预建 external-content FTS5 trigram），
// archive ZipFileEncoder 打 deflate zip + 随包 manifest.json（含 zip_sha256 / full_pack 块），
// 经 _DirAssetBundle 按生产同款 asset key 喂给 DefaultSeedImporter。
//
// 覆盖：闸门 / 首启导入 / 重复导入幂等 / 升级重写保用户行(组重挂+分类列直迁) /
// SHA256 失败拒绝(zip+db 两级) / FTS 后台重建(进度流+MATCH+触发器恢复) / 取消+重跑 /
// importFull 预建 FTS 影子表复制跳过重建 / 维护闸门随包走(pre_deduped+pre_classified_v3
// → 落账跳过首启白扫；老包无标记不退化；包版本过期仍重跑) / 真实 lite asset 包完整性。
//
// ── 真实 lite 包桌面实测（BENCH 测试，pwsh：`$env:BENCH='true'; flutter test
//    test/seed_import_test.dart --plain-name BENCH`；2026-10-14，Windows 桌面 flutter-test JIT，
//    NVMe，包体 = `repack_deflate.py --target-mb 70` 产物（源 = 就地清洗后的
//    `_build/seed_lite.db`）：deflate zip 60.5MiB / seed.db 165.0MiB / comment≤300 /
//    schema v4（17 索引）/ 已去重 + v3 分类已回填 + category 已镜像同步）：
//    ┌ 导入全程（asset 读取→sha256 校验 zip+db→解压 165MB→ATTACH 单事务拷贝 305k 行→闸门落账→清理）
//    │   = 3.46s（其中解压+校验段 2.34s，拷贝事务段 ~1.1s）
//    ├ FTS 后台重建（book_fts 53,441 + floor_fts 165,399 行，110 批×2000）= 18.4s
//    ├ 首启维护 no-op 验证（dedup 0 删 / reclassify 0 改 0 同步，含词典构建）= 9.8s ← 见下注
//    └ 导入+重建后 app.db = 400MiB
//    注：维护那 9.8s 是「白扫」——包内已是收敛态，扫完 0 删 0 改。**生产路径不付这笔钱**：
//    闸门随包走（manifest.features.pre_deduped / pre_classified_v3 → _copyInTransaction 第 5b 步
//    落 settings.dedup_version / classifier_version），首启 needsDedup/needsReclassify 均为 false
//    直接跳过；本 BENCH 仍**强制直调** dedupBookEntries/reclassifyPostsV3 以保留 no-op 验收。
//    对比清洗固化前同段 18.7s：降幅来自 schema v4 的 12 个查询索引（drift `_createQueryIndexes`），
//    代价是导入拷贝段 0.7s→1.1s（带索引批量插入）与 app.db 388→400MiB。实测过「拷贝期临时
//    DROP 索引」，不划算（省下的与事后对满表 CREATE INDEX 的全表扫+排序相抵，还开出
//    「有数据无索引」的崩溃窗口），故不采用。
//    对照：种子包说明.md §8 的 35.0s 首启导入口径含触发器逐行同步 FTS；本实现拷贝期摘除触发器、
//    FTS 改后台批式重建，故导入事务远快于该口径。中端手机按文档 §6.3 的 ×2–3 系数估算：
//    导入 ≈ 10–25s（一次性、有进度页），FTS 重建 ≈ 45–90s（后台 isolate，不阻塞 UI，可取消续跑）；
//    Release AOT 下纯 Dart 段（sha256/inflate）还会更快。清洗固化的完整口径见 种子包说明.md §12。
@Timeout(Duration(minutes: 10))
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show QueryRow, Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:booksift/classify/classifier.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/maintenance.dart';
import 'package:booksift/data/seed_import.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

// ─────────────────────────── fixture 常量与构建 ───────────────────────────

const int _postCount = 12;
const int _floorCount = 30;
const int _imageCount = 6;
const int _entryCountV1 = 24000; // > 12 批（2000/批）→ 取消测试有安全窗口

/// 推荐语填充文本（~130 字/行，模拟真实 lite 包 comment 形态）：
/// trigram 索引成本 ∝ 文本长度，太短会让重建 0.1s 跑完、取消测试无窗口。
const String _commentPad = '长剑如歌行板测试文本段落甲乙丙丁戊己庚辛壬癸子丑寅卯辰巳午未申酉戌亥'
    '长剑如歌行板测试文本段落甲乙丙丁戊己庚辛壬癸子丑寅卯辰巳午未申酉戌亥'
    '长剑如歌行板测试文本段落甲乙丙丁戊己庚辛壬癸子丑寅卯辰巳午未申酉戌亥'
    '长剑如歌行板测试文本段落甲乙丙丁戊己庚辛壬癸子丑寅卯辰巳午未申酉戌亥';
const int _groupCountV1 = 5;

/// 闸门类用例的小包行数（只验 settings 落账，不需要 FTS 重建那种规模）。
const int _entryCountSmall = 100;

late Directory _root; // 全部 fixture 的临时根
late Directory _bundleV1; // lite v1 asset 目录（zip + manifest，含 full_pack 块）
late Directory _bundleV2; // lite v2 asset 目录（升级用：改标题/删组换 id/加行/带分类列）
late Directory _bundleBadZip; // v1 manifest + 中段字节损坏的 zip
late Directory _bundleBadDbSha; // 内嵌 manifest db_sha256 全零
late Directory _bundleGated; // 清洗固化 lite 包：features 带 pre_deduped + pre_classified_v3
late Directory _bundleStale; // 同上但分类器版本过期（pre_classified_v3 = classifierVersion - 1）
late String _fullZipPath; // full 档（预建 FTS）zip 磁盘路径（模拟用户下载件）
late String _fullGatedZipPath; // full 档清洗固化包（预建 FTS + 同两个标记）zip 路径

/// 直建迷你 seed.db（镜像 make_seed_pack.py 的 DDL；含 seed-only 溯源列以验证导入按列名取用）。
void _writeSeedDb(
  String dbPath, {
  required int entryMax,
  required int groupCount,
  required int groupIdBase,
  bool extraPost = false,
  int extraEntryId = 0,
  String post1Title = '扫书帖标题一',
  bool kindColumns = false,
  bool ftsPrebuilt = false,
}) {
  final sql.Database db = sql.sqlite3.open(dbPath);
  try {
    db.execute('PRAGMA journal_mode=OFF');
    db.execute('''
      CREATE TABLE posts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tid INTEGER UNIQUE, title TEXT, author TEXT, author_name TEXT, user_id INTEGER,
        portrait TEXT NOT NULL DEFAULT '',
        date TEXT CHECK(date IS NULL OR date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
        date_raw TEXT,
        channel TEXT NOT NULL, sub_channel TEXT,
        post_type TEXT NOT NULL DEFAULT '扫书',
        ${kindColumns ? "post_kind TEXT NOT NULL DEFAULT '扫书', recommend_flag INTEGER NOT NULL DEFAULT 0," : ''}
        floor_count INTEGER NOT NULL DEFAULT 0, image_count INTEGER NOT NULL DEFAULT 0,
        origin TEXT NOT NULL DEFAULT 'seed', collected_at INTEGER,
        raw_content TEXT, src_origin TEXT, src_origin_id INTEGER
      )''');
    db.execute('''
      CREATE TABLE floors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        post_id INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
        seq INTEGER NOT NULL, pid INTEGER,
        text TEXT NOT NULL DEFAULT '', text_norm_hash TEXT,
        char_count INTEGER NOT NULL DEFAULT 0, created_at INTEGER, author_id INTEGER,
        src_origin_id INTEGER
      )''');
    db.execute('''
      CREATE TABLE images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        floor_id INTEGER NOT NULL REFERENCES floors(id) ON DELETE CASCADE,
        url_original TEXT, url_permanent TEXT,
        width INTEGER NOT NULL DEFAULT 0, height INTEGER NOT NULL DEFAULT 0,
        src_origin_id INTEGER
      )''');
    db.execute('''
      CREATE TABLE book_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL, name_norm TEXT NOT NULL,
        author TEXT, author_norm TEXT, author_kind TEXT,
        recommender TEXT, comment TEXT, comment_src TEXT, comment_norm_hash TEXT,
        date TEXT CHECK(date IS NULL OR date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
        date_raw TEXT,
        channel TEXT NOT NULL, sub_channel TEXT,
        category TEXT NOT NULL DEFAULT '扫书',
        post_ref INTEGER REFERENCES posts(id) ON DELETE SET NULL,
        floor_ref INTEGER REFERENCES floors(id) ON DELETE SET NULL,
        src_tid INTEGER, src_url TEXT, word_count INTEGER, book_grade TEXT,
        quality INTEGER NOT NULL DEFAULT 2,
        content_hash TEXT NOT NULL UNIQUE,
        book_group_id INTEGER,
        origin TEXT NOT NULL DEFAULT 'seed', collected_at INTEGER,
        src_origin TEXT, src_origin_table TEXT, src_origin_id INTEGER
      )''');
    db.execute('''
      CREATE TABLE book_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name_norm TEXT NOT NULL UNIQUE,
        author_eff_norm TEXT NOT NULL DEFAULT '',
        name_display TEXT, author_display TEXT,
        entry_total INTEGER NOT NULL DEFAULT 0, distinct_comment INTEGER NOT NULL DEFAULT 0,
        channels TEXT, date_min TEXT, date_max TEXT, word_count_max INTEGER
      )''');

    db.execute('BEGIN');
    // posts 1..12（+可选 id=20 加行）：tid 1..8 真实、9..12 NULL；类型混合。
    final sql.PreparedStatement psPost = db.prepare(
      'INSERT INTO posts(id,tid,title,author,date,channel,post_type'
      '${kindColumns ? ',post_kind,recommend_flag' : ''}'
      ',floor_count,origin,src_origin,src_origin_id) '
      'VALUES(:id,:tid,:title,:author,:date,:channel,:pt'
      '${kindColumns ? ',:pk,:rf' : ''}'
      ',:fc,:origin,:so,:soid)',
    );
    for (var id = 1; id <= _postCount + (extraPost ? 1 : 0); id++) {
      final int realId = (extraPost && id == _postCount + 1) ? 20 : id;
      final String pt = id == 7 || id == 10 ? '求书' : (id == 8 || id == 11 ? '日常' : '扫书');
      psPost.executeWith(sql.StatementParameters.named(<String, Object?>{
        ':id': realId,
        ':tid': realId <= 8 ? 100000 + realId : null,
        ':title': realId == 1 ? post1Title : '帖子标题$realId',
        ':author': '作者君$realId',
        ':date': '2024-0${(realId % 9) + 1}-15',
        ':channel': realId % 2 == 0 ? 'yy小说吧' : '哀伤雪刃',
        ':pt': pt,
        if (kindColumns) ':pk': realId == 1 ? '排雷' : pt,
        if (kindColumns) ':rf': realId == 1 ? -1 : (pt == '扫书' ? 1 : 0),
        ':fc': 3,
        ':origin': 'seed',
        ':so': 'saoshu',
        ':soid': realId,
      }));
    }
    psPost.close();
    // floors 1..30（floor 5 带可检索特征文本）+ images 1..6
    final sql.PreparedStatement psFloor = db.prepare(
      'INSERT INTO floors(id,post_id,seq,text,text_norm_hash,char_count,src_origin_id) '
      'VALUES(:id,:pid,:seq,:text,:nh,:cc,:soid)',
    );
    for (var id = 1; id <= _floorCount; id++) {
      final String text = id == 5 ? '紫气东来测试楼层正文' : '楼层正文$id 普通内容';
      psFloor.executeWith(sql.StatementParameters.named(<String, Object?>{
        ':id': id, ':pid': ((id - 1) % _postCount) + 1, ':seq': id,
        ':text': text, ':nh': 'nh$id', ':cc': text.length, ':soid': id,
      }));
    }
    psFloor.close();
    final sql.PreparedStatement psImg = db.prepare(
      'INSERT INTO images(id,floor_id,url_permanent,width,height,src_origin_id) '
      'VALUES(:id,:fid,:url,100,200,:soid)',
    );
    for (var id = 1; id <= _imageCount; id++) {
      psImg.executeWith(sql.StatementParameters.named(<String, Object?>{
        ':id': id, ':fid': id, ':url': 'https://imgsrc.baidu.com/forum/pic/item/$id.jpg', ':soid': id,
      }));
    }
    psImg.close();
    // book_groups：id = base+1..base+N，name_norm 'g1'..'gN'
    final sql.PreparedStatement psGrp = db.prepare(
      'INSERT INTO book_groups(id,name_norm,name_display,entry_total,channels) '
      "VALUES(:id,:nn,:nd,0,'[\"yy小说吧\"]')",
    );
    for (var k = 1; k <= groupCount; k++) {
      psGrp.executeWith(sql.StatementParameters.named(<String, Object?>{':id': groupIdBase + k, ':nn': 'g$k', ':nd': 'G$k'}));
    }
    psGrp.close();
    // book_entries 1..entryMax（+可选加行）：每 100 条埋 '赛博剑仙测试' 特征推荐语；id 42 独特书名。
    final sql.PreparedStatement psEntry = db.prepare(
      'INSERT INTO book_entries(id,name,name_norm,author,recommender,comment,content_hash,'
      'channel,category,post_ref,floor_ref,book_group_id,origin,comment_norm_hash,date,'
      'word_count,quality,src_origin,src_origin_table,src_origin_id) '
      "VALUES(:id,:name,:name,:author,:rec,:comment,:ch,'yy小说吧','扫书',:pref,:fref,:gid,'seed',:cnh,"
      "'2024-03-01',:wc,2,'saoshu','book',:id)",
    );
    void insertEntry(int id) {
      psEntry.executeWith(sql.StatementParameters.named(<String, Object?>{
        ':id': id,
        ':name': id == 42 ? '独特书名剑来' : '书名$id',
        ':author': '作者${id % 50}',
        ':rec': '吧友$id',
        ':comment': id % 100 == 0 ? '赛博剑仙测试推荐语$id $_commentPad' : '推荐语$id $_commentPad',
        ':ch': 'h$id',
        ':pref': ((id - 1) % _postCount) + 1,
        ':fref': ((id - 1) % _floorCount) + 1,
        ':gid': groupIdBase + (id % groupCount) + 1,
        ':cnh': 'cnh$id',
        ':wc': 1000 + id % 500,
      }));
    }
    for (var id = 1; id <= entryMax; id++) {
      insertEntry(id);
    }
    if (extraEntryId > 0) {
      insertEntry(extraEntryId);
    }
    psEntry.close();
    db.execute('COMMIT');

    if (ftsPrebuilt) {
      // full 档形态：预建 external-content FTS5 trigram（与 app_database._createFts 同定义）。
      db.execute('''CREATE VIRTUAL TABLE book_fts USING fts5(
        name, author, recommender, comment,
        content='book_entries', content_rowid='id', tokenize='trigram')''');
      db.execute('''CREATE VIRTUAL TABLE floor_fts USING fts5(
        text, content='floors', content_rowid='id', tokenize='trigram')''');
      db.execute("INSERT INTO book_fts(book_fts) VALUES('rebuild')");
      db.execute("INSERT INTO floor_fts(floor_fts) VALUES('rebuild')");
    }
    db.execute('PRAGMA user_version=1');
  } finally {
    db.close();
  }
}

/// 打 deflate zip + 写随包 manifest.json（生产同款结构）。返回 zip sha256。
/// features 块同时进 zip 内嵌 manifest 与随包 sidecar（sidecar 由 `...embedded` 展开）。
String _writeSeedPack(
  Directory dir, {
  required String zipName,
  required int packVersion,
  required int entryCount,
  required int groupCount,
  bool ftsPrebuilt = false,
  bool kindColumns = false,
  bool preDeduped = false,
  int? preClassifiedV3,
  String? dbSha256Override,
  Map<String, Object?>? fullPack,
  void Function(String dbPath)? seedDbCustomizer,
}) {
  dir.createSync(recursive: true);
  final String dbPath = p.join(dir.path, '_seed_build.db');
  _writeSeedDb(
    dbPath,
    entryMax: entryCount,
    groupCount: groupCount,
    groupIdBase: 0,
    kindColumns: kindColumns,
    ftsPrebuilt: ftsPrebuilt,
  );
  seedDbCustomizer?.call(dbPath);
  final File dbFile = File(dbPath);
  final String dbSha = dbSha256Override ?? sha256.convert(dbFile.readAsBytesSync()).toString();
  final Map<String, Object?> embedded = <String, Object?>{
    'pack_name': ftsPrebuilt ? 'seed_pack_test_full' : 'seed_pack_lite_test',
    'pack_version': packVersion,
    'tier': ftsPrebuilt ? 'full' : 'lite',
    'schema_version': 1,
    'min_app_version': '1.0.0',
    'built_at': '2026-10-13T00:00:00+08:00',
    'builder': 'seed_import_test fixture',
    'db_file': 'seed.db',
    'db_size_bytes': dbFile.lengthSync(),
    'db_sha256': dbSha,
    'features': <String, Object?>{
      'fts_prebuilt': ftsPrebuilt,
      'comment_max_chars': ftsPrebuilt ? null : 300,
      // 清洗固化标记（发行包 app/assets/seed/manifest.json 同款口径）：
      // 有则导入侧按包落维护闸门；无则一个闸门都不写（老包 / 未清洗档行为）。
      if (preDeduped) 'pre_deduped': true,
      'pre_classified_v3': ?preClassifiedV3,
    },
    'rows': <String, int>{
      'posts': _postCount, 'floors': _floorCount, 'images': _imageCount,
      'book_entries': entryCount, 'book_groups': groupCount,
    },
  };
  final String zipPath = p.join(dir.path, zipName);
  final File manifestTmp = File(p.join(dir.path, '_manifest_tmp.json'))
    ..writeAsStringSync(jsonEncode(embedded));
  final ZipFileEncoder encoder = ZipFileEncoder();
  encoder.create(zipPath, level: 6);
  encoder.addFileSync(dbFile, 'seed.db');
  encoder.addFileSync(manifestTmp, 'manifest.json');
  encoder.closeSync();
  manifestTmp.deleteSync();
  dbFile.deleteSync();
  final String zipSha = sha256.convert(File(zipPath).readAsBytesSync()).toString();
  final Map<String, Object?> sidecar = <String, Object?>{
    ...embedded,
    'compression': <String, Object?>{
      'method': 'deflate', 'zip_file': zipName,
      'zip_size_bytes': File(zipPath).lengthSync(), 'zip_sha256': zipSha,
    },
    'full_pack': ?fullPack,
  };
  File(p.join(dir.path, 'manifest.json')).writeAsStringSync(jsonEncode(sidecar));
  return zipSha;
}

/// 目录 fake AssetBundle：key 尾段 → 目录下同名文件；缺文件抛 FlutterError（同 rootBundle 行为）。
class _DirAssetBundle extends CachingAssetBundle {
  _DirAssetBundle(this.dir);

  final Directory dir;

  @override
  Future<ByteData> load(String key) async {
    final File f = File(p.join(dir.path, key.split('/').last));
    if (!f.existsSync()) {
      throw FlutterError('Unable to load asset: $key');
    }
    final Uint8List bytes = await f.readAsBytes();
    return ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
  }
}

// ─────────────────────────── 测试脚手架 ───────────────────────────

final List<AppDatabase> _openDbs = <AppDatabase>[];

/// 新开独立 app.db（文件库，主 isolate NativeDatabase；FTS 重建 isolate 另开第二连接）。
(AppDatabase, DefaultSeedImporter) _newEnv(Directory assets, Directory envDir) {
  envDir.createSync(recursive: true);
  final String dbPath = p.join(envDir.path, 'app.sqlite');
  final AppDatabase db = AppDatabase(NativeDatabase(File(dbPath)));
  _openDbs.add(db);
  final DefaultSeedImporter importer = DefaultSeedImporter(
    db,
    assetBundle: _DirAssetBundle(assets),
    workDirProvider: () async => Directory(p.join(envDir.path, 'tmp'))..createSync(recursive: true),
    databasePathProvider: () async => dbPath,
  );
  return (db, importer);
}

Future<int> _count(AppDatabase db, String sqlText) async =>
    (await db.customSelect(sqlText).getSingle()).read<int>('n');

Future<String?> _setting(AppDatabase db, String key) async {
  final row = await (db.select(db.settings)..where((t) => t.key.equals(key))).getSingleOrNull();
  return row?.value;
}

void _deleteTreeQuietly(Directory dir) {
  for (var attempt = 0; attempt < 5; attempt++) {
    try {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
      return;
    } catch (_) {
      sleep(const Duration(milliseconds: 200)); // Windows：等重建 isolate 释放 -wal 句柄
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 每测试独立文件库 + FTS 重建 isolate 二开同库 → 多 AppDatabase 实例是预期行为。
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUpAll(() {
    _root = Directory.systemTemp.createTempSync('seed_import_test');
    // ① full 档（预建 FTS）→ 其 zip sha 进 lite v1 随包 manifest 的 full_pack 块
    final Directory fullDir = Directory(p.join(_root.path, 'full_pack'))..createSync(recursive: true);
    _writeSeedPack(fullDir,
        zipName: 'seed_pack_v1.zip', packVersion: 1,
        entryCount: _entryCountV1, groupCount: _groupCountV1, ftsPrebuilt: true);
    _fullZipPath = p.join(fullDir.path, 'seed_pack_v1.zip');
    final String fullZipSha = sha256.convert(File(_fullZipPath).readAsBytesSync()).toString();
    // ② lite v1（无 FTS）
    _bundleV1 = Directory(p.join(_root.path, 'bundle_v1'));
    _writeSeedPack(_bundleV1,
        zipName: 'seed_pack_lite_v1.zip', packVersion: 1, // 老包起点，升级用例随后安装 v2
        entryCount: _entryCountV1, groupCount: _groupCountV1,
        fullPack: <String, Object?>{
          'pack_version': 1, 'zip_file': 'seed_pack_v1.zip',
          'zip_size_bytes': File(_fullZipPath).lengthSync(), 'zip_sha256': fullZipSha,
        });
    // ③ lite v2（升级包）：改标题 / 加帖 id20 / 条目 1..23999+24050 / 组 id 11..14(删 g5) / 带分类列
    _bundleV2 = Directory(p.join(_root.path, 'bundle_v2'));
    _writeSeedPack(
      _bundleV2,
      zipName: 'seed_pack_lite_v1.zip', // asset key 固定，版本差异在 manifest.pack_version
      packVersion: 3, // v2 已成为当前发行包，升级测试目标顺延一版
      entryCount: _entryCountV1 - 1,
      groupCount: 4,
      kindColumns: true,
      seedDbCustomizer: (String dbPath) {
        final sql.Database db = sql.sqlite3.open(dbPath);
        try {
          db.execute('ALTER TABLE book_groups RENAME TO book_groups_old');
          db.execute('''CREATE TABLE book_groups (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name_norm TEXT NOT NULL UNIQUE,
            author_eff_norm TEXT NOT NULL DEFAULT '',
            name_display TEXT, author_display TEXT,
            entry_total INTEGER NOT NULL DEFAULT 0, distinct_comment INTEGER NOT NULL DEFAULT 0,
            channels TEXT, date_min TEXT, date_max TEXT, word_count_max INTEGER)''');
          db.execute('''INSERT INTO book_groups(id,name_norm,name_display,entry_total,channels)
            SELECT id+10,name_norm,name_display,entry_total,channels FROM book_groups_old''');
          db.execute('DROP TABLE book_groups_old');
          db.execute('UPDATE book_entries SET book_group_id = book_group_id + 10');
          db.execute("UPDATE posts SET title='v2标题一', post_kind='排雷', recommend_flag=-1 WHERE id=1");
          db.execute("INSERT INTO posts(id,tid,title,author,date,channel,post_type,post_kind,"
              "recommend_flag,floor_count,origin,src_origin,src_origin_id) "
              "VALUES(20,100020,'v2新帖','新作者','2025-01-01','yy小说吧','扫书','扫书',1,0,'seed','saoshu',20)");
          db.execute("INSERT INTO book_entries(id,name,name_norm,author,recommender,comment,"
              "content_hash,channel,category,post_ref,floor_ref,book_group_id,origin,"
              "comment_norm_hash,date,word_count,quality,src_origin,src_origin_table,src_origin_id) "
              "VALUES(24050,'新书名v2','新书名v2','新作者','新吧友','v2新条目推荐语','h24050','yy小说吧',"
              "'扫书',1,1,11,'seed','cnh24050','2025-01-02',1234,2,'saoshu','book',24050)");
        } finally {
          db.close();
        }
      },
    );
    // ④ 损坏 zip：v1 包中段字节翻转（zip sha 必不符）
    _bundleBadZip = Directory(p.join(_root.path, 'bundle_bad_zip'))..createSync(recursive: true);
    File(p.join(_bundleV1.path, 'manifest.json'))
        .copySync(p.join(_bundleBadZip.path, 'manifest.json'));
    final Uint8List bad = File(p.join(_bundleV1.path, 'seed_pack_lite_v1.zip')).readAsBytesSync();
    bad[bad.length ~/ 2] ^= 0xff;
    File(p.join(_bundleBadZip.path, 'seed_pack_lite_v1.zip')).writeAsBytesSync(bad);
    // ⑤ db sha 不符：迷你包（100 行足够），内嵌 manifest db_sha256 全零
    _bundleBadDbSha = Directory(p.join(_root.path, 'bundle_bad_dbsha'));
    _writeSeedPack(_bundleBadDbSha,
        zipName: 'seed_pack_lite_v1.zip', packVersion: 1,
        entryCount: 100, groupCount: 2, dbSha256Override: '0' * 64);
    // ⑥ 清洗固化档（对标 bake_clean_seed.dart 产物）：full 先建（其 sha 进 lite 的 full_pack 块），
    //    features 带 pre_deduped + pre_classified_v3 = App 当前 classifierVersion。
    final Directory fullGatedDir = Directory(p.join(_root.path, 'full_pack_gated'))..createSync(recursive: true);
    _writeSeedPack(fullGatedDir,
        zipName: 'seed_pack_v1.zip', packVersion: 1,
        entryCount: _entryCountSmall, groupCount: 2, ftsPrebuilt: true,
        preDeduped: true, preClassifiedV3: classifierVersion);
    _fullGatedZipPath = p.join(fullGatedDir.path, 'seed_pack_v1.zip');
    final String fullGatedSha = sha256.convert(File(_fullGatedZipPath).readAsBytesSync()).toString();
    _bundleGated = Directory(p.join(_root.path, 'bundle_gated'));
    _writeSeedPack(_bundleGated,
        zipName: 'seed_pack_lite_v1.zip', packVersion: 1,
        entryCount: _entryCountSmall, groupCount: 2,
        preDeduped: true, preClassifiedV3: classifierVersion,
        fullPack: <String, Object?>{
          'pack_version': 1, 'zip_file': 'seed_pack_v1.zip',
          'zip_size_bytes': File(_fullGatedZipPath).lengthSync(), 'zip_sha256': fullGatedSha,
        });
    // ⑦ 分类器版本过期的清洗包（包 2 / App 3）→ 闸门不匹配，首启仍须重跑回填
    _bundleStale = Directory(p.join(_root.path, 'bundle_stale_classifier'));
    _writeSeedPack(_bundleStale,
        zipName: 'seed_pack_lite_v1.zip', packVersion: 1,
        entryCount: _entryCountSmall, groupCount: 2,
        preDeduped: true, preClassifiedV3: classifierVersion - 1);
  });

  tearDownAll(() async {
    for (final AppDatabase db in _openDbs) {
      try {
        await db.close();
      } catch (_) {}
    }
    _deleteTreeQuietly(_root);
  });

  test('闸门：无种子包时 readManifest 为 null，不打扰启动', () async {
    final Directory env = Directory(p.join(_root.path, 't0'))..createSync(recursive: true);
    final Directory emptyAssets = Directory(p.join(env.path, 'assets'))..createSync(recursive: true);
    final (AppDatabase db, DefaultSeedImporter importer) = _newEnv(emptyAssets, env);
    expect(await importer.readManifest(), isNull);
    expect(await importer.needsBasicImport(), isFalse);
    expect(await importer.needsFullImport(), isFalse);
    final List<SeedImportState> states = await importer.importBasic().toList();
    expect(states.single.phase, SeedImportPhase.error);
    expect(states.single.message, contains('未找到内置种子包'));
  });

  test('首启导入：闸门→流式校验解压→ATTACH 单事务拷贝→闸门落账', () async {
    final Directory env = Directory(p.join(_root.path, 't1'))..createSync(recursive: true);
    final (AppDatabase db, DefaultSeedImporter importer) = _newEnv(_bundleV1, env);
    expect(await importer.needsBasicImport(), isTrue);
    expect(await importer.readSeedVersion(), isNull);

    final List<SeedImportState> states = await importer.importBasic().toList();
    expect(states.last.phase, SeedImportPhase.done);
    expect(states.last.progress, 1);
    expect(states.first.phase, SeedImportPhase.extracting);
    expect(states.indexWhere((s) => s.phase == SeedImportPhase.importing) >
        states.indexWhere((s) => s.phase == SeedImportPhase.extracting), isTrue);

    // 行数与 manifest 对账
    expect(await _count(db, 'SELECT COUNT(*) AS n FROM posts'), _postCount);
    expect(await _count(db, 'SELECT COUNT(*) AS n FROM floors'), _floorCount);
    expect(await _count(db, 'SELECT COUNT(*) AS n FROM images'), _imageCount);
    expect(await _count(db, 'SELECT COUNT(*) AS n FROM book_entries'), _entryCountV1);
    expect(await _count(db, 'SELECT COUNT(*) AS n FROM book_groups'), _groupCountV1);
    // origin 纯度：全部 'seed'
    expect(await _count(db, "SELECT COUNT(*) AS n FROM posts WHERE origin <> 'seed'"), 0);
    expect(await _count(db, "SELECT COUNT(*) AS n FROM book_entries WHERE origin <> 'seed'"), 0);
    // 分类派生：seed.db 无 post_kind/recommend_flag → post_kind=post_type、扫书→+1/求书→0
    final QueryRow post1 = await db.customSelect('SELECT post_kind,recommend_flag FROM posts WHERE id=1').getSingle();
    expect(post1.read<String>('post_kind'), '扫书');
    expect(post1.read<int>('recommend_flag'), 1);
    final QueryRow post10 = await db.customSelect('SELECT post_kind,recommend_flag FROM posts WHERE id=10').getSingle();
    expect(post10.read<String>('post_kind'), '求书');
    expect(post10.read<int>('recommend_flag'), 0);
    // 内容抽查 + 闸门
    expect(await _count(db, "SELECT COUNT(*) AS n FROM floors WHERE text LIKE '%紫气东来%'"), 1);
    expect(await _setting(db, 'seed_version'), '1');
    expect(await importer.needsBasicImport(), isFalse);
    expect(await importer.needsFullImport(), isTrue); // full_pack v1 清单在、seed_full_version 缺
    // lite 档：FTS 尚未建（后台重建前 MATCH 无结果），fts_rebuild_done 未落
    expect(await _count(db, "SELECT COUNT(*) AS n FROM book_fts WHERE book_fts MATCH '书名100'"), 0);
    expect(await _setting(db, DefaultSeedImporter.ftsRebuildDoneKey), isNull);
    // 用户表零触碰
    expect(await _count(db, 'SELECT COUNT(*) AS n FROM bookmarks'), 0);
    expect(await _count(db, 'SELECT COUNT(*) AS n FROM favorites'), 0);
    // 重入卫生：临时目录已清
    expect(Directory(p.join(env.path, 'tmp', 'seed_import_basic')).existsSync(), isFalse);
  });

  test('重复导入幂等：中断重跑不产生重复行', () async {
    final Directory env = Directory(p.join(_root.path, 't2'))..createSync(recursive: true);
    final (AppDatabase db, DefaultSeedImporter importer) = _newEnv(_bundleV1, env);
    expect((await importer.importBasic().toList()).last.phase, SeedImportPhase.done);
    // 模拟「中断后重跑」：闸门已最新仍强制重导（控制器之外的直调路径）
    expect((await importer.importBasic().toList()).last.phase, SeedImportPhase.done);
    expect(await _count(db, 'SELECT COUNT(*) AS n FROM book_entries'), _entryCountV1);
    expect(await _count(db, 'SELECT COUNT(DISTINCT content_hash) AS n FROM book_entries'), _entryCountV1);
    expect(await _count(db, 'SELECT COUNT(*) AS n FROM posts'), _postCount);
    expect(await _count(db, 'SELECT COUNT(*) AS n FROM floors'), _floorCount);
    expect(await _count(db, 'SELECT COUNT(*) AS n FROM book_groups'), _groupCountV1);
    expect(await _setting(db, 'seed_version'), '1');
  });

  test('升级重写：seed 行全量重写，用户行零损伤，组按 name_norm 重挂，分类列直迁', () async {
    final Directory env = Directory(p.join(_root.path, 't3'))..createSync(recursive: true);
    final (AppDatabase db, DefaultSeedImporter importer) = _newEnv(_bundleV1, env);
    expect((await importer.importBasic().toList()).last.phase, SeedImportPhase.done);

    // ── 用户数据（origin=poc/live，M0 采集口径）──
    final int userPostId = await db.into(db.posts).insert(PostsCompanion.insert(
      channel: '用户吧',
      tid: const Value(777001),
      title: const Value('用户自采帖'),
      origin: const Value('poc'),
    ));
    await db.into(db.floors).insert(FloorsCompanion.insert(
      postId: userPostId, seq: 1, content: const Value('用户楼层内容'),
    ));
    final int userEntryId = await db.into(db.bookEntries).insert(BookEntriesCompanion.insert(
      name: '用户书', nameNorm: '用户书', contentHash: 'user_h1', channel: '用户吧',
      origin: const Value('live'), bookGroupId: const Value(3), // v1 组 g3 (id=3)
    ));
    await db.into(db.bookmarks).insert(BookmarksCompanion.insert(
      title: '用户书签', postRef: Value(userPostId), createdAt: DateTime(2026, 10, 13),
    ));
    await db.into(db.favorites).insert(FavoritesCompanion.insert(
      targetType: 'entry', targetId: userEntryId, title: '用户书', addedAt: DateTime(2026, 10, 13),
    ));
    await db.customStatement("INSERT INTO settings(key,value) VALUES('theme','dark')");

    // ── 升级 v2 ──
    final DefaultSeedImporter importerV2 = DefaultSeedImporter(
      db,
      assetBundle: _DirAssetBundle(_bundleV2),
      workDirProvider: () async => Directory(p.join(env.path, 'tmp'))..createSync(recursive: true),
      databasePathProvider: () async => p.join(env.path, 'app.sqlite'),
    );
    expect(await importerV2.readManifest() != null, isTrue);
    expect((await importerV2.readManifest())!.version, 3);
    expect(await importerV2.needsBasicImport(), isTrue);
    final List<SeedImportState> states = await importerV2.importBasic().toList();
    expect(states.last.phase, SeedImportPhase.done, reason: states.last.message);
    expect(await _setting(db, 'seed_version'), '3');

    // seed 行全量重写为升级包内容
    final QueryRow v2Post1 = await db.customSelect(
      'SELECT title,post_kind,recommend_flag FROM posts WHERE id=1').getSingle();
    expect(v2Post1.read<String>('title'), 'v2标题一');
    // v2 包带 post_kind/recommend_flag 列 → 直迁（排雷/-1），不走 post_type 派生
    expect(v2Post1.read<String>('post_kind'), '排雷');
    expect(v2Post1.read<int>('recommend_flag'), -1);
    expect(await _count(db, 'SELECT COUNT(*) AS n FROM posts WHERE id=20'), 1); // v2 加行
    expect(await _count(db, "SELECT COUNT(*) AS n FROM book_entries WHERE content_hash='h24000'"), 0); // v1 删行
    expect(await _count(db, "SELECT COUNT(*) AS n FROM book_entries WHERE content_hash='h24050'"), 1); // v2 新行
    expect(await _count(db, "SELECT COUNT(*) AS n FROM book_entries WHERE origin='seed'"), _entryCountV1);
    expect(await _count(db, 'SELECT COUNT(*) AS n FROM book_groups'), 4); // g5 已删
    expect(await _count(db, 'SELECT COUNT(*) AS n FROM book_groups WHERE id BETWEEN 11 AND 14'), 4);

    // 用户行零损伤
    expect(await _count(db, "SELECT COUNT(*) AS n FROM posts WHERE origin='poc' AND id=$userPostId"), 1);
    expect(await _count(db, "SELECT COUNT(*) AS n FROM floors WHERE post_id=$userPostId AND text='用户楼层内容'"), 1);
    expect(await _count(db, "SELECT COUNT(*) AS n FROM book_entries WHERE id=$userEntryId AND origin='live'"), 1);
    expect(await _count(db, 'SELECT COUNT(*) AS n FROM bookmarks'), 1);
    expect(await _count(db, 'SELECT COUNT(*) AS n FROM favorites'), 1);
    expect(await _setting(db, 'theme'), 'dark');
    // 用户条目按 name_norm 重挂新组（g3: id 3 → 13）
    final QueryRow userEntry = await db
        .customSelect('SELECT book_group_id FROM book_entries WHERE id=$userEntryId').getSingle();
    expect(userEntry.read<int>('book_group_id'), 13);
  });

  test('SHA256 校验失败：zip 损坏拒绝导入且无残留', () async {
    final Directory env = Directory(p.join(_root.path, 't4'))..createSync(recursive: true);
    final (AppDatabase db, DefaultSeedImporter importer) = _newEnv(_bundleBadZip, env);
    final List<SeedImportState> states = await importer.importBasic().toList();
    expect(states.last.phase, SeedImportPhase.error);
    expect(states.last.message, contains('SHA256'));
    expect(await _count(db, 'SELECT COUNT(*) AS n FROM posts'), 0);
    expect(await _count(db, 'SELECT COUNT(*) AS n FROM book_entries'), 0);
    expect(await _setting(db, 'seed_version'), isNull);
    expect(await importer.needsBasicImport(), isTrue); // 闸门未落，可重试
    expect(Directory(p.join(env.path, 'tmp', 'seed_import_basic')).existsSync(), isFalse);
  });

  test('SHA256 校验失败：seed.db 摘要不符拒绝导入', () async {
    final Directory env = Directory(p.join(_root.path, 't5'))..createSync(recursive: true);
    final (AppDatabase db, DefaultSeedImporter importer) = _newEnv(_bundleBadDbSha, env);
    final List<SeedImportState> states = await importer.importBasic().toList();
    expect(states.last.phase, SeedImportPhase.error);
    expect(states.last.message, contains('seed.db SHA256'));
    expect(await _count(db, 'SELECT COUNT(*) AS n FROM book_entries'), 0);
    expect(await _setting(db, 'seed_version'), isNull);
  });

  test('FTS 后台重建：进度流每 2000 行 yield，MATCH 可查，触发器恢复', () async {
    final Directory env = Directory(p.join(_root.path, 't6'))..createSync(recursive: true);
    final (AppDatabase db, DefaultSeedImporter importer) = _newEnv(_bundleV1, env);
    expect((await importer.importBasic().toList()).last.phase, SeedImportPhase.done);

    final List<SeedImportState> states = await importer.rebuildFts().toList();
    final List<SeedImportState> progress =
        states.where((s) => s.phase == SeedImportPhase.rebuildingFts).toList();
    // 24000 条目 → ≥12 批 book_fts + 1 批 floor_fts，每批 yield 一次
    expect(progress.length, greaterThanOrEqualTo(12));
    expect(progress.first.progress, greaterThan(0));
    expect(progress.last.progress, lessThanOrEqualTo(1));
    expect(states.last.phase, SeedImportPhase.done, reason: states.last.message);
    expect(states.last.message, contains('重建完成'));
    expect(await _setting(db, DefaultSeedImporter.ftsRebuildDoneKey), '1');

    // MATCH 可查（trigram ≥3 字）
    expect(await _count(db, "SELECT COUNT(*) AS n FROM book_fts WHERE book_fts MATCH '独特书名剑来'"), 1);
    expect(await _count(db, "SELECT COUNT(*) AS n FROM book_fts WHERE book_fts MATCH '赛博剑仙测试'"),
        _entryCountV1 ~/ 100);
    expect(await _count(db, "SELECT COUNT(*) AS n FROM floor_fts WHERE floor_fts MATCH '紫气东来测试楼层'"), 1);
    // 触发器已恢复：重建后新插入行立即可 MATCH
    await db.into(db.bookEntries).insert(BookEntriesCompanion.insert(
      name: '即时触发器书', nameNorm: '即时触发器书', contentHash: 'trig_h1', channel: '用户吧',
      origin: const Value('poc'),
    ));
    expect(await _count(db, "SELECT COUNT(*) AS n FROM book_fts WHERE book_fts MATCH '即时触发器书'"), 1);
  });

  test('FTS 重建可取消：中断后部分态，重跑幂等补全', () async {
    final Directory env = Directory(p.join(_root.path, 't7'))..createSync(recursive: true);
    final (AppDatabase db, DefaultSeedImporter importer) = _newEnv(_bundleV1, env);
    expect((await importer.importBasic().toList()).last.phase, SeedImportPhase.done);

    final List<SeedImportState> states = <SeedImportState>[];
    var cancelSent = false;
    await for (final SeedImportState s in importer.rebuildFts()) {
      states.add(s);
      if (!cancelSent && s.phase == SeedImportPhase.rebuildingFts) {
        cancelSent = true;
        importer.cancelFtsRebuild(); // 首批进度后即取消（批间检查）
      }
    }
    expect(cancelSent, isTrue);
    expect(states.last.phase, SeedImportPhase.error, reason: states.last.message);
    expect(states.last.message, contains('已取消'));
    expect(await _setting(db, DefaultSeedImporter.ftsRebuildDoneKey), isNull);
    // 部分态：只有前几批入了索引（docsize 每索引行一条），尾部行未入
    final int indexed = await _count(db, 'SELECT COUNT(*) AS n FROM book_fts_docsize');
    expect(indexed, greaterThan(0));
    expect(indexed, lessThan(_entryCountV1));
    expect(await _count(db, "SELECT COUNT(*) AS n FROM book_fts WHERE book_fts MATCH '书名23999'"), 0);

    // 重跑：delete-all 起点 → 幂等补全（无重复索引：独特 token 恰 1 命中）
    final List<SeedImportState> states2 = await importer.rebuildFts().toList();
    expect(states2.last.phase, SeedImportPhase.done);
    expect(await _count(db, "SELECT COUNT(*) AS n FROM book_fts WHERE book_fts MATCH '书名23999'"), 1);
    expect(await _count(db, "SELECT COUNT(*) AS n FROM book_fts WHERE book_fts MATCH '独特书名剑来'"), 1);
    expect(await _count(db, 'SELECT COUNT(*) AS n FROM book_fts_docsize'), _entryCountV1);
    expect(await _setting(db, DefaultSeedImporter.ftsRebuildDoneKey), '1');
  });

  test('importFull：预建 FTS 影子表复制，跳过重建，双闸门落账', () async {
    final Directory env = Directory(p.join(_root.path, 't8'))..createSync(recursive: true);
    final (AppDatabase db, DefaultSeedImporter importer) = _newEnv(_bundleV1, env);
    expect(await importer.needsFullImport(), isTrue);

    final List<SeedImportState> states = await importer.importFull(_fullZipPath).toList();
    expect(states.last.phase, SeedImportPhase.done, reason: states.last.message);
    expect(states.last.message, contains('跳过重建'));
    expect(states.any((s) => s.phase == SeedImportPhase.rebuildingFts), isFalse);

    // 预建索引直接可查（未跑 rebuildFts）
    expect(await _count(db, "SELECT COUNT(*) AS n FROM book_fts WHERE book_fts MATCH '独特书名剑来'"), 1);
    expect(await _count(db, "SELECT COUNT(*) AS n FROM floor_fts WHERE floor_fts MATCH '紫气东来测试楼层'"), 1);
    // 双闸门 + FTS 就绪标记
    expect(await _setting(db, 'seed_full_version'), '1');
    expect(await _setting(db, 'seed_version'), '1');
    expect(await _setting(db, DefaultSeedImporter.ftsRebuildDoneKey), '1');
    expect(await importer.needsFullImport(), isFalse);
    expect(await importer.needsBasicImport(), isFalse);
    expect(await _count(db, 'SELECT COUNT(*) AS n FROM book_entries'), _entryCountV1);

    // 完整包不存在 → 明确报错
    final List<SeedImportState> miss = await importer.importFull(p.join(env.path, '不存在.zip')).toList();
    expect(miss.single.phase, SeedImportPhase.error);
  });

  // ── 维护闸门随包走（manifest.features.pre_deduped / pre_classified_v3）──
  // 未覆盖「闸门与内容拷贝同事务」的原子性：闸门写入是 _copyInTransaction 第 5 步，其后只剩
  // DELETE settings / DROP TEMP TABLE / COUNT 对账三类不可能失败的语句，而拷贝段（第 3 步）
  // 能造的失败都发生在闸门之前 —— fixture 层任何可造的中断点都只能证明「内容回滚」，
  // 证明不了「闸门与内容同生共死」。要造得在 drift 之外包一层「第 N 条语句抛错」的
  // QueryExecutor，超出本次范围；原子性由代码结构保证（同一个 `_db.transaction`）。

  test('闸门随包走：清洗包导入即落维护闸门，首启维护跳过', () async {
    final Directory env = Directory(p.join(_root.path, 't10'))..createSync(recursive: true);
    final (AppDatabase db, DefaultSeedImporter importer) = _newEnv(_bundleGated, env);
    final SeedManifest m = (await importer.readManifest())!;
    expect(m.preDeduped, isTrue);
    expect(m.preClassifiedVersion, classifierVersion);

    expect((await importer.importBasic().toList()).last.phase, SeedImportPhase.done);

    // 闸门值取自包声明（非 App 常量写死）→ needsXxx 双双 false，首启维护整段跳过
    expect(await _setting(db, 'dedup_version'), dedupDoneValue);
    expect(await _setting(db, 'classifier_version'), '$classifierVersion');
    expect(await needsDedup(db), isFalse);
    expect(await needsReclassify(db), isFalse);
    // 闸门只影响维护，不影响导入本体
    expect(await _count(db, 'SELECT COUNT(*) AS n FROM book_entries'), _entryCountSmall);
    expect(await _setting(db, 'seed_version'), '1');
  });

  test('老包不退化：manifest 无清洗标记 → 两个维护闸门都不写，维护照跑', () async {
    final Directory env = Directory(p.join(_root.path, 't11'))..createSync(recursive: true);
    final (AppDatabase db, DefaultSeedImporter importer) = _newEnv(_bundleV1, env);
    final SeedManifest m = (await importer.readManifest())!;
    expect(m.preDeduped, isFalse);
    expect(m.preClassifiedVersion, isNull);

    expect((await importer.importBasic().toList()).last.phase, SeedImportPhase.done);

    expect(await _setting(db, 'dedup_version'), isNull);
    expect(await _setting(db, 'classifier_version'), isNull);
    expect(await needsDedup(db), isTrue);
    expect(await needsReclassify(db), isTrue);
    expect(await _setting(db, 'seed_version'), '1'); // 版本闸门不受影响
  });

  test('包声明过期分类器版本：闸门不匹配 → 仍会重跑回填（dedup 闸门照落）', () async {
    final Directory env = Directory(p.join(_root.path, 't12'))..createSync(recursive: true);
    final (AppDatabase db, DefaultSeedImporter importer) = _newEnv(_bundleStale, env);
    expect((await importer.importBasic().toList()).last.phase, SeedImportPhase.done);

    expect(await _setting(db, 'classifier_version'), '${classifierVersion - 1}');
    expect(await needsReclassify(db), isTrue, reason: '包版本落后 App classifierVersion → 首启自动重跑并落新版本');
    expect(await _setting(db, 'dedup_version'), dedupDoneValue);
    expect(await needsDedup(db), isFalse);
  });

  test('importFull 同走 _copyInTransaction：full 档清洗包也落维护闸门', () async {
    final Directory env = Directory(p.join(_root.path, 't13'))..createSync(recursive: true);
    final (AppDatabase db, DefaultSeedImporter importer) = _newEnv(_bundleGated, env);
    final List<SeedImportState> states = await importer.importFull(_fullGatedZipPath).toList();
    expect(states.last.phase, SeedImportPhase.done, reason: states.last.message);

    // full 档以 zip 内嵌 manifest 为权威 → 同一份 features 标记同样落闸门
    expect(await _setting(db, 'dedup_version'), dedupDoneValue);
    expect(await _setting(db, 'classifier_version'), '$classifierVersion');
    expect(await needsDedup(db), isFalse);
    expect(await needsReclassify(db), isFalse);
    expect(await _setting(db, 'seed_version'), '1');
    expect(await _setting(db, 'seed_full_version'), '1');
    expect(await _setting(db, DefaultSeedImporter.ftsRebuildDoneKey), '1'); // 预建影子表复制成功
  });

  test('真实 lite asset 包：manifest 解析 + zip SHA256 流式校验', () async {
    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    _openDbs.add(db);
    final DefaultSeedImporter importer = DefaultSeedImporter(db); // rootBundle + 默认 asset key
    final SeedManifest? m = await importer.readManifest();
    expect(m, isNotNull);
    expect(m!.version, 3);
    expect(m.tier, 'lite');
    expect(m.ftsPrebuilt, isFalse);
    // 2026-10-14 清洗固化（app/tool/bake_clean_seed.dart）：包内库经 drift 迁移到当期
    // schemaVersion（v4 = 补齐查询索引），posts 带 post_kind/recommend_flag
    // → 导入侧 `_seedPostsHasKindColumns()` 走直迁分支。
    expect(m.schemaVersion, 4);
    // 行数随种子包更新，不在此处固定历史快照；下方导入与 BENCH 用例以 manifest 逐项对账。
    expect(m.rows['posts'], greaterThan(0));
    expect(m.rows['book_entries'], greaterThan(0));
    expect(m.dbSha256, isNotNull);
    expect(m.zipSha256, isNotNull);
    expect(m.fullVersion, 3); // full_pack 下载清单块
    expect(m.sha256, isNotNull);
    expect(m.version, 3); // 数据增量随包升级时要触发已安装用户的重新导入
    // 流式校验 asset zip（落盘后 64KB 分块 sha256）
    final Directory tmp = Directory(p.join(_root.path, 't9'))..createSync(recursive: true);
    final ByteData zip = await rootBundle.load(DefaultSeedImporter.defaultSeedZipAssetKey);
    final String zipPath = p.join(tmp.path, 'seed_pack_lite_v1.zip');
    await File(zipPath).writeAsBytes(
        zip.buffer.asUint8List(zip.offsetInBytes, zip.lengthInBytes), flush: true);
    expect(await importer.verifyZipSha256(zipPath, m.zipSha256!), isTrue);
    expect(await importer.verifyZipSha256(zipPath, 'f' * 64), isFalse);
  }, timeout: const Timeout(Duration(minutes: 5)));

  // ── 真实包桌面实测（任务要求 8）。运行（pwsh）：
  //    $env:BENCH='true'; flutter test test/seed_import_test.dart --plain-name BENCH
  //    结果回填至文件头注释。
  test(
    'BENCH：真实 lite 包桌面实测（导入 + FTS 重建）',
    skip: Platform.environment['BENCH'] == 'true'
        ? false
        : r'需 $env:BENCH=true（真实 60MB asset 包，分钟级）',
    () async {
      final Directory env = Directory.systemTemp.createTempSync('seed_bench');
      try {
        final String dbPath = p.join(env.path, 'app.sqlite');
        final AppDatabase db = AppDatabase(NativeDatabase(File(dbPath)));
        final DefaultSeedImporter importer = DefaultSeedImporter(
          db,
          workDirProvider: () async => Directory(p.join(env.path, 'tmp'))..createSync(recursive: true),
          databasePathProvider: () async => dbPath,
        );
        final SeedManifest m = (await importer.readManifest())!;
        final Stopwatch sw = Stopwatch()..start();
        var importSeconds = -1.0;
        final Stopwatch phase = Stopwatch()..start();
        await for (final SeedImportState s in importer.importBasic()) {
          if (s.phase == SeedImportPhase.importing && phase.isRunning) {
            phase.stop();
          }
          if (s.phase == SeedImportPhase.done) {
            importSeconds = sw.elapsedMilliseconds / 1000;
          }
          // ignore: avoid_print
          print('[BENCH] import ${s.phase.name} ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s '
              '${(s.progress * 100).toStringAsFixed(0)}% ${s.message}');
        }
        phase.stop();
        expect(importSeconds, greaterThan(0));
        expect(await _setting(db, 'seed_version'), '${m.version}');
        expect(await _count(db, 'SELECT COUNT(*) AS n FROM posts'), m.rows['posts']);
        expect(await _count(db, 'SELECT COUNT(*) AS n FROM book_entries'), m.rows['book_entries']);

        // 闸门随包走：清洗标记在导入事务内落账 → 生产路径首启维护直接跳过（下面那段「白扫」
        // 是本 BENCH 特意强制直调的 no-op 验收，不是生产行为）。
        expect(m.preDeduped, isTrue);
        expect(m.preClassifiedVersion, classifierVersion);
        expect(await _setting(db, 'dedup_version'), dedupDoneValue);
        expect(await _setting(db, 'classifier_version'), '$classifierVersion');
        expect(await needsDedup(db), isFalse);
        expect(await needsReclassify(db), isFalse);

        sw.reset();
        var rebuildSeconds = -1.0;
        var progressEvents = 0;
        await for (final SeedImportState s in importer.rebuildFts()) {
          if (s.phase == SeedImportPhase.rebuildingFts) {
            progressEvents++;
          }
          if (s.phase == SeedImportPhase.done) {
            rebuildSeconds = sw.elapsedMilliseconds / 1000;
          }
        }
        expect(rebuildSeconds, greaterThan(0));
        expect(progressEvents, greaterThan(50));
        expect(await _setting(db, DefaultSeedImporter.ftsRebuildDoneKey), '1');
        final QueryRow hit = await db
            .customSelect("SELECT COUNT(*) AS n FROM book_fts WHERE book_fts MATCH '世子很凶'")
            .getSingle();
        expect(hit.read<int>('n'), greaterThan(0));

        // ── 清洗固化验收（2026-10-14）──
        // 发行包内已是收敛态（bake_clean_seed.dart：先裁 comment≤300 → dedup → v3 回填），
        // 故真机首启的后台维护必须是 no-op。只能在**实际发行包**上验：dedup 判据是
        // normText(comment) 前缀链（maintenance.dart `_judgeDupGroup`），与 comment 截断阈值
        // 耦合；工具内的二刷只覆盖中间库，覆盖不到「导入直迁 post_kind」这一段。
        final Stopwatch maint = Stopwatch()..start();
        final DedupStats dedup = await dedupBookEntries(db);
        final BookDict dict =
            BookDict.fromLines(await File('assets/dict/book_dict.txt').readAsLines());
        final ReclassifyStats reclass = await reclassifyPostsV3(db, dict: dict);
        expect(dedup.rowsDeleted, 0, reason: '发行包已去重，首启维护不应再删行');
        expect(reclass.postsUpdated, 0, reason: '发行包已按 v3 回填，首启维护不应再改分类');
        expect(await _setting(db, 'dedup_version'), dedupDoneValue);
        expect(await _setting(db, 'classifier_version'), '$classifierVersion');
        // 分类分布随包直迁，且与总帖数自洽；具体历史快照不在测试里写死。
        final int kindTotal = await _count(db, 'SELECT COUNT(*) AS n FROM posts');
        final int kindCounts = await _count(
          db,
          'SELECT COUNT(*) AS n FROM posts WHERE post_kind IN '
          "('扫书','排雷','求书','日常')",
        );
        expect(kindCounts, kindTotal);
        // ignore: avoid_print
        print('[BENCH] 首启维护 no-op（dedup ${dedup.rowsDeleted} 删 / reclassify '
            '${reclass.postsUpdated} 改）: ${(maint.elapsedMilliseconds / 1000).toStringAsFixed(1)}s');

        final int dbSizeKb = (File(dbPath).lengthSync() / 1024).round();
        // ignore: avoid_print
        print('[BENCH] ────────── 桌面实测汇总（Windows, flutter-test JIT）──────────');
        // ignore: avoid_print
        print('[BENCH] 解压+校验段: ${phase.elapsedMilliseconds / 1000}s');
        // ignore: avoid_print
        print('[BENCH] 导入全程(asset读取→闸门落账): ${importSeconds}s');
        // ignore: avoid_print
        print('[BENCH] FTS 重建(book+floor, $progressEvents 批): ${rebuildSeconds}s');
        // ignore: avoid_print
        print('[BENCH] 导入后 app.db: ${dbSizeKb}KB');
        await db.close();
      } finally {
        _deleteTreeQuietly(env);
      }
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
