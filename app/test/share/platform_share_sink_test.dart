import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:booksift/features/share/share_service.dart';

void main() {
  late Directory root;
  late Directory documents;
  late Directory temporary;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('booksift_share_sink');
    documents = Directory('${root.path}${Platform.pathSeparator}documents');
    temporary = Directory('${root.path}${Platform.pathSeparator}temporary');
    await documents.create();
    await temporary.create();
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  for (final String operatingSystem in <String>['android', 'ios']) {
    test('$operatingSystem 保存写入应用文档目录，不调用桌面文件选择器', () async {
      int saveFileCalls = 0;
      final PlatformShareOperations operations = PlatformShareOperations(
        operatingSystem: operatingSystem,
        documentsDirectory: () async => documents,
        saveFileOperation:
            ({
              required String dialogTitle,
              required String fileName,
              required Uint8List bytes,
              required String mimeType,
              required List<String> allowedExtensions,
            }) async {
              saveFileCalls++;
              return Uri.file('${root.path}${Platform.pathSeparator}$fileName');
            },
      );
      final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3]);

      final ShareOutcome outcome = await PlatformShareSink(
        operations,
      ).save(bytes, 'card.png');

      expect(outcome.kind, ShareOutcomeKind.saved);
      expect(
        outcome.path,
        '${documents.path}${Platform.pathSeparator}card.png',
      );
      expect(await File(outcome.path!).readAsBytes(), bytes);
      expect(saveFileCalls, 0);
      expect(outcome.message, contains('分享'));
    });

    test('$operatingSystem 分享先写临时文件，再交给系统分享面板', () async {
      final Uint8List bytes = Uint8List.fromList(<int>[4, 5, 6]);
      bool called = false;
      final PlatformShareOperations operations = PlatformShareOperations(
        operatingSystem: operatingSystem,
        temporaryDirectory: () async => temporary,
        shareOperation: (ShareParams params) async {
          called = true;
          expect(params.text, '书单说明');
          expect(params.files, hasLength(1));
          expect(await File(params.files!.single.path).readAsBytes(), bytes);
          return const ShareResult('shared', ShareResultStatus.success);
        },
      );

      final ShareOutcome outcome = await PlatformShareSink(
        operations,
      ).share(bytes, 'card.png', text: '书单说明');

      expect(outcome.kind, ShareOutcomeKind.shared);
      expect(called, isTrue);
      expect(
        outcome.path,
        '${temporary.path}${Platform.pathSeparator}card.png',
      );
    });
  }

  test('桌面保存委托文件选择器，保留用户选择的目标 URI', () async {
    Uri? selected;
    String? selectedName;
    final Uint8List bytes = Uint8List.fromList(<int>[7, 8, 9]);
    final PlatformShareOperations operations = PlatformShareOperations(
      operatingSystem: 'windows',
      saveFileOperation:
          ({
            required String dialogTitle,
            required String fileName,
            required Uint8List bytes,
            required String mimeType,
            required List<String> allowedExtensions,
          }) async {
            selectedName = fileName;
            expect(dialogTitle, '保存分享卡片');
            expect(mimeType, 'image/png');
            expect(allowedExtensions, <String>['png']);
            expect(bytes, <int>[7, 8, 9]);
            selected = Uri.file(
              '${root.path}${Platform.pathSeparator}chosen.png',
            );
            return selected;
          },
    );

    final ShareOutcome outcome = await PlatformShareSink(
      operations,
    ).save(bytes, 'card.png');

    expect(outcome.kind, ShareOutcomeKind.saved);
    expect(outcome.path, selected!.toFilePath());
    expect(selectedName, 'card.png');
    expect(await documents.list().toList(), isEmpty);
  });

  test('桌面保存对话框失败时，PNG 兜底写入应用文档目录', () async {
    final PlatformShareOperations operations = PlatformShareOperations(
      operatingSystem: 'linux',
      documentsDirectory: () async => documents,
      saveFileOperation:
          ({
            required String dialogTitle,
            required String fileName,
            required Uint8List bytes,
            required String mimeType,
            required List<String> allowedExtensions,
          }) async => throw StateError('dialog unavailable'),
    );
    final Uint8List bytes = Uint8List.fromList(<int>[10, 11]);

    final ShareOutcome outcome = await PlatformShareSink(
      operations,
    ).save(bytes, 'fallback.png');

    expect(outcome.kind, ShareOutcomeKind.saved);
    expect(outcome.message, contains('对话框不可用'));
    expect(await File(outcome.path!).readAsBytes(), bytes);
  });
}
