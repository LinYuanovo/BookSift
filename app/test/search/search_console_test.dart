/// M3 搜索页收尾测试：本地搜索视图零 Material Icon（图标 SVG 化，设计 02 搜索台屏
/// index.html id=scr-search:1268–1352）+ 搜索结果导出书单入口（P2-4 另一半）。
///
/// 分组与边界（TESTING.md §1/§3）：
///  · 「导出文档构造」plain test() —— buildSearchResultDoc / stripHighlightMarkers
///    纯函数，直接断言字段映射与缺省诚实口径；
///  · 其余 testWidgets —— FakeBookRepository（纯内存微任务）+ searchExportServiceProvider
///    注入 FakeTextFileSink（零真实 IO）+ mock 剪贴板平台通道；假时钟区内无真实异步。
library;

import 'package:booksift/core/icons.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/features/export/booklist_export.dart';
import 'package:booksift/features/export/export_sheet.dart';
import 'package:booksift/features/search/search_page.dart';
import 'package:booksift/features/search/search_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../export/support.dart' show FakeTextFileSink, previewTextOf;
import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import '../support/harness.dart';
import 'online_search_test.dart' show mockClipboard;

/// SearchPage 子树内的 Material Icon（守卫目标：恒为 0）。
Finder pageMaterialIcons() =>
    find.descendant(of: find.byType(SearchPage), matching: find.byType(Icon));

/// SearchPage 子树内全部 AppIcon 的资产名。
Iterable<String> pageIconAssets(WidgetTester tester) => tester
    .widgetList<AppIcon>(find.descendant(of: find.byType(SearchPage), matching: find.byType(AppIcon)))
    .map((AppIcon i) => i.assetName);

Widget searchApp(FakeBookRepository repo, {String initial = '/search', TextFileSink? sink}) =>
    testApp(repo, initial: initial, extraOverrides: <Override>[
      if (sink != null)
        searchExportServiceProvider.overrideWithValue(BooklistExportService(sink)),
    ]);

void main() {
  // ── 导出文档构造（纯函数，plain test） ─────────────────────────────────

  group('buildSearchResultDoc / stripHighlightMarkers（纯函数）', () {
    test('高亮标记剥离：`[词]` → 词（Queries snippet 约定 → 导出纯文本）', () {
      expect(stripHighlightMarkers('前[十日终焉]后[a]b[]'), '前十日终焉后ab');
      expect(stripHighlightMarkers('无标记'), '无标记');
    });

    test('GroupHit → ExportBook：字段诚实映射，投影外字段留空不造假', () {
      const GroupHit hit = GroupHit(
        groupId: 901,
        name: '《十日终焉》',
        nameNorm: '十日终焉',
        author: '杀虫队队员',
        hitCount: 2,
        recommendCount: 1,
        avoidCount: 1,
        latestDate: '2025-04-28',
        snippet: '本期主推《篡水浒》，另有[十日终焉]值得一看',
        preview: '本期主推《篡水浒》，另有[十日终焉]值得一看',
        channels: <String>['yy小说吧', '大佬专栏'],
        bestEntryId: 2009,
        bestFlag: -1,
      );
      final BooklistDoc doc = buildSearchResultDoc(
        const SearchOutcome(page: Paged<GroupHit>(items: <GroupHit>[hit], total: 1)),
        query: ' 十日终焉 ',
        now: DateTime(2026, 10, 13, 12),
      );

      expect(doc.kind, BooklistDocKind.favorites);
      expect(doc.heading, '「十日终焉」搜索结果书单', reason: 'query trim 后入题');
      final ExportBook book = doc.books.single;
      expect(book.title, '十日终焉', reason: '去书名号（渲染器负责套回）');
      expect(book.author, '杀虫队队员');
      expect(book.channels, <String>['yy小说吧', '大佬专栏']);
      expect(book.dateRange, '2025-04-28', reason: '结果行只有最近日期，单日期不谎称跨度');
      expect(book.entryCount, 1, reason: '「共 N 条推荐」= recommendCount');
      expect(book.avoidCount, 1);
      final ExportRecommendation rec = book.recommendations.single;
      expect(rec.comment, '本期主推《篡水浒》，另有十日终焉值得一看');
      expect(rec.avoid, isTrue, reason: 'bestFlag<0 → 排雷标记');
      expect(rec.recommender, isNull, reason: 'GroupHit 未投影推荐人 → 留空');
      expect(rec.date, isNull);
      expect(rec.channel, isNull);

      final String md = renderMarkdown(doc);
      expect(md, contains('### 《十日终焉》'));
      expect(md, contains('⚠ 排雷标记'));
      expect(md, contains(kBooklistAttribution));
    });

    test('空关键词（条件浏览）→ 标题不带「」；作者/摘要缺省 → 留空', () {
      const GroupHit bare = GroupHit(
        groupId: null,
        name: '散条目书',
        nameNorm: '散条目书',
        hitCount: 1,
        recommendCount: 1,
        avoidCount: 0,
        channels: <String>[],
        bestEntryId: 1,
        bestFlag: 1,
      );
      final BooklistDoc doc = buildSearchResultDoc(
        const SearchOutcome(page: Paged<GroupHit>(items: <GroupHit>[bare], total: 1)),
        query: '  ',
      );
      expect(doc.heading, '搜索结果书单');
      final ExportBook book = doc.books.single;
      expect(book.author, isNull);
      expect(book.dateRange, isNull);
      expect(book.recommendations.single.comment, isNull);
      expect(book.recommendations.single.avoid, isFalse);
      expect(renderMarkdown(doc), contains('（暂无推荐语）'), reason: '不造假占位');
    });
  });

  // ── 搜索台/结果页 UI（testWidgets：内存 fake，零真实 IO） ─────────────────

  group('搜索页零 Material Icon 守卫 + 图标语义（设计 02 屏）', () {
    late FakeBookRepository repo;
    setUp(() => repo = FakeBookRepository(library: demoLibrary()));

    testWidgets('搜索台：字段=search·16 / 历史行=clock·16，SearchPage 子树零 Icon',
        (WidgetTester tester) async {
      await repo.addHistory(const SearchFilter(query: '十日终焉'));
      useSurface(tester);
      await tester.pumpWidget(searchApp(repo));
      await tester.pumpAndSettle();

      expect(find.text('搜索历史'), findsOneWidget);
      expect(pageMaterialIcons(), findsNothing,
          reason: '结构图标单一出口 = assets/icons SVG（AppIcon）');
      final Iterable<String> assets = pageIconAssets(tester);
      expect(assets, contains('assets/icons/search.svg'), reason: '搜索字段图标（index.html:1281）');
      expect(assets, contains('assets/icons/clock.svg'), reason: '历史行图标（index.html:1311）');
    });

    testWidgets('联想行：search SVG + 点联想直接提交出结果', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(searchApp(repo));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '十日');
      await tester.pump(const Duration(milliseconds: 250)); // 联想 debounce（TESTING.md §3.5）
      await tester.pumpAndSettle();

      expect(find.text('联想'), findsOneWidget);
      expect(find.text('《十日终焉》'), findsWidgets, reason: '联想行（设计 .sg 行 :1289）');
      expect(pageMaterialIcons(), findsNothing);
      expect(pageIconAssets(tester), contains('assets/icons/search.svg'));

      await tester.tap(find.text('《十日终焉》').first);
      await tester.pumpAndSettle();
      final ProviderContainer container = containerOf(tester, find.byType(SearchPage));
      expect(container.read(searchDraftProvider).submitted, isTrue);
      expect(container.read(searchDraftProvider).filter.query, '十日终焉');
      expect(find.text('1 结果'), findsOneWidget);
      expect(pageMaterialIcons(), findsNothing, reason: '结果态守卫同样为零');
    });

    testWidgets('清除钮：close SVG，点击=清空并回搜索台', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(searchApp(repo, initial: '/search?q=%E5%8D%81%E6%97%A5%E7%BB%88%E7%84%89'));
      await tester.pumpAndSettle();

      final Finder clearBtn = find.byTooltip('清空并回搜索台');
      expect(clearBtn, findsOneWidget);
      expect(
        tester.widget<AppIcon>(find.descendant(of: clearBtn, matching: find.byType(AppIcon))).assetName,
        'assets/icons/close.svg',
      );
      expect(pageMaterialIcons(), findsNothing);

      await tester.tap(clearBtn);
      await tester.pumpAndSettle();
      final ProviderContainer container = containerOf(tester, find.byType(SearchPage));
      expect(container.read(searchDraftProvider).submitted, isFalse);
      expect(find.text('搜索历史'), findsOneWidget, reason: '回搜索台');
      expect(find.text('十日终焉'), findsWidgets, reason: '提交写入的历史行在场');
    });

    testWidgets('历史行：clock SVG + 点击复现 + 长按复制关键词 + 左滑删除', (WidgetTester tester) async {
      await repo.addHistory(const SearchFilter(query: '十日终焉'));
      await repo.addHistory(const SearchFilter(query: '逍遥小书生'));
      final List<String> copied = mockClipboard(tester);
      useSurface(tester);
      await tester.pumpWidget(searchApp(repo));
      await tester.pumpAndSettle();

      expect(pageIconAssets(tester), contains('assets/icons/clock.svg'));
      expect(pageMaterialIcons(), findsNothing);

      // 点历史行 = 复现条件直接出结果（§5.3）。
      await tester.tap(find.widgetWithText(InkWell, '十日终焉'));
      await tester.pumpAndSettle();
      final ProviderContainer container = containerOf(tester, find.byType(SearchPage));
      expect(container.read(searchDraftProvider).submitted, isTrue);
      expect(container.read(searchDraftProvider).filter.query, '十日终焉');

      // 回搜索台做长按/左滑回归。
      await tester.tap(find.byTooltip('清空并回搜索台'));
      await tester.pumpAndSettle();

      await tester.longPress(find.widgetWithText(InkWell, '十日终焉'));
      await tester.pumpAndSettle();
      expect(copied, <String>['十日终焉']);
      expect(find.text('关键词已复制到剪贴板'), findsOneWidget);
      await dismissSnackBars(tester);

      expect(repo.history, hasLength(2));
      await tester.drag(find.widgetWithText(InkWell, '十日终焉'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(repo.history, hasLength(1), reason: '左滑删除落库');
      expect(repo.history.single.query, '逍遥小书生');
      expect(pageMaterialIcons(), findsNothing);
    });

    testWidgets('结果态：export=external SVG 入口在场；计数圆点非 Material Icon', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(searchApp(repo, initial: '/search?q=%E5%8D%81%E6%97%A5%E7%BB%88%E7%84%89'));
      await tester.pumpAndSettle();

      expect(find.text('1 结果'), findsOneWidget);
      final Finder exportBtn = find.byTooltip('导出书单');
      expect(exportBtn, findsOneWidget);
      expect(
        tester.widget<AppIcon>(find.descendant(of: exportBtn, matching: find.byType(AppIcon))).assetName,
        'assets/icons/external.svg',
      );
      expect(pageMaterialIcons(), findsNothing, reason: '推荐/排雷圆点 = Container 色块（dot-sep 语汇）');
    });

    testWidgets('空结果：隐藏导出入口，空态走 search SVG 线稿', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(searchApp(repo, initial: '/search?q=%E4%B8%8D%E5%AD%98%E5%9C%A8%E4%B9%A6%E5%90%8Dxyz'));
      await tester.pumpAndSettle();

      expect(find.textContaining('相关的书'), findsOneWidget);
      expect(find.byTooltip('导出书单'), findsNothing, reason: '空结果无导出意义');
      expect(pageMaterialIcons(), findsNothing);
      expect(pageIconAssets(tester), contains('assets/icons/search.svg'));
    });
  });

  // ── 导出入口接线（fake sink，零真实 IO） ────────────────────────────────

  group('搜索结果导出（P2-4）', () {
    late FakeBookRepository repo;
    setUp(() => repo = FakeBookRepository(library: demoLibrary()));

    testWidgets('点导出 → 弹层预览含书单标题与书名；保存文件走 fake sink（MD 口径）',
        (WidgetTester tester) async {
      final FakeTextFileSink sink = FakeTextFileSink();
      useSurface(tester);
      await tester.pumpWidget(
          searchApp(repo, initial: '/search?q=%E5%8D%81%E6%97%A5%E7%BB%88%E7%84%89', sink: sink));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('导出书单'));
      await tester.pumpAndSettle();
      expect(find.byType(BooklistExportSheet), findsOneWidget);

      // 预览（前 20 行 mono）：标题 + 书名 + 计数元信息。
      final String preview = previewTextOf(tester);
      expect(preview, contains('# 「十日终焉」搜索结果书单'));
      expect(preview, contains('《十日终焉》'));
      expect(preview, contains('共 1 本书'));

      // 保存：sink 收到 MD 全文 + 文件名/MIME 口径（真 IO 在 TextFileSink 端口后，已 fake）。
      await tester.tap(find.text('保存文件'));
      await tester.pumpAndSettle();
      final String saved = sink.savedContents.single;
      expect(saved, contains('# 「十日终焉」搜索结果书单'));
      expect(saved, contains('《十日终焉》'));
      expect(saved, contains('杀虫队队员'), reason: '作者来自 GroupHit 投影');
      expect(saved, contains(kBooklistAttribution));
      expect(sink.savedNames.single, startsWith('booksift_booklist_'));
      expect(sink.savedNames.single, endsWith('.md'));
      expect(sink.savedMimes.single, 'text/markdown');
      expect(find.textContaining('已保存'), findsOneWidget);
      await dismissSnackBars(tester);
    });
  });
}
