import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/features/content/book_detail_page.dart';
import 'package:booksift/features/content/content_detail_page.dart';
import 'package:booksift/features/home/cards.dart';
import 'package:booksift/features/profile/profile_page.dart';
import 'package:booksift/features/search/search_page.dart';
import 'package:booksift/theme/app_spacing.dart';

import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import '../support/harness.dart';

// 任务 4/5：我的页三处空态水平居中 + 三段列表整行可点。
//
// 全部 testWidgets + 全内存 fake（FakeBookRepository / testApp 挂具），零真实 IO
// （app/test/TESTING.md §3）：
//   · 任务 4 —— 空态中心对齐 ProfilePage 容器中心（改前是 start 对齐的左贴边）；
//   · 任务 5 —— 行宽 = 内容区宽，点最右缘（文本块之外）也走同一条恢复路径。

void main() {
  late FakeBookRepository repo;

  setUp(() => repo = FakeBookRepository(library: demoLibrary()));

  // 预置书签 / 收藏 / 历史各一行（fake 写路径只有微任务，可在 testWidgets 体内 await）。
  Future<void> seedRows() async {
    await repo.togglePostBookmark(
      postRef: 7,
      title: '【扫书】yy小说吧四月下旬合集',
      author: '扫书人甲',
      channel: 'yy小说吧',
      position: 6,
      floorSeq: 2,
    );
    await repo.toggleFavorite(
      targetType: FavoriteTarget.bookGroup,
      targetId: 901,
      title: '《十日终焉》',
    );
    await repo.addHistory(const SearchFilter(query: '世子很凶', month: '4'));
  }

  double viewportWidth(WidgetTester tester) =>
      tester.view.physicalSize.width / tester.view.devicePixelRatio;

  double pagePadding(WidgetTester tester) =>
      AppSpacing.of(tester.element(find.byType(ProfilePage))).pagePadding;

  /// 点某行的最右缘（文本块之外）：整行可点才命中。
  Future<void> tapRowRightEdge(WidgetTester tester, Finder row) async {
    final Rect r = tester.getRect(row);
    await tester.tapAt(
      Offset(viewportWidth(tester) - pagePadding(tester) - 4, r.center.dy),
    );
    await tester.pumpAndSettle();
  }

  group('我的页：三段列表整行可点（任务 5）', () {
    testWidgets('书签夹整行铺满 —— 点最右缘也能打开帖子详情', (WidgetTester tester) async {
      useSurface(tester, height: 1400);
      await seedRows();
      await tester.pumpWidget(testApp(repo, initial: '/profile'));
      await tester.pumpAndSettle();

      final Finder row = find.byKey(
        ValueKey<String>('bm-${repo.bookmarks.single.id}'),
      );
      expect(
        tester.getSize(row).width,
        closeTo(viewportWidth(tester) - 2 * pagePadding(tester), 0.5),
        reason: '书签行与收藏/历史同款：铺满内容区，而不是只包住文本',
      );

      await tapRowRightEdge(tester, row);
      expect(find.byType(ContentDetailPage), findsOneWidget);
    });

    testWidgets('收藏夹整行铺满 —— 点最右缘也能打开书聚合页', (WidgetTester tester) async {
      useSurface(tester, height: 1400);
      await seedRows();
      await tester.pumpWidget(testApp(repo, initial: '/profile'));
      await tester.pumpAndSettle();

      final Finder row = find.byKey(
        ValueKey<String>('fav-${repo.favorites.single.id}'),
      );
      expect(
        tester.getSize(row).width,
        closeTo(viewportWidth(tester) - 2 * pagePadding(tester), 0.5),
      );

      await tapRowRightEdge(tester, row);
      expect(find.byType(BookDetailPage), findsOneWidget);
    });

    testWidgets('搜索历史整行铺满 —— 点最右缘也能复现搜索', (WidgetTester tester) async {
      useSurface(tester, height: 1400);
      await seedRows();
      await tester.pumpWidget(testApp(repo, initial: '/profile'));
      await tester.pumpAndSettle();

      final Finder row = find.byKey(
        ValueKey<String>('his-${repo.history.single.id}'),
      );
      expect(
        tester.getSize(row).width,
        closeTo(viewportWidth(tester) - 2 * pagePadding(tester), 0.5),
      );

      await tapRowRightEdge(tester, row);
      expect(find.byType(SearchPage), findsOneWidget);
    });
  });

  group('我的页：空态水平居中（任务 4）', () {
    testWidgets('横屏：书签夹/收藏夹/搜索历史三处占位提示居中', (WidgetTester tester) async {
      // 横屏宽窗 + 足高视口：三段空态都在树内（ListView 懒构建，TESTING.md §7）。
      useSurface(tester, width: 1280, height: 1400);
      await tester.pumpWidget(testApp(repo, initial: '/profile'));
      await tester.pumpAndSettle();

      final double containerCenter = tester
          .getRect(find.byType(ProfilePage))
          .center
          .dx;
      for (final String title in <String>['还没有书签', '还没有收藏', '暂无搜索历史']) {
        final Finder empty = find.byWidgetPredicate(
          (Widget w) => w is AppEmptyState && w.title == title,
        );
        expect(empty, findsOneWidget, reason: '$title 空态应在场');
        expect(
          tester.getRect(empty).center.dx,
          closeTo(containerCenter, 0.5),
          reason: '$title 应在容器中水平居中',
        );
      }
    });
  });
}
