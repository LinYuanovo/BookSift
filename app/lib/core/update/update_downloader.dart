/// Cross-platform, resumable update package downloader.
///
/// This library deliberately stays on the pure Dart side of the update
/// feature. It owns HTTP Range requests, the on-disk manifest, the partial
/// file and the final cache entry; platform installation is handled elsewhere.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

/// A single update asset download.
final class UpdateDownloadRequest {
  const UpdateDownloadRequest({
    required this.url,
    required this.fileName,
    required this.cacheKey,
    this.expectedSha256,
    this.version,
  });

  final String url;
  final String fileName;
  final String cacheKey;
  final String? expectedSha256;
  final String? version;
}

/// A progress snapshot emitted after a chunk or stream write.
final class UpdateDownloadProgress {
  const UpdateDownloadProgress({
    required this.downloadedBytes,
    required this.totalBytes,
    required this.completedChunks,
    required this.totalChunks,
    required this.activeChunks,
    this.resumed = false,
  });

  final int downloadedBytes;
  final int totalBytes;
  final int completedChunks;
  final int totalChunks;
  final int activeChunks;
  final bool resumed;

  double? get fraction =>
      totalBytes <= 0 ? null : (downloadedBytes / totalBytes).clamp(0.0, 1.0);
}

/// A verified or cache-reused package.
final class UpdateDownloadResult {
  const UpdateDownloadResult({
    required this.file,
    required this.bytes,
    required this.sha256,
    required this.reusedCache,
    required this.resumed,
  });

  final File file;
  final int bytes;
  final String sha256;
  final bool reusedCache;
  final bool resumed;
}

final class UpdateDownloadException implements Exception {
  const UpdateDownloadException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'UpdateDownloadException: $message'
      : 'UpdateDownloadException: $message ($cause)';
}

/// Injectable download port used by the Riverpod controller and tests.
abstract interface class UpdateDownloader {
  Future<UpdateDownloadResult> download(
    UpdateDownloadRequest request, {
    void Function(UpdateDownloadProgress progress)? onProgress,
    CancelToken? cancelToken,
  });
}

/// Thrown internally when a server ignores a Range request. The caller can
/// safely restart as a single stream because no response bytes were written.
final class _RangeUnsupported implements Exception {
  const _RangeUnsupported(this.message);

  final String message;
}

final class _DownloadManifest {
  const _DownloadManifest({
    required this.url,
    required this.fileName,
    required this.cacheKey,
    required this.version,
    required this.expectedSha256,
    required this.totalBytes,
    required this.chunkSize,
    required this.rangeSupported,
    required this.completedChunks,
    required this.completedBytes,
    this.sha256,
  });

  final String url;
  final String fileName;
  final String cacheKey;
  final String? version;
  final String? expectedSha256;
  final int totalBytes;
  final int chunkSize;
  final bool rangeSupported;
  final Set<int> completedChunks;
  final int completedBytes;
  final String? sha256;

  _DownloadManifest copyWith({
    int? totalBytes,
    bool? rangeSupported,
    Set<int>? completedChunks,
    int? completedBytes,
    String? sha256,
  }) => _DownloadManifest(
    url: url,
    fileName: fileName,
    cacheKey: cacheKey,
    version: version,
    expectedSha256: expectedSha256,
    totalBytes: totalBytes ?? this.totalBytes,
    chunkSize: chunkSize,
    rangeSupported: rangeSupported ?? this.rangeSupported,
    completedChunks: completedChunks ?? this.completedChunks,
    completedBytes: completedBytes ?? this.completedBytes,
    sha256: sha256 ?? this.sha256,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'url': url,
    'fileName': fileName,
    'cacheKey': cacheKey,
    'version': version,
    'expectedSha256': expectedSha256,
    'totalBytes': totalBytes,
    'chunkSize': chunkSize,
    'rangeSupported': rangeSupported,
    'completedChunks': completedChunks.toList()..sort(),
    'completedBytes': completedBytes,
    'sha256': sha256,
  };

  static _DownloadManifest? fromJson(Object? value) {
    if (value is! Map) return null;
    final Object? total = value['totalBytes'];
    final Object? chunk = value['chunkSize'];
    final Object? completed = value['completedChunks'];
    if (total is! num || chunk is! num || completed is! List) return null;
    final Set<int> chunks = <int>{};
    for (final Object? item in completed) {
      if (item is! num || item.toInt() < 0) return null;
      chunks.add(item.toInt());
    }
    return _DownloadManifest(
      url: value['url'] is String ? value['url'] as String : '',
      fileName: value['fileName'] is String ? value['fileName'] as String : '',
      cacheKey: value['cacheKey'] is String ? value['cacheKey'] as String : '',
      version: value['version'] is String ? value['version'] as String : null,
      expectedSha256: value['expectedSha256'] is String
          ? value['expectedSha256'] as String
          : null,
      totalBytes: total.toInt(),
      chunkSize: chunk.toInt(),
      rangeSupported: value['rangeSupported'] == true,
      completedChunks: chunks,
      completedBytes: value['completedBytes'] is num
          ? (value['completedBytes'] as num).toInt()
          : 0,
      sha256: value['sha256'] is String ? value['sha256'] as String : null,
    );
  }

  bool matches(UpdateDownloadRequest request, String expected, int size) =>
      url == request.url &&
      fileName == request.fileName &&
      cacheKey == request.cacheKey &&
      version == request.version &&
      (expected.isEmpty || (expectedSha256 ?? '') == expected) &&
      chunkSize == size;
}

final class _ProbeResult {
  const _ProbeResult({
    required this.totalBytes,
    required this.rangeSupported,
    this.fullResponse,
  });

  final int totalBytes;
  final bool rangeSupported;
  final Response<ResponseBody>? fullResponse;
}

final class _ManifestWriter {
  _ManifestWriter(this.file, this.writeManifest);

  final File file;
  final Future<void> Function(File, _DownloadManifest) writeManifest;
  Future<void> _tail = Future<void>.value();

  Future<void> write(_DownloadManifest manifest) async {
    final Future<void> previous = _tail;
    final Completer<void> next = Completer<void>();
    _tail = next.future;
    await previous;
    try {
      await writeManifest(file, manifest);
    } finally {
      next.complete();
    }
  }
}

/// Multi-range downloader with persistent chunk state.
///
/// Each completed range is written to its own cache file before its manifest
/// entry is persisted, so independent workers never contend for one file handle.
final class ResumableUpdateDownloader implements UpdateDownloader {
  ResumableUpdateDownloader(
    this.dio,
    this.cacheDirectory, {
    this.chunkSize = 2 * 1024 * 1024,
    this.maxConcurrent = 4,
    this.retryLimit = 3,
  });

  final Dio dio;
  final Directory cacheDirectory;
  final int chunkSize;
  final int maxConcurrent;
  final int retryLimit;

  @override
  Future<UpdateDownloadResult> download(
    UpdateDownloadRequest request, {
    void Function(UpdateDownloadProgress progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    _validate(request);
    final CancelToken token = cancelToken ?? CancelToken();
    await cacheDirectory.create(recursive: true);
    final String identity = <String>[
      request.cacheKey,
      request.url,
      request.fileName,
      request.version ?? '',
      request.expectedSha256?.trim().toLowerCase() ?? '',
    ].join('\n');
    final String safeKey = sha256
        .convert(utf8.encode(identity))
        .toString()
        .substring(0, 32);
    final String safeName = _safePart(p.basename(request.fileName));
    final String stem = '$safeKey-$safeName';
    final File part = File(p.join(cacheDirectory.path, '$stem.part'));
    final File manifestFile = File(
      p.join(cacheDirectory.path, '$stem.manifest.json'),
    );
    final File finalFile = File(p.join(cacheDirectory.path, stem));
    final String expected = request.expectedSha256?.trim().toLowerCase() ?? '';

    _DownloadManifest? manifest = await _readManifest(manifestFile);
    if (manifest == null || !manifest.matches(request, expected, chunkSize)) {
      await _clearCacheFiles(
        stem,
        part,
        manifestFile,
        finalFile,
        deleteFinal: false,
      );
      manifest = null;
    }

    _checkCanceled(token, request.url);
    if (await finalFile.exists()) {
      final int length = await finalFile.length();
      final String hash = await _hash(finalFile);
      final bool hasVerifiedManifest =
          manifest != null &&
          manifest.totalBytes == length &&
          manifest.completedBytes == length &&
          manifest.completedChunks.length == _chunkCount(length) &&
          manifest.sha256 == hash;
      if ((expected.isNotEmpty && hash == expected) || hasVerifiedManifest) {
        _emit(
          onProgress,
          UpdateDownloadProgress(
            downloadedBytes: length,
            totalBytes: length,
            completedChunks: _chunkCount(length),
            totalChunks: _chunkCount(length),
            activeChunks: 0,
          ),
        );
        return UpdateDownloadResult(
          file: finalFile,
          bytes: length,
          sha256: hash,
          reusedCache: true,
          resumed: false,
        );
      }
      await finalFile.delete();
    }

    final bool canResumeSingleStream =
        manifest != null &&
        !manifest.rangeSupported &&
        manifest.totalBytes > 0 &&
        await part.exists() &&
        await part.length() > 0;
    final _ProbeResult probe = canResumeSingleStream
        ? _ProbeResult(totalBytes: manifest.totalBytes, rangeSupported: false)
        : await _probe(request.url, token);
    final int totalBytes = probe.totalBytes;
    if (totalBytes <= 0 && probe.fullResponse == null) {
      throw const UpdateDownloadException('响应缺少文件长度');
    }

    if (manifest == null || manifest.totalBytes != totalBytes) {
      if (manifest != null) {
        await _clearCacheFiles(stem, part, manifestFile, finalFile);
      }
      manifest = _DownloadManifest(
        url: request.url,
        fileName: request.fileName,
        cacheKey: request.cacheKey,
        version: request.version,
        expectedSha256: expected,
        totalBytes: totalBytes,
        chunkSize: chunkSize,
        rangeSupported: probe.rangeSupported,
        completedChunks: <int>{},
        completedBytes: 0,
      );
      await _writeManifest(manifestFile, manifest);
    }

    final bool resumed =
        manifest.completedChunks.isNotEmpty ||
        (await part.exists() && await part.length() > 0);
    if (probe.rangeSupported && totalBytes > 0 && probe.fullResponse == null) {
      try {
        return await _downloadRanges(
          request,
          part,
          manifestFile,
          finalFile,
          manifest,
          onProgress,
          token,
          resumed,
        );
      } on _RangeUnsupported {
        await _clearCacheFiles(stem, part, manifestFile, finalFile);
        manifest = _DownloadManifest(
          url: request.url,
          fileName: request.fileName,
          cacheKey: request.cacheKey,
          version: request.version,
          expectedSha256: expected,
          totalBytes: totalBytes,
          chunkSize: chunkSize,
          rangeSupported: false,
          completedChunks: <int>{},
          completedBytes: 0,
        );
        await _writeManifest(manifestFile, manifest);
      }
    }

    return _downloadSingle(
      request,
      part,
      manifestFile,
      finalFile,
      manifest,
      probe.fullResponse,
      onProgress,
      token,
      resumed,
    );
  }

  Future<UpdateDownloadResult> _downloadRanges(
    UpdateDownloadRequest request,
    File part,
    File manifestFile,
    File finalFile,
    _DownloadManifest manifest,
    void Function(UpdateDownloadProgress progress)? onProgress,
    CancelToken token,
    bool resumed,
  ) async {
    final int totalChunks = _chunkCount(manifest.totalBytes);
    final Set<int> completed = <int>{...manifest.completedChunks};
    for (final int index in <int>{...completed}) {
      final File chunk = _chunkFile(part, index);
      if (!await chunk.exists() ||
          await chunk.length() != _chunkLength(index, manifest.totalBytes)) {
        completed.remove(index);
        if (await chunk.exists()) await chunk.delete();
      }
    }
    final Queue<int> pending = Queue<int>.from(
      Iterable<int>.generate(
        totalChunks,
      ).where((int i) => !completed.contains(i)),
    );
    final _ManifestWriter manifestWriter = _ManifestWriter(
      manifestFile,
      _writeManifest,
    );
    final CancelToken rangeToken = CancelToken();
    bool rangeUnsupported = false;
    Object? workerFailure;
    unawaited(
      token.whenCancel.then<void>((DioException error) {
        rangeToken.cancel(error);
      }),
    );
    int active = 0;
    int completedBytes = _completedBytes(manifest, completed);
    manifest = manifest.copyWith(completedBytes: completedBytes);
    _emit(
      onProgress,
      UpdateDownloadProgress(
        downloadedBytes: completedBytes,
        totalBytes: manifest.totalBytes,
        completedChunks: completed.length,
        totalChunks: totalChunks,
        activeChunks: 0,
        resumed: resumed,
      ),
    );

    Future<void> worker() async {
      while (true) {
        if (rangeUnsupported || workerFailure != null) return;
        _checkCanceled(token, request.url);
        if (pending.isEmpty) return;
        final int index = pending.removeFirst();
        active++;
        try {
          final List<int> bytes = await _fetchChunkWithRetry(
            request.url,
            index,
            manifest.totalBytes,
            rangeToken,
          );
          await _chunkFile(part, index).writeAsBytes(bytes, flush: true);
          completed.add(index);
          completedBytes += bytes.length;
          manifest = manifest.copyWith(
            completedChunks: <int>{...completed},
            completedBytes: completedBytes,
          );
          await manifestWriter.write(manifest);
          _emit(
            onProgress,
            UpdateDownloadProgress(
              downloadedBytes: completedBytes,
              totalBytes: manifest.totalBytes,
              completedChunks: completed.length,
              totalChunks: totalChunks,
              activeChunks: active,
              resumed: resumed,
            ),
          );
        } on _RangeUnsupported {
          rangeUnsupported = true;
          rangeToken.cancel('server ignored HTTP Range');
        } on Object catch (error) {
          if (token.isCancelled) {
            workerFailure ??= error;
            rangeToken.cancel(error);
          } else if (!rangeUnsupported) {
            workerFailure ??= error;
            rangeToken.cancel(error);
          }
        } finally {
          active--;
        }
      }
    }

    final int workerCount = pending.isEmpty
        ? 0
        : maxConcurrent.clamp(1, pending.length);
    await Future.wait<void>(
      List<Future<void>>.generate(workerCount, (_) => worker()),
    );
    _checkCanceled(token, request.url);
    if (rangeUnsupported) throw const _RangeUnsupported('服务器不支持 Range');
    final Object? failure = workerFailure;
    if (failure != null) throw failure;

    await _assembleChunks(part, totalChunks);
    final String hash = await _hash(part);
    if (manifest.totalBytes != await part.length() ||
        (request.expectedSha256?.isNotEmpty == true &&
            hash != request.expectedSha256!.trim().toLowerCase())) {
      await _clearCacheFiles(_stemForPart(part), part, manifestFile, finalFile);
      throw const UpdateDownloadException('下载校验失败：文件长度或 SHA-256 不匹配');
    }
    manifest = manifest.copyWith(sha256: hash);
    await manifestWriter.write(manifest);
    await _replace(part, finalFile);
    await _deleteChunks(part);
    for (int index = 0; index < totalChunks; index++) {
      final File chunk = _chunkFile(part, index);
      if (await chunk.exists()) await chunk.delete();
    }
    _emit(
      onProgress,
      UpdateDownloadProgress(
        downloadedBytes: manifest.totalBytes,
        totalBytes: manifest.totalBytes,
        completedChunks: totalChunks,
        totalChunks: totalChunks,
        activeChunks: 0,
        resumed: resumed,
      ),
    );
    return UpdateDownloadResult(
      file: finalFile,
      bytes: manifest.totalBytes,
      sha256: hash,
      reusedCache: false,
      resumed: resumed,
    );
  }

  Future<List<int>> _fetchChunkWithRetry(
    String url,
    int index,
    int totalBytes,
    CancelToken token,
  ) async {
    Object? lastError;
    final int start = index * chunkSize;
    final int end = (start + chunkSize - 1).clamp(start, totalBytes - 1);
    final int expectedLength = end - start + 1;
    for (int attempt = 0; attempt <= retryLimit; attempt++) {
      _checkCanceled(token, url);
      try {
        final Response<ResponseBody> response = await dio.get<ResponseBody>(
          url,
          cancelToken: token,
          options: Options(
            responseType: ResponseType.stream,
            validateStatus: (_) => true,
            headers: <String, String>{'Range': 'bytes=$start-$end'},
          ),
        );
        if (response.statusCode != HttpStatus.partialContent) {
          await response.data?.stream.listen(null).cancel();
          throw _RangeUnsupported(
            'Range 请求返回 HTTP ${response.statusCode ?? '?'}',
          );
        }
        final (int? rangeStart, int? rangeEnd, int? rangeTotal) =
            _rangePosition(response.headers);
        if (rangeStart != start ||
            rangeEnd != end ||
            rangeTotal != totalBytes) {
          await response.data?.stream.listen(null).cancel();
          throw UpdateDownloadException(
            '分块区间不符：期望 $start-$end/$totalBytes，实际 $rangeStart-$rangeEnd/$rangeTotal',
          );
        }
        final List<int> bytes = await _readBody(response.data, token, url);
        if (bytes.length != expectedLength) {
          throw UpdateDownloadException(
            '分块长度不符：期望 $expectedLength，实际 ${bytes.length}',
          );
        }
        return bytes;
      } on _RangeUnsupported {
        rethrow;
      } on Object catch (error) {
        if (token.isCancelled) rethrow;
        lastError = error;
      }
    }
    throw UpdateDownloadException('分块下载失败（$start-$end）', lastError);
  }

  Future<UpdateDownloadResult> _downloadSingle(
    UpdateDownloadRequest request,
    File part,
    File manifestFile,
    File finalFile,
    _DownloadManifest manifest,
    Response<ResponseBody>? initialResponse,
    void Function(UpdateDownloadProgress progress)? onProgress,
    CancelToken token,
    bool resumed,
  ) async {
    final int existingBytes = await part.exists() ? await part.length() : 0;
    final Response<ResponseBody> response =
        initialResponse ??
        await dio.get<ResponseBody>(
          request.url,
          cancelToken: token,
          options: Options(
            responseType: ResponseType.stream,
            validateStatus: (_) => true,
            headers: existingBytes > 0
                ? <String, String>{'Range': 'bytes=$existingBytes-'}
                : null,
          ),
        );
    _checkCanceled(token, request.url);
    if (response.statusCode != HttpStatus.ok &&
        response.statusCode != HttpStatus.partialContent) {
      throw UpdateDownloadException(
        '下载请求失败：HTTP ${response.statusCode ?? '?'}',
      );
    }
    final bool append =
        existingBytes > 0 &&
        response.statusCode == HttpStatus.partialContent &&
        initialResponse == null;
    if (append) {
      final (int? rangeStart, int? rangeEnd, int? rangeTotal) = _rangePosition(
        response.headers,
      );
      if (rangeStart != existingBytes ||
          rangeEnd != manifest.totalBytes - 1 ||
          rangeTotal != manifest.totalBytes) {
        await response.data?.stream.listen(null).cancel();
        throw const UpdateDownloadException('续传响应区间不匹配');
      }
    } else if (response.statusCode == HttpStatus.partialContent) {
      await response.data?.stream.listen(null).cancel();
      throw const UpdateDownloadException('完整下载意外收到部分响应');
    }
    final int start = append ? existingBytes : 0;
    if (!append && existingBytes > 0) {
      await part.writeAsBytes(const <int>[], flush: true);
    }
    final int responseLength =
        int.tryParse(
          response.headers.value(Headers.contentLengthHeader) ?? '',
        ) ??
        0;
    final int total = append
        ? _rangePosition(response.headers).$3!
        : (manifest.totalBytes > 0 ? manifest.totalBytes : responseLength);
    int downloaded = start;
    _emit(
      onProgress,
      UpdateDownloadProgress(
        downloadedBytes: downloaded,
        totalBytes: total,
        completedChunks: 0,
        totalChunks: _chunkCount(total),
        activeChunks: 1,
        resumed: resumed && append,
      ),
    );
    final IOSink sink = part.openWrite(
      mode: append ? FileMode.append : FileMode.write,
    );
    try {
      final ResponseBody? body = response.data;
      if (body == null) throw const UpdateDownloadException('下载响应为空');
      await for (final List<int> bytes in body.stream) {
        _checkCanceled(token, request.url);
        sink.add(bytes);
        downloaded += bytes.length;
        _emit(
          onProgress,
          UpdateDownloadProgress(
            downloadedBytes: downloaded,
            totalBytes: total,
            completedChunks: _chunkCount(downloaded),
            totalChunks: _chunkCount(total),
            activeChunks: 1,
            resumed: resumed && append,
          ),
        );
      }
    } finally {
      await sink.close();
    }
    final int bytes = await part.length();
    if (total > 0 && bytes != total) {
      throw const UpdateDownloadException('下载内容不完整');
    }
    final String hash = await _hash(part);
    final String expected = request.expectedSha256?.trim().toLowerCase() ?? '';
    if (expected.isNotEmpty && hash != expected) {
      await _clearCacheFiles(_stemForPart(part), part, manifestFile, finalFile);
      throw const UpdateDownloadException('下载校验失败：SHA-256 不匹配');
    }
    final _DownloadManifest completed = manifest.copyWith(
      totalBytes: bytes,
      rangeSupported: false,
      completedChunks: <int>{...Iterable<int>.generate(_chunkCount(bytes))},
      completedBytes: bytes,
      sha256: hash,
    );
    await _writeManifest(manifestFile, completed);
    await _replace(part, finalFile);
    return UpdateDownloadResult(
      file: finalFile,
      bytes: bytes,
      sha256: hash,
      reusedCache: false,
      resumed: resumed && append,
    );
  }

  Future<_ProbeResult> _probe(String url, CancelToken token) async {
    try {
      final Response<void> head = await dio.request<void>(
        url,
        cancelToken: token,
        options: Options(method: 'HEAD', validateStatus: (_) => true),
      );
      final int length = _contentLength(head.headers);
      final bool ranges =
          (head.headers.value('accept-ranges') ?? '').toLowerCase() == 'bytes';
      if (head.statusCode != null &&
          head.statusCode! >= 200 &&
          head.statusCode! < 300 &&
          length > 0 &&
          ranges) {
        return _ProbeResult(totalBytes: length, rangeSupported: true);
      }
    } catch (_) {
      // A server may reject HEAD. The one-byte range probe below is the
      // fallback and is also how we detect servers that omit Accept-Ranges.
    }
    _checkCanceled(token, url);
    final Response<ResponseBody> range = await dio.get<ResponseBody>(
      url,
      cancelToken: token,
      options: Options(
        responseType: ResponseType.stream,
        validateStatus: (_) => true,
        headers: <String, String>{'Range': 'bytes=0-0'},
      ),
    );
    if (range.statusCode == HttpStatus.partialContent) {
      final (int? start, int? end, int? total) = _rangePosition(range.headers);
      if (start == 0 && end == 0 && total != null && total > 0) {
        await range.data?.stream.drain<void>();
        return _ProbeResult(totalBytes: total, rangeSupported: true);
      }
      await range.data?.stream.listen(null).cancel();
      final Response<ResponseBody> full = await dio.get<ResponseBody>(
        url,
        cancelToken: token,
        options: Options(
          responseType: ResponseType.stream,
          validateStatus: (_) => true,
        ),
      );
      if (full.statusCode == HttpStatus.ok) {
        return _ProbeResult(
          totalBytes: _contentLength(full.headers),
          rangeSupported: false,
          fullResponse: full,
        );
      }
      throw UpdateDownloadException('下载探测失败：HTTP ${full.statusCode ?? '?'}');
    }
    if (range.statusCode == HttpStatus.ok) {
      final int length = _contentLength(range.headers);
      return _ProbeResult(
        totalBytes: length,
        rangeSupported: false,
        fullResponse: range,
      );
    }
    throw UpdateDownloadException('下载探测失败：HTTP ${range.statusCode ?? '?'}');
  }

  Future<List<int>> _readBody(
    ResponseBody? body,
    CancelToken token,
    String url,
  ) async {
    if (body == null) throw const UpdateDownloadException('下载响应为空');
    final BytesBuilder builder = BytesBuilder(copy: false);
    await for (final List<int> bytes in body.stream) {
      _checkCanceled(token, url);
      builder.add(bytes);
    }
    return builder.takeBytes();
  }

  Future<_DownloadManifest?> _readManifest(File file) async {
    if (!await file.exists()) return null;
    try {
      return _DownloadManifest.fromJson(jsonDecode(await file.readAsString()));
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeManifest(File file, _DownloadManifest manifest) async {
    final File temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(manifest.toJson()), flush: true);
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }

  File _chunkFile(File part, int index) => File('${part.path}.chunk-$index');

  String _stemForPart(File part) {
    final String name = p.basename(part.path);
    return name.endsWith('.part')
        ? name.substring(0, name.length - '.part'.length)
        : name;
  }

  int _chunkLength(int index, int totalBytes) {
    final int start = index * chunkSize;
    return (start + chunkSize).clamp(start, totalBytes) - start;
  }

  Future<void> _assembleChunks(File part, int totalChunks) async {
    final IOSink sink = part.openWrite();
    try {
      for (int index = 0; index < totalChunks; index++) {
        await sink.addStream(_chunkFile(part, index).openRead());
      }
    } finally {
      await sink.close();
    }
  }

  Future<void> _deleteChunks(File part) async {
    if (!await part.parent.exists()) return;
    await for (final FileSystemEntity entity in part.parent.list()) {
      if (entity is File &&
          p
              .basename(entity.path)
              .startsWith('${p.basename(part.path)}.chunk-')) {
        await entity.delete();
      }
    }
  }

  Future<void> _replace(File source, File target) async {
    if (await target.exists()) await target.delete();
    await source.rename(target.path);
  }

  Future<void> _clearCacheFiles(
    String stem,
    File part,
    File manifest,
    File finalFile, {
    bool deleteFinal = true,
  }) async {
    for (final File file in <File>[
      part,
      manifest,
      if (deleteFinal) finalFile,
      File('${manifest.path}.tmp'),
    ]) {
      if (await file.exists()) await file.delete();
    }
    if (await part.parent.exists()) {
      await for (final FileSystemEntity entity in part.parent.list()) {
        if (entity is File &&
            p.basename(entity.path).startsWith('$stem.part.chunk-')) {
          await entity.delete();
        }
      }
    }
  }

  int _completedBytes(_DownloadManifest manifest, Set<int> completed) {
    int bytes = 0;
    for (final int index in completed) {
      final int start = index * manifest.chunkSize;
      if (start >= manifest.totalBytes) continue;
      bytes +=
          (start + manifest.chunkSize).clamp(start, manifest.totalBytes) -
          start;
    }
    return bytes;
  }

  int _chunkCount(int bytes) =>
      bytes <= 0 ? 0 : (bytes + chunkSize - 1) ~/ chunkSize;

  int _contentLength(Headers headers) =>
      int.tryParse(headers.value(Headers.contentLengthHeader) ?? '') ?? 0;

  (int?, int?, int?) _rangePosition(Headers headers) {
    final String? value = headers.value('content-range');
    if (value == null) return (null, null, null);
    final RegExpMatch? match = RegExp(
      r'bytes\s+(\d+)-(\d+)/(\d+)',
    ).firstMatch(value);
    if (match == null) return (null, null, null);
    return (
      int.tryParse(match.group(1)!),
      int.tryParse(match.group(2)!),
      int.tryParse(match.group(3)!),
    );
  }

  void _validate(UpdateDownloadRequest request) {
    if (request.url.trim().isEmpty) {
      throw const UpdateDownloadException('下载链接为空');
    }
    if (request.fileName.trim().isEmpty || request.cacheKey.trim().isEmpty) {
      throw const UpdateDownloadException('下载文件名或缓存键为空');
    }
    final String expected = request.expectedSha256?.trim() ?? '';
    if (expected.isNotEmpty &&
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(expected)) {
      throw const UpdateDownloadException('expectedSha256 不是 64 位十六进制摘要');
    }
    if (chunkSize <= 0 || maxConcurrent <= 0 || retryLimit < 0) {
      throw const UpdateDownloadException('下载参数无效');
    }
  }

  void _checkCanceled(CancelToken token, String url) {
    if (!token.isCancelled) return;
    throw DioException(
      requestOptions: RequestOptions(path: url),
      type: DioExceptionType.cancel,
      error: token.cancelError,
    );
  }

  void _emit(
    void Function(UpdateDownloadProgress progress)? callback,
    UpdateDownloadProgress progress,
  ) {
    callback?.call(progress);
  }

  Future<String> _hash(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  String _safePart(String value) {
    final String clean = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return clean.isEmpty
        ? sha256.convert(utf8.encode(value)).toString().substring(0, 16)
        : clean;
  }
}
