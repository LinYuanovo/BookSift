import 'dart:convert';

import 'package:booksift/book_sources/forum_browser_policy.dart';
import 'package:booksift/book_sources/forum_session.dart';
import 'package:booksift/book_sources/forum_source.dart';
import 'package:booksift/book_sources/source_settings.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'forum_source_test.dart' show ForumAdapter;

void main() {
  final Uri base = Uri.parse('https://forum.example/');

  test(
    'credentials round trip only for the configured origin and retain legacy cookies',
    () {
      final settings = ForumSourceSettings(
        base: base,
        cookie: 'session=valid',
        username: 'reader',
        password: 'local-only',
      );
      final encoded = encodeForumSession(settings);
      expect(decodeForumSession(base, encoded).username, 'reader');
      expect(decodeForumSession(base, encoded).password, 'local-only');
      expect(
        decodeForumSession(Uri.parse('https://other.example/'), encoded).cookie,
        isEmpty,
      );
      expect(
        decodeForumSession(
          base,
          jsonEncode({'origin': base.origin, 'cookie': 'old=kept'}),
        ).cookie,
        'old=kept',
      );
      expect(decodeForumSession(base, '{').cookie, isEmpty);
    },
  );

  test(
    'valid cookie is reused without login; rotated cookie is persisted',
    () async {
      final client = ForumSourceClient();
      addTearDown(() => client.dio.close(force: true));
      final saved = <String>[];
      int logins = 0;
      final result = await ForumSessionCoordinator(client).run(
        base: base,
        cookie: 'session=valid',
        login: () async {
          logins++;
          return 'session=new';
        },
        operation: (cookie) async {
          expect(cookie, 'session=valid');
          client.restoreSession(base, 'session=rotated');
          return 7;
        },
        persist: (cookie) async => saved.add(cookie),
      );
      expect(result, 7);
      expect(logins, 0);
      expect(saved, ['session=rotated']);
    },
  );

  test(
    'expired cookie triggers one login and retries using the captured cookie',
    () async {
      final client = ForumSourceClient();
      addTearDown(() => client.dio.close(force: true));
      int attempts = 0;
      int logins = 0;
      final saved = <String>[];
      final result = await ForumSessionCoordinator(client).run(
        base: base,
        cookie: 'session=expired',
        login: () async {
          logins++;
          return 'session=new';
        },
        operation: (cookie) async {
          attempts++;
          if (cookie.endsWith('expired')) {
            throw const ForumAuthenticationRequired();
          }
          return cookie;
        },
        persist: (cookie) async => saved.add(cookie),
      );
      expect(result, 'session=new');
      expect(attempts, 2);
      expect(logins, 1);
      expect(saved, ['session=new']);
    },
  );

  test(
    'network failures do not start login; cancellation never submits a search',
    () async {
      final client = ForumSourceClient();
      addTearDown(() => client.dio.close(force: true));
      int logins = 0;
      await expectLater(
        ForumSessionCoordinator(client).run<int>(
          base: base,
          cookie: 'session=valid',
          login: () async {
            logins++;
            return null;
          },
          operation: (_) async => throw const SourceFailure('network'),
          persist: (_) async {},
        ),
        throwsA(isA<SourceFailure>()),
      );
      expect(logins, 0);
      int searches = 0;
      await expectLater(
        ForumSessionCoordinator(client).run<int>(
          base: base,
          cookie: '',
          login: () async => null,
          operation: (_) async => ++searches,
          persist: (_) async {},
        ),
        throwsA(isA<SourceFailure>()),
      );
      expect(searches, 0);
    },
  );

  test(
    'session probe distinguishes login forms, verified members and ambiguous errors',
    () async {
      for (final (String page, bool? expected) scenario in <(String, bool?)>[
        (
          '<form action="member.php?action=login"><input type="password"></form>',
          false,
        ),
        ('<a href="member.php?action=logout">退出</a>', true),
      ('<a href="member.php?action=logout">退出</a><input name="oldpassword" type="password">', true),
        ('<p>Service unavailable</p>', null),
      ]) {
        final client = ForumSourceClient(
          dio: Dio()
            ..httpClientAdapter = ForumAdapter(
              (_) => ResponseBody.fromString(scenario.$1, 200),
            ),
        );
        if (scenario.$2 == null) {
          await expectLater(
            client.checkSession(base, 'session=provided'),
            throwsA(isA<SourceFailure>()),
          );
        } else {
          expect(
            await client.checkSession(base, 'session=provided'),
            scenario.$2,
          );
        }
        client.dio.close(force: true);
      }
    },
  );

  test(
    'browser navigation rejects cross-origin and script URLs; login values are JSON encoded',
    () {
      expect(isForumNavigationAllowed(base, base.resolve('forum.php')), isTrue);
      for (final String url in [
        'https://other.example/',
        'http://forum.example/',
        'javascript:alert(1)',
        'https://user@forum.example/',
      ]) {
        expect(isForumNavigationAllowed(base, Uri.parse(url)), isFalse);
      }
      const String username = 'reader";attack()';
      const String secret = 'pass\\word\nline';
      final script = forumLoginScript(base, username, secret);
      expect(script, contains(jsonEncode(username)));
      expect(script, contains(jsonEncode(secret)));
      expect(
        script.indexOf("return 'captcha'"),
        lessThan(script.indexOf('submit.click()')),
      );
    },
  );
}
