import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:booksift/book_sources/forum_source.dart';
import 'package:charset/charset.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class ForumAdapter implements HttpClientAdapter {
  ForumAdapter(this.respond);
  final ResponseBody Function(RequestOptions options) respond;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  final Uri base = Uri.parse('https://forum.example/');

  test(
    'forum addresses add HTTPS for bare domains and preserve ports and paths',
    () {
      for (final (String input, String expected) address in <(String, String)>[
        ('forum.example', 'https://forum.example/'),
        ('  forum.example/  ', 'https://forum.example/'),
        ('FORUM.example/books', 'https://forum.example/books/'),
        ('forum.example:8443/books', 'https://forum.example:8443/books/'),
        ('//forum.example/books', 'https://forum.example/books/'),
        ('https://forum.example/books/', 'https://forum.example/books/'),
      ]) {
        final Uri normalized = validateForumBase(address.$1);
        expect(normalized.toString(), address.$2, reason: address.$1);
        expect(validateForumBase(normalized.toString()), normalized);
      }
      expect(validateForumBase('forum.example').origin, base.origin);
    },
  );

  test(
    'address completion keeps malformed addresses and explicit non-HTTPS schemes invalid',
    () {
      for (final String input in <String>[
        '',
        '   ',
        '/books',
        'forum .example',
        'http://forum.example',
        'ftp://forum.example',
        'javascript:alert(1)',
        'user@forum.example',
        'forum.example?token=value',
        'forum.example#section',
        'https://forum.example?token=value',
        'https://forum.example#section',
      ]) {
        expect(
          () => validateForumBase(input),
          throwsA(isA<SourceFailure>()),
          reason: input,
        );
      }
    },
  );

  test('navigation only accepts labeled HTTPS forum links', () {
    expect(
      navigationTarget(
        '<a id="enterButton" href="https://sxsy33.com">进入</a><a href="https://t.me/foo">进入</a>',
        Uri.parse('https://sxsy.pw'),
        ForumSource.shangxiang,
      )?.host,
      'sxsy33.com',
    );
    expect(
      navigationTarget(
        '<a href="https://ads.example/">广告</a>',
        base,
        ForumSource.soushu,
      ),
      isNull,
    );
    expect(
      () => validateForumBase('http://forum.example'),
      throwsA(isA<SourceFailure>()),
    );
    expect(
      () => validateForumBase('https://user@forum.example'),
      throwsA(isA<SourceFailure>()),
    );
  });

  test(
    'navigation follows literal redirects and 404 landing pages without credentials',
    () async {
      final ForumAdapter adapter = ForumAdapter((options) {
        expect(options.headers.containsKey('Cookie'), isFalse);
        if (options.uri.host == 'soushu2025.com') {
          return ResponseBody.fromString(
            '<script>window.location.href="http://landing.example/o/";</script>',
            200,
          );
        }
        if (options.uri.host == 'landing.example') {
          return ResponseBody.fromString(
            '<h1>搜书吧</h1><a href="https://ads.example/" class="link">其他服务</a><a href="https://forum.example/" class="link">最新地址</a>',
            404,
          );
        }
        return ResponseBody.fromString(
          '<input name="formhash" value="abc"><input name="password">',
          200,
        );
      });
      final ForumSourceClient client = ForumSourceClient(
        dio: Dio()..httpClientAdapter = adapter,
      );
      expect(await client.resolve(ForumSource.soushu), base);
      expect(adapter.requests.map((request) => request.uri.host), <String>[
        'soushu2025.com',
        'landing.example',
        'forum.example',
      ]);
    },
  );

  test('download-label attachments take the file name from their own block', () {
    final List<BookAttachment> files = parseBookAttachments(
      '<dl><dd><p><span>原文.txt</span></p><p><a href="forum.php?mod=attachment&amp;aid=abc">下载</a></p></dd></dl>',
      base,
    );
    expect(files.single.name, '原文.txt');
  });

  test('Discuz results and attachments are deduplicated and same origin', () {
    const String page =
        '<div class="slst"><h3 class="xs3"><a href="thread-10-1-1.html">红楼梦</a></h3><h3 class="xs3"><a href="https://ads.example/book">广告</a></h3></div>';
    expect(parseForumResults(page, base).single.title, '红楼梦');
    final List<BookAttachment> attachments = parseBookAttachments(
      '<a href="forum.php?mod=attachment&amp;aid=1">红楼梦.txt</a>'
      '<a href="forum.php?mod=attachment&amp;aid=1">重复.txt</a>'
      '<a href="https://other.example/attachment.php">外链.zip</a>'
      '<a href="forum.php?mod=misc&amp;action=attachpay&amp;aid=2">购买</a>',
      base,
    );
    expect(attachments.length, 1);
    expect(attachments.single.url.queryParameters['aid'], '1');
  });

  test('GBK search encodes Chinese query and binds cookies to origin', () async {
    final ForumAdapter adapter = ForumAdapter((options) {
      if (options.method == 'GET') {
        return ResponseBody.fromBytes(
          gbk.encode(
            '<meta charset="gbk"><input name="formhash" value="abcd">',
          ),
          200,
        );
      }
      return ResponseBody.fromBytes(
        gbk.encode(
          '<meta charset="gbk"><h3 class="xs3"><a href="thread-1-1-1.html">红楼梦</a></h3>',
        ),
        200,
      );
    });
    final ForumSourceClient client = ForumSourceClient(
      dio: Dio()..httpClientAdapter = adapter,
    );
    final List<ForumBook> results = await client.search(
      base,
      '红楼梦',
      cookie: 'auth=fixture',
    );
    expect(results.single.title, '红楼梦');
    expect(adapter.requests.last.data, contains('%ba%ec%c2%a5%c3%ce'));
    expect(
      adapter.requests.every(
        (request) => request.headers['Cookie'] == 'auth=fixture',
      ),
      isTrue,
    );
  });

  test('cross-origin redirect stops before leaking a login cookie', () async {
    final ForumAdapter adapter = ForumAdapter(
      (options) => ResponseBody.fromString(
        '',
        302,
        headers: <String, List<String>>{
          'location': <String>['https://other.example/login'],
        },
      ),
    );
    final ForumSourceClient client = ForumSourceClient(
      dio: Dio()..httpClientAdapter = adapter,
    );
    await expectLater(
      client.search(base, '书名', cookie: 'auth=fixture'),
      throwsA(isA<SourceFailure>()),
    );
    expect(adapter.requests.length, 1);
  });

  test(
    'search keeps the form session cookie and rejects truncated downloads',
    () async {
      final ForumAdapter adapter = ForumAdapter((options) {
        if (options.uri.path == '/attachment.php') {
          return ResponseBody.fromString(
            'partial',
            200,
            headers: <String, List<String>>{
              'content-length': <String>['100'],
            },
          );
        }
        if (options.method == 'GET') {
          return ResponseBody.fromString(
            '<input name="formhash" value="abcd">',
            200,
            headers: <String, List<String>>{
              'set-cookie': <String>['session=rotated; Path=/; Secure'],
            },
          );
        }
        return ResponseBody.fromString(
          '<h3 class="xs3"><a href="thread-1.html">书</a></h3>',
          200,
        );
      });
      final ForumSourceClient client = ForumSourceClient(
        dio: Dio()..httpClientAdapter = adapter,
      );
      await client.search(base, '书');
      expect(
        adapter.requests.last.headers['Cookie'],
        contains('session=rotated'),
      );
      final Directory temporary = await Directory.systemTemp.createTemp(
        'booksift-partial-',
      );
      try {
        final BookAttachment attachment = BookAttachment(
          'book.txt',
          base.resolve('attachment.php'),
          base,
        );
        await expectLater(
          client.download(
            base,
            attachment,
            temporary,
            cancelToken: CancelToken(),
          ),
          throwsA(isA<SourceFailure>()),
        );
        expect(await temporary.list().isEmpty, isTrue);
        final CancelToken canceled = CancelToken()..cancel();
        await expectLater(
          client.download(base, attachment, temporary, cancelToken: canceled),
          throwsA(isA<DioException>()),
        );
        expect(await temporary.list().isEmpty, isTrue);
      } finally {
        await temporary.delete(recursive: true);
      }
    },
  );

  test('login pages are reported instead of empty search results', () async {
    final ForumSourceClient client = ForumSourceClient(
      dio: Dio()
        ..httpClientAdapter = ForumAdapter(
          (options) => ResponseBody.fromString('<input type="password">', 200),
        ),
    );
    await expectLater(
      client.search(base, '书名'),
      throwsA(
        isA<SourceFailure>().having(
          (error) => error.message,
          'message',
          contains('登录'),
        ),
      ),
    );
  });

  test(
    'downloads preserve bytes and reject HTML or incomplete responses',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'booksift-forum-test-',
      );
      final BookAttachment attachment = BookAttachment(
        'book.txt',
        base.resolve('attachment.php?aid=1'),
        base.resolve('thread-1.html'),
      );
      try {
        final List<int> bytes = utf8.encode('红楼梦\n第一回');
        final ForumSourceClient client = ForumSourceClient(
          dio: Dio()
            ..httpClientAdapter = ForumAdapter(
              (options) => ResponseBody.fromBytes(
                bytes,
                200,
                headers: <String, List<String>>{
                  'content-length': <String>['${bytes.length}'],
                },
              ),
            ),
        );
        final File file = await client.download(
          base,
          attachment,
          directory,
          cancelToken: CancelToken(),
        );
        expect(await file.readAsBytes(), bytes);
        await file.delete();
        final ForumSourceClient invalid = ForumSourceClient(
          dio: Dio()
            ..httpClientAdapter = ForumAdapter(
              (options) => ResponseBody.fromString(
                '<!DOCTYPE html><html>请登录</html>',
                200,
              ),
            ),
        );
        await expectLater(
          invalid.download(
            base,
            attachment,
            directory,
            cancelToken: CancelToken(),
          ),
          throwsA(isA<SourceFailure>()),
        );
        expect(await directory.list().isEmpty, isTrue);
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}
