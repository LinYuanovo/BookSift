// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PostsTable extends Posts with TableInfo<$PostsTable, Post> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PostsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tidMeta = const VerificationMeta('tid');
  @override
  late final GeneratedColumn<int> tid = GeneratedColumn<int>(
    'tid',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorNameMeta = const VerificationMeta(
    'authorName',
  );
  @override
  late final GeneratedColumn<String> authorName = GeneratedColumn<String>(
    'author_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _portraitMeta = const VerificationMeta(
    'portrait',
  );
  @override
  late final GeneratedColumn<String> portrait = GeneratedColumn<String>(
    'portrait',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateRawMeta = const VerificationMeta(
    'dateRaw',
  );
  @override
  late final GeneratedColumn<String> dateRaw = GeneratedColumn<String>(
    'date_raw',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _channelMeta = const VerificationMeta(
    'channel',
  );
  @override
  late final GeneratedColumn<String> channel = GeneratedColumn<String>(
    'channel',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subChannelMeta = const VerificationMeta(
    'subChannel',
  );
  @override
  late final GeneratedColumn<String> subChannel = GeneratedColumn<String>(
    'sub_channel',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _postTypeMeta = const VerificationMeta(
    'postType',
  );
  @override
  late final GeneratedColumn<String> postType = GeneratedColumn<String>(
    'post_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('扫书'),
  );
  static const VerificationMeta _postKindMeta = const VerificationMeta(
    'postKind',
  );
  @override
  late final GeneratedColumn<String> postKind = GeneratedColumn<String>(
    'post_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('扫书'),
  );
  static const VerificationMeta _recommendFlagMeta = const VerificationMeta(
    'recommendFlag',
  );
  @override
  late final GeneratedColumn<int> recommendFlag = GeneratedColumn<int>(
    'recommend_flag',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _floorCountMeta = const VerificationMeta(
    'floorCount',
  );
  @override
  late final GeneratedColumn<int> floorCount = GeneratedColumn<int>(
    'floor_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _imageCountMeta = const VerificationMeta(
    'imageCount',
  );
  @override
  late final GeneratedColumn<int> imageCount = GeneratedColumn<int>(
    'image_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('builtin'),
  );
  static const VerificationMeta _collectedAtMeta = const VerificationMeta(
    'collectedAt',
  );
  @override
  late final GeneratedColumn<DateTime> collectedAt = GeneratedColumn<DateTime>(
    'collected_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tid,
    title,
    author,
    authorName,
    userId,
    portrait,
    date,
    dateRaw,
    channel,
    subChannel,
    postType,
    postKind,
    recommendFlag,
    floorCount,
    imageCount,
    origin,
    collectedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'posts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Post> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tid')) {
      context.handle(
        _tidMeta,
        tid.isAcceptableOrUnknown(data['tid']!, _tidMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('author_name')) {
      context.handle(
        _authorNameMeta,
        authorName.isAcceptableOrUnknown(data['author_name']!, _authorNameMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('portrait')) {
      context.handle(
        _portraitMeta,
        portrait.isAcceptableOrUnknown(data['portrait']!, _portraitMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    if (data.containsKey('date_raw')) {
      context.handle(
        _dateRawMeta,
        dateRaw.isAcceptableOrUnknown(data['date_raw']!, _dateRawMeta),
      );
    }
    if (data.containsKey('channel')) {
      context.handle(
        _channelMeta,
        channel.isAcceptableOrUnknown(data['channel']!, _channelMeta),
      );
    } else if (isInserting) {
      context.missing(_channelMeta);
    }
    if (data.containsKey('sub_channel')) {
      context.handle(
        _subChannelMeta,
        subChannel.isAcceptableOrUnknown(data['sub_channel']!, _subChannelMeta),
      );
    }
    if (data.containsKey('post_type')) {
      context.handle(
        _postTypeMeta,
        postType.isAcceptableOrUnknown(data['post_type']!, _postTypeMeta),
      );
    }
    if (data.containsKey('post_kind')) {
      context.handle(
        _postKindMeta,
        postKind.isAcceptableOrUnknown(data['post_kind']!, _postKindMeta),
      );
    }
    if (data.containsKey('recommend_flag')) {
      context.handle(
        _recommendFlagMeta,
        recommendFlag.isAcceptableOrUnknown(
          data['recommend_flag']!,
          _recommendFlagMeta,
        ),
      );
    }
    if (data.containsKey('floor_count')) {
      context.handle(
        _floorCountMeta,
        floorCount.isAcceptableOrUnknown(data['floor_count']!, _floorCountMeta),
      );
    }
    if (data.containsKey('image_count')) {
      context.handle(
        _imageCountMeta,
        imageCount.isAcceptableOrUnknown(data['image_count']!, _imageCountMeta),
      );
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    }
    if (data.containsKey('collected_at')) {
      context.handle(
        _collectedAtMeta,
        collectedAt.isAcceptableOrUnknown(
          data['collected_at']!,
          _collectedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Post map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Post(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tid'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      authorName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_name'],
      ),
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      ),
      portrait: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}portrait'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      ),
      dateRaw: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_raw'],
      ),
      channel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel'],
      )!,
      subChannel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sub_channel'],
      ),
      postType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}post_type'],
      )!,
      postKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}post_kind'],
      )!,
      recommendFlag: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recommend_flag'],
      )!,
      floorCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}floor_count'],
      )!,
      imageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}image_count'],
      )!,
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      )!,
      collectedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}collected_at'],
      ),
    );
  }

  @override
  $PostsTable createAlias(String alias) {
    return $PostsTable(attachedDatabase, alias);
  }
}

class Post extends DataClass implements Insertable<Post> {
  final int id;

  /// 贴吧主题 id；非贴吧来源为 NULL。
  final int? tid;
  final String? title;

  /// 发帖人昵称（显示名）。
  final String? author;

  /// 发帖人 user_name（唯一标识）。
  final String? authorName;
  final int? userId;
  final String portrait;

  /// 'YYYY-MM-DD'，入库前校验合法性。
  final String? date;

  /// 非法/原始日期留档（对标 unified date_raw）。
  final String? dateRaw;

  /// yy小说吧/哀伤雪刃/雪群推书/大佬贴吧扫书/…
  final String channel;

  /// 扫书人 ID / 尾标。
  final String? subChannel;

  /// 源分类留档（unified 直迁）：扫书/求书/日常，不参与产品逻辑。
  final String postType;

  /// 产品分类（§8.9 classifier）：扫书/排雷/求书/日常；日常闲聊采集端丢弃不入库。
  final String postKind;

  /// 推荐语义：+1=推荐 / -1=排雷 / 0=中性；由 post_kind 派生，大佬存量按 book_grade 映射。
  final int recommendFlag;
  final int floorCount;
  final int imageCount;

  /// builtin/collected/imported。
  final String origin;
  final DateTime? collectedAt;
  const Post({
    required this.id,
    this.tid,
    this.title,
    this.author,
    this.authorName,
    this.userId,
    required this.portrait,
    this.date,
    this.dateRaw,
    required this.channel,
    this.subChannel,
    required this.postType,
    required this.postKind,
    required this.recommendFlag,
    required this.floorCount,
    required this.imageCount,
    required this.origin,
    this.collectedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || tid != null) {
      map['tid'] = Variable<int>(tid);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || authorName != null) {
      map['author_name'] = Variable<String>(authorName);
    }
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<int>(userId);
    }
    map['portrait'] = Variable<String>(portrait);
    if (!nullToAbsent || date != null) {
      map['date'] = Variable<String>(date);
    }
    if (!nullToAbsent || dateRaw != null) {
      map['date_raw'] = Variable<String>(dateRaw);
    }
    map['channel'] = Variable<String>(channel);
    if (!nullToAbsent || subChannel != null) {
      map['sub_channel'] = Variable<String>(subChannel);
    }
    map['post_type'] = Variable<String>(postType);
    map['post_kind'] = Variable<String>(postKind);
    map['recommend_flag'] = Variable<int>(recommendFlag);
    map['floor_count'] = Variable<int>(floorCount);
    map['image_count'] = Variable<int>(imageCount);
    map['origin'] = Variable<String>(origin);
    if (!nullToAbsent || collectedAt != null) {
      map['collected_at'] = Variable<DateTime>(collectedAt);
    }
    return map;
  }

  PostsCompanion toCompanion(bool nullToAbsent) {
    return PostsCompanion(
      id: Value(id),
      tid: tid == null && nullToAbsent ? const Value.absent() : Value(tid),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      authorName: authorName == null && nullToAbsent
          ? const Value.absent()
          : Value(authorName),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      portrait: Value(portrait),
      date: date == null && nullToAbsent ? const Value.absent() : Value(date),
      dateRaw: dateRaw == null && nullToAbsent
          ? const Value.absent()
          : Value(dateRaw),
      channel: Value(channel),
      subChannel: subChannel == null && nullToAbsent
          ? const Value.absent()
          : Value(subChannel),
      postType: Value(postType),
      postKind: Value(postKind),
      recommendFlag: Value(recommendFlag),
      floorCount: Value(floorCount),
      imageCount: Value(imageCount),
      origin: Value(origin),
      collectedAt: collectedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(collectedAt),
    );
  }

  factory Post.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Post(
      id: serializer.fromJson<int>(json['id']),
      tid: serializer.fromJson<int?>(json['tid']),
      title: serializer.fromJson<String?>(json['title']),
      author: serializer.fromJson<String?>(json['author']),
      authorName: serializer.fromJson<String?>(json['authorName']),
      userId: serializer.fromJson<int?>(json['userId']),
      portrait: serializer.fromJson<String>(json['portrait']),
      date: serializer.fromJson<String?>(json['date']),
      dateRaw: serializer.fromJson<String?>(json['dateRaw']),
      channel: serializer.fromJson<String>(json['channel']),
      subChannel: serializer.fromJson<String?>(json['subChannel']),
      postType: serializer.fromJson<String>(json['postType']),
      postKind: serializer.fromJson<String>(json['postKind']),
      recommendFlag: serializer.fromJson<int>(json['recommendFlag']),
      floorCount: serializer.fromJson<int>(json['floorCount']),
      imageCount: serializer.fromJson<int>(json['imageCount']),
      origin: serializer.fromJson<String>(json['origin']),
      collectedAt: serializer.fromJson<DateTime?>(json['collectedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tid': serializer.toJson<int?>(tid),
      'title': serializer.toJson<String?>(title),
      'author': serializer.toJson<String?>(author),
      'authorName': serializer.toJson<String?>(authorName),
      'userId': serializer.toJson<int?>(userId),
      'portrait': serializer.toJson<String>(portrait),
      'date': serializer.toJson<String?>(date),
      'dateRaw': serializer.toJson<String?>(dateRaw),
      'channel': serializer.toJson<String>(channel),
      'subChannel': serializer.toJson<String?>(subChannel),
      'postType': serializer.toJson<String>(postType),
      'postKind': serializer.toJson<String>(postKind),
      'recommendFlag': serializer.toJson<int>(recommendFlag),
      'floorCount': serializer.toJson<int>(floorCount),
      'imageCount': serializer.toJson<int>(imageCount),
      'origin': serializer.toJson<String>(origin),
      'collectedAt': serializer.toJson<DateTime?>(collectedAt),
    };
  }

  Post copyWith({
    int? id,
    Value<int?> tid = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<String?> author = const Value.absent(),
    Value<String?> authorName = const Value.absent(),
    Value<int?> userId = const Value.absent(),
    String? portrait,
    Value<String?> date = const Value.absent(),
    Value<String?> dateRaw = const Value.absent(),
    String? channel,
    Value<String?> subChannel = const Value.absent(),
    String? postType,
    String? postKind,
    int? recommendFlag,
    int? floorCount,
    int? imageCount,
    String? origin,
    Value<DateTime?> collectedAt = const Value.absent(),
  }) => Post(
    id: id ?? this.id,
    tid: tid.present ? tid.value : this.tid,
    title: title.present ? title.value : this.title,
    author: author.present ? author.value : this.author,
    authorName: authorName.present ? authorName.value : this.authorName,
    userId: userId.present ? userId.value : this.userId,
    portrait: portrait ?? this.portrait,
    date: date.present ? date.value : this.date,
    dateRaw: dateRaw.present ? dateRaw.value : this.dateRaw,
    channel: channel ?? this.channel,
    subChannel: subChannel.present ? subChannel.value : this.subChannel,
    postType: postType ?? this.postType,
    postKind: postKind ?? this.postKind,
    recommendFlag: recommendFlag ?? this.recommendFlag,
    floorCount: floorCount ?? this.floorCount,
    imageCount: imageCount ?? this.imageCount,
    origin: origin ?? this.origin,
    collectedAt: collectedAt.present ? collectedAt.value : this.collectedAt,
  );
  Post copyWithCompanion(PostsCompanion data) {
    return Post(
      id: data.id.present ? data.id.value : this.id,
      tid: data.tid.present ? data.tid.value : this.tid,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      authorName: data.authorName.present
          ? data.authorName.value
          : this.authorName,
      userId: data.userId.present ? data.userId.value : this.userId,
      portrait: data.portrait.present ? data.portrait.value : this.portrait,
      date: data.date.present ? data.date.value : this.date,
      dateRaw: data.dateRaw.present ? data.dateRaw.value : this.dateRaw,
      channel: data.channel.present ? data.channel.value : this.channel,
      subChannel: data.subChannel.present
          ? data.subChannel.value
          : this.subChannel,
      postType: data.postType.present ? data.postType.value : this.postType,
      postKind: data.postKind.present ? data.postKind.value : this.postKind,
      recommendFlag: data.recommendFlag.present
          ? data.recommendFlag.value
          : this.recommendFlag,
      floorCount: data.floorCount.present
          ? data.floorCount.value
          : this.floorCount,
      imageCount: data.imageCount.present
          ? data.imageCount.value
          : this.imageCount,
      origin: data.origin.present ? data.origin.value : this.origin,
      collectedAt: data.collectedAt.present
          ? data.collectedAt.value
          : this.collectedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Post(')
          ..write('id: $id, ')
          ..write('tid: $tid, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('authorName: $authorName, ')
          ..write('userId: $userId, ')
          ..write('portrait: $portrait, ')
          ..write('date: $date, ')
          ..write('dateRaw: $dateRaw, ')
          ..write('channel: $channel, ')
          ..write('subChannel: $subChannel, ')
          ..write('postType: $postType, ')
          ..write('postKind: $postKind, ')
          ..write('recommendFlag: $recommendFlag, ')
          ..write('floorCount: $floorCount, ')
          ..write('imageCount: $imageCount, ')
          ..write('origin: $origin, ')
          ..write('collectedAt: $collectedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tid,
    title,
    author,
    authorName,
    userId,
    portrait,
    date,
    dateRaw,
    channel,
    subChannel,
    postType,
    postKind,
    recommendFlag,
    floorCount,
    imageCount,
    origin,
    collectedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Post &&
          other.id == this.id &&
          other.tid == this.tid &&
          other.title == this.title &&
          other.author == this.author &&
          other.authorName == this.authorName &&
          other.userId == this.userId &&
          other.portrait == this.portrait &&
          other.date == this.date &&
          other.dateRaw == this.dateRaw &&
          other.channel == this.channel &&
          other.subChannel == this.subChannel &&
          other.postType == this.postType &&
          other.postKind == this.postKind &&
          other.recommendFlag == this.recommendFlag &&
          other.floorCount == this.floorCount &&
          other.imageCount == this.imageCount &&
          other.origin == this.origin &&
          other.collectedAt == this.collectedAt);
}

class PostsCompanion extends UpdateCompanion<Post> {
  final Value<int> id;
  final Value<int?> tid;
  final Value<String?> title;
  final Value<String?> author;
  final Value<String?> authorName;
  final Value<int?> userId;
  final Value<String> portrait;
  final Value<String?> date;
  final Value<String?> dateRaw;
  final Value<String> channel;
  final Value<String?> subChannel;
  final Value<String> postType;
  final Value<String> postKind;
  final Value<int> recommendFlag;
  final Value<int> floorCount;
  final Value<int> imageCount;
  final Value<String> origin;
  final Value<DateTime?> collectedAt;
  const PostsCompanion({
    this.id = const Value.absent(),
    this.tid = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.authorName = const Value.absent(),
    this.userId = const Value.absent(),
    this.portrait = const Value.absent(),
    this.date = const Value.absent(),
    this.dateRaw = const Value.absent(),
    this.channel = const Value.absent(),
    this.subChannel = const Value.absent(),
    this.postType = const Value.absent(),
    this.postKind = const Value.absent(),
    this.recommendFlag = const Value.absent(),
    this.floorCount = const Value.absent(),
    this.imageCount = const Value.absent(),
    this.origin = const Value.absent(),
    this.collectedAt = const Value.absent(),
  });
  PostsCompanion.insert({
    this.id = const Value.absent(),
    this.tid = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.authorName = const Value.absent(),
    this.userId = const Value.absent(),
    this.portrait = const Value.absent(),
    this.date = const Value.absent(),
    this.dateRaw = const Value.absent(),
    required String channel,
    this.subChannel = const Value.absent(),
    this.postType = const Value.absent(),
    this.postKind = const Value.absent(),
    this.recommendFlag = const Value.absent(),
    this.floorCount = const Value.absent(),
    this.imageCount = const Value.absent(),
    this.origin = const Value.absent(),
    this.collectedAt = const Value.absent(),
  }) : channel = Value(channel);
  static Insertable<Post> custom({
    Expression<int>? id,
    Expression<int>? tid,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? authorName,
    Expression<int>? userId,
    Expression<String>? portrait,
    Expression<String>? date,
    Expression<String>? dateRaw,
    Expression<String>? channel,
    Expression<String>? subChannel,
    Expression<String>? postType,
    Expression<String>? postKind,
    Expression<int>? recommendFlag,
    Expression<int>? floorCount,
    Expression<int>? imageCount,
    Expression<String>? origin,
    Expression<DateTime>? collectedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tid != null) 'tid': tid,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (authorName != null) 'author_name': authorName,
      if (userId != null) 'user_id': userId,
      if (portrait != null) 'portrait': portrait,
      if (date != null) 'date': date,
      if (dateRaw != null) 'date_raw': dateRaw,
      if (channel != null) 'channel': channel,
      if (subChannel != null) 'sub_channel': subChannel,
      if (postType != null) 'post_type': postType,
      if (postKind != null) 'post_kind': postKind,
      if (recommendFlag != null) 'recommend_flag': recommendFlag,
      if (floorCount != null) 'floor_count': floorCount,
      if (imageCount != null) 'image_count': imageCount,
      if (origin != null) 'origin': origin,
      if (collectedAt != null) 'collected_at': collectedAt,
    });
  }

  PostsCompanion copyWith({
    Value<int>? id,
    Value<int?>? tid,
    Value<String?>? title,
    Value<String?>? author,
    Value<String?>? authorName,
    Value<int?>? userId,
    Value<String>? portrait,
    Value<String?>? date,
    Value<String?>? dateRaw,
    Value<String>? channel,
    Value<String?>? subChannel,
    Value<String>? postType,
    Value<String>? postKind,
    Value<int>? recommendFlag,
    Value<int>? floorCount,
    Value<int>? imageCount,
    Value<String>? origin,
    Value<DateTime?>? collectedAt,
  }) {
    return PostsCompanion(
      id: id ?? this.id,
      tid: tid ?? this.tid,
      title: title ?? this.title,
      author: author ?? this.author,
      authorName: authorName ?? this.authorName,
      userId: userId ?? this.userId,
      portrait: portrait ?? this.portrait,
      date: date ?? this.date,
      dateRaw: dateRaw ?? this.dateRaw,
      channel: channel ?? this.channel,
      subChannel: subChannel ?? this.subChannel,
      postType: postType ?? this.postType,
      postKind: postKind ?? this.postKind,
      recommendFlag: recommendFlag ?? this.recommendFlag,
      floorCount: floorCount ?? this.floorCount,
      imageCount: imageCount ?? this.imageCount,
      origin: origin ?? this.origin,
      collectedAt: collectedAt ?? this.collectedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tid.present) {
      map['tid'] = Variable<int>(tid.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (authorName.present) {
      map['author_name'] = Variable<String>(authorName.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (portrait.present) {
      map['portrait'] = Variable<String>(portrait.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (dateRaw.present) {
      map['date_raw'] = Variable<String>(dateRaw.value);
    }
    if (channel.present) {
      map['channel'] = Variable<String>(channel.value);
    }
    if (subChannel.present) {
      map['sub_channel'] = Variable<String>(subChannel.value);
    }
    if (postType.present) {
      map['post_type'] = Variable<String>(postType.value);
    }
    if (postKind.present) {
      map['post_kind'] = Variable<String>(postKind.value);
    }
    if (recommendFlag.present) {
      map['recommend_flag'] = Variable<int>(recommendFlag.value);
    }
    if (floorCount.present) {
      map['floor_count'] = Variable<int>(floorCount.value);
    }
    if (imageCount.present) {
      map['image_count'] = Variable<int>(imageCount.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (collectedAt.present) {
      map['collected_at'] = Variable<DateTime>(collectedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PostsCompanion(')
          ..write('id: $id, ')
          ..write('tid: $tid, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('authorName: $authorName, ')
          ..write('userId: $userId, ')
          ..write('portrait: $portrait, ')
          ..write('date: $date, ')
          ..write('dateRaw: $dateRaw, ')
          ..write('channel: $channel, ')
          ..write('subChannel: $subChannel, ')
          ..write('postType: $postType, ')
          ..write('postKind: $postKind, ')
          ..write('recommendFlag: $recommendFlag, ')
          ..write('floorCount: $floorCount, ')
          ..write('imageCount: $imageCount, ')
          ..write('origin: $origin, ')
          ..write('collectedAt: $collectedAt')
          ..write(')'))
        .toString();
  }
}

class $FloorsTable extends Floors with TableInfo<$FloorsTable, Floor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FloorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _postIdMeta = const VerificationMeta('postId');
  @override
  late final GeneratedColumn<int> postId = GeneratedColumn<int>(
    'post_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES posts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pidMeta = const VerificationMeta('pid');
  @override
  late final GeneratedColumn<int> pid = GeneratedColumn<int>(
    'pid',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _textNormHashMeta = const VerificationMeta(
    'textNormHash',
  );
  @override
  late final GeneratedColumn<String> textNormHash = GeneratedColumn<String>(
    'text_norm_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _charCountMeta = const VerificationMeta(
    'charCount',
  );
  @override
  late final GeneratedColumn<int> charCount = GeneratedColumn<int>(
    'char_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorIdMeta = const VerificationMeta(
    'authorId',
  );
  @override
  late final GeneratedColumn<int> authorId = GeneratedColumn<int>(
    'author_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    postId,
    seq,
    pid,
    content,
    textNormHash,
    charCount,
    createdAt,
    authorId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'floors';
  @override
  VerificationContext validateIntegrity(
    Insertable<Floor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('post_id')) {
      context.handle(
        _postIdMeta,
        postId.isAcceptableOrUnknown(data['post_id']!, _postIdMeta),
      );
    } else if (isInserting) {
      context.missing(_postIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('pid')) {
      context.handle(
        _pidMeta,
        pid.isAcceptableOrUnknown(data['pid']!, _pidMeta),
      );
    }
    if (data.containsKey('text')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['text']!, _contentMeta),
      );
    }
    if (data.containsKey('text_norm_hash')) {
      context.handle(
        _textNormHashMeta,
        textNormHash.isAcceptableOrUnknown(
          data['text_norm_hash']!,
          _textNormHashMeta,
        ),
      );
    }
    if (data.containsKey('char_count')) {
      context.handle(
        _charCountMeta,
        charCount.isAcceptableOrUnknown(data['char_count']!, _charCountMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('author_id')) {
      context.handle(
        _authorIdMeta,
        authorId.isAcceptableOrUnknown(data['author_id']!, _authorIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Floor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Floor(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      postId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}post_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      pid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pid'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      textNormHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_norm_hash'],
      ),
      charCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}char_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      authorId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}author_id'],
      ),
    );
  }

  @override
  $FloorsTable createAlias(String alias) {
    return $FloorsTable(attachedDatabase, alias);
  }
}

class Floor extends DataClass implements Insertable<Floor> {
  final int id;
  final int postId;

  /// 楼层号（1=楼主）。
  final int seq;

  /// 贴吧楼层 pid。
  final int? pid;

  /// 楼层正文。SQL 列名保持 text（§7.2/§7.3 FTS 触发器约定）；
  /// Dart 名用 content 以避开 drift Table.text() 构建器的同名冲突。
  final String content;

  /// sha1(norm_text)[:16]，去重用。
  final String? textNormHash;
  final int charCount;
  final DateTime? createdAt;
  final int? authorId;
  const Floor({
    required this.id,
    required this.postId,
    required this.seq,
    this.pid,
    required this.content,
    this.textNormHash,
    required this.charCount,
    this.createdAt,
    this.authorId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['post_id'] = Variable<int>(postId);
    map['seq'] = Variable<int>(seq);
    if (!nullToAbsent || pid != null) {
      map['pid'] = Variable<int>(pid);
    }
    map['text'] = Variable<String>(content);
    if (!nullToAbsent || textNormHash != null) {
      map['text_norm_hash'] = Variable<String>(textNormHash);
    }
    map['char_count'] = Variable<int>(charCount);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || authorId != null) {
      map['author_id'] = Variable<int>(authorId);
    }
    return map;
  }

  FloorsCompanion toCompanion(bool nullToAbsent) {
    return FloorsCompanion(
      id: Value(id),
      postId: Value(postId),
      seq: Value(seq),
      pid: pid == null && nullToAbsent ? const Value.absent() : Value(pid),
      content: Value(content),
      textNormHash: textNormHash == null && nullToAbsent
          ? const Value.absent()
          : Value(textNormHash),
      charCount: Value(charCount),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      authorId: authorId == null && nullToAbsent
          ? const Value.absent()
          : Value(authorId),
    );
  }

  factory Floor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Floor(
      id: serializer.fromJson<int>(json['id']),
      postId: serializer.fromJson<int>(json['postId']),
      seq: serializer.fromJson<int>(json['seq']),
      pid: serializer.fromJson<int?>(json['pid']),
      content: serializer.fromJson<String>(json['content']),
      textNormHash: serializer.fromJson<String?>(json['textNormHash']),
      charCount: serializer.fromJson<int>(json['charCount']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      authorId: serializer.fromJson<int?>(json['authorId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'postId': serializer.toJson<int>(postId),
      'seq': serializer.toJson<int>(seq),
      'pid': serializer.toJson<int?>(pid),
      'content': serializer.toJson<String>(content),
      'textNormHash': serializer.toJson<String?>(textNormHash),
      'charCount': serializer.toJson<int>(charCount),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'authorId': serializer.toJson<int?>(authorId),
    };
  }

  Floor copyWith({
    int? id,
    int? postId,
    int? seq,
    Value<int?> pid = const Value.absent(),
    String? content,
    Value<String?> textNormHash = const Value.absent(),
    int? charCount,
    Value<DateTime?> createdAt = const Value.absent(),
    Value<int?> authorId = const Value.absent(),
  }) => Floor(
    id: id ?? this.id,
    postId: postId ?? this.postId,
    seq: seq ?? this.seq,
    pid: pid.present ? pid.value : this.pid,
    content: content ?? this.content,
    textNormHash: textNormHash.present ? textNormHash.value : this.textNormHash,
    charCount: charCount ?? this.charCount,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    authorId: authorId.present ? authorId.value : this.authorId,
  );
  Floor copyWithCompanion(FloorsCompanion data) {
    return Floor(
      id: data.id.present ? data.id.value : this.id,
      postId: data.postId.present ? data.postId.value : this.postId,
      seq: data.seq.present ? data.seq.value : this.seq,
      pid: data.pid.present ? data.pid.value : this.pid,
      content: data.content.present ? data.content.value : this.content,
      textNormHash: data.textNormHash.present
          ? data.textNormHash.value
          : this.textNormHash,
      charCount: data.charCount.present ? data.charCount.value : this.charCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      authorId: data.authorId.present ? data.authorId.value : this.authorId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Floor(')
          ..write('id: $id, ')
          ..write('postId: $postId, ')
          ..write('seq: $seq, ')
          ..write('pid: $pid, ')
          ..write('content: $content, ')
          ..write('textNormHash: $textNormHash, ')
          ..write('charCount: $charCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('authorId: $authorId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    postId,
    seq,
    pid,
    content,
    textNormHash,
    charCount,
    createdAt,
    authorId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Floor &&
          other.id == this.id &&
          other.postId == this.postId &&
          other.seq == this.seq &&
          other.pid == this.pid &&
          other.content == this.content &&
          other.textNormHash == this.textNormHash &&
          other.charCount == this.charCount &&
          other.createdAt == this.createdAt &&
          other.authorId == this.authorId);
}

class FloorsCompanion extends UpdateCompanion<Floor> {
  final Value<int> id;
  final Value<int> postId;
  final Value<int> seq;
  final Value<int?> pid;
  final Value<String> content;
  final Value<String?> textNormHash;
  final Value<int> charCount;
  final Value<DateTime?> createdAt;
  final Value<int?> authorId;
  const FloorsCompanion({
    this.id = const Value.absent(),
    this.postId = const Value.absent(),
    this.seq = const Value.absent(),
    this.pid = const Value.absent(),
    this.content = const Value.absent(),
    this.textNormHash = const Value.absent(),
    this.charCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.authorId = const Value.absent(),
  });
  FloorsCompanion.insert({
    this.id = const Value.absent(),
    required int postId,
    required int seq,
    this.pid = const Value.absent(),
    this.content = const Value.absent(),
    this.textNormHash = const Value.absent(),
    this.charCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.authorId = const Value.absent(),
  }) : postId = Value(postId),
       seq = Value(seq);
  static Insertable<Floor> custom({
    Expression<int>? id,
    Expression<int>? postId,
    Expression<int>? seq,
    Expression<int>? pid,
    Expression<String>? content,
    Expression<String>? textNormHash,
    Expression<int>? charCount,
    Expression<DateTime>? createdAt,
    Expression<int>? authorId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (postId != null) 'post_id': postId,
      if (seq != null) 'seq': seq,
      if (pid != null) 'pid': pid,
      if (content != null) 'text': content,
      if (textNormHash != null) 'text_norm_hash': textNormHash,
      if (charCount != null) 'char_count': charCount,
      if (createdAt != null) 'created_at': createdAt,
      if (authorId != null) 'author_id': authorId,
    });
  }

  FloorsCompanion copyWith({
    Value<int>? id,
    Value<int>? postId,
    Value<int>? seq,
    Value<int?>? pid,
    Value<String>? content,
    Value<String?>? textNormHash,
    Value<int>? charCount,
    Value<DateTime?>? createdAt,
    Value<int?>? authorId,
  }) {
    return FloorsCompanion(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      seq: seq ?? this.seq,
      pid: pid ?? this.pid,
      content: content ?? this.content,
      textNormHash: textNormHash ?? this.textNormHash,
      charCount: charCount ?? this.charCount,
      createdAt: createdAt ?? this.createdAt,
      authorId: authorId ?? this.authorId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (postId.present) {
      map['post_id'] = Variable<int>(postId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (pid.present) {
      map['pid'] = Variable<int>(pid.value);
    }
    if (content.present) {
      map['text'] = Variable<String>(content.value);
    }
    if (textNormHash.present) {
      map['text_norm_hash'] = Variable<String>(textNormHash.value);
    }
    if (charCount.present) {
      map['char_count'] = Variable<int>(charCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (authorId.present) {
      map['author_id'] = Variable<int>(authorId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FloorsCompanion(')
          ..write('id: $id, ')
          ..write('postId: $postId, ')
          ..write('seq: $seq, ')
          ..write('pid: $pid, ')
          ..write('content: $content, ')
          ..write('textNormHash: $textNormHash, ')
          ..write('charCount: $charCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('authorId: $authorId')
          ..write(')'))
        .toString();
  }
}

class $ImagesTable extends Images with TableInfo<$ImagesTable, FloorImage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _floorIdMeta = const VerificationMeta(
    'floorId',
  );
  @override
  late final GeneratedColumn<int> floorId = GeneratedColumn<int>(
    'floor_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES floors (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _urlOriginalMeta = const VerificationMeta(
    'urlOriginal',
  );
  @override
  late final GeneratedColumn<String> urlOriginal = GeneratedColumn<String>(
    'url_original',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _urlPermanentMeta = const VerificationMeta(
    'urlPermanent',
  );
  @override
  late final GeneratedColumn<String> urlPermanent = GeneratedColumn<String>(
    'url_permanent',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    floorId,
    urlOriginal,
    urlPermanent,
    width,
    height,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'images';
  @override
  VerificationContext validateIntegrity(
    Insertable<FloorImage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('floor_id')) {
      context.handle(
        _floorIdMeta,
        floorId.isAcceptableOrUnknown(data['floor_id']!, _floorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_floorIdMeta);
    }
    if (data.containsKey('url_original')) {
      context.handle(
        _urlOriginalMeta,
        urlOriginal.isAcceptableOrUnknown(
          data['url_original']!,
          _urlOriginalMeta,
        ),
      );
    }
    if (data.containsKey('url_permanent')) {
      context.handle(
        _urlPermanentMeta,
        urlPermanent.isAcceptableOrUnknown(
          data['url_permanent']!,
          _urlPermanentMeta,
        ),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FloorImage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FloorImage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      floorId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}floor_id'],
      )!,
      urlOriginal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url_original'],
      ),
      urlPermanent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url_permanent'],
      ),
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      )!,
    );
  }

  @override
  $ImagesTable createAlias(String alias) {
    return $ImagesTable(attachedDatabase, alias);
  }
}

class FloorImage extends DataClass implements Insertable<FloorImage> {
  final int id;
  final int floorId;

  /// 接口原始链（cdn_src/origin_src）。
  final String? urlOriginal;

  /// imgsrc 归一化永久链。
  final String? urlPermanent;
  final int width;
  final int height;
  const FloorImage({
    required this.id,
    required this.floorId,
    this.urlOriginal,
    this.urlPermanent,
    required this.width,
    required this.height,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['floor_id'] = Variable<int>(floorId);
    if (!nullToAbsent || urlOriginal != null) {
      map['url_original'] = Variable<String>(urlOriginal);
    }
    if (!nullToAbsent || urlPermanent != null) {
      map['url_permanent'] = Variable<String>(urlPermanent);
    }
    map['width'] = Variable<int>(width);
    map['height'] = Variable<int>(height);
    return map;
  }

  ImagesCompanion toCompanion(bool nullToAbsent) {
    return ImagesCompanion(
      id: Value(id),
      floorId: Value(floorId),
      urlOriginal: urlOriginal == null && nullToAbsent
          ? const Value.absent()
          : Value(urlOriginal),
      urlPermanent: urlPermanent == null && nullToAbsent
          ? const Value.absent()
          : Value(urlPermanent),
      width: Value(width),
      height: Value(height),
    );
  }

  factory FloorImage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FloorImage(
      id: serializer.fromJson<int>(json['id']),
      floorId: serializer.fromJson<int>(json['floorId']),
      urlOriginal: serializer.fromJson<String?>(json['urlOriginal']),
      urlPermanent: serializer.fromJson<String?>(json['urlPermanent']),
      width: serializer.fromJson<int>(json['width']),
      height: serializer.fromJson<int>(json['height']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'floorId': serializer.toJson<int>(floorId),
      'urlOriginal': serializer.toJson<String?>(urlOriginal),
      'urlPermanent': serializer.toJson<String?>(urlPermanent),
      'width': serializer.toJson<int>(width),
      'height': serializer.toJson<int>(height),
    };
  }

  FloorImage copyWith({
    int? id,
    int? floorId,
    Value<String?> urlOriginal = const Value.absent(),
    Value<String?> urlPermanent = const Value.absent(),
    int? width,
    int? height,
  }) => FloorImage(
    id: id ?? this.id,
    floorId: floorId ?? this.floorId,
    urlOriginal: urlOriginal.present ? urlOriginal.value : this.urlOriginal,
    urlPermanent: urlPermanent.present ? urlPermanent.value : this.urlPermanent,
    width: width ?? this.width,
    height: height ?? this.height,
  );
  FloorImage copyWithCompanion(ImagesCompanion data) {
    return FloorImage(
      id: data.id.present ? data.id.value : this.id,
      floorId: data.floorId.present ? data.floorId.value : this.floorId,
      urlOriginal: data.urlOriginal.present
          ? data.urlOriginal.value
          : this.urlOriginal,
      urlPermanent: data.urlPermanent.present
          ? data.urlPermanent.value
          : this.urlPermanent,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FloorImage(')
          ..write('id: $id, ')
          ..write('floorId: $floorId, ')
          ..write('urlOriginal: $urlOriginal, ')
          ..write('urlPermanent: $urlPermanent, ')
          ..write('width: $width, ')
          ..write('height: $height')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, floorId, urlOriginal, urlPermanent, width, height);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FloorImage &&
          other.id == this.id &&
          other.floorId == this.floorId &&
          other.urlOriginal == this.urlOriginal &&
          other.urlPermanent == this.urlPermanent &&
          other.width == this.width &&
          other.height == this.height);
}

class ImagesCompanion extends UpdateCompanion<FloorImage> {
  final Value<int> id;
  final Value<int> floorId;
  final Value<String?> urlOriginal;
  final Value<String?> urlPermanent;
  final Value<int> width;
  final Value<int> height;
  const ImagesCompanion({
    this.id = const Value.absent(),
    this.floorId = const Value.absent(),
    this.urlOriginal = const Value.absent(),
    this.urlPermanent = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
  });
  ImagesCompanion.insert({
    this.id = const Value.absent(),
    required int floorId,
    this.urlOriginal = const Value.absent(),
    this.urlPermanent = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
  }) : floorId = Value(floorId);
  static Insertable<FloorImage> custom({
    Expression<int>? id,
    Expression<int>? floorId,
    Expression<String>? urlOriginal,
    Expression<String>? urlPermanent,
    Expression<int>? width,
    Expression<int>? height,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (floorId != null) 'floor_id': floorId,
      if (urlOriginal != null) 'url_original': urlOriginal,
      if (urlPermanent != null) 'url_permanent': urlPermanent,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
    });
  }

  ImagesCompanion copyWith({
    Value<int>? id,
    Value<int>? floorId,
    Value<String?>? urlOriginal,
    Value<String?>? urlPermanent,
    Value<int>? width,
    Value<int>? height,
  }) {
    return ImagesCompanion(
      id: id ?? this.id,
      floorId: floorId ?? this.floorId,
      urlOriginal: urlOriginal ?? this.urlOriginal,
      urlPermanent: urlPermanent ?? this.urlPermanent,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (floorId.present) {
      map['floor_id'] = Variable<int>(floorId.value);
    }
    if (urlOriginal.present) {
      map['url_original'] = Variable<String>(urlOriginal.value);
    }
    if (urlPermanent.present) {
      map['url_permanent'] = Variable<String>(urlPermanent.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImagesCompanion(')
          ..write('id: $id, ')
          ..write('floorId: $floorId, ')
          ..write('urlOriginal: $urlOriginal, ')
          ..write('urlPermanent: $urlPermanent, ')
          ..write('width: $width, ')
          ..write('height: $height')
          ..write(')'))
        .toString();
  }
}

class $BookEntriesTable extends BookEntries
    with TableInfo<$BookEntriesTable, BookEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameNormMeta = const VerificationMeta(
    'nameNorm',
  );
  @override
  late final GeneratedColumn<String> nameNorm = GeneratedColumn<String>(
    'name_norm',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorNormMeta = const VerificationMeta(
    'authorNorm',
  );
  @override
  late final GeneratedColumn<String> authorNorm = GeneratedColumn<String>(
    'author_norm',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorKindMeta = const VerificationMeta(
    'authorKind',
  );
  @override
  late final GeneratedColumn<String> authorKind = GeneratedColumn<String>(
    'author_kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recommenderMeta = const VerificationMeta(
    'recommender',
  );
  @override
  late final GeneratedColumn<String> recommender = GeneratedColumn<String>(
    'recommender',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _commentMeta = const VerificationMeta(
    'comment',
  );
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
    'comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _commentSrcMeta = const VerificationMeta(
    'commentSrc',
  );
  @override
  late final GeneratedColumn<String> commentSrc = GeneratedColumn<String>(
    'comment_src',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _commentNormHashMeta = const VerificationMeta(
    'commentNormHash',
  );
  @override
  late final GeneratedColumn<String> commentNormHash = GeneratedColumn<String>(
    'comment_norm_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateRawMeta = const VerificationMeta(
    'dateRaw',
  );
  @override
  late final GeneratedColumn<String> dateRaw = GeneratedColumn<String>(
    'date_raw',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _channelMeta = const VerificationMeta(
    'channel',
  );
  @override
  late final GeneratedColumn<String> channel = GeneratedColumn<String>(
    'channel',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subChannelMeta = const VerificationMeta(
    'subChannel',
  );
  @override
  late final GeneratedColumn<String> subChannel = GeneratedColumn<String>(
    'sub_channel',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('扫书'),
  );
  static const VerificationMeta _postRefMeta = const VerificationMeta(
    'postRef',
  );
  @override
  late final GeneratedColumn<int> postRef = GeneratedColumn<int>(
    'post_ref',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES posts (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _floorRefMeta = const VerificationMeta(
    'floorRef',
  );
  @override
  late final GeneratedColumn<int> floorRef = GeneratedColumn<int>(
    'floor_ref',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES floors (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _srcTidMeta = const VerificationMeta('srcTid');
  @override
  late final GeneratedColumn<int> srcTid = GeneratedColumn<int>(
    'src_tid',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _srcUrlMeta = const VerificationMeta('srcUrl');
  @override
  late final GeneratedColumn<String> srcUrl = GeneratedColumn<String>(
    'src_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wordCountMeta = const VerificationMeta(
    'wordCount',
  );
  @override
  late final GeneratedColumn<int> wordCount = GeneratedColumn<int>(
    'word_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bookGradeMeta = const VerificationMeta(
    'bookGrade',
  );
  @override
  late final GeneratedColumn<String> bookGrade = GeneratedColumn<String>(
    'book_grade',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _qualityMeta = const VerificationMeta(
    'quality',
  );
  @override
  late final GeneratedColumn<int> quality = GeneratedColumn<int>(
    'quality',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _bookGroupIdMeta = const VerificationMeta(
    'bookGroupId',
  );
  @override
  late final GeneratedColumn<int> bookGroupId = GeneratedColumn<int>(
    'book_group_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('builtin'),
  );
  static const VerificationMeta _collectedAtMeta = const VerificationMeta(
    'collectedAt',
  );
  @override
  late final GeneratedColumn<DateTime> collectedAt = GeneratedColumn<DateTime>(
    'collected_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    nameNorm,
    author,
    authorNorm,
    authorKind,
    recommender,
    comment,
    commentSrc,
    commentNormHash,
    date,
    dateRaw,
    channel,
    subChannel,
    category,
    postRef,
    floorRef,
    srcTid,
    srcUrl,
    wordCount,
    bookGrade,
    quality,
    contentHash,
    bookGroupId,
    origin,
    collectedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('name_norm')) {
      context.handle(
        _nameNormMeta,
        nameNorm.isAcceptableOrUnknown(data['name_norm']!, _nameNormMeta),
      );
    } else if (isInserting) {
      context.missing(_nameNormMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('author_norm')) {
      context.handle(
        _authorNormMeta,
        authorNorm.isAcceptableOrUnknown(data['author_norm']!, _authorNormMeta),
      );
    }
    if (data.containsKey('author_kind')) {
      context.handle(
        _authorKindMeta,
        authorKind.isAcceptableOrUnknown(data['author_kind']!, _authorKindMeta),
      );
    }
    if (data.containsKey('recommender')) {
      context.handle(
        _recommenderMeta,
        recommender.isAcceptableOrUnknown(
          data['recommender']!,
          _recommenderMeta,
        ),
      );
    }
    if (data.containsKey('comment')) {
      context.handle(
        _commentMeta,
        comment.isAcceptableOrUnknown(data['comment']!, _commentMeta),
      );
    }
    if (data.containsKey('comment_src')) {
      context.handle(
        _commentSrcMeta,
        commentSrc.isAcceptableOrUnknown(data['comment_src']!, _commentSrcMeta),
      );
    }
    if (data.containsKey('comment_norm_hash')) {
      context.handle(
        _commentNormHashMeta,
        commentNormHash.isAcceptableOrUnknown(
          data['comment_norm_hash']!,
          _commentNormHashMeta,
        ),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    if (data.containsKey('date_raw')) {
      context.handle(
        _dateRawMeta,
        dateRaw.isAcceptableOrUnknown(data['date_raw']!, _dateRawMeta),
      );
    }
    if (data.containsKey('channel')) {
      context.handle(
        _channelMeta,
        channel.isAcceptableOrUnknown(data['channel']!, _channelMeta),
      );
    } else if (isInserting) {
      context.missing(_channelMeta);
    }
    if (data.containsKey('sub_channel')) {
      context.handle(
        _subChannelMeta,
        subChannel.isAcceptableOrUnknown(data['sub_channel']!, _subChannelMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('post_ref')) {
      context.handle(
        _postRefMeta,
        postRef.isAcceptableOrUnknown(data['post_ref']!, _postRefMeta),
      );
    }
    if (data.containsKey('floor_ref')) {
      context.handle(
        _floorRefMeta,
        floorRef.isAcceptableOrUnknown(data['floor_ref']!, _floorRefMeta),
      );
    }
    if (data.containsKey('src_tid')) {
      context.handle(
        _srcTidMeta,
        srcTid.isAcceptableOrUnknown(data['src_tid']!, _srcTidMeta),
      );
    }
    if (data.containsKey('src_url')) {
      context.handle(
        _srcUrlMeta,
        srcUrl.isAcceptableOrUnknown(data['src_url']!, _srcUrlMeta),
      );
    }
    if (data.containsKey('word_count')) {
      context.handle(
        _wordCountMeta,
        wordCount.isAcceptableOrUnknown(data['word_count']!, _wordCountMeta),
      );
    }
    if (data.containsKey('book_grade')) {
      context.handle(
        _bookGradeMeta,
        bookGrade.isAcceptableOrUnknown(data['book_grade']!, _bookGradeMeta),
      );
    }
    if (data.containsKey('quality')) {
      context.handle(
        _qualityMeta,
        quality.isAcceptableOrUnknown(data['quality']!, _qualityMeta),
      );
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('book_group_id')) {
      context.handle(
        _bookGroupIdMeta,
        bookGroupId.isAcceptableOrUnknown(
          data['book_group_id']!,
          _bookGroupIdMeta,
        ),
      );
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    }
    if (data.containsKey('collected_at')) {
      context.handle(
        _collectedAtMeta,
        collectedAt.isAcceptableOrUnknown(
          data['collected_at']!,
          _collectedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      nameNorm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_norm'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      authorNorm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_norm'],
      ),
      authorKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_kind'],
      ),
      recommender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recommender'],
      ),
      comment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment'],
      ),
      commentSrc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment_src'],
      ),
      commentNormHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment_norm_hash'],
      ),
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      ),
      dateRaw: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_raw'],
      ),
      channel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel'],
      )!,
      subChannel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sub_channel'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      postRef: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}post_ref'],
      ),
      floorRef: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}floor_ref'],
      ),
      srcTid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}src_tid'],
      ),
      srcUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}src_url'],
      ),
      wordCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}word_count'],
      ),
      bookGrade: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_grade'],
      ),
      quality: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quality'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      bookGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}book_group_id'],
      ),
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      )!,
      collectedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}collected_at'],
      ),
    );
  }

  @override
  $BookEntriesTable createAlias(String alias) {
    return $BookEntriesTable(attachedDatabase, alias);
  }
}

class BookEntry extends DataClass implements Insertable<BookEntry> {
  final int id;

  /// 书名（含《》原样或裸名，存原值）。
  final String name;

  /// 归一化书名（检索/聚合键）。
  final String nameNorm;

  /// 小说作者。
  final String? author;
  final String? authorNorm;

  /// novel_author/inferred/parsed。
  final String? authorKind;

  /// 推荐人（发帖人/大佬名）。
  final String? recommender;

  /// 推荐语。
  final String? comment;

  /// clist_item/saoshu_floor_single/dalao_review/collected_floor。
  final String? commentSrc;
  final String? commentNormHash;

  /// 'YYYY-MM-DD'，CHECK 同 unified。
  final String? date;
  final String? dateRaw;
  final String channel;
  final String? subChannel;

  /// 冗余自 posts.post_kind（扫书/排雷/求书/日常），避免搜索 join；排雷筛选维度走此列。
  final String category;
  final int? postRef;
  final int? floorRef;
  final int? srcTid;
  final String? srcUrl;
  final int? wordCount;

  /// 大佬评级 hex（#11850A/#FF0000/#000000）。
  final String? bookGrade;

  /// 3=作者+推荐语 2=推荐语 1=仅推荐人。
  final int quality;

  /// sha1(nameNorm+0x1f+authorNorm+0x1f+commentNormHash)[:16] 去重键。
  final String contentHash;
  final int? bookGroupId;
  final String origin;
  final DateTime? collectedAt;
  const BookEntry({
    required this.id,
    required this.name,
    required this.nameNorm,
    this.author,
    this.authorNorm,
    this.authorKind,
    this.recommender,
    this.comment,
    this.commentSrc,
    this.commentNormHash,
    this.date,
    this.dateRaw,
    required this.channel,
    this.subChannel,
    required this.category,
    this.postRef,
    this.floorRef,
    this.srcTid,
    this.srcUrl,
    this.wordCount,
    this.bookGrade,
    required this.quality,
    required this.contentHash,
    this.bookGroupId,
    required this.origin,
    this.collectedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['name_norm'] = Variable<String>(nameNorm);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || authorNorm != null) {
      map['author_norm'] = Variable<String>(authorNorm);
    }
    if (!nullToAbsent || authorKind != null) {
      map['author_kind'] = Variable<String>(authorKind);
    }
    if (!nullToAbsent || recommender != null) {
      map['recommender'] = Variable<String>(recommender);
    }
    if (!nullToAbsent || comment != null) {
      map['comment'] = Variable<String>(comment);
    }
    if (!nullToAbsent || commentSrc != null) {
      map['comment_src'] = Variable<String>(commentSrc);
    }
    if (!nullToAbsent || commentNormHash != null) {
      map['comment_norm_hash'] = Variable<String>(commentNormHash);
    }
    if (!nullToAbsent || date != null) {
      map['date'] = Variable<String>(date);
    }
    if (!nullToAbsent || dateRaw != null) {
      map['date_raw'] = Variable<String>(dateRaw);
    }
    map['channel'] = Variable<String>(channel);
    if (!nullToAbsent || subChannel != null) {
      map['sub_channel'] = Variable<String>(subChannel);
    }
    map['category'] = Variable<String>(category);
    if (!nullToAbsent || postRef != null) {
      map['post_ref'] = Variable<int>(postRef);
    }
    if (!nullToAbsent || floorRef != null) {
      map['floor_ref'] = Variable<int>(floorRef);
    }
    if (!nullToAbsent || srcTid != null) {
      map['src_tid'] = Variable<int>(srcTid);
    }
    if (!nullToAbsent || srcUrl != null) {
      map['src_url'] = Variable<String>(srcUrl);
    }
    if (!nullToAbsent || wordCount != null) {
      map['word_count'] = Variable<int>(wordCount);
    }
    if (!nullToAbsent || bookGrade != null) {
      map['book_grade'] = Variable<String>(bookGrade);
    }
    map['quality'] = Variable<int>(quality);
    map['content_hash'] = Variable<String>(contentHash);
    if (!nullToAbsent || bookGroupId != null) {
      map['book_group_id'] = Variable<int>(bookGroupId);
    }
    map['origin'] = Variable<String>(origin);
    if (!nullToAbsent || collectedAt != null) {
      map['collected_at'] = Variable<DateTime>(collectedAt);
    }
    return map;
  }

  BookEntriesCompanion toCompanion(bool nullToAbsent) {
    return BookEntriesCompanion(
      id: Value(id),
      name: Value(name),
      nameNorm: Value(nameNorm),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      authorNorm: authorNorm == null && nullToAbsent
          ? const Value.absent()
          : Value(authorNorm),
      authorKind: authorKind == null && nullToAbsent
          ? const Value.absent()
          : Value(authorKind),
      recommender: recommender == null && nullToAbsent
          ? const Value.absent()
          : Value(recommender),
      comment: comment == null && nullToAbsent
          ? const Value.absent()
          : Value(comment),
      commentSrc: commentSrc == null && nullToAbsent
          ? const Value.absent()
          : Value(commentSrc),
      commentNormHash: commentNormHash == null && nullToAbsent
          ? const Value.absent()
          : Value(commentNormHash),
      date: date == null && nullToAbsent ? const Value.absent() : Value(date),
      dateRaw: dateRaw == null && nullToAbsent
          ? const Value.absent()
          : Value(dateRaw),
      channel: Value(channel),
      subChannel: subChannel == null && nullToAbsent
          ? const Value.absent()
          : Value(subChannel),
      category: Value(category),
      postRef: postRef == null && nullToAbsent
          ? const Value.absent()
          : Value(postRef),
      floorRef: floorRef == null && nullToAbsent
          ? const Value.absent()
          : Value(floorRef),
      srcTid: srcTid == null && nullToAbsent
          ? const Value.absent()
          : Value(srcTid),
      srcUrl: srcUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(srcUrl),
      wordCount: wordCount == null && nullToAbsent
          ? const Value.absent()
          : Value(wordCount),
      bookGrade: bookGrade == null && nullToAbsent
          ? const Value.absent()
          : Value(bookGrade),
      quality: Value(quality),
      contentHash: Value(contentHash),
      bookGroupId: bookGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(bookGroupId),
      origin: Value(origin),
      collectedAt: collectedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(collectedAt),
    );
  }

  factory BookEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookEntry(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      nameNorm: serializer.fromJson<String>(json['nameNorm']),
      author: serializer.fromJson<String?>(json['author']),
      authorNorm: serializer.fromJson<String?>(json['authorNorm']),
      authorKind: serializer.fromJson<String?>(json['authorKind']),
      recommender: serializer.fromJson<String?>(json['recommender']),
      comment: serializer.fromJson<String?>(json['comment']),
      commentSrc: serializer.fromJson<String?>(json['commentSrc']),
      commentNormHash: serializer.fromJson<String?>(json['commentNormHash']),
      date: serializer.fromJson<String?>(json['date']),
      dateRaw: serializer.fromJson<String?>(json['dateRaw']),
      channel: serializer.fromJson<String>(json['channel']),
      subChannel: serializer.fromJson<String?>(json['subChannel']),
      category: serializer.fromJson<String>(json['category']),
      postRef: serializer.fromJson<int?>(json['postRef']),
      floorRef: serializer.fromJson<int?>(json['floorRef']),
      srcTid: serializer.fromJson<int?>(json['srcTid']),
      srcUrl: serializer.fromJson<String?>(json['srcUrl']),
      wordCount: serializer.fromJson<int?>(json['wordCount']),
      bookGrade: serializer.fromJson<String?>(json['bookGrade']),
      quality: serializer.fromJson<int>(json['quality']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      bookGroupId: serializer.fromJson<int?>(json['bookGroupId']),
      origin: serializer.fromJson<String>(json['origin']),
      collectedAt: serializer.fromJson<DateTime?>(json['collectedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'nameNorm': serializer.toJson<String>(nameNorm),
      'author': serializer.toJson<String?>(author),
      'authorNorm': serializer.toJson<String?>(authorNorm),
      'authorKind': serializer.toJson<String?>(authorKind),
      'recommender': serializer.toJson<String?>(recommender),
      'comment': serializer.toJson<String?>(comment),
      'commentSrc': serializer.toJson<String?>(commentSrc),
      'commentNormHash': serializer.toJson<String?>(commentNormHash),
      'date': serializer.toJson<String?>(date),
      'dateRaw': serializer.toJson<String?>(dateRaw),
      'channel': serializer.toJson<String>(channel),
      'subChannel': serializer.toJson<String?>(subChannel),
      'category': serializer.toJson<String>(category),
      'postRef': serializer.toJson<int?>(postRef),
      'floorRef': serializer.toJson<int?>(floorRef),
      'srcTid': serializer.toJson<int?>(srcTid),
      'srcUrl': serializer.toJson<String?>(srcUrl),
      'wordCount': serializer.toJson<int?>(wordCount),
      'bookGrade': serializer.toJson<String?>(bookGrade),
      'quality': serializer.toJson<int>(quality),
      'contentHash': serializer.toJson<String>(contentHash),
      'bookGroupId': serializer.toJson<int?>(bookGroupId),
      'origin': serializer.toJson<String>(origin),
      'collectedAt': serializer.toJson<DateTime?>(collectedAt),
    };
  }

  BookEntry copyWith({
    int? id,
    String? name,
    String? nameNorm,
    Value<String?> author = const Value.absent(),
    Value<String?> authorNorm = const Value.absent(),
    Value<String?> authorKind = const Value.absent(),
    Value<String?> recommender = const Value.absent(),
    Value<String?> comment = const Value.absent(),
    Value<String?> commentSrc = const Value.absent(),
    Value<String?> commentNormHash = const Value.absent(),
    Value<String?> date = const Value.absent(),
    Value<String?> dateRaw = const Value.absent(),
    String? channel,
    Value<String?> subChannel = const Value.absent(),
    String? category,
    Value<int?> postRef = const Value.absent(),
    Value<int?> floorRef = const Value.absent(),
    Value<int?> srcTid = const Value.absent(),
    Value<String?> srcUrl = const Value.absent(),
    Value<int?> wordCount = const Value.absent(),
    Value<String?> bookGrade = const Value.absent(),
    int? quality,
    String? contentHash,
    Value<int?> bookGroupId = const Value.absent(),
    String? origin,
    Value<DateTime?> collectedAt = const Value.absent(),
  }) => BookEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    nameNorm: nameNorm ?? this.nameNorm,
    author: author.present ? author.value : this.author,
    authorNorm: authorNorm.present ? authorNorm.value : this.authorNorm,
    authorKind: authorKind.present ? authorKind.value : this.authorKind,
    recommender: recommender.present ? recommender.value : this.recommender,
    comment: comment.present ? comment.value : this.comment,
    commentSrc: commentSrc.present ? commentSrc.value : this.commentSrc,
    commentNormHash: commentNormHash.present
        ? commentNormHash.value
        : this.commentNormHash,
    date: date.present ? date.value : this.date,
    dateRaw: dateRaw.present ? dateRaw.value : this.dateRaw,
    channel: channel ?? this.channel,
    subChannel: subChannel.present ? subChannel.value : this.subChannel,
    category: category ?? this.category,
    postRef: postRef.present ? postRef.value : this.postRef,
    floorRef: floorRef.present ? floorRef.value : this.floorRef,
    srcTid: srcTid.present ? srcTid.value : this.srcTid,
    srcUrl: srcUrl.present ? srcUrl.value : this.srcUrl,
    wordCount: wordCount.present ? wordCount.value : this.wordCount,
    bookGrade: bookGrade.present ? bookGrade.value : this.bookGrade,
    quality: quality ?? this.quality,
    contentHash: contentHash ?? this.contentHash,
    bookGroupId: bookGroupId.present ? bookGroupId.value : this.bookGroupId,
    origin: origin ?? this.origin,
    collectedAt: collectedAt.present ? collectedAt.value : this.collectedAt,
  );
  BookEntry copyWithCompanion(BookEntriesCompanion data) {
    return BookEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      nameNorm: data.nameNorm.present ? data.nameNorm.value : this.nameNorm,
      author: data.author.present ? data.author.value : this.author,
      authorNorm: data.authorNorm.present
          ? data.authorNorm.value
          : this.authorNorm,
      authorKind: data.authorKind.present
          ? data.authorKind.value
          : this.authorKind,
      recommender: data.recommender.present
          ? data.recommender.value
          : this.recommender,
      comment: data.comment.present ? data.comment.value : this.comment,
      commentSrc: data.commentSrc.present
          ? data.commentSrc.value
          : this.commentSrc,
      commentNormHash: data.commentNormHash.present
          ? data.commentNormHash.value
          : this.commentNormHash,
      date: data.date.present ? data.date.value : this.date,
      dateRaw: data.dateRaw.present ? data.dateRaw.value : this.dateRaw,
      channel: data.channel.present ? data.channel.value : this.channel,
      subChannel: data.subChannel.present
          ? data.subChannel.value
          : this.subChannel,
      category: data.category.present ? data.category.value : this.category,
      postRef: data.postRef.present ? data.postRef.value : this.postRef,
      floorRef: data.floorRef.present ? data.floorRef.value : this.floorRef,
      srcTid: data.srcTid.present ? data.srcTid.value : this.srcTid,
      srcUrl: data.srcUrl.present ? data.srcUrl.value : this.srcUrl,
      wordCount: data.wordCount.present ? data.wordCount.value : this.wordCount,
      bookGrade: data.bookGrade.present ? data.bookGrade.value : this.bookGrade,
      quality: data.quality.present ? data.quality.value : this.quality,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      bookGroupId: data.bookGroupId.present
          ? data.bookGroupId.value
          : this.bookGroupId,
      origin: data.origin.present ? data.origin.value : this.origin,
      collectedAt: data.collectedAt.present
          ? data.collectedAt.value
          : this.collectedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('nameNorm: $nameNorm, ')
          ..write('author: $author, ')
          ..write('authorNorm: $authorNorm, ')
          ..write('authorKind: $authorKind, ')
          ..write('recommender: $recommender, ')
          ..write('comment: $comment, ')
          ..write('commentSrc: $commentSrc, ')
          ..write('commentNormHash: $commentNormHash, ')
          ..write('date: $date, ')
          ..write('dateRaw: $dateRaw, ')
          ..write('channel: $channel, ')
          ..write('subChannel: $subChannel, ')
          ..write('category: $category, ')
          ..write('postRef: $postRef, ')
          ..write('floorRef: $floorRef, ')
          ..write('srcTid: $srcTid, ')
          ..write('srcUrl: $srcUrl, ')
          ..write('wordCount: $wordCount, ')
          ..write('bookGrade: $bookGrade, ')
          ..write('quality: $quality, ')
          ..write('contentHash: $contentHash, ')
          ..write('bookGroupId: $bookGroupId, ')
          ..write('origin: $origin, ')
          ..write('collectedAt: $collectedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    nameNorm,
    author,
    authorNorm,
    authorKind,
    recommender,
    comment,
    commentSrc,
    commentNormHash,
    date,
    dateRaw,
    channel,
    subChannel,
    category,
    postRef,
    floorRef,
    srcTid,
    srcUrl,
    wordCount,
    bookGrade,
    quality,
    contentHash,
    bookGroupId,
    origin,
    collectedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.nameNorm == this.nameNorm &&
          other.author == this.author &&
          other.authorNorm == this.authorNorm &&
          other.authorKind == this.authorKind &&
          other.recommender == this.recommender &&
          other.comment == this.comment &&
          other.commentSrc == this.commentSrc &&
          other.commentNormHash == this.commentNormHash &&
          other.date == this.date &&
          other.dateRaw == this.dateRaw &&
          other.channel == this.channel &&
          other.subChannel == this.subChannel &&
          other.category == this.category &&
          other.postRef == this.postRef &&
          other.floorRef == this.floorRef &&
          other.srcTid == this.srcTid &&
          other.srcUrl == this.srcUrl &&
          other.wordCount == this.wordCount &&
          other.bookGrade == this.bookGrade &&
          other.quality == this.quality &&
          other.contentHash == this.contentHash &&
          other.bookGroupId == this.bookGroupId &&
          other.origin == this.origin &&
          other.collectedAt == this.collectedAt);
}

class BookEntriesCompanion extends UpdateCompanion<BookEntry> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> nameNorm;
  final Value<String?> author;
  final Value<String?> authorNorm;
  final Value<String?> authorKind;
  final Value<String?> recommender;
  final Value<String?> comment;
  final Value<String?> commentSrc;
  final Value<String?> commentNormHash;
  final Value<String?> date;
  final Value<String?> dateRaw;
  final Value<String> channel;
  final Value<String?> subChannel;
  final Value<String> category;
  final Value<int?> postRef;
  final Value<int?> floorRef;
  final Value<int?> srcTid;
  final Value<String?> srcUrl;
  final Value<int?> wordCount;
  final Value<String?> bookGrade;
  final Value<int> quality;
  final Value<String> contentHash;
  final Value<int?> bookGroupId;
  final Value<String> origin;
  final Value<DateTime?> collectedAt;
  const BookEntriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.nameNorm = const Value.absent(),
    this.author = const Value.absent(),
    this.authorNorm = const Value.absent(),
    this.authorKind = const Value.absent(),
    this.recommender = const Value.absent(),
    this.comment = const Value.absent(),
    this.commentSrc = const Value.absent(),
    this.commentNormHash = const Value.absent(),
    this.date = const Value.absent(),
    this.dateRaw = const Value.absent(),
    this.channel = const Value.absent(),
    this.subChannel = const Value.absent(),
    this.category = const Value.absent(),
    this.postRef = const Value.absent(),
    this.floorRef = const Value.absent(),
    this.srcTid = const Value.absent(),
    this.srcUrl = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.bookGrade = const Value.absent(),
    this.quality = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.bookGroupId = const Value.absent(),
    this.origin = const Value.absent(),
    this.collectedAt = const Value.absent(),
  });
  BookEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String nameNorm,
    this.author = const Value.absent(),
    this.authorNorm = const Value.absent(),
    this.authorKind = const Value.absent(),
    this.recommender = const Value.absent(),
    this.comment = const Value.absent(),
    this.commentSrc = const Value.absent(),
    this.commentNormHash = const Value.absent(),
    this.date = const Value.absent(),
    this.dateRaw = const Value.absent(),
    required String channel,
    this.subChannel = const Value.absent(),
    this.category = const Value.absent(),
    this.postRef = const Value.absent(),
    this.floorRef = const Value.absent(),
    this.srcTid = const Value.absent(),
    this.srcUrl = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.bookGrade = const Value.absent(),
    this.quality = const Value.absent(),
    required String contentHash,
    this.bookGroupId = const Value.absent(),
    this.origin = const Value.absent(),
    this.collectedAt = const Value.absent(),
  }) : name = Value(name),
       nameNorm = Value(nameNorm),
       channel = Value(channel),
       contentHash = Value(contentHash);
  static Insertable<BookEntry> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? nameNorm,
    Expression<String>? author,
    Expression<String>? authorNorm,
    Expression<String>? authorKind,
    Expression<String>? recommender,
    Expression<String>? comment,
    Expression<String>? commentSrc,
    Expression<String>? commentNormHash,
    Expression<String>? date,
    Expression<String>? dateRaw,
    Expression<String>? channel,
    Expression<String>? subChannel,
    Expression<String>? category,
    Expression<int>? postRef,
    Expression<int>? floorRef,
    Expression<int>? srcTid,
    Expression<String>? srcUrl,
    Expression<int>? wordCount,
    Expression<String>? bookGrade,
    Expression<int>? quality,
    Expression<String>? contentHash,
    Expression<int>? bookGroupId,
    Expression<String>? origin,
    Expression<DateTime>? collectedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (nameNorm != null) 'name_norm': nameNorm,
      if (author != null) 'author': author,
      if (authorNorm != null) 'author_norm': authorNorm,
      if (authorKind != null) 'author_kind': authorKind,
      if (recommender != null) 'recommender': recommender,
      if (comment != null) 'comment': comment,
      if (commentSrc != null) 'comment_src': commentSrc,
      if (commentNormHash != null) 'comment_norm_hash': commentNormHash,
      if (date != null) 'date': date,
      if (dateRaw != null) 'date_raw': dateRaw,
      if (channel != null) 'channel': channel,
      if (subChannel != null) 'sub_channel': subChannel,
      if (category != null) 'category': category,
      if (postRef != null) 'post_ref': postRef,
      if (floorRef != null) 'floor_ref': floorRef,
      if (srcTid != null) 'src_tid': srcTid,
      if (srcUrl != null) 'src_url': srcUrl,
      if (wordCount != null) 'word_count': wordCount,
      if (bookGrade != null) 'book_grade': bookGrade,
      if (quality != null) 'quality': quality,
      if (contentHash != null) 'content_hash': contentHash,
      if (bookGroupId != null) 'book_group_id': bookGroupId,
      if (origin != null) 'origin': origin,
      if (collectedAt != null) 'collected_at': collectedAt,
    });
  }

  BookEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? nameNorm,
    Value<String?>? author,
    Value<String?>? authorNorm,
    Value<String?>? authorKind,
    Value<String?>? recommender,
    Value<String?>? comment,
    Value<String?>? commentSrc,
    Value<String?>? commentNormHash,
    Value<String?>? date,
    Value<String?>? dateRaw,
    Value<String>? channel,
    Value<String?>? subChannel,
    Value<String>? category,
    Value<int?>? postRef,
    Value<int?>? floorRef,
    Value<int?>? srcTid,
    Value<String?>? srcUrl,
    Value<int?>? wordCount,
    Value<String?>? bookGrade,
    Value<int>? quality,
    Value<String>? contentHash,
    Value<int?>? bookGroupId,
    Value<String>? origin,
    Value<DateTime?>? collectedAt,
  }) {
    return BookEntriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      nameNorm: nameNorm ?? this.nameNorm,
      author: author ?? this.author,
      authorNorm: authorNorm ?? this.authorNorm,
      authorKind: authorKind ?? this.authorKind,
      recommender: recommender ?? this.recommender,
      comment: comment ?? this.comment,
      commentSrc: commentSrc ?? this.commentSrc,
      commentNormHash: commentNormHash ?? this.commentNormHash,
      date: date ?? this.date,
      dateRaw: dateRaw ?? this.dateRaw,
      channel: channel ?? this.channel,
      subChannel: subChannel ?? this.subChannel,
      category: category ?? this.category,
      postRef: postRef ?? this.postRef,
      floorRef: floorRef ?? this.floorRef,
      srcTid: srcTid ?? this.srcTid,
      srcUrl: srcUrl ?? this.srcUrl,
      wordCount: wordCount ?? this.wordCount,
      bookGrade: bookGrade ?? this.bookGrade,
      quality: quality ?? this.quality,
      contentHash: contentHash ?? this.contentHash,
      bookGroupId: bookGroupId ?? this.bookGroupId,
      origin: origin ?? this.origin,
      collectedAt: collectedAt ?? this.collectedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nameNorm.present) {
      map['name_norm'] = Variable<String>(nameNorm.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (authorNorm.present) {
      map['author_norm'] = Variable<String>(authorNorm.value);
    }
    if (authorKind.present) {
      map['author_kind'] = Variable<String>(authorKind.value);
    }
    if (recommender.present) {
      map['recommender'] = Variable<String>(recommender.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (commentSrc.present) {
      map['comment_src'] = Variable<String>(commentSrc.value);
    }
    if (commentNormHash.present) {
      map['comment_norm_hash'] = Variable<String>(commentNormHash.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (dateRaw.present) {
      map['date_raw'] = Variable<String>(dateRaw.value);
    }
    if (channel.present) {
      map['channel'] = Variable<String>(channel.value);
    }
    if (subChannel.present) {
      map['sub_channel'] = Variable<String>(subChannel.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (postRef.present) {
      map['post_ref'] = Variable<int>(postRef.value);
    }
    if (floorRef.present) {
      map['floor_ref'] = Variable<int>(floorRef.value);
    }
    if (srcTid.present) {
      map['src_tid'] = Variable<int>(srcTid.value);
    }
    if (srcUrl.present) {
      map['src_url'] = Variable<String>(srcUrl.value);
    }
    if (wordCount.present) {
      map['word_count'] = Variable<int>(wordCount.value);
    }
    if (bookGrade.present) {
      map['book_grade'] = Variable<String>(bookGrade.value);
    }
    if (quality.present) {
      map['quality'] = Variable<int>(quality.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (bookGroupId.present) {
      map['book_group_id'] = Variable<int>(bookGroupId.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (collectedAt.present) {
      map['collected_at'] = Variable<DateTime>(collectedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookEntriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('nameNorm: $nameNorm, ')
          ..write('author: $author, ')
          ..write('authorNorm: $authorNorm, ')
          ..write('authorKind: $authorKind, ')
          ..write('recommender: $recommender, ')
          ..write('comment: $comment, ')
          ..write('commentSrc: $commentSrc, ')
          ..write('commentNormHash: $commentNormHash, ')
          ..write('date: $date, ')
          ..write('dateRaw: $dateRaw, ')
          ..write('channel: $channel, ')
          ..write('subChannel: $subChannel, ')
          ..write('category: $category, ')
          ..write('postRef: $postRef, ')
          ..write('floorRef: $floorRef, ')
          ..write('srcTid: $srcTid, ')
          ..write('srcUrl: $srcUrl, ')
          ..write('wordCount: $wordCount, ')
          ..write('bookGrade: $bookGrade, ')
          ..write('quality: $quality, ')
          ..write('contentHash: $contentHash, ')
          ..write('bookGroupId: $bookGroupId, ')
          ..write('origin: $origin, ')
          ..write('collectedAt: $collectedAt')
          ..write(')'))
        .toString();
  }
}

class $BookGroupsTable extends BookGroups
    with TableInfo<$BookGroupsTable, BookGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameNormMeta = const VerificationMeta(
    'nameNorm',
  );
  @override
  late final GeneratedColumn<String> nameNorm = GeneratedColumn<String>(
    'name_norm',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _authorEffNormMeta = const VerificationMeta(
    'authorEffNorm',
  );
  @override
  late final GeneratedColumn<String> authorEffNorm = GeneratedColumn<String>(
    'author_eff_norm',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _nameDisplayMeta = const VerificationMeta(
    'nameDisplay',
  );
  @override
  late final GeneratedColumn<String> nameDisplay = GeneratedColumn<String>(
    'name_display',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorDisplayMeta = const VerificationMeta(
    'authorDisplay',
  );
  @override
  late final GeneratedColumn<String> authorDisplay = GeneratedColumn<String>(
    'author_display',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _entryTotalMeta = const VerificationMeta(
    'entryTotal',
  );
  @override
  late final GeneratedColumn<int> entryTotal = GeneratedColumn<int>(
    'entry_total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _distinctCommentMeta = const VerificationMeta(
    'distinctComment',
  );
  @override
  late final GeneratedColumn<int> distinctComment = GeneratedColumn<int>(
    'distinct_comment',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _channelsMeta = const VerificationMeta(
    'channels',
  );
  @override
  late final GeneratedColumn<String> channels = GeneratedColumn<String>(
    'channels',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateMinMeta = const VerificationMeta(
    'dateMin',
  );
  @override
  late final GeneratedColumn<String> dateMin = GeneratedColumn<String>(
    'date_min',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateMaxMeta = const VerificationMeta(
    'dateMax',
  );
  @override
  late final GeneratedColumn<String> dateMax = GeneratedColumn<String>(
    'date_max',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wordCountMaxMeta = const VerificationMeta(
    'wordCountMax',
  );
  @override
  late final GeneratedColumn<int> wordCountMax = GeneratedColumn<int>(
    'word_count_max',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nameNorm,
    authorEffNorm,
    nameDisplay,
    authorDisplay,
    entryTotal,
    distinctComment,
    channels,
    dateMin,
    dateMax,
    wordCountMax,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name_norm')) {
      context.handle(
        _nameNormMeta,
        nameNorm.isAcceptableOrUnknown(data['name_norm']!, _nameNormMeta),
      );
    } else if (isInserting) {
      context.missing(_nameNormMeta);
    }
    if (data.containsKey('author_eff_norm')) {
      context.handle(
        _authorEffNormMeta,
        authorEffNorm.isAcceptableOrUnknown(
          data['author_eff_norm']!,
          _authorEffNormMeta,
        ),
      );
    }
    if (data.containsKey('name_display')) {
      context.handle(
        _nameDisplayMeta,
        nameDisplay.isAcceptableOrUnknown(
          data['name_display']!,
          _nameDisplayMeta,
        ),
      );
    }
    if (data.containsKey('author_display')) {
      context.handle(
        _authorDisplayMeta,
        authorDisplay.isAcceptableOrUnknown(
          data['author_display']!,
          _authorDisplayMeta,
        ),
      );
    }
    if (data.containsKey('entry_total')) {
      context.handle(
        _entryTotalMeta,
        entryTotal.isAcceptableOrUnknown(data['entry_total']!, _entryTotalMeta),
      );
    }
    if (data.containsKey('distinct_comment')) {
      context.handle(
        _distinctCommentMeta,
        distinctComment.isAcceptableOrUnknown(
          data['distinct_comment']!,
          _distinctCommentMeta,
        ),
      );
    }
    if (data.containsKey('channels')) {
      context.handle(
        _channelsMeta,
        channels.isAcceptableOrUnknown(data['channels']!, _channelsMeta),
      );
    }
    if (data.containsKey('date_min')) {
      context.handle(
        _dateMinMeta,
        dateMin.isAcceptableOrUnknown(data['date_min']!, _dateMinMeta),
      );
    }
    if (data.containsKey('date_max')) {
      context.handle(
        _dateMaxMeta,
        dateMax.isAcceptableOrUnknown(data['date_max']!, _dateMaxMeta),
      );
    }
    if (data.containsKey('word_count_max')) {
      context.handle(
        _wordCountMaxMeta,
        wordCountMax.isAcceptableOrUnknown(
          data['word_count_max']!,
          _wordCountMaxMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      nameNorm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_norm'],
      )!,
      authorEffNorm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_eff_norm'],
      )!,
      nameDisplay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_display'],
      ),
      authorDisplay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_display'],
      ),
      entryTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entry_total'],
      )!,
      distinctComment: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}distinct_comment'],
      )!,
      channels: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channels'],
      ),
      dateMin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_min'],
      ),
      dateMax: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_max'],
      ),
      wordCountMax: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}word_count_max'],
      ),
    );
  }

  @override
  $BookGroupsTable createAlias(String alias) {
    return $BookGroupsTable(attachedDatabase, alias);
  }
}

class BookGroup extends DataClass implements Insertable<BookGroup> {
  final int id;
  final String nameNorm;
  final String authorEffNorm;
  final String? nameDisplay;
  final String? authorDisplay;
  final int entryTotal;
  final int distinctComment;

  /// JSON 数组：渠道集合。
  final String? channels;
  final String? dateMin;
  final String? dateMax;

  /// 榜单用。
  final int? wordCountMax;
  const BookGroup({
    required this.id,
    required this.nameNorm,
    required this.authorEffNorm,
    this.nameDisplay,
    this.authorDisplay,
    required this.entryTotal,
    required this.distinctComment,
    this.channels,
    this.dateMin,
    this.dateMax,
    this.wordCountMax,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name_norm'] = Variable<String>(nameNorm);
    map['author_eff_norm'] = Variable<String>(authorEffNorm);
    if (!nullToAbsent || nameDisplay != null) {
      map['name_display'] = Variable<String>(nameDisplay);
    }
    if (!nullToAbsent || authorDisplay != null) {
      map['author_display'] = Variable<String>(authorDisplay);
    }
    map['entry_total'] = Variable<int>(entryTotal);
    map['distinct_comment'] = Variable<int>(distinctComment);
    if (!nullToAbsent || channels != null) {
      map['channels'] = Variable<String>(channels);
    }
    if (!nullToAbsent || dateMin != null) {
      map['date_min'] = Variable<String>(dateMin);
    }
    if (!nullToAbsent || dateMax != null) {
      map['date_max'] = Variable<String>(dateMax);
    }
    if (!nullToAbsent || wordCountMax != null) {
      map['word_count_max'] = Variable<int>(wordCountMax);
    }
    return map;
  }

  BookGroupsCompanion toCompanion(bool nullToAbsent) {
    return BookGroupsCompanion(
      id: Value(id),
      nameNorm: Value(nameNorm),
      authorEffNorm: Value(authorEffNorm),
      nameDisplay: nameDisplay == null && nullToAbsent
          ? const Value.absent()
          : Value(nameDisplay),
      authorDisplay: authorDisplay == null && nullToAbsent
          ? const Value.absent()
          : Value(authorDisplay),
      entryTotal: Value(entryTotal),
      distinctComment: Value(distinctComment),
      channels: channels == null && nullToAbsent
          ? const Value.absent()
          : Value(channels),
      dateMin: dateMin == null && nullToAbsent
          ? const Value.absent()
          : Value(dateMin),
      dateMax: dateMax == null && nullToAbsent
          ? const Value.absent()
          : Value(dateMax),
      wordCountMax: wordCountMax == null && nullToAbsent
          ? const Value.absent()
          : Value(wordCountMax),
    );
  }

  factory BookGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookGroup(
      id: serializer.fromJson<int>(json['id']),
      nameNorm: serializer.fromJson<String>(json['nameNorm']),
      authorEffNorm: serializer.fromJson<String>(json['authorEffNorm']),
      nameDisplay: serializer.fromJson<String?>(json['nameDisplay']),
      authorDisplay: serializer.fromJson<String?>(json['authorDisplay']),
      entryTotal: serializer.fromJson<int>(json['entryTotal']),
      distinctComment: serializer.fromJson<int>(json['distinctComment']),
      channels: serializer.fromJson<String?>(json['channels']),
      dateMin: serializer.fromJson<String?>(json['dateMin']),
      dateMax: serializer.fromJson<String?>(json['dateMax']),
      wordCountMax: serializer.fromJson<int?>(json['wordCountMax']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'nameNorm': serializer.toJson<String>(nameNorm),
      'authorEffNorm': serializer.toJson<String>(authorEffNorm),
      'nameDisplay': serializer.toJson<String?>(nameDisplay),
      'authorDisplay': serializer.toJson<String?>(authorDisplay),
      'entryTotal': serializer.toJson<int>(entryTotal),
      'distinctComment': serializer.toJson<int>(distinctComment),
      'channels': serializer.toJson<String?>(channels),
      'dateMin': serializer.toJson<String?>(dateMin),
      'dateMax': serializer.toJson<String?>(dateMax),
      'wordCountMax': serializer.toJson<int?>(wordCountMax),
    };
  }

  BookGroup copyWith({
    int? id,
    String? nameNorm,
    String? authorEffNorm,
    Value<String?> nameDisplay = const Value.absent(),
    Value<String?> authorDisplay = const Value.absent(),
    int? entryTotal,
    int? distinctComment,
    Value<String?> channels = const Value.absent(),
    Value<String?> dateMin = const Value.absent(),
    Value<String?> dateMax = const Value.absent(),
    Value<int?> wordCountMax = const Value.absent(),
  }) => BookGroup(
    id: id ?? this.id,
    nameNorm: nameNorm ?? this.nameNorm,
    authorEffNorm: authorEffNorm ?? this.authorEffNorm,
    nameDisplay: nameDisplay.present ? nameDisplay.value : this.nameDisplay,
    authorDisplay: authorDisplay.present
        ? authorDisplay.value
        : this.authorDisplay,
    entryTotal: entryTotal ?? this.entryTotal,
    distinctComment: distinctComment ?? this.distinctComment,
    channels: channels.present ? channels.value : this.channels,
    dateMin: dateMin.present ? dateMin.value : this.dateMin,
    dateMax: dateMax.present ? dateMax.value : this.dateMax,
    wordCountMax: wordCountMax.present ? wordCountMax.value : this.wordCountMax,
  );
  BookGroup copyWithCompanion(BookGroupsCompanion data) {
    return BookGroup(
      id: data.id.present ? data.id.value : this.id,
      nameNorm: data.nameNorm.present ? data.nameNorm.value : this.nameNorm,
      authorEffNorm: data.authorEffNorm.present
          ? data.authorEffNorm.value
          : this.authorEffNorm,
      nameDisplay: data.nameDisplay.present
          ? data.nameDisplay.value
          : this.nameDisplay,
      authorDisplay: data.authorDisplay.present
          ? data.authorDisplay.value
          : this.authorDisplay,
      entryTotal: data.entryTotal.present
          ? data.entryTotal.value
          : this.entryTotal,
      distinctComment: data.distinctComment.present
          ? data.distinctComment.value
          : this.distinctComment,
      channels: data.channels.present ? data.channels.value : this.channels,
      dateMin: data.dateMin.present ? data.dateMin.value : this.dateMin,
      dateMax: data.dateMax.present ? data.dateMax.value : this.dateMax,
      wordCountMax: data.wordCountMax.present
          ? data.wordCountMax.value
          : this.wordCountMax,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookGroup(')
          ..write('id: $id, ')
          ..write('nameNorm: $nameNorm, ')
          ..write('authorEffNorm: $authorEffNorm, ')
          ..write('nameDisplay: $nameDisplay, ')
          ..write('authorDisplay: $authorDisplay, ')
          ..write('entryTotal: $entryTotal, ')
          ..write('distinctComment: $distinctComment, ')
          ..write('channels: $channels, ')
          ..write('dateMin: $dateMin, ')
          ..write('dateMax: $dateMax, ')
          ..write('wordCountMax: $wordCountMax')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    nameNorm,
    authorEffNorm,
    nameDisplay,
    authorDisplay,
    entryTotal,
    distinctComment,
    channels,
    dateMin,
    dateMax,
    wordCountMax,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookGroup &&
          other.id == this.id &&
          other.nameNorm == this.nameNorm &&
          other.authorEffNorm == this.authorEffNorm &&
          other.nameDisplay == this.nameDisplay &&
          other.authorDisplay == this.authorDisplay &&
          other.entryTotal == this.entryTotal &&
          other.distinctComment == this.distinctComment &&
          other.channels == this.channels &&
          other.dateMin == this.dateMin &&
          other.dateMax == this.dateMax &&
          other.wordCountMax == this.wordCountMax);
}

class BookGroupsCompanion extends UpdateCompanion<BookGroup> {
  final Value<int> id;
  final Value<String> nameNorm;
  final Value<String> authorEffNorm;
  final Value<String?> nameDisplay;
  final Value<String?> authorDisplay;
  final Value<int> entryTotal;
  final Value<int> distinctComment;
  final Value<String?> channels;
  final Value<String?> dateMin;
  final Value<String?> dateMax;
  final Value<int?> wordCountMax;
  const BookGroupsCompanion({
    this.id = const Value.absent(),
    this.nameNorm = const Value.absent(),
    this.authorEffNorm = const Value.absent(),
    this.nameDisplay = const Value.absent(),
    this.authorDisplay = const Value.absent(),
    this.entryTotal = const Value.absent(),
    this.distinctComment = const Value.absent(),
    this.channels = const Value.absent(),
    this.dateMin = const Value.absent(),
    this.dateMax = const Value.absent(),
    this.wordCountMax = const Value.absent(),
  });
  BookGroupsCompanion.insert({
    this.id = const Value.absent(),
    required String nameNorm,
    this.authorEffNorm = const Value.absent(),
    this.nameDisplay = const Value.absent(),
    this.authorDisplay = const Value.absent(),
    this.entryTotal = const Value.absent(),
    this.distinctComment = const Value.absent(),
    this.channels = const Value.absent(),
    this.dateMin = const Value.absent(),
    this.dateMax = const Value.absent(),
    this.wordCountMax = const Value.absent(),
  }) : nameNorm = Value(nameNorm);
  static Insertable<BookGroup> custom({
    Expression<int>? id,
    Expression<String>? nameNorm,
    Expression<String>? authorEffNorm,
    Expression<String>? nameDisplay,
    Expression<String>? authorDisplay,
    Expression<int>? entryTotal,
    Expression<int>? distinctComment,
    Expression<String>? channels,
    Expression<String>? dateMin,
    Expression<String>? dateMax,
    Expression<int>? wordCountMax,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nameNorm != null) 'name_norm': nameNorm,
      if (authorEffNorm != null) 'author_eff_norm': authorEffNorm,
      if (nameDisplay != null) 'name_display': nameDisplay,
      if (authorDisplay != null) 'author_display': authorDisplay,
      if (entryTotal != null) 'entry_total': entryTotal,
      if (distinctComment != null) 'distinct_comment': distinctComment,
      if (channels != null) 'channels': channels,
      if (dateMin != null) 'date_min': dateMin,
      if (dateMax != null) 'date_max': dateMax,
      if (wordCountMax != null) 'word_count_max': wordCountMax,
    });
  }

  BookGroupsCompanion copyWith({
    Value<int>? id,
    Value<String>? nameNorm,
    Value<String>? authorEffNorm,
    Value<String?>? nameDisplay,
    Value<String?>? authorDisplay,
    Value<int>? entryTotal,
    Value<int>? distinctComment,
    Value<String?>? channels,
    Value<String?>? dateMin,
    Value<String?>? dateMax,
    Value<int?>? wordCountMax,
  }) {
    return BookGroupsCompanion(
      id: id ?? this.id,
      nameNorm: nameNorm ?? this.nameNorm,
      authorEffNorm: authorEffNorm ?? this.authorEffNorm,
      nameDisplay: nameDisplay ?? this.nameDisplay,
      authorDisplay: authorDisplay ?? this.authorDisplay,
      entryTotal: entryTotal ?? this.entryTotal,
      distinctComment: distinctComment ?? this.distinctComment,
      channels: channels ?? this.channels,
      dateMin: dateMin ?? this.dateMin,
      dateMax: dateMax ?? this.dateMax,
      wordCountMax: wordCountMax ?? this.wordCountMax,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (nameNorm.present) {
      map['name_norm'] = Variable<String>(nameNorm.value);
    }
    if (authorEffNorm.present) {
      map['author_eff_norm'] = Variable<String>(authorEffNorm.value);
    }
    if (nameDisplay.present) {
      map['name_display'] = Variable<String>(nameDisplay.value);
    }
    if (authorDisplay.present) {
      map['author_display'] = Variable<String>(authorDisplay.value);
    }
    if (entryTotal.present) {
      map['entry_total'] = Variable<int>(entryTotal.value);
    }
    if (distinctComment.present) {
      map['distinct_comment'] = Variable<int>(distinctComment.value);
    }
    if (channels.present) {
      map['channels'] = Variable<String>(channels.value);
    }
    if (dateMin.present) {
      map['date_min'] = Variable<String>(dateMin.value);
    }
    if (dateMax.present) {
      map['date_max'] = Variable<String>(dateMax.value);
    }
    if (wordCountMax.present) {
      map['word_count_max'] = Variable<int>(wordCountMax.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookGroupsCompanion(')
          ..write('id: $id, ')
          ..write('nameNorm: $nameNorm, ')
          ..write('authorEffNorm: $authorEffNorm, ')
          ..write('nameDisplay: $nameDisplay, ')
          ..write('authorDisplay: $authorDisplay, ')
          ..write('entryTotal: $entryTotal, ')
          ..write('distinctComment: $distinctComment, ')
          ..write('channels: $channels, ')
          ..write('dateMin: $dateMin, ')
          ..write('dateMax: $dateMax, ')
          ..write('wordCountMax: $wordCountMax')
          ..write(')'))
        .toString();
  }
}

class $SearchHistoryTable extends SearchHistory
    with TableInfo<$SearchHistoryTable, SearchHistoryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _queryMeta = const VerificationMeta('query');
  @override
  late final GeneratedColumn<String> query = GeneratedColumn<String>(
    'query',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<String> year = GeneratedColumn<String>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<String> month = GeneratedColumn<String>(
    'month',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tenDayMeta = const VerificationMeta('tenDay');
  @override
  late final GeneratedColumn<String> tenDay = GeneratedColumn<String>(
    'ten_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _channelMeta = const VerificationMeta(
    'channel',
  );
  @override
  late final GeneratedColumn<String> channel = GeneratedColumn<String>(
    'channel',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortMeta = const VerificationMeta('sort');
  @override
  late final GeneratedColumn<String> sort = GeneratedColumn<String>(
    'sort',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('time_desc'),
  );
  static const VerificationMeta _searchedAtMeta = const VerificationMeta(
    'searchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> searchedAt = GeneratedColumn<DateTime>(
    'searched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    query,
    year,
    month,
    tenDay,
    channel,
    category,
    sort,
    searchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchHistoryEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('query')) {
      context.handle(
        _queryMeta,
        query.isAcceptableOrUnknown(data['query']!, _queryMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    }
    if (data.containsKey('ten_day')) {
      context.handle(
        _tenDayMeta,
        tenDay.isAcceptableOrUnknown(data['ten_day']!, _tenDayMeta),
      );
    }
    if (data.containsKey('channel')) {
      context.handle(
        _channelMeta,
        channel.isAcceptableOrUnknown(data['channel']!, _channelMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('sort')) {
      context.handle(
        _sortMeta,
        sort.isAcceptableOrUnknown(data['sort']!, _sortMeta),
      );
    }
    if (data.containsKey('searched_at')) {
      context.handle(
        _searchedAtMeta,
        searchedAt.isAcceptableOrUnknown(data['searched_at']!, _searchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_searchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SearchHistoryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchHistoryEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      query: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}query'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}year'],
      ),
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month'],
      ),
      tenDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ten_day'],
      ),
      channel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      sort: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort'],
      )!,
      searchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}searched_at'],
      )!,
    );
  }

  @override
  $SearchHistoryTable createAlias(String alias) {
    return $SearchHistoryTable(attachedDatabase, alias);
  }
}

class SearchHistoryEntry extends DataClass
    implements Insertable<SearchHistoryEntry> {
  final int id;
  final String query;

  /// '2024' / 'early'(更早) / null=全部。
  final String? year;

  /// '1'..'12' / null。
  final String? month;

  /// 'upper'/'middle'/'lower' / null。
  final String? tenDay;
  final String? channel;

  /// 扫书/排雷/求书/日常。
  final String? category;
  final String sort;
  final DateTime searchedAt;
  const SearchHistoryEntry({
    required this.id,
    required this.query,
    this.year,
    this.month,
    this.tenDay,
    this.channel,
    this.category,
    required this.sort,
    required this.searchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['query'] = Variable<String>(query);
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<String>(year);
    }
    if (!nullToAbsent || month != null) {
      map['month'] = Variable<String>(month);
    }
    if (!nullToAbsent || tenDay != null) {
      map['ten_day'] = Variable<String>(tenDay);
    }
    if (!nullToAbsent || channel != null) {
      map['channel'] = Variable<String>(channel);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['sort'] = Variable<String>(sort);
    map['searched_at'] = Variable<DateTime>(searchedAt);
    return map;
  }

  SearchHistoryCompanion toCompanion(bool nullToAbsent) {
    return SearchHistoryCompanion(
      id: Value(id),
      query: Value(query),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      month: month == null && nullToAbsent
          ? const Value.absent()
          : Value(month),
      tenDay: tenDay == null && nullToAbsent
          ? const Value.absent()
          : Value(tenDay),
      channel: channel == null && nullToAbsent
          ? const Value.absent()
          : Value(channel),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      sort: Value(sort),
      searchedAt: Value(searchedAt),
    );
  }

  factory SearchHistoryEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchHistoryEntry(
      id: serializer.fromJson<int>(json['id']),
      query: serializer.fromJson<String>(json['query']),
      year: serializer.fromJson<String?>(json['year']),
      month: serializer.fromJson<String?>(json['month']),
      tenDay: serializer.fromJson<String?>(json['tenDay']),
      channel: serializer.fromJson<String?>(json['channel']),
      category: serializer.fromJson<String?>(json['category']),
      sort: serializer.fromJson<String>(json['sort']),
      searchedAt: serializer.fromJson<DateTime>(json['searchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'query': serializer.toJson<String>(query),
      'year': serializer.toJson<String?>(year),
      'month': serializer.toJson<String?>(month),
      'tenDay': serializer.toJson<String?>(tenDay),
      'channel': serializer.toJson<String?>(channel),
      'category': serializer.toJson<String?>(category),
      'sort': serializer.toJson<String>(sort),
      'searchedAt': serializer.toJson<DateTime>(searchedAt),
    };
  }

  SearchHistoryEntry copyWith({
    int? id,
    String? query,
    Value<String?> year = const Value.absent(),
    Value<String?> month = const Value.absent(),
    Value<String?> tenDay = const Value.absent(),
    Value<String?> channel = const Value.absent(),
    Value<String?> category = const Value.absent(),
    String? sort,
    DateTime? searchedAt,
  }) => SearchHistoryEntry(
    id: id ?? this.id,
    query: query ?? this.query,
    year: year.present ? year.value : this.year,
    month: month.present ? month.value : this.month,
    tenDay: tenDay.present ? tenDay.value : this.tenDay,
    channel: channel.present ? channel.value : this.channel,
    category: category.present ? category.value : this.category,
    sort: sort ?? this.sort,
    searchedAt: searchedAt ?? this.searchedAt,
  );
  SearchHistoryEntry copyWithCompanion(SearchHistoryCompanion data) {
    return SearchHistoryEntry(
      id: data.id.present ? data.id.value : this.id,
      query: data.query.present ? data.query.value : this.query,
      year: data.year.present ? data.year.value : this.year,
      month: data.month.present ? data.month.value : this.month,
      tenDay: data.tenDay.present ? data.tenDay.value : this.tenDay,
      channel: data.channel.present ? data.channel.value : this.channel,
      category: data.category.present ? data.category.value : this.category,
      sort: data.sort.present ? data.sort.value : this.sort,
      searchedAt: data.searchedAt.present
          ? data.searchedAt.value
          : this.searchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryEntry(')
          ..write('id: $id, ')
          ..write('query: $query, ')
          ..write('year: $year, ')
          ..write('month: $month, ')
          ..write('tenDay: $tenDay, ')
          ..write('channel: $channel, ')
          ..write('category: $category, ')
          ..write('sort: $sort, ')
          ..write('searchedAt: $searchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    query,
    year,
    month,
    tenDay,
    channel,
    category,
    sort,
    searchedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchHistoryEntry &&
          other.id == this.id &&
          other.query == this.query &&
          other.year == this.year &&
          other.month == this.month &&
          other.tenDay == this.tenDay &&
          other.channel == this.channel &&
          other.category == this.category &&
          other.sort == this.sort &&
          other.searchedAt == this.searchedAt);
}

class SearchHistoryCompanion extends UpdateCompanion<SearchHistoryEntry> {
  final Value<int> id;
  final Value<String> query;
  final Value<String?> year;
  final Value<String?> month;
  final Value<String?> tenDay;
  final Value<String?> channel;
  final Value<String?> category;
  final Value<String> sort;
  final Value<DateTime> searchedAt;
  const SearchHistoryCompanion({
    this.id = const Value.absent(),
    this.query = const Value.absent(),
    this.year = const Value.absent(),
    this.month = const Value.absent(),
    this.tenDay = const Value.absent(),
    this.channel = const Value.absent(),
    this.category = const Value.absent(),
    this.sort = const Value.absent(),
    this.searchedAt = const Value.absent(),
  });
  SearchHistoryCompanion.insert({
    this.id = const Value.absent(),
    this.query = const Value.absent(),
    this.year = const Value.absent(),
    this.month = const Value.absent(),
    this.tenDay = const Value.absent(),
    this.channel = const Value.absent(),
    this.category = const Value.absent(),
    this.sort = const Value.absent(),
    required DateTime searchedAt,
  }) : searchedAt = Value(searchedAt);
  static Insertable<SearchHistoryEntry> custom({
    Expression<int>? id,
    Expression<String>? query,
    Expression<String>? year,
    Expression<String>? month,
    Expression<String>? tenDay,
    Expression<String>? channel,
    Expression<String>? category,
    Expression<String>? sort,
    Expression<DateTime>? searchedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (query != null) 'query': query,
      if (year != null) 'year': year,
      if (month != null) 'month': month,
      if (tenDay != null) 'ten_day': tenDay,
      if (channel != null) 'channel': channel,
      if (category != null) 'category': category,
      if (sort != null) 'sort': sort,
      if (searchedAt != null) 'searched_at': searchedAt,
    });
  }

  SearchHistoryCompanion copyWith({
    Value<int>? id,
    Value<String>? query,
    Value<String?>? year,
    Value<String?>? month,
    Value<String?>? tenDay,
    Value<String?>? channel,
    Value<String?>? category,
    Value<String>? sort,
    Value<DateTime>? searchedAt,
  }) {
    return SearchHistoryCompanion(
      id: id ?? this.id,
      query: query ?? this.query,
      year: year ?? this.year,
      month: month ?? this.month,
      tenDay: tenDay ?? this.tenDay,
      channel: channel ?? this.channel,
      category: category ?? this.category,
      sort: sort ?? this.sort,
      searchedAt: searchedAt ?? this.searchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (query.present) {
      map['query'] = Variable<String>(query.value);
    }
    if (year.present) {
      map['year'] = Variable<String>(year.value);
    }
    if (month.present) {
      map['month'] = Variable<String>(month.value);
    }
    if (tenDay.present) {
      map['ten_day'] = Variable<String>(tenDay.value);
    }
    if (channel.present) {
      map['channel'] = Variable<String>(channel.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (sort.present) {
      map['sort'] = Variable<String>(sort.value);
    }
    if (searchedAt.present) {
      map['searched_at'] = Variable<DateTime>(searchedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryCompanion(')
          ..write('id: $id, ')
          ..write('query: $query, ')
          ..write('year: $year, ')
          ..write('month: $month, ')
          ..write('tenDay: $tenDay, ')
          ..write('channel: $channel, ')
          ..write('category: $category, ')
          ..write('sort: $sort, ')
          ..write('searchedAt: $searchedAt')
          ..write(')'))
        .toString();
  }
}

class $BookmarksTable extends Bookmarks
    with TableInfo<$BookmarksTable, Bookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _postRefMeta = const VerificationMeta(
    'postRef',
  );
  @override
  late final GeneratedColumn<int> postRef = GeneratedColumn<int>(
    'post_ref',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _entryRefMeta = const VerificationMeta(
    'entryRef',
  );
  @override
  late final GeneratedColumn<int> entryRef = GeneratedColumn<int>(
    'entry_ref',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _channelMeta = const VerificationMeta(
    'channel',
  );
  @override
  late final GeneratedColumn<String> channel = GeneratedColumn<String>(
    'channel',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _snapQueryMeta = const VerificationMeta(
    'snapQuery',
  );
  @override
  late final GeneratedColumn<String> snapQuery = GeneratedColumn<String>(
    'snap_query',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snapYearMeta = const VerificationMeta(
    'snapYear',
  );
  @override
  late final GeneratedColumn<String> snapYear = GeneratedColumn<String>(
    'snap_year',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snapMonthMeta = const VerificationMeta(
    'snapMonth',
  );
  @override
  late final GeneratedColumn<String> snapMonth = GeneratedColumn<String>(
    'snap_month',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snapTenDayMeta = const VerificationMeta(
    'snapTenDay',
  );
  @override
  late final GeneratedColumn<String> snapTenDay = GeneratedColumn<String>(
    'snap_ten_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snapChannelMeta = const VerificationMeta(
    'snapChannel',
  );
  @override
  late final GeneratedColumn<String> snapChannel = GeneratedColumn<String>(
    'snap_channel',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snapCategoryMeta = const VerificationMeta(
    'snapCategory',
  );
  @override
  late final GeneratedColumn<String> snapCategory = GeneratedColumn<String>(
    'snap_category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snapSortMeta = const VerificationMeta(
    'snapSort',
  );
  @override
  late final GeneratedColumn<String> snapSort = GeneratedColumn<String>(
    'snap_sort',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    postRef,
    entryRef,
    title,
    author,
    channel,
    position,
    snapQuery,
    snapYear,
    snapMonth,
    snapTenDay,
    snapChannel,
    snapCategory,
    snapSort,
    note,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Bookmark> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('post_ref')) {
      context.handle(
        _postRefMeta,
        postRef.isAcceptableOrUnknown(data['post_ref']!, _postRefMeta),
      );
    }
    if (data.containsKey('entry_ref')) {
      context.handle(
        _entryRefMeta,
        entryRef.isAcceptableOrUnknown(data['entry_ref']!, _entryRefMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('channel')) {
      context.handle(
        _channelMeta,
        channel.isAcceptableOrUnknown(data['channel']!, _channelMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('snap_query')) {
      context.handle(
        _snapQueryMeta,
        snapQuery.isAcceptableOrUnknown(data['snap_query']!, _snapQueryMeta),
      );
    }
    if (data.containsKey('snap_year')) {
      context.handle(
        _snapYearMeta,
        snapYear.isAcceptableOrUnknown(data['snap_year']!, _snapYearMeta),
      );
    }
    if (data.containsKey('snap_month')) {
      context.handle(
        _snapMonthMeta,
        snapMonth.isAcceptableOrUnknown(data['snap_month']!, _snapMonthMeta),
      );
    }
    if (data.containsKey('snap_ten_day')) {
      context.handle(
        _snapTenDayMeta,
        snapTenDay.isAcceptableOrUnknown(
          data['snap_ten_day']!,
          _snapTenDayMeta,
        ),
      );
    }
    if (data.containsKey('snap_channel')) {
      context.handle(
        _snapChannelMeta,
        snapChannel.isAcceptableOrUnknown(
          data['snap_channel']!,
          _snapChannelMeta,
        ),
      );
    }
    if (data.containsKey('snap_category')) {
      context.handle(
        _snapCategoryMeta,
        snapCategory.isAcceptableOrUnknown(
          data['snap_category']!,
          _snapCategoryMeta,
        ),
      );
    }
    if (data.containsKey('snap_sort')) {
      context.handle(
        _snapSortMeta,
        snapSort.isAcceptableOrUnknown(data['snap_sort']!, _snapSortMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Bookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bookmark(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      postRef: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}post_ref'],
      ),
      entryRef: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entry_ref'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      channel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      snapQuery: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snap_query'],
      ),
      snapYear: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snap_year'],
      ),
      snapMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snap_month'],
      ),
      snapTenDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snap_ten_day'],
      ),
      snapChannel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snap_channel'],
      ),
      snapCategory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snap_category'],
      ),
      snapSort: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snap_sort'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BookmarksTable createAlias(String alias) {
    return $BookmarksTable(attachedDatabase, alias);
  }
}

class Bookmark extends DataClass implements Insertable<Bookmark> {
  final int id;

  /// 指向帖子。
  final int? postRef;

  /// 或指向书目条目。
  final int? entryRef;
  final String title;
  final String? author;
  final String? channel;

  /// 结果列表位置。
  final int position;
  final String? snapQuery;
  final String? snapYear;
  final String? snapMonth;
  final String? snapTenDay;
  final String? snapChannel;
  final String? snapCategory;
  final String? snapSort;
  final String? note;
  final DateTime createdAt;
  const Bookmark({
    required this.id,
    this.postRef,
    this.entryRef,
    required this.title,
    this.author,
    this.channel,
    required this.position,
    this.snapQuery,
    this.snapYear,
    this.snapMonth,
    this.snapTenDay,
    this.snapChannel,
    this.snapCategory,
    this.snapSort,
    this.note,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || postRef != null) {
      map['post_ref'] = Variable<int>(postRef);
    }
    if (!nullToAbsent || entryRef != null) {
      map['entry_ref'] = Variable<int>(entryRef);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || channel != null) {
      map['channel'] = Variable<String>(channel);
    }
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || snapQuery != null) {
      map['snap_query'] = Variable<String>(snapQuery);
    }
    if (!nullToAbsent || snapYear != null) {
      map['snap_year'] = Variable<String>(snapYear);
    }
    if (!nullToAbsent || snapMonth != null) {
      map['snap_month'] = Variable<String>(snapMonth);
    }
    if (!nullToAbsent || snapTenDay != null) {
      map['snap_ten_day'] = Variable<String>(snapTenDay);
    }
    if (!nullToAbsent || snapChannel != null) {
      map['snap_channel'] = Variable<String>(snapChannel);
    }
    if (!nullToAbsent || snapCategory != null) {
      map['snap_category'] = Variable<String>(snapCategory);
    }
    if (!nullToAbsent || snapSort != null) {
      map['snap_sort'] = Variable<String>(snapSort);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      id: Value(id),
      postRef: postRef == null && nullToAbsent
          ? const Value.absent()
          : Value(postRef),
      entryRef: entryRef == null && nullToAbsent
          ? const Value.absent()
          : Value(entryRef),
      title: Value(title),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      channel: channel == null && nullToAbsent
          ? const Value.absent()
          : Value(channel),
      position: Value(position),
      snapQuery: snapQuery == null && nullToAbsent
          ? const Value.absent()
          : Value(snapQuery),
      snapYear: snapYear == null && nullToAbsent
          ? const Value.absent()
          : Value(snapYear),
      snapMonth: snapMonth == null && nullToAbsent
          ? const Value.absent()
          : Value(snapMonth),
      snapTenDay: snapTenDay == null && nullToAbsent
          ? const Value.absent()
          : Value(snapTenDay),
      snapChannel: snapChannel == null && nullToAbsent
          ? const Value.absent()
          : Value(snapChannel),
      snapCategory: snapCategory == null && nullToAbsent
          ? const Value.absent()
          : Value(snapCategory),
      snapSort: snapSort == null && nullToAbsent
          ? const Value.absent()
          : Value(snapSort),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
    );
  }

  factory Bookmark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bookmark(
      id: serializer.fromJson<int>(json['id']),
      postRef: serializer.fromJson<int?>(json['postRef']),
      entryRef: serializer.fromJson<int?>(json['entryRef']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String?>(json['author']),
      channel: serializer.fromJson<String?>(json['channel']),
      position: serializer.fromJson<int>(json['position']),
      snapQuery: serializer.fromJson<String?>(json['snapQuery']),
      snapYear: serializer.fromJson<String?>(json['snapYear']),
      snapMonth: serializer.fromJson<String?>(json['snapMonth']),
      snapTenDay: serializer.fromJson<String?>(json['snapTenDay']),
      snapChannel: serializer.fromJson<String?>(json['snapChannel']),
      snapCategory: serializer.fromJson<String?>(json['snapCategory']),
      snapSort: serializer.fromJson<String?>(json['snapSort']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'postRef': serializer.toJson<int?>(postRef),
      'entryRef': serializer.toJson<int?>(entryRef),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String?>(author),
      'channel': serializer.toJson<String?>(channel),
      'position': serializer.toJson<int>(position),
      'snapQuery': serializer.toJson<String?>(snapQuery),
      'snapYear': serializer.toJson<String?>(snapYear),
      'snapMonth': serializer.toJson<String?>(snapMonth),
      'snapTenDay': serializer.toJson<String?>(snapTenDay),
      'snapChannel': serializer.toJson<String?>(snapChannel),
      'snapCategory': serializer.toJson<String?>(snapCategory),
      'snapSort': serializer.toJson<String?>(snapSort),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Bookmark copyWith({
    int? id,
    Value<int?> postRef = const Value.absent(),
    Value<int?> entryRef = const Value.absent(),
    String? title,
    Value<String?> author = const Value.absent(),
    Value<String?> channel = const Value.absent(),
    int? position,
    Value<String?> snapQuery = const Value.absent(),
    Value<String?> snapYear = const Value.absent(),
    Value<String?> snapMonth = const Value.absent(),
    Value<String?> snapTenDay = const Value.absent(),
    Value<String?> snapChannel = const Value.absent(),
    Value<String?> snapCategory = const Value.absent(),
    Value<String?> snapSort = const Value.absent(),
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
  }) => Bookmark(
    id: id ?? this.id,
    postRef: postRef.present ? postRef.value : this.postRef,
    entryRef: entryRef.present ? entryRef.value : this.entryRef,
    title: title ?? this.title,
    author: author.present ? author.value : this.author,
    channel: channel.present ? channel.value : this.channel,
    position: position ?? this.position,
    snapQuery: snapQuery.present ? snapQuery.value : this.snapQuery,
    snapYear: snapYear.present ? snapYear.value : this.snapYear,
    snapMonth: snapMonth.present ? snapMonth.value : this.snapMonth,
    snapTenDay: snapTenDay.present ? snapTenDay.value : this.snapTenDay,
    snapChannel: snapChannel.present ? snapChannel.value : this.snapChannel,
    snapCategory: snapCategory.present ? snapCategory.value : this.snapCategory,
    snapSort: snapSort.present ? snapSort.value : this.snapSort,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
  );
  Bookmark copyWithCompanion(BookmarksCompanion data) {
    return Bookmark(
      id: data.id.present ? data.id.value : this.id,
      postRef: data.postRef.present ? data.postRef.value : this.postRef,
      entryRef: data.entryRef.present ? data.entryRef.value : this.entryRef,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      channel: data.channel.present ? data.channel.value : this.channel,
      position: data.position.present ? data.position.value : this.position,
      snapQuery: data.snapQuery.present ? data.snapQuery.value : this.snapQuery,
      snapYear: data.snapYear.present ? data.snapYear.value : this.snapYear,
      snapMonth: data.snapMonth.present ? data.snapMonth.value : this.snapMonth,
      snapTenDay: data.snapTenDay.present
          ? data.snapTenDay.value
          : this.snapTenDay,
      snapChannel: data.snapChannel.present
          ? data.snapChannel.value
          : this.snapChannel,
      snapCategory: data.snapCategory.present
          ? data.snapCategory.value
          : this.snapCategory,
      snapSort: data.snapSort.present ? data.snapSort.value : this.snapSort,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bookmark(')
          ..write('id: $id, ')
          ..write('postRef: $postRef, ')
          ..write('entryRef: $entryRef, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('channel: $channel, ')
          ..write('position: $position, ')
          ..write('snapQuery: $snapQuery, ')
          ..write('snapYear: $snapYear, ')
          ..write('snapMonth: $snapMonth, ')
          ..write('snapTenDay: $snapTenDay, ')
          ..write('snapChannel: $snapChannel, ')
          ..write('snapCategory: $snapCategory, ')
          ..write('snapSort: $snapSort, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    postRef,
    entryRef,
    title,
    author,
    channel,
    position,
    snapQuery,
    snapYear,
    snapMonth,
    snapTenDay,
    snapChannel,
    snapCategory,
    snapSort,
    note,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bookmark &&
          other.id == this.id &&
          other.postRef == this.postRef &&
          other.entryRef == this.entryRef &&
          other.title == this.title &&
          other.author == this.author &&
          other.channel == this.channel &&
          other.position == this.position &&
          other.snapQuery == this.snapQuery &&
          other.snapYear == this.snapYear &&
          other.snapMonth == this.snapMonth &&
          other.snapTenDay == this.snapTenDay &&
          other.snapChannel == this.snapChannel &&
          other.snapCategory == this.snapCategory &&
          other.snapSort == this.snapSort &&
          other.note == this.note &&
          other.createdAt == this.createdAt);
}

class BookmarksCompanion extends UpdateCompanion<Bookmark> {
  final Value<int> id;
  final Value<int?> postRef;
  final Value<int?> entryRef;
  final Value<String> title;
  final Value<String?> author;
  final Value<String?> channel;
  final Value<int> position;
  final Value<String?> snapQuery;
  final Value<String?> snapYear;
  final Value<String?> snapMonth;
  final Value<String?> snapTenDay;
  final Value<String?> snapChannel;
  final Value<String?> snapCategory;
  final Value<String?> snapSort;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  const BookmarksCompanion({
    this.id = const Value.absent(),
    this.postRef = const Value.absent(),
    this.entryRef = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.channel = const Value.absent(),
    this.position = const Value.absent(),
    this.snapQuery = const Value.absent(),
    this.snapYear = const Value.absent(),
    this.snapMonth = const Value.absent(),
    this.snapTenDay = const Value.absent(),
    this.snapChannel = const Value.absent(),
    this.snapCategory = const Value.absent(),
    this.snapSort = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  BookmarksCompanion.insert({
    this.id = const Value.absent(),
    this.postRef = const Value.absent(),
    this.entryRef = const Value.absent(),
    required String title,
    this.author = const Value.absent(),
    this.channel = const Value.absent(),
    this.position = const Value.absent(),
    this.snapQuery = const Value.absent(),
    this.snapYear = const Value.absent(),
    this.snapMonth = const Value.absent(),
    this.snapTenDay = const Value.absent(),
    this.snapChannel = const Value.absent(),
    this.snapCategory = const Value.absent(),
    this.snapSort = const Value.absent(),
    this.note = const Value.absent(),
    required DateTime createdAt,
  }) : title = Value(title),
       createdAt = Value(createdAt);
  static Insertable<Bookmark> custom({
    Expression<int>? id,
    Expression<int>? postRef,
    Expression<int>? entryRef,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? channel,
    Expression<int>? position,
    Expression<String>? snapQuery,
    Expression<String>? snapYear,
    Expression<String>? snapMonth,
    Expression<String>? snapTenDay,
    Expression<String>? snapChannel,
    Expression<String>? snapCategory,
    Expression<String>? snapSort,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (postRef != null) 'post_ref': postRef,
      if (entryRef != null) 'entry_ref': entryRef,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (channel != null) 'channel': channel,
      if (position != null) 'position': position,
      if (snapQuery != null) 'snap_query': snapQuery,
      if (snapYear != null) 'snap_year': snapYear,
      if (snapMonth != null) 'snap_month': snapMonth,
      if (snapTenDay != null) 'snap_ten_day': snapTenDay,
      if (snapChannel != null) 'snap_channel': snapChannel,
      if (snapCategory != null) 'snap_category': snapCategory,
      if (snapSort != null) 'snap_sort': snapSort,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  BookmarksCompanion copyWith({
    Value<int>? id,
    Value<int?>? postRef,
    Value<int?>? entryRef,
    Value<String>? title,
    Value<String?>? author,
    Value<String?>? channel,
    Value<int>? position,
    Value<String?>? snapQuery,
    Value<String?>? snapYear,
    Value<String?>? snapMonth,
    Value<String?>? snapTenDay,
    Value<String?>? snapChannel,
    Value<String?>? snapCategory,
    Value<String?>? snapSort,
    Value<String?>? note,
    Value<DateTime>? createdAt,
  }) {
    return BookmarksCompanion(
      id: id ?? this.id,
      postRef: postRef ?? this.postRef,
      entryRef: entryRef ?? this.entryRef,
      title: title ?? this.title,
      author: author ?? this.author,
      channel: channel ?? this.channel,
      position: position ?? this.position,
      snapQuery: snapQuery ?? this.snapQuery,
      snapYear: snapYear ?? this.snapYear,
      snapMonth: snapMonth ?? this.snapMonth,
      snapTenDay: snapTenDay ?? this.snapTenDay,
      snapChannel: snapChannel ?? this.snapChannel,
      snapCategory: snapCategory ?? this.snapCategory,
      snapSort: snapSort ?? this.snapSort,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (postRef.present) {
      map['post_ref'] = Variable<int>(postRef.value);
    }
    if (entryRef.present) {
      map['entry_ref'] = Variable<int>(entryRef.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (channel.present) {
      map['channel'] = Variable<String>(channel.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (snapQuery.present) {
      map['snap_query'] = Variable<String>(snapQuery.value);
    }
    if (snapYear.present) {
      map['snap_year'] = Variable<String>(snapYear.value);
    }
    if (snapMonth.present) {
      map['snap_month'] = Variable<String>(snapMonth.value);
    }
    if (snapTenDay.present) {
      map['snap_ten_day'] = Variable<String>(snapTenDay.value);
    }
    if (snapChannel.present) {
      map['snap_channel'] = Variable<String>(snapChannel.value);
    }
    if (snapCategory.present) {
      map['snap_category'] = Variable<String>(snapCategory.value);
    }
    if (snapSort.present) {
      map['snap_sort'] = Variable<String>(snapSort.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksCompanion(')
          ..write('id: $id, ')
          ..write('postRef: $postRef, ')
          ..write('entryRef: $entryRef, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('channel: $channel, ')
          ..write('position: $position, ')
          ..write('snapQuery: $snapQuery, ')
          ..write('snapYear: $snapYear, ')
          ..write('snapMonth: $snapMonth, ')
          ..write('snapTenDay: $snapTenDay, ')
          ..write('snapChannel: $snapChannel, ')
          ..write('snapCategory: $snapCategory, ')
          ..write('snapSort: $snapSort, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $FavoritesTable extends Favorites
    with TableInfo<$FavoritesTable, Favorite> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoritesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _targetTypeMeta = const VerificationMeta(
    'targetType',
  );
  @override
  late final GeneratedColumn<String> targetType = GeneratedColumn<String>(
    'target_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<int> targetId = GeneratedColumn<int>(
    'target_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subtitleMeta = const VerificationMeta(
    'subtitle',
  );
  @override
  late final GeneratedColumn<String> subtitle = GeneratedColumn<String>(
    'subtitle',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    targetType,
    targetId,
    title,
    subtitle,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<Favorite> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('target_type')) {
      context.handle(
        _targetTypeMeta,
        targetType.isAcceptableOrUnknown(data['target_type']!, _targetTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_targetTypeMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('subtitle')) {
      context.handle(
        _subtitleMeta,
        subtitle.isAcceptableOrUnknown(data['subtitle']!, _subtitleMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Favorite map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Favorite(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      targetType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_type'],
      )!,
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      subtitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subtitle'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $FavoritesTable createAlias(String alias) {
    return $FavoritesTable(attachedDatabase, alias);
  }
}

class Favorite extends DataClass implements Insertable<Favorite> {
  final int id;

  /// 'book_group' | 'post' | 'entry'。
  final String targetType;
  final int targetId;
  final String title;
  final String? subtitle;
  final DateTime addedAt;
  const Favorite({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.title,
    this.subtitle,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['target_type'] = Variable<String>(targetType);
    map['target_id'] = Variable<int>(targetId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || subtitle != null) {
      map['subtitle'] = Variable<String>(subtitle);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  FavoritesCompanion toCompanion(bool nullToAbsent) {
    return FavoritesCompanion(
      id: Value(id),
      targetType: Value(targetType),
      targetId: Value(targetId),
      title: Value(title),
      subtitle: subtitle == null && nullToAbsent
          ? const Value.absent()
          : Value(subtitle),
      addedAt: Value(addedAt),
    );
  }

  factory Favorite.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Favorite(
      id: serializer.fromJson<int>(json['id']),
      targetType: serializer.fromJson<String>(json['targetType']),
      targetId: serializer.fromJson<int>(json['targetId']),
      title: serializer.fromJson<String>(json['title']),
      subtitle: serializer.fromJson<String?>(json['subtitle']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'targetType': serializer.toJson<String>(targetType),
      'targetId': serializer.toJson<int>(targetId),
      'title': serializer.toJson<String>(title),
      'subtitle': serializer.toJson<String?>(subtitle),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  Favorite copyWith({
    int? id,
    String? targetType,
    int? targetId,
    String? title,
    Value<String?> subtitle = const Value.absent(),
    DateTime? addedAt,
  }) => Favorite(
    id: id ?? this.id,
    targetType: targetType ?? this.targetType,
    targetId: targetId ?? this.targetId,
    title: title ?? this.title,
    subtitle: subtitle.present ? subtitle.value : this.subtitle,
    addedAt: addedAt ?? this.addedAt,
  );
  Favorite copyWithCompanion(FavoritesCompanion data) {
    return Favorite(
      id: data.id.present ? data.id.value : this.id,
      targetType: data.targetType.present
          ? data.targetType.value
          : this.targetType,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      title: data.title.present ? data.title.value : this.title,
      subtitle: data.subtitle.present ? data.subtitle.value : this.subtitle,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Favorite(')
          ..write('id: $id, ')
          ..write('targetType: $targetType, ')
          ..write('targetId: $targetId, ')
          ..write('title: $title, ')
          ..write('subtitle: $subtitle, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, targetType, targetId, title, subtitle, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Favorite &&
          other.id == this.id &&
          other.targetType == this.targetType &&
          other.targetId == this.targetId &&
          other.title == this.title &&
          other.subtitle == this.subtitle &&
          other.addedAt == this.addedAt);
}

class FavoritesCompanion extends UpdateCompanion<Favorite> {
  final Value<int> id;
  final Value<String> targetType;
  final Value<int> targetId;
  final Value<String> title;
  final Value<String?> subtitle;
  final Value<DateTime> addedAt;
  const FavoritesCompanion({
    this.id = const Value.absent(),
    this.targetType = const Value.absent(),
    this.targetId = const Value.absent(),
    this.title = const Value.absent(),
    this.subtitle = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  FavoritesCompanion.insert({
    this.id = const Value.absent(),
    required String targetType,
    required int targetId,
    required String title,
    this.subtitle = const Value.absent(),
    required DateTime addedAt,
  }) : targetType = Value(targetType),
       targetId = Value(targetId),
       title = Value(title),
       addedAt = Value(addedAt);
  static Insertable<Favorite> custom({
    Expression<int>? id,
    Expression<String>? targetType,
    Expression<int>? targetId,
    Expression<String>? title,
    Expression<String>? subtitle,
    Expression<DateTime>? addedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (targetType != null) 'target_type': targetType,
      if (targetId != null) 'target_id': targetId,
      if (title != null) 'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  FavoritesCompanion copyWith({
    Value<int>? id,
    Value<String>? targetType,
    Value<int>? targetId,
    Value<String>? title,
    Value<String?>? subtitle,
    Value<DateTime>? addedAt,
  }) {
    return FavoritesCompanion(
      id: id ?? this.id,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (targetType.present) {
      map['target_type'] = Variable<String>(targetType.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<int>(targetId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (subtitle.present) {
      map['subtitle'] = Variable<String>(subtitle.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoritesCompanion(')
          ..write('id: $id, ')
          ..write('targetType: $targetType, ')
          ..write('targetId: $targetId, ')
          ..write('title: $title, ')
          ..write('subtitle: $subtitle, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class $CollectionStateTable extends CollectionState
    with TableInfo<$CollectionStateTable, CollectionStateEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectionStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _fnameMeta = const VerificationMeta('fname');
  @override
  late final GeneratedColumn<String> fname = GeneratedColumn<String>(
    'fname',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fidMeta = const VerificationMeta('fid');
  @override
  late final GeneratedColumn<int> fid = GeneratedColumn<int>(
    'fid',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _lastThreadTimeMeta = const VerificationMeta(
    'lastThreadTime',
  );
  @override
  late final GeneratedColumn<int> lastThreadTime = GeneratedColumn<int>(
    'last_thread_time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastTidMeta = const VerificationMeta(
    'lastTid',
  );
  @override
  late final GeneratedColumn<int> lastTid = GeneratedColumn<int>(
    'last_tid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastRunAtMeta = const VerificationMeta(
    'lastRunAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastRunAt = GeneratedColumn<DateTime>(
    'last_run_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastStatusMeta = const VerificationMeta(
    'lastStatus',
  );
  @override
  late final GeneratedColumn<String> lastStatus = GeneratedColumn<String>(
    'last_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('never'),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _consecutiveFailuresMeta =
      const VerificationMeta('consecutiveFailures');
  @override
  late final GeneratedColumn<int> consecutiveFailures = GeneratedColumn<int>(
    'consecutive_failures',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _cooldownUntilMeta = const VerificationMeta(
    'cooldownUntil',
  );
  @override
  late final GeneratedColumn<DateTime> cooldownUntil =
      GeneratedColumn<DateTime>(
        'cooldown_until',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _newSinceVisitMeta = const VerificationMeta(
    'newSinceVisit',
  );
  @override
  late final GeneratedColumn<int> newSinceVisit = GeneratedColumn<int>(
    'new_since_visit',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalThreadsMeta = const VerificationMeta(
    'totalThreads',
  );
  @override
  late final GeneratedColumn<int> totalThreads = GeneratedColumn<int>(
    'total_threads',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalFloorsMeta = const VerificationMeta(
    'totalFloors',
  );
  @override
  late final GeneratedColumn<int> totalFloors = GeneratedColumn<int>(
    'total_floors',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    fname,
    fid,
    enabled,
    lastThreadTime,
    lastTid,
    lastRunAt,
    lastStatus,
    lastError,
    consecutiveFailures,
    cooldownUntil,
    newSinceVisit,
    totalThreads,
    totalFloors,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collection_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<CollectionStateEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('fname')) {
      context.handle(
        _fnameMeta,
        fname.isAcceptableOrUnknown(data['fname']!, _fnameMeta),
      );
    } else if (isInserting) {
      context.missing(_fnameMeta);
    }
    if (data.containsKey('fid')) {
      context.handle(
        _fidMeta,
        fid.isAcceptableOrUnknown(data['fid']!, _fidMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('last_thread_time')) {
      context.handle(
        _lastThreadTimeMeta,
        lastThreadTime.isAcceptableOrUnknown(
          data['last_thread_time']!,
          _lastThreadTimeMeta,
        ),
      );
    }
    if (data.containsKey('last_tid')) {
      context.handle(
        _lastTidMeta,
        lastTid.isAcceptableOrUnknown(data['last_tid']!, _lastTidMeta),
      );
    }
    if (data.containsKey('last_run_at')) {
      context.handle(
        _lastRunAtMeta,
        lastRunAt.isAcceptableOrUnknown(data['last_run_at']!, _lastRunAtMeta),
      );
    }
    if (data.containsKey('last_status')) {
      context.handle(
        _lastStatusMeta,
        lastStatus.isAcceptableOrUnknown(data['last_status']!, _lastStatusMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('consecutive_failures')) {
      context.handle(
        _consecutiveFailuresMeta,
        consecutiveFailures.isAcceptableOrUnknown(
          data['consecutive_failures']!,
          _consecutiveFailuresMeta,
        ),
      );
    }
    if (data.containsKey('cooldown_until')) {
      context.handle(
        _cooldownUntilMeta,
        cooldownUntil.isAcceptableOrUnknown(
          data['cooldown_until']!,
          _cooldownUntilMeta,
        ),
      );
    }
    if (data.containsKey('new_since_visit')) {
      context.handle(
        _newSinceVisitMeta,
        newSinceVisit.isAcceptableOrUnknown(
          data['new_since_visit']!,
          _newSinceVisitMeta,
        ),
      );
    }
    if (data.containsKey('total_threads')) {
      context.handle(
        _totalThreadsMeta,
        totalThreads.isAcceptableOrUnknown(
          data['total_threads']!,
          _totalThreadsMeta,
        ),
      );
    }
    if (data.containsKey('total_floors')) {
      context.handle(
        _totalFloorsMeta,
        totalFloors.isAcceptableOrUnknown(
          data['total_floors']!,
          _totalFloorsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {fname};
  @override
  CollectionStateEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CollectionStateEntry(
      fname: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fname'],
      )!,
      fid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fid'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      lastThreadTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_thread_time'],
      )!,
      lastTid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_tid'],
      )!,
      lastRunAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_run_at'],
      ),
      lastStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_status'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      consecutiveFailures: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}consecutive_failures'],
      )!,
      cooldownUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cooldown_until'],
      ),
      newSinceVisit: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}new_since_visit'],
      )!,
      totalThreads: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_threads'],
      )!,
      totalFloors: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_floors'],
      )!,
    );
  }

  @override
  $CollectionStateTable createAlias(String alias) {
    return $CollectionStateTable(attachedDatabase, alias);
  }
}

class CollectionStateEntry extends DataClass
    implements Insertable<CollectionStateEntry> {
  /// 吧名（主键）。
  final String fname;
  final int? fid;
  final bool enabled;

  /// 水位：已采最新 create_time（epoch 秒）。
  final int lastThreadTime;

  /// 水位：已采最大 tid。
  final int lastTid;
  final DateTime? lastRunAt;

  /// never/ok/partial/api_error/rate_limited/canceled。
  final String lastStatus;
  final String? lastError;
  final int consecutiveFailures;
  final DateTime? cooldownUntil;

  /// 首页红点。
  final int newSinceVisit;
  final int totalThreads;
  final int totalFloors;
  const CollectionStateEntry({
    required this.fname,
    this.fid,
    required this.enabled,
    required this.lastThreadTime,
    required this.lastTid,
    this.lastRunAt,
    required this.lastStatus,
    this.lastError,
    required this.consecutiveFailures,
    this.cooldownUntil,
    required this.newSinceVisit,
    required this.totalThreads,
    required this.totalFloors,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['fname'] = Variable<String>(fname);
    if (!nullToAbsent || fid != null) {
      map['fid'] = Variable<int>(fid);
    }
    map['enabled'] = Variable<bool>(enabled);
    map['last_thread_time'] = Variable<int>(lastThreadTime);
    map['last_tid'] = Variable<int>(lastTid);
    if (!nullToAbsent || lastRunAt != null) {
      map['last_run_at'] = Variable<DateTime>(lastRunAt);
    }
    map['last_status'] = Variable<String>(lastStatus);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['consecutive_failures'] = Variable<int>(consecutiveFailures);
    if (!nullToAbsent || cooldownUntil != null) {
      map['cooldown_until'] = Variable<DateTime>(cooldownUntil);
    }
    map['new_since_visit'] = Variable<int>(newSinceVisit);
    map['total_threads'] = Variable<int>(totalThreads);
    map['total_floors'] = Variable<int>(totalFloors);
    return map;
  }

  CollectionStateCompanion toCompanion(bool nullToAbsent) {
    return CollectionStateCompanion(
      fname: Value(fname),
      fid: fid == null && nullToAbsent ? const Value.absent() : Value(fid),
      enabled: Value(enabled),
      lastThreadTime: Value(lastThreadTime),
      lastTid: Value(lastTid),
      lastRunAt: lastRunAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastRunAt),
      lastStatus: Value(lastStatus),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      consecutiveFailures: Value(consecutiveFailures),
      cooldownUntil: cooldownUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(cooldownUntil),
      newSinceVisit: Value(newSinceVisit),
      totalThreads: Value(totalThreads),
      totalFloors: Value(totalFloors),
    );
  }

  factory CollectionStateEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CollectionStateEntry(
      fname: serializer.fromJson<String>(json['fname']),
      fid: serializer.fromJson<int?>(json['fid']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      lastThreadTime: serializer.fromJson<int>(json['lastThreadTime']),
      lastTid: serializer.fromJson<int>(json['lastTid']),
      lastRunAt: serializer.fromJson<DateTime?>(json['lastRunAt']),
      lastStatus: serializer.fromJson<String>(json['lastStatus']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      consecutiveFailures: serializer.fromJson<int>(
        json['consecutiveFailures'],
      ),
      cooldownUntil: serializer.fromJson<DateTime?>(json['cooldownUntil']),
      newSinceVisit: serializer.fromJson<int>(json['newSinceVisit']),
      totalThreads: serializer.fromJson<int>(json['totalThreads']),
      totalFloors: serializer.fromJson<int>(json['totalFloors']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'fname': serializer.toJson<String>(fname),
      'fid': serializer.toJson<int?>(fid),
      'enabled': serializer.toJson<bool>(enabled),
      'lastThreadTime': serializer.toJson<int>(lastThreadTime),
      'lastTid': serializer.toJson<int>(lastTid),
      'lastRunAt': serializer.toJson<DateTime?>(lastRunAt),
      'lastStatus': serializer.toJson<String>(lastStatus),
      'lastError': serializer.toJson<String?>(lastError),
      'consecutiveFailures': serializer.toJson<int>(consecutiveFailures),
      'cooldownUntil': serializer.toJson<DateTime?>(cooldownUntil),
      'newSinceVisit': serializer.toJson<int>(newSinceVisit),
      'totalThreads': serializer.toJson<int>(totalThreads),
      'totalFloors': serializer.toJson<int>(totalFloors),
    };
  }

  CollectionStateEntry copyWith({
    String? fname,
    Value<int?> fid = const Value.absent(),
    bool? enabled,
    int? lastThreadTime,
    int? lastTid,
    Value<DateTime?> lastRunAt = const Value.absent(),
    String? lastStatus,
    Value<String?> lastError = const Value.absent(),
    int? consecutiveFailures,
    Value<DateTime?> cooldownUntil = const Value.absent(),
    int? newSinceVisit,
    int? totalThreads,
    int? totalFloors,
  }) => CollectionStateEntry(
    fname: fname ?? this.fname,
    fid: fid.present ? fid.value : this.fid,
    enabled: enabled ?? this.enabled,
    lastThreadTime: lastThreadTime ?? this.lastThreadTime,
    lastTid: lastTid ?? this.lastTid,
    lastRunAt: lastRunAt.present ? lastRunAt.value : this.lastRunAt,
    lastStatus: lastStatus ?? this.lastStatus,
    lastError: lastError.present ? lastError.value : this.lastError,
    consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
    cooldownUntil: cooldownUntil.present
        ? cooldownUntil.value
        : this.cooldownUntil,
    newSinceVisit: newSinceVisit ?? this.newSinceVisit,
    totalThreads: totalThreads ?? this.totalThreads,
    totalFloors: totalFloors ?? this.totalFloors,
  );
  CollectionStateEntry copyWithCompanion(CollectionStateCompanion data) {
    return CollectionStateEntry(
      fname: data.fname.present ? data.fname.value : this.fname,
      fid: data.fid.present ? data.fid.value : this.fid,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      lastThreadTime: data.lastThreadTime.present
          ? data.lastThreadTime.value
          : this.lastThreadTime,
      lastTid: data.lastTid.present ? data.lastTid.value : this.lastTid,
      lastRunAt: data.lastRunAt.present ? data.lastRunAt.value : this.lastRunAt,
      lastStatus: data.lastStatus.present
          ? data.lastStatus.value
          : this.lastStatus,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      consecutiveFailures: data.consecutiveFailures.present
          ? data.consecutiveFailures.value
          : this.consecutiveFailures,
      cooldownUntil: data.cooldownUntil.present
          ? data.cooldownUntil.value
          : this.cooldownUntil,
      newSinceVisit: data.newSinceVisit.present
          ? data.newSinceVisit.value
          : this.newSinceVisit,
      totalThreads: data.totalThreads.present
          ? data.totalThreads.value
          : this.totalThreads,
      totalFloors: data.totalFloors.present
          ? data.totalFloors.value
          : this.totalFloors,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CollectionStateEntry(')
          ..write('fname: $fname, ')
          ..write('fid: $fid, ')
          ..write('enabled: $enabled, ')
          ..write('lastThreadTime: $lastThreadTime, ')
          ..write('lastTid: $lastTid, ')
          ..write('lastRunAt: $lastRunAt, ')
          ..write('lastStatus: $lastStatus, ')
          ..write('lastError: $lastError, ')
          ..write('consecutiveFailures: $consecutiveFailures, ')
          ..write('cooldownUntil: $cooldownUntil, ')
          ..write('newSinceVisit: $newSinceVisit, ')
          ..write('totalThreads: $totalThreads, ')
          ..write('totalFloors: $totalFloors')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    fname,
    fid,
    enabled,
    lastThreadTime,
    lastTid,
    lastRunAt,
    lastStatus,
    lastError,
    consecutiveFailures,
    cooldownUntil,
    newSinceVisit,
    totalThreads,
    totalFloors,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CollectionStateEntry &&
          other.fname == this.fname &&
          other.fid == this.fid &&
          other.enabled == this.enabled &&
          other.lastThreadTime == this.lastThreadTime &&
          other.lastTid == this.lastTid &&
          other.lastRunAt == this.lastRunAt &&
          other.lastStatus == this.lastStatus &&
          other.lastError == this.lastError &&
          other.consecutiveFailures == this.consecutiveFailures &&
          other.cooldownUntil == this.cooldownUntil &&
          other.newSinceVisit == this.newSinceVisit &&
          other.totalThreads == this.totalThreads &&
          other.totalFloors == this.totalFloors);
}

class CollectionStateCompanion extends UpdateCompanion<CollectionStateEntry> {
  final Value<String> fname;
  final Value<int?> fid;
  final Value<bool> enabled;
  final Value<int> lastThreadTime;
  final Value<int> lastTid;
  final Value<DateTime?> lastRunAt;
  final Value<String> lastStatus;
  final Value<String?> lastError;
  final Value<int> consecutiveFailures;
  final Value<DateTime?> cooldownUntil;
  final Value<int> newSinceVisit;
  final Value<int> totalThreads;
  final Value<int> totalFloors;
  final Value<int> rowid;
  const CollectionStateCompanion({
    this.fname = const Value.absent(),
    this.fid = const Value.absent(),
    this.enabled = const Value.absent(),
    this.lastThreadTime = const Value.absent(),
    this.lastTid = const Value.absent(),
    this.lastRunAt = const Value.absent(),
    this.lastStatus = const Value.absent(),
    this.lastError = const Value.absent(),
    this.consecutiveFailures = const Value.absent(),
    this.cooldownUntil = const Value.absent(),
    this.newSinceVisit = const Value.absent(),
    this.totalThreads = const Value.absent(),
    this.totalFloors = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CollectionStateCompanion.insert({
    required String fname,
    this.fid = const Value.absent(),
    this.enabled = const Value.absent(),
    this.lastThreadTime = const Value.absent(),
    this.lastTid = const Value.absent(),
    this.lastRunAt = const Value.absent(),
    this.lastStatus = const Value.absent(),
    this.lastError = const Value.absent(),
    this.consecutiveFailures = const Value.absent(),
    this.cooldownUntil = const Value.absent(),
    this.newSinceVisit = const Value.absent(),
    this.totalThreads = const Value.absent(),
    this.totalFloors = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : fname = Value(fname);
  static Insertable<CollectionStateEntry> custom({
    Expression<String>? fname,
    Expression<int>? fid,
    Expression<bool>? enabled,
    Expression<int>? lastThreadTime,
    Expression<int>? lastTid,
    Expression<DateTime>? lastRunAt,
    Expression<String>? lastStatus,
    Expression<String>? lastError,
    Expression<int>? consecutiveFailures,
    Expression<DateTime>? cooldownUntil,
    Expression<int>? newSinceVisit,
    Expression<int>? totalThreads,
    Expression<int>? totalFloors,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (fname != null) 'fname': fname,
      if (fid != null) 'fid': fid,
      if (enabled != null) 'enabled': enabled,
      if (lastThreadTime != null) 'last_thread_time': lastThreadTime,
      if (lastTid != null) 'last_tid': lastTid,
      if (lastRunAt != null) 'last_run_at': lastRunAt,
      if (lastStatus != null) 'last_status': lastStatus,
      if (lastError != null) 'last_error': lastError,
      if (consecutiveFailures != null)
        'consecutive_failures': consecutiveFailures,
      if (cooldownUntil != null) 'cooldown_until': cooldownUntil,
      if (newSinceVisit != null) 'new_since_visit': newSinceVisit,
      if (totalThreads != null) 'total_threads': totalThreads,
      if (totalFloors != null) 'total_floors': totalFloors,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CollectionStateCompanion copyWith({
    Value<String>? fname,
    Value<int?>? fid,
    Value<bool>? enabled,
    Value<int>? lastThreadTime,
    Value<int>? lastTid,
    Value<DateTime?>? lastRunAt,
    Value<String>? lastStatus,
    Value<String?>? lastError,
    Value<int>? consecutiveFailures,
    Value<DateTime?>? cooldownUntil,
    Value<int>? newSinceVisit,
    Value<int>? totalThreads,
    Value<int>? totalFloors,
    Value<int>? rowid,
  }) {
    return CollectionStateCompanion(
      fname: fname ?? this.fname,
      fid: fid ?? this.fid,
      enabled: enabled ?? this.enabled,
      lastThreadTime: lastThreadTime ?? this.lastThreadTime,
      lastTid: lastTid ?? this.lastTid,
      lastRunAt: lastRunAt ?? this.lastRunAt,
      lastStatus: lastStatus ?? this.lastStatus,
      lastError: lastError ?? this.lastError,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      cooldownUntil: cooldownUntil ?? this.cooldownUntil,
      newSinceVisit: newSinceVisit ?? this.newSinceVisit,
      totalThreads: totalThreads ?? this.totalThreads,
      totalFloors: totalFloors ?? this.totalFloors,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (fname.present) {
      map['fname'] = Variable<String>(fname.value);
    }
    if (fid.present) {
      map['fid'] = Variable<int>(fid.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (lastThreadTime.present) {
      map['last_thread_time'] = Variable<int>(lastThreadTime.value);
    }
    if (lastTid.present) {
      map['last_tid'] = Variable<int>(lastTid.value);
    }
    if (lastRunAt.present) {
      map['last_run_at'] = Variable<DateTime>(lastRunAt.value);
    }
    if (lastStatus.present) {
      map['last_status'] = Variable<String>(lastStatus.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (consecutiveFailures.present) {
      map['consecutive_failures'] = Variable<int>(consecutiveFailures.value);
    }
    if (cooldownUntil.present) {
      map['cooldown_until'] = Variable<DateTime>(cooldownUntil.value);
    }
    if (newSinceVisit.present) {
      map['new_since_visit'] = Variable<int>(newSinceVisit.value);
    }
    if (totalThreads.present) {
      map['total_threads'] = Variable<int>(totalThreads.value);
    }
    if (totalFloors.present) {
      map['total_floors'] = Variable<int>(totalFloors.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectionStateCompanion(')
          ..write('fname: $fname, ')
          ..write('fid: $fid, ')
          ..write('enabled: $enabled, ')
          ..write('lastThreadTime: $lastThreadTime, ')
          ..write('lastTid: $lastTid, ')
          ..write('lastRunAt: $lastRunAt, ')
          ..write('lastStatus: $lastStatus, ')
          ..write('lastError: $lastError, ')
          ..write('consecutiveFailures: $consecutiveFailures, ')
          ..write('cooldownUntil: $cooldownUntil, ')
          ..write('newSinceVisit: $newSinceVisit, ')
          ..write('totalThreads: $totalThreads, ')
          ..write('totalFloors: $totalFloors, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CollectionLogsTable extends CollectionLogs
    with TableInfo<$CollectionLogsTable, CollectionLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectionLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _fnameMeta = const VerificationMeta('fname');
  @override
  late final GeneratedColumn<String> fname = GeneratedColumn<String>(
    'fname',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runAtMeta = const VerificationMeta('runAt');
  @override
  late final GeneratedColumn<DateTime> runAt = GeneratedColumn<DateTime>(
    'run_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _threadsAddedMeta = const VerificationMeta(
    'threadsAdded',
  );
  @override
  late final GeneratedColumn<int> threadsAdded = GeneratedColumn<int>(
    'threads_added',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _floorsAddedMeta = const VerificationMeta(
    'floorsAdded',
  );
  @override
  late final GeneratedColumn<int> floorsAdded = GeneratedColumn<int>(
    'floors_added',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _entriesAddedMeta = const VerificationMeta(
    'entriesAdded',
  );
  @override
  late final GeneratedColumn<int> entriesAdded = GeneratedColumn<int>(
    'entries_added',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _skippedDupMeta = const VerificationMeta(
    'skippedDup',
  );
  @override
  late final GeneratedColumn<int> skippedDup = GeneratedColumn<int>(
    'skipped_dup',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fname,
    runAt,
    status,
    threadsAdded,
    floorsAdded,
    entriesAdded,
    skippedDup,
    detail,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collection_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<CollectionLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('fname')) {
      context.handle(
        _fnameMeta,
        fname.isAcceptableOrUnknown(data['fname']!, _fnameMeta),
      );
    } else if (isInserting) {
      context.missing(_fnameMeta);
    }
    if (data.containsKey('run_at')) {
      context.handle(
        _runAtMeta,
        runAt.isAcceptableOrUnknown(data['run_at']!, _runAtMeta),
      );
    } else if (isInserting) {
      context.missing(_runAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('threads_added')) {
      context.handle(
        _threadsAddedMeta,
        threadsAdded.isAcceptableOrUnknown(
          data['threads_added']!,
          _threadsAddedMeta,
        ),
      );
    }
    if (data.containsKey('floors_added')) {
      context.handle(
        _floorsAddedMeta,
        floorsAdded.isAcceptableOrUnknown(
          data['floors_added']!,
          _floorsAddedMeta,
        ),
      );
    }
    if (data.containsKey('entries_added')) {
      context.handle(
        _entriesAddedMeta,
        entriesAdded.isAcceptableOrUnknown(
          data['entries_added']!,
          _entriesAddedMeta,
        ),
      );
    }
    if (data.containsKey('skipped_dup')) {
      context.handle(
        _skippedDupMeta,
        skippedDup.isAcceptableOrUnknown(data['skipped_dup']!, _skippedDupMeta),
      );
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CollectionLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CollectionLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      fname: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fname'],
      )!,
      runAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}run_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      threadsAdded: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}threads_added'],
      )!,
      floorsAdded: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}floors_added'],
      )!,
      entriesAdded: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entries_added'],
      )!,
      skippedDup: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}skipped_dup'],
      )!,
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      ),
    );
  }

  @override
  $CollectionLogsTable createAlias(String alias) {
    return $CollectionLogsTable(attachedDatabase, alias);
  }
}

class CollectionLog extends DataClass implements Insertable<CollectionLog> {
  final int id;
  final String fname;
  final DateTime runAt;
  final String status;
  final int threadsAdded;
  final int floorsAdded;
  final int entriesAdded;
  final int skippedDup;
  final String? detail;
  const CollectionLog({
    required this.id,
    required this.fname,
    required this.runAt,
    required this.status,
    required this.threadsAdded,
    required this.floorsAdded,
    required this.entriesAdded,
    required this.skippedDup,
    this.detail,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['fname'] = Variable<String>(fname);
    map['run_at'] = Variable<DateTime>(runAt);
    map['status'] = Variable<String>(status);
    map['threads_added'] = Variable<int>(threadsAdded);
    map['floors_added'] = Variable<int>(floorsAdded);
    map['entries_added'] = Variable<int>(entriesAdded);
    map['skipped_dup'] = Variable<int>(skippedDup);
    if (!nullToAbsent || detail != null) {
      map['detail'] = Variable<String>(detail);
    }
    return map;
  }

  CollectionLogsCompanion toCompanion(bool nullToAbsent) {
    return CollectionLogsCompanion(
      id: Value(id),
      fname: Value(fname),
      runAt: Value(runAt),
      status: Value(status),
      threadsAdded: Value(threadsAdded),
      floorsAdded: Value(floorsAdded),
      entriesAdded: Value(entriesAdded),
      skippedDup: Value(skippedDup),
      detail: detail == null && nullToAbsent
          ? const Value.absent()
          : Value(detail),
    );
  }

  factory CollectionLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CollectionLog(
      id: serializer.fromJson<int>(json['id']),
      fname: serializer.fromJson<String>(json['fname']),
      runAt: serializer.fromJson<DateTime>(json['runAt']),
      status: serializer.fromJson<String>(json['status']),
      threadsAdded: serializer.fromJson<int>(json['threadsAdded']),
      floorsAdded: serializer.fromJson<int>(json['floorsAdded']),
      entriesAdded: serializer.fromJson<int>(json['entriesAdded']),
      skippedDup: serializer.fromJson<int>(json['skippedDup']),
      detail: serializer.fromJson<String?>(json['detail']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fname': serializer.toJson<String>(fname),
      'runAt': serializer.toJson<DateTime>(runAt),
      'status': serializer.toJson<String>(status),
      'threadsAdded': serializer.toJson<int>(threadsAdded),
      'floorsAdded': serializer.toJson<int>(floorsAdded),
      'entriesAdded': serializer.toJson<int>(entriesAdded),
      'skippedDup': serializer.toJson<int>(skippedDup),
      'detail': serializer.toJson<String?>(detail),
    };
  }

  CollectionLog copyWith({
    int? id,
    String? fname,
    DateTime? runAt,
    String? status,
    int? threadsAdded,
    int? floorsAdded,
    int? entriesAdded,
    int? skippedDup,
    Value<String?> detail = const Value.absent(),
  }) => CollectionLog(
    id: id ?? this.id,
    fname: fname ?? this.fname,
    runAt: runAt ?? this.runAt,
    status: status ?? this.status,
    threadsAdded: threadsAdded ?? this.threadsAdded,
    floorsAdded: floorsAdded ?? this.floorsAdded,
    entriesAdded: entriesAdded ?? this.entriesAdded,
    skippedDup: skippedDup ?? this.skippedDup,
    detail: detail.present ? detail.value : this.detail,
  );
  CollectionLog copyWithCompanion(CollectionLogsCompanion data) {
    return CollectionLog(
      id: data.id.present ? data.id.value : this.id,
      fname: data.fname.present ? data.fname.value : this.fname,
      runAt: data.runAt.present ? data.runAt.value : this.runAt,
      status: data.status.present ? data.status.value : this.status,
      threadsAdded: data.threadsAdded.present
          ? data.threadsAdded.value
          : this.threadsAdded,
      floorsAdded: data.floorsAdded.present
          ? data.floorsAdded.value
          : this.floorsAdded,
      entriesAdded: data.entriesAdded.present
          ? data.entriesAdded.value
          : this.entriesAdded,
      skippedDup: data.skippedDup.present
          ? data.skippedDup.value
          : this.skippedDup,
      detail: data.detail.present ? data.detail.value : this.detail,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CollectionLog(')
          ..write('id: $id, ')
          ..write('fname: $fname, ')
          ..write('runAt: $runAt, ')
          ..write('status: $status, ')
          ..write('threadsAdded: $threadsAdded, ')
          ..write('floorsAdded: $floorsAdded, ')
          ..write('entriesAdded: $entriesAdded, ')
          ..write('skippedDup: $skippedDup, ')
          ..write('detail: $detail')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fname,
    runAt,
    status,
    threadsAdded,
    floorsAdded,
    entriesAdded,
    skippedDup,
    detail,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CollectionLog &&
          other.id == this.id &&
          other.fname == this.fname &&
          other.runAt == this.runAt &&
          other.status == this.status &&
          other.threadsAdded == this.threadsAdded &&
          other.floorsAdded == this.floorsAdded &&
          other.entriesAdded == this.entriesAdded &&
          other.skippedDup == this.skippedDup &&
          other.detail == this.detail);
}

class CollectionLogsCompanion extends UpdateCompanion<CollectionLog> {
  final Value<int> id;
  final Value<String> fname;
  final Value<DateTime> runAt;
  final Value<String> status;
  final Value<int> threadsAdded;
  final Value<int> floorsAdded;
  final Value<int> entriesAdded;
  final Value<int> skippedDup;
  final Value<String?> detail;
  const CollectionLogsCompanion({
    this.id = const Value.absent(),
    this.fname = const Value.absent(),
    this.runAt = const Value.absent(),
    this.status = const Value.absent(),
    this.threadsAdded = const Value.absent(),
    this.floorsAdded = const Value.absent(),
    this.entriesAdded = const Value.absent(),
    this.skippedDup = const Value.absent(),
    this.detail = const Value.absent(),
  });
  CollectionLogsCompanion.insert({
    this.id = const Value.absent(),
    required String fname,
    required DateTime runAt,
    required String status,
    this.threadsAdded = const Value.absent(),
    this.floorsAdded = const Value.absent(),
    this.entriesAdded = const Value.absent(),
    this.skippedDup = const Value.absent(),
    this.detail = const Value.absent(),
  }) : fname = Value(fname),
       runAt = Value(runAt),
       status = Value(status);
  static Insertable<CollectionLog> custom({
    Expression<int>? id,
    Expression<String>? fname,
    Expression<DateTime>? runAt,
    Expression<String>? status,
    Expression<int>? threadsAdded,
    Expression<int>? floorsAdded,
    Expression<int>? entriesAdded,
    Expression<int>? skippedDup,
    Expression<String>? detail,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fname != null) 'fname': fname,
      if (runAt != null) 'run_at': runAt,
      if (status != null) 'status': status,
      if (threadsAdded != null) 'threads_added': threadsAdded,
      if (floorsAdded != null) 'floors_added': floorsAdded,
      if (entriesAdded != null) 'entries_added': entriesAdded,
      if (skippedDup != null) 'skipped_dup': skippedDup,
      if (detail != null) 'detail': detail,
    });
  }

  CollectionLogsCompanion copyWith({
    Value<int>? id,
    Value<String>? fname,
    Value<DateTime>? runAt,
    Value<String>? status,
    Value<int>? threadsAdded,
    Value<int>? floorsAdded,
    Value<int>? entriesAdded,
    Value<int>? skippedDup,
    Value<String?>? detail,
  }) {
    return CollectionLogsCompanion(
      id: id ?? this.id,
      fname: fname ?? this.fname,
      runAt: runAt ?? this.runAt,
      status: status ?? this.status,
      threadsAdded: threadsAdded ?? this.threadsAdded,
      floorsAdded: floorsAdded ?? this.floorsAdded,
      entriesAdded: entriesAdded ?? this.entriesAdded,
      skippedDup: skippedDup ?? this.skippedDup,
      detail: detail ?? this.detail,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fname.present) {
      map['fname'] = Variable<String>(fname.value);
    }
    if (runAt.present) {
      map['run_at'] = Variable<DateTime>(runAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (threadsAdded.present) {
      map['threads_added'] = Variable<int>(threadsAdded.value);
    }
    if (floorsAdded.present) {
      map['floors_added'] = Variable<int>(floorsAdded.value);
    }
    if (entriesAdded.present) {
      map['entries_added'] = Variable<int>(entriesAdded.value);
    }
    if (skippedDup.present) {
      map['skipped_dup'] = Variable<int>(skippedDup.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectionLogsCompanion(')
          ..write('id: $id, ')
          ..write('fname: $fname, ')
          ..write('runAt: $runAt, ')
          ..write('status: $status, ')
          ..write('threadsAdded: $threadsAdded, ')
          ..write('floorsAdded: $floorsAdded, ')
          ..write('entriesAdded: $entriesAdded, ')
          ..write('skippedDup: $skippedDup, ')
          ..write('detail: $detail')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  /// seed_version/theme/sort_dir/wifi_only/concurrent_forums/classifier_version/...
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PostsTable posts = $PostsTable(this);
  late final $FloorsTable floors = $FloorsTable(this);
  late final $ImagesTable images = $ImagesTable(this);
  late final $BookEntriesTable bookEntries = $BookEntriesTable(this);
  late final $BookGroupsTable bookGroups = $BookGroupsTable(this);
  late final $SearchHistoryTable searchHistory = $SearchHistoryTable(this);
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final $FavoritesTable favorites = $FavoritesTable(this);
  late final $CollectionStateTable collectionState = $CollectionStateTable(
    this,
  );
  late final $CollectionLogsTable collectionLogs = $CollectionLogsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    posts,
    floors,
    images,
    bookEntries,
    bookGroups,
    searchHistory,
    bookmarks,
    favorites,
    collectionState,
    collectionLogs,
    settings,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'posts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('floors', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'floors',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('images', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'posts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('book_entries', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'floors',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('book_entries', kind: UpdateKind.update)],
    ),
  ]);
}

typedef $$PostsTableCreateCompanionBuilder =
    PostsCompanion Function({
      Value<int> id,
      Value<int?> tid,
      Value<String?> title,
      Value<String?> author,
      Value<String?> authorName,
      Value<int?> userId,
      Value<String> portrait,
      Value<String?> date,
      Value<String?> dateRaw,
      required String channel,
      Value<String?> subChannel,
      Value<String> postType,
      Value<String> postKind,
      Value<int> recommendFlag,
      Value<int> floorCount,
      Value<int> imageCount,
      Value<String> origin,
      Value<DateTime?> collectedAt,
    });
typedef $$PostsTableUpdateCompanionBuilder =
    PostsCompanion Function({
      Value<int> id,
      Value<int?> tid,
      Value<String?> title,
      Value<String?> author,
      Value<String?> authorName,
      Value<int?> userId,
      Value<String> portrait,
      Value<String?> date,
      Value<String?> dateRaw,
      Value<String> channel,
      Value<String?> subChannel,
      Value<String> postType,
      Value<String> postKind,
      Value<int> recommendFlag,
      Value<int> floorCount,
      Value<int> imageCount,
      Value<String> origin,
      Value<DateTime?> collectedAt,
    });

final class $$PostsTableReferences
    extends BaseReferences<_$AppDatabase, $PostsTable, Post> {
  $$PostsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FloorsTable, List<Floor>> _floorsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.floors,
    aliasName: 'posts__id__floors__post_id',
  );

  $$FloorsTableProcessedTableManager get floorsRefs {
    final manager = $$FloorsTableTableManager(
      $_db,
      $_db.floors,
    ).filter((f) => f.postId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_floorsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BookEntriesTable, List<BookEntry>>
  _bookEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bookEntries,
    aliasName: 'posts__id__book_entries__post_ref',
  );

  $$BookEntriesTableProcessedTableManager get bookEntriesRefs {
    final manager = $$BookEntriesTableTableManager(
      $_db,
      $_db.bookEntries,
    ).filter((f) => f.postRef.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_bookEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PostsTableFilterComposer extends Composer<_$AppDatabase, $PostsTable> {
  $$PostsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tid => $composableBuilder(
    column: $table.tid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorName => $composableBuilder(
    column: $table.authorName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get portrait => $composableBuilder(
    column: $table.portrait,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dateRaw => $composableBuilder(
    column: $table.dateRaw,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subChannel => $composableBuilder(
    column: $table.subChannel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get postType => $composableBuilder(
    column: $table.postType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get postKind => $composableBuilder(
    column: $table.postKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recommendFlag => $composableBuilder(
    column: $table.recommendFlag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get floorCount => $composableBuilder(
    column: $table.floorCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get imageCount => $composableBuilder(
    column: $table.imageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get collectedAt => $composableBuilder(
    column: $table.collectedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> floorsRefs(
    Expression<bool> Function($$FloorsTableFilterComposer f) f,
  ) {
    final $$FloorsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.floors,
      getReferencedColumn: (t) => t.postId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FloorsTableFilterComposer(
            $db: $db,
            $table: $db.floors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> bookEntriesRefs(
    Expression<bool> Function($$BookEntriesTableFilterComposer f) f,
  ) {
    final $$BookEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookEntries,
      getReferencedColumn: (t) => t.postRef,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookEntriesTableFilterComposer(
            $db: $db,
            $table: $db.bookEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PostsTableOrderingComposer
    extends Composer<_$AppDatabase, $PostsTable> {
  $$PostsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tid => $composableBuilder(
    column: $table.tid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorName => $composableBuilder(
    column: $table.authorName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get portrait => $composableBuilder(
    column: $table.portrait,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dateRaw => $composableBuilder(
    column: $table.dateRaw,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subChannel => $composableBuilder(
    column: $table.subChannel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get postType => $composableBuilder(
    column: $table.postType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get postKind => $composableBuilder(
    column: $table.postKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recommendFlag => $composableBuilder(
    column: $table.recommendFlag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get floorCount => $composableBuilder(
    column: $table.floorCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get imageCount => $composableBuilder(
    column: $table.imageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get collectedAt => $composableBuilder(
    column: $table.collectedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PostsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PostsTable> {
  $$PostsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get tid =>
      $composableBuilder(column: $table.tid, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get authorName => $composableBuilder(
    column: $table.authorName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get portrait =>
      $composableBuilder(column: $table.portrait, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get dateRaw =>
      $composableBuilder(column: $table.dateRaw, builder: (column) => column);

  GeneratedColumn<String> get channel =>
      $composableBuilder(column: $table.channel, builder: (column) => column);

  GeneratedColumn<String> get subChannel => $composableBuilder(
    column: $table.subChannel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get postType =>
      $composableBuilder(column: $table.postType, builder: (column) => column);

  GeneratedColumn<String> get postKind =>
      $composableBuilder(column: $table.postKind, builder: (column) => column);

  GeneratedColumn<int> get recommendFlag => $composableBuilder(
    column: $table.recommendFlag,
    builder: (column) => column,
  );

  GeneratedColumn<int> get floorCount => $composableBuilder(
    column: $table.floorCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get imageCount => $composableBuilder(
    column: $table.imageCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<DateTime> get collectedAt => $composableBuilder(
    column: $table.collectedAt,
    builder: (column) => column,
  );

  Expression<T> floorsRefs<T extends Object>(
    Expression<T> Function($$FloorsTableAnnotationComposer a) f,
  ) {
    final $$FloorsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.floors,
      getReferencedColumn: (t) => t.postId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FloorsTableAnnotationComposer(
            $db: $db,
            $table: $db.floors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> bookEntriesRefs<T extends Object>(
    Expression<T> Function($$BookEntriesTableAnnotationComposer a) f,
  ) {
    final $$BookEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookEntries,
      getReferencedColumn: (t) => t.postRef,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.bookEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PostsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PostsTable,
          Post,
          $$PostsTableFilterComposer,
          $$PostsTableOrderingComposer,
          $$PostsTableAnnotationComposer,
          $$PostsTableCreateCompanionBuilder,
          $$PostsTableUpdateCompanionBuilder,
          (Post, $$PostsTableReferences),
          Post,
          PrefetchHooks Function({bool floorsRefs, bool bookEntriesRefs})
        > {
  $$PostsTableTableManager(_$AppDatabase db, $PostsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PostsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PostsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PostsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> tid = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> authorName = const Value.absent(),
                Value<int?> userId = const Value.absent(),
                Value<String> portrait = const Value.absent(),
                Value<String?> date = const Value.absent(),
                Value<String?> dateRaw = const Value.absent(),
                Value<String> channel = const Value.absent(),
                Value<String?> subChannel = const Value.absent(),
                Value<String> postType = const Value.absent(),
                Value<String> postKind = const Value.absent(),
                Value<int> recommendFlag = const Value.absent(),
                Value<int> floorCount = const Value.absent(),
                Value<int> imageCount = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<DateTime?> collectedAt = const Value.absent(),
              }) => PostsCompanion(
                id: id,
                tid: tid,
                title: title,
                author: author,
                authorName: authorName,
                userId: userId,
                portrait: portrait,
                date: date,
                dateRaw: dateRaw,
                channel: channel,
                subChannel: subChannel,
                postType: postType,
                postKind: postKind,
                recommendFlag: recommendFlag,
                floorCount: floorCount,
                imageCount: imageCount,
                origin: origin,
                collectedAt: collectedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> tid = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> authorName = const Value.absent(),
                Value<int?> userId = const Value.absent(),
                Value<String> portrait = const Value.absent(),
                Value<String?> date = const Value.absent(),
                Value<String?> dateRaw = const Value.absent(),
                required String channel,
                Value<String?> subChannel = const Value.absent(),
                Value<String> postType = const Value.absent(),
                Value<String> postKind = const Value.absent(),
                Value<int> recommendFlag = const Value.absent(),
                Value<int> floorCount = const Value.absent(),
                Value<int> imageCount = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<DateTime?> collectedAt = const Value.absent(),
              }) => PostsCompanion.insert(
                id: id,
                tid: tid,
                title: title,
                author: author,
                authorName: authorName,
                userId: userId,
                portrait: portrait,
                date: date,
                dateRaw: dateRaw,
                channel: channel,
                subChannel: subChannel,
                postType: postType,
                postKind: postKind,
                recommendFlag: recommendFlag,
                floorCount: floorCount,
                imageCount: imageCount,
                origin: origin,
                collectedAt: collectedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$PostsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({floorsRefs = false, bookEntriesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (floorsRefs) db.floors,
                    if (bookEntriesRefs) db.bookEntries,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (floorsRefs)
                        await $_getPrefetchedData<Post, $PostsTable, Floor>(
                          currentTable: table,
                          referencedTable: $$PostsTableReferences
                              ._floorsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PostsTableReferences(db, table, p0).floorsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.postId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (bookEntriesRefs)
                        await $_getPrefetchedData<Post, $PostsTable, BookEntry>(
                          currentTable: table,
                          referencedTable: $$PostsTableReferences
                              ._bookEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PostsTableReferences(
                                db,
                                table,
                                p0,
                              ).bookEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.postRef == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PostsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PostsTable,
      Post,
      $$PostsTableFilterComposer,
      $$PostsTableOrderingComposer,
      $$PostsTableAnnotationComposer,
      $$PostsTableCreateCompanionBuilder,
      $$PostsTableUpdateCompanionBuilder,
      (Post, $$PostsTableReferences),
      Post,
      PrefetchHooks Function({bool floorsRefs, bool bookEntriesRefs})
    >;
typedef $$FloorsTableCreateCompanionBuilder =
    FloorsCompanion Function({
      Value<int> id,
      required int postId,
      required int seq,
      Value<int?> pid,
      Value<String> content,
      Value<String?> textNormHash,
      Value<int> charCount,
      Value<DateTime?> createdAt,
      Value<int?> authorId,
    });
typedef $$FloorsTableUpdateCompanionBuilder =
    FloorsCompanion Function({
      Value<int> id,
      Value<int> postId,
      Value<int> seq,
      Value<int?> pid,
      Value<String> content,
      Value<String?> textNormHash,
      Value<int> charCount,
      Value<DateTime?> createdAt,
      Value<int?> authorId,
    });

final class $$FloorsTableReferences
    extends BaseReferences<_$AppDatabase, $FloorsTable, Floor> {
  $$FloorsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PostsTable _postIdTable(_$AppDatabase db) =>
      db.posts.createAlias('floors__post_id__posts__id');

  $$PostsTableProcessedTableManager get postId {
    final $_column = $_itemColumn<int>('post_id')!;

    final manager = $$PostsTableTableManager(
      $_db,
      $_db.posts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_postIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ImagesTable, List<FloorImage>> _imagesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.images,
    aliasName: 'floors__id__images__floor_id',
  );

  $$ImagesTableProcessedTableManager get imagesRefs {
    final manager = $$ImagesTableTableManager(
      $_db,
      $_db.images,
    ).filter((f) => f.floorId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_imagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BookEntriesTable, List<BookEntry>>
  _bookEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bookEntries,
    aliasName: 'floors__id__book_entries__floor_ref',
  );

  $$BookEntriesTableProcessedTableManager get bookEntriesRefs {
    final manager = $$BookEntriesTableTableManager(
      $_db,
      $_db.bookEntries,
    ).filter((f) => f.floorRef.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_bookEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FloorsTableFilterComposer
    extends Composer<_$AppDatabase, $FloorsTable> {
  $$FloorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pid => $composableBuilder(
    column: $table.pid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textNormHash => $composableBuilder(
    column: $table.textNormHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get charCount => $composableBuilder(
    column: $table.charCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnFilters(column),
  );

  $$PostsTableFilterComposer get postId {
    final $$PostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.postId,
      referencedTable: $db.posts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostsTableFilterComposer(
            $db: $db,
            $table: $db.posts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> imagesRefs(
    Expression<bool> Function($$ImagesTableFilterComposer f) f,
  ) {
    final $$ImagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.images,
      getReferencedColumn: (t) => t.floorId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImagesTableFilterComposer(
            $db: $db,
            $table: $db.images,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> bookEntriesRefs(
    Expression<bool> Function($$BookEntriesTableFilterComposer f) f,
  ) {
    final $$BookEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookEntries,
      getReferencedColumn: (t) => t.floorRef,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookEntriesTableFilterComposer(
            $db: $db,
            $table: $db.bookEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FloorsTableOrderingComposer
    extends Composer<_$AppDatabase, $FloorsTable> {
  $$FloorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pid => $composableBuilder(
    column: $table.pid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textNormHash => $composableBuilder(
    column: $table.textNormHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get charCount => $composableBuilder(
    column: $table.charCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnOrderings(column),
  );

  $$PostsTableOrderingComposer get postId {
    final $$PostsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.postId,
      referencedTable: $db.posts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostsTableOrderingComposer(
            $db: $db,
            $table: $db.posts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FloorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FloorsTable> {
  $$FloorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<int> get pid =>
      $composableBuilder(column: $table.pid, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get textNormHash => $composableBuilder(
    column: $table.textNormHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get charCount =>
      $composableBuilder(column: $table.charCount, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get authorId =>
      $composableBuilder(column: $table.authorId, builder: (column) => column);

  $$PostsTableAnnotationComposer get postId {
    final $$PostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.postId,
      referencedTable: $db.posts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostsTableAnnotationComposer(
            $db: $db,
            $table: $db.posts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> imagesRefs<T extends Object>(
    Expression<T> Function($$ImagesTableAnnotationComposer a) f,
  ) {
    final $$ImagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.images,
      getReferencedColumn: (t) => t.floorId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImagesTableAnnotationComposer(
            $db: $db,
            $table: $db.images,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> bookEntriesRefs<T extends Object>(
    Expression<T> Function($$BookEntriesTableAnnotationComposer a) f,
  ) {
    final $$BookEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookEntries,
      getReferencedColumn: (t) => t.floorRef,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.bookEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FloorsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FloorsTable,
          Floor,
          $$FloorsTableFilterComposer,
          $$FloorsTableOrderingComposer,
          $$FloorsTableAnnotationComposer,
          $$FloorsTableCreateCompanionBuilder,
          $$FloorsTableUpdateCompanionBuilder,
          (Floor, $$FloorsTableReferences),
          Floor,
          PrefetchHooks Function({
            bool postId,
            bool imagesRefs,
            bool bookEntriesRefs,
          })
        > {
  $$FloorsTableTableManager(_$AppDatabase db, $FloorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FloorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FloorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FloorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> postId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<int?> pid = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> textNormHash = const Value.absent(),
                Value<int> charCount = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<int?> authorId = const Value.absent(),
              }) => FloorsCompanion(
                id: id,
                postId: postId,
                seq: seq,
                pid: pid,
                content: content,
                textNormHash: textNormHash,
                charCount: charCount,
                createdAt: createdAt,
                authorId: authorId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int postId,
                required int seq,
                Value<int?> pid = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> textNormHash = const Value.absent(),
                Value<int> charCount = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<int?> authorId = const Value.absent(),
              }) => FloorsCompanion.insert(
                id: id,
                postId: postId,
                seq: seq,
                pid: pid,
                content: content,
                textNormHash: textNormHash,
                charCount: charCount,
                createdAt: createdAt,
                authorId: authorId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$FloorsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({postId = false, imagesRefs = false, bookEntriesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (imagesRefs) db.images,
                    if (bookEntriesRefs) db.bookEntries,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (postId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.postId,
                                    referencedTable: $$FloorsTableReferences
                                        ._postIdTable(db),
                                    referencedColumn: $$FloorsTableReferences
                                        ._postIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (imagesRefs)
                        await $_getPrefetchedData<
                          Floor,
                          $FloorsTable,
                          FloorImage
                        >(
                          currentTable: table,
                          referencedTable: $$FloorsTableReferences
                              ._imagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FloorsTableReferences(db, table, p0).imagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.floorId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (bookEntriesRefs)
                        await $_getPrefetchedData<
                          Floor,
                          $FloorsTable,
                          BookEntry
                        >(
                          currentTable: table,
                          referencedTable: $$FloorsTableReferences
                              ._bookEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FloorsTableReferences(
                                db,
                                table,
                                p0,
                              ).bookEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.floorRef == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$FloorsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FloorsTable,
      Floor,
      $$FloorsTableFilterComposer,
      $$FloorsTableOrderingComposer,
      $$FloorsTableAnnotationComposer,
      $$FloorsTableCreateCompanionBuilder,
      $$FloorsTableUpdateCompanionBuilder,
      (Floor, $$FloorsTableReferences),
      Floor,
      PrefetchHooks Function({
        bool postId,
        bool imagesRefs,
        bool bookEntriesRefs,
      })
    >;
typedef $$ImagesTableCreateCompanionBuilder =
    ImagesCompanion Function({
      Value<int> id,
      required int floorId,
      Value<String?> urlOriginal,
      Value<String?> urlPermanent,
      Value<int> width,
      Value<int> height,
    });
typedef $$ImagesTableUpdateCompanionBuilder =
    ImagesCompanion Function({
      Value<int> id,
      Value<int> floorId,
      Value<String?> urlOriginal,
      Value<String?> urlPermanent,
      Value<int> width,
      Value<int> height,
    });

final class $$ImagesTableReferences
    extends BaseReferences<_$AppDatabase, $ImagesTable, FloorImage> {
  $$ImagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FloorsTable _floorIdTable(_$AppDatabase db) =>
      db.floors.createAlias('images__floor_id__floors__id');

  $$FloorsTableProcessedTableManager get floorId {
    final $_column = $_itemColumn<int>('floor_id')!;

    final manager = $$FloorsTableTableManager(
      $_db,
      $_db.floors,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_floorIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ImagesTableFilterComposer
    extends Composer<_$AppDatabase, $ImagesTable> {
  $$ImagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get urlOriginal => $composableBuilder(
    column: $table.urlOriginal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get urlPermanent => $composableBuilder(
    column: $table.urlPermanent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  $$FloorsTableFilterComposer get floorId {
    final $$FloorsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.floorId,
      referencedTable: $db.floors,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FloorsTableFilterComposer(
            $db: $db,
            $table: $db.floors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImagesTableOrderingComposer
    extends Composer<_$AppDatabase, $ImagesTable> {
  $$ImagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get urlOriginal => $composableBuilder(
    column: $table.urlOriginal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get urlPermanent => $composableBuilder(
    column: $table.urlPermanent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  $$FloorsTableOrderingComposer get floorId {
    final $$FloorsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.floorId,
      referencedTable: $db.floors,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FloorsTableOrderingComposer(
            $db: $db,
            $table: $db.floors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImagesTable> {
  $$ImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get urlOriginal => $composableBuilder(
    column: $table.urlOriginal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get urlPermanent => $composableBuilder(
    column: $table.urlPermanent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  $$FloorsTableAnnotationComposer get floorId {
    final $$FloorsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.floorId,
      referencedTable: $db.floors,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FloorsTableAnnotationComposer(
            $db: $db,
            $table: $db.floors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImagesTable,
          FloorImage,
          $$ImagesTableFilterComposer,
          $$ImagesTableOrderingComposer,
          $$ImagesTableAnnotationComposer,
          $$ImagesTableCreateCompanionBuilder,
          $$ImagesTableUpdateCompanionBuilder,
          (FloorImage, $$ImagesTableReferences),
          FloorImage,
          PrefetchHooks Function({bool floorId})
        > {
  $$ImagesTableTableManager(_$AppDatabase db, $ImagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> floorId = const Value.absent(),
                Value<String?> urlOriginal = const Value.absent(),
                Value<String?> urlPermanent = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
              }) => ImagesCompanion(
                id: id,
                floorId: floorId,
                urlOriginal: urlOriginal,
                urlPermanent: urlPermanent,
                width: width,
                height: height,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int floorId,
                Value<String?> urlOriginal = const Value.absent(),
                Value<String?> urlPermanent = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
              }) => ImagesCompanion.insert(
                id: id,
                floorId: floorId,
                urlOriginal: urlOriginal,
                urlPermanent: urlPermanent,
                width: width,
                height: height,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$ImagesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({floorId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (floorId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.floorId,
                                referencedTable: $$ImagesTableReferences
                                    ._floorIdTable(db),
                                referencedColumn: $$ImagesTableReferences
                                    ._floorIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ImagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImagesTable,
      FloorImage,
      $$ImagesTableFilterComposer,
      $$ImagesTableOrderingComposer,
      $$ImagesTableAnnotationComposer,
      $$ImagesTableCreateCompanionBuilder,
      $$ImagesTableUpdateCompanionBuilder,
      (FloorImage, $$ImagesTableReferences),
      FloorImage,
      PrefetchHooks Function({bool floorId})
    >;
typedef $$BookEntriesTableCreateCompanionBuilder =
    BookEntriesCompanion Function({
      Value<int> id,
      required String name,
      required String nameNorm,
      Value<String?> author,
      Value<String?> authorNorm,
      Value<String?> authorKind,
      Value<String?> recommender,
      Value<String?> comment,
      Value<String?> commentSrc,
      Value<String?> commentNormHash,
      Value<String?> date,
      Value<String?> dateRaw,
      required String channel,
      Value<String?> subChannel,
      Value<String> category,
      Value<int?> postRef,
      Value<int?> floorRef,
      Value<int?> srcTid,
      Value<String?> srcUrl,
      Value<int?> wordCount,
      Value<String?> bookGrade,
      Value<int> quality,
      required String contentHash,
      Value<int?> bookGroupId,
      Value<String> origin,
      Value<DateTime?> collectedAt,
    });
typedef $$BookEntriesTableUpdateCompanionBuilder =
    BookEntriesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> nameNorm,
      Value<String?> author,
      Value<String?> authorNorm,
      Value<String?> authorKind,
      Value<String?> recommender,
      Value<String?> comment,
      Value<String?> commentSrc,
      Value<String?> commentNormHash,
      Value<String?> date,
      Value<String?> dateRaw,
      Value<String> channel,
      Value<String?> subChannel,
      Value<String> category,
      Value<int?> postRef,
      Value<int?> floorRef,
      Value<int?> srcTid,
      Value<String?> srcUrl,
      Value<int?> wordCount,
      Value<String?> bookGrade,
      Value<int> quality,
      Value<String> contentHash,
      Value<int?> bookGroupId,
      Value<String> origin,
      Value<DateTime?> collectedAt,
    });

final class $$BookEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $BookEntriesTable, BookEntry> {
  $$BookEntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PostsTable _postRefTable(_$AppDatabase db) =>
      db.posts.createAlias('book_entries__post_ref__posts__id');

  $$PostsTableProcessedTableManager? get postRef {
    final $_column = $_itemColumn<int>('post_ref');
    if ($_column == null) return null;
    final manager = $$PostsTableTableManager(
      $_db,
      $_db.posts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_postRefTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $FloorsTable _floorRefTable(_$AppDatabase db) =>
      db.floors.createAlias('book_entries__floor_ref__floors__id');

  $$FloorsTableProcessedTableManager? get floorRef {
    final $_column = $_itemColumn<int>('floor_ref');
    if ($_column == null) return null;
    final manager = $$FloorsTableTableManager(
      $_db,
      $_db.floors,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_floorRefTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BookEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $BookEntriesTable> {
  $$BookEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameNorm => $composableBuilder(
    column: $table.nameNorm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorNorm => $composableBuilder(
    column: $table.authorNorm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorKind => $composableBuilder(
    column: $table.authorKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recommender => $composableBuilder(
    column: $table.recommender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commentSrc => $composableBuilder(
    column: $table.commentSrc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commentNormHash => $composableBuilder(
    column: $table.commentNormHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dateRaw => $composableBuilder(
    column: $table.dateRaw,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subChannel => $composableBuilder(
    column: $table.subChannel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get srcTid => $composableBuilder(
    column: $table.srcTid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get srcUrl => $composableBuilder(
    column: $table.srcUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookGrade => $composableBuilder(
    column: $table.bookGrade,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bookGroupId => $composableBuilder(
    column: $table.bookGroupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get collectedAt => $composableBuilder(
    column: $table.collectedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PostsTableFilterComposer get postRef {
    final $$PostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.postRef,
      referencedTable: $db.posts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostsTableFilterComposer(
            $db: $db,
            $table: $db.posts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FloorsTableFilterComposer get floorRef {
    final $$FloorsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.floorRef,
      referencedTable: $db.floors,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FloorsTableFilterComposer(
            $db: $db,
            $table: $db.floors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $BookEntriesTable> {
  $$BookEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameNorm => $composableBuilder(
    column: $table.nameNorm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorNorm => $composableBuilder(
    column: $table.authorNorm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorKind => $composableBuilder(
    column: $table.authorKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recommender => $composableBuilder(
    column: $table.recommender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commentSrc => $composableBuilder(
    column: $table.commentSrc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commentNormHash => $composableBuilder(
    column: $table.commentNormHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dateRaw => $composableBuilder(
    column: $table.dateRaw,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subChannel => $composableBuilder(
    column: $table.subChannel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get srcTid => $composableBuilder(
    column: $table.srcTid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get srcUrl => $composableBuilder(
    column: $table.srcUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookGrade => $composableBuilder(
    column: $table.bookGrade,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bookGroupId => $composableBuilder(
    column: $table.bookGroupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get collectedAt => $composableBuilder(
    column: $table.collectedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PostsTableOrderingComposer get postRef {
    final $$PostsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.postRef,
      referencedTable: $db.posts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostsTableOrderingComposer(
            $db: $db,
            $table: $db.posts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FloorsTableOrderingComposer get floorRef {
    final $$FloorsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.floorRef,
      referencedTable: $db.floors,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FloorsTableOrderingComposer(
            $db: $db,
            $table: $db.floors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookEntriesTable> {
  $$BookEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get nameNorm =>
      $composableBuilder(column: $table.nameNorm, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get authorNorm => $composableBuilder(
    column: $table.authorNorm,
    builder: (column) => column,
  );

  GeneratedColumn<String> get authorKind => $composableBuilder(
    column: $table.authorKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recommender => $composableBuilder(
    column: $table.recommender,
    builder: (column) => column,
  );

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<String> get commentSrc => $composableBuilder(
    column: $table.commentSrc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get commentNormHash => $composableBuilder(
    column: $table.commentNormHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get dateRaw =>
      $composableBuilder(column: $table.dateRaw, builder: (column) => column);

  GeneratedColumn<String> get channel =>
      $composableBuilder(column: $table.channel, builder: (column) => column);

  GeneratedColumn<String> get subChannel => $composableBuilder(
    column: $table.subChannel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get srcTid =>
      $composableBuilder(column: $table.srcTid, builder: (column) => column);

  GeneratedColumn<String> get srcUrl =>
      $composableBuilder(column: $table.srcUrl, builder: (column) => column);

  GeneratedColumn<int> get wordCount =>
      $composableBuilder(column: $table.wordCount, builder: (column) => column);

  GeneratedColumn<String> get bookGrade =>
      $composableBuilder(column: $table.bookGrade, builder: (column) => column);

  GeneratedColumn<int> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bookGroupId => $composableBuilder(
    column: $table.bookGroupId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<DateTime> get collectedAt => $composableBuilder(
    column: $table.collectedAt,
    builder: (column) => column,
  );

  $$PostsTableAnnotationComposer get postRef {
    final $$PostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.postRef,
      referencedTable: $db.posts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostsTableAnnotationComposer(
            $db: $db,
            $table: $db.posts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FloorsTableAnnotationComposer get floorRef {
    final $$FloorsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.floorRef,
      referencedTable: $db.floors,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FloorsTableAnnotationComposer(
            $db: $db,
            $table: $db.floors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookEntriesTable,
          BookEntry,
          $$BookEntriesTableFilterComposer,
          $$BookEntriesTableOrderingComposer,
          $$BookEntriesTableAnnotationComposer,
          $$BookEntriesTableCreateCompanionBuilder,
          $$BookEntriesTableUpdateCompanionBuilder,
          (BookEntry, $$BookEntriesTableReferences),
          BookEntry,
          PrefetchHooks Function({bool postRef, bool floorRef})
        > {
  $$BookEntriesTableTableManager(_$AppDatabase db, $BookEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> nameNorm = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> authorNorm = const Value.absent(),
                Value<String?> authorKind = const Value.absent(),
                Value<String?> recommender = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<String?> commentSrc = const Value.absent(),
                Value<String?> commentNormHash = const Value.absent(),
                Value<String?> date = const Value.absent(),
                Value<String?> dateRaw = const Value.absent(),
                Value<String> channel = const Value.absent(),
                Value<String?> subChannel = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<int?> postRef = const Value.absent(),
                Value<int?> floorRef = const Value.absent(),
                Value<int?> srcTid = const Value.absent(),
                Value<String?> srcUrl = const Value.absent(),
                Value<int?> wordCount = const Value.absent(),
                Value<String?> bookGrade = const Value.absent(),
                Value<int> quality = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<int?> bookGroupId = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<DateTime?> collectedAt = const Value.absent(),
              }) => BookEntriesCompanion(
                id: id,
                name: name,
                nameNorm: nameNorm,
                author: author,
                authorNorm: authorNorm,
                authorKind: authorKind,
                recommender: recommender,
                comment: comment,
                commentSrc: commentSrc,
                commentNormHash: commentNormHash,
                date: date,
                dateRaw: dateRaw,
                channel: channel,
                subChannel: subChannel,
                category: category,
                postRef: postRef,
                floorRef: floorRef,
                srcTid: srcTid,
                srcUrl: srcUrl,
                wordCount: wordCount,
                bookGrade: bookGrade,
                quality: quality,
                contentHash: contentHash,
                bookGroupId: bookGroupId,
                origin: origin,
                collectedAt: collectedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String nameNorm,
                Value<String?> author = const Value.absent(),
                Value<String?> authorNorm = const Value.absent(),
                Value<String?> authorKind = const Value.absent(),
                Value<String?> recommender = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<String?> commentSrc = const Value.absent(),
                Value<String?> commentNormHash = const Value.absent(),
                Value<String?> date = const Value.absent(),
                Value<String?> dateRaw = const Value.absent(),
                required String channel,
                Value<String?> subChannel = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<int?> postRef = const Value.absent(),
                Value<int?> floorRef = const Value.absent(),
                Value<int?> srcTid = const Value.absent(),
                Value<String?> srcUrl = const Value.absent(),
                Value<int?> wordCount = const Value.absent(),
                Value<String?> bookGrade = const Value.absent(),
                Value<int> quality = const Value.absent(),
                required String contentHash,
                Value<int?> bookGroupId = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<DateTime?> collectedAt = const Value.absent(),
              }) => BookEntriesCompanion.insert(
                id: id,
                name: name,
                nameNorm: nameNorm,
                author: author,
                authorNorm: authorNorm,
                authorKind: authorKind,
                recommender: recommender,
                comment: comment,
                commentSrc: commentSrc,
                commentNormHash: commentNormHash,
                date: date,
                dateRaw: dateRaw,
                channel: channel,
                subChannel: subChannel,
                category: category,
                postRef: postRef,
                floorRef: floorRef,
                srcTid: srcTid,
                srcUrl: srcUrl,
                wordCount: wordCount,
                bookGrade: bookGrade,
                quality: quality,
                contentHash: contentHash,
                bookGroupId: bookGroupId,
                origin: origin,
                collectedAt: collectedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BookEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({postRef = false, floorRef = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (postRef) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.postRef,
                                referencedTable: $$BookEntriesTableReferences
                                    ._postRefTable(db),
                                referencedColumn: $$BookEntriesTableReferences
                                    ._postRefTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (floorRef) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.floorRef,
                                referencedTable: $$BookEntriesTableReferences
                                    ._floorRefTable(db),
                                referencedColumn: $$BookEntriesTableReferences
                                    ._floorRefTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BookEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookEntriesTable,
      BookEntry,
      $$BookEntriesTableFilterComposer,
      $$BookEntriesTableOrderingComposer,
      $$BookEntriesTableAnnotationComposer,
      $$BookEntriesTableCreateCompanionBuilder,
      $$BookEntriesTableUpdateCompanionBuilder,
      (BookEntry, $$BookEntriesTableReferences),
      BookEntry,
      PrefetchHooks Function({bool postRef, bool floorRef})
    >;
typedef $$BookGroupsTableCreateCompanionBuilder =
    BookGroupsCompanion Function({
      Value<int> id,
      required String nameNorm,
      Value<String> authorEffNorm,
      Value<String?> nameDisplay,
      Value<String?> authorDisplay,
      Value<int> entryTotal,
      Value<int> distinctComment,
      Value<String?> channels,
      Value<String?> dateMin,
      Value<String?> dateMax,
      Value<int?> wordCountMax,
    });
typedef $$BookGroupsTableUpdateCompanionBuilder =
    BookGroupsCompanion Function({
      Value<int> id,
      Value<String> nameNorm,
      Value<String> authorEffNorm,
      Value<String?> nameDisplay,
      Value<String?> authorDisplay,
      Value<int> entryTotal,
      Value<int> distinctComment,
      Value<String?> channels,
      Value<String?> dateMin,
      Value<String?> dateMax,
      Value<int?> wordCountMax,
    });

class $$BookGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $BookGroupsTable> {
  $$BookGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameNorm => $composableBuilder(
    column: $table.nameNorm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorEffNorm => $composableBuilder(
    column: $table.authorEffNorm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameDisplay => $composableBuilder(
    column: $table.nameDisplay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorDisplay => $composableBuilder(
    column: $table.authorDisplay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get entryTotal => $composableBuilder(
    column: $table.entryTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get distinctComment => $composableBuilder(
    column: $table.distinctComment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channels => $composableBuilder(
    column: $table.channels,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dateMin => $composableBuilder(
    column: $table.dateMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dateMax => $composableBuilder(
    column: $table.dateMax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wordCountMax => $composableBuilder(
    column: $table.wordCountMax,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $BookGroupsTable> {
  $$BookGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameNorm => $composableBuilder(
    column: $table.nameNorm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorEffNorm => $composableBuilder(
    column: $table.authorEffNorm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameDisplay => $composableBuilder(
    column: $table.nameDisplay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorDisplay => $composableBuilder(
    column: $table.authorDisplay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get entryTotal => $composableBuilder(
    column: $table.entryTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get distinctComment => $composableBuilder(
    column: $table.distinctComment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channels => $composableBuilder(
    column: $table.channels,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dateMin => $composableBuilder(
    column: $table.dateMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dateMax => $composableBuilder(
    column: $table.dateMax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wordCountMax => $composableBuilder(
    column: $table.wordCountMax,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookGroupsTable> {
  $$BookGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nameNorm =>
      $composableBuilder(column: $table.nameNorm, builder: (column) => column);

  GeneratedColumn<String> get authorEffNorm => $composableBuilder(
    column: $table.authorEffNorm,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nameDisplay => $composableBuilder(
    column: $table.nameDisplay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get authorDisplay => $composableBuilder(
    column: $table.authorDisplay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get entryTotal => $composableBuilder(
    column: $table.entryTotal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get distinctComment => $composableBuilder(
    column: $table.distinctComment,
    builder: (column) => column,
  );

  GeneratedColumn<String> get channels =>
      $composableBuilder(column: $table.channels, builder: (column) => column);

  GeneratedColumn<String> get dateMin =>
      $composableBuilder(column: $table.dateMin, builder: (column) => column);

  GeneratedColumn<String> get dateMax =>
      $composableBuilder(column: $table.dateMax, builder: (column) => column);

  GeneratedColumn<int> get wordCountMax => $composableBuilder(
    column: $table.wordCountMax,
    builder: (column) => column,
  );
}

class $$BookGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookGroupsTable,
          BookGroup,
          $$BookGroupsTableFilterComposer,
          $$BookGroupsTableOrderingComposer,
          $$BookGroupsTableAnnotationComposer,
          $$BookGroupsTableCreateCompanionBuilder,
          $$BookGroupsTableUpdateCompanionBuilder,
          (
            BookGroup,
            BaseReferences<_$AppDatabase, $BookGroupsTable, BookGroup>,
          ),
          BookGroup,
          PrefetchHooks Function()
        > {
  $$BookGroupsTableTableManager(_$AppDatabase db, $BookGroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> nameNorm = const Value.absent(),
                Value<String> authorEffNorm = const Value.absent(),
                Value<String?> nameDisplay = const Value.absent(),
                Value<String?> authorDisplay = const Value.absent(),
                Value<int> entryTotal = const Value.absent(),
                Value<int> distinctComment = const Value.absent(),
                Value<String?> channels = const Value.absent(),
                Value<String?> dateMin = const Value.absent(),
                Value<String?> dateMax = const Value.absent(),
                Value<int?> wordCountMax = const Value.absent(),
              }) => BookGroupsCompanion(
                id: id,
                nameNorm: nameNorm,
                authorEffNorm: authorEffNorm,
                nameDisplay: nameDisplay,
                authorDisplay: authorDisplay,
                entryTotal: entryTotal,
                distinctComment: distinctComment,
                channels: channels,
                dateMin: dateMin,
                dateMax: dateMax,
                wordCountMax: wordCountMax,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String nameNorm,
                Value<String> authorEffNorm = const Value.absent(),
                Value<String?> nameDisplay = const Value.absent(),
                Value<String?> authorDisplay = const Value.absent(),
                Value<int> entryTotal = const Value.absent(),
                Value<int> distinctComment = const Value.absent(),
                Value<String?> channels = const Value.absent(),
                Value<String?> dateMin = const Value.absent(),
                Value<String?> dateMax = const Value.absent(),
                Value<int?> wordCountMax = const Value.absent(),
              }) => BookGroupsCompanion.insert(
                id: id,
                nameNorm: nameNorm,
                authorEffNorm: authorEffNorm,
                nameDisplay: nameDisplay,
                authorDisplay: authorDisplay,
                entryTotal: entryTotal,
                distinctComment: distinctComment,
                channels: channels,
                dateMin: dateMin,
                dateMax: dateMax,
                wordCountMax: wordCountMax,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookGroupsTable,
      BookGroup,
      $$BookGroupsTableFilterComposer,
      $$BookGroupsTableOrderingComposer,
      $$BookGroupsTableAnnotationComposer,
      $$BookGroupsTableCreateCompanionBuilder,
      $$BookGroupsTableUpdateCompanionBuilder,
      (BookGroup, BaseReferences<_$AppDatabase, $BookGroupsTable, BookGroup>),
      BookGroup,
      PrefetchHooks Function()
    >;
typedef $$SearchHistoryTableCreateCompanionBuilder =
    SearchHistoryCompanion Function({
      Value<int> id,
      Value<String> query,
      Value<String?> year,
      Value<String?> month,
      Value<String?> tenDay,
      Value<String?> channel,
      Value<String?> category,
      Value<String> sort,
      required DateTime searchedAt,
    });
typedef $$SearchHistoryTableUpdateCompanionBuilder =
    SearchHistoryCompanion Function({
      Value<int> id,
      Value<String> query,
      Value<String?> year,
      Value<String?> month,
      Value<String?> tenDay,
      Value<String?> channel,
      Value<String?> category,
      Value<String> sort,
      Value<DateTime> searchedAt,
    });

class $$SearchHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $SearchHistoryTable> {
  $$SearchHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenDay => $composableBuilder(
    column: $table.tenDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SearchHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $SearchHistoryTable> {
  $$SearchHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenDay => $composableBuilder(
    column: $table.tenDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $SearchHistoryTable> {
  $$SearchHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get query =>
      $composableBuilder(column: $table.query, builder: (column) => column);

  GeneratedColumn<String> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<String> get tenDay =>
      $composableBuilder(column: $table.tenDay, builder: (column) => column);

  GeneratedColumn<String> get channel =>
      $composableBuilder(column: $table.channel, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get sort =>
      $composableBuilder(column: $table.sort, builder: (column) => column);

  GeneratedColumn<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => column,
  );
}

class $$SearchHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SearchHistoryTable,
          SearchHistoryEntry,
          $$SearchHistoryTableFilterComposer,
          $$SearchHistoryTableOrderingComposer,
          $$SearchHistoryTableAnnotationComposer,
          $$SearchHistoryTableCreateCompanionBuilder,
          $$SearchHistoryTableUpdateCompanionBuilder,
          (
            SearchHistoryEntry,
            BaseReferences<
              _$AppDatabase,
              $SearchHistoryTable,
              SearchHistoryEntry
            >,
          ),
          SearchHistoryEntry,
          PrefetchHooks Function()
        > {
  $$SearchHistoryTableTableManager(_$AppDatabase db, $SearchHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SearchHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> query = const Value.absent(),
                Value<String?> year = const Value.absent(),
                Value<String?> month = const Value.absent(),
                Value<String?> tenDay = const Value.absent(),
                Value<String?> channel = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String> sort = const Value.absent(),
                Value<DateTime> searchedAt = const Value.absent(),
              }) => SearchHistoryCompanion(
                id: id,
                query: query,
                year: year,
                month: month,
                tenDay: tenDay,
                channel: channel,
                category: category,
                sort: sort,
                searchedAt: searchedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> query = const Value.absent(),
                Value<String?> year = const Value.absent(),
                Value<String?> month = const Value.absent(),
                Value<String?> tenDay = const Value.absent(),
                Value<String?> channel = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String> sort = const Value.absent(),
                required DateTime searchedAt,
              }) => SearchHistoryCompanion.insert(
                id: id,
                query: query,
                year: year,
                month: month,
                tenDay: tenDay,
                channel: channel,
                category: category,
                sort: sort,
                searchedAt: searchedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SearchHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SearchHistoryTable,
      SearchHistoryEntry,
      $$SearchHistoryTableFilterComposer,
      $$SearchHistoryTableOrderingComposer,
      $$SearchHistoryTableAnnotationComposer,
      $$SearchHistoryTableCreateCompanionBuilder,
      $$SearchHistoryTableUpdateCompanionBuilder,
      (
        SearchHistoryEntry,
        BaseReferences<_$AppDatabase, $SearchHistoryTable, SearchHistoryEntry>,
      ),
      SearchHistoryEntry,
      PrefetchHooks Function()
    >;
typedef $$BookmarksTableCreateCompanionBuilder =
    BookmarksCompanion Function({
      Value<int> id,
      Value<int?> postRef,
      Value<int?> entryRef,
      required String title,
      Value<String?> author,
      Value<String?> channel,
      Value<int> position,
      Value<String?> snapQuery,
      Value<String?> snapYear,
      Value<String?> snapMonth,
      Value<String?> snapTenDay,
      Value<String?> snapChannel,
      Value<String?> snapCategory,
      Value<String?> snapSort,
      Value<String?> note,
      required DateTime createdAt,
    });
typedef $$BookmarksTableUpdateCompanionBuilder =
    BookmarksCompanion Function({
      Value<int> id,
      Value<int?> postRef,
      Value<int?> entryRef,
      Value<String> title,
      Value<String?> author,
      Value<String?> channel,
      Value<int> position,
      Value<String?> snapQuery,
      Value<String?> snapYear,
      Value<String?> snapMonth,
      Value<String?> snapTenDay,
      Value<String?> snapChannel,
      Value<String?> snapCategory,
      Value<String?> snapSort,
      Value<String?> note,
      Value<DateTime> createdAt,
    });

class $$BookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get postRef => $composableBuilder(
    column: $table.postRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get entryRef => $composableBuilder(
    column: $table.entryRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapQuery => $composableBuilder(
    column: $table.snapQuery,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapYear => $composableBuilder(
    column: $table.snapYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapMonth => $composableBuilder(
    column: $table.snapMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapTenDay => $composableBuilder(
    column: $table.snapTenDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapChannel => $composableBuilder(
    column: $table.snapChannel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapCategory => $composableBuilder(
    column: $table.snapCategory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapSort => $composableBuilder(
    column: $table.snapSort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get postRef => $composableBuilder(
    column: $table.postRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get entryRef => $composableBuilder(
    column: $table.entryRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapQuery => $composableBuilder(
    column: $table.snapQuery,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapYear => $composableBuilder(
    column: $table.snapYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapMonth => $composableBuilder(
    column: $table.snapMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapTenDay => $composableBuilder(
    column: $table.snapTenDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapChannel => $composableBuilder(
    column: $table.snapChannel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapCategory => $composableBuilder(
    column: $table.snapCategory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapSort => $composableBuilder(
    column: $table.snapSort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get postRef =>
      $composableBuilder(column: $table.postRef, builder: (column) => column);

  GeneratedColumn<int> get entryRef =>
      $composableBuilder(column: $table.entryRef, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get channel =>
      $composableBuilder(column: $table.channel, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get snapQuery =>
      $composableBuilder(column: $table.snapQuery, builder: (column) => column);

  GeneratedColumn<String> get snapYear =>
      $composableBuilder(column: $table.snapYear, builder: (column) => column);

  GeneratedColumn<String> get snapMonth =>
      $composableBuilder(column: $table.snapMonth, builder: (column) => column);

  GeneratedColumn<String> get snapTenDay => $composableBuilder(
    column: $table.snapTenDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get snapChannel => $composableBuilder(
    column: $table.snapChannel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get snapCategory => $composableBuilder(
    column: $table.snapCategory,
    builder: (column) => column,
  );

  GeneratedColumn<String> get snapSort =>
      $composableBuilder(column: $table.snapSort, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BookmarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookmarksTable,
          Bookmark,
          $$BookmarksTableFilterComposer,
          $$BookmarksTableOrderingComposer,
          $$BookmarksTableAnnotationComposer,
          $$BookmarksTableCreateCompanionBuilder,
          $$BookmarksTableUpdateCompanionBuilder,
          (Bookmark, BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark>),
          Bookmark,
          PrefetchHooks Function()
        > {
  $$BookmarksTableTableManager(_$AppDatabase db, $BookmarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> postRef = const Value.absent(),
                Value<int?> entryRef = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> channel = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String?> snapQuery = const Value.absent(),
                Value<String?> snapYear = const Value.absent(),
                Value<String?> snapMonth = const Value.absent(),
                Value<String?> snapTenDay = const Value.absent(),
                Value<String?> snapChannel = const Value.absent(),
                Value<String?> snapCategory = const Value.absent(),
                Value<String?> snapSort = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => BookmarksCompanion(
                id: id,
                postRef: postRef,
                entryRef: entryRef,
                title: title,
                author: author,
                channel: channel,
                position: position,
                snapQuery: snapQuery,
                snapYear: snapYear,
                snapMonth: snapMonth,
                snapTenDay: snapTenDay,
                snapChannel: snapChannel,
                snapCategory: snapCategory,
                snapSort: snapSort,
                note: note,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> postRef = const Value.absent(),
                Value<int?> entryRef = const Value.absent(),
                required String title,
                Value<String?> author = const Value.absent(),
                Value<String?> channel = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String?> snapQuery = const Value.absent(),
                Value<String?> snapYear = const Value.absent(),
                Value<String?> snapMonth = const Value.absent(),
                Value<String?> snapTenDay = const Value.absent(),
                Value<String?> snapChannel = const Value.absent(),
                Value<String?> snapCategory = const Value.absent(),
                Value<String?> snapSort = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required DateTime createdAt,
              }) => BookmarksCompanion.insert(
                id: id,
                postRef: postRef,
                entryRef: entryRef,
                title: title,
                author: author,
                channel: channel,
                position: position,
                snapQuery: snapQuery,
                snapYear: snapYear,
                snapMonth: snapMonth,
                snapTenDay: snapTenDay,
                snapChannel: snapChannel,
                snapCategory: snapCategory,
                snapSort: snapSort,
                note: note,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookmarksTable,
      Bookmark,
      $$BookmarksTableFilterComposer,
      $$BookmarksTableOrderingComposer,
      $$BookmarksTableAnnotationComposer,
      $$BookmarksTableCreateCompanionBuilder,
      $$BookmarksTableUpdateCompanionBuilder,
      (Bookmark, BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark>),
      Bookmark,
      PrefetchHooks Function()
    >;
typedef $$FavoritesTableCreateCompanionBuilder =
    FavoritesCompanion Function({
      Value<int> id,
      required String targetType,
      required int targetId,
      required String title,
      Value<String?> subtitle,
      required DateTime addedAt,
    });
typedef $$FavoritesTableUpdateCompanionBuilder =
    FavoritesCompanion Function({
      Value<int> id,
      Value<String> targetType,
      Value<int> targetId,
      Value<String> title,
      Value<String?> subtitle,
      Value<DateTime> addedAt,
    });

class $$FavoritesTableFilterComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetType => $composableBuilder(
    column: $table.targetType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FavoritesTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetType => $composableBuilder(
    column: $table.targetType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FavoritesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get targetType => $composableBuilder(
    column: $table.targetType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get subtitle =>
      $composableBuilder(column: $table.subtitle, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$FavoritesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoritesTable,
          Favorite,
          $$FavoritesTableFilterComposer,
          $$FavoritesTableOrderingComposer,
          $$FavoritesTableAnnotationComposer,
          $$FavoritesTableCreateCompanionBuilder,
          $$FavoritesTableUpdateCompanionBuilder,
          (Favorite, BaseReferences<_$AppDatabase, $FavoritesTable, Favorite>),
          Favorite,
          PrefetchHooks Function()
        > {
  $$FavoritesTableTableManager(_$AppDatabase db, $FavoritesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoritesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> targetType = const Value.absent(),
                Value<int> targetId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> subtitle = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
              }) => FavoritesCompanion(
                id: id,
                targetType: targetType,
                targetId: targetId,
                title: title,
                subtitle: subtitle,
                addedAt: addedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String targetType,
                required int targetId,
                required String title,
                Value<String?> subtitle = const Value.absent(),
                required DateTime addedAt,
              }) => FavoritesCompanion.insert(
                id: id,
                targetType: targetType,
                targetId: targetId,
                title: title,
                subtitle: subtitle,
                addedAt: addedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FavoritesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoritesTable,
      Favorite,
      $$FavoritesTableFilterComposer,
      $$FavoritesTableOrderingComposer,
      $$FavoritesTableAnnotationComposer,
      $$FavoritesTableCreateCompanionBuilder,
      $$FavoritesTableUpdateCompanionBuilder,
      (Favorite, BaseReferences<_$AppDatabase, $FavoritesTable, Favorite>),
      Favorite,
      PrefetchHooks Function()
    >;
typedef $$CollectionStateTableCreateCompanionBuilder =
    CollectionStateCompanion Function({
      required String fname,
      Value<int?> fid,
      Value<bool> enabled,
      Value<int> lastThreadTime,
      Value<int> lastTid,
      Value<DateTime?> lastRunAt,
      Value<String> lastStatus,
      Value<String?> lastError,
      Value<int> consecutiveFailures,
      Value<DateTime?> cooldownUntil,
      Value<int> newSinceVisit,
      Value<int> totalThreads,
      Value<int> totalFloors,
      Value<int> rowid,
    });
typedef $$CollectionStateTableUpdateCompanionBuilder =
    CollectionStateCompanion Function({
      Value<String> fname,
      Value<int?> fid,
      Value<bool> enabled,
      Value<int> lastThreadTime,
      Value<int> lastTid,
      Value<DateTime?> lastRunAt,
      Value<String> lastStatus,
      Value<String?> lastError,
      Value<int> consecutiveFailures,
      Value<DateTime?> cooldownUntil,
      Value<int> newSinceVisit,
      Value<int> totalThreads,
      Value<int> totalFloors,
      Value<int> rowid,
    });

class $$CollectionStateTableFilterComposer
    extends Composer<_$AppDatabase, $CollectionStateTable> {
  $$CollectionStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get fname => $composableBuilder(
    column: $table.fname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fid => $composableBuilder(
    column: $table.fid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastThreadTime => $composableBuilder(
    column: $table.lastThreadTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastTid => $composableBuilder(
    column: $table.lastTid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastRunAt => $composableBuilder(
    column: $table.lastRunAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastStatus => $composableBuilder(
    column: $table.lastStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get consecutiveFailures => $composableBuilder(
    column: $table.consecutiveFailures,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cooldownUntil => $composableBuilder(
    column: $table.cooldownUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get newSinceVisit => $composableBuilder(
    column: $table.newSinceVisit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalThreads => $composableBuilder(
    column: $table.totalThreads,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalFloors => $composableBuilder(
    column: $table.totalFloors,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CollectionStateTableOrderingComposer
    extends Composer<_$AppDatabase, $CollectionStateTable> {
  $$CollectionStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get fname => $composableBuilder(
    column: $table.fname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fid => $composableBuilder(
    column: $table.fid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastThreadTime => $composableBuilder(
    column: $table.lastThreadTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastTid => $composableBuilder(
    column: $table.lastTid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastRunAt => $composableBuilder(
    column: $table.lastRunAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastStatus => $composableBuilder(
    column: $table.lastStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get consecutiveFailures => $composableBuilder(
    column: $table.consecutiveFailures,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cooldownUntil => $composableBuilder(
    column: $table.cooldownUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get newSinceVisit => $composableBuilder(
    column: $table.newSinceVisit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalThreads => $composableBuilder(
    column: $table.totalThreads,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalFloors => $composableBuilder(
    column: $table.totalFloors,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CollectionStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $CollectionStateTable> {
  $$CollectionStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get fname =>
      $composableBuilder(column: $table.fname, builder: (column) => column);

  GeneratedColumn<int> get fid =>
      $composableBuilder(column: $table.fid, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get lastThreadTime => $composableBuilder(
    column: $table.lastThreadTime,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastTid =>
      $composableBuilder(column: $table.lastTid, builder: (column) => column);

  GeneratedColumn<DateTime> get lastRunAt =>
      $composableBuilder(column: $table.lastRunAt, builder: (column) => column);

  GeneratedColumn<String> get lastStatus => $composableBuilder(
    column: $table.lastStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get consecutiveFailures => $composableBuilder(
    column: $table.consecutiveFailures,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cooldownUntil => $composableBuilder(
    column: $table.cooldownUntil,
    builder: (column) => column,
  );

  GeneratedColumn<int> get newSinceVisit => $composableBuilder(
    column: $table.newSinceVisit,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalThreads => $composableBuilder(
    column: $table.totalThreads,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalFloors => $composableBuilder(
    column: $table.totalFloors,
    builder: (column) => column,
  );
}

class $$CollectionStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CollectionStateTable,
          CollectionStateEntry,
          $$CollectionStateTableFilterComposer,
          $$CollectionStateTableOrderingComposer,
          $$CollectionStateTableAnnotationComposer,
          $$CollectionStateTableCreateCompanionBuilder,
          $$CollectionStateTableUpdateCompanionBuilder,
          (
            CollectionStateEntry,
            BaseReferences<
              _$AppDatabase,
              $CollectionStateTable,
              CollectionStateEntry
            >,
          ),
          CollectionStateEntry,
          PrefetchHooks Function()
        > {
  $$CollectionStateTableTableManager(
    _$AppDatabase db,
    $CollectionStateTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CollectionStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CollectionStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CollectionStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> fname = const Value.absent(),
                Value<int?> fid = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> lastThreadTime = const Value.absent(),
                Value<int> lastTid = const Value.absent(),
                Value<DateTime?> lastRunAt = const Value.absent(),
                Value<String> lastStatus = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> consecutiveFailures = const Value.absent(),
                Value<DateTime?> cooldownUntil = const Value.absent(),
                Value<int> newSinceVisit = const Value.absent(),
                Value<int> totalThreads = const Value.absent(),
                Value<int> totalFloors = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CollectionStateCompanion(
                fname: fname,
                fid: fid,
                enabled: enabled,
                lastThreadTime: lastThreadTime,
                lastTid: lastTid,
                lastRunAt: lastRunAt,
                lastStatus: lastStatus,
                lastError: lastError,
                consecutiveFailures: consecutiveFailures,
                cooldownUntil: cooldownUntil,
                newSinceVisit: newSinceVisit,
                totalThreads: totalThreads,
                totalFloors: totalFloors,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String fname,
                Value<int?> fid = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> lastThreadTime = const Value.absent(),
                Value<int> lastTid = const Value.absent(),
                Value<DateTime?> lastRunAt = const Value.absent(),
                Value<String> lastStatus = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> consecutiveFailures = const Value.absent(),
                Value<DateTime?> cooldownUntil = const Value.absent(),
                Value<int> newSinceVisit = const Value.absent(),
                Value<int> totalThreads = const Value.absent(),
                Value<int> totalFloors = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CollectionStateCompanion.insert(
                fname: fname,
                fid: fid,
                enabled: enabled,
                lastThreadTime: lastThreadTime,
                lastTid: lastTid,
                lastRunAt: lastRunAt,
                lastStatus: lastStatus,
                lastError: lastError,
                consecutiveFailures: consecutiveFailures,
                cooldownUntil: cooldownUntil,
                newSinceVisit: newSinceVisit,
                totalThreads: totalThreads,
                totalFloors: totalFloors,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CollectionStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CollectionStateTable,
      CollectionStateEntry,
      $$CollectionStateTableFilterComposer,
      $$CollectionStateTableOrderingComposer,
      $$CollectionStateTableAnnotationComposer,
      $$CollectionStateTableCreateCompanionBuilder,
      $$CollectionStateTableUpdateCompanionBuilder,
      (
        CollectionStateEntry,
        BaseReferences<
          _$AppDatabase,
          $CollectionStateTable,
          CollectionStateEntry
        >,
      ),
      CollectionStateEntry,
      PrefetchHooks Function()
    >;
typedef $$CollectionLogsTableCreateCompanionBuilder =
    CollectionLogsCompanion Function({
      Value<int> id,
      required String fname,
      required DateTime runAt,
      required String status,
      Value<int> threadsAdded,
      Value<int> floorsAdded,
      Value<int> entriesAdded,
      Value<int> skippedDup,
      Value<String?> detail,
    });
typedef $$CollectionLogsTableUpdateCompanionBuilder =
    CollectionLogsCompanion Function({
      Value<int> id,
      Value<String> fname,
      Value<DateTime> runAt,
      Value<String> status,
      Value<int> threadsAdded,
      Value<int> floorsAdded,
      Value<int> entriesAdded,
      Value<int> skippedDup,
      Value<String?> detail,
    });

class $$CollectionLogsTableFilterComposer
    extends Composer<_$AppDatabase, $CollectionLogsTable> {
  $$CollectionLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fname => $composableBuilder(
    column: $table.fname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get runAt => $composableBuilder(
    column: $table.runAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get threadsAdded => $composableBuilder(
    column: $table.threadsAdded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get floorsAdded => $composableBuilder(
    column: $table.floorsAdded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get entriesAdded => $composableBuilder(
    column: $table.entriesAdded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get skippedDup => $composableBuilder(
    column: $table.skippedDup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CollectionLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $CollectionLogsTable> {
  $$CollectionLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fname => $composableBuilder(
    column: $table.fname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get runAt => $composableBuilder(
    column: $table.runAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get threadsAdded => $composableBuilder(
    column: $table.threadsAdded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get floorsAdded => $composableBuilder(
    column: $table.floorsAdded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get entriesAdded => $composableBuilder(
    column: $table.entriesAdded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get skippedDup => $composableBuilder(
    column: $table.skippedDup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CollectionLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CollectionLogsTable> {
  $$CollectionLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fname =>
      $composableBuilder(column: $table.fname, builder: (column) => column);

  GeneratedColumn<DateTime> get runAt =>
      $composableBuilder(column: $table.runAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get threadsAdded => $composableBuilder(
    column: $table.threadsAdded,
    builder: (column) => column,
  );

  GeneratedColumn<int> get floorsAdded => $composableBuilder(
    column: $table.floorsAdded,
    builder: (column) => column,
  );

  GeneratedColumn<int> get entriesAdded => $composableBuilder(
    column: $table.entriesAdded,
    builder: (column) => column,
  );

  GeneratedColumn<int> get skippedDup => $composableBuilder(
    column: $table.skippedDup,
    builder: (column) => column,
  );

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);
}

class $$CollectionLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CollectionLogsTable,
          CollectionLog,
          $$CollectionLogsTableFilterComposer,
          $$CollectionLogsTableOrderingComposer,
          $$CollectionLogsTableAnnotationComposer,
          $$CollectionLogsTableCreateCompanionBuilder,
          $$CollectionLogsTableUpdateCompanionBuilder,
          (
            CollectionLog,
            BaseReferences<_$AppDatabase, $CollectionLogsTable, CollectionLog>,
          ),
          CollectionLog,
          PrefetchHooks Function()
        > {
  $$CollectionLogsTableTableManager(
    _$AppDatabase db,
    $CollectionLogsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CollectionLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CollectionLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CollectionLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> fname = const Value.absent(),
                Value<DateTime> runAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> threadsAdded = const Value.absent(),
                Value<int> floorsAdded = const Value.absent(),
                Value<int> entriesAdded = const Value.absent(),
                Value<int> skippedDup = const Value.absent(),
                Value<String?> detail = const Value.absent(),
              }) => CollectionLogsCompanion(
                id: id,
                fname: fname,
                runAt: runAt,
                status: status,
                threadsAdded: threadsAdded,
                floorsAdded: floorsAdded,
                entriesAdded: entriesAdded,
                skippedDup: skippedDup,
                detail: detail,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String fname,
                required DateTime runAt,
                required String status,
                Value<int> threadsAdded = const Value.absent(),
                Value<int> floorsAdded = const Value.absent(),
                Value<int> entriesAdded = const Value.absent(),
                Value<int> skippedDup = const Value.absent(),
                Value<String?> detail = const Value.absent(),
              }) => CollectionLogsCompanion.insert(
                id: id,
                fname: fname,
                runAt: runAt,
                status: status,
                threadsAdded: threadsAdded,
                floorsAdded: floorsAdded,
                entriesAdded: entriesAdded,
                skippedDup: skippedDup,
                detail: detail,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CollectionLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CollectionLogsTable,
      CollectionLog,
      $$CollectionLogsTableFilterComposer,
      $$CollectionLogsTableOrderingComposer,
      $$CollectionLogsTableAnnotationComposer,
      $$CollectionLogsTableCreateCompanionBuilder,
      $$CollectionLogsTableUpdateCompanionBuilder,
      (
        CollectionLog,
        BaseReferences<_$AppDatabase, $CollectionLogsTable, CollectionLog>,
      ),
      CollectionLog,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PostsTableTableManager get posts =>
      $$PostsTableTableManager(_db, _db.posts);
  $$FloorsTableTableManager get floors =>
      $$FloorsTableTableManager(_db, _db.floors);
  $$ImagesTableTableManager get images =>
      $$ImagesTableTableManager(_db, _db.images);
  $$BookEntriesTableTableManager get bookEntries =>
      $$BookEntriesTableTableManager(_db, _db.bookEntries);
  $$BookGroupsTableTableManager get bookGroups =>
      $$BookGroupsTableTableManager(_db, _db.bookGroups);
  $$SearchHistoryTableTableManager get searchHistory =>
      $$SearchHistoryTableTableManager(_db, _db.searchHistory);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
  $$FavoritesTableTableManager get favorites =>
      $$FavoritesTableTableManager(_db, _db.favorites);
  $$CollectionStateTableTableManager get collectionState =>
      $$CollectionStateTableTableManager(_db, _db.collectionState);
  $$CollectionLogsTableTableManager get collectionLogs =>
      $$CollectionLogsTableTableManager(_db, _db.collectionLogs);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
