import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:booksift/book_sources/forum_browser_policy.dart';
import 'package:booksift/book_sources/forum_source.dart';
import 'package:booksift/book_sources/source_settings.dart';
import 'package:booksift/features/search/forum_download.dart';
import 'package:booksift/theme/book_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class _DownloadFixture extends ForumSourceClient {
  @override
  Future<File> download(
    Uri base,
    BookAttachment attachment,
    Directory temporary, {
    String cookie = '',
    required CancelToken cancelToken,
    void Function(int, int)? onProgress,
  }) async {
    final bytes = utf8.encode('BookSift native save acceptance\n');
    onProgress?.call(bytes.length, bytes.length);
    return File('${temporary.path}/attachment.part').writeAsBytes(bytes);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'production download dialog saves through Android DocumentsUI',
    (tester) async {
      final base = Uri.parse('https://forum.example/');
      final client = _DownloadFixture();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [forumClientProvider.overrideWithValue(client)],
          child: MaterialApp(
            theme: BookTheme.light,
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => showForumDownload(
                  context,
                  ForumSourceSettings(base: base),
                  BookAttachment(
                    'BookSift-native-save.txt',
                    base.resolve('attachment.php'),
                    base,
                  ),
                ),
                child: const Text('下载测试文件'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('下载测试文件'));
      final deadline = DateTime.now().add(const Duration(minutes: 3));
      while (find.textContaining('已保存到：').evaluate().isEmpty &&
          DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.textContaining('已保存到：'), findsOneWidget);
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      client.dio.close(force: true);
    },
    skip: !const bool.fromEnvironment('BOOKSIFT_NATIVE_SAVE_ACCEPTANCE'),
  );
  testWidgets(
    'native webview fills credentials, pauses for captcha, submits and captures cookies',
    (tester) async {
      final Uri base = Uri.parse('https://forum.example/');
      final Completer<InAppWebViewController> created =
          Completer<InAppWebViewController>();
      final Completer<void> loaded = Completer<void>();
      PlatformInAppWebViewController.debugLoggingSettings.enabled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InAppWebView(
              initialData: InAppWebViewInitialData(
                baseUrl: WebUri(base.toString()),
                data: '''
<html><body><form action="/member.php?action=login" onsubmit="event.preventDefault();window.submitted=true;document.cookie='session=fixture;path=/;Secure';">
<input name="username"><input name="password" type="password"><input name="seccodeverify"><button name="loginsubmit" type="submit">登录</button>
</form></body></html>
''',
              ),
              onWebViewCreated: created.complete,
              onLoadStop: (_, url) {
                if (!loaded.isCompleted) loaded.complete();
              },
            ),
          ),
        ),
      );
      await loaded.future.timeout(const Duration(seconds: 30));
      final controller = await created.future;
      expect(
        await controller.evaluateJavascript(
          source: forumLoginScript(base, 'reader@example.com', 'fixture-pass'),
        ),
        'captcha',
      );
      final String fields =
          await controller.evaluateJavascript(
                source:
                    "JSON.stringify([document.querySelector('[name=username]').value,document.querySelector('[type=password]').value,window.submitted===true])",
              )
              as String;
      expect(jsonDecode(fields), ['reader@example.com', 'fixture-pass', false]);
      await controller.evaluateJavascript(
        source: "document.querySelector('[name=seccodeverify]').remove()",
      );
      expect(
        await controller.evaluateJavascript(
          source: forumLoginScript(base, 'reader@example.com', 'fixture-pass'),
        ),
        'submitted',
      );
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri(base.toString()),
      );
      expect(
        cookies.any(
          (cookie) => cookie.name == 'session' && cookie.value == 'fixture',
        ),
        isTrue,
      );
      expect(
        await controller.evaluateJavascript(
          source: forumLoginScript(
            Uri.parse('https://other.example/'),
            'other',
            'unused',
          ),
        ),
        'blocked',
      );
      await CookieManager.instance().deleteCookies(
        url: WebUri(base.toString()),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
