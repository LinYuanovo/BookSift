import 'dart:convert';
import 'dart:io';

import 'package:booksift/content/content_draft.dart';
import 'package:booksift/content/document_reader.dart';
import 'package:booksift/content/document_fetcher.dart';
import 'package:html/parser.dart' as html;

Future<void> main(List<String> arguments) async {
  final Directory directory = Directory(
    arguments.isEmpty ? 'build/acceptance/wechat' : arguments.first,
  );
  final DocumentFetcher source = DocumentFetcher();
  final List<Map<String, Object?>> results = <Map<String, Object?>>[];
  try {
    for (int sample = 1; sample <= 4; sample++) {
      final File file = File('${directory.path}/sample-$sample-complete.html');
      final raw = await file.readAsBytes();
      final ContentDraft draft = const DocumentReader().read(
        bytes: raw,
        fileName: file.uri.pathSegments.last,
      );
      final DateTime start = DateTime.now();
      final ContentDraft embedded = await source.preserveImages(draft);
      final images = embedded.floors
          .expand((ContentFloorDraft floor) => floor.images)
          .toList();
      final failed = images
          .where((ContentImageDraft image) => !image.embedded)
          .toList();
      final document = html.parse(utf8.decode(raw));
      final Map<String, String> replacement = <String, String>{};
      final originalImages = draft.floors
          .expand((ContentFloorDraft floor) => floor.images)
          .toList();
      for (int index = 0; index < originalImages.length; index++) {
        replacement[originalImages[index].url] = images[index].url;
      }
      for (final element in document.querySelectorAll('#js_content img')) {
        final String original =
            element.attributes['data-src'] ?? element.attributes['src'] ?? '';
        final String? next = replacement[original];
        if (next != null) {
          element.attributes['data-src'] = next;
          element.attributes['src'] = next;
        }
      }
      for (final profile in document.querySelectorAll('mp-common-profile')) {
        final String original = profile.attributes['data-headimg'] ?? '';
        final String? next = replacement[original];
        if (next != null) profile.attributes['data-headimg'] = next;
      }
      await File(
        '${directory.path}/sample-$sample-offline.html',
      ).writeAsString(document.outerHtml);
      results.add(<String, Object?>{
        'sample': sample,
        'total': images.length,
        'embedded': images.length - failed.length,
        'failed': failed.map((ContentImageDraft image) => image.url).toList(),
        'seconds': DateTime.now().difference(start).inSeconds,
        'warnings': embedded.warnings.toSet().toList(),
      });
      stdout.writeln(jsonEncode(results.last));
      await File(
        '${directory.path}/images-report.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(results));
    }
  } finally {
    source.close();
  }
}
