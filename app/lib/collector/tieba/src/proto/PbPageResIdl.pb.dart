// This is a generated file - do not edit.
//
// Generated from PbPageResIdl.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'Error.pb.dart' as $0;
import 'Page.pb.dart' as $2;
import 'Post.pb.dart' as $3;
import 'SimpleForum.pb.dart' as $1;
import 'ThreadInfo.pb.dart' as $4;
import 'User.pb.dart' as $5;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class PbPageResIdl_DataRes extends $pb.GeneratedMessage {
  factory PbPageResIdl_DataRes({
    $1.SimpleForum? forum,
    $2.Page? page,
    $core.Iterable<$3.Post>? postList,
    $4.ThreadInfo? thread,
    $core.Iterable<$5.User>? userList,
    $fixnum.Int64? threadFreqNum,
  }) {
    final result = PbPageResIdl_DataRes._();
    if (forum != null) result.forum = forum;
    if (page != null) result.page = page;
    if (postList != null) result.postList.addAll(postList);
    if (thread != null) result.thread = thread;
    if (userList != null) result.userList.addAll(userList);
    if (threadFreqNum != null) result.threadFreqNum = threadFreqNum;
    return result;
  }

  PbPageResIdl_DataRes._();

  factory PbPageResIdl_DataRes.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PbPageResIdl_DataRes()..mergeFromBuffer(data, registry);
  factory PbPageResIdl_DataRes.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PbPageResIdl_DataRes()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PbPageResIdl.DataRes',
      createEmptyInstance: PbPageResIdl_DataRes.$_createMessage)
    ..aOM<$1.SimpleForum>(2, _omitFieldNames ? '' : 'forum',
        subBuilder: $1.SimpleForum.$_createMessage)
    ..aOM<$2.Page>(3, _omitFieldNames ? '' : 'page',
        subBuilder: $2.Page.$_createMessage)
    ..pPM<$3.Post>(6, _omitFieldNames ? '' : 'postList',
        subBuilder: $3.Post.$_createMessage)
    ..aOM<$4.ThreadInfo>(8, _omitFieldNames ? '' : 'thread',
        subBuilder: $4.ThreadInfo.$_createMessage)
    ..pPM<$5.User>(13, _omitFieldNames ? '' : 'userList',
        subBuilder: $5.User.$_createMessage)
    ..aInt64(37, _omitFieldNames ? '' : 'threadFreqNum')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PbPageResIdl_DataRes clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PbPageResIdl_DataRes copyWith(void Function(PbPageResIdl_DataRes) updates) =>
      super.copyWith((message) => updates(message as PbPageResIdl_DataRes))
          as PbPageResIdl_DataRes;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use PbPageResIdl_DataRes() / PbPageResIdl_DataRes.new instead')
  static PbPageResIdl_DataRes create() => PbPageResIdl_DataRes._();
  static $pb.GeneratedMessage $_createMessage() => PbPageResIdl_DataRes._();
  @$core.override
  PbPageResIdl_DataRes createEmptyInstance() => PbPageResIdl_DataRes._();
  @$core.pragma('dart2js:noInline')
  static PbPageResIdl_DataRes getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PbPageResIdl_DataRes>(
          PbPageResIdl_DataRes.$_createMessage);
  static PbPageResIdl_DataRes? _defaultInstance;

  @$pb.TagNumber(2)
  $1.SimpleForum get forum => $_getN(0);
  @$pb.TagNumber(2)
  set forum($1.SimpleForum value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasForum() => $_has(0);
  @$pb.TagNumber(2)
  void clearForum() => $_clearField(2);
  @$pb.TagNumber(2)
  $1.SimpleForum ensureForum() => $_ensure(0);

  @$pb.TagNumber(3)
  $2.Page get page => $_getN(1);
  @$pb.TagNumber(3)
  set page($2.Page value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasPage() => $_has(1);
  @$pb.TagNumber(3)
  void clearPage() => $_clearField(3);
  @$pb.TagNumber(3)
  $2.Page ensurePage() => $_ensure(1);

  @$pb.TagNumber(6)
  $pb.PbList<$3.Post> get postList => $_getList(2);

  @$pb.TagNumber(8)
  $4.ThreadInfo get thread => $_getN(3);
  @$pb.TagNumber(8)
  set thread($4.ThreadInfo value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasThread() => $_has(3);
  @$pb.TagNumber(8)
  void clearThread() => $_clearField(8);
  @$pb.TagNumber(8)
  $4.ThreadInfo ensureThread() => $_ensure(3);

  @$pb.TagNumber(13)
  $pb.PbList<$5.User> get userList => $_getList(4);

  @$pb.TagNumber(37)
  $fixnum.Int64 get threadFreqNum => $_getI64(5);
  @$pb.TagNumber(37)
  set threadFreqNum($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(37)
  $core.bool hasThreadFreqNum() => $_has(5);
  @$pb.TagNumber(37)
  void clearThreadFreqNum() => $_clearField(37);
}

class PbPageResIdl extends $pb.GeneratedMessage {
  factory PbPageResIdl({
    $0.Error? error,
    PbPageResIdl_DataRes? data,
  }) {
    final result = PbPageResIdl._();
    if (error != null) result.error = error;
    if (data != null) result.data = data;
    return result;
  }

  PbPageResIdl._();

  factory PbPageResIdl.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PbPageResIdl()..mergeFromBuffer(data, registry);
  factory PbPageResIdl.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PbPageResIdl()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PbPageResIdl',
      createEmptyInstance: PbPageResIdl.$_createMessage)
    ..aOM<$0.Error>(1, _omitFieldNames ? '' : 'error',
        subBuilder: $0.Error.$_createMessage)
    ..aOM<PbPageResIdl_DataRes>(2, _omitFieldNames ? '' : 'data',
        subBuilder: PbPageResIdl_DataRes.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PbPageResIdl clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PbPageResIdl copyWith(void Function(PbPageResIdl) updates) =>
      super.copyWith((message) => updates(message as PbPageResIdl))
          as PbPageResIdl;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PbPageResIdl() / PbPageResIdl.new instead')
  static PbPageResIdl create() => PbPageResIdl._();
  static $pb.GeneratedMessage $_createMessage() => PbPageResIdl._();
  @$core.override
  PbPageResIdl createEmptyInstance() => PbPageResIdl._();
  @$core.pragma('dart2js:noInline')
  static PbPageResIdl getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PbPageResIdl>(
          PbPageResIdl.$_createMessage);
  static PbPageResIdl? _defaultInstance;

  @$pb.TagNumber(1)
  $0.Error get error => $_getN(0);
  @$pb.TagNumber(1)
  set error($0.Error value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasError() => $_has(0);
  @$pb.TagNumber(1)
  void clearError() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.Error ensureError() => $_ensure(0);

  @$pb.TagNumber(2)
  PbPageResIdl_DataRes get data => $_getN(1);
  @$pb.TagNumber(2)
  set data(PbPageResIdl_DataRes value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => $_clearField(2);
  @$pb.TagNumber(2)
  PbPageResIdl_DataRes ensureData() => $_ensure(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
