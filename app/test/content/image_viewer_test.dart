import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/features/content/content_detail_page.dart';
import 'package:booksift/theme/book_theme.dart';

import '../support/harness.dart';

// 任务 2：图片查看器画廊归一化（showImageViewer 新增可选 images/initialIndex，
// 缺省退化为单张 → 旧调用点兼容）。
// 任务 3：弹层外框尺寸（可用窗口 60%×80%）与「点外部关闭 / 点内部不关」。
// 左右切换钮：悬停侧区淡入 / 移出淡出（AnimatedOpacity + IgnorePointer），首末页按钮隐藏。
//
// 归一化 / 尺寸是纯函数 → plain test()（floor_images_grid_test 同款口径）。
// testWidgets 只经 showImageViewer 的 imageBuilder 注入口挂假图，**不**塞真实 URL ——
// CachedNetworkImage 会触真实网络/磁盘缓存（app/test/TESTING.md §1；仓库语料一律无图）。

FloorImage _img(int id) => FloorImage(
  id: id,
  floorId: 1,
  urlOriginal: 'https://tiebapic.baidu.com/item/$id.jpg',
  urlPermanent: null,
  width: 0,
  height: 0,
);

void main() {
  group('FloorImages.viewerGalleryOf', () {
    test('images 缺省（null）→ 退化为被点单图（旧签名兼容）', () {
      final ({List<FloorImage> images, int index}) g =
          FloorImages.viewerGalleryOf(_img(7), null, 0);
      expect(g.images, hasLength(1));
      expect(g.images.single.id, 7);
      expect(g.index, 0);
    });

    test('空列表 → 同样退化单图，越界 initialIndex 不泄漏', () {
      final ({List<FloorImage> images, int index}) g =
          FloorImages.viewerGalleryOf(_img(3), const <FloorImage>[], 5);
      expect(g.images.map((FloorImage e) => e.id), <int>[3]);
      expect(g.index, 0);
    });

    test('给定画廊 → 原列表直通 + 起始位保留（PageView initialPage 用）', () {
      final List<FloorImage> gallery = <FloorImage>[_img(1), _img(2), _img(3)];
      final ({List<FloorImage> images, int index}) g =
          FloorImages.viewerGalleryOf(gallery[1], gallery, 1);
      expect(g.images, same(gallery));
      expect(g.index, 1);
    });

    test('起始位越界 → 夹取到合法域', () {
      final List<FloorImage> gallery = <FloorImage>[_img(1), _img(2)];
      expect(FloorImages.viewerGalleryOf(gallery[0], gallery, -3).index, 0);
      expect(FloorImages.viewerGalleryOf(gallery[0], gallery, 99).index, 1);
    });
  });

  group('FloorImages.viewerFrameOf', () {
    test('横竖屏同口径：按可用窗口算 宽 60% / 高 80%', () {
      final Size landscape = FloorImages.viewerFrameOf(const Size(1280, 800));
      expect(landscape.width, closeTo(768, 0.001));
      expect(landscape.height, closeTo(640, 0.001));

      final Size portrait = FloorImages.viewerFrameOf(const Size(390, 844));
      expect(portrait.width, closeTo(234, 0.001));
      expect(portrait.height, closeTo(675.2, 0.001));
    });
  });

  // 查看器弹层（任务 3）：走真实入口 showImageViewer + imageBuilder 假图（零网络/零磁盘）。
  group('查看器弹层', () {
    Widget host(void Function(BuildContext context) onReady) => MaterialApp(
      theme: BookTheme.light,
      darkTheme: BookTheme.dark,
      themeMode: ThemeMode.light,
      home: Builder(
        builder: (BuildContext context) {
          onReady(context);
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    );

    Widget fakeImage(BuildContext context, FloorImage image) => Container(
      width: 320,
      height: 240,
      color: const Color(0xFFBDBDBD),
    );

    testWidgets('外框 = 软件窗口 60%×80%；点内部不关、点外部关闭', (WidgetTester tester) async {
      useSurface(tester, width: 1000, height: 600);
      late BuildContext hostContext;
      await tester.pumpWidget(
        host((BuildContext context) => hostContext = context),
      );

      final List<FloorImage> gallery = <FloorImage>[_img(1), _img(2)];
      showImageViewer(
        hostContext,
        gallery.first,
        images: gallery,
        imageBuilder: fakeImage,
      );
      await tester.pumpAndSettle();

      // 1000×600 的窗口 → 600×480 外框（不再全屏，四周留出「外部」）。
      final Size frame = tester.getSize(find.byType(PageView));
      expect(frame.width, closeTo(600, 0.5));
      expect(frame.height, closeTo(480, 0.5));
      // 保留 i/n 计数与右上关闭钮。
      expect(find.text('1/2'), findsOneWidget);
      expect(find.byTooltip('关闭'), findsOneWidget);

      // 点图片 / PageView 内部 → 不关。
      await tester.tap(find.byType(PageView));
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsOneWidget, reason: '内部点击不关闭');

      // 点弹层外（barrier 区域）→ 关闭。
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsNothing);
    });

    testWidgets('保留左右翻页与关闭钮：横滑换页更新 i/n，关闭钮可关', (WidgetTester tester) async {
      useSurface(tester, width: 1000, height: 600);
      late BuildContext hostContext;
      await tester.pumpWidget(
        host((BuildContext context) => hostContext = context),
      );

      final List<FloorImage> gallery = <FloorImage>[_img(1), _img(2)];
      showImageViewer(
        hostContext,
        gallery.first,
        images: gallery,
        imageBuilder: fakeImage,
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('2/2'), findsOneWidget);

      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsNothing);
    });

    testWidgets('左右切换钮：悬停淡入、移出淡出，首末页隐藏，点击同步 i/n', (WidgetTester tester) async {
      useSurface(tester, width: 1000, height: 600);
      late BuildContext hostContext;
      await tester.pumpWidget(
        host((BuildContext context) => hostContext = context),
      );

      final List<FloorImage> gallery = <FloorImage>[_img(1), _img(2), _img(3)];
      showImageViewer(
        hostContext,
        gallery[1],
        images: gallery,
        initialIndex: 1,
        imageBuilder: fakeImage,
      );
      await tester.pumpAndSettle();
      expect(find.text('2/3'), findsOneWidget);

      const Key prevFade = Key('image_viewer_prev_fade');
      const Key nextFade = Key('image_viewer_next_fade');
      double fadeOf(Key key) =>
          tester.widget<AnimatedOpacity>(find.byKey(key)).opacity;

      // 初始无悬停 → 两个切换钮均隐藏。
      expect(fadeOf(prevFade), 0);
      expect(fadeOf(nextFade), 0);

      // 真实鼠标（PointerDeviceKind.mouse）驱动 MouseRegion 悬停。
      final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      Finder hoverOf(String side) => find.byKey(Key('image_viewer_hover_$side'));

      // 悬停左侧 → 上一张淡入；点击 → 回到第一张并同步 i/n。
      await mouse.moveTo(tester.getCenter(hoverOf('left')));
      await tester.pumpAndSettle();
      expect(fadeOf(prevFade), 1);
      expect(fadeOf(nextFade), 0);

      await tester.tap(find.byKey(const Key('image_viewer_prev_button')));
      await tester.pumpAndSettle();
      expect(find.text('1/3'), findsOneWidget);
      // 第一张：左侧钮按可用性隐藏（此时鼠标仍在左区）。
      expect(fadeOf(prevFade), 0);

      // 悬停右侧 → 下一张淡入；点击一次到第二张。
      await mouse.moveTo(tester.getCenter(hoverOf('right')));
      await tester.pumpAndSettle();
      expect(fadeOf(nextFade), 1);
      expect(fadeOf(prevFade), 0);

      await tester.tap(find.byKey(const Key('image_viewer_next_button')));
      await tester.pumpAndSettle();
      expect(find.text('2/3'), findsOneWidget);

      // 移出右侧区域（回到中段）→ 下一张淡出。
      await mouse.moveTo(tester.getCenter(find.byType(PageView)));
      await tester.pumpAndSettle();
      expect(fadeOf(nextFade), 0);

      // 再悬停右侧点一次 → 末页；末页右侧钮隐藏，i/n 同步。
      await mouse.moveTo(tester.getCenter(hoverOf('right')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('image_viewer_next_button')));
      await tester.pumpAndSettle();
      expect(find.text('3/3'), findsOneWidget);
      expect(fadeOf(nextFade), 0);
    });
  });
}
