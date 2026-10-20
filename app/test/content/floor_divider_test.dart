import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/constants.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/theme/app_colors.dart';
import 'package:booksift/theme/app_spacing.dart';

import '../support/fake_book_repository.dart';
import '../support/harness.dart';

// 任务 1：楼层之间发丝分割线（首楼层前不加、末楼层后不加；c.border + AppMetrics.hairline）。
//
// 断言口径：头部元信息分隔的 Divider(height: space6) 不显式带 thickness/color（走
// DividerTheme），按 widget 属性谓词可精确圈出楼层分割线，不受头部那条干扰。
// 全部 testWidgets 零真实 IO（语料无图，TESTING.md §3.1）。

FakeLibrary _postWithFloors(int floors) => FakeLibrary(
  posts: <Post>[
    Post(
      id: 900,
      tid: 900900,
      title: '分割线帖',
      portrait: '',
      date: '2025-04-28',
      channel: 'yy小说吧',
      postType: CategoryKind.scan,
      postKind: CategoryKind.scan,
      recommendFlag: 1,
      floorCount: floors,
      imageCount: 0,
      origin: Origin.builtin,
    ),
  ],
  floors: <int, List<FloorData>>{
    900: <FloorData>[
      for (int i = 1; i <= floors; i++)
        FloorData(
          floor: Floor(
            id: 900000 + i,
            postId: 900,
            seq: i,
            content: '第 $i 层正文占位。',
            charCount: 9,
          ),
          images: const <FloorImage>[],
        ),
    ],
  },
  entries: const <EntryRow>[],
  groups: const <BookGroup>[],
);

/// 楼层间发丝线（widget 属性级谓词：显式 hairline + border 令牌色）。
Finder floorHairlines() => find.byWidgetPredicate(
  (Widget w) =>
      w is Divider &&
      w.thickness == AppMetrics.hairline &&
      w.color == AppColors.light.border,
);

void main() {
  testWidgets('3 楼层帖：楼层间恰 2 条发丝线（n-1，首前/末后不加）', (WidgetTester tester) async {
    useSurface(tester);
    await tester.pumpWidget(
      testApp(FakeBookRepository(library: _postWithFloors(3)), initial: '/post/900'),
    );
    await tester.pumpAndSettle();

    expect(floorHairlines(), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('单楼层帖：零条楼层分割线（头部分隔线不受影响）', (WidgetTester tester) async {
    useSurface(tester);
    await tester.pumpWidget(
      testApp(FakeBookRepository(library: _postWithFloors(1)), initial: '/post/900'),
    );
    await tester.pumpAndSettle();

    expect(floorHairlines(), findsNothing);
    expect(find.byType(Divider), findsOneWidget, reason: '头部元信息分隔线仍在');
  });

  testWidgets('楼层流零楼层（全删）：不产生分割线', (WidgetTester tester) async {
    final FakeLibrary lib = _postWithFloors(2);
    lib.floors[900] = const <FloorData>[]; // 帖在、楼层全删 → 空态分支
    useSurface(tester);
    await tester.pumpWidget(
      testApp(FakeBookRepository(library: lib), initial: '/post/900'),
    );
    await tester.pumpAndSettle();

    expect(floorHairlines(), findsNothing);
    expect(find.text('原帖内容已不可用'), findsOneWidget);
  });
}
