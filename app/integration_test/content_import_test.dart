import 'dart:convert';
import 'dart:io';

import 'package:booksift/app_router.dart';
import 'package:booksift/content/content_draft.dart';
import 'package:booksift/content/content_store.dart';
import 'package:booksift/content/document_reader.dart';
import 'package:booksift/content/document_source.dart';
import 'package:booksift/core/fonts/font_service.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/database_provider.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/data/seed_import_providers.dart';
import 'package:booksift/features/content/book_detail_page.dart';
import 'package:booksift/features/content/content_detail_page.dart';
import 'package:booksift/features/content/content_editor_page.dart';
import 'package:booksift/theme/book_theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/harness.dart' show NoopSeedImporter, fakeFontService;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Linux 集成：390×844 竖屏视口下微信导入与帖子兜底→校对→回读', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    debugPrint('native-stage: create temporary database');
    final Directory directory = await Directory.systemTemp.createTemp(
      'booksift-native-import-',
    );
    final File databaseFile = File('${directory.path}/library.sqlite');
    final AppDatabase db = AppDatabase(NativeDatabase(databaseFile));
    final ContentStore store = ContentStore(db);
    final String sourceDirectory = const String.fromEnvironment(
      'BOOKSIFT_ACCEPTANCE_DIR',
      defaultValue: '/home/dev/code/BookSift/app/build/acceptance/wechat',
    );
    final File articleFile = File('$sourceDirectory/sample-1-offline.html');
    final ContentDraft article = const DocumentReader().read(
      bytes: await articleFile.readAsBytes(),
      fileName: 'sample-1-offline.html',
    );
    debugPrint('native-stage: real document parsed');
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        fontServiceProvider.overrideWith((Ref ref) => fakeFontService()),
        seedImporterProvider.overrideWithValue(NoopSeedImporter()),
        if (!const bool.fromEnvironment('BOOKSIFT_NATIVE_PICKER'))
          documentSourceProvider.overrideWithValue(
            _LocalDocumentSource(article),
          ),
      ],
    );
    bool closed = false;
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: BookTheme.light,
            routerConfig: container.read(appRouterProvider),
          ),
        ),
      );
      debugPrint('native-stage: first frame');
      await tester.pumpAndSettle();
      debugPrint('native-stage: homepage ready');
      await tester.tap(find.byTooltip('导入扫书'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('import-pick-file')));
      await tester.pumpAndSettle();
      for (
        int attempt = 0;
        attempt < 90 &&
            find.byKey(const Key('edit-post-title')).evaluate().isEmpty;
        attempt++
      ) {
        await tester.pump(const Duration(seconds: 1));
      }
      debugPrint('native-stage: document selected');
      expect(find.byType(ContentEditorPage), findsOneWidget);
      expect(find.textContaining('图片 21 张'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('edit-post-title')),
        '真实端到端导入校对',
      );
      await tester.tap(find.byKey(const Key('content-save')));
      await tester.pumpAndSettle();
      if (find.text('保留链接并保存').evaluate().isNotEmpty) {
        await tester.tap(find.text('保留链接并保存'));
        await tester.pumpAndSettle();
      }
      debugPrint('native-stage: import saved');
      expect(
        tester.takeException(),
        isNull,
        reason: 'portrait import save has no overflow',
      );
      expect(find.byType(ContentEditorPage), findsNothing);
      expect(find.byType(ContentDetailPage), findsOneWidget);
      final List<Post> posts = await db.select(db.posts).get();
      expect(posts, hasLength(1));
      final int postId = posts.single.id;
      final ContentDraft recovered = (await store.load(postId))!;
      expect(recovered.entries.single.name, '阴阳造化炉');
      expect(recovered.entries.single.author, '青烽不醉');
      expect(recovered.imageCount, 21);
      expect(recovered.entries.single.comment, contains('小说'));
      final NavigatorState navigator = tester.state<NavigatorState>(
        find.byType(Navigator).last,
      );
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => ContentEditorPage(postId: postId),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('edit-post-author')),
        '用户校对的书评人',
      );
      final Finder editorList = find.descendant(
        of: find.byType(ContentEditorPage),
        matching: find.byType(ListView),
      );
      await tester.dragUntilVisible(
        find.text('书目与评价'),
        editorList,
        const Offset(0, -350),
      );
      await tester.pumpAndSettle();
      if (find.byKey(const Key('edit-entry-author-0')).evaluate().isEmpty) {
        await tester.tap(find.text('1 · 阴阳造化炉'));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.byKey(const Key('edit-entry-author-0')));
      await tester.enterText(
        find.byKey(const Key('edit-entry-author-0')),
        '作者校对结果',
      );
      await tester.tap(find.byKey(const Key('content-save')));
      await tester.pumpAndSettle();
      final Queries queries = Queries(db);
      final SearchOutcome search = await queries.searchBooks(
        const SearchFilter(query: '阴阳造化炉'),
      );
      expect(search.page.total, 1);
      final BookEntry entry = await db.select(db.bookEntries).getSingle();
      final BookDetailData book = (await queries.bookDetail(
        entry.bookGroupId!,
      ))!;
      expect(book.group.authorDisplay, '作者校对结果');
      expect((await queries.postDetail(postId))!.post.author, '用户校对的书评人');
      expect(
        (await store.load(postId))!.rawDocument,
        await articleFile.readAsBytes(),
      );
      for (
        int attempt = 0;
        attempt < 30 && find.byType(PostBookChip).evaluate().isEmpty;
        attempt++
      ) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.byType(PostBookChip), findsOneWidget);
      await tester.tap(find.byType(PostBookChip).first);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'portrait book navigation has no overflow',
      );
      expect(find.byType(BookDetailPage), findsOneWidget);
      container.read(appRouterProvider).pop();
      await tester.pumpAndSettle();
      expect(find.byType(ContentDetailPage), findsOneWidget);
      container.read(appRouterProvider).go('/search?q=阴阳造化炉');
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'portrait search has no overflow',
      );
      container.read(appRouterProvider).go('/home');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('导入扫书'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('import-source-text')));
      const String fallbackText =
          '这是一段不包含可识别书名和作者的阅读讨论。\n\n'
          '请保留用户输入的全部正文。\n\n这是正文结尾。';
      await tester.enterText(
        find.byKey(const Key('import-source-text')),
        fallbackText,
      );
      await tester.ensureVisible(find.byKey(const Key('import-recognize')));
      await tester.tap(find.byKey(const Key('import-recognize')));
      await tester.pumpAndSettle();
      expect(find.textContaining('将作为帖子保存'), findsOneWidget);
      await tester.tap(find.byKey(const Key('content-save')));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'portrait fallback save has no overflow',
      );
      final List<Post> savedPosts = await db.select(db.posts).get();
      final Post fallbackPost = savedPosts.singleWhere(
        (Post post) => post.title == '这是一段不包含可识别书名和作者的阅读讨论。',
      );
      final ContentDraft fallbackDraft = (await store.load(fallbackPost.id))!;
      expect(fallbackDraft.entries, isEmpty);
      expect(
        fallbackDraft.floors
            .map((ContentFloorDraft floor) => floor.text)
            .join('\n\n'),
        fallbackText,
      );
      expect(find.byType(ContentDetailPage), findsOneWidget);
      expect(find.text(fallbackPost.title!), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await db.close();
      closed = true;
      final AppDatabase reopened = AppDatabase(NativeDatabase(databaseFile));
      try {
        final ContentDraft persisted = (await ContentStore(
          reopened,
        ).load(postId))!;
        expect(persisted.imageCount, 21);
        expect(persisted.entries.single.author, '作者校对结果');
        expect(persisted.author, '用户校对的书评人');
        expect(
          await reopened.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        await File('$sourceDirectory/native-e2e.json').writeAsString(
          jsonEncode(<String, Object?>{
            'passed': true,
            'postId': postId,
            'book': persisted.entries.single.name,
            'author': persisted.entries.single.author,
            'images': persisted.imageCount,
            'originalExact':
                persisted.rawDocument!.length == (await articleFile.length()),
            'databaseReopened': true,
          }),
        );
      } finally {
        await reopened.close();
      }
    } finally {
      if (!closed) {
        container.dispose();
        await db.close();
      }
      await directory.delete(recursive: true);
    }
  });
}

class _LocalDocumentSource implements DocumentSource {
  _LocalDocumentSource(this.draft);
  final ContentDraft draft;

  @override
  Future<ContentDraft?> pickDocument() async => draft;
  @override
  Future<ContentDraft> readUrl(String url) async => draft;
  @override
  Future<ContentImageDraft?> pickImage() async => null;
  @override
  Future<ContentDraft> preserveImages(ContentDraft draft) async => draft;
}
