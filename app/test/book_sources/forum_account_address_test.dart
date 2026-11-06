import 'package:booksift/book_sources/forum_source.dart';
import 'package:booksift/book_sources/source_settings.dart';
import 'package:booksift/core/widgets/app_dialog.dart';
import 'package:booksift/core/widgets/app_text_field.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/bduss.dart';
import 'package:booksift/data/repo/database_provider.dart';
import 'package:booksift/features/search/forum_account_dialog.dart';
import 'package:booksift/theme/book_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../profile/bduss_settings_test.dart' show MemorySecrets;

class _SettingsDatabase implements AppDatabase {
  final Map<String, String> settingsValues = <String, String>{};

  @override
  Future<void> customStatement(String statement, [List<Object?>? args]) async {
    settingsValues[args![0] as String] = args[1] as String;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'saving a bare domain normalizes the address without discarding its same-origin cookie',
    (tester) async {
      final database = _SettingsDatabase();
      final secrets = MemorySecrets();
      final Uri base = Uri.parse('https://forum.example/');
      const String cookie = 'session=stored';
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(database),
            secretStoreProvider.overrideWithValue(secrets),
            forumSettingsProvider(ForumSource.shangxiang).overrideWith(
              (ref) async => ForumSourceSettings(base: base, cookie: cookie),
            ),
          ],
          child: MaterialApp(
            theme: BookTheme.light,
            home: Consumer(
              builder: (context, ref, child) => Scaffold(
                body: TextButton(
                  onPressed: () => showForumAccountDialog(
                    context,
                    ref,
                    ForumSource.shangxiang,
                  ),
                  child: const Text('设置书源'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('设置书源'));
      await tester.pumpAndSettle();
      final Finder address = find.descendant(
        of: find.widgetWithText(AppTextField, '论坛最新地址（HTTPS）'),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(address);
      await tester.enterText(address, '  forum.example  ');
      await tester.ensureVisible(find.text('保存'));
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsNothing);
      expect(
        database.settingsValues['book_source.shangxiang.base'],
        base.toString(),
      );
      final saved = decodeForumSession(
        base,
        await secrets.read('book_source.shangxiang.session'),
      );
      expect(saved.cookie, cookie);
      expect(tester.takeException(), isNull);
    },
  );
}
