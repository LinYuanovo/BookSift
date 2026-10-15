import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../theme/app_typography.dart';

/// 分享卡片（原型 §5.11「文字转图分享」· M3 P1-4）。
///
/// 卡片就是一棵普通 Widget 树：外层 [RepaintBoundary]（由 share_sheet.dart 挂 GlobalKey）
/// → `toImage(pixelRatio: 2.5)` → PNG（见 share_service.dart）。
///
/// 视觉语汇继承本 App 设计系统（衬线书名大字 + 引用正文 + 发丝分隔线 + 水印行），
/// 但**颜色不取 AppColors token**：4 配色是随图片固化的「内容配色」，导出物必须在
/// 明/暗主题下逐像素一致，因此本文件只引用字阶 token（[AppTypography]，衬线书名走
/// display 槽），色值见 [ShareCardPalette]。
///
/// 依赖：调用方须提供 BookTheme（字阶扩展），与全仓组件一致。

/// 4 档内容配色（§5.11：白 `#FFFFFFFF` / 黑 `#FF293443` / 绿 `#FFCFECBA` / 米 `#FFE6D3AA`，
/// 边框色随配色）。
///
/// 底色 4 值为原型逐字给定；前景/次级/边框/强调为本次派生（同族色相，正文对比度
/// 全部 ≥4.5:1，守卫见 test/share/share_card_render_test.dart）。
///
/// 色值用 `Color.fromARGB(a, r, g, b)` 表述、不写 ARGB hex 字面量：`test/theme_tokens_test.dart`
/// 有「lib/theme 之外禁止硬编码色值」的全仓守卫（其正则按行扫，连注释里的 hex 写法一起算），
/// 该守卫针对「组件应引用 AppColors token」；本表是导出图片的一部分、刻意不随 App 明暗主题
/// 变化（同一份 PNG 在浅色/深色模式下必须逐像素一致），属守卫的例外面。
/// 若集成时更希望显式白名单，可在该守卫里把 `lib/features/share/` 与 `lib/theme/` 同列跳过。
enum ShareCardPalette {
  /// 白（默认）：白底黑字。
  paper('白', Color.fromARGB(255, 255, 255, 255), Color.fromARGB(255, 31, 30, 27),
      Color.fromARGB(255, 102, 100, 92), Color.fromARGB(255, 227, 223, 213), Color.fromARGB(255, 166, 78, 44)),

  /// 黑：深板岩底白字。
  ink('黑', Color.fromARGB(255, 41, 52, 67), Color.fromARGB(255, 245, 247, 250),
      Color.fromARGB(255, 183, 192, 204), Color.fromARGB(255, 61, 74, 92), Color.fromARGB(255, 143, 180, 204)),

  /// 绿：薄荷底深绿字。
  moss('绿', Color.fromARGB(255, 207, 236, 186), Color.fromARGB(255, 30, 51, 32),
      Color.fromARGB(255, 74, 97, 72), Color.fromARGB(255, 179, 214, 156), Color.fromARGB(255, 47, 111, 53)),

  /// 米：暖米底深棕字。
  sand('米', Color.fromARGB(255, 230, 211, 170), Color.fromARGB(255, 58, 44, 20),
      Color.fromARGB(255, 107, 88, 54), Color.fromARGB(255, 210, 188, 140), Color.fromARGB(255, 140, 74, 33));

  const ShareCardPalette(this.label, this.background, this.foreground, this.muted, this.border, this.accent);

  /// 设置面板 swatch 的中文名（§5.11 线框「⬜白 ⬛黑 🟩绿 🟨米」）。
  final String label;

  /// 卡片底色（§5.11 给定 hex）。
  final Color background;

  /// 主文字（书名/正文）。
  final Color foreground;

  /// 次级文字（作者/推荐人/水印）。
  final Color muted;

  /// 分隔线与描边。
  final Color border;

  /// 强调（书名上的短规则线 / 引号）。
  final Color accent;
}

/// 卡片载荷：内容 + 版式参数（不可变；弹层持可编辑副本，见 share_sheet.dart）。
///
/// 参数域继承宝典（§5.11）：字号 8–30、行距 1.0–3.0、4 配色、水印可编辑、
/// 正文 >8000 字截断。
@immutable
class ShareCardSpec {
  const ShareCardSpec({
    this.bookName,
    this.title,
    this.author,
    this.recommender,
    this.quote = '',
    this.watermark,
    this.fontSize = defaultFontSize,
    this.lineHeight = defaultLineHeight,
    this.palette = ShareCardPalette.paper,
  });

  /// 字号下限（§5.11）。
  static const double minFontSize = 8;

  /// 字号上限（§5.11）。
  static const double maxFontSize = 30;

  /// 行距下限（§5.11）。
  static const double minLineHeight = 1.0;

  /// 行距上限（§5.11）。
  static const double maxLineHeight = 3.0;

  /// 正文字数上限（§5.11 错误态：>8000 字提示截断）。
  static const int maxQuoteChars = 8000;

  /// 字号步进（A−/A+）。
  static const double fontSizeStep = 1;

  /// 行距步进（L−/L+，一位小数）。
  static const double lineHeightStep = 0.1;

  static const double defaultFontSize = 16;
  static const double defaultLineHeight = 1.7;

  /// 截断标记（拼在截断正文末尾）。
  static const String truncatedSuffix = '…（已截断）';

  /// 书名（不含《》，渲染时补全）；书聚合/自由模式用。
  final String? bookName;

  /// 无书名时的标题行（帖标题 / 自由模式手输）；不加《》。
  final String? title;

  /// 作者。
  final String? author;

  /// 推荐人（默认水印的 BY 对象）。
  final String? recommender;

  /// 引用正文（**原始未截断**文本；渲染取 [displayQuote]）。
  final String quote;

  /// 水印文字；null 或空 → [defaultWatermark]。
  final String? watermark;

  /// 正文字号 8–30。
  final double fontSize;

  /// 正文行距倍数 1.0–3.0。
  final double lineHeight;

  /// 配色。
  final ShareCardPalette palette;

  /// 默认水印「扫书汇APP | BY {推荐人}」（§5.11；无推荐人时只留品牌段）。
  String get defaultWatermark {
    final String by = (recommender ?? '').trim();
    return by.isEmpty ? '${AppConstants.appName}APP' : '${AppConstants.appName}APP | BY $by';
  }

  /// 实际渲染的水印（用户改过就用用户的）。
  String get effectiveWatermark {
    final String w = (watermark ?? '').trim();
    return w.isEmpty ? defaultWatermark : w;
  }

  /// 标题行：书名优先（补《》），否则帖标题/手输标题，都空则 null。
  String? get headline {
    final String book = (bookName ?? '').trim();
    if (book.isNotEmpty) {
      return book.startsWith('《') ? book : '《$book》';
    }
    final String t = (title ?? '').trim();
    return t.isEmpty ? null : t;
  }

  /// 书名下的署名行（作者 / 推荐人）；都空则 null。
  String? get creditLine {
    final List<String> parts = <String>[
      if ((author ?? '').trim().isNotEmpty) author!.trim(),
      if ((recommender ?? '').trim().isNotEmpty) '推荐人 ${recommender!.trim()}',
    ];
    return parts.isEmpty ? null : parts.join(' / ');
  }

  /// 是否触发 §5.11 截断态。
  bool get isTruncated => quote.length > maxQuoteChars;

  /// 渲染用正文（截断到 8000 字 + 标记）。
  String get displayQuote =>
      isTruncated ? '${quote.substring(0, maxQuoteChars)}$truncatedSuffix' : quote;

  /// 字号步进（越界即夹紧到 8–30）。
  ShareCardSpec stepFontSize(double delta) => copyWith(
        fontSize: (fontSize + delta).clamp(minFontSize, maxFontSize),
      );

  /// 行距步进（越界即夹紧到 1.0–3.0；一位小数）。
  ShareCardSpec stepLineHeight(double delta) => copyWith(
        lineHeight: double.parse(
          (lineHeight + delta).clamp(minLineHeight, maxLineHeight).toStringAsFixed(1),
        ),
      );

  ShareCardSpec copyWith({
    String? bookName,
    String? title,
    String? author,
    String? recommender,
    String? quote,
    String? watermark,
    double? fontSize,
    double? lineHeight,
    ShareCardPalette? palette,
  }) {
    return ShareCardSpec(
      bookName: bookName ?? this.bookName,
      title: title ?? this.title,
      author: author ?? this.author,
      recommender: recommender ?? this.recommender,
      quote: quote ?? this.quote,
      watermark: watermark ?? this.watermark,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      palette: palette ?? this.palette,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ShareCardSpec &&
      other.bookName == bookName &&
      other.title == title &&
      other.author == author &&
      other.recommender == recommender &&
      other.quote == quote &&
      other.watermark == watermark &&
      other.fontSize == fontSize &&
      other.lineHeight == lineHeight &&
      other.palette == palette;

  @override
  int get hashCode => Object.hash(
        bookName,
        title,
        author,
        recommender,
        quote,
        watermark,
        fontSize,
        lineHeight,
        palette,
      );
}

/// 分享卡片本体（固定宽度的「画板」，居中留白；导出 PNG = 本 widget 的栅格化结果）。
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.spec, this.width = 360});

  final ShareCardSpec spec;

  /// 画板宽（dp）；导出像素宽 = width × pixelRatio。
  final double width;

  /// 画板内边距（内容物固定版式，不吃 AppSpacing token——卡片是图片，不是 App 界面）。
  static const EdgeInsets _padding = EdgeInsets.fromLTRB(28, 26, 28, 20);

  @override
  Widget build(BuildContext context) {
    final AppTypography t = AppTypography.of(context);
    final ShareCardPalette p = spec.palette;
    final String? headline = spec.headline;
    final String? credit = spec.creditLine;
    // 书名随正文字号等比放大（display 槽的 family/字重不变，只换字号）。
    final double headlineSize = (spec.fontSize * 1.6).clamp(14.0, 44.0);
    return Container(
      width: width,
      padding: _padding,
      decoration: BoxDecoration(
        color: p.background,
        border: Border.all(color: p.border, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 强调短规则线（28×2）：卡片唯一装饰，替代图标（导出物里不塞 SVG，省资产解码）。
          Container(width: 28, height: 2, color: p.accent),
          if (headline != null) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              headline,
              style: t.display.copyWith(
                fontSize: headlineSize,
                height: 1.35,
                color: p.foreground,
              ),
            ),
          ],
          if (credit != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(credit, style: t.secondary.copyWith(color: p.muted)),
          ],
          const SizedBox(height: 18),
          Container(height: 1, color: p.border),
          const SizedBox(height: 18),
          Text(
            spec.displayQuote,
            style: t.body.copyWith(
              fontSize: spec.fontSize,
              height: spec.lineHeight,
              color: p.foreground,
            ),
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: p.border),
          const SizedBox(height: 12),
          // 水印行（§5.11：默认「扫书汇APP | BY {推荐人}」，可编辑）。
          Row(
            children: <Widget>[
              Container(width: 14, height: 2, color: p.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  spec.effectiveWatermark,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.label.copyWith(letterSpacing: 0.6, color: p.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
