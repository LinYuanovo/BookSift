import '../collector/normalization.dart' show normName;

int? extractNovelWordCount(String text, {String? bookName}) {
  String area = text;
  if (bookName != null) {
    final List<RegExpMatch> titles = RegExp(r'《([^《》\n]{1,100})》').allMatches(text).toList();
    final String normalized = normName(bookName);
    final int selected = titles.indexWhere((match) => normName(match[1]!) == normalized);
    if (selected >= 0) {
      final RegExpMatch anchor = titles[selected];
      int end = text.length;
      for (final RegExpMatch next in titles.skip(selected + 1)) {
        if (normName(next[1]!) != normalized) {
          end = next.start;
          break;
        }
      }
      area = text.substring(anchor.start, end);
    } else if (titles.isNotEmpty) {
      return null;
    }
  }
  area = String.fromCharCodes(area.runes.map((rune) =>
      rune >= 0xff01 && rune <= 0xff5e ? rune - 0xfee0 : rune));
  final RegExp pattern = RegExp(
    r'(?:作品|本书|小说|全书|总)?(?:字数|字數|篇幅)(?:/章节)?\s*[:：=]?\s*(\d[\d,]*(?:\.\d+)?)\s*(百万|千万|亿|万|千|[wWkK])?\s*(?:字)?',
  );
  for (final RegExpMatch match in pattern.allMatches(area)) {
    final String prefix = area.substring((match.start - 6).clamp(0, area.length), match.start);
    if (RegExp(r'(?:书评|评论|评语|本章|单章|章节)\s*$').hasMatch(prefix)) continue;
    String number = match[1]!;
    if (number.contains(',')) {
      if (RegExp(r'^\d{1,3}(?:,\d{3})+$').hasMatch(number)) {
        number = number.replaceAll(',', '');
      } else if (RegExp(r'^\d+,\d{1,2}$').hasMatch(number) && match[2] != null) {
        number = number.replaceAll(',', '.');
      } else {
        continue;
      }
    }
    final double? amount = double.tryParse(number);
    if (amount == null) continue;
    final int multiplier = switch (match[2]) {
      '亿' => 100000000,
      '千万' => 10000000,
      '百万' => 1000000,
      '万' || 'w' || 'W' => 10000,
      '千' || 'k' || 'K' => 1000,
      _ => 1,
    };
    final int count = (amount * multiplier).round();
    if (count > 0 && count <= 1000000000) return count;
  }
  return null;
}
