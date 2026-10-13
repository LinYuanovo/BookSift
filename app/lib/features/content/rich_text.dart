import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

// 楼层富文本渲染管线（§5.6，Dart 等价实现逆向报告 §2.4 规则）：
// 1) 《书名》→ 红色加粗可点（点击=以书名发起全库搜索，长按=复制书名，MI-3）；
// 2) URL → info 色下划线可点（点击=复制 + Toast「链接已复制到剪贴板」，§5.6 渲染管线 2）；
// 3) 搜索词 → 琥珀高亮逐词 IGNORE_CASE 着色（§5.6 渲染管线 4）；
// 4) 楼层前缀 ● N楼 与内联图片由 content_detail_page 组装。

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

/// 楼层正文（Text.rich + WidgetSpan；书名/链接可点，搜索词琥珀高亮）。
class FloorRichText extends StatefulWidget {
  const FloorRichText({
    super.key,
    required this.text,
    required this.onBookTap,
    this.highlightWords = const <String>[],
  });

  final String text;

  /// 点击《书名》= 以书名发起新搜索（§5.6 核心交互闭环）。
  final ValueChanged<String> onBookTap;
  final List<String> highlightWords;

  @override
  State<FloorRichText> createState() => _FloorRichTextState();
}

class _FloorRichTextState extends State<FloorRichText> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

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

  /// 纯文本段内按搜索词逐词 IGNORE_CASE 高亮。
  List<TextSpan> _highlighted(String text, TextStyle base) {
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

    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final TextStyle base = t.bodyRich.copyWith(color: c.text);
    final List<InlineSpan> spans = <InlineSpan>[];
    for (final FloorSegment seg in parseFloorSegments(widget.text)) {
      switch (seg) {
        case PlainSegment(:final String text):
          spans.addAll(_highlighted(text, base));
        case BookSegment(:final String name):
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _BookSpan(
              name: name,
              style: t.bodyRich.copyWith(color: c.bookname, fontWeight: FontWeight.w600),
              onTap: () => widget.onBookTap(name),
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: name));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('书名已复制到剪贴板')));
              },
            ),
          ));
        case UrlSegment(:final String url):
          spans.add(TextSpan(
            text: url,
            style: base.copyWith(
              color: c.info,
              decoration: TextDecoration.underline,
              decorationColor: c.info,
            ),
            recognizer: _tap(() {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('链接已复制到剪贴板')));
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
          Icon(Icons.circle, size: 7, color: c.accent),
          SizedBox(width: s.space2),
          Text('$seq楼', style: t.label.copyWith(color: c.textMuted, letterSpacing: 0)),
        ],
      ),
    );
  }
}
