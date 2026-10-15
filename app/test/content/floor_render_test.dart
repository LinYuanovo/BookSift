import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/features/content/rich_text.dart';

import '../support/fake_book_repository.dart';
import '../support/harness.dart';

void main() {
  // 真机回归：种子库 post_id=63「重生之都市修仙」一楼原文渲染。
  testWidgets('FloorRichText 渲染含书名与多行正文的楼层（release 空楼层回归）', (WidgetTester tester) async {
    useSurface(tester);
    const String text = '1、《重生之都市修仙》\n　　简介：渡劫期大修士陈凡陨落在天劫中，却一梦五百年重回地球的年少时代。\n'
        '　　类型：修仙 爽文\n　　楼主说：最近在某点蛮红的，目前看了60%。';
    await tester.pumpWidget(testApp(
      FakeBookRepository(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: FloorRichText(text: text, onBookTap: (_) {}),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('渡劫期大修士'), findsOneWidget);
  });

  // 真机回归：种子「大佬贴吧扫书」渠道把每本书卡片存为一楼且 seq 全为 1——
  // 楼层锚点若按 seq 键控，多个楼层共用同一 GlobalKey，构建即抛异常，release 下正文整层不渲染。
  testWidgets('帖子详情：同帖多楼层 seq 重复时全部正文正常渲染（GlobalKey 冲突回归）', (WidgetTester tester) async {
    final FakeLibrary lib = FakeLibrary(
      posts: <Post>[
        Post(
          id: 900,
          tid: 900900,
          title: '多卡片同seq帖',
          portrait: '',
          date: '2025-04-28',
          channel: '大佬贴吧扫书',
          postType: '扫书',
          postKind: '扫书',
          recommendFlag: 1,
          floorCount: 3,
          imageCount: 0,
          origin: 'builtin',
        ),
      ],
      floors: <int, List<FloorData>>{
        900: <FloorData>[
          for (int i = 1; i <= 3; i++)
            FloorData(
              floor: Floor(
                id: 900000 + i,
                postId: 900,
                seq: 1, // 同 seq 重复——回归目标
                content: '卡片 $i 的正文标记文本，各有不同。',
                charCount: 16,
              ),
              images: const <FloorImage>[],
            ),
        ],
      },
      entries: const <EntryRow>[],
      groups: const <BookGroup>[],
    );
    useSurface(tester);
    await tester.pumpWidget(testApp(FakeBookRepository(library: lib), initial: '/post/900'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    for (int i = 1; i <= 3; i++) {
      expect(find.textContaining('卡片 $i 的正文标记文本'), findsOneWidget, reason: '第 $i 张卡片正文应渲染');
    }
  });
}
