import 'package:booksift/content/novel_word_count.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/word_count_maintenance.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'explicit novel counts support units, punctuation and fullwidth digits',
    () {
      for (final (String text, int count) in <(String, int)>[
        ('字数：120万字', 1200000),
        ('作品字数：50,2万字', 502000),
        ('字数 1,234,567 字', 1234567),
        ('本书字数：３００．５万', 3005000),
        ('篇幅: 1.5百万', 1500000),
        ('字数/章节：80W/1000章', 800000),
      ]) {
        expect(extractNovelWordCount(text), count, reason: text);
      }
      for (final String text in <String>[
        '书评字数：3000',
        '评论字数:500',
        '本章字数:2000',
        '看完第300章',
        '这篇评论' * 100,
        '字数:0',
      ]) {
        expect(extractNovelWordCount(text), isNull, reason: text);
      }
    },
  );

  test('counts stay within the matching book section', () {
    const String text = '《甲书》字数：100万\n《乙书》字数：250万';
    expect(extractNovelWordCount(text, bookName: '甲书'), 1000000);
    expect(extractNovelWordCount(text, bookName: '乙书'), 2500000);
    expect(extractNovelWordCount(text, bookName: '丙书'), isNull);
    expect(extractNovelWordCount('《甲书》暂无\n《乙书》字数:80万', bookName: '甲书'), isNull);
  });

  test(
    'repair replaces legacy review lengths, protects edits and updates aggregates',
    () async {
      final AppDatabase database = AppDatabase(NativeDatabase.memory());
      try {
        await database.customStatement(
          "INSERT INTO book_groups(id,name_norm) VALUES (1,'甲书')",
        );
        for (final (
              int id,
              String origin,
              String source,
              String comment,
              int words,
            )
            row
            in <(int, String, String, String, int)>[
              (1, 'seed', 'clist_item', '《甲书》字数：150万', 300),
              (2, 'seed', 'dalao_review', '《乙书》只是评论', 500),
              (3, 'collected', 'collected_floor', '《甲书》作品字数200万', 0),
              (4, 'imported', 'document', '手工指定', 3000000),
              (5, 'seed', 'user_edited', '手工校对', 4000000),
            ]) {
          await database.customStatement(
            'INSERT INTO book_entries(id,name,name_norm,channel,content_hash,origin,comment_src,comment,word_count,book_group_id) VALUES (?,?,?,?,?,?,?,?,?,1)',
            <Object>[
              row.$1,
              row.$1 == 2 ? '乙书' : '甲书',
              '甲书',
              'test',
              '${row.$1}',
              row.$2,
              row.$3,
              row.$4,
              row.$5,
            ],
          );
        }
        expect(await repairNovelWordCounts(database), 3);
        final rows = await database
            .customSelect('SELECT word_count FROM book_entries ORDER BY id')
            .get();
        expect(rows.map((row) => row.data['word_count']), <int?>[
          1500000,
          null,
          2000000,
          3000000,
          4000000,
        ]);
        expect(
          (await database.select(database.bookGroups).getSingle()).wordCountMax,
          4000000,
        );
        expect(await repairNovelWordCounts(database), 0);
        await database.customStatement(
          "INSERT INTO book_fts(book_fts,rank) VALUES ('integrity-check',1)",
        );
      } finally {
        await database.close();
      }
    },
  );
}
