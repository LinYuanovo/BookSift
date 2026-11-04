import 'dart:convert';

import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/features/content/content_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'document_reader_test.dart' show sampleImage;

void main() {
  Widget image(String url) => FloorImages.imageWidget(
    image: FloorImage(
      id: 1,
      floorId: 1,
      urlOriginal: url,
      width: 100,
      height: 80,
    ),
    width: 100,
    height: 80,
    fit: BoxFit.cover,
    errorBuilder: (_) => const Text('图片不可用'),
  );

  test('嵌入 SVG 使用矢量解码器并保留展示尺寸', () async {
    final String bytes = base64Encode(
      utf8.encode(
        '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="80"><rect width="100" height="80" fill="red"/></svg>',
      ),
    );
    final Widget widget = image('data:image/svg+xml;base64,$bytes');
    expect(widget, isA<SvgPicture>());
    final SvgPicture picture = widget as SvgPicture;
    expect(picture.width, 100);
    expect(picture.height, 80);
    expect(picture.fit, BoxFit.cover);
    expect(picture.errorBuilder, isNotNull);
    expect(
      (await picture.bytesLoader.loadBytes(null)).lengthInBytes,
      greaterThan(0),
    );
  });

  test('嵌入 PNG 沿用位图解码器', () {
    expect(image('data:image/png;base64,$sampleImage'), isA<Image>());
  });

  test('损坏的嵌入地址保留错误占位', () {
    expect(image('data:image/png;base64,%%%'), isA<Builder>());
  });
}
