import 'package:drift/drift.dart';

import '../content/novel_word_count.dart';
import 'db/app_database.dart';

const String wordCountRepairKey = 'novel_word_count_version';

Future<int> repairNovelWordCounts(AppDatabase database, {bool Function()? isCancelled}) async {
  final QueryRow? done = await database.customSelect(
    'SELECT value FROM settings WHERE key = ?',
    variables: <Variable>[Variable.withString(wordCountRepairKey)],
  ).getSingleOrNull();
  if (done?.read<String>('value') == '1') return 0;
  int cursor = 0;
  int changed = 0;
  while (true) {
    if (isCancelled?.call() == true) return changed;
    final List<QueryRow> rows = await database.customSelect(
      'SELECT b.id,b.name,b.origin,b.word_count,b.book_group_id,b.comment,f.text '
      'FROM book_entries b LEFT JOIN floors f ON f.id=b.floor_ref '
      "WHERE b.id > ? AND b.origin IN ('seed','builtin','collected') "
      "AND COALESCE(b.comment_src,'') <> 'user_edited' "
      'ORDER BY b.id LIMIT 200',
      variables: <Variable>[Variable.withInt(cursor)],
    ).get();
    if (rows.isEmpty) break;
    await database.transaction(() async {
      final Set<int> groups = <int>{};
      for (final QueryRow row in rows) {
        final String name = row.read<String>('name');
        final int? count = extractNovelWordCount(row.readNullable<String>('text') ?? '', bookName: name) ??
            extractNovelWordCount(row.readNullable<String>('comment') ?? '', bookName: name);
        final int? old = row.readNullable<int>('word_count');
        if (old == count) continue;
        await database.customStatement(
          "UPDATE book_entries SET word_count=? WHERE id=? AND COALESCE(comment_src,'') <> 'user_edited'",
          <Object?>[count, row.read<int>('id')],
        );
        final int? group = row.readNullable<int>('book_group_id');
        if (group != null) groups.add(group);
        changed++;
      }
      for (final int group in groups) {
        await database.customStatement(
          'UPDATE book_groups SET word_count_max=(SELECT MAX(word_count) FROM book_entries WHERE book_group_id=?) WHERE id=?',
          <Object>[group, group],
        );
      }
    });
    cursor = rows.last.read<int>('id');
    await Future<void>.delayed(Duration.zero);
  }
  if (isCancelled?.call() != true) {
    await database.customStatement(
      'INSERT INTO settings(key,value) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
      <Object>[wordCountRepairKey, '1'],
    );
  }
  return changed;
}
