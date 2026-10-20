// This is a generated file - do not edit.
//
// Generated from SubPostList.proto.

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
import 'User.pb.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class SubPostList extends $pb.GeneratedMessage {
  factory SubPostList({
    $fixnum.Int64? id,
    $core.Iterable<$0.PbContent>? content,
    $core.int? time,
    $fixnum.Int64? authorId,
    $core.String? title,
    $core.int? floor,
    $1.User? author,
    $2.Agree? agree,
  }) {
    final result = SubPostList._();
    if (id != null) result.id = id;
    if (content != null) result.content.addAll(content);
    if (time != null) result.time = time;
    if (authorId != null) result.authorId = authorId;
    if (title != null) result.title = title;
    if (floor != null) result.floor = floor;
    if (author != null) result.author = author;
    if (agree != null) result.agree = agree;
    return result;
  }

  SubPostList._();

  factory SubPostList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SubPostList()..mergeFromBuffer(data, registry);
  factory SubPostList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SubPostList()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubPostList',
      createEmptyInstance: SubPostList.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..pPM<$0.PbContent>(2, _omitFieldNames ? '' : 'content',
        subBuilder: $0.PbContent.$_createMessage)
    ..aI(3, _omitFieldNames ? '' : 'time', fieldType: $pb.PbFieldType.OU3)
    ..aInt64(4, _omitFieldNames ? '' : 'authorId')
    ..aOS(5, _omitFieldNames ? '' : 'title')
    ..aI(6, _omitFieldNames ? '' : 'floor', fieldType: $pb.PbFieldType.OU3)
    ..aOM<$1.User>(7, _omitFieldNames ? '' : 'author',
        subBuilder: $1.User.$_createMessage)
    ..aOM<$2.Agree>(9, _omitFieldNames ? '' : 'agree',
        subBuilder: $2.Agree.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubPostList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubPostList copyWith(void Function(SubPostList) updates) =>
      super.copyWith((message) => updates(message as SubPostList))
          as SubPostList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SubPostList() / SubPostList.new instead')
  static SubPostList create() => SubPostList._();
  static $pb.GeneratedMessage $_createMessage() => SubPostList._();
  @$core.override
  SubPostList createEmptyInstance() => SubPostList._();
  @$core.pragma('dart2js:noInline')
  static SubPostList getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SubPostList>(
          SubPostList.$_createMessage);
  static SubPostList? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$0.PbContent> get content => $_getList(1);

  @$pb.TagNumber(3)
  $core.int get time => $_getIZ(2);
  @$pb.TagNumber(3)
  set time($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTime() => $_has(2);
  @$pb.TagNumber(3)
  void clearTime() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get authorId => $_getI64(3);
  @$pb.TagNumber(4)
  set authorId($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAuthorId() => $_has(3);
  @$pb.TagNumber(4)
  void clearAuthorId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get title => $_getSZ(4);
  @$pb.TagNumber(5)
  set title($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTitle() => $_has(4);
  @$pb.TagNumber(5)
  void clearTitle() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get floor => $_getIZ(5);
  @$pb.TagNumber(6)
  set floor($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFloor() => $_has(5);
  @$pb.TagNumber(6)
  void clearFloor() => $_clearField(6);

  @$pb.TagNumber(7)
  $1.User get author => $_getN(6);
  @$pb.TagNumber(7)
  set author($1.User value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasAuthor() => $_has(6);
  @$pb.TagNumber(7)
  void clearAuthor() => $_clearField(7);
  @$pb.TagNumber(7)
  $1.User ensureAuthor() => $_ensure(6);

  @$pb.TagNumber(9)
  $2.Agree get agree => $_getN(7);
  @$pb.TagNumber(9)
  set agree($2.Agree value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasAgree() => $_has(7);
  @$pb.TagNumber(9)
  void clearAgree() => $_clearField(9);
  @$pb.TagNumber(9)
  $2.Agree ensureAgree() => $_ensure(7);
}

class SubPost extends $pb.GeneratedMessage {
  factory SubPost({
    $fixnum.Int64? pid,
    $core.Iterable<SubPostList>? subPostList,
  }) {
    final result = SubPost._();
    if (pid != null) result.pid = pid;
    if (subPostList != null) result.subPostList.addAll(subPostList);
    return result;
  }

  SubPost._();

  factory SubPost.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SubPost()..mergeFromBuffer(data, registry);
  factory SubPost.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SubPost()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubPost',
      createEmptyInstance: SubPost.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'pid', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..pPM<SubPostList>(2, _omitFieldNames ? '' : 'subPostList',
        subBuilder: SubPostList.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubPost clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubPost copyWith(void Function(SubPost) updates) =>
      super.copyWith((message) => updates(message as SubPost)) as SubPost;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SubPost() / SubPost.new instead')
  static SubPost create() => SubPost._();
  static $pb.GeneratedMessage $_createMessage() => SubPost._();
  @$core.override
  SubPost createEmptyInstance() => SubPost._();
  @$core.pragma('dart2js:noInline')
  static SubPost getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SubPost>(SubPost.$_createMessage);
  static SubPost? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get pid => $_getI64(0);
  @$pb.TagNumber(1)
  set pid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPid() => $_has(0);
  @$pb.TagNumber(1)
  void clearPid() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<SubPostList> get subPostList => $_getList(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
