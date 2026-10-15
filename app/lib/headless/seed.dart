/// 种子包体检：解析 `assets/seed/manifest.json` + 流式校验 zip 的 SHA256。
///
/// **只做校验，不做导入**。导入（解压 → ATTACH → 单事务拷贝 → FTS 重建）在
/// `lib/data/seed_import.dart`，它经 `AssetBundle` 读资产、依赖 `package:flutter`，
/// 无法在纯 Dart 的 `dart run` 下执行；把它改成可注入的文件源属于另一件事，
/// 这里不越界。CLI 侧的价值是回答排错最常问的那句：**「随包数据集完不完整」**。
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// 种子包体检结果。
class SeedPackReport {
  const SeedPackReport({
    required this.dir,
    required this.manifest,
    required this.zipPath,
    required this.zipBytes,
    required this.expectedZipBytes,
    required this.expectedSha256,
    required this.actualSha256,
    required this.elapsed,
  });

  final String dir;

  /// manifest.json 全量（原样透出，字段随打包脚本演进不必改这里）。
  final Map<String, Object?> manifest;

  final String? zipPath;
  final int? zipBytes;
  final int? expectedZipBytes;
  final String? expectedSha256;

  /// 实测 sha256；[SeedInspector.inspect] 传 `verifyHash: false` 时为 null。
  final String? actualSha256;

  final Duration elapsed;

  bool get zipPresent => zipPath != null;

  bool get sizeMatches =>
      zipBytes != null && expectedZipBytes != null && zipBytes == expectedZipBytes;

  /// null = 未校验。
  bool? get shaMatches =>
      actualSha256 == null || expectedSha256 == null
          ? null
          : actualSha256!.toLowerCase() == expectedSha256!.toLowerCase();

  bool get ok => zipPresent && sizeMatches && shaMatches != false;

  Map<String, Object?> toJson() => <String, Object?>{
        'ok': ok,
        'dir': dir,
        'packName': manifest['pack_name'],
        'packVersion': manifest['pack_version'],
        'tier': manifest['tier'],
        'builtAt': manifest['built_at'],
        'zipFile': manifest['compression'] is Map
            ? (manifest['compression'] as Map<String, Object?>)['zip_file']
            : null,
        'zipPath': zipPath,
        'zipBytes': zipBytes,
        'expectedZipBytes': expectedZipBytes,
        'sizeMatches': sizeMatches,
        'expectedSha256': expectedSha256,
        'actualSha256': actualSha256,
        'shaMatches': shaMatches,
        'verifySeconds': elapsed.inMilliseconds / 1000.0,
        'dbSizeBytes': manifest['db_size_bytes'],
        'dbSha256': manifest['db_sha256'],
        'rows': manifest['rows'],
        'features': manifest['features'],
        'dataWindow': manifest['data_window'],
      };
}

/// 种子包体检入口（无状态）。
abstract final class SeedInspector {
  /// 体检 [dir]（含 manifest.json 与 zip）。
  ///
  /// [verifyHash]=true 时对 zip 做流式 sha256（54MB 包桌面实测秒级）；
  /// [onProgress] 用于把阶段推进报到日志（读 manifest / 校验中 / 完成）。
  static Future<SeedPackReport> inspect(
    String dir, {
    bool verifyHash = true,
    void Function(String stage)? onProgress,
  }) async {
    final Stopwatch sw = Stopwatch()..start();
    final File manifestFile = File('$dir${Platform.pathSeparator}manifest.json');
    if (!await manifestFile.exists()) {
      throw SeedInspectException('manifest.json 不存在：$dir');
    }
    onProgress?.call('读 manifest.json');
    final Map<String, Object?> manifest =
        jsonDecode(await manifestFile.readAsString()) as Map<String, Object?>;

    final Map<String, Object?> compression =
        (manifest['compression'] as Map<String, Object?>?) ?? const <String, Object?>{};
    final String? zipName = compression['zip_file'] as String?;
    final String? expectedSha = compression['zip_sha256'] as String?;
    final int? expectedBytes = (compression['zip_size_bytes'] as num?)?.toInt();

    if (zipName == null) {
      throw SeedInspectException('manifest.compression.zip_file 缺失，无法定位 zip');
    }
    final File zip = File('$dir${Platform.pathSeparator}$zipName');
    if (!await zip.exists()) {
      return SeedPackReport(
        dir: dir,
        manifest: manifest,
        zipPath: null,
        zipBytes: null,
        expectedZipBytes: expectedBytes,
        expectedSha256: expectedSha,
        actualSha256: null,
        elapsed: sw.elapsed,
      );
    }

    final int size = await zip.length();
    String? actual;
    if (verifyHash) {
      onProgress?.call('流式校验 sha256（$size 字节）');
      actual = (await sha256.bind(zip.openRead()).first).toString();
    }
    sw.stop();
    onProgress?.call('完成');
    return SeedPackReport(
      dir: dir,
      manifest: manifest,
      zipPath: zip.path,
      zipBytes: size,
      expectedZipBytes: expectedBytes,
      expectedSha256: expectedSha,
      actualSha256: actual,
      elapsed: sw.elapsed,
    );
  }
}

/// 体检失败（manifest 缺失/字段缺失）。
class SeedInspectException implements Exception {
  const SeedInspectException(this.message);

  final String message;

  @override
  String toString() => 'SeedInspectException: $message';
}
