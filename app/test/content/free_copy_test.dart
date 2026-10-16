import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/icons.dart';
import 'package:booksift/features/content/content_detail_page.dart';
import 'package:booksift/features/content/detail_slot.dart';
import 'package:booksift/features/content/rich_text.dart';
import 'package:booksift/features/search/search_page.dart';
import 'package:booksift/features/search/search_state.dart';
import 'package:booksift/theme/app_colors.dart';

import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import '../support/harness.dart';

// P1-6 阅读流自由复制（多选文本复制）：长按/图标进入选择模式 → 逐楼层 SelectionArea
// 跨段多选 → 系统工具栏复制；选择模式下书名/链接点击手势暂停，退出手势恢复。
// 任务 6：进出选择模式各弹一条 toast（showAppToast），楼层流**不再**有常驻提示条
// ——正文不被下压；toast 自行淡出，不需要关闭钮（AppBar 开关仍是同一出口）。
//
// 口径出处：
//   · 原型 §3.1 P1-6「长按进入选择模式」；§5.6 帖子详情富文本管线（书名再搜/链接复制不得破坏）；
//   · 逐楼层包 SelectionArea 而非整流单包：Android 上 SelectableRegion 对水平拖拽即时取胜
//     （eagerVictoryOnDrag，framework selectable_region.dart _initTouchGestureRecognizer），
//     整包会让上下帖 PageView 横滑在正文区全面失效；逐楼层包裹时非正文区仍可翻页；
//   · 选择模式书名降级为纯文本 span（《》原样可复制）→ find.text 精确匹配不到独立 Text，
//     recognizer 一律 null；
//   · toast 与 SnackBar 一样是假时钟 Timer（停留 2.2s）：showAppToast 保证同一时刻
//     至多一条，用例收尾一次 dismissSnackBars 即可推进（TESTING.md §3.5）。
//
// 全部 testWidgets 零真实 IO（FakeBookRepository + harness 三哨兵，app/test/TESTING.md §3.1）。

void main() {
  group('P1-6 自由复制', () {
    late FakeBookRepository repo;

    setUp(() {
      repo = FakeBookRepository(library: demoLibrary());
    });

    testWidgets('AppBar 开关进入/退出选择模式 + 逐楼层 SelectionArea + AppBar 零 Material Icon',
        (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, home: const ContentDetailPage(selection: PostSelection(postId: 7))));
      await tester.pumpAndSettle();

      // 阅读模式：无 SelectionArea，书名 = 独立可点 span（InkWell 承载的 Text）。
      // 限定正文：头部书目 chip 也渲染《篡水浒》（PostBookChip）。
      expect(find.byType(SelectionArea), findsNothing);
      expect(
        find.descendant(
          of: find.byType(FloorRichText),
          matching: find.text('《篡水浒》'),
        ),
        findsOneWidget,
      );

      // 切换钮 = 设计 SVG copy.svg（20px → 非 -s 档）；AppBar（home 挂具不可 pop → 无返回键）
      // 零 Material Icon，恰两枚 SVG（自由复制 + 更多）。
      final Finder toggle = find.byTooltip('自由复制');
      expect(toggle, findsOneWidget);
      expect(
        tester.widget<AppIcon>(find.descendant(of: toggle, matching: find.byType(AppIcon))).assetName,
        'assets/icons/copy.svg',
      );
      expect(find.descendant(of: find.byType(AppBar), matching: find.byType(Icon)), findsNothing);
      expect(find.descendant(of: find.byType(AppBar), matching: find.byType(SvgPicture)), findsNWidgets(2));

      // 进入选择模式：帖 7 两楼 → 两个 SelectionArea；书名 WidgetSpan+InkWell 已撤。
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.byType(SelectionArea), findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byType(FloorRichText),
          matching: find.text('《篡水浒》'),
        ),
        findsNothing,
        reason: '书名降级为可选纯文本 span（头部书目 chip 不算正文）',
      );
      expect(find.textContaining('本期主推'), findsOneWidget, reason: '楼层富文本仍在（Text.rich）');

      // 退出钮换 close.svg，AppBar 仍零 Material Icon。
      final Finder exit = find.byTooltip('退出自由复制');
      expect(exit, findsOneWidget);
      expect(
        tester.widget<AppIcon>(find.descendant(of: exit, matching: find.byType(AppIcon))).assetName,
        'assets/icons/close.svg',
      );
      expect(find.descendant(of: find.byType(AppBar), matching: find.byType(Icon)), findsNothing);

      // 退出 → 回阅读模式，手势 span 复原（头部书目 chip 恒在，限定正文断言）。
      await tester.tap(exit);
      await tester.pumpAndSettle();
      expect(find.byType(SelectionArea), findsNothing);
      expect(
        find.descendant(
          of: find.byType(FloorRichText),
          matching: find.text('《篡水浒》'),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('自由复制'), findsOneWidget);
      await dismissSnackBars(tester);
    });

    testWidgets('长按楼层正文 → 进入选择模式（P1-6 主入口）', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, initial: '/post/7'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectionArea), findsNothing);

      // 长按二楼正文（纯文本 + URL span 均无长按手势 → 楼层入口胜出；一楼中心可能落在
      // 书名 InkWell 上——长按那里 = 复制书名，既有 MI-3 语义，不属本入口）。
      await tester.longPress(find.textContaining('原帖备份'));
      await tester.pumpAndSettle();

      expect(find.byType(SelectionArea), findsNWidgets(2));
      expect(find.byTooltip('退出自由复制'), findsOneWidget);
      await dismissSnackBars(tester);
    });

    testWidgets('选择模式书名/URL 点击手势暂停；退出恢复 §5.6 再搜闭环', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, initial: '/post/7'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('自由复制'));
      await tester.pumpAndSettle();

      // 结构性暂停：无 WidgetSpan 残留；书名 span（《》原样、bookname 色保持）与 URL span
      // （info 色下划线保持）recognizer 一律 null。
      TextSpan? spanOf(String floorMatch, String spanMatch, {bool prefix = false}) {
        final Text rich = tester.widget<Text>(find.textContaining(floorMatch));
        TextSpan? found;
        bool hasWidgetSpan = false;
        rich.textSpan!.visitChildren((InlineSpan span) {
          if (span is WidgetSpan) {
            hasWidgetSpan = true;
          }
          if (span is TextSpan &&
              (prefix ? (span.text ?? '').startsWith(spanMatch) : span.text == spanMatch)) {
            found = span;
          }
          return true;
        });
        expect(hasWidgetSpan, isFalse, reason: '选择模式不得残留 WidgetSpan+InkWell 书名');
        return found;
      }

      final TextSpan? bookSpan = spanOf('本期主推', '《篡水浒》');
      expect(bookSpan, isNotNull);
      expect(bookSpan!.recognizer, isNull, reason: '书名点击再搜暂停');
      expect(bookSpan.style?.color, AppColors.light.bookname);

      final TextSpan? urlSpan = spanOf('原帖备份', 'https://', prefix: true);
      expect(urlSpan, isNotNull);
      expect(urlSpan!.recognizer, isNull, reason: '链接点击复制暂停');
      expect(urlSpan.style?.color, AppColors.light.info);

      // 行为性暂停：点首楼正文（中心覆盖书名 span 区域）→ 不触发书名再搜，仍留在详情页。
      await tester.tap(find.textContaining('本期主推'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchPage), findsNothing);
      expect(find.byType(ContentDetailPage), findsOneWidget);

      // 退出选择模式 → InkWell 书名 span 回归，点击恢复「书名 → 搜索台预填自动提交」闭环。
      await tester.tap(find.byTooltip('退出自由复制'));
      await tester.pumpAndSettle();
      final Finder bodyBook = find.descendant(
        of: find.byType(FloorRichText),
        matching: find.text('《篡水浒》'),
      );
      expect(bodyBook, findsOneWidget);

      await tester.tap(bodyBook);
      await tester.pumpAndSettle();
      final SearchDraft draft = containerOf(tester, find.byType(SearchPage)).read(searchDraftProvider);
      expect(draft.filter.query, '篡水浒');
      expect(draft.submitted, isTrue);
      await dismissSnackBars(tester);
    });

    testWidgets('embedded 右槽形态：开关与长按入口同样生效（§9.7 双形态兼容）', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(
        repo,
        home: const ContentDetailPage(selection: PostSelection(postId: 7), embedded: true),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('自由复制'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectionArea), findsNWidgets(2));

      await tester.tap(find.byTooltip('退出自由复制'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectionArea), findsNothing);

      // 长按入口在 embedded 形态同样生效。
      await tester.longPress(find.textContaining('原帖备份'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectionArea), findsNWidgets(2));
      await dismissSnackBars(tester);
    });

    testWidgets('选择模式不吞上下帖横滑（逐楼层包裹：非正文区拖拽仍翻页）', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(
        repo,
        home: const ContentDetailPage(
          selection: PostSelection(postId: 7, siblings: <int>[7, 14403], position: 0),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('帖子详情 1/2'), findsOneWidget);

      await tester.tap(find.byTooltip('自由复制'));
      await tester.pumpAndSettle();

      // 从头部标题（SelectionArea 之外）横滑 → PageView 正常翻页。
      await tester.drag(find.text('【扫书】yy小说吧四月下旬合集'), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('帖子详情 2/2'), findsOneWidget);
      expect(find.textContaining('排雷帖'), findsOneWidget);

      // 选择模式为页面级状态：翻页后新帖（14403 单楼）仍处于选择模式。
      expect(find.byType(SelectionArea), findsOneWidget);
      await dismissSnackBars(tester);
    });

    testWidgets('任务 6 反馈：进出各一条 toast，楼层流无固定提示条（正文不被下压）', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, initial: '/post/7'));
      await tester.pumpAndSettle();

      // 阅读模式：进/出两条文案都不在。
      expect(find.text('自由复制：长按楼层正文选择文字'), findsNothing);
      expect(find.text('自由复制模式：长按楼层正文选择文字'), findsNothing);

      // 进入：弹一条用法说明 toast；固定提示条已删除。
      await tester.tap(find.byTooltip('自由复制'));
      await tester.pumpAndSettle();
      expect(find.text('自由复制：长按楼层正文选择文字'), findsOneWidget, reason: '进入 toast 用法说明');
      expect(
        find.text('自由复制模式：长按楼层正文选择文字'),
        findsNothing,
        reason: '楼层流顶部固定提示条已删除（不再把正文下压）',
      );
      expect(find.byType(SelectionArea), findsNWidgets(2));

      // toast 自行淡出后页面不残留提示；选择模式本身仍在（页面级状态）。
      await dismissSnackBars(tester);
      expect(find.text('自由复制：长按楼层正文选择文字'), findsNothing, reason: 'toast 自行消失');
      expect(find.byType(SelectionArea), findsNWidgets(2), reason: '选择模式持续有效');

      // 退出：再弹一条 toast（AppBar 开关是同一出口）；SelectionArea 撤销。
      await tester.tap(find.byTooltip('退出自由复制'));
      await tester.pumpAndSettle();
      expect(find.text('已退出自由复制'), findsOneWidget, reason: '退出 toast');
      expect(find.byType(SelectionArea), findsNothing);
      await dismissSnackBars(tester);
      expect(find.text('已退出自由复制'), findsNothing, reason: 'toast 自行淡出，无需关闭钮');
    });
  });

  // 需求 3（用户口径）：**电脑上帖子详情默认就能自由复制**，不必先点「自由复制模式」；
  // 且单击书名/链接仍然可用（书名/链接并回文本流但保留 recognizer）。
  // 触屏端行为不变（默认不选中，长按进模式——否则 SelectionArea 会抢走横滑翻页）。
  group('桌面档：帖子详情随时可自由复制', () {
    late FakeBookRepository repo;
    setUp(() => repo = FakeBookRepository(library: demoLibrary()));

    testWidgets('Windows：默认逐楼层 SelectionArea；书名可整段复制且单击仍能搜索', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        useSurface(tester, width: 1440, height: 900);
        await tester.pumpWidget(
          testApp(repo, home: const ContentDetailPage(selection: PostSelection(postId: 7))),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SelectionArea), findsNWidgets(2), reason: '未点开关就已可选中');
        expect(find.byTooltip('自由复制'), findsOneWidget, reason: 'AppBar 开关仍在（切成「纯复制」档）');

        bool hasWidgetSpan = false;
        TextSpan? bookSpan;
        final Text rich = tester.widget<Text>(find.textContaining('本期主推'));
        rich.textSpan!.visitChildren((InlineSpan span) {
          if (span is WidgetSpan) {
            hasWidgetSpan = true;
          }
          if (span is TextSpan && (span.text ?? '').startsWith('《篡水浒》')) {
            bookSpan = span;
          }
          return true;
        });
        expect(hasWidgetSpan, isFalse, reason: '书名不能再用 WidgetSpan+InkWell，否则整段复制会漏掉书名');
        expect(bookSpan, isNotNull, reason: '书名并回文本流');
        expect(bookSpan!.recognizer, isNotNull, reason: '桌面档单击书名仍要能跳搜索');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Android：默认仍不可选中（保持长按进模式）', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(
        testApp(repo, home: const ContentDetailPage(selection: PostSelection(postId: 7))),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SelectionArea), findsNothing);
    });
  });
}
