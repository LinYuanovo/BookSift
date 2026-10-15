import 'package:booksift/features/content/book_detail_page.dart';
import 'package:booksift/features/content/content_detail_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import '../support/harness.dart';

// 帖头书目 chips（PostBookChip）：计数 = 全站按帖推荐/排雷次数，点击进书聚合页。
void main() {
  testWidgets('帖头书目 chip：按帖计数展示 + 点击进书聚合页', (
    WidgetTester tester,
  ) async {
    useSurface(tester);
    await tester.pumpWidget(
      testApp(
        FakeBookRepository(library: demoLibrary()),
        initial: '/post/7',
      ),
    );
    await tester.pumpAndSettle();

    final Finder chip = find.byType(PostBookChip);
    expect(chip, findsWidgets, reason: '帖 7 语料三条书目 → 三枚 chip');
    final Finder shuihu = find.descendant(
      of: chip,
      matching: find.textContaining('《篡水浒》'),
    );
    expect(shuihu, findsOneWidget);
    // 计数段 = 全站按帖口径（demo 语料该书推荐/排雷条数），非帖内条数聚合。
    expect(
      find.descendant(
        of: find.ancestor(of: shuihu, matching: chip),
        matching: find.textContaining('推荐'),
      ),
      findsOneWidget,
    );

    await tester.tap(shuihu);
    await tester.pumpAndSettle();
    expect(find.byType(BookDetailPage), findsOneWidget);
  });
}
