import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/icons.dart';
import 'package:booksift/features/export/booklist_export.dart';
import 'package:booksift/features/export/export_sheet.dart';
import 'package:booksift/features/home/cards.dart';
import 'package:booksift/features/share/share_service.dart';

import 'support.dart';

// 书单导出弹层（M3 P2-4）：格式分段切换、前 20 行 mono 预览、保存/分享两条出口
// 与 SnackBar 人话。零真实 IO：导出端口注入 FakeTextFileSink（TESTING.md §3.1）。

void main() {
  group('弹层结构', () {
    testWidgets('标题/元信息/格式分段/预览/文件名提示/两个出口按钮齐活', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      await openExportSheet(tester, demoFavoritesDoc());

      expect(inExportSheet(find.text('导出书单')), findsOneWidget);
      expect(
        inExportSheet(find.text('生成时间: 2026-10-13 12:00 · 共 2 本书 · 共 1 帖')),
        findsOneWidget,
        reason: '头部副行 = doc.metaLine',
      );
      // 格式分段（cards.dart SegmentedPill 复用）。
      expect(inExportSheet(find.byType(SegmentedPill<BooklistFormat>)), findsOneWidget);
      expect(inExportSheet(find.text('Markdown')), findsOneWidget);
      expect(inExportSheet(find.text('TXT')), findsOneWidget);
      // 预览首行 + 出口按钮（本机非移动端 → 「保存文件」口径）。
      expect(previewTextOf(tester), startsWith('# 我的收藏书单'));
      expect(find.text('保存文件'), findsOneWidget);
      expect(find.text('分享'), findsOneWidget);
      expect(find.text('存到文档目录'), findsNothing, reason: '桌面口径不谎称文档目录兜底');
      expect(inExportSheet(find.text('将导出: booksift_booklist_20261013_120000.md')), findsOneWidget);
    });

    testWidgets('图标守卫：弹层内零 Material Icon，关闭钮走设计 SVG', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      await openExportSheet(tester, demoFavoritesDoc());

      expect(inExportSheet(find.byType(Icon)), findsNothing);
      expect(inExportSheet(find.byType(SvgPicture)), findsWidgets);
      expect(
        tester.widget<AppIcon>(inExportSheet(find.byType(AppIcon))).name,
        'close',
      );
    });
  });

  group('格式切换与预览', () {
    testWidgets('切到 TXT：预览换成对齐纯文本，文件名换 .txt', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      await openExportSheet(tester, demoFavoritesDoc());

      await tester.tap(inExportSheet(find.text('TXT')));
      await tester.pumpAndSettle();
      final String preview = previewTextOf(tester);
      expect(preview, startsWith('我的收藏书单'));
      expect(preview, contains('═'), reason: 'TXT 文档头分隔线');
      expect(preview, contains('作\u3000者: 杀虫队队员'), reason: '全角标签对齐');
      expect(preview, isNot(contains('# ')), reason: '不再是 Markdown');
      expect(inExportSheet(find.text('将导出: booksift_booklist_20261013_120000.txt')), findsOneWidget);

      await tester.tap(inExportSheet(find.text('Markdown')));
      await tester.pumpAndSettle();
      expect(previewTextOf(tester), startsWith('# 我的收藏书单'));
    });

    testWidgets('预览只给前 20 行，超出部分给行数提示', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      // 30 本书 → 渲染远超 20 行。
      final BooklistDoc big = BooklistDoc(
        kind: BooklistDocKind.favorites,
        heading: '我的收藏书单',
        generatedAt: demoExportNow,
        books: <ExportBook>[
          for (int i = 0; i < 30; i++)
            ExportBook(title: '测试书名$i', recommendations: const <ExportRecommendation>[]),
        ],
      );
      await openExportSheet(tester, big);

      final String preview = previewTextOf(tester);
      final List<String> lines = preview.split('\n');
      expect(lines.length, BooklistExportSheet.previewLineLimit + 1, reason: '20 行 + 1 行截断提示');
      expect(lines.last, contains('……（共 '));
      expect(lines.last, contains(' 行，导出文件包含全部内容）'));
      expect(preview, isNot(contains('测试书名29')), reason: '尾部内容不进预览');
    });

    testWidgets('空收藏文档也能开弹层：预览给空态文案', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      await openExportSheet(tester, demoEmptyDoc());
      expect(previewTextOf(tester), contains(kEmptyFavoritesMessage));
      expect(previewTextOf(tester), contains(kBooklistAttribution));
    });
  });

  group('保存 / 分享出口（注入 FakeTextFileSink）', () {
    testWidgets('保存文件：sink 收到当前格式全文 + .md 文件名 + text/markdown', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      final FakeTextFileSink sink = FakeTextFileSink();
      final BooklistDoc doc = demoFavoritesDoc();
      await openExportSheet(tester, doc, sink: sink);

      await tester.tap(find.text('保存文件'));
      await tester.pumpAndSettle();

      expect(sink.savedContents.single, renderMarkdown(doc));
      expect(sink.savedNames.single, 'booksift_booklist_20261013_120000.md');
      expect(sink.savedMimes.single, 'text/markdown');
      expect(find.textContaining('已保存'), findsOneWidget);
      await dismissSnackBars(tester);
    });

    testWidgets('切 TXT 后保存：内容与扩展名同步切换', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      final FakeTextFileSink sink = FakeTextFileSink();
      final BooklistDoc doc = demoFavoritesDoc();
      await openExportSheet(tester, doc, sink: sink);

      await tester.tap(inExportSheet(find.text('TXT')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存文件'));
      await tester.pumpAndSettle();

      expect(sink.savedContents.single, renderText(doc));
      expect(sink.savedNames.single, endsWith('.txt'));
      expect(sink.savedMimes.single, 'text/plain');
      await dismissSnackBars(tester);
    });

    testWidgets('分享：sink 收到全文 + 文案 heading；SnackBar 报「已交给系统分享面板」', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      final FakeTextFileSink sink = FakeTextFileSink();
      final BooklistDoc doc = demoBookDoc();
      await openExportSheet(tester, doc, sink: sink);

      await tester.tap(find.text('分享'));
      await tester.pumpAndSettle();

      expect(sink.sharedContents.single, renderMarkdown(doc));
      expect(sink.sharedNames.single, endsWith('.md'));
      expect(sink.shareText, '《逍遥小书生》推荐单');
      expect(sink.shareOrigin, isNotNull, reason: 'iPad popover 锚点');
      expect(find.text('已交给系统分享面板'), findsOneWidget);
      await dismissSnackBars(tester);
    });

    testWidgets('取消保存：SnackBar 报「已取消保存」', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      final FakeTextFileSink sink = FakeTextFileSink()
        ..saveOutcome = const ShareOutcome(ShareOutcomeKind.cancelled, message: '已取消保存');
      await openExportSheet(tester, demoFavoritesDoc(), sink: sink);

      await tester.tap(find.text('保存文件'));
      await tester.pumpAndSettle();
      expect(find.text('已取消保存'), findsOneWidget);
      await dismissSnackBars(tester);
    });

    testWidgets('分享不可用降级保存：SnackBar 给落盘路径人话', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      final FakeTextFileSink sink = FakeTextFileSink()
        ..shareOutcome = const ShareOutcome(
          ShareOutcomeKind.saved,
          path: r'C:\Users\x\Documents\booksift_export\booksift_booklist_20261013_120000.md',
          message: r'系统分享不可用（unavailable），已改为保存到：C:\Users\x\Documents',
        );
      await openExportSheet(tester, demoFavoritesDoc(), sink: sink);

      await tester.tap(find.text('分享'));
      await tester.pumpAndSettle();
      expect(find.textContaining('系统分享不可用'), findsOneWidget);
      await dismissSnackBars(tester);
    });

    testWidgets('关闭钮收起弹层', (WidgetTester tester) async {
      useSurface(tester, height: 1600);
      await openExportSheet(tester, demoFavoritesDoc());

      await tester.tap(inExportSheet(find.byTooltip('关闭')));
      await tester.pumpAndSettle();
      expect(find.byType(BooklistExportSheet), findsNothing);
    });
  });
}
