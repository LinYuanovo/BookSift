import 'package:booksift/collector/collect_controller.dart';
import 'package:booksift/core/widgets/app_dialog.dart';
import 'package:booksift/data/reading_session.dart';
import 'package:booksift/data/reading_session_provider.dart';
import 'package:booksift/data/storage_maintenance.dart';
import 'package:booksift/features/profile/storage_section.dart';
import 'package:booksift/theme/app_colors.dart';
import 'package:booksift/theme/app_typography.dart';
import 'package:booksift/theme/book_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_book_repository.dart';
import '../support/fake_collect.dart';
import '../support/harness.dart';

class _SessionStore implements ReadingSessionStore {
  @override
  Future<ReadingSession?> loadPrevious() async =>
      ReadingSession(savedAt: DateTime(2026), offset: 500, homePages: 2);
  @override
  void record(ReadingSession session) {}
  @override
  Future<void> flush() async {}
  @override
  void dispose() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'storage row and confirmation use dark theme typography and SVG',
    (tester) async {
      useSurface(tester, width: 320);
      final ThemeData theme = BookTheme.dark;
      final AppColors colors = theme.extension<AppColors>()!;
      final AppTypography typography = theme.extension<AppTypography>()!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            ...testOverrides(FakeBookRepository()),
            collectRunStateProvider.overrideWith(FakeCollectRunNotifier.new),
            storageUsageProvider.overrideWith(
              (ref) async => const StorageUsage(
                databaseBytes: 170000000,
                reclaimableBytes: 1000000,
              ),
            ),
          ],
          child: MaterialApp(
            theme: theme,
            home: const Scaffold(body: StorageSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('整理存储空间')).style,
        typography.bodyStrong.copyWith(color: colors.text),
      );
      expect(
        tester.widget<Text>(find.textContaining('可回收空闲页')).style,
        typography.caption.copyWith(color: colors.textMuted),
      );
      await tester.tap(find.text('整理存储空间'));
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('整理存储空间？')).style,
        typography.headline.copyWith(color: colors.text),
      );
      expect(find.byType(Icon), findsNothing);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'startup resume confirmation uses project dialog and remains dismissible',
    (tester) async {
      useSurface(tester, width: 320);
      await tester.pumpWidget(
        testApp(
          FakeBookRepository(),
          extraOverrides: <Override>[
            readingSessionProvider.overrideWithValue(_SessionStore()),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsOneWidget);
      final AppTypography typography = AppTypography.of(
        tester.element(find.byType(AppDialog)),
      );
      final AppColors colors = AppColors.of(
        tester.element(find.byType(AppDialog)),
      );
      expect(
        tester.widget<Text>(find.text('继续上次浏览？')).style,
        typography.headline.copyWith(color: colors.text),
      );
      await tester.tap(find.text('从首页开始'));
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
