import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/update/update_downloader.dart';

final class RangeAdapter implements HttpClientAdapter {
  RangeAdapter(
    this.bytes, {
    this.supportsRange = true,
    this.delayForRange,
    this.mismatchedContentRange = false,
  });

  final Uint8List bytes;
  bool supportsRange;
  Duration Function(int start)? delayForRange;
  final bool mismatchedContentRange;
  final List<RequestOptions> requests = <RequestOptions>[];
  int active = 0;
  int maxActive = 0;

  Iterable<RequestOptions> get rangeRequests => requests.where(
    (RequestOptions request) => request.headers['Range'] != null,
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final String? range = options.headers['Range']?.toString();
    if (options.method.toUpperCase() == 'HEAD') {
      return ResponseBody.fromBytes(
        const <int>[],
        200,
        headers: <String, List<String>>{
          Headers.contentLengthHeader: <String>[bytes.length.toString()],
          if (supportsRange) 'accept-ranges': <String>['bytes'],
        },
      );
    }

    if (range == null || !supportsRange) {
      return ResponseBody.fromBytes(
        bytes,
        200,
        headers: <String, List<String>>{
          Headers.contentLengthHeader: <String>[bytes.length.toString()],
        },
      );
    }

    final RegExpMatch match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range)!;
    final int start = int.parse(match.group(1)!);
    final int requestedEnd = match.group(2)!.isEmpty
        ? bytes.length - 1
        : int.parse(match.group(2)!);
    final int end = requestedEnd.clamp(start, bytes.length - 1);
    final Duration delay = delayForRange?.call(start) ?? Duration.zero;
    active++;
    maxActive = active > maxActive ? active : maxActive;
    try {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      return ResponseBody.fromBytes(
        bytes.sublist(start, end + 1),
        206,
        headers: <String, List<String>>{
          Headers.contentLengthHeader: <String>[(end - start + 1).toString()],
          'content-range': <String>[
            'bytes ${mismatchedContentRange ? start + 1 : start}-$end/${bytes.length}',
          ],
          'accept-ranges': <String>['bytes'],
        },
      );
    } finally {
      active--;
    }
  }

  @override
  void close({bool force = false}) {}
}

final class ResumeAdapter implements HttpClientAdapter {
  ResumeAdapter(this.bytes);

  final Uint8List bytes;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.method.toUpperCase() == 'HEAD') {
      return ResponseBody.fromBytes(
        const <int>[],
        200,
        headers: <String, List<String>>{
          Headers.contentLengthHeader: <String>[bytes.length.toString()],
        },
      );
    }
    final String? range = options.headers['Range']?.toString();
    if (range == null) {
      return ResponseBody.fromBytes(
        bytes,
        200,
        headers: <String, List<String>>{
          Headers.contentLengthHeader: <String>[bytes.length.toString()],
        },
      );
    }
    final int start = int.parse(
      RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!,
    );
    return ResponseBody.fromBytes(
      bytes.sublist(start),
      206,
      headers: <String, List<String>>{
        Headers.contentLengthHeader: <String>[('${bytes.length - start}')],
        'content-range': <String>[
          'bytes $start-${bytes.length - 1}/${bytes.length}',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio testDio(HttpClientAdapter adapter) => Dio()..httpClientAdapter = adapter;

UpdateDownloadRequest requestFor(
  Uint8List bytes, {
  String key = 'release-key',
}) => UpdateDownloadRequest(
  url: 'https://cdn.example/update.bin',
  fileName: 'update.bin',
  cacheKey: key,
  expectedSha256: sha256.convert(bytes).toString(),
  version: '1.2.3',
);

Future<Directory> makeCache() async {
  final Directory directory = await Directory.systemTemp.createTemp(
    'booksift-update-',
  );
  addTearDown(() => directory.delete(recursive: true));
  return directory;
}

void main() {
  test('Range 分块并发下载：校验、manifest 持久化、完整缓存复用', () async {
    final Uint8List bytes = Uint8List.fromList(
      List<int>.generate(17, (int index) => (index * 13) & 0xff),
    );
    final RangeAdapter adapter = RangeAdapter(
      bytes,
      delayForRange: (_) => const Duration(milliseconds: 5),
    );
    final ResumableUpdateDownloader downloader = ResumableUpdateDownloader(
      testDio(adapter),
      await makeCache(),
      chunkSize: 4,
      maxConcurrent: 3,
    );

    final UpdateDownloadResult first = await downloader.download(
      requestFor(bytes),
    );
    expect(await first.file.readAsBytes(), bytes);
    expect(first.reusedCache, isFalse);
    expect(adapter.maxActive, greaterThan(1));
    expect(adapter.rangeRequests.length, greaterThanOrEqualTo(4));
    expect(
      adapter.requests.any(
        (RequestOptions request) => request.method == 'HEAD',
      ),
      isTrue,
    );
    expect(
      first.file.parent.listSync().whereType<File>().any(
        (File file) => file.path.endsWith('.manifest.json'),
      ),
      isTrue,
    );

    final int requestCount = adapter.requests.length;
    final UpdateDownloadResult second = await downloader.download(
      requestFor(bytes),
    );
    expect(second.reusedCache, isTrue);
    expect(second.sha256, sha256.convert(bytes).toString());
    expect(adapter.requests.length, requestCount);
  });

  test('Range 不支持时安全退化为完整响应，不把 200 写进小分块', () async {
    final Uint8List bytes = Uint8List.fromList(
      List<int>.generate(9, (int i) => i + 1),
    );
    final RangeAdapter adapter = RangeAdapter(bytes, supportsRange: false);
    final ResumableUpdateDownloader downloader = ResumableUpdateDownloader(
      testDio(adapter),
      await makeCache(),
      chunkSize: 3,
    );

    final UpdateDownloadResult result = await downloader.download(
      requestFor(bytes),
    );
    expect(await result.file.readAsBytes(), bytes);
    expect(adapter.rangeRequests.length, 1); // 仅用于能力探测，响应 200 后走单流。
    expect(result.bytes, bytes.length);
  });

  test('无预置 SHA-256 时通过完成态 manifest 复用完整缓存', () async {
    final Uint8List bytes = Uint8List.fromList(
      List<int>.generate(11, (int i) => i + 40),
    );
    final RangeAdapter adapter = RangeAdapter(bytes);
    final ResumableUpdateDownloader downloader = ResumableUpdateDownloader(
      testDio(adapter),
      await makeCache(),
      chunkSize: 4,
    );
    final UpdateDownloadRequest request = UpdateDownloadRequest(
      url: 'https://cdn.example/update-without-checksum.bin',
      fileName: 'update.bin',
      cacheKey: 'release-without-checksum',
      version: '1.2.3',
    );

    await downloader.download(request);
    final int requestCount = adapter.requests.length;
    final UpdateDownloadResult reused = await downloader.download(request);

    expect(reused.reusedCache, isTrue);
    expect(reused.sha256, sha256.convert(bytes).toString());
    expect(adapter.requests.length, requestCount);
  });

  test('单流模式的部分响应续传使用 Content-Range 总长度', () async {
    final Uint8List bytes = Uint8List.fromList(
      List<int>.generate(9, (int i) => i + 70),
    );
    final ResumeAdapter adapter = ResumeAdapter(bytes);
    final Directory cache = await makeCache();
    final ResumableUpdateDownloader downloader = ResumableUpdateDownloader(
      testDio(adapter),
      cache,
      chunkSize: 4,
    );
    final UpdateDownloadRequest request = UpdateDownloadRequest(
      url: 'https://cdn.example/single-resume.bin',
      fileName: 'update.bin',
      cacheKey: 'single-resume',
      version: '1.2.3',
    );

    final String identity = <String>[
      request.cacheKey,
      request.url,
      request.fileName,
      request.version ?? '',
      '',
    ].join('\n');
    final String safeKey = sha256
        .convert(utf8.encode(identity))
        .toString()
        .substring(0, 32);
    final File part = File('${cache.path}/$safeKey-update.bin.part');
    final File manifest = File(
      '${cache.path}/$safeKey-update.bin.manifest.json',
    );
    await part.writeAsBytes(bytes.sublist(0, 4), flush: true);
    await manifest.writeAsString(
      jsonEncode(<String, Object?>{
        'url': request.url,
        'fileName': request.fileName,
        'cacheKey': request.cacheKey,
        'version': request.version,
        'expectedSha256': null,
        'totalBytes': bytes.length,
        'chunkSize': 4,
        'rangeSupported': false,
        'completedChunks': <int>[],
        'completedBytes': 4,
      }),
      flush: true,
    );
    final UpdateDownloadResult resumed = await downloader.download(request);

    expect(resumed.resumed, isTrue);
    expect(await resumed.file.readAsBytes(), bytes);
    expect(adapter.requests.length, 1);
    expect(adapter.requests.single.headers['Range'], 'bytes=4-');
  });

  test('取消保留已完成分块，下一次只请求未完成 Range', () async {
    final Uint8List bytes = Uint8List.fromList(
      List<int>.generate(12, (int i) => i + 20),
    );
    final RangeAdapter adapter = RangeAdapter(
      bytes,
      delayForRange: (int start) =>
          start == 0 ? Duration.zero : const Duration(milliseconds: 120),
    );
    final Directory cache = await makeCache();
    final ResumableUpdateDownloader downloader = ResumableUpdateDownloader(
      testDio(adapter),
      cache,
      chunkSize: 4,
      maxConcurrent: 1,
    );
    final CancelToken token = CancelToken();
    final Completer<void> firstChunk = Completer<void>();
    final Future<UpdateDownloadResult> pending = downloader.download(
      requestFor(bytes),
      cancelToken: token,
      onProgress: (UpdateDownloadProgress progress) {
        if (progress.completedChunks >= 1 && !firstChunk.isCompleted) {
          firstChunk.complete();
        }
      },
    );
    await firstChunk.future;
    token.cancel('test cancel');
    await expectLater(pending, throwsA(isA<DioException>()));

    adapter.delayForRange = (_) => Duration.zero;
    final UpdateDownloadResult resumed = await downloader.download(
      requestFor(bytes),
    );
    expect(resumed.resumed, isTrue);
    expect(await resumed.file.readAsBytes(), bytes);
    final List<String> ranges = adapter.rangeRequests
        .map((RequestOptions request) => request.headers['Range']! as String)
        .toList();
    expect(ranges.skip(1), isNot(contains('bytes=0-3')));
  });

  test('SHA-256 不匹配时不留下可复用的完整文件', () async {
    final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
    final RangeAdapter adapter = RangeAdapter(bytes);
    final Directory cache = await makeCache();
    final ResumableUpdateDownloader downloader = ResumableUpdateDownloader(
      testDio(adapter),
      cache,
      chunkSize: 2,
    );
    final UpdateDownloadRequest request = UpdateDownloadRequest(
      url: 'https://cdn.example/update.bin',
      fileName: 'update.bin',
      cacheKey: 'bad-hash',
      expectedSha256: '0' * 64,
    );

    await expectLater(
      downloader.download(request),
      throwsA(isA<UpdateDownloadException>()),
    );
    expect(
      cache.listSync().whereType<File>().where(
        (File file) =>
            file.path.contains('.part') || file.path.endsWith('.manifest.json'),
      ),
      isEmpty,
    );
  });

  test('Range Content-Range 区间不匹配时拒绝写入缓存', () async {
    final Uint8List bytes = Uint8List.fromList(
      List<int>.generate(8, (int i) => i + 1),
    );
    final RangeAdapter adapter = RangeAdapter(
      bytes,
      mismatchedContentRange: true,
    );
    final Directory cache = await makeCache();
    final ResumableUpdateDownloader downloader = ResumableUpdateDownloader(
      testDio(adapter),
      cache,
      chunkSize: 4,
      retryLimit: 0,
    );

    await expectLater(
      downloader.download(requestFor(bytes)),
      throwsA(isA<UpdateDownloadException>()),
    );
    expect(
      cache.listSync().whereType<File>().where(
        (File file) => !file.path.endsWith('.json'),
      ),
      isEmpty,
    );
  });
}
