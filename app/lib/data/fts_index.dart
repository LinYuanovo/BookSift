/// FTS 索引档位管理（纯 Dart；不 import flutter）。
///
/// 三档：
/// - `off`  只留内容表（全部 LIKE，最省存储）；
/// - `book` 仅 `book_fts`（书名/作者/推荐人/评语）；
/// - `full` `book_fts` + `floor_fts`（现状，正文全文可命中）。
///
/// 设计要点（对应 docs/2026-10-20_FTS索引可选化改造方案.md）：
/// - DDL 单一出处 `db/fts_schema.dart`，与 `AppDatabase._createFts` 逐字一致；
/// - 切换/删除/重建都在独立 isolate 的独立连接上执行（WAL + busy_timeout），
///   批间可取消；完成后才落 `fts_mode` / `fts_built_mode`；
/// - `VACUUM` 失败不影响「表已删除」这一结果，只回报警告（不谎报已释放）。
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

import '../core/constants.dart';
import 'db/fts_schema.dart';
import 'fts_mode.dart';

export 'fts_mode.dart' show FtsMode, ftsModeFromWire;

/// 由实际能力推断已建成档位。
FtsMode ftsModeOfCapability(FtsCapability cap) {
  if (cap.bookReady && cap.floorReady) {
    return FtsMode.full;
  }
  if (cap.bookReady) {
    return FtsMode.book;
  }
  return FtsMode.off;
}

/// 实际能力探测结果（不信任 settings）。
class FtsCapability {
  const FtsCapability({
    required this.bookTable,
    required this.floorTable,
    required this.bookTriggers,
    required this.floorTriggers,
    required this.bookRows,
    required this.floorRows,
    required this.bookContentRows,
    required this.floorContentRows,
  });

  const FtsCapability.empty()
      : bookTable = false,
        floorTable = false,
        bookTriggers = false,
        floorTriggers = false,
        bookRows = 0,
        floorRows = 0,
        bookContentRows = 0,
        floorContentRows = 0;

  final bool bookTable;
  final bool floorTable;
  final bool bookTriggers;
  final bool floorTriggers;
  final int bookRows;
  final int floorRows;
  final int bookContentRows;
  final int floorContentRows;

  bool get bookReady => bookTable && bookTriggers;
  bool get floorReady => floorTable && floorTriggers;

  /// 表/触发器在、但索引行数少于内容行数 → 半态（需重建）。
  bool get bookIncomplete =>
      bookReady && bookContentRows > 0 && bookRows < bookContentRows;
  bool get floorIncomplete =>
      floorReady && floorContentRows > 0 && floorRows < floorContentRows;

  /// 当前能力对应的档位（按「可用」而非「完整」判定，避免半态被误认为 off）。
  FtsMode get mode => ftsModeOfCapability(this);

  bool get healthy => !bookIncomplete && !floorIncomplete;
}

/// 进度/结果事件。
class FtsProgress {
  const FtsProgress({
    required this.target,
    this.progress = 0,
    this.message = '',
    this.done = false,
    this.cancelled = false,
    this.warning,
  });

  final FtsMode target;
  final double progress;
  final String message;
  final bool done;
  final bool cancelled;

  /// 非致命警告（如 VACUUM 失败），完成后随 done 一起回报。
  final String? warning;
}

class FtsIndexException implements Exception {
  const FtsIndexException(this.message);

  final String message;

  @override
  String toString() => 'FtsIndexException: $message';
}

/// 索引档位服务。
abstract interface class FtsIndexService {
  /// 探测实际能力（含索引行数）。
  Future<FtsCapability> detect();

  /// 切到 [target]；[rebuild] = true 时先删后建（修复半态/手动重建）。
  Stream<FtsProgress> apply(FtsMode target, {bool rebuild = false});

  /// 删除全部索引（等价 `apply(off)`）。
  Stream<FtsProgress> drop();

  /// 请求中断进行中的任务（批间生效；已执行的 DDL 不回滚）。
  void cancel();
}

/// 默认实现：独立 isolate + 独立连接。
class DefaultFtsIndexService implements FtsIndexService {
  DefaultFtsIndexService(this.dbPath);

  final String dbPath;

  static const int batchSize = 2000;
  static const String cancelMessage = 'cancel';

  SendPort? _control;

  @override
  Future<FtsCapability> detect() async {
    if (!File(dbPath).existsSync()) {
      return const FtsCapability.empty();
    }
    Database? db;
    try {
      db = sqlite3.open(dbPath);
      // 与索引 isolate 的收尾窗口错开：done 事件发出时对方可能尚未 close。
      db.execute('PRAGMA busy_timeout=3000');
      return detectOn(db);
    } catch (_) {
      return const FtsCapability.empty();
    } finally {
      db?.close();
    }
  }

  @override
  Stream<FtsProgress> drop() => apply(FtsMode.off);

  @override
  Stream<FtsProgress> apply(FtsMode target, {bool rebuild = false}) async* {
    final ReceivePort events = ReceivePort();
    var completed = false;
    try {
      await Isolate.spawn(
        _ftsJobIsolate,
        _FtsJob(
          dbPath: dbPath,
          target: target,
          rebuild: rebuild,
          events: events.sendPort,
        ),
        onError: events.sendPort,
        onExit: events.sendPort,
      );
      await for (final Object? message in events) {
        if (message is _FtsControlMessage) {
          _control = message.port;
          continue;
        }
        if (message is FtsProgress) {
          if (message.done) {
            completed = !message.cancelled;
          }
          yield message;
          if (message.done) {
            return;
          }
          continue;
        }
        if (message == null) {
          yield FtsProgress(
            target: target,
            done: true,
            message: '索引操作 isolate 意外退出',
          );
          return;
        }
        if (message is List) {
          yield FtsProgress(
            target: target,
            done: true,
            message: '索引操作失败: ${message.isEmpty ? '未知错误' : message.first}',
          );
          return;
        }
      }
    } finally {
      if (!completed) {
        _control?.send(cancelMessage);
      }
      _control = null;
      events.close();
    }
  }

  @override
  void cancel() => _control?.send(cancelMessage);

  /// 在给定连接上探测能力（测试可直接复用）。
  static FtsCapability detectOn(Database db) {
    final Set<String> tables = db
        .select("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((Row row) => row['name'] as String)
        .toSet();
    final Set<String> triggers = db
        .select("SELECT name FROM sqlite_master WHERE type = 'trigger'")
        .map((Row row) => row['name'] as String)
        .toSet();
    final bool bookTable = tables.contains(bookFtsTable);
    final bool floorTable = tables.contains(floorFtsTable);

    int scalar(String sql) {
      final List<Row> rows = db.select(sql);
      return rows.isEmpty ? 0 : ((rows.single.values.first as num?) ?? 0).toInt();
    }

    final int bookContent =
        tables.contains('book_entries') ? scalar('SELECT COUNT(*) FROM book_entries') : 0;
    final int floorContent =
        tables.contains('floors') ? scalar('SELECT COUNT(*) FROM floors') : 0;
    return FtsCapability(
      bookTable: bookTable,
      floorTable: floorTable,
      bookTriggers: bookFtsTriggerNames.every(triggers.contains),
      floorTriggers: floorFtsTriggerNames.every(triggers.contains),
      bookRows: bookTable ? scalar('SELECT COUNT(*) FROM $bookFtsTable') : 0,
      floorRows: floorTable ? scalar('SELECT COUNT(*) FROM $floorFtsTable') : 0,
      bookContentRows: bookContent,
      floorContentRows: floorContent,
    );
  }
}

/// isolate 入参（可跨 isolate 传输）。
class _FtsJob {
  const _FtsJob({
    required this.dbPath,
    required this.target,
    required this.rebuild,
    required this.events,
  });

  final String dbPath;
  final FtsMode target;
  final bool rebuild;
  final SendPort events;
}

/// 控制端口消息：isolate → 主 isolate 回传控制 SendPort。
class _FtsControlMessage {
  const _FtsControlMessage(this.port);

  final SendPort port;
}

/// isolate 入口：SQL 同步执行，批间让出事件循环以接收取消消息。
Future<void> _ftsJobIsolate(_FtsJob job) async {
  final ReceivePort control = ReceivePort();
  var cancelled = false;
  control.listen((Object? message) {
    if (message == DefaultFtsIndexService.cancelMessage) {
      cancelled = true;
    }
  });
  job.events.send(_FtsControlMessage(control.sendPort));

  Database? db;
  try {
    db = sqlite3.open(job.dbPath);
    db.execute('PRAGMA busy_timeout=8000');
    db.execute('PRAGMA journal_mode=WAL');
    final List<Row> probe = db.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='book_entries'",
    );
    if (probe.isEmpty) {
      throw const FtsIndexException('数据库尚未初始化');
    }

    job.events.send(
      FtsProgress(target: job.target, progress: 0.02, message: '准备索引…'),
    );

    if (job.target == FtsMode.off) {
      dropFtsTables(db, book: true, floor: true);
      job.events.send(
        FtsProgress(
          target: job.target,
          progress: 0.6,
          message: '索引已删除 · 正在收缩文件…',
        ),
      );
      final String? warning = vacuum(db);
      writeFtsSettings(db, target: job.target, built: job.target);
      job.events.send(
        FtsProgress(
          target: job.target,
          progress: 1,
          done: true,
          message: warning == null ? '索引已删除' : '索引已删除（$warning）',
          warning: warning,
        ),
      );
      return;
    }

    final bool keepFloor = job.target == FtsMode.full;
    if (job.rebuild) {
      dropFtsTables(db, book: true, floor: keepFloor);
    } else if (!keepFloor) {
      dropFtsTables(db, book: false, floor: true);
    }
    // CREATE ... IF NOT EXISTS：半态（表在、触发器缺）也能一次修好。
    final Database conn = db;
    await createBookFts((String sql) async => conn.execute(sql));
    if (keepFloor) {
      await createFloorFts((String sql) async => conn.execute(sql));
    }

    final int bookContent = scalar(db, 'SELECT COUNT(*) FROM book_entries');
    final int floorContent = keepFloor ? scalar(db, 'SELECT COUNT(*) FROM floors') : 0;
    final int total = bookContent + floorContent;
    final int bookBefore = tableCount(db, bookFtsTable);
    final int floorBefore = keepFloor ? tableCount(db, floorFtsTable) : 0;

    var processed = 0;

    void emit(int done, String message) => job.events.send(
          FtsProgress(
            target: job.target,
            progress: total <= 0 ? 0.5 : 0.05 + 0.85 * (done / total),
            message: message,
          ),
        );

    if (job.rebuild || bookBefore < bookContent) {
      if (bookBefore > 0) {
        db.execute("INSERT INTO $bookFtsTable($bookFtsTable) VALUES('delete-all')");
      }
      final int done = await rebuildBook(
        db,
        isCancelled: () => cancelled,
        onProgress: (int n) => emit(processed + n, '重建 book_fts $n/$bookContent'),
      );
      if (cancelled) {
        _sendCancelled(job, '重建已取消（book_fts 不完整，可重试）');
        return;
      }
      processed += done;
    } else {
      processed += bookContent;
    }

    if (keepFloor) {
      if (job.rebuild || floorBefore < floorContent) {
        if (floorBefore > 0) {
          db.execute("INSERT INTO $floorFtsTable($floorFtsTable) VALUES('delete-all')");
        }
        final int done = await rebuildFloor(
          db,
          isCancelled: () => cancelled,
          onProgress: (int n) => emit(processed + n, '重建 floor_fts $n/$floorContent'),
        );
        if (cancelled) {
          _sendCancelled(job, '重建已取消（floor_fts 不完整，可重试）');
          return;
        }
        processed += done;
      } else {
        processed += floorContent;
      }
    }

    if (total > 0) {
      emit(total, '索引已就绪');
    }

    final String? warning = vacuum(db);
    writeFtsSettings(db, target: job.target, built: job.target);
    job.events.send(
      FtsProgress(
        target: job.target,
        progress: 1,
        done: true,
        message: doneMessage(job.target, warning),
        warning: warning,
      ),
    );
  } catch (error) {
    job.events.send(
      FtsProgress(target: job.target, progress: 0, done: true, message: '$error'),
    );
  } finally {
    db?.close();
    control.close();
  }
}

void _sendCancelled(_FtsJob job, String message) => job.events.send(
      FtsProgress(target: job.target, done: true, cancelled: true, message: message),
    );

String doneMessage(FtsMode mode, String? warning) => switch (mode) {
      FtsMode.book => warning == null ? '基础索引就绪' : '基础索引就绪（$warning）',
      FtsMode.full => warning == null ? '完整索引就绪' : '完整索引就绪（$warning）',
      FtsMode.off => '索引已删除',
    };

int scalar(Database db, String sql) {
  final List<Row> rows = db.select(sql);
  return rows.isEmpty ? 0 : ((rows.single.values.first as num?) ?? 0).toInt();
}

int tableCount(Database db, String table) => scalar(db, 'SELECT COUNT(*) FROM $table');

/// 先删触发器再删表（避免内容表写入时触发器引用已删除的虚拟表）。
void dropFtsTables(Database db, {required bool book, required bool floor}) {
  if (book) {
    for (final String name in bookFtsTriggerNames) {
      db.execute('DROP TRIGGER IF EXISTS $name');
    }
    db.execute('DROP TABLE IF EXISTS $bookFtsTable');
  }
  if (floor) {
    for (final String name in floorFtsTriggerNames) {
      db.execute('DROP TRIGGER IF EXISTS $name');
    }
    db.execute('DROP TABLE IF EXISTS $floorFtsTable');
  }
}

/// 返回 null = 成功；否则为可展示的警告文案。
String? vacuum(Database db) {
  try {
    // 先 checkpoint 把 WAL 并回主库，VACUUM 才能真正收缩文件。
    db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    db.execute('VACUUM');
    db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    return null;
  } catch (_) {
    return '文件空间未收缩（可稍后重试）';
  }
}

void writeFtsSettings(
  Database db, {
  required FtsMode target,
  required FtsMode built,
}) {
  void put(String key, String value) {
    db.execute(
      'INSERT INTO settings(key,value) VALUES(?,?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      <Object?>[key, value],
    );
  }

  db.execute(
    'DELETE FROM settings WHERE key = ?',
    <Object?>['fts_rebuild_done'],
  );
  if (built != FtsMode.off) {
    // 兼容旧键：老版本只认 fts_rebuild_done=1（doctor / 老控制器）。
    put('fts_rebuild_done', '1');
  }
  put(SettingsKeys.ftsMode, target.wire);
  put(SettingsKeys.ftsBuiltMode, built.wire);
}

/// 分批索引 book_entries（id 游标；每批 2000 行，批间让出事件循环）。
Future<int> rebuildBook(
  Database db, {
  required bool Function() isCancelled,
  required void Function(int done) onProgress,
}) async {
  final int maxId = scalar(db, 'SELECT COALESCE(MAX(id),0) FROM book_entries');
  var cursor = 0;
  var done = 0;
  while (!isCancelled()) {
    final List<Row> rows = db.select(
      'SELECT MAX(id) AS m FROM (SELECT id FROM book_entries '
      'WHERE id > ? AND id <= ? ORDER BY id LIMIT ?)',
      <Object?>[cursor, maxId, DefaultFtsIndexService.batchSize],
    );
    final int? next = rows.isEmpty ? null : (rows.single['m'] as num?)?.toInt();
    if (next == null) {
      break;
    }
    db.execute(
      'INSERT INTO $bookFtsTable(rowid,name,author,recommender,comment) '
      'SELECT id,name,author,recommender,comment FROM book_entries '
      'WHERE id > ? AND id <= ?',
      <Object?>[cursor, next],
    );
    done += db.updatedRows;
    cursor = next;
    onProgress(done);
    await Future<void>.delayed(Duration.zero);
  }
  return done;
}

/// 分批索引 floors（同型）。
Future<int> rebuildFloor(
  Database db, {
  required bool Function() isCancelled,
  required void Function(int done) onProgress,
}) async {
  final int maxId = scalar(db, 'SELECT COALESCE(MAX(id),0) FROM floors');
  var cursor = 0;
  var done = 0;
  while (!isCancelled()) {
    final List<Row> rows = db.select(
      'SELECT MAX(id) AS m FROM (SELECT id FROM floors '
      'WHERE id > ? AND id <= ? ORDER BY id LIMIT ?)',
      <Object?>[cursor, maxId, DefaultFtsIndexService.batchSize],
    );
    final int? next = rows.isEmpty ? null : (rows.single['m'] as num?)?.toInt();
    if (next == null) {
      break;
    }
    db.execute(
      'INSERT INTO $floorFtsTable(rowid,text) '
      'SELECT id,text FROM floors WHERE id > ? AND id <= ?',
      <Object?>[cursor, next],
    );
    done += db.updatedRows;
    cursor = next;
    onProgress(done);
    await Future<void>.delayed(Duration.zero);
  }
  return done;
}
