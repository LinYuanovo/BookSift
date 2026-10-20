import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/constants.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/features/content/content_detail_page.dart';
import 'package:booksift/features/content/detail_slot.dart';
import 'package:booksift/features/content/rich_text.dart';

import '../support/fake_book_repository.dart';
import '../support/harness.dart';

// 任务 2：目录跳转 / 书签恢复定位到未构建楼层。
//
// testWidgets 零真实 IO（TESTING.md §1）：FakeBookRepository 内存语料、**无图**
// （避免 CachedNetworkImage 触真实网络/磁盘缓存）；无图帖的 _maybeRefreshImages
// 在读 appDatabaseProvider 之前就返回，故不触 harness 的真库哨兵。
//
// 注意：详情页头部有「N楼」楼层计数文本，与 FloorHeader 的「N楼」同形 ——
// 一律用 [floorHeader] 按 widget 类型定位，不能用 find.text('40楼')。

/// [floors] 楼长帖（每楼一行正文；40 楼约 3.8 屏 → 末楼在懒构建窗外）。
FakeLibrary longPost({required int floors}) {
  return FakeLibrary(
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
}

/// 楼层头（按 widget 类型 + seq，避开详情页头部的「N楼」计数文本）。
Finder floorHeader(int seq) => find.byWidgetPredicate(
  (Widget w) => w is FloorHeader && w.seq == seq,
);

/// 该楼层所在的楼层流 ListView（按祖先取，避免命中路由栈里上一页的列表）。
Finder floorList(int seq) => find.ancestor(
  of: floorHeader(seq),
  matching: find.byType(ListView),
);

/// 跳转落位断言：楼层号可见，且落位精确。
///
/// 锚点 key 挂在楼层**正文** Padding 上（楼层头是它的上一个兄弟），故
/// alignment=0.05 → 「楼层头底边」落在视口顶部 5% 处；末段楼层受 maxScrollExtent
/// 夹取（下面没有更多内容可滚），此时「已滚到底」就是可达的最佳落点。
void expectFloorLanded(WidgetTester tester, int seq) {
  final Finder header = floorHeader(seq);
  expect(header, findsOneWidget, reason: '$seq 楼应已构建进树');
  final Finder list = floorList(seq);
  expect(list, findsOneWidget);
  final Rect viewport = tester.getRect(list);
  final Rect r = tester.getRect(header);
  final Rect label = tester.getRect(
    find.descendant(of: header, matching: find.byType(Text)),
  );
  expect(label.top, greaterThanOrEqualTo(viewport.top - 0.5), reason: '$seq 楼号须在视口内');
  expect(label.bottom, lessThanOrEqualTo(viewport.bottom + 0.5), reason: '$seq 楼号须在视口内');

  final ScrollPosition pos = Scrollable.of(tester.element(header)).position;
  if (pos.pixels < pos.maxScrollExtent - 0.5) {
    expect(
      r.bottom,
      closeTo(viewport.top + viewport.height * 0.05, 2.0),
      reason: 'alignment 0.05 须精确生效（比例估算旧实现在楼层高度差异大时会偏）',
    );
  } else {
    expect(
      pos.pixels,
      closeTo(pos.maxScrollExtent, 0.5),
      reason: '末段楼层：落点被 maxScrollExtent 夹取，须已滚到底',
    );
    expect(r.top, greaterThanOrEqualTo(viewport.top - 0.5), reason: '末楼整块在视口内');
    expect(r.bottom, lessThanOrEqualTo(viewport.bottom + 0.5), reason: '末楼整块在视口内');
  }
}

/// 目录弹层内滚到 [seq] 楼条目并点击（弹层自身也是懒列表）。
Future<void> tapTocEntry(WidgetTester tester, int seq) async {
  await tester.tap(find.text('目录'));
  await tester.pumpAndSettle();
  final Finder sheet = find.byType(BottomSheet);
  expect(sheet, findsOneWidget);
  final Finder entry = find.descendant(of: sheet, matching: find.text('$seq楼'));
  await tester.dragUntilVisible(
    entry,
    find.descendant(of: sheet, matching: find.byType(Scrollable)),
    const Offset(0, -300),
  );
  await tester.tap(entry);
  await tester.pumpAndSettle();
  expect(find.byType(BottomSheet), findsNothing, reason: '点击后弹层关闭');
}

void main() {
  testWidgets('40 楼帖点目录最后一楼：目标楼层头进视口并落到底部最佳位', (WidgetTester tester) async {
    final FakeBookRepository repo = FakeBookRepository(
      library: longPost(floors: 40),
    );
    useSurface(tester);
    await tester.pumpWidget(testApp(repo, initial: '/post/900'));
    await tester.pumpAndSettle();

    // 跳转前：末楼在懒构建窗外（不在树），首楼在视口顶部。
    expect(floorHeader(40), findsNothing, reason: 'ListView 懒构建：40 楼尚未进树');
    expect(floorHeader(1), findsOneWidget);

    await tapTocEntry(tester, 40);

    expectFloorLanded(tester, 40);
    expect(floorHeader(1), findsNothing, reason: '已滚离视口（确实发生了跳转）');
  });

  testWidgets('目录跳中段楼层：alignment 0.05 精确生效（未构建楼层也能定位）', (WidgetTester tester) async {
    final FakeBookRepository repo = FakeBookRepository(
      library: longPost(floors: 40),
    );
    useSurface(tester);
    await tester.pumpWidget(testApp(repo, initial: '/post/900'));
    await tester.pumpAndSettle();
    expect(floorHeader(30), findsNothing, reason: '30 楼初始未构建');

    await tapTocEntry(tester, 30);

    expectFloorLanded(tester, 30);
  });

  testWidgets('书签恢复复用同一路径：initialFloorSeq 指向未构建楼层也能定位', (WidgetTester tester) async {
    final FakeBookRepository repo = FakeBookRepository(
      library: longPost(floors: 40),
    );
    await repo.togglePostBookmark(postRef: 900, title: '长楼帖', floorSeq: 25);
    useSurface(tester);
    await tester.pumpWidget(testApp(repo, initial: '/profile'));
    await tester.pumpAndSettle();
    expect(floorHeader(25), findsNothing, reason: '跳转前 25 楼未构建');

    await tester.tap(find.textContaining('「长楼帖」'));
    await tester.pumpAndSettle();

    expectFloorLanded(tester, 25);
  });

  testWidgets('定位后 cacheExtent 复原：长帖不常驻全量构建', (WidgetTester tester) async {
    final FakeBookRepository repo = FakeBookRepository(
      library: longPost(floors: 40),
    );
    useSurface(tester);
    await tester.pumpWidget(testApp(repo, initial: '/post/900'));
    await tester.pumpAndSettle();

    await tapTocEntry(tester, 30);

    expectFloorLanded(tester, 30);
    expect(
      tester.widget<ListView>(floorList(30)).cacheExtent,
      isNull,
      reason: '落位动画结束后须复原为框架默认（1e5 常驻会全量构建整帖）',
    );
    expect(floorHeader(1), findsNothing, reason: '远端楼层回到未构建态');
  });

  // ── 多书帖楼层精确定位（Task 1）：同帖多楼层 seq 相同，只有 floor.id 能唯一定位 ──
  testWidgets('同 peer seq 的两楼：initialFloorId 精确定位到目标楼（不被 seq 抢先落到首楼）',
      (WidgetTester tester) async {
    // 铺垫 29 楼（seq 1..29），末尾两楼 seq 均为 30（「大佬贴吧扫书」每卡片一记），
    // id 不同 —— 目标 id=901002 在最末，需滚动才可见。
    final List<FloorData> floors = <FloorData>[
      for (int i = 1; i <= 29; i++)
        FloorData(
          floor: Floor(id: 902000 + i, postId: 901, seq: i, content: '铺垫第 $i 楼正文占位内容。', charCount: 13),
          images: const <FloorImage>[],
        ),
      FloorData(
        floor: const Floor(id: 901001, postId: 901, seq: 30, content: '第一本书甲的正文占位内容。', charCount: 13),
        images: const <FloorImage>[],
      ),
      FloorData(
        floor: const Floor(id: 901002, postId: 901, seq: 30, content: '第二本书乙的正文占位内容。', charCount: 13),
        images: const <FloorImage>[],
      ),
    ];
    final FakeLibrary lib = FakeLibrary(
      posts: <Post>[
        Post(
          id: 901,
          tid: 901901,
          title: '扫书多书帖',
          portrait: '',
          date: '2025-04-28',
          channel: '大佬专栏',
          postType: CategoryKind.scan,
          postKind: CategoryKind.scan,
          recommendFlag: 1,
          floorCount: floors.length,
          imageCount: 0,
          origin: Origin.builtin,
        ),
      ],
      floors: <int, List<FloorData>>{901: floors},
      entries: const <EntryRow>[],
      groups: const <BookGroup>[],
    );
    final FakeBookRepository repo = FakeBookRepository(library: lib);
    useSurface(tester);
    await tester.pumpWidget(testApp(
      repo,
      home: const ContentDetailPage(
        selection: PostSelection(postId: 901, initialFloorId: 901002),
      ),
    ));
    await tester.pumpAndSettle();

    // 定位到 id=901002 那一楼（内容「第二本」），而非 seq 抢先命中的首楼（「第一本」）。
    expect(find.text('第二本书乙的正文占位内容。'), findsOneWidget);
    final ScrollPosition pos =
        Scrollable.of(tester.element(find.text('第二本书乙的正文占位内容。'))).position;
    expect(pos.pixels, greaterThan(0), reason: '确实滚到了第二楼（非停首楼）');
  });
}
