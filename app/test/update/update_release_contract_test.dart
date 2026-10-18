import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _readRepoFile(String relativePath) {
  final String separator = Platform.pathSeparator;
  String root = Directory.current.path;
  for (int i = 0; i < 5; i++) {
    final String pubspec =
        '$root$separator'
        'app$separator'
        'pubspec.yaml';
    if (File(pubspec).existsSync()) {
      final File file = File('$root$separator$relativePath');
      if (!file.existsSync()) {
        throw StateError('缺少契约文件：$relativePath');
      }
      return file.readAsStringSync();
    }
    root = Directory(root).parent.path;
  }
  throw StateError('无法定位 BooksSift 仓库根目录：${Directory.current.path}');
}

void _expectAll(String source, Iterable<String> fragments, String scope) {
  for (final String fragment in fragments) {
    expect(source, contains(fragment), reason: '$scope 缺少契约片段：$fragment');
  }
}

void main() {
  test('更新服务声明五平台字段、静态 JSON 字段和固定资产名', () {
    final String service = _readRepoFile(
      'app/lib/core/update/update_service.dart',
    );

    _expectAll(service, <String>[
      'this.apkUrl',
      'this.iosUrl',
      'this.windowsUrl',
      'this.macosUrl',
      'this.linuxUrl',
      'this.apkSha256',
      'this.iosSha256',
      'this.windowsSha256',
      'this.macosSha256',
      'this.linuxSha256',
      'apk_url',
      'apk_sha256',
      'ios_url',
      'ios_sha256',
      'windows_url',
      'windows_sha256',
      'macos_url',
      'macos_sha256',
      'linux_url',
      'linux_sha256',
    ], 'update_service 五平台字段');
    _expectAll(service, <String>[
      r'android-v$version.apk',
      r'ios-v$version.ipa',
      r'windows-x64-v$version.zip',
      r'macos-universal-v$version.zip',
      r'linux-x64-v$version.tar.gz',
    ], 'update_service 固定资产名');
  });

  test('工作流与发布脚本使用同一套五平台包名', () {
    final String workflow = _readRepoFile(
      '.github/workflows/build-release.yml',
    );
    final String scripts = <String>[
      _readRepoFile('tools/make_release.ps1'),
      _readRepoFile('tools/make_release_linux.sh'),
    ].join('\n');

    _expectAll(workflow, <String>[
      r'android-v${VERSION}.apk',
      r'ios-v${VERSION}.ipa',
      r'$pkg = "windows-x64-v$env:VERSION"',
      r'macos-universal-v${VERSION}.zip',
      r'pkg="linux-x64-v${VERSION}"',
    ], 'build-release 工作流包名');
    _expectAll(workflow, <String>[
      '生成带真实摘要的 version.json',
      'apk_sha256',
      'ios_sha256',
      'windows_sha256',
      'macos_sha256',
      'linux_sha256',
    ], 'build-release version.json');
    _expectAll(scripts, <String>[
      r'android-v$Version.apk',
      r'ios-v$Version.ipa',
      r'windows-x64-v$Version.zip',
      r'macos-universal-v$Version.zip',
      r'PKG_NAME="linux-x64-v$VERSION"',
      r'$PKG_NAME.tar.gz',
    ], '发布脚本包名');
  });

  test('桌面更新助手随 Windows 与 Linux 发行包一起安装', () {
    final String windows = _readRepoFile('app/windows/CMakeLists.txt');
    final String linux = _readRepoFile('app/linux/CMakeLists.txt');
    final String windowsHelper = _readRepoFile(
      'app/windows/updater/booksift_updater.ps1',
    );
    final String linuxHelper = _readRepoFile(
      'app/linux/updater/booksift_updater.sh',
    );

    _expectAll(windows, <String>[
      'updater/booksift_updater.ps1',
      r'${INSTALL_BUNDLE_DATA_DIR}/update',
    ], 'Windows updater install');
    _expectAll(linux, <String>[
      'updater/booksift_updater.sh',
      r'${INSTALL_BUNDLE_DATA_DIR}/update',
    ], 'Linux updater install');
    _expectAll(windowsHelper, <String>[
      'Expand-Archive',
      'Move-Item',
      'Start-Process',
      'AppPid',
    ], 'Windows updater helper');
    _expectAll(linuxHelper, <String>[
      'tar -xzf',
      'BACKUP',
      r'mv "$SOURCE" "$BUNDLE"',
      'APP_PID',
    ], 'Linux updater helper');
  });

  test('更新文档覆盖双源、断点续传、校验、缓存和平台动作', () {
    final String docs = _readRepoFile('website/guide/update.md');
    _expectAll(docs, <String>[
      'GitHub Releases',
      'version.json',
      'HTTP `Range`',
      '分块并发',
      'manifest',
      '.part',
      '取消下载或断网后',
      '断点续传',
      'SHA-256 校验',
      '完整文件',
      'update-cache',
      '唤起系统安装器',
      '桌面程序包',
      '分享或导出',
      '手动安装',
      '不提供 iOS 静默安装承诺',
      '种子数据包',
    ], '在线更新文档');
  });
}
