import 'package:booksift/content/content_draft.dart';
import 'package:booksift/content/document_source.dart';

class MemoryContentEditorRepository implements ContentEditorRepository {
  MemoryContentEditorRepository({this.draft});

  ContentDraft? draft;
  ContentDraft? saved;
  bool failSave = false;

  @override
  Future<ContentDraft?> load(int postId) async => draft;

  @override
  Future<ContentSaveResult> save(ContentDraft next) async {
    if (failSave) throw const ContentEditException('保存失败，草稿仍在');
    saved = next;
    return ContentSaveResult(
      postId: next.postId ?? 77,
      entryCount: next.entries.length,
    );
  }

  @override
  Future<String?> exportOriginal(int postId) async => 'original.txt';
}

class MemoryDocumentSource implements DocumentSource {
  MemoryDocumentSource({this.document});

  final ContentDraft? document;

  @override
  Future<ContentDraft?> pickDocument() async => document;

  @override
  Future<ContentDraft> readUrl(String url) async =>
      document ?? (throw const ContentEditException('需要在浏览器完成验证'));

  @override
  Future<ContentImageDraft?> pickImage() async => null;

  @override
  Future<ContentDraft> preserveImages(ContentDraft draft) async => draft;
}
