import 'dart:io';

import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/storage_maintenance.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compaction preserves data and releases deleted pages', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'booksift-storage-',
    );
    final AppDatabase database = AppDatabase(
      NativeDatabase(File('${directory.path}/copy.db')),
    );
    try {
      await database.customStatement('CREATE TABLE scratch (value BLOB)');
      await database.customStatement(
        'INSERT INTO scratch VALUES (zeroblob(2097152))',
      );
      await database.customStatement(
        "INSERT INTO settings(key,value) VALUES ('retained','yes')",
      );
      await database.customStatement('DROP TABLE scratch');
      final StorageUsage before = await readStorageUsage(database);
      final StorageUsage after = await compactLibrary(database);
      expect(before.reclaimableBytes, greaterThan(1000000));
      expect(after.databaseBytes, lessThan(before.databaseBytes));
      expect(
        (await database
                .customSelect("SELECT value FROM settings WHERE key='retained'")
                .getSingle())
            .read<String>('value'),
        'yes',
      );
      expect(
        (await database.customSelect('PRAGMA integrity_check').getSingle())
            .data
            .values
            .single,
        'ok',
      );
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });

  test('update cleanup keeps unrelated files and directories', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'booksift-cache-',
    );
    try {
      final File owned = File('${directory.path}/${'a' * 32}-app.apk.part');
      await owned.writeAsString('cache');
      final File retained = File('${directory.path}/book.epub');
      await retained.writeAsString('book');
      await Directory('${directory.path}/imports').create();
      expect(await clearUpdateCache(directory), 5);
      expect(await retained.readAsString(), 'book');
      expect(await Directory('${directory.path}/imports').exists(), isTrue);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
