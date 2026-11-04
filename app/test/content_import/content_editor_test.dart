import 'package:booksift/content/content_draft.dart';
import 'package:booksift/content/document_source.dart';
import 'package:booksift/features/content/content_editor_page.dart';
import 'package:booksift/features/content/content_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_book_repository.dart';
import '../support/harness.dart';
import 'editor_support.dart';

void main() {
  const ContentDraft existing = ContentDraft(
    postId: 1,
    baseline: 'baseline',
    title: '既有帖子',
    author: '原发帖人',
    channel: 'yy小说吧',
    date: '2026-11-04',
    floors: <ContentFloorDraft>[ContentFloorDraft(id: 1, text: '既有帖子完整正文')],
    entries: <ContentEntryDraft>[
      ContentEntryDraft(
        id: 1,
        name: '既有书目',
        author: '原小说作者',
        comment: '完整原书评',
        recommender: '原发帖人',
        channel: 'yy小说吧',
        date: '2026-11-04',
      ),
    ],
  );

  Future<void> pumpEditor(
    WidgetTester tester,
    MemoryContentEditorRepository editor, {
    bool import = false,
    double width = 390,
  }) async {
    useSurface(tester, width: width, height: 900);
    await tester.pumpWidget(
      testApp(
        FakeBookRepository(),
        home: ContentEditorPage(postId: import ? null : 1),
        extraOverrides: <Override>[
          contentEditorRepositoryProvider.overrideWithValue(editor),
          documentSourceProvider.overrideWithValue(MemoryDocumentSource()),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('导入入口识别长文并允许作为普通帖子保存', (WidgetTester tester) async {
    final MemoryContentEditorRepository editor =
        MemoryContentEditorRepository();
    await pumpEditor(tester, editor, import: true);
    await tester.enterText(
      find.byKey(const Key('import-source-text')),
      '原始讨论\n\n真实正文，没有可辨认的书目，结尾不得丢失。',
    );
    await tester.ensureVisible(find.byKey(const Key('import-recognize')));
    await tester.tap(find.byKey(const Key('import-recognize')));
    await tester.pumpAndSettle();
    expect(find.textContaining('将作为帖子保存'), findsOneWidget);
    await tester.tap(find.byKey(const Key('content-save')));
    await tester.pumpAndSettle();
    expect(editor.saved!.entries, isEmpty);
    expect(editor.saved!.floors.last.text, contains('结尾不得丢失'));
    await dismissSnackBars(tester);
  });

  testWidgets('既有帖子同一编辑器保存标题、书名、作者、正文和评价', (WidgetTester tester) async {
    final MemoryContentEditorRepository editor = MemoryContentEditorRepository(
      draft: existing,
    );
    await pumpEditor(tester, editor, width: 1180);
    await tester.enterText(find.byKey(const Key('edit-post-title')), '用户改后的标题');
    await tester.enterText(find.byKey(const Key('edit-post-author')), '新书评人');
    await tester.ensureVisible(find.byKey(const Key('edit-floor-0')));
    await tester.enterText(find.byKey(const Key('edit-floor-0')), '修改后的完整正文');
    await tester.ensureVisible(find.byKey(const Key('edit-entry-name-0')));
    await tester.enterText(find.byKey(const Key('edit-entry-name-0')), '校对后书名');
    await tester.enterText(
      find.byKey(const Key('edit-entry-author-0')),
      '校对后小说作者',
    );
    await tester.ensureVisible(find.byKey(const Key('edit-entry-comment-0')));
    await tester.enterText(
      find.byKey(const Key('edit-entry-comment-0')),
      '修改后的长评完整末尾',
    );
    await tester.tap(find.byKey(const Key('content-save')));
    await tester.pumpAndSettle();
    expect(editor.saved!.postId, 1);
    expect(editor.saved!.title, '用户改后的标题');
    expect(editor.saved!.floors.single.text, '修改后的完整正文');
    expect(editor.saved!.entries.single.name, '校对后书名');
    expect(editor.saved!.entries.single.author, '校对后小说作者');
    expect(editor.saved!.entries.single.recommender, '新书评人');
    expect(editor.saved!.entries.single.comment, '修改后的长评完整末尾');
    await dismissSnackBars(tester);
  });

  testWidgets('保存失败保留所有草稿，取消修改需要确认', (WidgetTester tester) async {
    final MemoryContentEditorRepository editor = MemoryContentEditorRepository(
      draft: existing,
    )..failSave = true;
    await pumpEditor(tester, editor);
    await tester.enterText(find.byKey(const Key('edit-post-title')), '尚未保存的草稿');
    await tester.tap(find.byKey(const Key('content-save')));
    await tester.pumpAndSettle();
    expect(find.text('保存失败，草稿仍在'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('edit-post-title')))
          .controller!
          .text,
      '尚未保存的草稿',
    );
    await tester.tap(find.byTooltip('取消编辑'));
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存内容？'), findsOneWidget);
    await tester.tap(find.text('返回继续编辑'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('edit-post-title')), findsOneWidget);
  });

  testWidgets('已有帖子详情更多菜单有统一编辑入口', (WidgetTester tester) async {
    useSurface(tester);
    await tester.pumpWidget(
      testApp(
        FakeBookRepository(),
        initial: '/post/7',
        extraOverrides: [
          contentEditorRepositoryProvider.overrideWithValue(
            MemoryContentEditorRepository(draft: existing),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ContentDetailPage), findsOneWidget);
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑帖子'));
    await tester.pumpAndSettle();
    expect(find.byType(ContentEditorPage), findsOneWidget);
    expect(find.text('既有帖子'), findsOneWidget);
  });

  for (final double width in <double>[320, 390, 720, 1180]) {
    testWidgets('统一编辑布局在 $width 宽度无溢出', (WidgetTester tester) async {
      await pumpEditor(
        tester,
        MemoryContentEditorRepository(draft: existing),
        width: width,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
