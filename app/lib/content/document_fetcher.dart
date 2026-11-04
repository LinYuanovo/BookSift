import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'content_draft.dart';
import 'document_reader.dart';

class DocumentFetcher {
  DocumentFetcher({Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              followRedirects: false,
            ),
          );

  final Dio dio;

  Future<ContentDraft> readUrl(String url) async {
    if (!validContentUrl(url) || url.isEmpty) {
      throw const ContentEditException('请输入完整的 HTTP 或 HTTPS 网页链接。');
    }
    try {
      final ({Uint8List bytes, String type}) response = await _download(
        url,
        maxImportBytes,
        image: false,
      );
      if (response.type.isNotEmpty &&
          !<String>[
            'text/html',
            'application/xhtml+xml',
            'text/plain',
            'text/markdown',
          ].any(response.type.startsWith)) {
        throw const ContentEditException('链接不是可读取的网页，请选择保存后的文档。');
      }
      return const DocumentReader().read(
        bytes: response.bytes,
        fileName: response.type.startsWith('text/plain')
            ? '网页正文.txt'
            : '网页原文.html',
        sourceUrl: url,
      );
    } on ContentEditException {
      rethrow;
    } catch (_) {
      throw const ContentEditException(
        '网页读取失败。请在实际浏览器打开链接，完成验证后保存 HTML 或粘贴正文。',
      );
    }
  }

  Future<ContentDraft> preserveImages(ContentDraft draft) async {
    final Map<String, String?> cache = <String, String?>{};
    final List<ContentFloorDraft> floors = <ContentFloorDraft>[];
    int preservedBytes = draft.rawDocument?.length ?? 0;
    int failed = 0;
    for (final ContentFloorDraft floor in draft.floors) {
      final List<ContentImageDraft> images = <ContentImageDraft>[];
      for (final ContentImageDraft image in floor.images) {
        if (image.embedded) {
          images.add(image);
          continue;
        }
        if (!cache.containsKey(image.url)) {
          try {
            if (preservedBytes > maxExpandedDocumentBytes) {
              throw const ContentEditException('图片总量过大。');
            }
            final ({Uint8List bytes, String type}) result = await _download(
              image.url,
              8 * 1024 * 1024,
              image: true,
            );
            if (!result.type.startsWith('image/')) {
              throw const ContentEditException('图片来源返回非图片内容。');
            }
            preservedBytes += result.bytes.length;
            if (preservedBytes > maxExpandedDocumentBytes) {
              throw const ContentEditException('图片总量过大。');
            }
            cache[image.url] =
                'data:${result.type.split(';').first};base64,${base64Encode(result.bytes)}';
          } catch (_) {
            cache[image.url] = null;
          }
        }
        final String? embedded = cache[image.url];
        if (embedded == null) failed++;
        images.add(
          ContentImageDraft(
            id: image.id,
            url: embedded ?? image.url,
            width: image.width,
            height: image.height,
          ),
        );
      }
      floors.add(
        ContentFloorDraft(id: floor.id, text: floor.text, images: images),
      );
    }
    return draft.copyWith(
      floors: floors,
      warnings: <String>[
        ...draft.warnings.where(
          (String warning) =>
              !warning.startsWith('网络图片已保留地址') &&
              !(warning.startsWith('有 ') && warning.contains('网络图片未能下载')) &&
              !warning.startsWith('本地图片留档'),
        ),
        if (failed > 0) '有 $failed 张网络图片未能下载，已保留链接；离线时无法保证显示，请补充图片后再保存。',
        if (failed == 0 && cache.isNotEmpty) '本地图片留档：网络图片已嵌入，可离线查看。',
      ],
    );
  }

  Future<({Uint8List bytes, String type})> _download(
    String url,
    int limit, {
    required bool image,
  }) async {
    Uri current = Uri.parse(url);
    for (int redirect = 0; redirect <= 5; redirect++) {
      await _publicAddress(current).timeout(const Duration(seconds: 10));
      final Response<ResponseBody> response = await dio.get<ResponseBody>(
        current.toString(),
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          validateStatus: (int? status) =>
              status != null && status >= 200 && status < 400,
          headers: <String, String>{
            'User-Agent': 'Mozilla/5.0 BookSift/1.0',
            if (image)
              'Referer': current.host.endsWith('qpic.cn')
                  ? 'https://mp.weixin.qq.com/'
                  : current.origin,
          },
        ),
      );
      final ResponseBody? body = response.data;
      if (body == null) throw const ContentEditException('来源响应为空。');
      if ((response.statusCode ?? 0) >= 300) {
        await body.stream.listen((_) {}).cancel();
        final String? location = response.headers.value('location');
        if (location == null) throw const ContentEditException('来源跳转缺少地址。');
        current = current.resolve(location);
        continue;
      }
      final int? length = int.tryParse(
        response.headers.value('content-length') ?? '',
      );
      if (length != null && length > limit) {
        await body.stream.listen((_) {}).cancel();
        throw const ContentEditException('来源内容过大，请分篇导入。');
      }
      final BytesBuilder bytes = BytesBuilder(copy: false);
      await for (final Uint8List chunk in body.stream.timeout(
        const Duration(seconds: 20),
      )) {
        if (bytes.length + chunk.length > limit) {
          throw const ContentEditException('来源内容过大，请分篇导入。');
        }
        bytes.add(chunk);
      }
      return (
        bytes: bytes.takeBytes(),
        type: response.headers.value('content-type') ?? '',
      );
    }
    throw const ContentEditException('来源跳转过多，请保存文档后导入。');
  }

  Future<void> _publicAddress(Uri uri) async {
    if (!validContentUrl(uri.toString())) {
      throw const ContentEditException('来源地址无效。');
    }
    final List<InternetAddress> addresses = await InternetAddress.lookup(
      uri.host,
    );
    if (addresses.isEmpty ||
        addresses.any((InternetAddress address) {
          final List<int> bytes = address.rawAddress;
          if (address.isLoopback ||
              address.isLinkLocal ||
              address.isMulticast) {
            return true;
          }
          if (bytes.length == 4) {
            return bytes[0] == 0 ||
                bytes[0] == 10 ||
                bytes[0] == 127 ||
                (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
                (bytes[0] == 192 && bytes[1] == 168) ||
                (bytes[0] == 100 && bytes[1] >= 64 && bytes[1] <= 127) ||
                bytes[0] >= 224;
          }
          if (bytes.length == 16 &&
              bytes.take(10).every((int byte) => byte == 0) &&
              bytes[10] == 255 &&
              bytes[11] == 255) {
            return true;
          }
          return (bytes[0] & 0xfe) == 0xfc ||
              bytes.every((int byte) => byte == 0);
        })) {
      throw const ContentEditException('只允许读取公开网页地址。');
    }
  }

  void close() => dio.close(force: true);
}
