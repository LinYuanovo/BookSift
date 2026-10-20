import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/features/share/share_card.dart';
import 'package:booksift/features/share/share_service.dart';
import 'package:booksift/features/share/share_sheet.dart';
import 'package:booksift/theme/book_theme.dart';

// 文字转图分享（M3 P1-4）的测试替身与宿主。
//
// 纪律（app/test/TESTING.md §1/§3.1）：testWidgets 体内**不得**碰真实事件循环。
// 分享导出链路上有两处真实异步 —— `RepaintBoundary.toImage()`（引擎侧）与
// 文件写/平台通道（file_picker / share_plus / path_provider）。所以：
//   · 真栅格化断言 → 放 `tester.runAsync(...)`（share_card_render_test.dart）；
//   · 弹层交互断言 → 注入 [fakeRenderPng] + [FakeShareSink]（纯微任务，零 IO）。

/// PNG 文件头 8 字节（判定「确实栅格化出了 PNG」）。
const List<int> kPngMagic = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

/// 假 PNG 字节：magic + 填充。不是合法图像，只用于断言「字节流到了 sink」。
Uint8List fakePng({int length = 64}) => Uint8List.fromList(<int>[
      ...kPngMagic,
      ...List<int>.filled(length - kPngMagic.length, 0),
    ]);

/// 纯内存渲染端口（只有微任务 → 可在 testWidgets 假时钟区里 await）。
Future<Uint8List> fakeRenderPng(GlobalKey boundaryKey, {double pixelRatio = kSharePixelRatio}) async =>
    fakePng();

/// 内存导出端口：记下每次 save/share 的字节、文件名、文案与 iPad 锚点。
final class FakeShareSink implements ShareSink {
  FakeShareSink({
    this.saveOutcome = const ShareOutcome(
      ShareOutcomeKind.saved,
      path: r'C:\Users\x\Documents\booksift_share\booksift_share_20261013_120000.png',
    ),
    this.shareOutcome = const ShareOutcome(ShareOutcomeKind.shared),
  });

  /// 可改写的返回值（测「取消 / 不支持 / 失败」三态的 SnackBar 文案）。
  ShareOutcome saveOutcome;
  ShareOutcome shareOutcome;

  final List<Uint8List> savedBytes = <Uint8List>[];
  final List<Uint8List> sharedBytes = <Uint8List>[];
  final List<String> savedNames = <String>[];
  final List<String> sharedNames = <String>[];
  String? shareText;
  Rect? shareOrigin;

  @override
  Future<ShareOutcome> save(Uint8List png, String fileName) async {
    savedBytes.add(png);
    savedNames.add(fileName);
    return saveOutcome;
  }

  @override
  Future<ShareOutcome> share(Uint8List png, String fileName, {String? text, Rect? origin}) async {
    sharedBytes.add(png);
    sharedNames.add(fileName);
    shareText = text;
    shareOrigin = origin;
    return shareOutcome;
  }
}

/// 弹层测试宿主：点按钮走**真入口** [showShareSheet]（顺带覆盖 modal 弹层形态）。
Widget shareSheetHost(
  ShareCardSpec spec, {
  bool freeMode = false,
  ShareSink? sink,
  SharePngRenderer render = fakeRenderPng,
}) {
  final ShareService service = ShareService(sink ?? FakeShareSink(), render);
  return MaterialApp(
    theme: BookTheme.light,
    home: Scaffold(
      body: Builder(
        builder: (BuildContext context) => Center(
          child: TextButton(
            onPressed: () =>
                showShareSheet(context, spec, freeMode: freeMode, service: service),
            child: const Text('打开弹层'),
          ),
        ),
      ),
    ),
  );
}

/// 打开弹层并等入场动画收敛。
Future<void> openShareSheet(
  WidgetTester tester,
  ShareCardSpec spec, {
  bool freeMode = false,
  ShareSink? sink,
  SharePngRenderer render = fakeRenderPng,
}) async {
  await tester.pumpWidget(shareSheetHost(spec, freeMode: freeMode, sink: sink, render: render));
  await tester.tap(find.text('打开弹层'));
  await tester.pumpAndSettle();
}

/// 弹层里当前渲染的卡片载荷（断言参数面板 → 卡片 的联动）。
ShareCardSpec cardSpecOf(WidgetTester tester) =>
    tester.widget<ShareCard>(find.descendant(of: find.byType(ShareSheet), matching: find.byType(ShareCard))).spec;

/// 演示载荷（§5.11 线框同形状：书名 + 作者 + 推荐人 + 引用正文）。
const ShareCardSpec demoShareSpec = ShareCardSpec(
  bookName: '十日终焉',
  author: '杀虫队队员',
  recommender: '残梦灬语宵',
  quote: '悬疑无限流，十日一轮，规则怪谈与群像并存，前期节奏偏慢但后劲很足。',
);
