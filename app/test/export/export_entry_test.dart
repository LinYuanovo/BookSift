import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/icons.dart';
import 'package:booksift/data/repo/database_provider.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/data/repo/queries_providers.dart';
import 'package:booksift/features/content/book_detail_page.dart';
import 'package:booksift/features/export/booklist_export.dart';
import 'package:booksift/features/export/export_sheet.dart';
import 'package:booksift/features/home/cards.dart';
import 'package:booksift/features/profile/profile_page.dart';
import 'package:booksift/theme/book_theme.dart';

import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import 'support.dart';

// 两处入口接线（原型 §3.1 P2-4）：我的→收藏夹段头「导出」图标（导出全部收藏）/
// 书聚合页 ⋮「导出书单(MD/TXT)」（导出该书）。搜索页入口留待下轮，不在本文件。
//
// 只断言「入口把什么文档送进弹层」，不点保存/分享 —— 弹层默认服务是真
// PlatformTextFileSink，出口链路由 export_sheet_test.dart 注入 fake 覆盖。
//
// 宿主不走 support/harness.dart 的 testApp（那会拖入 app_router → settings_page 的
// 编译依赖）：入口测试只需要页面本体 + queriesProvider 注入，直接 home: 挂载。

/// 入口测试宿主：内存 fake 仓 + 真库哨兵（同 harness.testOverrides 口径）。
Widget entryHost(FakeBookRepository repo, Widget page) {
  return ProviderScope(
    overrides: <Override>[
      queriesProvider.overrideWithValue(repo),
      appDatabaseProvider.overrideWith(
        (Ref ref) => throw StateError('widget 测试禁止触碰真实数据库（见 app/test/TESTING.md）'),
      ),
    ],
    child: MaterialApp(
      theme: BookTheme.light,
      darkTheme: BookTheme.dark,
      themeMode: ThemeMode.light,
      home: page,
    ),
  );
}

void main() {
  late FakeBookRepository repo;

  setUp(() => repo = FakeBookRepository(library: demoLibrary()));

  group('我的 → 收藏夹导出入口', () {
    testWidgets('段头「导出」图标（SVG external）→ 汇总全部收藏进弹层', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      await repo.toggleFavorite(
        targetType: FavoriteTarget.bookGroup,
        targetId: 901,
        title: '《十日终焉》',
        subtitle: '杀虫队队员',
      );
      await repo.toggleFavorite(
        targetType: FavoriteTarget.post,
        targetId: 14403,
        title: '排雷：这几本千万别踩',
      );

      await tester.pumpWidget(entryHost(repo, const ProfilePage()));
      await tester.pumpAndSettle();

      // 入口图标走设计稿 SVG（external），非 Material Icon。
      final Finder exportBtn = find.byTooltip('导出书单');
      expect(exportBtn, findsOneWidget);
      expect(
        tester.widget<AppIcon>(find.descendant(of: exportBtn, matching: find.byType(AppIcon))).name,
        'external',
      );

      await tester.tap(exportBtn);
      await tester.pumpAndSettle();

      expect(find.byType(BooklistExportSheet), findsOneWidget);
      // 收藏夹文档：书粒度补全 + 帖粒度都在。
      final BooklistDoc doc = tester.widget<BooklistExportSheet>(find.byType(BooklistExportSheet)).doc;
      expect(doc.kind, BooklistDocKind.favorites);
      expect(doc.heading, '我的收藏书单');
      expect(doc.books, hasLength(1));
      expect(doc.books.single.title, '十日终焉');
      expect(doc.books.single.author, '杀虫队队员');
      expect(doc.posts, hasLength(1));
      expect(doc.posts.single.avoid, isTrue);
      // 弹层预览 = 前 20 行 MD，书块标题在场。
      expect(previewTextOf(tester), contains('《十日终焉》'));
    });

    testWidgets('收藏夹为空 → 不给导出按钮（与「清空」同款隐去口径）', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      await tester.pumpWidget(entryHost(repo, const ProfilePage()));
      await tester.pumpAndSettle();

      expect(find.text('收藏夹 0'), findsOneWidget);
      expect(find.byTooltip('导出书单'), findsNothing);
      // 同页历史段的「清空」也不在场（既有口径参照）。
      expect(find.text('清空'), findsNothing);
    });
  });

  group('书聚合页 ⋮「导出书单(MD/TXT)」', () {
    testWidgets('菜单项在场且不动既有三项 → 弹层收到该书全量明细', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      await tester.pumpWidget(entryHost(repo, const BookDetailPage(bookGroupId: 904)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      expect(find.text('复制书名'), findsOneWidget);
      expect(find.text('导出该书推荐'), findsOneWidget);
      expect(find.text('导出书单(MD/TXT)'), findsOneWidget);
      expect(find.text('搜索作者'), findsOneWidget);

      await tester.tap(find.text('导出书单(MD/TXT)'));
      await tester.pumpAndSettle();

      expect(find.byType(BooklistExportSheet), findsOneWidget);
      final BooklistDoc doc = tester.widget<BooklistExportSheet>(find.byType(BooklistExportSheet)).doc;
      expect(doc.kind, BooklistDocKind.singleBook);
      expect(doc.heading, '《逍遥小书生》推荐单');
      expect(doc.books.single.recommendations, hasLength(2));
      expect(doc.books.single.recommendations.where((ExportRecommendation r) => r.avoid), hasLength(1));
    });

    testWidgets('导出跟随当前语义筛选：仅排雷 → 明细只剩排雷条', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      await tester.pumpWidget(entryHost(repo, const BookDetailPage(bookGroupId: 904)));
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(
        of: find.byType(SegmentedPill<SemanticFilter>),
        matching: find.text('仅排雷'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('导出书单(MD/TXT)'));
      await tester.pumpAndSettle();

      final BooklistDoc doc = tester.widget<BooklistExportSheet>(find.byType(BooklistExportSheet)).doc;
      expect(doc.books.single.recommendations, hasLength(1));
      expect(doc.books.single.recommendations.single.avoid, isTrue);
      expect(doc.metaLine, contains('共 1 条 · 推荐 0 · 排雷 1'));
    });
  });
}
