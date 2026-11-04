import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repo/database_provider.dart';
import 'content_draft.dart';
import 'content_store.dart';
import 'document_fetcher.dart';
import 'document_reader.dart';

abstract interface class ContentEditorRepository {
  Future<ContentDraft?> load(int postId);
  Future<ContentSaveResult> save(ContentDraft draft);
  Future<String?> exportOriginal(int postId);
}

class DatabaseContentEditorRepository implements ContentEditorRepository {
  DatabaseContentEditorRepository(this.store);
  final ContentStore store;

  @override
  Future<ContentDraft?> load(int postId) => store.load(postId);
  @override
  Future<ContentSaveResult> save(ContentDraft draft) => store.save(draft);
  @override
  Future<String?> exportOriginal(int postId) async {
    final document = await store.original(postId);
    if (document == null) throw const ContentEditException('这个帖子尚未建立原始留档。');
    final Uri? uri = await FilePicker.saveFile(
      fileName: document.fileName,
      bytes: document.originalBytes,
      mimeType: document.mediaType,
      dialogTitle: '保存原始文档',
    );
    return uri?.toString();
  }
}

final contentEditorRepositoryProvider = Provider<ContentEditorRepository>(
  (Ref ref) => DatabaseContentEditorRepository(
    ContentStore(ref.watch(appDatabaseProvider)),
  ),
);

abstract interface class DocumentSource {
  Future<ContentDraft?> pickDocument();
  Future<ContentDraft> readUrl(String url);
  Future<ContentImageDraft?> pickImage();
  Future<ContentDraft> preserveImages(ContentDraft draft);
}

final documentSourceProvider = Provider<DocumentSource>((Ref ref) {
  final PlatformDocumentSource source = PlatformDocumentSource();
  ref.onDispose(source.close);
  return source;
});

class PlatformDocumentSource implements DocumentSource {
  PlatformDocumentSource({DocumentFetcher? fetcher})
    : fetcher = fetcher ?? DocumentFetcher();
  final DocumentFetcher fetcher;

  @override
  Future<ContentDraft?> pickDocument() async {
    final PlatformFile? file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const <String>[
        'txt',
        'md',
        'markdown',
        'html',
        'htm',
        'docx',
      ],
      dialogTitle: '选择扫书文档',
    );
    if (file == null) return null;
    if ((await file.length() ?? 0) > maxImportBytes) {
      throw const ContentEditException('文档超过 24 MB，请分篇导入。');
    }
    return const DocumentReader().read(
      bytes: await file.readAsBytes(),
      fileName: file.name,
    );
  }

  @override
  Future<ContentDraft> readUrl(String url) => fetcher.readUrl(url);

  @override
  Future<ContentDraft> preserveImages(ContentDraft draft) =>
      fetcher.preserveImages(draft);

  @override
  Future<ContentImageDraft?> pickImage() async {
    final PlatformFile? file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const <String>[
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
        'bmp',
      ],
      dialogTitle: '选择正文图片',
    );
    if (file == null) return null;
    if ((await file.length() ?? 0) > 8 * 1024 * 1024) {
      throw const ContentEditException('图片超过 8 MB。');
    }
    final bytes = await file.readAsBytes();
    final String extension = file.name.split('.').last.toLowerCase();
    return ContentImageDraft(
      url:
          'data:image/${extension == 'jpg' ? 'jpeg' : extension};base64,${base64Encode(bytes)}',
    );
  }

  void close() => fetcher.close();
}
