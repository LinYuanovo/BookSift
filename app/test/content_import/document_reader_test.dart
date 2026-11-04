import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:booksift/content/content_draft.dart';
import 'package:booksift/content/document_reader.dart';
import 'package:flutter_test/flutter_test.dart';

const String sampleImage =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jXioAAAAASUVORK5CYII=';

void main() {
  const DocumentReader reader = DocumentReader();
  ContentDraft text(String value, {String name = '扫书.txt'}) => reader.read(
    bytes: Uint8List.fromList(utf8.encode(value)),
    fileName: name,
    now: DateTime.utc(2026, 11, 3, 18),
  );

  test('多书长评完整保存，区分书评人和小说作者，正文提及其他书不自动串书', () {
    final String longReview = List<String>.filled(
      120,
      '第一本书的完整评价，不应截断。',
    ).join();
    final String raw =
        '十一月扫书\n\n1.《星河旅人》 作者：林川\n$longReview\n顺便想起《以前读过的书》。\n\n2.《山海归途》 by 苏明\n第二本评价末尾校验词。';
    final ContentDraft draft = text(raw);
    expect(draft.date, '2026-11-04');
    expect(draft.entries.map((ContentEntryDraft entry) => entry.name), <String>[
      '星河旅人',
      '山海归途',
    ]);
    expect(
      draft.entries.map((ContentEntryDraft entry) => entry.author),
      <String>['林川', '苏明'],
    );
    expect(draft.entries.first.comment, contains(longReview));
    expect(draft.entries.first.comment, contains('以前读过的书'));
    expect(draft.entries.last.comment, contains('第二本评价末尾校验词'));
    expect(utf8.decode(draft.rawDocument!), raw);
    expect(
      draft.floors.map((ContentFloorDraft floor) => floor.text).join('\n\n'),
      raw,
    );
  });

  test('书名标签、无书名号的 by 格式、未知作者与排雷分别校对', () {
    final ContentDraft draft = text(
      '书名：破晓记录\n作者：张远\n字数：123.5万\n第一本全文。\n\n星光漫游 by 陈树\n第二本全文。\n\n排雷：《迷雾楼》\n作者：不详\n第三本全文。',
    );
    expect(draft.entries.map((ContentEntryDraft entry) => entry.name), <String>[
      '破晓记录',
      '星光漫游',
      '迷雾楼',
    ]);
    expect(draft.entries.first.author, '张远');
    expect(draft.entries.first.wordCount, 1235000);
    expect(draft.entries[1].author, '陈树');
    expect(draft.entries.last.author, '');
    expect(draft.entries.last.category, '排雷');
  });

  test('未识别仍完整保留为帖子，正文中的用户符号和 emoji 不损坏', () {
    const String raw = '读书随笔\n\n这次只有讨论，没有可靠的书名。😀\n结尾真实内容。';
    final ContentDraft draft = text(raw);
    expect(draft.entries, isEmpty);
    expect(draft.rawDocument, utf8.encode(raw));
    expect(draft.floors.last.text, contains('😀\n结尾真实内容。'));
  });

  test('微信 HTML 保留可见段落顺序、标题、账号、日期、懒加载图片、链接和媒体提示', () {
    final String raw =
        '''<!doctype html><html><head><title>页面标题</title></head><body>
<h1 id="activity-name">真实扫书标题</h1><span id="js_name">读书账号</span><span id="publish_time">2026年11月02日</span>
<div id="js_content"><section><p>开场完整文本 &amp; 作者观点</p>
<p><strong>《青山行》</strong> 作者：何溪</p><p>长评首段<br>长评第二行</p>
<p><img data-src="https://mmbiz.qpic.cn/mmbiz_png/cover/0?wx_fmt=png" src="placeholder.gif" alt="原图说明" data-w="1200" data-h="900"></p>
<p><a href="https://example.com/reference">参考资料</a></p><p>末尾内容不得丢失。</p><video src="https://example.com/video.mp4"></video></section></div>
<script>malicious()</script><div>网页操作栏不属于正文</div></body></html>''';
    final ContentDraft draft = reader.read(
      bytes: Uint8List.fromList(utf8.encode(raw)),
      fileName: '公众号.html',
      sourceUrl: 'https://mp.weixin.qq.com/s/sample',
    );
    expect(draft.title, '真实扫书标题');
    expect(draft.author, '读书账号');
    expect(draft.channel, '微信公众号');
    expect(draft.date, '2026-11-02');
    expect(draft.imageCount, 1);
    final ContentImageDraft image = draft.floors
        .expand((ContentFloorDraft floor) => floor.images)
        .single;
    expect(image.url, 'https://mmbiz.qpic.cn/mmbiz_png/cover/0?wx_fmt=png');
    expect(image.width, 1200);
    final String body = draft.floors
        .map((ContentFloorDraft floor) => floor.text)
        .join('\n');
    expect(body, contains('开场完整文本 & 作者观点'));
    expect(body, contains('长评首段\n长评第二行'));
    expect(body, contains('原图说明'));
    expect(body, contains('https://example.com/reference'));
    expect(body, contains('末尾内容不得丢失'));
    expect(body, isNot(contains('malicious')));
    expect(body, isNot(contains('网页操作栏')));
    expect(draft.entries.single.author, '何溪');
    expect(draft.entries.single.comment, contains('末尾内容不得丢失'));
    expect(draft.warnings.join('\n'), contains('video'));
    expect(draft.rawDocument, utf8.encode(raw));
  });

  test('验证、删除页、空 HTML 和无损解码失败均不能假装导入成功', () {
    for (final String html in <String>[
      '<html><body>环境异常，完成验证后即可继续访问。</body></html>',
      '<html><body>该内容已被发布者删除</body></html>',
      '<html><body></body></html>',
    ]) {
      expect(
        () => text(html, name: 'page.html'),
        throwsA(isA<ContentEditException>()),
      );
    }
    expect(
      () => reader.read(
        bytes: Uint8List.fromList(<int>[0x81, 0x82, 0x83]),
        fileName: 'bad.txt',
      ),
      throwsA(isA<ContentEditException>()),
    );
  });

  test('UTF-16 保留中文、换行与完整原始字节', () {
    const String raw = '《完整书目》 作者：清溪\n尾部😀';
    final BytesBuilder bytes = BytesBuilder()..add(<int>[0xff, 0xfe]);
    for (final int code in raw.codeUnits) {
      bytes.add(<int>[code & 255, code >> 8]);
    }
    final Uint8List original = bytes.takeBytes();
    final ContentDraft draft = reader.read(
      bytes: original,
      fileName: 'utf16.txt',
    );
    expect(draft.floors.single.text, raw);
    expect(draft.rawDocument, original);
  });

  test('Markdown 本地嵌入图片和说明随段落保留', () {
    final ContentDraft draft = text(
      '# 扫书\n\n《小城日记》 作者：青禾\n![封面说明](data:image/png;base64,$sampleImage)\n完整评价尾部。',
      name: 'article.md',
    );
    expect(draft.imageCount, 1);
    expect(draft.floors.last.images.single.embedded, isTrue);
    expect(draft.floors.last.text, contains('封面说明'));
    expect(draft.entries.single.comment, contains('完整评价尾部'));
  });

  test('DOCX 段落、表格文本、链接及内嵌图片不丢失', () {
    final Archive archive = Archive();
    void add(String name, String content) {
      final List<int> data = utf8.encode(content);
      archive.addFile(ArchiveFile(name, data.length, data));
    }

    add(
      'word/document.xml',
      '''<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><w:body>
<w:p><w:r><w:t>《云端旅行》 作者：江林</w:t></w:r></w:p>
<w:p><w:r><w:t>第一段完整评价</w:t><w:br/><w:t>下一行</w:t></w:r><w:drawing><a:blip r:embed="rIdImage"/></w:drawing></w:p>
<w:tbl><w:tr><w:tc><w:p><w:r><w:t>表格里的真实内容</w:t></w:r></w:p></w:tc></w:tr></w:tbl>
<w:p><w:hyperlink r:id="rIdLink"><w:r><w:t>参考链接</w:t></w:r></w:hyperlink><w:r><w:t>最终结尾</w:t></w:r></w:p></w:body></w:document>''',
    );
    add(
      'word/_rels/document.xml.rels',
      '<Relationships><Relationship Id="rIdImage" Target="media/cover.png"/><Relationship Id="rIdLink" Target="https://example.com/reference"/></Relationships>',
    );
    final Uint8List image = base64Decode(sampleImage);
    archive.addFile(ArchiveFile('word/media/cover.png', image.length, image));
    final Uint8List bytes = Uint8List.fromList(ZipEncoder().encode(archive));
    final ContentDraft draft = reader.read(bytes: bytes, fileName: '真实文档.docx');
    expect(draft.rawDocument, bytes);
    expect(draft.imageCount, 1);
    expect(draft.floors[1].images.single.embedded, isTrue);
    final String body = draft.floors
        .map((ContentFloorDraft floor) => floor.text)
        .join('\n');
    expect(body, contains('第一段完整评价\n下一行'));
    expect(body, contains('表格里的真实内容'));
    expect(body, contains('https://example.com/reference'));
    expect(body, contains('最终结尾'));
    expect(draft.entries.single.comment, contains('最终结尾'));
  });

  test('单书扫书标签、别名和相关推荐不分拆主书完整评价', () {
    final ContentDraft draft = text('扫书:阴阳造化炉\n扫书人:二哈\n作者:青烽不醉\n本书又名《别名一》《别名二》\n\n相关小说推荐\n1.《推荐甲》\n2.《推荐乙》\n\n点评\n主书完整结尾。');
    expect(draft.entries, hasLength(1));
    expect(draft.entries.single.name, '阴阳造化炉');
    expect(draft.entries.single.author, '青烽不醉');
    expect(draft.entries.single.comment, contains('主书完整结尾'));
  });

  test('微信自定义公众号卡片图片随可见正文保存', () {
    final ContentDraft draft = text('<html><body><div id="js_content"><p>原文</p><mp-common-profile data-nickname="读书账号" data-signature="真实签名" data-headimg="https://example.com/avatar.png"></mp-common-profile><p>结尾</p></div></body></html>', name: 'page.html');
    expect(draft.imageCount, 1);
    expect(draft.floors.map((ContentFloorDraft floor) => floor.text).join('\n'), contains('读书账号 · 真实签名'));
  });

  test('UTF-16 不配对代理项拒绝损坏文字', () {
    expect(() => reader.read(bytes: Uint8List.fromList(<int>[0xff, 0xfe, 0x00, 0xd8]), fileName: 'bad-utf16.txt'), throwsA(isA<ContentEditException>()));
  });
}
