import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:booksift/core/constants.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/features/content/content_detail_page.dart';

import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import '../support/harness.dart';

// 任务 1：书签记录/恢复楼层位置。
//
// 分组（边界遵守 app/test/TESTING.md §3）：
//   · 「schema v4 迁移」plain test() —— 用 sqlite3 包手工建 v1/v2/v3 形态的磁盘库，
//     交给 AppDatabase 打开触发真实迁移，断言 floor_seq 加列 + 旧行 NULL + v4 查询索引
//     就位（sqlite_master）+ user_version 落 4（真实 IO）；
//   · 「floor_seq 落库」plain test() —— 内存库直接断言 Queries 写入路径；
//   · 「楼层书签 UI」testWidgets —— 全内存 fake（FakeBookRepository），零真实 IO。

// ─────────────────── 迁移挂具（plain test 专用，真实磁盘库）───────────────────

int _tmpSeq = 0;

/// 手工建 v[userVersion] 形态的最小库（被迁移触碰的表 + v4 查询索引引用的内容表），
/// 内含一行无 floor_seq 的旧书签；交给 AppDatabase 打开即触发 onUpgrade 链。
///
/// 形态随 [userVersion] 变化（对齐真实迁移链）：
/// - posts.post_kind/recommend_flag 为 v2 才加的列 → 仅 from≥2 预置（from<2 由 onUpgrade 补）；
/// - bookmarks.floor_seq 为 v3 才加的列 → 仅 from≥3 预置（from<3 由 onUpgrade 补）；
/// - posts.date/origin 与 floors/images/book_entries 为 base 列/表，各版本恒在
///   （v4 的 idx_posts_date/idx_posts_origin/idx_floors_post/idx_images_floor/idx_be_* 引用）。
Future<AppDatabase> _openLegacyDb(int userVersion) async {
  final Directory tmp = await Directory.systemTemp.createTemp(
    'booksift_v3mig${_tmpSeq++}',
  );
  final File f = File(p.join(tmp.path, 'legacy.db'));
  final sql.Database raw = sql.sqlite3.open(f.path);
  try {
    // posts：base 列 + date/origin；分类列按版本预置（from<2 留给 onUpgrade addColumn）。
    final String kindCols = userVersion >= 2
        ? ", post_kind TEXT NOT NULL DEFAULT '扫书', recommend_flag INTEGER NOT NULL DEFAULT 0"
        : '';
    raw.execute(
      'CREATE TABLE posts ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, tid INTEGER UNIQUE, title TEXT,'
      " channel TEXT NOT NULL, date TEXT, origin TEXT NOT NULL DEFAULT 'builtin'"
      '$kindCols)',
    );
    // bookmarks：floor_seq 按版本预置（from<3 留给 onUpgrade addColumn）。
    final String floorSeqCol = userVersion >= 3 ? ', floor_seq INTEGER' : '';
    raw.execute(
      'CREATE TABLE bookmarks ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, post_ref INTEGER, entry_ref INTEGER,'
      ' title TEXT NOT NULL, author TEXT, channel TEXT,'
      ' position INTEGER NOT NULL DEFAULT 0,'
      ' snap_query TEXT, snap_year TEXT, snap_month TEXT, snap_ten_day TEXT,'
      ' snap_channel TEXT, snap_category TEXT, snap_sort TEXT, note TEXT,'
      ' created_at INTEGER NOT NULL$floorSeqCol)',
    );
    raw.execute(
      "INSERT INTO bookmarks (post_ref, title, position, created_at) VALUES (7, '旧书签', 3, 1700000000)",
    );
    // v4 查询索引引用的内容表（最小形态：只含被索引列）。迁移测试只经 raw customSelect
    // 验索引/列/版本，不走 drift 类型映射查这些表，故无需与 drift 全 schema 逐列一致。
    raw.execute(
      'CREATE TABLE floors ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, post_id INTEGER NOT NULL, seq INTEGER NOT NULL)',
    );
    raw.execute(
      'CREATE TABLE images ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, floor_id INTEGER NOT NULL)',
    );
    raw.execute(
      'CREATE TABLE book_entries ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, name_norm TEXT NOT NULL, book_group_id INTEGER,'
      ' post_ref INTEGER, date TEXT, channel TEXT NOT NULL, sub_channel TEXT,'
      " origin TEXT NOT NULL DEFAULT 'builtin', category TEXT NOT NULL DEFAULT '扫书')",
    );
    raw.execute('PRAGMA user_version=$userVersion');
  } finally {
    raw.close();
  }
  final AppDatabase db = AppDatabase(NativeDatabase(f));
  addTearDown(() async {
    await db.close();
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows 句柄延迟释放：临时目录留待系统清理（features_test.openFixture 同口径）。
    }
  });
  return db;
}

Future<Set<String>> _columnNames(AppDatabase db, String table) async {
  final List<dynamic> rows = await db
      .customSelect('PRAGMA table_info($table)')
      .get();
  return rows.map((dynamic r) => r.data['name']! as String).toSet();
}

Future<int> _userVersion(AppDatabase db) async =>
    (await db.customSelect('PRAGMA user_version').getSingle())
            .data['user_version']!
        as int;

/// 库内用户索引名集合（sqlite_master；排除 sqlite_ 内部自动索引）。
Future<Set<String>> _indexNames(AppDatabase db) async {
  final List<dynamic> rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'index' "
        "AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  return rows.map((dynamic r) => r.data['name']! as String).toSet();
}

/// v4 查询索引全集（镜像 app_database.dart `_createQueryIndexes`）：
/// 任意 from<4 的库迁移到 v4 后，这 12 个 idx_* 须全部就位。
const Set<String> _v4QueryIndexes = <String>{
  'idx_be_name',
  'idx_be_group',
  'idx_be_postref',
  'idx_be_date',
  'idx_be_channel',
  'idx_be_origin',
  'idx_book_entries_category',
  'idx_posts_date',
  'idx_posts_kind',
  'idx_posts_origin',
  'idx_floors_post',
  'idx_images_floor',
};

void main() {
  group('schema v4 迁移', () {
    test(
      'v2 → v4：bookmarks 加 floor_seq 列，旧行保持 NULL，补查询索引，user_version 落 4',
      () async {
        final AppDatabase db = await _openLegacyDb(2);

        expect(await _columnNames(db, 'bookmarks'), contains('floor_seq'));
        final dynamic row = await db
            .customSelect('SELECT floor_seq, position FROM bookmarks')
            .getSingle();
        expect(row.data['floor_seq'], isNull, reason: '旧书签无楼层记忆');
        expect(row.data['position'], 3, reason: '既有列不受迁移影响');
        expect(await _indexNames(db), containsAll(_v4QueryIndexes));
        expect(await _userVersion(db), 4);
      },
    );

    test('v1 → v4：迁移链依次加列（posts 分类列 + bookmarks.floor_seq）+ 补查询索引', () async {
      final AppDatabase db = await _openLegacyDb(1);

      expect(
        await _columnNames(db, 'posts'),
        containsAll(<String>['post_kind', 'recommend_flag']),
      );
      expect(await _columnNames(db, 'bookmarks'), contains('floor_seq'));
      final dynamic row = await db
          .customSelect('SELECT floor_seq FROM bookmarks')
          .getSingle();
      expect(row.data['floor_seq'], isNull);
      expect(await _indexNames(db), containsAll(_v4QueryIndexes));
      expect(await _userVersion(db), 4);
    });

    test('v3 → v4：无列变更，仅补查询索引（sqlite_master 验 12 个 idx_* 就位）', () async {
      final AppDatabase db = await _openLegacyDb(3);

      // v3 已有的列不受影响（from<2 / from<3 分支均不触发）。
      expect(await _columnNames(db, 'posts'), contains('post_kind'));
      expect(await _columnNames(db, 'bookmarks'), contains('floor_seq'));
      // from<4 分支建齐全部查询索引。
      expect(await _indexNames(db), containsAll(_v4QueryIndexes));
      expect(await _userVersion(db), 4);
    });

    test('togglePostBookmark 落库 floor_seq；缺省调用保持 NULL（v3 直建内存库）', () async {
      final AppDatabase db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final Queries q = Queries(db);

      await q.togglePostBookmark(postRef: 7, title: 't', floorSeq: 12);
      await q.togglePostBookmark(postRef: 8, title: 'u');
      final List<Bookmark> rows = await q.watchBookmarks().first;
      expect(rows.firstWhere((Bookmark b) => b.postRef == 7).floorSeq, 12);
      expect(
        rows.firstWhere((Bookmark b) => b.postRef == 8).floorSeq,
        isNull,
        reason: '旧调用方语义不变',
      );
    });
  });

  // ─────────────────── UI（testWidgets，全内存 fake）───────────────────

  group('楼层书签 UI', () {
    late FakeBookRepository repo;
    setUp(() => repo = FakeBookRepository(library: demoLibrary()));

    testWidgets('详情页点书签记录首个可见楼层 seq（写入含楼层位置）', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, initial: '/post/18293'));
      await tester.pumpAndSettle();

      AnimatedSwitcher bookmark = tester.widget<AnimatedSwitcher>(
        find.byKey(const ValueKey<String>('post_action_bookmark')),
      );
      expect(bookmark.child?.key, const ValueKey<bool>(false));

      await tester.tap(find.text('书签'));
      await tester.pumpAndSettle();

      bookmark = tester.widget<AnimatedSwitcher>(
        find.byKey(const ValueKey<String>('post_action_bookmark')),
      );
      expect(bookmark.child?.key, const ValueKey<bool>(true));

      expect(find.text('已加入书签（含楼层位置）'), findsOneWidget);
      final Bookmark bm = repo.bookmarks.single;
      expect(bm.postRef, 18293);
      expect(bm.floorSeq, 1, reason: '单楼帖首个可见楼层 = 1 楼');
      await dismissSnackBars(tester);
    });

    testWidgets('书签恢复：副标题带楼层，点击打开详情并定位到记录楼层', (WidgetTester tester) async {
      // 30 楼长帖：未定位时 25 楼懒构建不在树，定位成功才可命中。
      final FakeLibrary longPost = FakeLibrary(
        posts: <Post>[
          Post(
            id: 900,
            tid: 900900,
            title: '长楼帖',
            portrait: '',
            date: '2025-04-28',
            channel: 'yy小说吧',
            postType: CategoryKind.scan,
            postKind: CategoryKind.scan,
            recommendFlag: 1,
            floorCount: 30,
            imageCount: 0,
            origin: Origin.builtin,
          ),
        ],
        floors: <int, List<FloorData>>{
          900: <FloorData>[
            for (int i = 1; i <= 30; i++)
              FloorData(
                floor: Floor(
                  id: 900000 + i,
                  postId: 900,
                  seq: i,
                  content: '第 $i 层正文内容占位，长度差不多。',
                  charCount: 16,
                ),
                images: const <FloorImage>[],
              ),
          ],
        },
        entries: const <EntryRow>[],
        groups: const <BookGroup>[],
      );
      final FakeBookRepository longRepo = FakeBookRepository(library: longPost);
      await longRepo.togglePostBookmark(
        postRef: 900,
        title: '长楼帖',
        floorSeq: 25,
      );

      useSurface(tester);
      await tester.pumpWidget(testApp(longRepo, initial: '/profile'));
      await tester.pumpAndSettle();

      // 副标题：「第 1 条 · 25楼」（floorSeq 非空才追加）。
      expect(find.textContaining('25楼'), findsOneWidget);

      await tester.tap(find.textContaining('「长楼帖」'));
      await tester.pumpAndSettle();

      final ContentDetailPage page = tester.widget(
        find.byType(ContentDetailPage),
      );
      expect(page.selection.postId, 900);
      expect(page.selection.initialFloorSeq, 25);
      // 定位生效：25 楼已滚入树（ListView 懒构建，不跳则不可见）。
      expect(find.text('25楼'), findsOneWidget);
    });
  });
}
