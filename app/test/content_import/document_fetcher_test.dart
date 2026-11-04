import 'dart:convert';
import 'dart:typed_data';

import 'package:booksift/content/content_draft.dart';
import 'package:booksift/content/document_fetcher.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('远程图片错误不丢链接，有明确离线不完整提示，已有警告保留', () async {
    final Dio dio = Dio()..httpClientAdapter = _FailureAdapter();
    final DocumentFetcher fetcher = DocumentFetcher(dio: dio);
    try {
      final ContentDraft draft = await fetcher.preserveImages(
        const ContentDraft(
          warnings: <String>['正文含视频，请到来源查看媒体。', '有图片地址无法读取；原文已留档。'],
          floors: <ContentFloorDraft>[
            ContentFloorDraft(
              text: '完整原文',
              images: <ContentImageDraft>[
                ContentImageDraft(url: 'https://example.com/picture.png'),
              ],
            ),
          ],
        ),
      );
      expect(
        draft.floors.single.images.single.url,
        'https://example.com/picture.png',
      );
      expect(draft.warnings.join('\n'), contains('未能下载'));
      expect(draft.warnings.join('\n'), contains('正文含视频'));
      expect(draft.floors.single.text, '完整原文');
    } finally {
      fetcher.close();
    }
  });

  test('只允许公开 HTTP(S) 来源，验证页不能导入成功', () async {
    final DocumentFetcher fetcher = DocumentFetcher();
    try {
      for (final String url in <String>[
        'file:///etc/passwd',
        'http://127.0.0.1/secret',
        'http://10.0.0.1/admin',
        'http://[::1]/secret',
        'http://[::ffff:127.0.0.1]/secret',
      ]) {
        await expectLater(
          fetcher.readUrl(url),
          throwsA(isA<ContentEditException>()),
        );
      }
      final Dio dio = Dio()..httpClientAdapter = _HtmlAdapter();
      final DocumentFetcher captcha = DocumentFetcher(dio: dio);
      try {
        await expectLater(
          captcha.readUrl('https://example.com/review'),
          throwsA(isA<ContentEditException>()),
        );
      } finally {
        captcha.close();
      }
    } finally {
      fetcher.close();
    }
  });
}

class _FailureAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw DioException(
    requestOptions: options,
    type: DioExceptionType.connectionError,
  );
  @override
  void close({bool force = false}) {}
}

class _HtmlAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromBytes(
    utf8.encode('<html><body>环境异常，完成验证后即可继续访问。</body></html>'),
    200,
    headers: <String, List<String>>{
      'content-type': <String>['text/html'],
    },
  );
  @override
  void close({bool force = false}) {}
}
