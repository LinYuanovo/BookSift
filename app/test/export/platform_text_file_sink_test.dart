import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:booksift/features/export/export_sheet.dart';
import 'package:booksift/features/share/share_service.dart';

void main() {
  late Directory root;
  late Directory documents;
  late Directory temporary;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('booksift_export_sink');
    documents = Directory('${root.path}${Platform.pathSeparator}documents');
    temporary = Directory('${root.path}${Platform.pathSeparator}temporary');
    await documents.create();
    await temporary.create();
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  for (final String operatingSystem in <String>['android', 'ios']) {
    test('$operatingSystem 保存书单到应用文档目录，不调用桌面文件选择器', () async {
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
              return null;
            },
      );
      const String content = '# 书单\n';

      final ShareOutcome outcome = await PlatformTextFileSink(
        operations,
      ).save(content, 'books.md', 'text/markdown');

      expect(outcome.kind, ShareOutcomeKind.saved);
      expect(
        outcome.path,
        '${documents.path}${Platform.pathSeparator}books.md',
      );
      expect(await File(outcome.path!).readAsString(), content);
      expect(saveFileCalls, 0);
      expect(outcome.message, contains('分享'));
    });

    test('$operatingSystem 分享书单时将 UTF-8 文件放入临时目录', () async {
      const String content = '书单内容';
      bool called = false;
      final PlatformShareOperations operations = PlatformShareOperations(
        operatingSystem: operatingSystem,
        temporaryDirectory: () async => temporary,
        shareOperation: (ShareParams params) async {
          called = true;
          expect(params.text, '我的书单');
          expect(params.files, hasLength(1));
          expect(await File(params.files!.single.path).readAsString(), content);
          return const ShareResult('shared', ShareResultStatus.success);
        },
      );

      final ShareOutcome outcome = await PlatformTextFileSink(
        operations,
      ).share(content, 'books.md', 'text/markdown', text: '我的书单');

      expect(outcome.kind, ShareOutcomeKind.shared);
      expect(called, isTrue);
      expect(
        outcome.path,
        '${temporary.path}${Platform.pathSeparator}books.md',
      );
    });
  }

  test('桌面保存书单委托文件选择器并传递扩展名、MIME 与内容', () async {
    Uri? selected;
    final PlatformShareOperations operations = PlatformShareOperations(
      operatingSystem: 'macos',
      saveFileOperation:
          ({
            required String dialogTitle,
            required String fileName,
            required Uint8List bytes,
            required String mimeType,
            required List<String> allowedExtensions,
          }) async {
            expect(dialogTitle, '保存书单');
            expect(fileName, 'books.txt');
            expect(mimeType, 'text/plain');
            expect(allowedExtensions, <String>['txt']);
            expect(String.fromCharCodes(bytes), 'book list');
            selected = Uri.file(
              '${root.path}${Platform.pathSeparator}chosen.txt',
            );
            return selected;
          },
    );

    final ShareOutcome outcome = await PlatformTextFileSink(
      operations,
    ).save('book list', 'books.txt', 'text/plain');

    expect(outcome.kind, ShareOutcomeKind.saved);
    expect(outcome.path, selected!.toFilePath());
  });

  test('桌面保存对话框失败时，书单 UTF-8 内容兜底写入应用文档目录', () async {
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
    const String content = '书单';

    final ShareOutcome outcome = await PlatformTextFileSink(
      operations,
    ).save(content, 'fallback.txt', 'text/plain');

    expect(outcome.kind, ShareOutcomeKind.saved);
    expect(outcome.message, contains('对话框不可用'));
    expect(await File(outcome.path!).readAsString(), content);
  });
}
