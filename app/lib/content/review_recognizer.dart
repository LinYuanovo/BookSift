import '../classify/src/engine.dart' show explicitManualKind, kRecommendKind;
import '../collector/normalization.dart';
import '../data/repo/queries.dart';
import 'content_draft.dart';
import 'novel_word_count.dart';

class ReviewRecognizer {
  const ReviewRecognizer();

  List<ContentEntryDraft> recognize(ContentDraft draft) {
    final StringBuffer combined = StringBuffer();
    final List<int> floorStarts = <int>[];
    for (final ContentFloorDraft floor in draft.floors) {
      floorStarts.add(combined.length);
      combined.write(floor.text);
      combined.write('\n\n');
    }
    final String text = combined.toString();
    final List<_BookAnchor> anchors = <_BookAnchor>[];
    final List<({int start, int end})> relatedRanges =
        <({int start, int end})>[];
    final RegExp relatedHeading = RegExp(
      r'^\s*(?:相关推荐|相关小说推荐|同作者强相关|近期[^\n]{0,30}强相关)[：:]?[^\n]*',
      multiLine: true,
    );
    final RegExp sectionHeading = RegExp(
      r'^\s*(?:点评|内容评价|剧情介绍|内容介绍|基本评价|评分细则|观前提醒|本书简介|女主|女配)\s*$',
      multiLine: true,
    );
    for (final RegExpMatch heading in relatedHeading.allMatches(text)) {
      final RegExpMatch? nextSection = sectionHeading.firstMatch(
        text.substring(heading.end),
      );
      relatedRanges.add((
        start: heading.start,
        end: nextSection == null
            ? text.length
            : heading.end + nextSection.start,
      ));
    }
    bool related(int offset) => relatedRanges.any(
      (({int start, int end}) range) =>
          offset >= range.start && offset < range.end,
    );
    final RegExp named = RegExp(
      r'^\s*(?:#{1,6}\s*|\d+[.、．)）]\s*)?(?:书\s*名|作品(?:名称)?|小说名|Title|本书|扫书|推书|书评)\s*[:：]\s*[《〈「『]?([^\n\r》〉」』]+)',
      caseSensitive: false,
      multiLine: true,
    );
    final RegExp wrapped = RegExp(r'《([^《》\n\r]{1,100})》');
    for (final RegExpMatch match in named.allMatches(text)) {
      final String name = match[1]!
          .split(
            RegExp(r'\s+(?:作者|作\s*者|by|Author)\s*[:：]?', caseSensitive: false),
          )
          .first
          .trim();
      if (_validName(name) && !related(match.start)) {
        anchors.add(_BookAnchor(name, match.start, match.end, true));
      }
    }
    for (final RegExpMatch match in wrapped.allMatches(text)) {
      final String name = match[1]!.trim();
      if (!_validName(name) ||
          related(match.start) ||
          anchors.any(
            (_BookAnchor anchor) =>
                anchor.start <= match.start && anchor.end >= match.end,
          )) {
        continue;
      }
      final int lineStart = match.start == 0
          ? 0
          : text.lastIndexOf('\n', match.start - 1) + 1;
      final String prefix = text
          .substring(lineStart, match.start)
          .replaceAll(RegExp(r'[\s#*\d、.．:：\-—【】（）()\[\]]'), '');
      if (prefix.contains('原名') ||
          prefix.contains('又名') ||
          prefix.contains('别名')) {
        continue;
      }
      final bool heading =
          prefix.isEmpty ||
          const <String>{
            '书名',
            '推荐',
            '推书',
            '排雷',
            '书评',
            '扫书',
            '小说',
            '作品',
          }.contains(prefix);
      anchors.add(_BookAnchor(name, match.start, match.end, heading));
    }
    final RegExp byline = RegExp(
      r'^\s*(?:#{1,6}\s*|\d+[.、．)）]\s*)?([^\n\r《》:：]{1,100}?)\s+(?:by\s+|作者\s*[:：]\s*)([^\n\r]+)',
      multiLine: true,
      caseSensitive: false,
    );
    for (final RegExpMatch match in byline.allMatches(text)) {
      final String name = match[1]!.replaceAll('**', '').trim();
      if (_validName(name) &&
          !related(match.start) &&
          !anchors.any(
            (_BookAnchor anchor) =>
                anchor.start >= match.start && anchor.start < match.end,
          )) {
        anchors.add(_BookAnchor(name, match.start, match.end, true));
      }
    }
    anchors.sort(
      (_BookAnchor first, _BookAnchor second) =>
          first.start.compareTo(second.start),
    );
    final List<_BookAnchor> headings = anchors
        .where((_BookAnchor anchor) => anchor.heading)
        .toList();
    final List<_BookAnchor> candidates = headings.isNotEmpty
        ? headings
        : anchors;
    final List<_BookAnchor> selected = <_BookAnchor>[];
    final Set<String> seen = <String>{};
    for (final _BookAnchor anchor in candidates) {
      if (seen.add(normName(anchor.name))) selected.add(anchor);
    }
    return <ContentEntryDraft>[
      for (int index = 0; index < selected.length; index++)
        _entry(draft, text, floorStarts, selected, index),
    ];
  }

  ContentEntryDraft _entry(
    ContentDraft draft,
    String text,
    List<int> floorStarts,
    List<_BookAnchor> anchors,
    int index,
  ) {
    final _BookAnchor anchor = anchors[index];
    final int lineStart = anchor.start == 0
        ? 0
        : text.lastIndexOf('\n', anchor.start - 1) + 1;
    final int start = index == 0
        ? 0
        : lineStart <= anchors[index - 1].end
        ? anchor.start
        : lineStart;
    final int nextStart = index + 1 < anchors.length
        ? text.lastIndexOf('\n', anchors[index + 1].start - 1) + 1
        : text.length;
    final int end = nextStart <= anchor.end && index + 1 < anchors.length
        ? anchors[index + 1].start
        : nextStart;
    final String comment = text
        .substring(start, end < start ? text.length : end)
        .trim();
    final int nextAnchor = index + 1 < anchors.length
        ? anchors[index + 1].start
        : text.length;
    final String authorArea = text.substring(
      anchor.start,
      (anchor.end + 700).clamp(anchor.start, nextAnchor),
    );
    final RegExp authorPattern = RegExp(
      r'(?:作\s*者|小说作者|原著|Author|\bby)\s*[:：]?\s*([^\s，。；、《》|｜（）()\[\]【】]{1,60})',
      caseSensitive: false,
    );
    String author = authorPattern.firstMatch(authorArea)?[1] ?? '';
    if (author.isEmpty) {
      final RegExpMatch? byline = RegExp(
        r'》\s*[/／|｜\-—]\s*([^\s，。；:：]{1,40})(?:\s*著)?',
      ).firstMatch(authorArea);
      author = byline?[1] ?? '';
    }
    final String intent = comment.split('\n').take(3).join('\n');
    final String metadataIntent = text.substring(
      anchor.start,
      (anchor.end + 1000).clamp(anchor.start, nextAnchor),
    );
    final String category =
        explicitManualKind(intent) ??
        (RegExp(
              r'^(?:\s|[#*\d、.．])*?(?:排雷|避雷|不推荐)\s*[:：]',
              multiLine: true,
            ).hasMatch(intent)
            ? CategoryKind.avoid
            : RegExp(r'推荐(?:等级|程度)\s*[:：]\s*(?:强推|推荐)').hasMatch(metadataIntent)
            ? kRecommendKind
            : draft.category);
    final int? wordCount = extractNovelWordCount(comment, bookName: anchor.name);
    int floorIndex = 0;
    for (int position = 0; position < floorStarts.length; position++) {
      if (floorStarts[position] <= anchor.start) floorIndex = position;
    }
    return ContentEntryDraft(
      name: anchor.name,
      author: normPerson(author).isEmpty ? '' : author,
      comment: comment,
      floorIndex: floorIndex,
      category: category,
      recommender: draft.author,
      channel: draft.channel,
      date: draft.date,
      sourceUrl: draft.sourceUrl,
      wordCount: wordCount,
      bookGrade: category == kRecommendKind
          ? '#11850A'
          : category == CategoryKind.avoid
          ? '#FF0000'
          : null,
    );
  }

  bool _validName(String name) =>
      name.isNotEmpty &&
      name.runes.length <= 100 &&
      normName(name).isNotEmpty &&
      !const <String>{'书名', '作者', '小说', '作品', '未知', '不详'}.contains(name);
}

class _BookAnchor {
  const _BookAnchor(this.name, this.start, this.end, this.heading);

  final String name;
  final int start;
  final int end;
  final bool heading;
}
