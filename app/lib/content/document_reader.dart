import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

import 'content_draft.dart';
import 'review_recognizer.dart';

const int maxImportBytes = 24 * 1024 * 1024;
const int maxExpandedDocumentBytes = 64 * 1024 * 1024;

class DocumentReader {
  const DocumentReader();

  ContentDraft read({
    required Uint8List bytes,
    required String fileName,
    String sourceUrl = '',
    DateTime? now,
  }) {
    if (bytes.isEmpty || bytes.length > maxImportBytes) {
      throw const ContentEditException('文档为空或超过 24 MB，请分篇导入。');
    }
    final String extension = path.extension(fileName).toLowerCase();
    if (extension == '.docx') return _docx(bytes, fileName, sourceUrl, now);
    final String text = _decode(bytes);
    if (extension == '.html' ||
        extension == '.htm' ||
        RegExp(
          r'^\s*(?:<!doctype\s+html|<html|<article|<div|<section)',
          caseSensitive: false,
        ).hasMatch(text)) {
      return _html(bytes, fileName, text, sourceUrl, now);
    }
    if (!const <String>{'.txt', '.md', '.markdown', ''}.contains(extension)) {
      throw const ContentEditException(
        '支持 TXT、Markdown、HTML 和 DOCX；其他格式请先导出为这些格式。',
      );
    }
    final bool markdown = extension == '.md' || extension == '.markdown';
    final List<ContentFloorDraft> floors = _textFloors(
      text,
      sourceUrl,
      markdown: markdown,
    );
    final String title = text
        .split(RegExp(r'\r?\n'))
        .map((String line) => line.trim())
        .firstWhere(
          (String line) => line.isNotEmpty,
          orElse: () => path.basenameWithoutExtension(fileName),
        )
        .replaceFirst(RegExp(r'^#{1,6}\s*'), '');
    return _recognize(
      ContentDraft(
        title: title.runes.take(120).map(String.fromCharCode).join(),
        sourceUrl: sourceUrl,
        date: contentDate(now ?? DateTime.now()),
        channel: sourceUrl.contains('mp.weixin.qq.com') ? '微信公众号' : '手动导入',
        floors: floors,
        rawDocument: bytes,
        fileName: fileName,
        mediaType: markdown ? 'text/markdown' : 'text/plain',
        warnings: _remoteWarning(floors),
      ),
    );
  }

  ContentDraft _html(
    Uint8List bytes,
    String fileName,
    String raw,
    String sourceUrl,
    DateTime? now,
  ) {
    final Document document = html.parse(raw);
    final Element? wechat = document.querySelector('#js_content');
    final Element? root =
        wechat ??
        document.querySelector('article') ??
        document.querySelector('main') ??
        document.body;
    if (root == null) {
      throw const ContentEditException('没有可导入的正文，请保存完整网页或粘贴原文。');
    }
    if (wechat == null &&
        (document.querySelector('iframe[src*="captcha"]') != null ||
            RegExp(
              r'环境异常|完成验证后即可继续访问|访问过于频繁|该内容已被发布者删除|此内容因违规无法查看',
            ).hasMatch(root.text))) {
      throw const ContentEditException(
        '来源返回验证页或失效页，未导入。请在实际浏览器完成验证后保存 HTML，或粘贴正文。',
      );
    }
    final String inferredUrl =
        document.querySelector('link[rel="canonical"]')?.attributes['href'] ??
        '';
    final String effectiveUrl =
        sourceUrl.isEmpty && validContentUrl(inferredUrl)
        ? inferredUrl
        : sourceUrl;
    final _HtmlContent content = _HtmlContent(effectiveUrl);
    content.walk(root);
    content.flush();
    if (content.floors.isEmpty) {
      throw const ContentEditException('网页正文为空，未导入。请保存完整网页或粘贴原文。');
    }
    final String title =
        (document.querySelector('#activity-name')?.text ??
                document
                    .querySelector('meta[property="og:title"]')
                    ?.attributes['content'] ??
                document.querySelector('h1')?.text ??
                document.querySelector('title')?.text ??
                path.basenameWithoutExtension(fileName))
            .trim();
    final String author =
        (document.querySelector('#js_name')?.text ??
                document
                    .querySelector('meta[name="author"]')
                    ?.attributes['content'] ??
                '')
            .trim();
    String dateText =
        document.querySelector('#publish_time')?.text ??
        document
            .querySelector('meta[property="article:published_time"]')
            ?.attributes['content'] ??
        document.querySelector('time')?.attributes['datetime'] ??
        '';
    if (dateText.isEmpty) {
      dateText =
          RegExp(
            r'''\bcreate_time\s*[:=]\s*["'](\d{4}-\d{2}-\d{2})''',
          ).firstMatch(raw)?[1] ??
          '';
    }
    final RegExpMatch? dateMatch = RegExp(
      r'(\d{4})[-年/](\d{1,2})[-月/](\d{1,2})',
    ).firstMatch(dateText);
    String date = dateMatch == null
        ? ''
        : '${dateMatch[1]}-${dateMatch[2]!.padLeft(2, '0')}-${dateMatch[3]!.padLeft(2, '0')}';
    if (date.isEmpty) {
      final RegExpMatch? epoch = RegExp(
        r'''\b(?:ct|ori_create_time)\s*[:=]\s*["']?(\d{10})''',
      ).firstMatch(raw);
      if (epoch != null) {
        date = contentDate(
          DateTime.fromMillisecondsSinceEpoch(
            int.parse(epoch[1]!) * 1000,
            isUtc: true,
          ),
        );
      }
    }
    if (!validContentDate(date) || date.isEmpty) {
      date = contentDate(now ?? DateTime.now());
    }
    return _recognize(
      ContentDraft(
        title: title,
        author: author,
        channel: wechat != null || effectiveUrl.contains('mp.weixin.qq.com')
            ? '微信公众号'
            : Uri.tryParse(effectiveUrl)?.host.isNotEmpty == true
            ? Uri.parse(effectiveUrl).host
            : '网页导入',
        sourceUrl: effectiveUrl,
        date: date,
        floors: content.floors,
        rawDocument: bytes,
        fileName: fileName,
        mediaType: 'text/html',
        warnings: <String>[
          ...content.warnings,
          ..._remoteWarning(content.floors),
        ],
      ),
    );
  }

  ContentDraft _docx(
    Uint8List bytes,
    String fileName,
    String sourceUrl,
    DateTime? now,
  ) {
    try {
      final ZipDirectory directory = ZipDirectory()
        ..read(InputMemoryStream(bytes));
      final int declaredSize = directory.fileHeaders.fold<int>(
        0,
        (int size, ZipFileHeader header) => size + header.uncompressedSize,
      );
      if (declaredSize > maxExpandedDocumentBytes) {
        throw const ContentEditException('文档解压后超过 64 MB，请分篇导入。');
      }
      final Archive archive = ZipDecoder().decodeBytes(bytes, verify: true);
      final Map<String, ArchiveFile> files = <String, ArchiveFile>{
        for (final ArchiveFile file in archive) file.name: file,
      };
      final ArchiveFile? main = files['word/document.xml'];
      if (main == null) throw const ContentEditException('DOCX 缺少正文，未导入。');
      final Map<String, String> relationships = <String, String>{};
      final ArchiveFile? rels = files['word/_rels/document.xml.rels'];
      if (rels != null) {
        for (final XmlElement relation in XmlDocument.parse(
          utf8.decode(rels.content),
        ).descendants.whereType<XmlElement>()) {
          if (relation.name.local == 'Relationship') {
            relationships[relation.getAttribute('Id') ?? ''] =
                relation.getAttribute('Target') ?? '';
          }
        }
      }
      final List<ContentFloorDraft> floors = <ContentFloorDraft>[];
      final List<String> warnings = <String>[];
      final XmlDocument xml = XmlDocument.parse(utf8.decode(main.content));
      for (final XmlElement paragraph
          in xml.descendants.whereType<XmlElement>().where(
            (XmlElement element) => element.name.local == 'p',
          )) {
        final StringBuffer text = StringBuffer();
        final List<ContentImageDraft> images = <ContentImageDraft>[];
        for (final XmlElement element
            in paragraph.descendants.whereType<XmlElement>()) {
          switch (element.name.local) {
            case 't':
              text.write(element.innerText);
            case 'br':
              text.write('\n');
            case 'tab':
              text.write('\t');
            case 'blip':
              final String relationId =
                  element.attributes
                      .where(
                        (XmlAttribute attribute) =>
                            attribute.name.local == 'embed' ||
                            attribute.name.local == 'link',
                      )
                      .map((XmlAttribute attribute) => attribute.value)
                      .firstOrNull ??
                  '';
              final String target = relationships[relationId] ?? '';
              final String archivePath = path.posix.normalize(
                path.posix.join('word', target),
              );
              final ArchiveFile? image = files[archivePath];
              if (image != null) {
                final String extension = path
                    .extension(target)
                    .toLowerCase()
                    .replaceFirst('.', '');
                final String mime = extension == 'jpg' ? 'jpeg' : extension;
                if (const <String>{
                  'jpeg',
                  'png',
                  'gif',
                  'webp',
                  'bmp',
                  'svg',
                }.contains(mime)) {
                  images.add(
                    ContentImageDraft(
                      url:
                          'data:image/${mime == 'svg' ? 'svg+xml' : mime};base64,${base64Encode(image.content)}',
                    ),
                  );
                } else {
                  warnings.add('文档图片 $target 的格式无法直接展示，原始 DOCX 已留档。');
                }
              } else if (validContentUrl(target) && target.isNotEmpty) {
                images.add(ContentImageDraft(url: target));
              } else {
                warnings.add('文档图片 $target 缺失，原始 DOCX 已留档。');
              }
            case 'hyperlink':
              final String relationId =
                  element.attributes
                      .where(
                        (XmlAttribute attribute) =>
                            attribute.name.local == 'id',
                      )
                      .map((XmlAttribute attribute) => attribute.value)
                      .firstOrNull ??
                  '';
              final String target = relationships[relationId] ?? '';
              if (validContentUrl(target) && target.isNotEmpty) {
                text.write(' [$target] ');
              }
          }
        }
        if (text.isNotEmpty || images.isNotEmpty) {
          floors.add(ContentFloorDraft(text: text.toString(), images: images));
        }
      }
      if (floors.isEmpty) throw const ContentEditException('DOCX 正文为空，未导入。');
      return _recognize(
        ContentDraft(
          title: path.basenameWithoutExtension(fileName),
          date: contentDate(now ?? DateTime.now()),
          sourceUrl: sourceUrl,
          floors: floors,
          rawDocument: bytes,
          fileName: fileName,
          mediaType:
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          warnings: <String>[...warnings, ..._remoteWarning(floors)],
        ),
      );
    } on ContentEditException {
      rethrow;
    } catch (_) {
      throw const ContentEditException('DOCX 文件损坏或格式不受支持，未导入。');
    }
  }

  List<ContentFloorDraft> _textFloors(
    String text,
    String sourceUrl, {
    required bool markdown,
  }) {
    final List<ContentFloorDraft> floors = <ContentFloorDraft>[];
    for (final String paragraph
        in text.replaceAll('\r\n', '\n').split(RegExp(r'\n[\t ]*\n'))) {
      if (paragraph.isEmpty) continue;
      final List<ContentImageDraft> images = <ContentImageDraft>[];
      final String body = markdown
          ? paragraph.replaceAllMapped(
              RegExp(r'!\[([^\]]*)\]\(([^\s)]+)(?:\s+"[^"]*")?\)'),
              (Match match) {
                final String url = resolveContentUrl(match[2]!, sourceUrl);
                if (url.isNotEmpty) images.add(ContentImageDraft(url: url));
                return match[1]!.isEmpty ? '' : '[图片说明：${match[1]}]';
              },
            )
          : paragraph;
      floors.add(ContentFloorDraft(text: body, images: images));
    }
    if (floors.isEmpty) throw const ContentEditException('正文为空，未导入。');
    return floors;
  }

  ContentDraft _recognize(ContentDraft draft) =>
      draft.copyWith(entries: const ReviewRecognizer().recognize(draft));

  List<String> _remoteWarning(List<ContentFloorDraft> floors) =>
      floors.any(
        (ContentFloorDraft floor) =>
            floor.images.any((ContentImageDraft image) => !image.embedded),
      )
      ? <String>['网络图片已保留地址；保存时会尝试嵌入。未能下载的图片会明确提示，仍可回到来源查看。']
      : const <String>[];

  String _decode(Uint8List bytes) {
    try {
      if (bytes.length >= 2 &&
          ((bytes[0] == 0xff && bytes[1] == 0xfe) ||
              (bytes[0] == 0xfe && bytes[1] == 0xff))) {
        if (bytes.length.isOdd) throw const FormatException('invalid UTF-16');
        final ByteData data = ByteData.sublistView(bytes);
        final Endian endian = bytes[0] == 0xff ? Endian.little : Endian.big;
        final List<int> units = <int>[
          for (int offset = 2; offset < bytes.length; offset += 2)
            data.getUint16(offset, endian),
        ];
        for (int index = 0; index < units.length; index++) {
          if (units[index] >= 0xd800 && units[index] <= 0xdbff) {
            if (index + 1 >= units.length ||
                units[index + 1] < 0xdc00 ||
                units[index + 1] > 0xdfff) {
              throw const FormatException('invalid UTF-16 surrogate');
            }
            index++;
          } else if (units[index] >= 0xdc00 && units[index] <= 0xdfff) {
            throw const FormatException('invalid UTF-16 surrogate');
          }
        }
        return String.fromCharCodes(units);
      }
      return utf8.decode(bytes).replaceFirst(RegExp(r'^\ufeff'), '');
    } on FormatException {
      throw const ContentEditException('文档编码无法无损读取，请另存为 UTF-8 或 UTF-16 后导入。');
    }
  }
}

String resolveContentUrl(String raw, String sourceUrl) {
  final String value = raw.trim();
  if (value.startsWith('data:image/') && validContentUrl(value, image: true)) {
    return value;
  }
  final Uri? parsed = Uri.tryParse(value);
  if (parsed == null || value.isEmpty) return '';
  final String resolved = parsed.hasScheme
      ? value
      : value.startsWith('//')
      ? 'https:$value'
      : sourceUrl.isNotEmpty
      ? Uri.parse(sourceUrl).resolveUri(parsed).toString()
      : '';
  return validContentUrl(resolved) ? resolved : '';
}

class _HtmlContent {
  _HtmlContent(this.sourceUrl);

  final String sourceUrl;
  final List<ContentFloorDraft> floors = <ContentFloorDraft>[];
  final List<String> warnings = <String>[];
  final StringBuffer text = StringBuffer();
  final List<ContentImageDraft> images = <ContentImageDraft>[];
  final List<String> links = <String>[];

  void flush() {
    final String body = text.toString().trim();
    if (body.isNotEmpty || images.isNotEmpty || links.isNotEmpty) {
      floors.add(
        ContentFloorDraft(
          text: <String>[if (body.isNotEmpty) body, ...links].join('\n'),
          images: List<ContentImageDraft>.of(images),
        ),
      );
    }
    text.clear();
    images.clear();
    links.clear();
  }

  void walk(Node node) {
    if (node is Text) {
      text.write(node.data);
      return;
    }
    if (node is! Element) return;
    final String tag = node.localName ?? '';
    if (const <String>{'script', 'style', 'noscript'}.contains(tag)) return;
    final bool block = const <String>{
      'p',
      'div',
      'section',
      'article',
      'main',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'li',
      'blockquote',
      'tr',
      'table',
      'pre',
      'figure',
    }.contains(tag);
    if (block) flush();
    if (tag == 'br') text.write('\n');
    if (tag == 'mp-common-profile' && node.querySelector('img') == null) {
      flush();
      final String profileName = node.attributes['data-nickname'] ?? '';
      final String signature = node.attributes['data-signature'] ?? '';
      text.write(
        '[公众号：$profileName${signature.isEmpty ? '' : ' · $signature'}]',
      );
      final String picture = resolveContentUrl(
        node.attributes['data-headimg'] ?? '',
        sourceUrl,
      );
      if (picture.isNotEmpty) images.add(ContentImageDraft(url: picture));
      flush();
    }
    if (tag == 'img') {
      flush();
      final String raw =
          node.attributes['data-src'] ??
          node.attributes['data-original'] ??
          node.attributes['data-lazy-src'] ??
          node.attributes['src'] ??
          '';
      final String url = resolveContentUrl(raw, sourceUrl);
      if (url.isNotEmpty) {
        images.add(
          ContentImageDraft(
            url: url,
            width:
                int.tryParse(
                  node.attributes['data-w'] ?? node.attributes['width'] ?? '',
                ) ??
                0,
            height:
                int.tryParse(
                  node.attributes['data-h'] ?? node.attributes['height'] ?? '',
                ) ??
                0,
          ),
        );
      } else {
        warnings.add('有图片地址无法读取；原始 HTML 已完整留档，请检查本地网页配套资源。');
      }
      final String alt =
          node.attributes['alt'] ?? node.attributes['title'] ?? '';
      if (alt.isNotEmpty) text.write('[图片说明：$alt]');
      flush();
    }
    if (const <String>{
      'video',
      'audio',
      'iframe',
      'mpvoice',
      'mpvideo',
      'qqmusic',
      'svg',
      'canvas',
    }.contains(tag)) {
      final String media =
          node.attributes['src'] ?? node.attributes['data-src'] ?? '';
      warnings.add('正文含 $tag，当前以文字提示和原始文档留档保留，请到来源查看媒体。');
      text.write('[媒体：$tag${media.isEmpty ? '' : ' $media'}]');
    }
    for (final Node child in node.nodes) {
      walk(child);
    }
    if (tag == 'td' || tag == 'th') text.write('\t');
    if (tag == 'a') {
      final String raw = node.attributes['href'] ?? '';
      final String url = resolveContentUrl(raw, sourceUrl);
      if (url.isNotEmpty && node.text != url) {
        links.add(url);
      }
    }
    if (block) flush();
  }
}
