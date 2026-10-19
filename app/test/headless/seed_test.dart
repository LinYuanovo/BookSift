// headless 种子包体检测试（seed.dart）。
//
// plain test()：真实 dart:io + 流式 sha256，TESTING.md §1 禁止进 testWidgets。
//
// 覆盖：随包真实 lite 包的元数据口径（不校 hash，避免每次 57MB）/
// 合成小包验证 sha 一致与不一致两侧 / manifest 缺失与字段缺失的报错路径。
//
// 注意：CLI 只做**校验**，导入仍由 App 首启执行（seed_import.dart 依赖 AssetBundle），
// 故此处不测导入。

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/headless/seed.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('booksift_seed_test');
  });

  tearDown(() async {
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  /// 造一个合成种子包目录（manifest + 小 zip 占位文件）。
  Future<String> makePack({
    required String zipName,
    required List<int> zipBytes,
    String? declaredSha,
    int? declaredSize,
    bool writeZip = true,
  }) async {
    final Directory dir = await Directory('${tmp.path}${Platform.pathSeparator}pack').create();
    final File zip = File('${dir.path}${Platform.pathSeparator}$zipName');
    if (writeZip) {
      await zip.writeAsBytes(zipBytes);
    }
    final String sha = declaredSha ?? sha256.convert(zipBytes).toString();
    await File('${dir.path}${Platform.pathSeparator}manifest.json').writeAsString(
      jsonEncode(<String, Object?>{
        'pack_name': 'fake_pack',
        'pack_version': 3,
        'tier': 'lite',
        'built_at': '2026-10-13T00:00:00+08:00',
        'db_size_bytes': 1024,
        'db_sha256': 'deadbeef',
        'rows': <String, int>{'posts': 1},
        'features': <String, Object?>{'fts_prebuilt': false},
        'data_window': <String, String>{'post_date_min': '2010-01-01'},
        'compression': <String, Object?>{
          'zip_file': zipName,
          'zip_sha256': sha,
          'zip_size_bytes': declaredSize ?? zipBytes.length,
        },
      }),
    );
    return dir.path;
  }

  group('真实随包 lite 包', () {
    test('--no-verify 口径：元数据齐全、大小一致、sha 记为未校验', () async {
      const String dir = 'assets/seed';
      if (!File('$dir${Platform.pathSeparator}manifest.json').existsSync()) {
        markTestSkipped('需在 app/ 目录下运行且资产已就位');
        return;
      }
      final SeedPackReport r = await SeedInspector.inspect(dir, verifyHash: false);

      expect(r.ok, isTrue);
      expect(r.manifest['pack_name'], 'seed_pack_lite');
      expect(r.manifest['tier'], 'lite');
      expect(r.zipPresent, isTrue);
      expect(r.sizeMatches, isTrue);
      expect(r.shaMatches, isNull, reason: '未校验时必须是 null，不能谎报 true');
      expect(r.actualSha256, isNull);
      expect(r.expectedSha256, isNotEmpty);

      final Map<String, Object?> j = r.toJson();
      expect(j['shaMatches'], isNull);
      expect(j['rows'], isA<Map>());
      expect(j['ok'], isTrue);
    });
  });

  group('合成包：校验两侧', () {
    test('sha 一致 → ok，耗时字段有值', () async {
      final List<int> bytes = List<int>.generate(4096, (int i) => i % 251);
      final String dir = await makePack(zipName: 'p.zip', zipBytes: bytes);

      final SeedPackReport r = await SeedInspector.inspect(dir);
      expect(r.shaMatches, isTrue);
      expect(r.sizeMatches, isTrue);
      expect(r.ok, isTrue);
      expect(r.actualSha256, r.expectedSha256);
      expect(r.zipBytes, bytes.length);
      expect(r.elapsed.inMilliseconds, greaterThanOrEqualTo(0));
    });

    test('内容被改（sha 不一致）→ ok=false，且期望/实测都可读', () async {
      final List<int> bytes = List<int>.generate(1024, (int i) => i % 256);
      final String dir = await makePack(
        zipName: 'p.zip',
        zipBytes: bytes,
        declaredSha: 'f' * 64,
      );

      final SeedPackReport r = await SeedInspector.inspect(dir);
      expect(r.shaMatches, isFalse);
      expect(r.ok, isFalse);
      expect(r.actualSha256, sha256.convert(bytes).toString());
      expect(r.expectedSha256, 'f' * 64);
      expect(r.toJson()['shaMatches'], isFalse);
    });

    test('大小不一致（截断）→ sizeMatches=false', () async {
      final List<int> bytes = List<int>.generate(2048, (int i) => 7);
      final String dir = await makePack(
        zipName: 'p.zip',
        zipBytes: bytes,
        declaredSize: bytes.length + 1,
      );
      final SeedPackReport r = await SeedInspector.inspect(dir, verifyHash: false);
      expect(r.sizeMatches, isFalse);
      expect(r.ok, isFalse);
    });

    test('zip 缺失 → zipPresent=false，ok=false（但不抛）', () async {
      final String dir = await makePack(
        zipName: 'missing.zip',
        zipBytes: const <int>[1, 2, 3],
        writeZip: false,
      );
      final SeedPackReport r = await SeedInspector.inspect(dir);
      expect(r.zipPresent, isFalse);
      expect(r.zipPath, isNull);
      expect(r.ok, isFalse);
      expect(r.shaMatches, isNull);
    });

    test('zip 哈希可缺失但 shaMatches 保持 null', () async {
      final Directory dir = await Directory(
        '${tmp.path}${Platform.pathSeparator}optional_sha',
      ).create();
      final List<int> bytes = const <int>[1, 2, 3];
      await File('${dir.path}${Platform.pathSeparator}p.zip').writeAsBytes(bytes);
      await File('${dir.path}${Platform.pathSeparator}manifest.json').writeAsString(
        jsonEncode(<String, Object?>{
          'compression': <String, Object?>{
            'zip_file': 'p.zip',
            'zip_size_bytes': bytes.length,
          },
        }),
      );

      final SeedPackReport report = await SeedInspector.inspect(dir.path);
      expect(report.ok, isTrue);
      expect(report.shaMatches, isNull);
      expect(report.toJson()['shaMatches'], isNull);
    });
  });

  group('报错路径', () {
    test('manifest.json 不存在 → SeedInspectException', () async {
      await expectLater(
        SeedInspector.inspect(tmp.path),
        throwsA(isA<SeedInspectException>().having(
          (SeedInspectException e) => e.message,
          'message',
          contains('manifest.json 不存在'),
        )),
      );
    });

    test('manifest 缺 compression.zip_file → SeedInspectException', () async {
      await File('${tmp.path}${Platform.pathSeparator}manifest.json')
          .writeAsString(jsonEncode(<String, Object?>{'pack_name': 'x'}));
      await expectLater(
        SeedInspector.inspect(tmp.path),
        throwsA(isA<SeedInspectException>()),
      );
    });

    test('manifest 拒绝 zip 路径越出指定目录', () async {
      final Directory outside = await Directory(
        '${tmp.path}${Platform.pathSeparator}outside',
      ).create();
      final String outsidePath = '${outside.path}${Platform.pathSeparator}p.zip';
      await File(outsidePath).writeAsBytes(const <int>[1]);
      await File('${tmp.path}${Platform.pathSeparator}manifest.json').writeAsString(
        jsonEncode(<String, Object?>{
          'compression': <String, Object?>{
            'zip_file': '../outside/p.zip',
            'zip_sha256': sha256.convert(const <int>[1]).toString(),
            'zip_size_bytes': 1,
          },
        }),
      );

      await expectLater(
        SeedInspector.inspect(tmp.path),
        throwsA(isA<SeedInspectException>()),
      );
    });

    test('manifest JSON 损坏时返回可读的体检异常', () async {
      await File('${tmp.path}${Platform.pathSeparator}manifest.json')
          .writeAsString('{broken');
      await expectLater(
        SeedInspector.inspect(tmp.path),
        throwsA(isA<SeedInspectException>().having(
          (SeedInspectException e) => e.message,
          'message',
          contains('格式无效'),
        )),
      );
    });

    test('onProgress 逐阶段回调（CLI 靠它把进度写进日志）', () async {
      final String dir = await makePack(zipName: 'p.zip', zipBytes: const <int>[9, 9, 9]);
      final List<String> stages = <String>[];
      await SeedInspector.inspect(dir, onProgress: stages.add);
      expect(stages, hasLength(3));
      expect(stages.first, contains('manifest'));
      expect(stages.last, '完成');
    });
  });
}
