// This is a generated file - do not edit.
//
// Generated from Post.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'Agree.pb.dart' as $2;
import 'PbContent.pb.dart' as $0;
import 'SubPostList.pb.dart' as $3;
import 'User.pb.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class Post_SubPost extends $pb.GeneratedMessage {
  factory Post_SubPost({
    $core.Iterable<$3.SubPostList>? subPostList,
  }) {
    final result = Post_SubPost._();
    if (subPostList != null) result.subPostList.addAll(subPostList);
    return result;
  }

  Post_SubPost._();

  factory Post_SubPost.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Post_SubPost()..mergeFromBuffer(data, registry);
  factory Post_SubPost.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Post_SubPost()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Post.SubPost',
      createEmptyInstance: Post_SubPost.$_createMessage)
    ..pPM<$3.SubPostList>(2, _omitFieldNames ? '' : 'subPostList',
        subBuilder: $3.SubPostList.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Post_SubPost clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Post_SubPost copyWith(void Function(Post_SubPost) updates) =>
      super.copyWith((message) => updates(message as Post_SubPost))
          as Post_SubPost;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Post_SubPost() / Post_SubPost.new instead')
  static Post_SubPost create() => Post_SubPost._();
  static $pb.GeneratedMessage $_createMessage() => Post_SubPost._();
  @$core.override
  Post_SubPost createEmptyInstance() => Post_SubPost._();
  @$core.pragma('dart2js:noInline')
  static Post_SubPost getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Post_SubPost>(
          Post_SubPost.$_createMessage);
  static Post_SubPost? _defaultInstance;

  @$pb.TagNumber(2)
  $pb.PbList<$3.SubPostList> get subPostList => $_getList(0);
}

class Post_SignatureData_SignatureContent extends $pb.GeneratedMessage {
  factory Post_SignatureData_SignatureContent({
    $core.int? type,
    $core.String? text,
  }) {
    final result = Post_SignatureData_SignatureContent._();
    if (type != null) result.type = type;
    if (text != null) result.text = text;
    return result;
  }

  Post_SignatureData_SignatureContent._();

  factory Post_SignatureData_SignatureContent.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Post_SignatureData_SignatureContent()..mergeFromBuffer(data, registry);
  factory Post_SignatureData_SignatureContent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Post_SignatureData_SignatureContent()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Post.SignatureData.SignatureContent',
      createEmptyInstance: Post_SignatureData_SignatureContent.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'type')
    ..aOS(2, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Post_SignatureData_SignatureContent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Post_SignatureData_SignatureContent copyWith(
          void Function(Post_SignatureData_SignatureContent) updates) =>
      super.copyWith((message) =>
              updates(message as Post_SignatureData_SignatureContent))
          as Post_SignatureData_SignatureContent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use Post_SignatureData_SignatureContent() / Post_SignatureData_SignatureContent.new instead')
  static Post_SignatureData_SignatureContent create() =>
      Post_SignatureData_SignatureContent._();
  static $pb.GeneratedMessage $_createMessage() =>
      Post_SignatureData_SignatureContent._();
  @$core.override
  Post_SignatureData_SignatureContent createEmptyInstance() =>
      Post_SignatureData_SignatureContent._();
  @$core.pragma('dart2js:noInline')
  static Post_SignatureData_SignatureContent getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
              Post_SignatureData_SignatureContent>(
          Post_SignatureData_SignatureContent.$_createMessage);
  static Post_SignatureData_SignatureContent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get type => $_getIZ(0);
  @$pb.TagNumber(1)
  set type($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get text => $_getSZ(1);
  @$pb.TagNumber(2)
  set text($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasText() => $_has(1);
  @$pb.TagNumber(2)
  void clearText() => $_clearField(2);
}

class Post_SignatureData extends $pb.GeneratedMessage {
  factory Post_SignatureData({
    $core.Iterable<Post_SignatureData_SignatureContent>? content,
  }) {
    final result = Post_SignatureData._();
    if (content != null) result.content.addAll(content);
    return result;
  }

  Post_SignatureData._();

  factory Post_SignatureData.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Post_SignatureData()..mergeFromBuffer(data, registry);
  factory Post_SignatureData.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Post_SignatureData()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Post.SignatureData',
      createEmptyInstance: Post_SignatureData.$_createMessage)
    ..pPM<Post_SignatureData_SignatureContent>(
        4, _omitFieldNames ? '' : 'content',
        subBuilder: Post_SignatureData_SignatureContent.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Post_SignatureData clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Post_SignatureData copyWith(void Function(Post_SignatureData) updates) =>
      super.copyWith((message) => updates(message as Post_SignatureData))
          as Post_SignatureData;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Post_SignatureData() / Post_SignatureData.new instead')
  static Post_SignatureData create() => Post_SignatureData._();
  static $pb.GeneratedMessage $_createMessage() => Post_SignatureData._();
  @$core.override
  Post_SignatureData createEmptyInstance() => Post_SignatureData._();
  @$core.pragma('dart2js:noInline')
  static Post_SignatureData getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Post_SignatureData>(
          Post_SignatureData.$_createMessage);
  static Post_SignatureData? _defaultInstance;

  @$pb.TagNumber(4)
  $pb.PbList<Post_SignatureData_SignatureContent> get content => $_getList(0);
}

class Post_ChatContent extends $pb.GeneratedMessage {
  factory Post_ChatContent({
    $core.String? botUk,
  }) {
    final result = Post_ChatContent._();
    if (botUk != null) result.botUk = botUk;
    return result;
  }

  Post_ChatContent._();

  factory Post_ChatContent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Post_ChatContent()..mergeFromBuffer(data, registry);
  factory Post_ChatContent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Post_ChatContent()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Post.ChatContent',
      createEmptyInstance: Post_ChatContent.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'botUk')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Post_ChatContent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Post_ChatContent copyWith(void Function(Post_ChatContent) updates) =>
      super.copyWith((message) => updates(message as Post_ChatContent))
          as Post_ChatContent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Post_ChatContent() / Post_ChatContent.new instead')
  static Post_ChatContent create() => Post_ChatContent._();
  static $pb.GeneratedMessage $_createMessage() => Post_ChatContent._();
  @$core.override
  Post_ChatContent createEmptyInstance() => Post_ChatContent._();
  @$core.pragma('dart2js:noInline')
  static Post_ChatContent getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Post_ChatContent>(
          Post_ChatContent.$_createMessage);
  static Post_ChatContent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get botUk => $_getSZ(0);
  @$pb.TagNumber(1)
  set botUk($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBotUk() => $_has(0);
  @$pb.TagNumber(1)
  void clearBotUk() => $_clearField(1);
}

class Post_SpriteMemeInfo extends $pb.GeneratedMessage {
  factory Post_SpriteMemeInfo({
    $fixnum.Int64? memeId,
  }) {
    final result = Post_SpriteMemeInfo._();
    if (memeId != null) result.memeId = memeId;
    return result;
  }

  Post_SpriteMemeInfo._();

  factory Post_SpriteMemeInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Post_SpriteMemeInfo()..mergeFromBuffer(data, registry);
  factory Post_SpriteMemeInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Post_SpriteMemeInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Post.SpriteMemeInfo',
      createEmptyInstance: Post_SpriteMemeInfo.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'memeId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Post_SpriteMemeInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Post_SpriteMemeInfo copyWith(void Function(Post_SpriteMemeInfo) updates) =>
      super.copyWith((message) => updates(message as Post_SpriteMemeInfo))
          as Post_SpriteMemeInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use Post_SpriteMemeInfo() / Post_SpriteMemeInfo.new instead')
  static Post_SpriteMemeInfo create() => Post_SpriteMemeInfo._();
  static $pb.GeneratedMessage $_createMessage() => Post_SpriteMemeInfo._();
  @$core.override
  Post_SpriteMemeInfo createEmptyInstance() => Post_SpriteMemeInfo._();
  @$core.pragma('dart2js:noInline')
  static Post_SpriteMemeInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Post_SpriteMemeInfo>(
          Post_SpriteMemeInfo.$_createMessage);
  static Post_SpriteMemeInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get memeId => $_getI64(0);
  @$pb.TagNumber(1)
  set memeId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMemeId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMemeId() => $_clearField(1);
}

class Post extends $pb.GeneratedMessage {
  factory Post({
    $fixnum.Int64? id,
    $core.int? floor,
    $core.int? time,
    $core.Iterable<$0.PbContent>? content,
    $core.int? subPostNumber,
    Post_SubPost? subPostList,
    $fixnum.Int64? authorId,
    Post_SignatureData? signature,
    $1.User? author,
    $2.Agree? agree,
    $fixnum.Int64? tid,
    Post_ChatContent? chatContent,
    Post_SpriteMemeInfo? spriteMemeInfo,
  }) {
    final result = Post._();
    if (id != null) result.id = id;
    if (floor != null) result.floor = floor;
    if (time != null) result.time = time;
    if (content != null) result.content.addAll(content);
    if (subPostNumber != null) result.subPostNumber = subPostNumber;
    if (subPostList != null) result.subPostList = subPostList;
    if (authorId != null) result.authorId = authorId;
    if (signature != null) result.signature = signature;
    if (author != null) result.author = author;
    if (agree != null) result.agree = agree;
    if (tid != null) result.tid = tid;
    if (chatContent != null) result.chatContent = chatContent;
    if (spriteMemeInfo != null) result.spriteMemeInfo = spriteMemeInfo;
    return result;
  }

  Post._();

  factory Post.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Post()..mergeFromBuffer(data, registry);
  factory Post.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Post()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Post',
      createEmptyInstance: Post.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aI(3, _omitFieldNames ? '' : 'floor', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'time', fieldType: $pb.PbFieldType.OU3)
    ..pPM<$0.PbContent>(5, _omitFieldNames ? '' : 'content',
        subBuilder: $0.PbContent.$_createMessage)
    ..aI(13, _omitFieldNames ? '' : 'subPostNumber',
        fieldType: $pb.PbFieldType.OU3)
    ..aOM<Post_SubPost>(15, _omitFieldNames ? '' : 'subPostList',
        subBuilder: Post_SubPost.$_createMessage)
    ..aInt64(19, _omitFieldNames ? '' : 'authorId')
    ..aOM<Post_SignatureData>(21, _omitFieldNames ? '' : 'signature',
        subBuilder: Post_SignatureData.$_createMessage)
    ..aOM<$1.User>(23, _omitFieldNames ? '' : 'author',
        subBuilder: $1.User.$_createMessage)
    ..aOM<$2.Agree>(37, _omitFieldNames ? '' : 'agree',
        subBuilder: $2.Agree.$_createMessage)
    ..aInt64(46, _omitFieldNames ? '' : 'tid')
    ..aOM<Post_ChatContent>(78, _omitFieldNames ? '' : 'chatContent',
        subBuilder: Post_ChatContent.$_createMessage)
    ..aOM<Post_SpriteMemeInfo>(79, _omitFieldNames ? '' : 'spriteMemeInfo',
        subBuilder: Post_SpriteMemeInfo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Post clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Post copyWith(void Function(Post) updates) =>
      super.copyWith((message) => updates(message as Post)) as Post;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Post() / Post.new instead')
  static Post create() => Post._();
  static $pb.GeneratedMessage $_createMessage() => Post._();
  @$core.override
  Post createEmptyInstance() => Post._();
  @$core.pragma('dart2js:noInline')
  static Post getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Post>(Post.$_createMessage);
  static Post? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(3)
  $core.int get floor => $_getIZ(1);
  @$pb.TagNumber(3)
  set floor($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(3)
  $core.bool hasFloor() => $_has(1);
  @$pb.TagNumber(3)
  void clearFloor() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get time => $_getIZ(2);
  @$pb.TagNumber(4)
  set time($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(4)
  $core.bool hasTime() => $_has(2);
  @$pb.TagNumber(4)
  void clearTime() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<$0.PbContent> get content => $_getList(3);

  @$pb.TagNumber(13)
  $core.int get subPostNumber => $_getIZ(4);
  @$pb.TagNumber(13)
  set subPostNumber($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(13)
  $core.bool hasSubPostNumber() => $_has(4);
  @$pb.TagNumber(13)
  void clearSubPostNumber() => $_clearField(13);

  @$pb.TagNumber(15)
  Post_SubPost get subPostList => $_getN(5);
  @$pb.TagNumber(15)
  set subPostList(Post_SubPost value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasSubPostList() => $_has(5);
  @$pb.TagNumber(15)
  void clearSubPostList() => $_clearField(15);
  @$pb.TagNumber(15)
  Post_SubPost ensureSubPostList() => $_ensure(5);

  @$pb.TagNumber(19)
  $fixnum.Int64 get authorId => $_getI64(6);
  @$pb.TagNumber(19)
  set authorId($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(19)
  $core.bool hasAuthorId() => $_has(6);
  @$pb.TagNumber(19)
  void clearAuthorId() => $_clearField(19);

  @$pb.TagNumber(21)
  Post_SignatureData get signature => $_getN(7);
  @$pb.TagNumber(21)
  set signature(Post_SignatureData value) => $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasSignature() => $_has(7);
  @$pb.TagNumber(21)
  void clearSignature() => $_clearField(21);
  @$pb.TagNumber(21)
  Post_SignatureData ensureSignature() => $_ensure(7);

  @$pb.TagNumber(23)
  $1.User get author => $_getN(8);
  @$pb.TagNumber(23)
  set author($1.User value) => $_setField(23, value);
  @$pb.TagNumber(23)
  $core.bool hasAuthor() => $_has(8);
  @$pb.TagNumber(23)
  void clearAuthor() => $_clearField(23);
  @$pb.TagNumber(23)
  $1.User ensureAuthor() => $_ensure(8);

  @$pb.TagNumber(37)
  $2.Agree get agree => $_getN(9);
  @$pb.TagNumber(37)
  set agree($2.Agree value) => $_setField(37, value);
  @$pb.TagNumber(37)
  $core.bool hasAgree() => $_has(9);
  @$pb.TagNumber(37)
  void clearAgree() => $_clearField(37);
  @$pb.TagNumber(37)
  $2.Agree ensureAgree() => $_ensure(9);

  @$pb.TagNumber(46)
  $fixnum.Int64 get tid => $_getI64(10);
  @$pb.TagNumber(46)
  set tid($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(46)
  $core.bool hasTid() => $_has(10);
  @$pb.TagNumber(46)
  void clearTid() => $_clearField(46);

  @$pb.TagNumber(78)
  Post_ChatContent get chatContent => $_getN(11);
  @$pb.TagNumber(78)
  set chatContent(Post_ChatContent value) => $_setField(78, value);
  @$pb.TagNumber(78)
  $core.bool hasChatContent() => $_has(11);
  @$pb.TagNumber(78)
  void clearChatContent() => $_clearField(78);
  @$pb.TagNumber(78)
  Post_ChatContent ensureChatContent() => $_ensure(11);

  @$pb.TagNumber(79)
  Post_SpriteMemeInfo get spriteMemeInfo => $_getN(12);
  @$pb.TagNumber(79)
  set spriteMemeInfo(Post_SpriteMemeInfo value) => $_setField(79, value);
  @$pb.TagNumber(79)
  $core.bool hasSpriteMemeInfo() => $_has(12);
  @$pb.TagNumber(79)
  void clearSpriteMemeInfo() => $_clearField(79);
  @$pb.TagNumber(79)
  Post_SpriteMemeInfo ensureSpriteMemeInfo() => $_ensure(12);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
