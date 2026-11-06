import 'dart:io';
import 'dart:ui' as ui;

import 'package:booksift/book_sources/forum_source.dart';
import 'package:booksift/app_router.dart';
import 'package:booksift/core/fonts/font_tokens.dart';
import 'package:booksift/book_sources/source_settings.dart';
import 'package:booksift/features/home/cards.dart';
import 'package:booksift/features/search/book_source_page.dart';
import 'package:booksift/features/search/search_page.dart';
import 'package:booksift/features/search/search_state.dart';
import 'package:booksift/theme/app_motion.dart';
import 'package:booksift/theme/book_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_book_repository.dart';
import '../support/harness.dart';
import 'online_search_test.dart' show selectSearchSource;

class _ForumClient extends ForumSourceClient {
  final List<String> queries = <String>[];
  @override
  Future<List<ForumBook>> search(
    Uri base,
    String query, {
    String cookie = '',
  }) async {
    queries.add(query);
    return [ForumBook('应用内书源结果', base.resolve('thread-1.html'))];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final String? font = Platform.environment['BOOKSIFT_UI_FONT'];
    if (font == null) return;
    final loader = FontLoader('Noto Sans CJK SC');
    loader.addFont(File(font).readAsBytes().then(ByteData.sublistView));
    await loader.load();
  });
  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    final String? directory = Platform.environment['BOOKSIFT_UI_SNAPSHOTS'];
    if (directory == null) return;
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final double width in [320.0, 390.0, 1280.0]) {
    testWidgets(
      'four sources share a control; actions swap without hiding results at $width',
      (tester) async {
        useSurface(tester, width: width);
        final client = _ForumClient();
        addTearDown(() => client.dio.close(force: true));
        final captureKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: captureKey,
            child: ProviderScope(
              overrides: <Override>[
                ...testOverrides(FakeBookRepository()),
                forumClientProvider.overrideWithValue(client),
                for (final source in ForumSource.values)
                  forumSettingsProvider(source).overrideWith(
                    (ref) async => ForumSourceSettings(
                      base: Uri.parse('https://forum.example/'),
                      cookie: 'session=valid',
                    ),
                  ),
              ],
              child: MaterialApp.router(
                theme: BookTheme.of(
                  Brightness.light,
                  Platform.environment['BOOKSIFT_UI_FONT'] == null
                      ? FontFamilySet.standard
                      : FontFamilySet.fromFamilyOf(
                          (role) => 'Noto Sans CJK SC',
                        ),
                ),
                routerConfig: createAppRouter(initialLocation: '/search?q='),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byTooltip('清除筛选'), findsOneWidget);
        final results = find.text('条件浏览');
        expect(results, findsOneWidget);
        final element = tester.element(results);
        await tester.tap(
          find.byKey(const ValueKey<String>('search-sources-collapsed')),
        );
        await tester.pumpAndSettle();
        expect(tester.element(results), same(element));
        expect(find.byTooltip('清除筛选'), findsNothing);
        expect(find.byTooltip('确认筛选'), findsNothing);
        expect(find.byTooltip('目录'), findsOneWidget);
        final control = tester.widget<SegmentedPill<SearchTab>>(
          find.byType(SegmentedPill<SearchTab>),
        );
        expect(control.options.map((option) => option.$1), SearchTab.values);
        await capture(tester, captureKey, 'unified-expanded-$width');
        await selectSearchSource(tester, '尚香书苑');
        if (width == 320) {
          tester.platformDispatcher.textScaleFactorTestValue = 1.6;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpAndSettle();
        }
        expect(find.byType(BookSourcePage), findsOneWidget);
        await tester.enterText(find.byType(TextField).first, '三体');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(client.queries, ['三体']);
        expect(find.text('应用内书源结果'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('search-sources-collapsed')),
          findsOneWidget,
        );
        expect(find.byTooltip('确认筛选'), findsOneWidget);
        expect(find.byTooltip('目录'), findsOneWidget);
        await capture(tester, captureKey, 'unified-results-$width');
        final motion = AppMotionTheme.of(
          tester.element(find.byType(SearchPage)),
        );
        expect(
          tester
              .widgetList<AnimatedSwitcher>(find.byType(AnimatedSwitcher))
              .any((widget) => widget.duration == motion.switch_.duration),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
