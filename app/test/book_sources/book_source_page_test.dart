import 'package:booksift/features/search/book_source_page.dart';
import 'package:booksift/theme/book_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('book search fits a narrow viewport and carries the book title', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: BookTheme.light,
          home: const BookSourcePage(initialQuery: '红楼梦'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('红楼梦'), findsOneWidget);
    expect(find.text('尚香书苑'), findsOneWidget);
    expect(find.text('搜书吧'), findsOneWidget);
    expect(find.byTooltip('书源设置'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
