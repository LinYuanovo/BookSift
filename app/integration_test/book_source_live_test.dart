import 'dart:convert';
import 'dart:io';

import 'package:booksift/book_sources/forum_source.dart';
import 'package:booksift/book_sources/source_settings.dart';
import 'package:booksift/features/search/book_source_page.dart';
import 'package:booksift/theme/book_theme.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const bool enabled = bool.fromEnvironment('BOOKSIFT_LIVE_ACCEPTANCE');
  testWidgets(
    'live forum search, purchased attachment and native save dialog',
    (tester) async {
      final Map<String, dynamic> fixture =
          jsonDecode(
                await rootBundle.loadString('assets/seed/live_acceptance.json'),
              )
              as Map<String, dynamic>;
      final List<dynamic> scenarios = fixture['scenarios'] as List<dynamic>;
      for (final Map<String, dynamic> scenario
          in scenarios.cast<Map<String, dynamic>>()) {
        final ForumSource source = ForumSource.values.byName(
          scenario['source'] as String,
        );
        final Uri base = Uri.parse(scenario['base'] as String);
        final String cookie = scenario['cookie'] as String;
        final String? proxy = scenario['proxy'] as String?;
        final Dio dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 40),
          ),
        );
        dio.httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () {
            final HttpClient client = HttpClient();
            client.findProxy = (_) => proxy == null ? 'DIRECT' : 'PROXY $proxy';
            return client;
          },
        );
        final ForumSourceClient client = ForumSourceClient(dio: dio);
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            forumClientProvider.overrideWithValue(client),
            forumSettingsProvider(source).overrideWith(
              (ref) async => ForumSourceSettings(base: base, cookie: cookie),
            ),
          ],
        );
        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: BookTheme.light,
                home: BookSourcePage(initialQuery: scenario['query'] as String),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (source == ForumSource.soushu) {
            await tester.tap(find.text(source.label));
            await tester.pumpAndSettle();
          }
          await tester.tap(find.byTooltip('搜索书源'));
          final Finder result = find.ancestor(
            of: find.textContaining(scenario['title'] as String),
            matching: find.byType(ListTile),
          );
          await _wait(tester, result, seconds: 90);
          await tester.ensureVisible(result.first);
          await tester.tap(result.first);
          await _wait(tester, find.byType(SimpleDialogOption), seconds: 60);
          await tester.tap(find.byType(SimpleDialogOption).first);
          await _wait(tester, find.text('选择保存位置…'), seconds: 90);
          debugPrint('BOOKSIFT_NATIVE_SAVE_READY source=${source.name}');
          await _wait(tester, find.textContaining('已保存到：'), seconds: 300);
          expect(tester.takeException(), isNull);
          debugPrint('BOOKSIFT_NATIVE_SAVE_PASSED source=${source.name}');
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
          dio.close(force: true);
        }
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

Future<void> _wait(
  WidgetTester tester,
  Finder target, {
  required int seconds,
}) async {
  final DateTime deadline = DateTime.now().add(Duration(seconds: seconds));
  while (target.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(target, findsWidgets);
}
