import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/features/export/booklist_export.dart';
import 'package:booksift/features/export/export_sheet.dart';
import 'package:booksift/features/share/share_service.dart';
import 'package:booksift/theme/book_theme.dart';

// 书单导出（M3 P2-4）的测试替身与宿主。
//
// 纪律（app/test/TESTING.md §1/§3.1）：testWidgets 体内不得碰真实事件循环。
// 导出链路上唯一的真实异步是文件写/平台通道（file_picker / share_plus /
// path_provider），全部收在 [TextFileSink] 端口后面 → 注入 [FakeTextFileSink]
// （纯微任务，零 IO）。渲染器本身是纯函数，plain test() 直接断言。

/// 固定「当前时间」（文档时间戳 / 文件名断言的确定性来源；DateTime 无 const 构造器）。
final DateTime demoExportNow = DateTime(2026, 10, 13, 12);

/// 内存导出端口：记下每次 save/share 的内容、文件名、MIME、文案与 iPad 锚点。
final class FakeTextFileSink implements TextFileSink {
  FakeTextFileSink({
    this.saveOutcome = const ShareOutcome(
      ShareOutcomeKind.saved,
      path: r'C:\Users\x\Documents\booksift_export\booksift_booklist_20261013_120000.md',
    ),
    this.shareOutcome = const ShareOutcome(ShareOutcomeKind.shared),
  });

  /// 可改写的返回值（测「取消 / 不支持 / 失败」三态的 SnackBar 文案）。
  ShareOutcome saveOutcome;
  ShareOutcome shareOutcome;

  final List<String> savedContents = <String>[];
  final List<String> sharedContents = <String>[];
  final List<String> savedNames = <String>[];
  final List<String> sharedNames = <String>[];
  final List<String> savedMimes = <String>[];
  final List<String> sharedMimes = <String>[];
  String? shareText;
  Rect? shareOrigin;

  @override
  Future<ShareOutcome> save(String content, String fileName, String mimeType) async {
    savedContents.add(content);
    savedNames.add(fileName);
    savedMimes.add(mimeType);
    return saveOutcome;
  }

  @override
  Future<ShareOutcome> share(
    String content,
    String fileName,
    String mimeType, {
    String? text,
    Rect? origin,
  }) async {
    sharedContents.add(content);
    sharedNames.add(fileName);
    sharedMimes.add(mimeType);
    shareText = text;
    shareOrigin = origin;
    return shareOutcome;
  }
}

/// 收藏夹演示文档（书 ×2：一本含排雷计数、一本纯净；帖 ×1：排雷帖）。
BooklistDoc demoFavoritesDoc() => BooklistDoc(
      kind: BooklistDocKind.favorites,
      heading: '我的收藏书单',
      generatedAt: demoExportNow,
      books: <ExportBook>[
        const ExportBook(
          title: '十日终焉',
          author: '杀虫队队员',
          channels: <String>['yy小说吧', '大佬专栏'],
          dateRange: '2024-12-05 ~ 2025-04-28',
          entryCount: 2,
          recommendations: <ExportRecommendation>[
            ExportRecommendation(
              recommender: '推荐人2009',
              date: '2025-04-28',
              channel: 'yy小说吧',
              comment: '无限流佳作，副本设计很有想法，群像写得扎实。',
            ),
          ],
        ),
        const ExportBook(
          title: '逍遥小书生',
          author: '荣荣',
          channels: <String>['yy小说吧'],
          dateRange: '2024-06-11 ~ 2025-03-30',
          entryCount: 2,
          avoidCount: 1,
          recommendations: <ExportRecommendation>[
            ExportRecommendation(
              recommender: '推荐人2013',
              date: '2025-03-30',
              channel: 'yy小说吧',
              comment: '轻松日常向，主角讨喜，适合下饭。',
            ),
          ],
        ),
      ],
      posts: const <ExportPost>[
        ExportPost(
          title: '排雷：这几本千万别踩',
          author: '避雷使者',
          channel: '哀伤雪刃',
          date: '2025-04-20',
          avoid: true,
        ),
      ],
    );

/// 单书演示文档（1 推荐 + 1 排雷且无推荐语，与 demo_data 904 组同形状）。
BooklistDoc demoBookDoc() => BooklistDoc(
      kind: BooklistDocKind.singleBook,
      heading: '《逍遥小书生》推荐单',
      generatedAt: demoExportNow,
      books: <ExportBook>[
        ExportBook(
          title: '逍遥小书生',
          author: '荣荣',
          channels: <String>['yy小说吧', '哀伤雪刃'],
          dateRange: '2024-06-11 ~ 2025-03-30',
          entryCount: 2,
          avoidCount: 1,
          recommendations: <ExportRecommendation>[
            ExportRecommendation(
              recommender: '推荐人2013',
              date: '2025-03-30',
              channel: 'yy小说吧',
              comment: '轻松日常向，主角讨喜，适合下饭，更新也稳定。',
            ),
            ExportRecommendation(
              recommender: '推荐人2014',
              date: '2024-06-11',
              channel: '哀伤雪刃',
              avoid: true,
            ),
          ],
        ),
      ],
    );

/// 空收藏文档（生成器空态文案用例）。
BooklistDoc demoEmptyDoc() => BooklistDoc(
      kind: BooklistDocKind.favorites,
      heading: '我的收藏书单',
      generatedAt: demoExportNow,
    );

/// 弹层测试宿主：点按钮走**真入口** [showBooklistExportSheet]（顺带覆盖 modal 弹层形态）。
Widget exportSheetHost(BooklistDoc doc, {TextFileSink? sink}) {
  final BooklistExportService service = BooklistExportService(sink ?? FakeTextFileSink());
  return MaterialApp(
    theme: BookTheme.light,
    home: Scaffold(
      body: Builder(
        builder: (BuildContext context) => Center(
          child: TextButton(
            onPressed: () => showBooklistExportSheet(context, doc, service: service),
            child: const Text('打开弹层'),
          ),
        ),
      ),
    ),
  );
}

/// 打开弹层并等入场动画收敛。
Future<void> openExportSheet(
  WidgetTester tester,
  BooklistDoc doc, {
  TextFileSink? sink,
}) async {
  await tester.pumpWidget(exportSheetHost(doc, sink: sink));
  await tester.tap(find.text('打开弹层'));
  await tester.pumpAndSettle();
}

/// 弹层内 Finder（把断言收窄到 sheet 子树，避免与宿主 Scaffold 混淆）。
Finder inExportSheet(Finder matching) =>
    find.descendant(of: find.byType(BooklistExportSheet), matching: matching);

/// 设定视口（与 support/harness.dart 同参；就地实现以免拖入 app_router →
/// settings_page/update 编译依赖 —— 弹层测试不需要全 App 挂具）。
void useSurface(WidgetTester tester, {double width = 390, double height = 844, double dpr = 3}) {
  tester.view.physicalSize = Size(width * dpr, height * dpr);
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
}

/// 推进 SnackBar 的 4s 自动消失 timer（同 harness.dismissSnackBars）。
Future<void> dismissSnackBars(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

/// 弹层当前预览文本（mono 预览容器里唯一的 Text）。
String previewTextOf(WidgetTester tester) {
  final Finder preview = inExportSheet(
    find.descendant(of: find.byType(SingleChildScrollView), matching: find.textContaining('生成时间')),
  );
  return tester.widget<Text>(preview).data!;
}
