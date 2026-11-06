import 'forum_source.dart';

class ForumSessionCoordinator {
  const ForumSessionCoordinator(this.client);
  final ForumSourceClient client;

  Future<T> run<T>({
    required Uri base,
    required String cookie,
    required Future<String?> Function() login,
    required Future<T> Function(String cookie) operation,
    required Future<void> Function(String cookie) persist,
  }) async {
    String activeCookie = cookie;
    bool loggedIn = false;
    Future<void> authenticate() async {
      final String? value = await login();
      if (value == null || value.trim().isEmpty) {
        throw const SourceFailure('已取消登录');
      }
      activeCookie = value;
      client.restoreSession(base, value);
      await persist(value);
      loggedIn = true;
    }

    if (activeCookie.trim().isEmpty) await authenticate();
    try {
      final T result = await operation(activeCookie);
      final String current = client.sessionCookie(base);
      if (current.isNotEmpty && current != activeCookie) await persist(current);
      return result;
    } on ForumAuthenticationRequired {
      if (loggedIn) rethrow;
      await authenticate();
      final T result = await operation(activeCookie);
      final String current = client.sessionCookie(base);
      if (current.isNotEmpty && current != activeCookie) await persist(current);
      return result;
    }
  }
}
