import 'dart:typed_data';

import '../core/constants.dart';
import '../data/repo/queries.dart';

class ContentImageDraft {
  const ContentImageDraft({
    this.id,
    required this.url,
    this.width = 0,
    this.height = 0,
  });

  final int? id;
  final String url;
  final int width;
  final int height;

  bool get embedded => url.startsWith('data:image/');
}

class ContentFloorDraft {
  const ContentFloorDraft({
    this.id,
    required this.text,
    this.images = const <ContentImageDraft>[],
  });

  final int? id;
  final String text;
  final List<ContentImageDraft> images;
}

class ContentEntryDraft {
  const ContentEntryDraft({
    this.id,
    required this.name,
    this.author = '',
    required this.comment,
    this.floorIndex = 0,
    this.category = CategoryKind.scan,
    this.recommender = '',
    this.channel = '',
    this.date = '',
    this.sourceUrl = '',
    this.wordCount,
    this.bookGrade,
  });

  final int? id;
  final String name;
  final String author;
  final String comment;
  final int floorIndex;
  final String category;
  final String recommender;
  final String channel;
  final String date;
  final String sourceUrl;
  final int? wordCount;
  final String? bookGrade;

  ContentEntryDraft copyWith({
    String? recommender,
    String? channel,
    String? date,
    String? sourceUrl,
  }) => ContentEntryDraft(
    id: id,
    name: name,
    author: author,
    comment: comment,
    floorIndex: floorIndex,
    category: category,
    recommender: recommender ?? this.recommender,
    channel: channel ?? this.channel,
    date: date ?? this.date,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    wordCount: wordCount,
    bookGrade: bookGrade,
  );
}

class ContentDraft {
  const ContentDraft({
    this.postId,
    this.baseline,
    this.title = '',
    this.author = '',
    this.channel = '手动导入',
    this.subChannel = '',
    this.date = '',
    this.category = CategoryKind.scan,
    this.sourceUrl = '',
    this.origin = Origin.imported,
    this.floors = const <ContentFloorDraft>[],
    this.entries = const <ContentEntryDraft>[],
    this.rawDocument,
    this.fileName,
    this.mediaType = 'text/plain',
    this.warnings = const <String>[],
  });

  final int? postId;
  final String? baseline;
  final String title;
  final String author;
  final String channel;
  final String subChannel;
  final String date;
  final String category;
  final String sourceUrl;
  final String origin;
  final List<ContentFloorDraft> floors;
  final List<ContentEntryDraft> entries;
  final Uint8List? rawDocument;
  final String? fileName;
  final String mediaType;
  final List<String> warnings;

  int get imageCount => floors.fold<int>(
    0,
    (int count, ContentFloorDraft floor) => count + floor.images.length,
  );

  ContentDraft copyWith({
    String? title,
    String? author,
    String? channel,
    String? subChannel,
    String? date,
    String? category,
    String? sourceUrl,
    List<ContentFloorDraft>? floors,
    List<ContentEntryDraft>? entries,
    List<String>? warnings,
  }) => ContentDraft(
    postId: postId,
    baseline: baseline,
    title: title ?? this.title,
    author: author ?? this.author,
    channel: channel ?? this.channel,
    subChannel: subChannel ?? this.subChannel,
    date: date ?? this.date,
    category: category ?? this.category,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    origin: origin,
    floors: floors ?? this.floors,
    entries: entries ?? this.entries,
    rawDocument: rawDocument,
    fileName: fileName,
    mediaType: mediaType,
    warnings: warnings ?? this.warnings,
  );
}

class ContentSaveResult {
  const ContentSaveResult({
    required this.postId,
    required this.entryCount,
    this.alreadyImported = false,
  });

  final int postId;
  final int entryCount;
  final bool alreadyImported;
}

class ContentEditException implements Exception {
  const ContentEditException(this.message);

  final String message;

  @override
  String toString() => message;
}

String contentDate(DateTime time) {
  final DateTime beijing = time.toUtc().add(const Duration(hours: 8));
  return '${beijing.year.toString().padLeft(4, '0')}-${beijing.month.toString().padLeft(2, '0')}-${beijing.day.toString().padLeft(2, '0')}';
}

bool validContentDate(String value) {
  if (value.isEmpty) return true;
  final RegExpMatch? match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})$',
  ).firstMatch(value);
  if (match == null) return false;
  final int year = int.parse(match[1]!);
  final int month = int.parse(match[2]!);
  final int day = int.parse(match[3]!);
  final DateTime parsed = DateTime(year, month, day);
  return year >= 1 &&
      parsed.year == year &&
      parsed.month == month &&
      parsed.day == day;
}

bool validContentUrl(String value, {bool image = false}) {
  if (value.isEmpty) return true;
  if (image && value.startsWith('data:image/')) {
    try {
      return UriData.parse(value).contentAsBytes().isNotEmpty;
    } on FormatException {
      return false;
    }
  }
  final Uri? uri = Uri.tryParse(value);
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
}
