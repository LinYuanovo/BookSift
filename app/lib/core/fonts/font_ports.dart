import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:path_provider/path_provider.dart';

import '../../data/db/app_database.dart';

// 字体服务的四个可替换端口（依赖倒置：FontService 只依赖接口，
// 单测用手写 fake 注入，见 test/font_service_test.dart）。

/// KV 持久化端口（settings 表）。
abstract interface class FontSettingsStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// drift settings 表实现（复用 lib/data 的 AppDatabase，只 import 不修改）。
final class DriftFontSettingsStore implements FontSettingsStore {
  DriftFontSettingsStore(this._db);

  final AppDatabase _db;

  @override
  Future<String?> read(String key) async {
    final Setting? row =
        await (_db.select(_db.settings)..where((Settings t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> write(String key, String value) =>
      _db.into(_db.settings).insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
}

/// 被选中的字体文件（bytes 已入内存，平台无关）。
@immutable
class PickedFontFile {
  const PickedFontFile({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

/// 文件选择端口；返回 null = 用户取消。
abstract interface class FontFilePicker {
  Future<PickedFontFile?> pickFontFile();
}

/// file_picker 实现（仅 ttf/otf；v13 静态 API，readAsBytes 取字节）。
final class PlatformFontFilePicker implements FontFilePicker {
  const PlatformFontFilePicker();

  static const List<String> allowedExtensions = <String>['ttf', 'otf'];

  @override
  Future<PickedFontFile?> pickFontFile() async {
    final PlatformFile? file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (file == null) return null;
    return PickedFontFile(fileName: file.name, bytes: await file.readAsBytes());
  }
}

/// 运行时字体注册端口（把 bytes 挂到家族名下）。
abstract interface class FontRegistrar {
  Future<void> registerFamily(String familyName, Uint8List bytes);
}

/// flutter/services FontLoader 实现。
final class RuntimeFontRegistrar implements FontRegistrar {
  const RuntimeFontRegistrar();

  @override
  Future<void> registerFamily(String familyName, Uint8List bytes) async {
    final FontLoader loader = FontLoader(familyName)
      ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes)));
    await loader.load();
  }
}

/// 字体文件落盘端口（文件名 = ImportedFont.storedName）。
abstract interface class FontFileStore {
  Future<Uint8List> read(String fileName);
  Future<void> write(String fileName, Uint8List bytes);
  Future<void> delete(String fileName);
}

/// applicationSupportDirectory/fonts/ 实现。
final class AppSupportFontFileStore implements FontFileStore {
  const AppSupportFontFileStore();

  Future<Directory> _fontsDir() async {
    final Directory support = await getApplicationSupportDirectory();
    final Directory dir = Directory('${support.path}/fonts');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  Future<Uint8List> read(String fileName) async {
    final Directory dir = await _fontsDir();
    return File('${dir.path}/$fileName').readAsBytes();
  }

  @override
  Future<void> write(String fileName, Uint8List bytes) async {
    final Directory dir = await _fontsDir();
    await File('${dir.path}/$fileName').writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> delete(String fileName) async {
    final Directory dir = await _fontsDir();
    final File file = File('${dir.path}/$fileName');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
