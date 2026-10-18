import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:url_launcher/url_launcher.dart';

import 'update_service.dart';

const String kUpdatePlatformChannel = 'booksift/update';

/// One release asset selected for a target platform.
final class UpdatePlatformAsset {
  const UpdatePlatformAsset({required this.fileName, this.url, this.sha256});

  final String fileName;
  final String? url;
  final String? sha256;

  String get name => fileName;

  @override
  bool operator ==(Object other) =>
      other is UpdatePlatformAsset &&
      other.fileName == fileName &&
      other.url == url &&
      other.sha256 == sha256;

  @override
  int get hashCode => Object.hash(fileName, url, sha256);
}

/// Selects only the asset for [target]. A missing URL returns null so callers
/// cannot accidentally download another platform's package.
UpdatePlatformAsset? platformAsset(UpdateInfo info, TargetPlatform target) {
  final UpdatePlatformAsset? asset = switch (target) {
    TargetPlatform.android => UpdatePlatformAsset(
      fileName: 'android-v${info.version}.apk',
      url: info.apkUrl,
      sha256: info.apkSha256,
    ),
    TargetPlatform.iOS => UpdatePlatformAsset(
      fileName: 'ios-v${info.version}.ipa',
      url: info.iosUrl,
      sha256: info.iosSha256,
    ),
    TargetPlatform.windows => UpdatePlatformAsset(
      fileName: 'windows-x64-v${info.version}.zip',
      url: info.windowsUrl,
      sha256: info.windowsSha256,
    ),
    TargetPlatform.macOS => UpdatePlatformAsset(
      fileName: 'macos-universal-v${info.version}.zip',
      url: info.macosUrl,
      sha256: info.macosSha256,
    ),
    TargetPlatform.linux => UpdatePlatformAsset(
      fileName: 'linux-x64-v${info.version}.tar.gz',
      url: info.linuxUrl,
      sha256: info.linuxSha256,
    ),
    TargetPlatform.fuchsia => null,
  };
  if (asset == null || asset.url == null || asset.url!.isEmpty) return null;
  return asset;
}

UpdatePlatformAsset? currentPlatformAsset(UpdateInfo info) =>
    platformAsset(info, defaultTargetPlatform);

final class UpdatePlatformException implements Exception {
  const UpdatePlatformException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'UpdatePlatformException: $message'
      : 'UpdatePlatformException: $message ($cause)';
}

typedef UpdateDirectoryGetter = Future<Directory> Function();
typedef UpdateUrlOpener = Future<bool> Function(Uri uri);
typedef UpdateApkInstaller = Future<bool> Function(String path);
typedef UpdatePackageInstaller = Future<bool> Function(String path);
typedef UpdateFileLocationOpener = Future<bool> Function(String path);

/// Injectable platform operations. Production uses path_provider, url_launcher,
/// share_plus, and the Android update MethodChannel; tests can replace each one.
final class UpdatePlatformOperations {
  const UpdatePlatformOperations({
    this.applicationSupportDirectory,
    this.applicationCacheDirectory,
    this.openUrl,
    this.installApk,
    this.installPackage,
    this.openFileLocation,
  });

  final UpdateDirectoryGetter? applicationSupportDirectory;
  final UpdateDirectoryGetter? applicationCacheDirectory;
  final UpdateUrlOpener? openUrl;
  final UpdateApkInstaller? installApk;
  final UpdatePackageInstaller? installPackage;
  final UpdateFileLocationOpener? openFileLocation;
}

abstract interface class UpdatePlatformPort {
  Future<Directory> getApplicationSupportDirectory();

  Future<Directory> getApplicationCacheDirectory();

  Future<bool> openDownloadedFile(String path, TargetPlatform target);

  Future<bool> installDownloadedFile(String path, TargetPlatform target);

  Future<bool> openExternalUrl(String url);
}

/// Default update package adapter. It contains no download logic: callers own
/// the downloaded file and only hand its path to [openDownloadedFile].
final class DefaultUpdatePlatform implements UpdatePlatformPort {
  const DefaultUpdatePlatform([
    this.operations = const UpdatePlatformOperations(),
  ]);

  final UpdatePlatformOperations operations;

  @override
  Future<Directory> getApplicationSupportDirectory() =>
      operations.applicationSupportDirectory?.call() ??
      path_provider.getApplicationSupportDirectory();

  @override
  Future<Directory> getApplicationCacheDirectory() =>
      operations.applicationCacheDirectory?.call() ??
      path_provider.getApplicationCacheDirectory();

  @override
  Future<bool> openDownloadedFile(String path, TargetPlatform target) async {
    if (path.trim().isEmpty) {
      throw const UpdatePlatformException('下载文件路径为空');
    }
    try {
      final UpdatePackageInstaller? installer = operations.installPackage;
      if (installer != null) return installer(path);
      return switch (target) {
        TargetPlatform.android => await _installApk(path),
        TargetPlatform.iOS => await _openIpaLocation(path),
        TargetPlatform.windows ||
        TargetPlatform.macOS ||
        TargetPlatform.linux => await openExternalUrl(
          Uri.file(path).toString(),
        ),
        TargetPlatform.fuchsia => throw const UpdatePlatformException(
          '当前平台不支持打开更新包',
        ),
      };
    } on UpdatePlatformException {
      rethrow;
    } on Object catch (error) {
      throw UpdatePlatformException('无法打开更新包', error);
    }
  }

  @override
  Future<bool> installDownloadedFile(String path, TargetPlatform target) async {
    if (path.trim().isEmpty) {
      throw const UpdatePlatformException('下载文件路径为空');
    }
    try {
      final UpdatePackageInstaller? installer = operations.installPackage;
      if (installer != null) return installer(path);
      return switch (target) {
        TargetPlatform.android => _installApk(path),
        TargetPlatform.windows =>
          const MethodChannel(kUpdatePlatformChannel)
              .invokeMethod<bool>('installPackage', <String, Object>{
                'path': path,
                'bundle': File(Platform.resolvedExecutable).parent.path,
              })
              .then((bool? opened) => opened ?? false),
        TargetPlatform.linux =>
          const MethodChannel(kUpdatePlatformChannel)
              .invokeMethod<bool>('installPackage', <String, Object>{
                'path': path,
              })
              .then((bool? opened) => opened ?? false),
        TargetPlatform.iOS => _openIpaLocation(path),
        TargetPlatform.macOS => openExternalUrl(Uri.file(path).toString()),
        TargetPlatform.fuchsia => throw const UpdatePlatformException(
          '当前平台不支持应用内更新',
        ),
      };
    } on PlatformException catch (error) {
      if (error.code == 'permission_required') {
        throw UpdatePlatformException('请先在系统设置中允许安装未知应用，再点「安装更新」', error);
      }
      throw UpdatePlatformException(error.message ?? '无法启动更新安装', error);
    } on UpdatePlatformException {
      rethrow;
    } on Object catch (error) {
      throw UpdatePlatformException('无法启动更新安装', error);
    }
  }

  @override
  Future<bool> openExternalUrl(String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || !uri.isAbsolute || uri.scheme.isEmpty) {
      throw const UpdatePlatformException('外部链接无效');
    }
    try {
      final UpdateUrlOpener? opener = operations.openUrl;
      if (opener != null) return opener(uri);
      if (!await canLaunchUrl(uri)) return false;
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object catch (error) {
      throw UpdatePlatformException('无法打开外部链接', error);
    }
  }

  Future<bool> _installApk(String path) async {
    final UpdateApkInstaller? installer = operations.installApk;
    if (installer != null) return installer(path);
    try {
      final bool? opened = await const MethodChannel(
        kUpdatePlatformChannel,
      ).invokeMethod<bool>('installApk', <String, Object>{'path': path});
      return opened ?? false;
    } on PlatformException catch (error) {
      if (error.code == 'permission_required') {
        throw UpdatePlatformException('请先在系统设置中允许安装未知应用，再点「安装更新」', error);
      }
      rethrow;
    }
  }

  Future<bool> _openIpaLocation(String path) async {
    final UpdateFileLocationOpener? opener = operations.openFileLocation;
    if (opener != null) return opener(path);
    try {
      final File file = File(path);
      if (!await file.exists()) {
        throw const UpdatePlatformException('更新文件不存在');
      }
      final bool? opened = await const MethodChannel(
        kUpdatePlatformChannel,
      ).invokeMethod<bool>('openFileLocation', <String, Object>{'path': path});
      return opened ?? false;
    } on PlatformException catch (error) {
      throw UpdatePlatformException(error.message ?? '无法打开文件位置', error);
    }
  }
}

typedef UpdatePlatform = UpdatePlatformPort;

const DefaultUpdatePlatform defaultUpdatePlatform = DefaultUpdatePlatform();

Future<Directory> getApplicationSupportDirectory() =>
    defaultUpdatePlatform.getApplicationSupportDirectory();

Future<Directory> getApplicationCacheDirectory() =>
    defaultUpdatePlatform.getApplicationCacheDirectory();

Future<bool> openDownloadedFile(String path, TargetPlatform target) =>
    defaultUpdatePlatform.openDownloadedFile(path, target);

Future<bool> openExternalUrl(String url) =>
    defaultUpdatePlatform.openExternalUrl(url);
