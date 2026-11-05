import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bduss.dart';
import '../data/repo/database_provider.dart';
import 'forum_source.dart';

class ForumSourceSettings {
  const ForumSourceSettings({this.base, this.cookie = ''});
  final Uri? base;
  final String cookie;
}

final forumClientProvider = Provider<ForumSourceClient>((ref) {
  final ForumSourceClient client = ForumSourceClient();
  ref.onDispose(() => client.dio.close(force: true));
  return client;
});

final forumSettingsProvider =
    FutureProvider.family<ForumSourceSettings, ForumSource>((
      ref,
      source,
    ) async {
      final database = ref.watch(appDatabaseProvider);
      final row =
          await (database.select(database.settings)..where(
                (table) => table.key.equals('book_source.${source.name}.base'),
              ))
              .getSingleOrNull();
      final Uri? base = row == null ? null : validateForumBase(row.value);
      String cookie = '';
      try {
        final String? raw = await ref
            .watch(secretStoreProvider)
            .read('book_source.${source.name}.session');
        if (raw != null) {
          final Map<String, dynamic> data =
              jsonDecode(raw) as Map<String, dynamic>;
          if (data['origin'] == base?.origin) cookie = data['cookie'] as String;
        }
      } catch (_) {}
      return ForumSourceSettings(base: base, cookie: cookie);
    });

Future<void> saveForumSettings(
  WidgetRef ref,
  ForumSource source,
  Uri base,
  String cookie,
) async {
  if (cookie.contains('\r') || cookie.contains('\n') || cookie.length > 16384) {
    throw const SourceFailure('Cookie 格式无效');
  }
  await ref
      .read(secretStoreProvider)
      .write(
        'book_source.${source.name}.session',
        cookie.trim().isEmpty
            ? null
            : jsonEncode(<String, String>{
                'origin': base.origin,
                'cookie': cookie.trim(),
              }),
      );
  await ref.read(appDatabaseProvider).customStatement(
    'INSERT INTO settings(key,value) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
    <Object>['book_source.${source.name}.base', base.toString()],
  );
  ref.invalidate(forumSettingsProvider(source));
  ref.invalidate(forumClientProvider);
}
