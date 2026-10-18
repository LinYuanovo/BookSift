import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'update_controller.dart';
import 'update_downloader.dart';
import 'update_platform.dart';
import 'update_service.dart';

typedef UpdatePlatformActions = UpdatePlatformPort;

final Provider<UpdatePlatformActions> defaultUpdatePlatformActions =
    Provider<UpdatePlatformActions>((Ref ref) => const DefaultUpdatePlatform());

final Provider<UpdatePlatformActions> updatePlatformProvider =
    Provider<UpdatePlatformActions>(
      (Ref ref) => ref.watch(defaultUpdatePlatformActions),
    );

final class DefaultUpdateDownloader implements UpdateDownloader {
  DefaultUpdateDownloader({required this.dio, required this.platform});

  final Dio dio;
  final UpdatePlatformPort platform;
  ResumableUpdateDownloader? _delegate;

  @override
  Future<UpdateDownloadResult> download(
    UpdateDownloadRequest request, {
    void Function(UpdateDownloadProgress progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final ResumableUpdateDownloader downloader = _delegate ??=
        ResumableUpdateDownloader(
          dio,
          Directory(
            p.join(
              (await platform.getApplicationSupportDirectory()).path,
              'update-cache',
            ),
          ),
        );
    return downloader.download(
      request,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }
}

final Provider<UpdateDownloader> updateDownloaderProvider =
    Provider<UpdateDownloader>((Ref ref) {
      return DefaultUpdateDownloader(
        dio: ref.watch(updateDioProvider),
        platform: ref.watch(updatePlatformProvider),
      );
    });

enum UpdateDownloadStatus { idle, downloading, ready, failed, canceled }

@immutable
final class UpdateDownloadState {
  const UpdateDownloadState({
    required this.status,
    this.resourceKey,
    this.progress,
    this.result,
    this.error,
  });

  const UpdateDownloadState.idle() : this(status: UpdateDownloadStatus.idle);

  final UpdateDownloadStatus status;
  final String? resourceKey;
  final UpdateDownloadProgress? progress;
  final UpdateDownloadResult? result;
  final Object? error;

  bool get isDownloading => status == UpdateDownloadStatus.downloading;
}

String updateDownloadResourceKey(UpdateInfo info, TargetPlatform target) {
  final UpdatePlatformAsset? asset = platformAsset(info, target);
  if (asset == null) return '';
  final String raw =
      '${target.name}|${asset.url}|${asset.sha256 ?? ''}|${info.version}';
  return sha256.convert(utf8.encode(raw)).toString().substring(0, 24);
}

final class UpdateDownloadController extends Notifier<UpdateDownloadState> {
  Future<UpdateDownloadResult?>? _active;
  CancelToken? _cancelToken;
  String? _activeKey;
  int _generation = 0;
  bool _disposed = false;

  @override
  UpdateDownloadState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _generation++;
      _cancelToken?.cancel('下载控制器已释放');
      _cancelToken = null;
      _active = null;
      _activeKey = null;
    });
    return const UpdateDownloadState.idle();
  }

  Future<UpdateDownloadResult?> download(
    UpdateInfo info, {
    TargetPlatform? target,
  }) {
    final TargetPlatform platform = target ?? defaultTargetPlatform;
    final UpdatePlatformAsset? asset = platformAsset(info, platform);
    if (asset == null || asset.url == null || asset.url!.isEmpty) {
      const UpdateDownloadException error = UpdateDownloadException(
        '该版本未提供下载链接',
      );
      if (!_disposed) {
        state = const UpdateDownloadState(
          status: UpdateDownloadStatus.failed,
          error: error,
        );
      }
      return Future<UpdateDownloadResult?>.value(null);
    }

    final String key = updateDownloadResourceKey(info, platform);
    final Future<UpdateDownloadResult?>? active = _active;
    if (active != null && _activeKey == key) return active;
    if (state.status == UpdateDownloadStatus.ready &&
        state.resourceKey == key &&
        state.result != null) {
      return Future<UpdateDownloadResult?>.value(state.result);
    }
    if (active != null) cancel();

    final int generation = ++_generation;
    final CancelToken cancelToken = CancelToken();
    _cancelToken = cancelToken;
    _activeKey = key;
    if (!_disposed) {
      state = UpdateDownloadState(
        status: UpdateDownloadStatus.downloading,
        resourceKey: key,
        progress: const UpdateDownloadProgress(
          downloadedBytes: 0,
          totalBytes: 0,
          completedChunks: 0,
          totalChunks: 0,
          activeChunks: 0,
        ),
      );
    }

    final Future<UpdateDownloadResult?> future = _run(
      generation,
      key,
      UpdateDownloadRequest(
        url: asset.url!,
        fileName: asset.fileName,
        cacheKey: key,
        expectedSha256: asset.sha256,
        version: info.version,
      ),
      cancelToken,
    );
    _active = future;
    return future;
  }

  Future<UpdateDownloadResult?> start(
    UpdateInfo info, {
    TargetPlatform? target,
  }) => download(info, target: target);

  void cancel() {
    final CancelToken? token = _cancelToken;
    if (token == null || token.isCancelled) return;
    final String? key = _activeKey;
    final UpdateDownloadProgress? progress = state.progress;
    _generation++;
    token.cancel('用户取消下载');
    _active = null;
    _activeKey = null;
    _cancelToken = null;
    if (!_disposed) {
      state = UpdateDownloadState(
        status: UpdateDownloadStatus.canceled,
        resourceKey: key,
        progress: progress,
      );
    }
  }

  Future<bool> openDownloadedFile(
    UpdateInfo info, {
    TargetPlatform? target,
  }) async {
    final TargetPlatform platform = target ?? defaultTargetPlatform;
    final String key = updateDownloadResourceKey(info, platform);
    final UpdateDownloadResult? result = state.resourceKey == key
        ? state.result
        : null;
    if (result == null || _disposed) return false;
    return ref
        .read(updatePlatformProvider)
        .openDownloadedFile(result.file.path, platform);
  }

  Future<bool> installDownloadedFile(
    UpdateInfo info, {
    TargetPlatform? target,
  }) async {
    final TargetPlatform platform = target ?? defaultTargetPlatform;
    final String key = updateDownloadResourceKey(info, platform);
    final UpdateDownloadResult? result = state.resourceKey == key
        ? state.result
        : null;
    if (result == null || _disposed) return false;
    return ref
        .read(updatePlatformProvider)
        .installDownloadedFile(result.file.path, platform);
  }

  Future<UpdateDownloadResult?> _run(
    int generation,
    String key,
    UpdateDownloadRequest request,
    CancelToken cancelToken,
  ) async {
    try {
      final UpdateDownloadResult result = await ref
          .read(updateDownloaderProvider)
          .download(
            request,
            cancelToken: cancelToken,
            onProgress: (UpdateDownloadProgress progress) {
              if (!_disposed && generation == _generation) {
                state = UpdateDownloadState(
                  status: UpdateDownloadStatus.downloading,
                  resourceKey: key,
                  progress: progress,
                );
              }
            },
          );
      if (!_disposed && generation == _generation) {
        state = UpdateDownloadState(
          status: UpdateDownloadStatus.ready,
          resourceKey: key,
          progress: state.progress,
          result: result,
        );
      }
      return result;
    } on DioException catch (error) {
      if (!_disposed && generation == _generation) {
        state = UpdateDownloadState(
          status:
              error.type == DioExceptionType.cancel || cancelToken.isCancelled
              ? UpdateDownloadStatus.canceled
              : UpdateDownloadStatus.failed,
          resourceKey: key,
          progress: state.progress,
          error: error.type == DioExceptionType.cancel ? null : error,
        );
      }
      return null;
    } on Object catch (error) {
      if (!_disposed && generation == _generation) {
        state = UpdateDownloadState(
          status: UpdateDownloadStatus.failed,
          resourceKey: key,
          progress: state.progress,
          error: error,
        );
      }
      return null;
    } finally {
      if (generation == _generation) {
        _active = null;
        _activeKey = null;
        _cancelToken = null;
      }
    }
  }
}

final NotifierProvider<UpdateDownloadController, UpdateDownloadState>
updateDownloadControllerProvider =
    NotifierProvider<UpdateDownloadController, UpdateDownloadState>(
      UpdateDownloadController.new,
    );
