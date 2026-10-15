import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/features/content/content_detail_page.dart';

// 任务 2：图片查看器画廊归一化（showImageViewer 新增可选 images/initialIndex，
// 缺省退化为单张 → 旧调用点兼容）。
//
// 全部 plain test()：归一化是纯函数（floor_images_grid_test 同款口径）。
// **不**在 testWidgets 里弹真实查看器 —— CachedNetworkImage 会触真实网络/磁盘缓存
// （app/test/TESTING.md §1；仓库语料一律无图，同口径）。

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
}
