import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:booksift/app_router.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/reading_session.dart';
import 'package:booksift/data/reading_session_provider.dart';
import 'package:booksift/data/repo/database_provider.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/data/repo/queries_providers.dart';
import 'package:booksift/data/seed_import.dart';
import 'package:booksift/data/seed_import_providers.dart';
import 'package:booksift/features/content/content_detail_page.dart';
import 'package:booksift/features/home/home_page.dart';
import 'package:booksift/theme/book_theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/harness.dart' show NoopSeedImporter;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full seed first content and persisted reading resume', (
    tester,
  ) async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'booksift-startup-',
    );
    final File file = File('${directory.path}/library.sqlite');
    final ByteData packed = await rootBundle.load(
      'assets/seed/seed_pack_lite_v1.zip',
    );
    final Archive archive = ZipDecoder().decodeBytes(
      packed.buffer.asUint8List(),
    );
    await file.writeAsBytes(archive.findFile('seed.db')!.content as List<int>);
    final AppDatabase database = AppDatabase(
      NativeDatabase.createInBackground(file),
    );
    ProviderContainer? container;
    try {
      Future<void> mount() async {
        container = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(database),
            queriesProvider.overrideWithValue(
              Queries(database, ftsMode: FtsMode.off),
            ),
            seedImporterProvider.overrideWithValue(NoopSeedImporter()),
            maintenanceEnabledProvider.overrideWithValue(false),
          ],
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container!,
            child: MaterialApp.router(
              theme: BookTheme.light,
              routerConfig: container!.read(appRouterProvider),
            ),
          ),
        );
      }

      final Stopwatch clock = Stopwatch()..start();
      int lastBeat = 0;
      int largestGap = 0;
      final Timer heartbeat = Timer.periodic(const Duration(milliseconds: 16), (
        _,
      ) {
        final int now = clock.elapsedMilliseconds;
        if (now - lastBeat > largestGap) largestGap = now - lastBeat;
        lastBeat = now;
      });
      await mount();
      final List<PostCardData> feed = await container!.read(
        homeFeedProvider.future,
      );
      await tester.pump();
      final int firstContent = clock.elapsedMilliseconds;
      expect(feed.length, 40);
      expect(find.text(feed.first.post.title!).evaluate(), isNotEmpty);
      await container!.read(rankTileTopProvider.future);
      await tester.pump();
      heartbeat.cancel();
      debugPrint(
        'BOOKSIFT_METRIC platform=${Platform.operatingSystem} first_content_ms=$firstContent largest_event_gap_ms=$largestGap',
      );
      if (const bool.fromEnvironment('BOOKSIFT_BENCHMARK_ONLY')) return;

      final PostCardData selected = feed.first;
      final ReadingSessionStore store = container!.read(readingSessionProvider);
      store.record(
        ReadingSession(
          savedAt: DateTime.now(),
          postId: selected.post.id,
          postTid: selected.post.tid,
          title: selected.post.title!,
          offset: 180,
        ),
      );
      await store.flush();
      await tester.pumpWidget(const SizedBox.shrink());
      container!.dispose();
      await mount();
      for (
        int attempt = 0;
        attempt < 100 && find.text('继续上次浏览？').evaluate().isEmpty;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('继续上次浏览？'), findsOneWidget);
      await tester.tap(find.text('继续浏览'));
      for (
        int attempt = 0;
        attempt < 100 && find.byType(ContentDetailPage).evaluate().isEmpty;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(ContentDetailPage), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull);
      debugPrint('BOOKSIFT_ACCEPTANCE resume_post=passed');
      await tester.pumpWidget(const SizedBox.shrink());
      container!.read(readingSessionProvider).record(ReadingSession(
        savedAt: DateTime.now(), offset: 500, homePages: 2,
      ));
      await container!.read(readingSessionProvider).flush();
      container!.dispose();
      await mount();
      for (int attempt = 0; attempt < 100 && find.text('继续上次浏览？').evaluate().isEmpty; attempt++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('继续上次浏览？'), findsOneWidget);
      await tester.tap(find.text('继续浏览'));
      await container!.read(homeFeedProvider.future);
      await tester.pumpAndSettle();
      expect(container!.read(homePageCountProvider), 2);
      final CustomScrollView homeScroll = tester.widget<CustomScrollView>(
        find.descendant(of: find.byType(HomePage), matching: find.byType(CustomScrollView)),
      );
      expect(homeScroll.controller!.offset, closeTo(500, 1));
      debugPrint('BOOKSIFT_ACCEPTANCE resume_home=passed');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      if (container != null) {
        await container!.read(readingSessionProvider).flush();
        container!.dispose();
      }
      await database.close();
      await directory.delete(recursive: true);
    }
  });
}
