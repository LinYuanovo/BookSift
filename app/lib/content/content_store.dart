import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../classify/src/engine.dart' show kRecommendKind;
import '../collector/normalization.dart';
import '../core/constants.dart';
import '../data/db/app_database.dart';
import '../data/db/fts_schema.dart';
import '../data/repo/queries.dart';
import 'content_draft.dart';
import 'document_reader.dart';

class ContentStore {
  ContentStore(this.db);

  final AppDatabase db;

  Future<ContentDraft?> load(int postId) => db.transaction(() async {
    final Post? post = await (db.select(
      db.posts,
    )..where((Posts table) => table.id.equals(postId))).getSingleOrNull();
    if (post == null) return null;
    final List<Floor> floors =
        await (db.select(db.floors)
              ..where((Floors table) => table.postId.equals(postId))
              ..orderBy(<OrderingTerm Function(Floors)>[
                (Floors table) => OrderingTerm.asc(table.seq),
                (Floors table) => OrderingTerm.asc(table.id),
              ]))
            .get();
    final List<FloorImage> images = floors.isEmpty
        ? <FloorImage>[]
        : await (db.select(db.images)
                ..where(
                  (Images table) =>
                      table.floorId.isIn(floors.map((Floor floor) => floor.id)),
                )
                ..orderBy(<OrderingTerm Function(Images)>[
                  (Images table) => OrderingTerm.asc(table.id),
                ]))
              .get();
    final List<BookEntry> entries =
        await (db.select(db.bookEntries)
              ..where((BookEntries table) => table.postRef.equals(postId))
              ..orderBy(<OrderingTerm Function(BookEntries)>[
                (BookEntries table) => OrderingTerm.asc(table.id),
              ]))
            .get();
    final ContentDocument? document =
        await (db.select(db.contentDocuments)
              ..where((ContentDocuments table) => table.postId.equals(postId)))
            .getSingleOrNull();
    final String sourceUrl =
        document?.sourceUrl ??
        (post.tid == null ? '' : 'https://tieba.baidu.com/p/${post.tid}');
    return ContentDraft(
      postId: postId,
      baseline: await _fingerprint(postId),
      title: post.title ?? '',
      author: post.author ?? '',
      channel: post.channel,
      subChannel: post.subChannel ?? '',
      date: post.date ?? '',
      category: post.postKind,
      origin: post.origin,
      sourceUrl: sourceUrl,
      floors: <ContentFloorDraft>[
        for (final Floor floor in floors)
          ContentFloorDraft(
            id: floor.id,
            text: floor.content,
            images: <ContentImageDraft>[
              for (final FloorImage image in images.where(
                (FloorImage image) => image.floorId == floor.id,
              ))
                ContentImageDraft(
                  id: image.id,
                  url: image.urlOriginal?.isNotEmpty == true
                      ? image.urlOriginal!
                      : image.urlPermanent ?? '',
                  width: image.width,
                  height: image.height,
                ),
            ],
          ),
      ],
      entries: <ContentEntryDraft>[
        for (final BookEntry entry in entries)
          ContentEntryDraft(
            id: entry.id,
            name: entry.name,
            author: entry.author ?? '',
            comment: entry.comment ?? '',
            floorIndex: floors
                .indexWhere((Floor floor) => floor.id == entry.floorRef)
                .clamp(0, floors.isEmpty ? 0 : floors.length - 1),
            category: entry.category,
            recommender: entry.recommender ?? '',
            channel: entry.channel,
            date: entry.date ?? '',
            sourceUrl: entry.srcUrl ?? '',
            wordCount: entry.wordCount,
            bookGrade: entry.bookGrade,
          ),
      ],
      rawDocument: document?.originalBytes,
      fileName: document?.fileName,
      mediaType: document?.mediaType ?? 'application/json',
      warnings: document == null
          ? const <String>[]
          : (jsonDecode(document.warnings) as List<dynamic>).cast<String>(),
    );
  });

  Future<ContentSaveResult> save(ContentDraft draft) async {
    _validate(draft);
    return db.transaction(() async {
      final DateTime now = DateTime.now();
      final String sourceUrl = draft.sourceUrl.trim();
      final String title = draft.title.trim().isEmpty
          ? '导入扫书'
          : draft.title.trim();
      final String? importKey =
          draft.postId == null && draft.rawDocument != null
          ? sha256.convert(<int>[
              ...utf8.encode('$sourceUrl\u001f'),
              ...draft.rawDocument!,
            ]).toString()
          : null;
      if (importKey != null) {
        final ContentDocument? duplicate =
            await (db.select(db.contentDocuments)..where(
                  (ContentDocuments table) => table.importKey.equals(importKey),
                ))
                .getSingleOrNull();
        if (duplicate != null) {
          final int count =
              await (db.select(db.bookEntries)..where(
                    (BookEntries table) =>
                        table.postRef.equals(duplicate.postId),
                  ))
                  .get()
                  .then((List<BookEntry> entries) => entries.length);
          return ContentSaveResult(
            postId: duplicate.postId,
            entryCount: count,
            alreadyImported: true,
          );
        }
      }
      final Setting? seed =
          await (db.select(db.settings)..where(
                (Settings table) => table.key.equals(SettingsKeys.seedVersion),
              ))
              .getSingleOrNull();
      final Setting? ftsReady =
          await (db.select(db.settings)..where(
                (Settings table) => table.key.equals('fts_rebuild_done'),
              ))
              .getSingleOrNull();
      final bool indexPending = seed != null && ftsReady?.value != '1';
      final List<String> activeTriggers = indexPending
          ? (await db
                    .customSelect(
                      "SELECT name FROM sqlite_master WHERE type = 'trigger' AND name IN (${List<String>.filled(allFtsTriggerNames.length, '?').join(',')})",
                      variables: <Variable<Object>>[
                        for (final String name in allFtsTriggerNames)
                          Variable<String>(name),
                      ],
                    )
                    .get())
                .map((QueryRow row) => row.read<String>('name'))
                .toList()
          : <String>[];
      for (final String trigger in activeTriggers) {
        await db.customStatement('DROP TRIGGER $trigger');
      }
      final int postId;
      Post? previous;
      if (draft.postId == null) {
        postId = await db
            .into(db.posts)
            .insert(
              PostsCompanion.insert(
                channel: draft.channel.trim(),
                origin: const Value<String>(Origin.imported),
                collectedAt: Value<DateTime?>(now),
              ),
            );
      } else {
        postId = draft.postId!;
        previous = await (db.select(
          db.posts,
        )..where((Posts table) => table.id.equals(postId))).getSingleOrNull();
        if (previous == null) throw const ContentEditException('帖子已不存在，草稿仍保留。');
        if (draft.baseline != await _fingerprint(postId)) {
          throw const ContentEditException('帖子在编辑期间发生变化，请保留草稿并重新打开后合并修改。');
        }
      }
      final List<Floor> oldFloors = await (db.select(
        db.floors,
      )..where((Floors table) => table.postId.equals(postId))).get();
      final List<BookEntry> oldEntries = await (db.select(
        db.bookEntries,
      )..where((BookEntries table) => table.postRef.equals(postId))).get();
      final Set<int> ownedFloors = oldFloors
          .map((Floor floor) => floor.id)
          .toSet();
      final Set<int> ownedEntries = oldEntries
          .map((BookEntry entry) => entry.id)
          .toSet();
      final List<FloorImage> oldImages = ownedFloors.isEmpty
          ? <FloorImage>[]
          : await (db.select(
              db.images,
            )..where((Images table) => table.floorId.isIn(ownedFloors))).get();
      final Map<int, int> imageFloors = <int, int>{
        for (final FloorImage image in oldImages) image.id: image.floorId,
      };
      if (draft.floors.any(
            (ContentFloorDraft floor) =>
                floor.id != null && !ownedFloors.contains(floor.id),
          ) ||
          draft.entries.any(
            (ContentEntryDraft entry) =>
                entry.id != null && !ownedEntries.contains(entry.id),
          )) {
        throw const ContentEditException('草稿包含其他帖子的内容，未保存。');
      }
      final String initialSnapshot = await _snapshot(postId);
      final ContentDocument? existingDocument =
          await (db.select(
                db.contentDocuments,
              )..where((ContentDocuments table) => table.postId.equals(postId)))
              .getSingleOrNull();
      final Uint8List original =
          draft.rawDocument ?? Uint8List.fromList(utf8.encode(initialSnapshot));
      if (existingDocument == null) {
        await db
            .into(db.contentDocuments)
            .insert(
              ContentDocumentsCompanion.insert(
                postId: Value<int>(postId),
                sourceUrl: Value<String>(sourceUrl),
                fileName: draft.fileName ?? 'post-$postId-original.json',
                mediaType: draft.mediaType,
                originalBytes: original,
                originalHash: sha256.convert(original).toString(),
                initialSnapshot: initialSnapshot,
                importKey: Value<String?>(importKey),
                warnings: Value<String>(jsonEncode(draft.warnings)),
                editedAt: now,
              ),
            );
      } else {
        await (db.update(db.contentDocuments)
              ..where((ContentDocuments table) => table.postId.equals(postId)))
            .write(
              ContentDocumentsCompanion(
                sourceUrl: Value<String>(sourceUrl),
                editedAt: Value<DateTime>(now),
                warnings: Value<String>(jsonEncode(draft.warnings)),
              ),
            );
      }
      final String date = draft.date.isEmpty && previous == null
          ? contentDate(now)
          : draft.date.trim();
      final String kind = draft.category == kRecommendKind
          ? CategoryKind.scan
          : draft.category;
      await (db.update(
        db.posts,
      )..where((Posts table) => table.id.equals(postId))).write(
        PostsCompanion(
          title: Value<String?>(title),
          author: Value<String?>(_nullable(draft.author)),
          channel: Value<String>(draft.channel.trim()),
          subChannel: Value<String?>(_nullable(draft.subChannel)),
          date: Value<String?>(_nullable(date)),
          postKind: Value<String>(kind),
          recommendFlag: Value<int>(
            draft.category == CategoryKind.avoid
                ? -1
                : draft.category == kRecommendKind
                ? 1
                : 0,
          ),
          floorCount: Value<int>(draft.floors.length),
          imageCount: Value<int>(draft.imageCount),
          origin:
              previous?.origin == Origin.seed ||
                  previous?.origin == Origin.builtin
              ? const Value<String>(Origin.imported)
              : const Value<String>.absent(),
        ),
      );
      final List<int> floorIds = <int>[];
      final Set<int> retainedImages = <int>{};
      for (final (int index, ContentFloorDraft floor) in draft.floors.indexed) {
        final FloorsCompanion values = FloorsCompanion(
          postId: Value<int>(postId),
          seq: Value<int>(index + 1),
          content: Value<String>(floor.text),
          textNormHash: Value<String?>(h16(normText(floor.text))),
          charCount: Value<int>(floor.text.runes.length),
        );
        final int floorId;
        if (floor.id == null) {
          floorId = await db.into(db.floors).insert(values);
        } else {
          floorId = floor.id!;
          await (db.update(
            db.floors,
          )..where((Floors table) => table.id.equals(floorId))).write(values);
        }
        floorIds.add(floorId);
        for (final ContentImageDraft image in floor.images) {
          final ImagesCompanion imageValues = ImagesCompanion(
            floorId: Value<int>(floorId),
            urlOriginal: Value<String?>(image.url.trim()),
            width: Value<int>(image.width),
            height: Value<int>(image.height),
          );
          if (image.id == null) {
            retainedImages.add(await db.into(db.images).insert(imageValues));
          } else {
            if (imageFloors[image.id] != floorId ||
                !retainedImages.add(image.id!)) {
              throw const ContentEditException('图片引用冲突，未保存。');
            }
            await (db.update(db.images)
                  ..where((Images table) => table.id.equals(image.id!)))
                .write(imageValues);
          }
        }
      }
      final Set<int> touchedGroups = oldEntries
          .map((BookEntry entry) => entry.bookGroupId)
          .whereType<int>()
          .toSet();
      final Map<String, List<BookEntry>> existingByName =
          <String, List<BookEntry>>{};
      for (final BookEntry entry in oldEntries) {
        existingByName
            .putIfAbsent(entry.nameNorm, () => <BookEntry>[])
            .add(entry);
      }
      final Set<int> referencedEntries = draft.entries
          .map((ContentEntryDraft entry) => entry.id)
          .whereType<int>()
          .toSet();
      for (final BookEntry entry in oldEntries) {
        await (db.update(
          db.bookEntries,
        )..where((BookEntries table) => table.id.equals(entry.id))).write(
          BookEntriesCompanion(
            contentHash: Value<String>(
              'editing:$postId:${entry.id}:${now.microsecondsSinceEpoch}',
            ),
          ),
        );
      }
      final Set<int> retainedEntries = <int>{};
      final String entryOrigin =
          previous?.origin == Origin.seed || previous?.origin == Origin.builtin
          ? Origin.imported
          : previous?.origin ?? Origin.imported;
      for (final ContentEntryDraft entry in draft.entries) {
        final String name = entry.name.trim().replaceAll(
          RegExp(r'^[《〈]|[》〉]$'),
          '',
        );
        final String nameNorm = normName(name);
        final String authorNorm = normPerson(entry.author);
        final BookGroup? group =
            await (db.select(
                  db.bookGroups,
                )..where((BookGroups table) => table.nameNorm.equals(nameNorm)))
                .getSingleOrNull();
        final int groupId =
            group?.id ??
            await db
                .into(db.bookGroups)
                .insert(
                  BookGroupsCompanion.insert(
                    nameNorm: nameNorm,
                    nameDisplay: Value<String?>(name),
                    authorDisplay: Value<String?>(_nullable(entry.author)),
                    authorEffNorm: Value<String>(authorNorm),
                  ),
                );
        touchedGroups.add(groupId);
        final String commentHash = entry.comment.trim().isEmpty
            ? ''
            : h16(normText(entry.comment));
        final BookEntriesCompanion values = BookEntriesCompanion(
          name: Value<String>(name),
          nameNorm: Value<String>(nameNorm),
          author: Value<String?>(_nullable(entry.author)),
          authorNorm: Value<String?>(_nullable(authorNorm)),
          authorKind: Value<String?>(authorNorm.isEmpty ? null : 'parsed'),
          comment: Value<String?>(_nullable(entry.comment, trim: false)),
          commentNormHash: Value<String?>(_nullable(commentHash)),
          commentSrc: const Value<String?>('user_edited'),
          recommender: Value<String?>(_nullable(entry.recommender)),
          channel: Value<String>(
            entry.channel.trim().isEmpty
                ? draft.channel.trim()
                : entry.channel.trim(),
          ),
          date: Value<String?>(_nullable(entry.date)),
          subChannel: Value<String?>(_nullable(draft.subChannel)),
          category: Value<String>(entry.category),
          postRef: Value<int?>(postId),
          floorRef: Value<int?>(floorIds[entry.floorIndex]),
          srcTid: Value<int?>(previous?.tid),
          srcUrl: Value<String?>(_nullable(entry.sourceUrl)),
          wordCount: Value<int?>(entry.wordCount),
          bookGrade: Value<String?>(entry.bookGrade),
          quality: Value<int>(
            authorNorm.isNotEmpty && entry.comment.isNotEmpty
                ? 3
                : entry.comment.isNotEmpty
                ? 2
                : 1,
          ),
          contentHash: Value<String>(
            entryContentHash(
              nameNorm: nameNorm,
              authorNorm: authorNorm,
              commentNormHash: commentHash,
              postRef: postId,
            ),
          ),
          bookGroupId: Value<int?>(groupId),
          origin: Value<String>(entryOrigin),
          collectedAt: previous == null
              ? Value<DateTime?>(now)
              : const Value<DateTime?>.absent(),
        );
        final int entryId;
        final int? retainedId =
            entry.id ??
            existingByName[nameNorm]
                ?.where(
                  (BookEntry previousEntry) =>
                      !referencedEntries.contains(previousEntry.id) &&
                      !retainedEntries.contains(previousEntry.id),
                )
                .firstOrNull
                ?.id;
        if (retainedId == null) {
          entryId = await db.into(db.bookEntries).insert(values);
        } else {
          entryId = retainedId;
          if (retainedEntries.contains(entryId)) {
            throw const ContentEditException('书目引用重复，未保存。');
          }
          await (db.update(db.bookEntries)
                ..where((BookEntries table) => table.id.equals(entryId)))
              .write(values);
        }
        retainedEntries.add(entryId);
      }
      final List<int> deletedEntries = ownedEntries
          .difference(retainedEntries)
          .toList();
      if (deletedEntries.isNotEmpty) {
        await (db.update(db.bookmarks)
              ..where((Bookmarks table) => table.entryRef.isIn(deletedEntries)))
            .write(const BookmarksCompanion(entryRef: Value<int?>(null)));
        await (db.delete(db.favorites)..where(
              (Favorites table) =>
                  table.targetType.equals(FavoriteTarget.entry) &
                  table.targetId.isIn(deletedEntries),
            ))
            .go();
        await (db.delete(
          db.bookEntries,
        )..where((BookEntries table) => table.id.isIn(deletedEntries))).go();
      }
      final List<int> deletedFloors = ownedFloors
          .difference(floorIds.toSet())
          .toList();
      if (deletedFloors.isNotEmpty) {
        await (db.delete(
          db.floors,
        )..where((Floors table) => table.id.isIn(deletedFloors))).go();
      }
      final List<int> deletedImages = imageFloors.keys
          .toSet()
          .difference(retainedImages)
          .toList();
      if (deletedImages.isNotEmpty) {
        await (db.delete(
          db.images,
        )..where((Images table) => table.id.isIn(deletedImages))).go();
      }
      for (final int groupId in touchedGroups) {
        await _refreshGroup(groupId);
      }
      await (db.update(db.favorites)..where(
            (Favorites table) =>
                table.targetType.equals(FavoriteTarget.post) &
                table.targetId.equals(postId),
          ))
          .write(
            FavoritesCompanion(
              title: Value<String>(title),
              subtitle: Value<String?>(_nullable(draft.author)),
            ),
          );
      await (db.update(
        db.bookmarks,
      )..where((Bookmarks table) => table.postRef.equals(postId))).write(
        BookmarksCompanion(
          title: Value<String>(title),
          author: Value<String?>(_nullable(draft.author)),
          channel: Value<String?>(draft.channel.trim()),
        ),
      );
      final List<Bookmark> bookmarks = await (db.select(
        db.bookmarks,
      )..where((Bookmarks table) => table.postRef.equals(postId))).get();
      for (final Bookmark bookmark in bookmarks) {
        final int previousIndex = oldFloors.indexWhere(
          (Floor floor) => floor.seq == bookmark.floorSeq,
        );
        if (previousIndex < 0) continue;
        final int nextIndex = floorIds.indexOf(oldFloors[previousIndex].id);
        await (db.update(
          db.bookmarks,
        )..where((Bookmarks table) => table.id.equals(bookmark.id))).write(
          BookmarksCompanion(
            floorSeq: Value<int?>(nextIndex < 0 ? 1 : nextIndex + 1),
          ),
        );
      }
      if (activeTriggers.any(bookFtsTriggerNames.contains)) {
        await createBookFtsTriggers(db.customStatement);
      }
      if (activeTriggers.any(floorFtsTriggerNames.contains)) {
        await createFloorFtsTriggers(db.customStatement);
      }
      return ContentSaveResult(
        postId: postId,
        entryCount: draft.entries.length,
      );
    });
  }

  Future<ContentDocument?> original(int postId) =>
      (db.select(db.contentDocuments)
            ..where((ContentDocuments table) => table.postId.equals(postId)))
          .getSingleOrNull();

  Future<String> _snapshot(int postId) async {
    final Map<String, Object?> snapshot = <String, Object?>{};
    for (final MapEntry<String, String> query in <String, String>{
      'post': 'SELECT * FROM posts WHERE id = ?',
      'floors': 'SELECT * FROM floors WHERE post_id = ? ORDER BY id',
      'images':
          'SELECT i.* FROM images i JOIN floors f ON f.id = i.floor_id WHERE f.post_id = ? ORDER BY i.id',
      'entries': 'SELECT * FROM book_entries WHERE post_ref = ? ORDER BY id',
      'source':
          'SELECT source_url, edited_at FROM content_documents WHERE post_id = ?',
    }.entries) {
      snapshot[query.key] =
          (await db
                  .customSelect(
                    query.value,
                    variables: <Variable<Object>>[Variable<int>(postId)],
                  )
                  .get())
              .map((QueryRow row) => row.data)
              .toList();
    }
    return jsonEncode(snapshot);
  }

  Future<String> _fingerprint(int postId) async =>
      sha256.convert(utf8.encode(await _snapshot(postId))).toString();

  Future<void> _refreshGroup(int groupId) async {
    final List<BookEntry> entries = await (db.select(
      db.bookEntries,
    )..where((BookEntries table) => table.bookGroupId.equals(groupId))).get();
    entries.sort((BookEntry first, BookEntry second) {
      final int manual = (first.commentSrc == 'user_edited' ? 0 : 1).compareTo(
        second.commentSrc == 'user_edited' ? 0 : 1,
      );
      return manual != 0 ? manual : second.quality.compareTo(first.quality);
    });
    final List<String> dates =
        entries
            .map((BookEntry entry) => entry.date)
            .whereType<String>()
            .toList()
          ..sort();
    final List<int> words =
        entries
            .map((BookEntry entry) => entry.wordCount)
            .whereType<int>()
            .toList()
          ..sort();
    final BookEntry? authorEntry = entries
        .where((BookEntry entry) => (entry.author ?? '').isNotEmpty)
        .firstOrNull;
    await (db.update(
      db.bookGroups,
    )..where((BookGroups table) => table.id.equals(groupId))).write(
      BookGroupsCompanion(
        entryTotal: Value<int>(entries.length),
        distinctComment: Value<int>(
          entries
              .map((BookEntry entry) => entry.commentNormHash)
              .whereType<String>()
              .where((String hash) => hash.isNotEmpty)
              .toSet()
              .length,
        ),
        channels: Value<String?>(
          jsonEncode(
            entries.map((BookEntry entry) => entry.channel).toSet().toList()
              ..sort(),
          ),
        ),
        dateMin: Value<String?>(dates.firstOrNull),
        dateMax: Value<String?>(dates.lastOrNull),
        wordCountMax: Value<int?>(words.lastOrNull),
        nameDisplay: entries.isEmpty
            ? const Value<String?>.absent()
            : Value<String?>(entries.first.name),
        authorDisplay: entries.isEmpty
            ? const Value<String?>.absent()
            : Value<String?>(authorEntry?.author),
        authorEffNorm: entries.isEmpty
            ? const Value<String>.absent()
            : Value<String>(authorEntry?.authorNorm ?? ''),
      ),
    );
    if (entries.isNotEmpty) {
      await (db.update(db.favorites)..where(
            (Favorites table) =>
                table.targetType.equals(FavoriteTarget.bookGroup) &
                table.targetId.equals(groupId),
          ))
          .write(
            FavoritesCompanion(
              title: Value<String>('《${entries.first.name}》'),
              subtitle: Value<String?>(authorEntry?.author),
            ),
          );
    }
  }

  void _validate(ContentDraft draft) {
    if (draft.channel.trim().isEmpty ||
        !validContentDate(draft.date.trim()) ||
        !validContentUrl(draft.sourceUrl.trim())) {
      throw const ContentEditException('请填写来源，并检查日期和原文链接。');
    }
    if (!<String>{
      ...CategoryKind.all,
      kRecommendKind,
    }.contains(draft.category)) {
      throw const ContentEditException('帖子类别无效。');
    }
    if (draft.floors.isEmpty ||
        !draft.floors.any(
          (ContentFloorDraft floor) =>
              floor.text.trim().isNotEmpty || floor.images.isNotEmpty,
        )) {
      throw const ContentEditException('请保留至少一段正文或一张图片。');
    }
    if (draft.rawDocument != null &&
        draft.rawDocument!.length > maxImportBytes) {
      throw const ContentEditException('原始文档超过 24 MB。');
    }
    final Set<String> names = <String>{};
    final Set<String> entryHashes = <String>{};
    final Set<int> floorIds = <int>{};
    int imageBytes = 0;
    for (final ContentFloorDraft floor in draft.floors) {
      if (floor.id != null && !floorIds.add(floor.id!)) {
        throw const ContentEditException('楼层引用重复。');
      }
      for (final ContentImageDraft image in floor.images) {
        if (image.url.isEmpty ||
            !validContentUrl(image.url.trim(), image: true) ||
            image.width < 0 ||
            image.height < 0) {
          throw const ContentEditException('有图片地址或尺寸无效。');
        }
        if (image.embedded) imageBytes += image.url.length;
      }
    }
    if (imageBytes > maxExpandedDocumentBytes) {
      throw const ContentEditException('嵌入图片超过 64 MB，请分篇导入。');
    }
    for (final ContentEntryDraft entry in draft.entries) {
      final String nameNorm = normName(entry.name);
      final String contentHash = entryContentHash(
        nameNorm: nameNorm,
        authorNorm: normPerson(entry.author),
        commentNormHash: entry.comment.trim().isEmpty
            ? ''
            : h16(normText(entry.comment)),
        postRef: draft.postId,
      );
      if (nameNorm.isEmpty ||
          draft.postId == null && !names.add(nameNorm) ||
          !entryHashes.add(contentHash)) {
        throw const ContentEditException('书名不能为空，同一帖子内请合并重复评价。');
      }
      if (entry.floorIndex < 0 ||
          entry.floorIndex >= draft.floors.length ||
          !validContentDate(entry.date.trim()) ||
          !validContentUrl(entry.sourceUrl.trim()) ||
          !<String>{
            ...CategoryKind.all,
            kRecommendKind,
          }.contains(entry.category) ||
          (entry.wordCount ?? 0) < 0) {
        throw const ContentEditException('请检查书目的楼层、日期、字数、来源链接和类别。');
      }
    }
  }
}

String? _nullable(String value, {bool trim = true}) => value.trim().isEmpty
    ? null
    : trim
    ? value.trim()
    : value;
