import 'dart:async';
import 'dart:convert';

import 'db/app_database.dart';

class ReadingSession {
  const ReadingSession({
    required this.savedAt,
    this.postId,
    this.postTid,
    this.title = '首页',
    this.offset = 0,
    this.homePages = 1,
    this.floorId,
    this.floorSeq,
  });

  final DateTime savedAt;
  final int? postId;
  final int? postTid;
  final String title;
  final double offset;
  final int homePages;
  final int? floorId;
  final int? floorSeq;

  String encode() => jsonEncode(<String, Object?>{
    'version': 1,
    'savedAt': savedAt.toIso8601String(),
    'postId': postId,
    'postTid': postTid,
    'title': title,
    'offset': offset,
    'homePages': homePages,
    'floorId': floorId,
    'floorSeq': floorSeq,
  });

  static ReadingSession? decode(String? raw) {
    try {
      if (raw == null || raw.length > 8192) return null;
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || decoded['version'] != 1) return null;
      final DateTime savedAt = DateTime.parse(decoded['savedAt'] as String);
      final double offset = (decoded['offset'] as num).toDouble();
      final int pages = decoded['homePages'] as int;
      final int? postId = decoded['postId'] as int?;
      if (!offset.isFinite || offset < 0 || offset > 10000000 ||
          pages < 1 || pages > 100 || (postId != null && postId <= 0)) {
        return null;
      }
      return ReadingSession(
        savedAt: savedAt,
        postId: postId,
        postTid: decoded['postTid'] as int?,
        title: decoded['title'] as String,
        offset: offset,
        homePages: pages,
        floorId: decoded['floorId'] as int?,
        floorSeq: decoded['floorSeq'] as int?,
      );
    } catch (_) {
      return null;
    }
  }
}

class ReadingSessionStore {
  ReadingSessionStore(this.database);

  static const String settingKey = 'reading_session.v1';
  final AppDatabase database;
  Future<ReadingSession?>? _initial;
  ReadingSession? _pending;
  Timer? _timer;
  Future<void> _writes = Future<void>.value();
  bool _closed = false;

  Future<ReadingSession?> loadPrevious() => _initial ??= _load();

  Future<ReadingSession?> _load() async {
    try {
      final row = await (database.select(database.settings)
        ..where((table) => table.key.equals(settingKey))).getSingleOrNull();
      return ReadingSession.decode(row?.value);
    } catch (_) {
      return null;
    }
  }

  void record(ReadingSession session) {
    if (_closed) return;
    unawaited(loadPrevious());
    _pending = session;
    _timer ??= Timer(const Duration(milliseconds: 500), () {
      _timer = null;
      unawaited(flush());
    });
  }

  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    final ReadingSession? pending = _pending;
    _pending = null;
    if (pending == null) return _writes;
    _writes = _writes.then((_) async {
      await loadPrevious();
      try {
        await database.customStatement(
          'INSERT INTO settings(key,value) VALUES (?,?) '
          'ON CONFLICT(key) DO UPDATE SET value=excluded.value',
          <Object>[settingKey, pending.encode()],
        );
      } catch (_) {}
    });
    return _writes;
  }

  void dispose() {
    _closed = true;
    _timer?.cancel();
    unawaited(flush());
  }
}
