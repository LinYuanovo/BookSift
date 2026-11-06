import 'dart:convert';
import 'dart:io';

import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:drift/native.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/benchmark_library.dart <database-copy>',
    );
    exitCode = 64;
    return;
  }
  final AppDatabase database = AppDatabase(
    NativeDatabase.createInBackground(File(arguments.single)),
  );
  final Queries queries = Queries(database);
  final Map<String, Object> results = <String, Object>{};
  Future<void> measure(String name, Future<Object?> Function() action) async {
    final Stopwatch timer = Stopwatch()..start();
    final Object? result = await action();
    results[name] = <String, Object>{
      'milliseconds': timer.elapsedMicroseconds / 1000,
      if (result is List) 'rows': result.length,
    };
  }

  try {
    await measure('open', () => database.customSelect('SELECT 1').get());
    for (int iteration = 0; iteration < 3; iteration++) {
      await measure(
        'timeline_$iteration',
        () => queries.timelinePosts(limit: 40),
      );
      await measure(
        'rank_$iteration',
        () => queries.rankRows(RankWindow.allTime),
      );
      await measure('random_$iteration', () => queries.randomBooks(10));
    }
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(results));
  } finally {
    await database.close();
  }
}
