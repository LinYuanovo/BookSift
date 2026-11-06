import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bduss.dart';
import '../data/repo/database_provider.dart';
import 'forum_source.dart';

class ForumSourceSettings {
  const ForumSourceSettings({
    this.base,
    this.cookie = '',
    this.username = '',
    this.password = '',
  });
  final Uri? base;
  final String cookie;
  final String username;
  final String password;

  ForumSourceSettings withCookie(String value) => ForumSourceSettings(
    base: base,
    cookie: value,
    username: username,
    password: password,
  );
}

ForumSourceSettings decodeForumSession(Uri? base, String? raw) {
  if (base == null || raw == null) return ForumSourceSettings(base: base);
  try {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['origin'] != base.origin) return ForumSourceSettings(base: base);
    return ForumSourceSettings(
      base: base,
      cookie: data['cookie'] as String? ?? '',
      username: data['username'] as String? ?? '',
      password: data['password'] as String? ?? '',
    );
  } catch (_) {
    return ForumSourceSettings(base: base);
  }
}

String encodeForumSession(ForumSourceSettings settings) =>
    jsonEncode(<String, String>{
      'origin': settings.base!.origin,
      'cookie': settings.cookie.trim(),
      'username': settings.username.trim(),
      'password': settings.password,
    });

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
      try {
        final String? raw = await ref
            .watch(secretStoreProvider)
            .read('book_source.${source.name}.session');
        return decodeForumSession(base, raw);
      } catch (_) {}
      return ForumSourceSettings(base: base);
    });

Future<void> saveForumSettings(
  WidgetRef ref,
  ForumSource source,
  Uri base,
  String cookie, {
  String username = '',
  String password = '',
}) async {
  if (cookie.contains('\r') || cookie.contains('\n') || cookie.length > 16384) {
    throw const SourceFailure('Cookie 格式无效');
  }
  await ref
      .read(secretStoreProvider)
      .write(
        'book_source.${source.name}.session',
        cookie.trim().isEmpty && username.trim().isEmpty && password.isEmpty
            ? null
            : encodeForumSession(
                ForumSourceSettings(
                  base: base,
                  cookie: cookie,
                  username: username,
                  password: password,
                ),
              ),
      );
  await ref.read(appDatabaseProvider).customStatement(
    'INSERT INTO settings(key,value) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
    <Object>['book_source.${source.name}.base', base.toString()],
  );
  ref.invalidate(forumSettingsProvider(source));
  ref.invalidate(forumClientProvider);
}

Future<void> saveForumSessionCookie(
  WidgetRef ref,
  ForumSource source,
  ForumSourceSettings settings,
  String cookie,
) async {
  await ref
      .read(secretStoreProvider)
      .write(
        'book_source.${source.name}.session',
        encodeForumSession(settings.withCookie(cookie)),
      );
  ref.invalidate(forumSettingsProvider(source));
}
