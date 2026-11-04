import 'dart:convert';
import 'dart:io';

import 'package:booksift/content/content_draft.dart';
import 'package:booksift/content/content_store.dart';
import 'package:booksift/content/document_reader.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

Future<void> main(List<String> arguments) async {
  final Directory directory = Directory(
    arguments.isEmpty ? 'build/acceptance/wechat' : arguments.first,
  );
  final String flavor =
      arguments.length > 1 &&
          <String>{'complete', 'offline'}.contains(arguments[1])
      ? '-${arguments[1]}'
      : '';
  final AppDatabase db = AppDatabase(
    NativeDatabase(
      File(
        '${directory.path}/import-${DateTime.now().millisecondsSinceEpoch}.sqlite',
      ),
    ),
  );
  final ContentStore store = ContentStore(db);
  final List<Map<String, Object?>> results = <Map<String, Object?>>[];
  final List<String> urls = await File('../docs-content/import-reviews-plan.md')
      .readAsLines()
      .then(
        (List<String> lines) => lines
            .where(
              (String line) => line.startsWith('- https://mp.weixin.qq.com/s/'),
            )
            .map((String line) => line.substring(2))
            .toList(),
      );
  try {
    for (final (int index, String url) in urls.indexed) {
      final bytes = await File(
        '${directory.path}/sample-${index + 1}$flavor.html',
      ).readAsBytes();
      final ContentDraft draft = const DocumentReader().read(
        bytes: bytes,
        fileName: 'sample-${index + 1}$flavor.html',
        sourceUrl: url,
      );
      final Element root = html
          .parse(utf8.decode(bytes))
          .querySelector('#js_content')!;
      final String htmlText = _bodyText(root);
      final ContentSaveResult saved = await store.save(draft);
      final PostDetailData recovered = (await Queries(
        db,
      ).postDetail(saved.postId))!;
      final String body = recovered.floors
          .map((FloorData floor) => floor.floor.content)
          .join('\n');
      String visible = '';
      final File browser = File(
        '${directory.path}/sample-${index + 1}-browser.txt',
      );
      int? visibleImages;
      if (await browser.exists()) {
        final String output = await browser.readAsString();
        final int start = output.indexOf('{');
        final int end = output.indexOf('\n###', start);
        final Map<String, dynamic> parsed =
            jsonDecode(
                  output
                      .substring(start, end == -1 ? output.length : end)
                      .trim(),
                )
                as Map<String, dynamic>;
        visible = parsed['text'] as String? ?? '';
        visibleImages = parsed['images'] as int?;
      }
      final List<String> missing = <String>[];
      for (final String paragraph
          in visible
              .split('\n')
              .map(_normalize)
              .where((String text) => text.isNotEmpty)) {
        if (!_normalize(body).contains(paragraph)) {
          missing.add(paragraph.runes.take(80).map(String.fromCharCode).join());
        }
      }
      final original = (await store.original(saved.postId))!;
      results.add(<String, Object?>{
        'sample': index + 1,
        'title': draft.title,
        'url': draft.sourceUrl,
        'bytes': bytes.length,
        'sha256': sha256.convert(bytes).toString(),
        'originalExact':
            original.originalHash == sha256.convert(bytes).toString(),
        'htmlTextChars': _normalize(htmlText).length,
        'storedTextChars': _normalize(body).length,
        'browserTextChars': _normalize(visible).length,
        'visibleParagraphsMissing': missing,
        'htmlImages': root.querySelectorAll('img').length,
        'browserImages': visibleImages,
        'storedImages': recovered.floors.fold<int>(
          0,
          (int count, FloorData floor) => count + floor.images.length,
        ),
        'floors': recovered.floors.length,
        'books': draft.entries
            .map(
              (ContentEntryDraft entry) => <String, Object?>{
                'name': entry.name,
                'author': entry.author,
                'commentChars': entry.comment.length,
              },
            )
            .toList(),
        'warnings': draft.warnings.toSet().toList(),
      });
    }
    final String report = const JsonEncoder.withIndent('  ').convert(results);
    await File('${directory.path}/report$flavor.json').writeAsString(report);
    stdout.writeln(report);
  } finally {
    await db.close();
  }
}

String _normalize(String text) => text.replaceAll(RegExp(r'\s+'), '');

String _bodyText(Node node) {
  if (node is Text) return node.data;
  if (node is Element &&
      const <String>{'script', 'style', 'noscript'}.contains(node.localName)) {
    return '';
  }
  return node.nodes.map(_bodyText).join();
}
