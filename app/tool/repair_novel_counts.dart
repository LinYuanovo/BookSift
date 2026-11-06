import 'dart:io';

import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/word_count_maintenance.dart';
import 'package:drift/native.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2 || arguments.first != '--copy') {
    stderr.writeln(
      'Usage: dart run tool/repair_novel_counts.dart --copy <test-database-copy>',
    );
    exitCode = 64;
    return;
  }
  final AppDatabase database = AppDatabase(
    NativeDatabase(File(arguments.last)),
  );
  try {
    final Stopwatch timer = Stopwatch()..start();
    final int changed = await repairNovelWordCounts(database);
    stdout.writeln('changed=$changed elapsed_ms=${timer.elapsedMilliseconds}');
    final rows = await database
        .customSelect(
          'SELECT COUNT(*) AS total,SUM(word_count IS NOT NULL) AS known,MAX(word_count) AS maximum FROM book_entries',
        )
        .getSingle();
    stdout.writeln(rows.data);
    stdout.writeln(
      'idempotent_changes=${await repairNovelWordCounts(database)}',
    );
    stdout.writeln(
      (await database.customSelect('PRAGMA integrity_check').getSingle()).data,
    );
  } finally {
    await database.close();
  }
}
