import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../core/widgets/app_toast.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

// 楼层富文本渲染管线（§5.6，Dart 等价实现逆向报告 §2.4 规则）：
// 1) 《书名》→ 红色加粗可点（点击=以书名发起全库搜索，长按=复制书名，MI-3）；
// 2) URL → info 色下划线可点（点击=复制 + Toast「链接已复制到剪贴板」，§5.6 渲染管线 2）；
// 3) 搜索词 → 琥珀高亮逐词 IGNORE_CASE 着色（§5.6 渲染管线 4）；
// 4) 楼层前缀 ● N楼 与内联图片由 content_detail_page 组装；
// 5) 页内搜索（任务 4）→ searchWord 字面量级 IGNORE_CASE 命中全部琥珀，第
//    searchFocusIndex 个命中换 accent 当前色；计数函数 countSearchHits 与着色同口径。

/// 书名 span（WidgetSpan 承载 → 独立命中区可测试；1–40 字防误吞整段）。
final RegExp _bookPattern = RegExp(r'《([^《》\n]{1,40})》');

/// URL span（**ASCII 连续段**；中文标点/空白/汉字即截断，尾部标点归还原段）。
///
/// 字符类必须是白名单而非 `[^\s《》…]` 黑名单：黑名单会把 `https://a.b/c。下一句`
/// 整段吞进链接（中文句号与汉字都不在排除集里），点击复制得到脏 URL。
/// 取值 = RFC 3986 保留/非保留字符集，天然排除全部非 ASCII。
final RegExp _urlPattern = RegExp(r"https?://[A-Za-z0-9\-._~:/?#\[\]@!$&'()*+,;=%]+");

const String _urlTrailingCut = '.,;:!?，。；：！？、)]}】>"\'…';

/// 解析结果为交错片段：书名 / 链接 / 纯文本（保持原文顺序）。
sealed class FloorSegment {}

class BookSegment extends FloorSegment {
  BookSegment(this.name);
  final String name;
}

class UrlSegment extends FloorSegment {
  UrlSegment(this.url);
  final String url;
}

class PlainSegment extends FloorSegment {
  PlainSegment(this.text);
  final String text;
}

/// 交错扫描书名与 URL（单遍、原文顺序）。
List<FloorSegment> parseFloorSegments(String text) {
  final List<FloorSegment> out = <FloorSegment>[];
  final List<RegExpMatch> matches = <RegExpMatch>[
    ..._bookPattern.allMatches(text),
    ..._urlPattern.allMatches(text),
  ]..sort((RegExpMatch a, RegExpMatch b) => a.start.compareTo(b.start));

  int cursor = 0;
  for (final RegExpMatch m in matches) {
    if (m.start < cursor) {
      continue; // 与已收录片段重叠（书名内含 http 等），先到先得。
    }
    if (m.start > cursor) {
      out.add(PlainSegment(text.substring(cursor, m.start)));
    }
    // 书名正则带捕获组（groupCount=1）；URL 正则无捕获组 —— 注意 Match.group(1) 对
    // 无捕获组的匹配是**抛 RangeError 而非返回 null**，必须先判 groupCount。
    final String? bookName = m.groupCount >= 1 ? m.group(1) : null;
    if (bookName != null) {
      out.add(BookSegment(bookName));
    } else {
      String url = m.group(0)!;
      while (url.isNotEmpty && _urlTrailingCut.contains(url[url.length - 1])) {
        url = url.substring(0, url.length - 1);
      }
      out.add(UrlSegment(url));
      // 被裁掉的尾部标点归还为纯文本。
      if (url.length < m.group(0)!.length) {
        out.add(PlainSegment(m.group(0)!.substring(url.length)));
      }
    }
    cursor = m.end;
  }
  if (cursor < text.length) {
    out.add(PlainSegment(text.substring(cursor)));
  }
  return out;
}

/// 页内搜索命中计数（任务 4）：与 [FloorRichText] 的着色**同一口径** —— 只数
/// [parseFloorSegments] 纯文本段内的 IGNORE_CASE 字面量命中（书名/URL span 不参与
/// 着色也就不计数），保证搜索条「当前/总数」与可见高亮一一对应、第 k 个命中的
/// 索引两端一致（content_detail_page 的命中定位与 FloorRichText 的当前色共用）。
int countSearchHits(String text, String searchWord) {
  if (searchWord.isEmpty) {
    return 0;
  }
  final RegExp re = RegExp(RegExp.escape(searchWord), caseSensitive: false);
  int n = 0;
  for (final FloorSegment seg in parseFloorSegments(text)) {
    if (seg is PlainSegment) {
      n += re.allMatches(seg.text).length;
    }
  }
  return n;
}

/// 楼层正文（Text.rich + WidgetSpan；书名/链接可点，搜索词琥珀高亮）。
class FloorRichText extends StatefulWidget {
  const FloorRichText({
    super.key,
    required this.text,
    required this.onBookTap,
    this.highlightWords = const <String>[],
    this.searchWord = '',
    this.searchFocusIndex = -1,
    this.selectable = false,
    this.keepTapWhileSelectable = false,
  });

  final String text;

  /// 点击《书名》= 以书名发起新搜索（§5.6 核心交互闭环）。
  final ValueChanged<String> onBookTap;
  final List<String> highlightWords;

  /// 任务 4 页内搜索词：字面量级 IGNORE_CASE 命中全部琥珀（c.highlight），第
  /// [searchFocusIndex] 个命中（按本楼内出现顺序 0 起）换当前色（c.accent 底 +
  /// onAccent 字色）。空串 = 未激活。口径见 [countSearchHits]（只数纯文本段）。
  final String searchWord;

  /// 当前命中在本楼层内的序号；-1 = 本楼不含当前命中（全部普通琥珀）。
  final int searchFocusIndex;

  /// P1-6 自由复制选择模式：书名/URL 一律降级为**纯文本 span**（无 InkWell
  /// WidgetSpan），选择与复制交由外层 SelectionArea；复制得到纯文本（书名《》原样、
  /// 搜索高亮 background 不影响选区字节）。
  final bool selectable;

  /// 可选中时是否**保留单击手势**（桌面「随时可自由复制」档，用户口径）：
  /// 书名单击仍跳搜索、URL 单击仍复制链接 —— 但用 [TextSpan.recognizer] 而非
  /// InkWell WidgetSpan，文字因此并回文本流，可以像普通段落一样拖选复制；
  /// 拖拽选词由外层 SelectionArea 接管，单击才走 recognizer，两者不冲突。
  /// 为 false（触屏长按进模式）时沿用「手势全停」，避免抢走横滑翻页。
  final bool keepTapWhileSelectable;

  @override
  State<FloorRichText> createState() => _FloorRichTextState();
}

class _FloorRichTextState extends State<FloorRichText> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  /// 页内搜索命中游标（任务 4）：一次 build 内跨 PlainSegment 连续计数，
  /// build 入口归零；与 searchFocusIndex / 搜索条计数（countSearchHits）同口径。
  int _searchCursor = 0;

  void _disposeRecognizers() {
    for (final TapGestureRecognizer r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  TapGestureRecognizer _tap(VoidCallback onTap) {
    final TapGestureRecognizer r = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(r);
    return r;
  }

  /// 纯文本段内两层高亮（任务 4）：页内搜索词优先 —— 命中子串走「当前色/琥珀」，
  /// 命中间隙子串再走外部搜索词逐词琥珀高亮（§5.6 渲染管线 4）。
  List<TextSpan> _highlighted(String text, TextStyle base) {
    if (widget.searchWord.isEmpty) {
      return _wordHighlighted(text, base);
    }
    final AppColors c = AppColors.of(context);
    final RegExp re = RegExp(RegExp.escape(widget.searchWord), caseSensitive: false);
    final List<TextSpan> spans = <TextSpan>[];
    int cursor = 0;
    for (final RegExpMatch m in re.allMatches(text)) {
      if (m.start > cursor) {
        spans.addAll(_wordHighlighted(text.substring(cursor, m.start), base));
      }
      final int k = _searchCursor++;
      final bool focused = k == widget.searchFocusIndex;
      spans.add(TextSpan(
        text: m.group(0),
        // 当前命中：accent 底 + onAccent 字色（对比度由 token 保证）；普通命中琥珀底不改字色。
        style: base.copyWith(
          background: Paint()..color = focused ? c.accent : c.highlight,
          color: focused ? c.onAccent : null,
        ),
      ));
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.addAll(_wordHighlighted(text.substring(cursor), base));
    }
    return spans;
  }

  /// 外部搜索词逐词 IGNORE_CASE 琥珀高亮（§5.6 渲染管线 4；页内搜索命中间隙也用）。
  List<TextSpan> _wordHighlighted(String text, TextStyle base) {
    final List<String> words = widget.highlightWords.where((String w) => w.trim().isNotEmpty).toList();
    if (words.isEmpty) {
      return <TextSpan>[TextSpan(text: text)];
    }
    final AppColors c = AppColors.of(context);
    final Paint bg = Paint()..color = c.highlight;
    final String pattern = words.map(RegExp.escape).join('|');
    final RegExp re = RegExp('($pattern)', caseSensitive: false);
    final List<TextSpan> spans = <TextSpan>[];
    int cursor = 0;
    for (final RegExpMatch m in re.allMatches(text)) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start)));
      }
      spans.add(TextSpan(text: m.group(0), style: base.copyWith(background: bg)));
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    // 旧一代 span 随重建丢弃，recognizer 同步回收（dispose 幂等由 clear 保证）。
    _disposeRecognizers();
    // 任务 4：命中序号每次 build 从头数（出现顺序与 countSearchHits 分母一致）。
    _searchCursor = 0;

    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final TextStyle base = t.bodyRich.copyWith(color: c.text);
    final List<InlineSpan> spans = <InlineSpan>[];
    for (final FloorSegment seg in parseFloorSegments(widget.text)) {
      switch (seg) {
        case PlainSegment(:final String text):
          spans.addAll(_highlighted(text, base));
        case BookSegment(:final String name):
          if (widget.selectable) {
            // P1-6 选择模式：书名并入连续文本流（《》原样可复制）。
            // 桌面档额外挂 recognizer：单击跳书名搜索（长按让位给选词）。
            spans.add(TextSpan(
              text: '《$name》',
              style: base.copyWith(color: c.bookname, fontWeight: FontWeight.w600),
              recognizer: widget.keepTapWhileSelectable
                  ? _tap(() => widget.onBookTap(name))
                  : null,
            ));
          } else {
            spans.add(WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _BookSpan(
                name: name,
                style: t.bodyRich.copyWith(color: c.bookname, fontWeight: FontWeight.w600),
                onTap: () => widget.onBookTap(name),
                onLongPress: () {
                  Clipboard.setData(ClipboardData(text: name));
                  showAppToast(context, '书名已复制到剪贴板');
                },
              ),
            ));
          }
        case UrlSegment(:final String url):
          spans.add(TextSpan(
            text: url,
            style: base.copyWith(
              color: c.info,
              decoration: TextDecoration.underline,
              decorationColor: c.info,
            ),
            // P1-6 选择模式：链接点击复制暂停（recognizer 不挂载），样式保持视觉连续；
            // 桌面档保留单击复制（拖选仍可用）。
            recognizer: widget.selectable && !widget.keepTapWhileSelectable
                ? null
                : _tap(() {
                    Clipboard.setData(ClipboardData(text: url));
                    showAppToast(context, '链接已复制到剪贴板');
                  }),
          ));
      }
    }
    return Text.rich(TextSpan(style: base, children: spans));
  }
}

/// 《书名》可点 span（MI-3：InkWell 涟漪即时触发，不等待播完）。
class _BookSpan extends StatelessWidget {
  const _BookSpan({required this.name, required this.style, required this.onTap, required this.onLongPress});

  final String name;
  final TextStyle style;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: AppRadius.smBorder,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text('《$name》', style: style),
          ),
        ),
      ),
    );
  }
}

/// 楼层号前缀「● N楼」（§5.6 渲染管线 5）。
class FloorHeader extends StatelessWidget {
  const FloorHeader({super.key, required this.seq});

  final int seq;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    return Padding(
      padding: EdgeInsets.only(top: s.space4, bottom: s.space2),
      child: Row(
        children: <Widget>[
          // 楼层头圆点 = 装饰色块（设计 dot-sep 语汇 index.html:669），非结构图标，不用 Material Icon。
          Container(width: 7, height: 7, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle)),
          SizedBox(width: s.space2),
          Text('$seq楼', style: t.label.copyWith(color: c.textMuted, letterSpacing: 0)),
        ],
      ),
    );
  }
}
