import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/update/update_platform.dart';
import 'package:booksift/core/update/update_service.dart';

UpdateInfo testUpdateInfo({
  String? apkUrl = 'https://example.com/android.apk',
  String? iosUrl = 'https://example.com/ios.ipa',
  String? windowsUrl = 'https://example.com/windows.zip',
  String? macosUrl = 'https://example.com/macos.zip',
  String? linuxUrl = 'https://example.com/linux.tar.gz',
}) => UpdateInfo(
  version: '1.2.3',
  source: UpdateSourceKind.staticJson,
  apkUrl: apkUrl,
  apkSha256: 'apk-hash',
  iosUrl: iosUrl,
  iosSha256: 'ios-hash',
  windowsUrl: windowsUrl,
  windowsSha256: 'windows-hash',
  macosUrl: macosUrl,
  macosSha256: 'macos-hash',
  linuxUrl: linuxUrl,
  linuxSha256: 'linux-hash',
);

final class FakeUpdatePlatform implements UpdatePlatformPort {
  FakeUpdatePlatform({required this.support, required this.cache});

  final Directory support;
  final Directory cache;
  final List<(String, TargetPlatform)> opened = <(String, TargetPlatform)>[];
  final List<String> externalUrls = <String>[];

  @override
  Future<Directory> getApplicationSupportDirectory() async => support;

  @override
  Future<Directory> getApplicationCacheDirectory() async => cache;

  @override
  Future<bool> openDownloadedFile(String path, TargetPlatform target) async {
    opened.add((path, target));
    return true;
  }

  @override
  Future<bool> installDownloadedFile(String path, TargetPlatform target) async {
    opened.add((path, target));
    return true;
  }

  @override
  Future<bool> openExternalUrl(String url) async {
    externalUrls.add(url);
    return true;
  }
}

void main() {
  group('platformAsset', () {
    test(
      'selects URL, sha256, and canonical filename for all five platforms',
      () {
        final UpdateInfo info = testUpdateInfo();

        expect(
          platformAsset(info, TargetPlatform.android),
          const UpdatePlatformAsset(
            fileName: 'BookSift-android-v1.2.3.apk',
            url: 'https://example.com/android.apk',
            sha256: 'apk-hash',
          ),
        );
        expect(
          platformAsset(info, TargetPlatform.iOS),
          const UpdatePlatformAsset(
            fileName: 'BookSift-ios-v1.2.3.ipa',
            url: 'https://example.com/ios.ipa',
            sha256: 'ios-hash',
          ),
        );
        expect(
          platformAsset(info, TargetPlatform.windows),
          const UpdatePlatformAsset(
            fileName: 'BookSift-windows-x64-v1.2.3.zip',
            url: 'https://example.com/windows.zip',
            sha256: 'windows-hash',
          ),
        );
        expect(
          platformAsset(info, TargetPlatform.macOS),
          const UpdatePlatformAsset(
            fileName: 'BookSift-macos-universal-v1.2.3.zip',
            url: 'https://example.com/macos.zip',
            sha256: 'macos-hash',
          ),
        );
        expect(
          platformAsset(info, TargetPlatform.linux),
          const UpdatePlatformAsset(
            fileName: 'BookSift-linux-x64-v1.2.3.tar.gz',
            url: 'https://example.com/linux.tar.gz',
            sha256: 'linux-hash',
          ),
        );
      },
    );

    test('does not fall back when the selected platform link is missing', () {
      final UpdatePlatformAsset? asset = platformAsset(
        testUpdateInfo(windowsUrl: null),
        TargetPlatform.windows,
      );

      expect(asset, isNull);
      expect(platformAsset(testUpdateInfo(), TargetPlatform.fuchsia), isNull);
    });
  });

  test(
    'platform port fake keeps directory and open operations injectable',
    () async {
      final FakeUpdatePlatform platform = FakeUpdatePlatform(
        support: Directory('/fake/support'),
        cache: Directory('/fake/cache'),
      );

      expect(
        (await platform.getApplicationSupportDirectory()).path,
        '/fake/support',
      );
      expect(
        (await platform.getApplicationCacheDirectory()).path,
        '/fake/cache',
      );
      expect(
        await platform.openDownloadedFile(
          '/fake/update.zip',
          TargetPlatform.windows,
        ),
        isTrue,
      );
      expect(await platform.openExternalUrl('https://example.com'), isTrue);
      expect(platform.opened, <(String, TargetPlatform)>[
        ('/fake/update.zip', TargetPlatform.windows),
      ]);
      expect(platform.externalUrls, <String>['https://example.com']);
    },
  );

  test(
    'default port uses injected URL operations without platform channels',
    () async {
      Uri? openedUri;
      final DefaultUpdatePlatform platform = DefaultUpdatePlatform(
        UpdatePlatformOperations(
          openUrl: (Uri uri) async {
            openedUri = uri;
            return true;
          },
          openFileLocation: (_) async => true,
        ),
      );

      expect(
        await platform.openDownloadedFile(
          '/fake/update.zip',
          TargetPlatform.windows,
        ),
        isTrue,
      );
      expect(openedUri, Uri.file('/fake/update.zip'));
      final Directory temporary = await Directory.systemTemp.createTemp(
        'booksift-ipa-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final String ipa = '${temporary.path}/update.ipa';
      await File(ipa).writeAsBytes(<int>[1]);
      expect(
        await platform.openDownloadedFile(ipa, TargetPlatform.iOS),
        isTrue,
      );
    },
  );

  test('desktop installer uses the native package installer port', () async {
    String? installedPath;
    final DefaultUpdatePlatform platform = DefaultUpdatePlatform(
      UpdatePlatformOperations(
        installPackage: (String path) async {
          installedPath = path;
          return true;
        },
      ),
    );

    expect(
      await platform.installDownloadedFile(
        '/fake/BookSift-windows-x64-v1.2.3.zip',
        TargetPlatform.windows,
      ),
      isTrue,
    );
    expect(installedPath, '/fake/BookSift-windows-x64-v1.2.3.zip');
  });
}
