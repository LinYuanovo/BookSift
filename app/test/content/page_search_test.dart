import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/constants.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/features/content/rich_text.dart';
import 'package:booksift/theme/app_colors.dart';

import '../support/fake_book_repository.dart';
import '../support/harness.dart';

// 任务 4：⋮「页内搜索」（VSCode 风格）—— AppBar 下方搜索条：输入即搜（IGNORE_CASE
// 字面量）、i/n 计数、上/下环形循环 + 滚动到所在楼层、当前命中 accent 染底、
// 普通命中琥珀、清除/关闭语义、0 命中「0/0」+ 按钮禁用、窄槽不溢出。
//
// 计数与着色同口径（rich_text.countSearchHits：只数纯文本段，书名/URL span 不参与），
// 故 plain test 直接断言口径函数；widget 测试断言搜索条交互与 span 染色。
// 全部 testWidgets 零真实 IO（语料无图，TESTING.md §3.1）。

Post _post({required int id, required int floors, String title = '页内搜索帖'}) => Post(
  id: id,
  tid: 900900,
  title: title,
  portrait: '',
  date: '2025-04-28',
  channel: 'yy小说吧',
  postType: CategoryKind.scan,
  postKind: CategoryKind.scan,
  recommendFlag: 1,
  floorCount: floors,
  imageCount: 0,
  origin: Origin.builtin,
);

FloorData _floor(int id, int seq, String text) => FloorData(
  floor: Floor(id: id, postId: 900, seq: seq, content: text, charCount: text.length),
  images: const <FloorImage>[],
);

/// 三楼层语料：「苹果」共 4 处命中（甲楼×2、乙楼×1、丙楼×1），全在纯文本段。
FakeLibrary _searchLibrary() => FakeLibrary(
  posts: <Post>[_post(id: 900, floors: 3)],
  floors: <int, List<FloorData>>{
    900: <FloorData>[
      _floor(900001, 1, '甲楼 苹果 香蕉 苹果 收'),
      _floor(900002, 2, '乙楼 苹果派 好看'),
      _floor(900003, 3, '丙楼 香蕉苹果 结束'),
    ],
  },
  entries: const <EntryRow>[],
  groups: const <BookGroup>[],
);

/// 40 楼层语料：仅 30 楼含「目标词」（懒构建窗外，验证搜索定位复用 _scrollToFloor）。
FakeLibrary _longLibrary() => FakeLibrary(
  posts: <Post>[_post(id: 900, floors: 40, title: '长楼帖')],
  floors: <int, List<FloorData>>{
    900: <FloorData>[
      for (int i = 1; i <= 40; i++)
        _floor(
          900000 + i,
          i,
          i == 30 ? '第 30 层 目标词 出现' : '第 $i 层正文内容占位，长度差不多。',
        ),
    ],
  },
  entries: const <EntryRow>[],
  groups: const <BookGroup>[],
);

/// ⋮「更多」→「页内搜索」展开搜索条。
Future<void> openSearchBar(WidgetTester tester) async {
  await tester.tap(find.byTooltip('更多'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('页内搜索'));
  await tester.pumpAndSettle();
}

/// 某楼层富文本里带底色（background != null）的命中 span（按出现顺序）。
List<TextSpan> hitSpans(WidgetTester tester, String floorMarker) {
  final Text rich = tester.widget<Text>(find.textContaining(floorMarker));
  final List<TextSpan> out = <TextSpan>[];
  rich.textSpan!.visitChildren((InlineSpan span) {
    if (span is TextSpan && span.style?.background != null) {
      out.add(span);
    }
    return true;
  });
  return out;
}

Finder floorHeader(int seq) => find.byWidgetPredicate(
  (Widget w) => w is FloorHeader && w.seq == seq,
);

/// 搜索条按钮（find.byTooltip 命中的是 RawTooltip 节点，IconButton 是其祖先）。
IconButton barButton(WidgetTester tester, String tooltip) =>
    tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip(tooltip),
        matching: find.byType(IconButton),
      ),
    );

/// Paint 底色比较走 toARGB32：Paint.color 经 Float32 存储往返，double 精度尾差
/// 会让同色 Color 对象判不等（toString 打印四位小数看不出差异）。
int argb(Color c) => c.toARGB32();

void main() {
  group('countSearchHits（与 FloorRichText 着色同口径）', () {
    test('空搜索词 = 0', () {
      expect(countSearchHits('苹果香蕉', ''), 0);
    });

    test('IGNORE_CASE 字面量计数', () {
      expect(countSearchHits('Hello hello HELLO', 'hello'), 3);
    });

    test('书名 span 不参与（不着色也就不计数）', () {
      expect(countSearchHits('《苹果》好吃 苹果', '苹果'), 1);
    });

    test('URL span 不参与', () {
      expect(countSearchHits('备份 https://tieba.baidu.com/p/1 完', 'tieba'), 0);
    });

    test('相邻命中非重叠计数', () {
      expect(countSearchHits('苹果苹果', '苹果'), 2);
    });
  });

  group('页内搜索条', () {
    late FakeBookRepository repo;
    setUp(() => repo = FakeBookRepository(library: _searchLibrary()));

    testWidgets('⋮ 展开搜索条：0 命中「0/0」且上/下禁用', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, initial: '/post/900'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);

      await openSearchBar(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('0/0'), findsOneWidget);
      expect(barButton(tester, '上一个命中').onPressed, isNull);
      expect(barButton(tester, '下一个命中').onPressed, isNull);
    });

    testWidgets('输入即搜：计数 1/4，当前命中 accent 染底、其余琥珀', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, initial: '/post/900'));
      await tester.pumpAndSettle();
      await openSearchBar(tester);

      await tester.enterText(find.byType(TextField), '苹果');
      await tester.pumpAndSettle();

      expect(find.text('1/4'), findsOneWidget);
      // 甲楼两处命中：第 1 处 = 当前（accent 底 + onAccent 字色），第 2 处普通琥珀。
      final List<TextSpan> f1 = hitSpans(tester, '甲楼');
      expect(f1, hasLength(2));
      expect(argb(f1[0].style!.background!.color), argb(AppColors.light.accent));
      expect(f1[0].style!.color, AppColors.light.onAccent);
      expect(argb(f1[1].style!.background!.color), argb(AppColors.light.highlight));
      // 非焦点楼层的命中一律普通琥珀。
      expect(
        argb(hitSpans(tester, '乙楼').single.style!.background!.color),
        argb(AppColors.light.highlight),
      );
    });

    testWidgets('下一个环形循环：同楼移焦 → 跨楼 → 回卷；上一个反绕', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, initial: '/post/900'));
      await tester.pumpAndSettle();
      await openSearchBar(tester);
      await tester.enterText(find.byType(TextField), '苹果');
      await tester.pumpAndSettle();

      // 2/4：仍在甲楼，当前色移到第 2 处。
      await tester.tap(find.byTooltip('下一个命中'));
      await tester.pumpAndSettle();
      expect(find.text('2/4'), findsOneWidget);
      final List<TextSpan> f1 = hitSpans(tester, '甲楼');
      expect(argb(f1[0].style!.background!.color), argb(AppColors.light.highlight));
      expect(argb(f1[1].style!.background!.color), argb(AppColors.light.accent));

      // 3/4 → 乙楼当前；4/4 → 丙楼当前。
      await tester.tap(find.byTooltip('下一个命中'));
      await tester.pumpAndSettle();
      expect(find.text('3/4'), findsOneWidget);
      expect(
        argb(hitSpans(tester, '乙楼').single.style!.background!.color),
        argb(AppColors.light.accent),
      );
      await tester.tap(find.byTooltip('下一个命中'));
      await tester.pumpAndSettle();
      expect(find.text('4/4'), findsOneWidget);

      // 回卷 1/4；上一个反绕回 4/4。
      await tester.tap(find.byTooltip('下一个命中'));
      await tester.pumpAndSettle();
      expect(find.text('1/4'), findsOneWidget);
      await tester.tap(find.byTooltip('上一个命中'));
      await tester.pumpAndSettle();
      expect(find.text('4/4'), findsOneWidget);
    });

    testWidgets('无命中：「0/0」+ 按钮禁用 + 零高亮', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, initial: '/post/900'));
      await tester.pumpAndSettle();
      await openSearchBar(tester);

      await tester.enterText(find.byType(TextField), '不存在的词');
      await tester.pumpAndSettle();

      expect(find.text('0/0'), findsOneWidget);
      expect(barButton(tester, '下一个命中').onPressed, isNull);
      expect(hitSpans(tester, '甲楼'), isEmpty);
    });

    testWidgets('清除 = 清空输入、搜索条保留、高亮消失', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, initial: '/post/900'));
      await tester.pumpAndSettle();
      await openSearchBar(tester);
      await tester.enterText(find.byType(TextField), '苹果');
      await tester.pumpAndSettle();
      expect(find.text('1/4'), findsOneWidget);

      await tester.tap(find.byTooltip('清除搜索词'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget, reason: '搜索条保留');
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
      expect(find.text('0/0'), findsOneWidget);
      expect(hitSpans(tester, '甲楼'), isEmpty);
    });

    testWidgets('关闭 = 收起搜索条并清除高亮', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, initial: '/post/900'));
      await tester.pumpAndSettle();
      await openSearchBar(tester);
      await tester.enterText(find.byType(TextField), '苹果');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('关闭页内搜索'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      // 楼层流里 searchWord 已传空（高亮清除）。
      for (final FloorRichText w in tester.widgetList<FloorRichText>(
        find.byType(FloorRichText),
      )) {
        expect(w.searchWord, isEmpty);
        expect(w.searchFocusIndex, -1);
      }
    });

    testWidgets('命中在懒构建窗外的远端楼层：输入即定位（复用 _scrollToFloor）', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(
        testApp(FakeBookRepository(library: _longLibrary()), initial: '/post/900'),
      );
      await tester.pumpAndSettle();
      expect(floorHeader(30), findsNothing, reason: '30 楼初始未构建');

      await openSearchBar(tester);
      await tester.enterText(find.byType(TextField), '目标词');
      await tester.pumpAndSettle();

      expect(find.text('1/1'), findsOneWidget);
      expect(floorHeader(30), findsOneWidget, reason: '已滚动定位到命中楼层');
      // 落位：楼层号在列表视口内。锚点 key 挂楼层正文（楼层头是上一兄弟），
      // alignment 0.05 → 头的 space4 上留白会探出视口顶，故按头内**文字标签**
      // 断言（toc_jump_test.expectFloorLanded 同口径）。
      final Rect viewport = tester.getRect(
        find.ancestor(of: floorHeader(30), matching: find.byType(ListView)),
      );
      final Rect label = tester.getRect(
        find.descendant(of: floorHeader(30), matching: find.byType(Text)),
      );
      expect(label.top, greaterThanOrEqualTo(viewport.top - 0.5));
      expect(label.bottom, lessThanOrEqualTo(viewport.bottom + 0.5));
    });

    testWidgets('embedded 窄右槽（320dp）：搜索条不溢出', (WidgetTester tester) async {
      useSurface(tester, width: 320);
      await tester.pumpWidget(testApp(repo, initial: '/post/900'));
      await tester.pumpAndSettle();
      await openSearchBar(tester);
      expect(tester.takeException(), isNull, reason: '窄槽展开搜索条即溢出');

      await tester.enterText(find.byType(TextField), '苹果');
      await tester.pumpAndSettle();
      expect(find.text('1/4'), findsOneWidget, reason: '窄槽下计数仍可见');
      expect(tester.takeException(), isNull, reason: '窄槽输入后溢出');
    });
  });
}
