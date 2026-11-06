import 'dart:io';

import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/reading_session.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reading position survives database close and a new store', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'booksift-session-',
    );
    final File file = File('${directory.path}/library.db');
    final AppDatabase first = AppDatabase(NativeDatabase(file));
    final ReadingSessionStore firstStore = ReadingSessionStore(first);
    firstStore.record(
      ReadingSession(
        savedAt: DateTime(2026, 11, 6),
        offset: 1234,
        homePages: 4,
      ),
    );
    await firstStore.flush();
    firstStore.dispose();
    await first.close();
    final AppDatabase second = AppDatabase(NativeDatabase(file));
    final ReadingSessionStore secondStore = ReadingSessionStore(second);
    try {
      final ReadingSession? previous = await secondStore.loadPrevious();
      expect(previous?.offset, 1234);
      expect(previous?.homePages, 4);
      secondStore.record(
        ReadingSession(
          savedAt: DateTime.now(),
          postId: 42,
          postTid: 999,
          offset: 250,
        ),
      );
      secondStore.record(
        ReadingSession(
          savedAt: DateTime.now(),
          postId: 42,
          postTid: 999,
          offset: 700,
        ),
      );
      await secondStore.flush();
      expect((await secondStore.loadPrevious())?.postId, isNull);
      final ReadingSessionStore reopened = ReadingSessionStore(second);
      expect((await reopened.loadPrevious())?.offset, 700);
      expect((await reopened.loadPrevious())?.postTid, 999);
      reopened.dispose();
    } finally {
      secondStore.dispose();
      await second.close();
      await directory.delete(recursive: true);
    }
  });

  test('invalid and unsupported snapshots are ignored', () {
    for (final String raw in <String>[
      '{',
      '[]',
      '{"version":2}',
      '{"version":1,"savedAt":"bad"}',
    ]) {
      expect(ReadingSession.decode(raw), isNull);
    }
    expect(
      ReadingSession.decode(
        ReadingSession(savedAt: DateTime.now(), offset: -1).encode(),
      ),
      isNull,
    );
    expect(
      ReadingSession.decode(
        ReadingSession(savedAt: DateTime.now(), homePages: 100000).encode(),
      ),
      isNull,
    );
  });
}
