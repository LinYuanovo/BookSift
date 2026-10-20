import 'package:booksift/core/constants.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/features/content/content_detail_page.dart';
import 'package:booksift/features/home/cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_book_repository.dart';
import '../support/harness.dart';

// 端到端：帖子详情 → 点书名 chip → 书聚合页 → 点评价卡 → 进帖直达**该书所在楼层**。
//
// 复刻真机路径（多书帖每本书一个楼层、seq 全相同）：点回帖子时必须落到 floor_ref 指向的
// 那一楼，而不是同 seq 的首楼。这条路径的隐蔽失效点是 postDetailProvider 缓存命中
// （原帖页仍在导航栈上）导致 ref.listen 不触发、定位逻辑不执行。

/// 多书帖：两个楼层 seq 都是 1（不同 id），各属一本不同书。
FakeLibrary multiBookPost() {
  return FakeLibrary(
    posts: <Post>[
      Post(
        id: 700,
        tid: 700700,
        title: '扫书多书帖',
        portrait: '',
        date: '2025-04-28',
        channel: 'yy小说吧',
        postType: CategoryKind.scan,
        postKind: CategoryKind.scan,
        recommendFlag: 1,
        floorCount: 22,
        imageCount: 0,
        origin: Origin.builtin,
      ),
    ],
    floors: <int, List<FloorData>>{
      700: <FloorData>[
        // 前 20 楼铺垫（把目标楼层推到屏外，跳转必须滚动才可见）。
        for (int i = 1; i <= 20; i++)
          FloorData(
            floor: Floor(id: 700100 + i, postId: 700, seq: i, content: '铺垫第 $i 楼正文占位内容。', charCount: 13),
            images: const <FloorImage>[],
          ),
        FloorData(
          floor: const Floor(id: 700001, postId: 700, seq: 21, content: '第一本书甲的正文占位内容。', charCount: 13),
          images: const <FloorImage>[],
        ),
        FloorData(
          floor: const Floor(id: 700002, postId: 700, seq: 21, content: '第二本书乙的正文占位内容。', charCount: 13),
          images: const <FloorImage>[],
        ),
      ],
    },
    entries: const <EntryRow>[
      EntryRow(
        id: 1,
        name: '《甲书》',
        nameNorm: '甲书',
        channel: 'yy小说吧',
        category: CategoryKind.scan,
        origin: Origin.builtin,
        quality: 2,
        date: '2025-04-28',
        postRef: 700,
        floorRef: 700001,
        floorSeq: 21,
        floorText: '第一本书甲的正文占位内容。',
        bookGroupId: 1,
      ),
      EntryRow(
        id: 2,
        name: '《乙书》',
        nameNorm: '乙书',
        channel: 'yy小说吧',
        category: CategoryKind.scan,
        origin: Origin.builtin,
        quality: 2,
        date: '2025-04-28',
        postRef: 700,
        floorRef: 700002,
        floorSeq: 21,
        floorText: '第二本书乙的正文占位内容。',
        bookGroupId: 2,
      ),
    ],
    groups: const <BookGroup>[
      BookGroup(id: 1, nameNorm: '甲书', authorEffNorm: '', entryTotal: 1, distinctComment: 1),
      BookGroup(id: 2, nameNorm: '乙书', authorEffNorm: '', entryTotal: 1, distinctComment: 1),
    ],
  );
}

void main() {
  testWidgets('帖 → 书名 chip → 书聚合 → 点卡 → 直达该书楼层（非同 seq 首楼）', (WidgetTester tester) async {
    final FakeBookRepository repo = FakeBookRepository(library: multiBookPost());
    useSurface(tester);
    await tester.pumpWidget(testApp(repo, initial: '/post/700'));
    await tester.pumpAndSettle();

    // 帖内书目 chip：点《乙书》→ 书聚合页（乙书 groupId=2）。
    final Finder chipB = find.descendant(
      of: find.byType(PostBookChip),
      matching: find.textContaining('《乙书》'),
    );
    expect(chipB, findsOneWidget);
    await tester.tap(chipB);
    await tester.pumpAndSettle();

    // 书聚合页：点评价卡（整卡 onTap = 进原帖）→ 应直达乙书楼层。
    // 卡内正文预览回退楼层正文（comment 为空）→ 以该文案定位卡片。
    final Finder cardB = find.widgetWithText(AccentCard, '第二本书乙的正文占位内容。');
    expect(cardB, findsOneWidget, reason: '乙书评价卡（正文预览回退楼层正文）');
    await tester.tap(cardB);
    await tester.pumpAndSettle();

    // 回到帖子详情：应定位到乙书所在楼层（id=700002）。
    final ContentDetailPage page = tester.widget(find.byType(ContentDetailPage));
    expect(page.selection.initialFloorId, 700002, reason: '楼层锚点 = 条目 floor_ref（精确到书）');

    final ScrollPosition pos =
        Scrollable.of(tester.element(find.text('第二本书乙的正文占位内容。'))).position;
    expect(pos.pixels, greaterThan(0), reason: '确实滚到乙书那楼（非停首楼）');
  });
}


