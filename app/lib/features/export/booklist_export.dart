import 'dart:convert';

import '../../data/db/app_database.dart';
import '../../data/repo/queries.dart';

/// 书单导出生成器（原型 §3.1 P2-4「导出书单 Markdown/TXT」· M3）。
///
/// 分层（全部纯 Dart，零 Flutter / 零 IO，可直接 plain test）：
///  1. 文档模型 [BooklistDoc]（书 [ExportBook] / 帖 [ExportPost] 两种粒度）；
///  2. 收集器 [buildFavoritesDoc]（收藏夹 → 经 [BookRepository] 补全作者/渠道/日期/
///     推荐语摘要/排雷计数）与 [buildBookDoc]（书聚合页当前筛选 → 全量推荐明细）；
///  3. 渲染器 [renderMarkdown] / [renderText]：MD 用标题+列表+引用块，TXT 用全角
///     标签对齐的纯文本；两者都含生成时间戳与固定署名行 [kBooklistAttribution]。
///
/// 弹层与平台落盘见 `export_sheet.dart`（本文件不 import Flutter）。

/// 导出格式（弹层分段选择；决定扩展名 / MIME / 走哪个渲染器）。
enum BooklistFormat {
  markdown(label: 'Markdown', extension: 'md', mimeType: 'text/markdown'),
  text(label: 'TXT', extension: 'txt', mimeType: 'text/plain');

  const BooklistFormat({required this.label, required this.extension, required this.mimeType});

  final String label;
  final String extension;
  final String mimeType;
}

/// 文档形态：收藏夹汇总（每书一段摘要）/ 单书推荐明细（该书多条推荐）。
enum BooklistDocKind { favorites, singleBook }

/// 固定署名行（§P2-4 交付口径，两种格式、空/非空文档都必须出现）。
const String kBooklistAttribution = '数据来源：贴吧扫书帖·扫书汇';

/// 空收藏文案（收藏夹为空时仍导出完整文档骨架，不产出空文件假象）。
const String kEmptyFavoritesMessage = '收藏夹还是空的 —— 在书聚合页点右上角星标、帖子详情点「收藏」，再来导出。';

/// 单书推荐明细为空（当前语义筛选筛光）时的占位文案。
const String kEmptyEntriesMessage = '（当前筛选下没有推荐条目）';

/// 摘要截断上限（收藏夹导出的推荐语摘要；字符数）。
const int kSummaryMaxChars = 60;

/// 一条推荐（收藏夹导出 = 单条摘要；单书导出 = 全量明细中的一条）。
class ExportRecommendation {
  const ExportRecommendation({this.recommender, this.date, this.channel, this.comment, this.avoid = false});

  final String? recommender;
  final String? date;
  final String? channel;

  /// 推荐语原文（收藏夹导出为 [summarizeComment] 摘要；null/空 = 该条无推荐语）。
  final String? comment;

  /// 排雷标记（§8.9：recommendFlag < 0）。
  final bool avoid;

  bool get hasComment => (comment ?? '').trim().isNotEmpty;
}

/// 一本书的导出块。
class ExportBook {
  const ExportBook({
    required this.title,
    this.author,
    this.channels = const <String>[],
    this.dateRange,
    this.entryCount = 0,
    this.avoidCount = 0,
    this.recommendations = const <ExportRecommendation>[],
  });

  /// 书名（不带《》；渲染器负责套书名号）。
  final String title;
  final String? author;
  final List<String> channels;

  /// 数据日期跨度（`2024-12-05 ~ 2025-04-28`；单日无跨度时为单个日期）。
  final String? dateRange;

  /// 全库推荐总条数（收藏夹导出用；单书导出 = 当前筛选条数）。
  final int entryCount;

  /// 排雷条数（>0 时渲染「排雷标记」行）。
  final int avoidCount;
  final List<ExportRecommendation> recommendations;
}

/// 一条帖子粒度收藏（收藏夹双粒度的另一半，§5.10）。
class ExportPost {
  const ExportPost({required this.title, this.author, this.channel, this.date, this.avoid = false});

  final String title;
  final String? author;
  final String? channel;
  final String? date;
  final bool avoid;
}

/// 导出文档（渲染器唯一输入）。
class BooklistDoc {
  const BooklistDoc({
    required this.kind,
    required this.heading,
    required this.generatedAt,
    this.books = const <ExportBook>[],
    this.posts = const <ExportPost>[],
  });

  final BooklistDocKind kind;

  /// 文档主标题（收藏夹 =「我的收藏书单」；单书 =「《书名》推荐单」）。
  final String heading;
  final DateTime generatedAt;
  final List<ExportBook> books;
  final List<ExportPost> posts;

  bool get isEmpty => books.isEmpty && posts.isEmpty;

  /// 头部元信息行（时间戳 + 计数；两种渲染器共用同一口径）。
  String get metaLine {
    final List<String> parts = <String>['生成时间: ${formatStamp(generatedAt)}'];
    switch (kind) {
      case BooklistDocKind.favorites:
        if (books.isNotEmpty) {
          parts.add('共 ${books.length} 本书');
        }
        if (posts.isNotEmpty) {
          parts.add('共 ${posts.length} 帖');
        }
      case BooklistDocKind.singleBook:
        parts.add(_countsPhrase(books.isEmpty ? const ExportBook(title: '') : books.first));
    }
    return parts.join(' · ');
  }
}

/// `2026-10-13 12:00` 时间戳（文档头 + 文件名共用两段式口径）。
String formatStamp(DateTime t) =>
    '${t.year}-${_two(t.month)}-${_two(t.day)} ${_two(t.hour)}:${_two(t.minute)}';

/// 导出文件名：`booksift_booklist_20261013_120000.md`（纯 ASCII，跨平台无转义坑，
/// 与 share_service.defaultShareFileName 同族）。
String defaultBooklistFileName(BooklistFormat format, {DateTime? now}) {
  final DateTime t = now ?? DateTime.now();
  return 'booksift_booklist_${t.year}${_two(t.month)}${_two(t.day)}'
      '_${_two(t.hour)}${_two(t.minute)}${_two(t.second)}.${format.extension}';
}

/// 推荐语摘要：换行/连续空白压平成单空格，超过 [maxChars] 截断加「…」。
/// null/空白 → null（渲染器落到「暂无推荐语」占位，不造假）。
String? summarizeComment(String? comment, {int maxChars = kSummaryMaxChars}) {
  final String flat = (comment ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.isEmpty) {
    return null;
  }
  return flat.length > maxChars ? '${flat.substring(0, maxChars)}…' : flat;
}

/// 按格式分派渲染器。
String renderBooklist(BooklistDoc doc, BooklistFormat format) => switch (format) {
      BooklistFormat.markdown => renderMarkdown(doc),
      BooklistFormat.text => renderText(doc),
    };

// ───────────────────────── Markdown 渲染 ─────────────────────────

/// Markdown：标题 + 列表 + 引用块（`#` 文档头 / `##` 分区 / `###` 每书或每条推荐）。
String renderMarkdown(BooklistDoc doc) {
  final StringBuffer b = StringBuffer();
  b
    ..writeln('# ${doc.heading}')
    ..writeln()
    ..writeln('> ${doc.metaLine}')
    ..writeln();
  if (doc.isEmpty) {
    b
      ..writeln(kEmptyFavoritesMessage)
      ..writeln();
  } else {
    switch (doc.kind) {
      case BooklistDocKind.favorites:
        _mdFavorites(b, doc);
      case BooklistDocKind.singleBook:
        _mdSingleBook(b, doc);
    }
  }
  b
    ..writeln('---')
    ..writeln()
    ..writeln(kBooklistAttribution);
  return b.toString();
}

void _mdFavorites(StringBuffer b, BooklistDoc doc) {
  if (doc.books.isNotEmpty) {
    b
      ..writeln('## 书籍')
      ..writeln();
    for (final ExportBook book in doc.books) {
      final ExportRecommendation? rec =
          book.recommendations.isEmpty ? null : book.recommendations.first;
      b.writeln('### 《${book.title}》');
      _mdLine(b, '作者', book.author);
      _mdLine(b, '推荐人', rec?.recommender);
      if (book.channels.isNotEmpty) {
        _mdLine(b, '渠道', book.channels.join(' / '));
      }
      final List<String> dateParts = <String>[
        if (book.dateRange != null) book.dateRange!,
        if (book.entryCount > 0) '共 ${book.entryCount} 条推荐',
      ];
      if (dateParts.isNotEmpty) {
        _mdLine(b, '日期', dateParts.join(' · '));
      }
      if (book.avoidCount > 0) {
        _mdLine(b, '⚠ 排雷标记', '含 ${book.avoidCount} 条排雷提示');
      }
      if (rec != null && rec.hasComment) {
        b
          ..writeln()
          ..writeln(_mdQuote(rec.comment!));
      } else {
        _mdLine(b, '推荐语摘要', '（暂无推荐语）');
      }
      b.writeln();
    }
  }
  if (doc.posts.isNotEmpty) {
    b
      ..writeln('## 帖子')
      ..writeln();
    for (final ExportPost p in doc.posts) {
      final List<String> tail = <String>[
        if ((p.author ?? '').isNotEmpty) p.author!,
        if ((p.channel ?? '').isNotEmpty) p.channel!,
        if ((p.date ?? '').isNotEmpty) p.date!,
        if (p.avoid) '⚠ 排雷',
      ];
      b.writeln('- 「${p.title}」${tail.isEmpty ? '' : ' · ${tail.join(' · ')}'}');
    }
    b.writeln();
  }
}

void _mdSingleBook(StringBuffer b, BooklistDoc doc) {
  if (doc.books.isEmpty) {
    return;
  }
  final ExportBook book = doc.books.first;
  b
    ..writeln('## 书目信息')
    ..writeln();
  _mdLine(b, '作者', book.author);
  if (book.channels.isNotEmpty) {
    _mdLine(b, '渠道', book.channels.join(' / '));
  }
  _mdLine(b, '日期', book.dateRange);
  _mdLine(b, '统计', _countsPhrase(book));
  b
    ..writeln()
    ..writeln('## 推荐明细')
    ..writeln();
  if (book.recommendations.isEmpty) {
    b
      ..writeln(kEmptyEntriesMessage)
      ..writeln();
    return;
  }
  for (int i = 0; i < book.recommendations.length; i++) {
    final ExportRecommendation rec = book.recommendations[i];
    final String label = rec.avoid ? '⚠ 排雷 ${i + 1}' : '推荐 ${i + 1}';
    final String tail = _recTail(rec);
    b
      ..writeln('### $label${tail.isEmpty ? '' : ' · $tail'}')
      ..writeln()
      ..writeln(_mdQuote(rec.hasComment ? rec.comment!.trim() : '（该条无推荐语）'))
      ..writeln();
  }
}

void _mdLine(StringBuffer b, String label, String? value) {
  if ((value ?? '').trim().isNotEmpty) {
    b.writeln('- $label: ${value!.trim()}');
  }
}

/// 引用块：多行评论每行前缀 `> `（空行只留 `>`）。
String _mdQuote(String comment) => comment
    .trim()
    .split('\n')
    .map((String line) => line.isEmpty ? '>' : '> ${line.trimRight()}')
    .join('\n');

// ───────────────────────── TXT 渲染 ─────────────────────────

/// TXT 分隔线（重线 = 文档头，细线 = 署名脚）。
const String _ruleHeavy = '════════════════════════════════════════';
const String _ruleLight = '────────────────────────────────────────';

// 全角空格填充到 3 字宽，冒号后单空格 → 值列天然对齐（等宽字体下严格对齐）。
const String _lblAuthor = '作\u3000者';
const String _lblRecommender = '推荐人';
const String _lblChannel = '渠\u3000道';
const String _lblDate = '日\u3000期';
const String _lblAvoid = '排\u3000雷';
const String _lblSummary = '摘\u3000要';
const String _lblStats = '统\u3000计';

/// TXT：全角标签对齐的纯文本（书籍/帖子/明细三段 + 头尾分隔线）。
String renderText(BooklistDoc doc) {
  final StringBuffer b = StringBuffer();
  b
    ..writeln(doc.heading)
    ..writeln(doc.metaLine)
    ..writeln(_ruleHeavy)
    ..writeln();
  if (doc.isEmpty) {
    b
      ..writeln(kEmptyFavoritesMessage)
      ..writeln();
  } else {
    switch (doc.kind) {
      case BooklistDocKind.favorites:
        _txtFavorites(b, doc);
      case BooklistDocKind.singleBook:
        _txtSingleBook(b, doc);
    }
  }
  b
    ..writeln(_ruleLight)
    ..writeln(kBooklistAttribution);
  return b.toString();
}

void _txtFavorites(StringBuffer b, BooklistDoc doc) {
  if (doc.books.isNotEmpty) {
    b
      ..writeln('【书籍】')
      ..writeln();
    for (final ExportBook book in doc.books) {
      final ExportRecommendation? rec =
          book.recommendations.isEmpty ? null : book.recommendations.first;
      b.writeln('《${book.title}》');
      _txtField(b, _lblAuthor, book.author);
      _txtField(b, _lblRecommender, rec?.recommender);
      if (book.channels.isNotEmpty) {
        _txtField(b, _lblChannel, book.channels.join(' / '));
      }
      final List<String> dateParts = <String>[
        if (book.dateRange != null) book.dateRange!,
        if (book.entryCount > 0) '共 ${book.entryCount} 条推荐',
      ];
      if (dateParts.isNotEmpty) {
        _txtField(b, _lblDate, dateParts.join('（') + (dateParts.length == 2 ? '）' : ''));
      }
      if (book.avoidCount > 0) {
        _txtField(b, _lblAvoid, '含 ${book.avoidCount} 条排雷提示');
      }
      _txtField(b, _lblSummary, rec != null && rec.hasComment ? '「${_flatten(rec.comment!)}」' : '（暂无推荐语）');
      b.writeln();
    }
  }
  if (doc.posts.isNotEmpty) {
    b
      ..writeln('【帖子】')
      ..writeln();
    for (final ExportPost p in doc.posts) {
      final List<String> tail = <String>[
        if ((p.author ?? '').isNotEmpty) '发帖人: ${p.author!}',
        if ((p.channel ?? '').isNotEmpty) '渠道: ${p.channel!}',
        if ((p.date ?? '').isNotEmpty) '日期: ${p.date!}',
        if (p.avoid) '⚠ 排雷',
      ];
      b
        ..writeln('「${p.title}」')
        ..writeln(tail.isEmpty ? '' : '      ${tail.join(' · ')}')
        ..writeln();
    }
  }
}

void _txtSingleBook(StringBuffer b, BooklistDoc doc) {
  if (doc.books.isEmpty) {
    return;
  }
  final ExportBook book = doc.books.first;
  b
    ..writeln('【书目信息】')
    ..writeln();
  _txtField(b, _lblAuthor, book.author);
  if (book.channels.isNotEmpty) {
    _txtField(b, _lblChannel, book.channels.join(' / '));
  }
  _txtField(b, _lblDate, book.dateRange);
  _txtField(b, _lblStats, _countsPhrase(book));
  b
    ..writeln()
    ..writeln('【推荐明细】')
    ..writeln();
  if (book.recommendations.isEmpty) {
    b
      ..writeln(kEmptyEntriesMessage)
      ..writeln();
    return;
  }
  for (int i = 0; i < book.recommendations.length; i++) {
    final ExportRecommendation rec = book.recommendations[i];
    final String label = rec.avoid ? '⚠ 排雷 ${i + 1}' : '推荐 ${i + 1}';
    final String tail = _recTail(rec);
    b.writeln('  [$label]${tail.isEmpty ? '' : ' $tail'}');
    if (rec.hasComment) {
      final List<String> lines = rec.comment!.trim().split('\n');
      for (final String line in lines) {
        b.writeln('      ${line.trim()}');
      }
    } else {
      b.writeln('      （该条无推荐语）');
    }
  }
  b.writeln();
}

void _txtField(StringBuffer b, String label, String? value) {
  if ((value ?? '').trim().isNotEmpty) {
    b.writeln('  $label: ${value!.trim()}');
  }
}

// ───────────────────────── 收集器 ─────────────────────────

/// 收藏夹 → 导出文档（§5.10 双粒度）：
///  - 书粒度（book_group）：经 [BookRepository.bookDetail] / [bookEntries] 补全
///    作者、渠道、日期跨度、排雷计数与最佳推荐语摘要；
///  - 帖粒度（post）：经 [postDetail] 取发帖人/渠道/日期与排雷语义；
///  - 书目已被移除（bookDetail 为 null）：退化为 title/subtitle 两字段，不静默丢行。
Future<BooklistDoc> buildFavoritesDoc({
  required BookRepository repo,
  required List<Favorite> favorites,
  DateTime? now,
}) async {
  final List<ExportBook> books = <ExportBook>[];
  final List<ExportPost> posts = <ExportPost>[];
  for (final Favorite f in favorites) {
    if (f.targetType == FavoriteTarget.bookGroup) {
      books.add(await _bookFromFavorite(repo, f));
    } else {
      posts.add(await _postFromFavorite(repo, f));
    }
  }
  return BooklistDoc(
    kind: BooklistDocKind.favorites,
    heading: '我的收藏书单',
    generatedAt: now ?? DateTime.now(),
    books: books,
    posts: posts,
  );
}

/// 书聚合页 → 单书导出文档（该书多条推荐；[entries] 用页面当前筛选/排序结果，
/// 与 ⋮「导出该书推荐」分享口径一致）。
BooklistDoc buildBookDoc({
  required BookDetailData data,
  required List<EntryRow> entries,
  DateTime? now,
}) {
  final BookGroup g = data.group;
  return BooklistDoc(
    kind: BooklistDocKind.singleBook,
    heading: '《${g.nameDisplay ?? g.nameNorm}》推荐单',
    generatedAt: now ?? DateTime.now(),
    books: <ExportBook>[
      ExportBook(
        title: g.nameDisplay ?? g.nameNorm,
        author: g.authorDisplay,
        channels: parseChannels(g.channels),
        dateRange: _rangeOf(g.dateMin, g.dateMax),
        entryCount: entries.length,
        avoidCount: entries.where((EntryRow e) => e.recommendFlag < 0).length,
        recommendations: <ExportRecommendation>[
          for (final EntryRow e in entries)
            ExportRecommendation(
              recommender: e.recommender,
              date: e.date,
              channel: e.channel,
              comment: e.comment,
              avoid: e.recommendFlag < 0,
            ),
        ],
      ),
    ],
  );
}

Future<ExportBook> _bookFromFavorite(BookRepository repo, Favorite f) async {
  final BookDetailData? detail = await repo.bookDetail(f.targetId);
  final BookGroup? g = detail?.group;
  List<EntryRow> entries = const <EntryRow>[];
  if (g != null) {
    entries = await repo.bookEntries(g.id, SemanticFilter.all);
  }
  final EntryRow? best = _bestComment(entries);
  final String? summary = summarizeComment(best?.comment);
  return ExportBook(
    title: stripBookMarks(f.title),
    author: (g?.authorDisplay ?? '').isNotEmpty ? g!.authorDisplay : f.subtitle,
    channels: parseChannels(g?.channels),
    dateRange: _rangeOf(g?.dateMin, g?.dateMax),
    entryCount: g?.entryTotal ?? entries.length,
    avoidCount: detail?.avoidCount ?? 0,
    recommendations: best == null
        ? const <ExportRecommendation>[]
        : <ExportRecommendation>[
            ExportRecommendation(
              recommender: best.recommender,
              date: best.date,
              channel: best.channel,
              comment: summary,
              avoid: best.recommendFlag < 0,
            ),
          ],
  );
}

Future<ExportPost> _postFromFavorite(BookRepository repo, Favorite f) async {
  final PostDetailData? detail = await repo.postDetail(f.targetId);
  final Post? post = detail?.post;
  return ExportPost(
    title: f.title,
    author: post?.author ?? f.subtitle,
    channel: post?.channel,
    date: post?.date,
    avoid: post != null && (post.postKind == CategoryKind.avoid || post.recommendFlag < 0),
  );
}

/// 摘要取条：quality 降序（bookEntries 默认排序）里第一条有推荐语的；全无 → 首条。
EntryRow? _bestComment(List<EntryRow> entries) {
  if (entries.isEmpty) {
    return null;
  }
  for (final EntryRow e in entries) {
    if ((e.comment ?? '').trim().isNotEmpty) {
      return e;
    }
  }
  return entries.first;
}

/// 去掉收藏标题两侧书名号（favorites.title 存的是 `《书名》`）。
String stripBookMarks(String title) {
  final String t = title.trim();
  if (t.length >= 2 && t.startsWith('《') && t.endsWith('》')) {
    return t.substring(1, t.length - 1);
  }
  return t;
}

/// 渠道 JSON 数组解析（与 book_detail_page 同口径：JSON 失败退化逗号分隔）。
List<String> parseChannels(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const <String>[];
  }
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded.whereType<String>().where((String e) => e.isNotEmpty).toList();
    }
  } on FormatException {
    // 落到逗号分隔兜底。
  }
  return raw.split(',').map((String e) => e.trim()).where((String e) => e.isNotEmpty).toList();
}

String? _rangeOf(String? min, String? max) {
  if ((min ?? '').isEmpty && (max ?? '').isEmpty) {
    return null;
  }
  if ((min ?? '').isEmpty) {
    return max;
  }
  if ((max ?? '').isEmpty || min == max) {
    return min;
  }
  return '$min ~ $max';
}

/// `共 2 条 · 推荐 1 · 排雷 1`（单书文档的计数口径：跟随当前筛选）。
String _countsPhrase(ExportBook book) {
  final int avoid = book.recommendations.where((ExportRecommendation r) => r.avoid).length;
  final int total = book.recommendations.length;
  return '共 $total 条 · 推荐 ${total - avoid} · 排雷 $avoid';
}

String _recTail(ExportRecommendation rec) => <String>[
      if ((rec.recommender ?? '').trim().isNotEmpty) rec.recommender!.trim(),
      if ((rec.date ?? '').trim().isNotEmpty) rec.date!.trim(),
      if ((rec.channel ?? '').trim().isNotEmpty) rec.channel!.trim(),
    ].join(' · ');

String _flatten(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

String _two(int v) => v.toString().padLeft(2, '0');
