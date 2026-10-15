import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/features/content/content_detail_page.dart';
import 'package:booksift/theme/app_spacing.dart';

// 任务 1（图片网格铺满）+ 任务 4（展示列顺序）。
//
// 全部 plain test()：几何与取链都是纯函数，无需 widget 树。
// **不**给 FloorImages 塞真实图片跑 testWidgets —— CachedNetworkImage 会触
// 真实网络/磁盘缓存（app/test/TESTING.md §1；仓库语料一律无图，同口径）。

/// compact 手机（≈411dp）详情页图片区可用宽：屏宽 - 页面左右 padding - 楼层左缩进。
double availableWidth(double screen, AppSpacing s) =>
    screen - s.pagePadding * 2 - s.space4;

/// 一行 n 张 tile 占用的主轴长度（含 n-1 个间距）。
double rowExtent(int columns, double tile, double spacing) =>
    columns * tile + (columns - 1) * spacing;

FloorImage img({String? original, String? permanent}) => FloorImage(
  id: 1,
  floorId: 1,
  urlOriginal: original,
  urlPermanent: permanent,
  width: 0,
  height: 0,
);

void main() {
  const AppSpacing s = AppSpacing.standard;
  final double spacing = s.space2;

  group('FloorImages.gridOf 列数/tile 计算', () {
    test('compact 411dp：一行 3 张且铺满可用宽（固定 120dp 时只有 2 张 + 大片留白）', () {
      final double w = availableWidth(411, s); // 411 - 40 - 16 = 355
      final ({int columns, double tile}) g = FloorImages.gridOf(w, spacing);

      expect(w, 355);
      expect(g.columns, 3);
      expect(g.tile, 113);
      expect(
        rowExtent(g.columns, g.tile, spacing),
        lessThanOrEqualTo(w),
        reason: '三张 + 两个间距不得超过可用宽（超了 Wrap 会把末列挤到下一行）',
      );
      expect(w - rowExtent(g.columns, g.tile, spacing), lessThan(g.columns),
          reason: '剩余留白 < 1px/列 = 视觉上铺满');
      // 旧实现口径对照：120dp 固定缩略图一行只放得下 2 张。
      expect((w + spacing) ~/ (120 + spacing), 2);
    });

    test('测试默认 390dp 面：一行 3 张', () {
      final ({int columns, double tile}) g = FloorImages.gridOf(
        availableWidth(390, s),
        spacing,
      );
      expect(g.columns, 3);
      expect(g.tile, 106);
    });

    test('列数被夹在 2..5：窄槽不少 2 列、超宽不多 5 列', () {
      expect(FloorImages.gridOf(150, spacing).columns, 2, reason: '窄槽下限 2 列');
      expect(FloorImages.gridOf(600, spacing).columns, 5, reason: '宽屏上限 5 列');
      expect(FloorImages.gridOf(1600, spacing).columns, 5);
    });

    test('tile 上限 maxTile：超宽屏/expanded 右槽不致过大，超出部分左对齐留白', () {
      final ({int columns, double tile}) g = FloorImages.gridOf(1200, spacing);
      expect(g.tile, FloorImages.maxTile);
      expect(
        rowExtent(g.columns, g.tile, spacing),
        lessThan(1200),
        reason: '触顶后不满铺，Wrap 默认 start 对齐 → 左对齐留白',
      );
    });

    test('零宽约束不产负尺寸（LayoutBuilder 过渡帧可能出现 maxWidth=0）', () {
      expect(FloorImages.gridOf(0, spacing).tile, 0);
    });

    test('全宽域扫描：tile 恒 ≥0、≤maxTile，且一行不溢出可用宽', () {
      // 起点 = 一个间距：窄于一个 spacing 的宽度连「2 tile + 1 gap」都放不下，
      // 无可用布局（此时 tile 归 0，见上一用例）。
      for (double w = spacing; w <= 1600; w += 7) {
        final ({int columns, double tile}) g = FloorImages.gridOf(w, spacing);
        expect(g.columns, inInclusiveRange(2, 5), reason: 'w=$w');
        expect(g.tile, inInclusiveRange(0, FloorImages.maxTile), reason: 'w=$w');
        expect(
          rowExtent(g.columns, g.tile, spacing),
          lessThanOrEqualTo(w),
          reason: 'w=$w 一行溢出 → Wrap 掉列（网格不铺满的根因）',
        );
      }
    });
  });

  group('FloorImages.displayUrl 展示列顺序（缩略图与查看器共用同一函数）', () {
    test('优先 url_original（带扩展名 + 新签名），url_permanent 只作兜底', () {
      expect(
        FloorImages.displayUrl(
          img(
            original: 'https://tiebapic.baidu.com/forum/pic/item/h.jpg?tbpicau=x',
            permanent: 'https://imgsrc.baidu.com/forum/pic/item/h',
          ),
        ),
        'https://tiebapic.baidu.com/forum/pic/item/h.jpg?tbpicau=x',
      );
    });

    test('lite 档实况：url_original 全 NULL → 回落 url_permanent（种子自带带扩展名链）', () {
      expect(
        FloorImages.displayUrl(
          img(permanent: 'https://imgsrc.baidu.com/forum/pic/item/h.jpg'),
        ),
        'https://imgsrc.baidu.com/forum/pic/item/h.jpg',
      );
    });

    test('两列皆缺 → 空串（CachedNetworkImage 走 errorWidget 图裂占位）', () {
      expect(FloorImages.displayUrl(img()), '');
      expect(FloorImages.displayUrl(img(original: '', permanent: '')), '');
    });
  });
}
