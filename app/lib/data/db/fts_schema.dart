/// FTS5 trigram 表的 schema 单一出处（纯 Dart，无 flutter / drift 依赖）。
///
/// 使用方：
/// - `data/db/app_database.dart`：onCreate 建全量（空表无成本）；
/// - `data/fts_index.dart`：按档位重建 / 删除；
/// - `data/seed_import.dart`：导入期间摘除 / 恢复触发器。
///
/// 迁移纪律：这里的 DDL 必须与旧实现逐字一致，避免老库升级时出现同名不同构。
library;

/// 书级 FTS 虚拟表名。
const String bookFtsTable = 'book_fts';

/// 楼层正文 FTS 虚拟表名。
const String floorFtsTable = 'floor_fts';

/// book_fts 的同步触发器（内容表 = book_entries）。
const List<String> bookFtsTriggerNames = <String>[
  'book_entries_ai',
  'book_entries_ad',
  'book_entries_au',
];

/// floor_fts 的同步触发器（内容表 = floors）。
const List<String> floorFtsTriggerNames = <String>[
  'floors_ai',
  'floors_ad',
  'floors_au',
];

/// 全部 FTS 触发器（旧库 doctor / 迁移兼容口径）。
const List<String> allFtsTriggerNames = <String>[
  ...bookFtsTriggerNames,
  ...floorFtsTriggerNames,
];

/// 书级 FTS 表 + 触发器。
Future<void> createBookFts(Future<void> Function(String) exec) async {
  await exec('''
    CREATE VIRTUAL TABLE IF NOT EXISTS $bookFtsTable USING fts5(
      name, author, recommender, comment,
      content='book_entries', content_rowid='id',
      tokenize='trigram'
    )''');
  await createBookFtsTriggers(exec);
}

/// 仅建 book_fts 的同步触发器（表已存在时用）。
Future<void> createBookFtsTriggers(Future<void> Function(String) exec) async {
  await exec(
    '''CREATE TRIGGER IF NOT EXISTS book_entries_ai AFTER INSERT ON book_entries BEGIN
    INSERT INTO $bookFtsTable(rowid,name,author,recommender,comment)
    VALUES (new.id,new.name,new.author,new.recommender,new.comment); END''',
  );
  await exec(
    '''CREATE TRIGGER IF NOT EXISTS book_entries_ad AFTER DELETE ON book_entries BEGIN
    INSERT INTO $bookFtsTable($bookFtsTable,rowid,name,author,recommender,comment)
    VALUES ('delete',old.id,old.name,old.author,old.recommender,old.comment); END''',
  );
  await exec(
    '''CREATE TRIGGER IF NOT EXISTS book_entries_au AFTER UPDATE ON book_entries BEGIN
    INSERT INTO $bookFtsTable($bookFtsTable,rowid,name,author,recommender,comment)
    VALUES ('delete',old.id,old.name,old.author,old.recommender,old.comment);
    INSERT INTO $bookFtsTable(rowid,name,author,recommender,comment)
    VALUES (new.id,new.name,new.author,new.recommender,new.comment); END''',
  );
}

/// 楼层正文 FTS 表 + 触发器。
Future<void> createFloorFts(Future<void> Function(String) exec) async {
  await exec('''
    CREATE VIRTUAL TABLE IF NOT EXISTS $floorFtsTable USING fts5(
      text, content='floors', content_rowid='id', tokenize='trigram'
    )''');
  await createFloorFtsTriggers(exec);
}

/// 仅建 floor_fts 的同步触发器（表已存在时用）。
Future<void> createFloorFtsTriggers(Future<void> Function(String) exec) async {
  await exec(
    '''CREATE TRIGGER IF NOT EXISTS floors_ai AFTER INSERT ON floors BEGIN
    INSERT INTO $floorFtsTable(rowid,text) VALUES (new.id,new.text); END''',
  );
  await exec(
    '''CREATE TRIGGER IF NOT EXISTS floors_ad AFTER DELETE ON floors BEGIN
    INSERT INTO $floorFtsTable($floorFtsTable,rowid,text) VALUES ('delete',old.id,old.text); END''',
  );
  await exec(
    '''CREATE TRIGGER IF NOT EXISTS floors_au AFTER UPDATE ON floors BEGIN
    INSERT INTO $floorFtsTable($floorFtsTable,rowid,text) VALUES ('delete',old.id,old.text);
    INSERT INTO $floorFtsTable(rowid,text) VALUES (new.id,new.text); END''',
  );
}

/// 两张 FTS 表 + 全部触发器（onCreate 口径）。
Future<void> createAllFts(Future<void> Function(String) exec) async {
  await createBookFts(exec);
  await createFloorFts(exec);
}
