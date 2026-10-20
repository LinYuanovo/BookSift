// This is a generated file - do not edit.
//
// Generated from FrsPageResIdl.proto.

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
import 'FrsTabInfo.pb.dart' as $4;
import 'Page.pb.dart' as $1;
import 'ThreadInfo.pb.dart' as $2;
import 'User.pb.dart' as $3;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class FrsPageResIdl_DataRes_ForumInfo_Manager extends $pb.GeneratedMessage {
  factory FrsPageResIdl_DataRes_ForumInfo_Manager() =>
      FrsPageResIdl_DataRes_ForumInfo_Manager._();

  FrsPageResIdl_DataRes_ForumInfo_Manager._();

  factory FrsPageResIdl_DataRes_ForumInfo_Manager.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FrsPageResIdl_DataRes_ForumInfo_Manager()
        ..mergeFromBuffer(data, registry);
  factory FrsPageResIdl_DataRes_ForumInfo_Manager.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FrsPageResIdl_DataRes_ForumInfo_Manager()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FrsPageResIdl.DataRes.ForumInfo.Manager',
      createEmptyInstance:
          FrsPageResIdl_DataRes_ForumInfo_Manager.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FrsPageResIdl_DataRes_ForumInfo_Manager clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FrsPageResIdl_DataRes_ForumInfo_Manager copyWith(
          void Function(FrsPageResIdl_DataRes_ForumInfo_Manager) updates) =>
      super.copyWith((message) =>
              updates(message as FrsPageResIdl_DataRes_ForumInfo_Manager))
          as FrsPageResIdl_DataRes_ForumInfo_Manager;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use FrsPageResIdl_DataRes_ForumInfo_Manager() / FrsPageResIdl_DataRes_ForumInfo_Manager.new instead')
  static FrsPageResIdl_DataRes_ForumInfo_Manager create() =>
      FrsPageResIdl_DataRes_ForumInfo_Manager._();
  static $pb.GeneratedMessage $_createMessage() =>
      FrsPageResIdl_DataRes_ForumInfo_Manager._();
  @$core.override
  FrsPageResIdl_DataRes_ForumInfo_Manager createEmptyInstance() =>
      FrsPageResIdl_DataRes_ForumInfo_Manager._();
  @$core.pragma('dart2js:noInline')
  static FrsPageResIdl_DataRes_ForumInfo_Manager getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
              FrsPageResIdl_DataRes_ForumInfo_Manager>(
          FrsPageResIdl_DataRes_ForumInfo_Manager.$_createMessage);
  static FrsPageResIdl_DataRes_ForumInfo_Manager? _defaultInstance;
}

class FrsPageResIdl_DataRes_ForumInfo extends $pb.GeneratedMessage {
  factory FrsPageResIdl_DataRes_ForumInfo({
    $fixnum.Int64? id,
    $core.String? name,
    $core.String? firstClass,
    $core.String? secondClass,
    $core.int? memberNum,
    $core.int? threadNum,
    $core.int? postNum,
    $core.Iterable<FrsPageResIdl_DataRes_ForumInfo_Manager>? managers,
  }) {
    final result = FrsPageResIdl_DataRes_ForumInfo._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (firstClass != null) result.firstClass = firstClass;
    if (secondClass != null) result.secondClass = secondClass;
    if (memberNum != null) result.memberNum = memberNum;
    if (threadNum != null) result.threadNum = threadNum;
    if (postNum != null) result.postNum = postNum;
    if (managers != null) result.managers.addAll(managers);
    return result;
  }

  FrsPageResIdl_DataRes_ForumInfo._();

  factory FrsPageResIdl_DataRes_ForumInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FrsPageResIdl_DataRes_ForumInfo()..mergeFromBuffer(data, registry);
  factory FrsPageResIdl_DataRes_ForumInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FrsPageResIdl_DataRes_ForumInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FrsPageResIdl.DataRes.ForumInfo',
      createEmptyInstance: FrsPageResIdl_DataRes_ForumInfo.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'firstClass')
    ..aOS(4, _omitFieldNames ? '' : 'secondClass')
    ..aI(9, _omitFieldNames ? '' : 'memberNum')
    ..aI(10, _omitFieldNames ? '' : 'threadNum')
    ..aI(11, _omitFieldNames ? '' : 'postNum')
    ..pPM<FrsPageResIdl_DataRes_ForumInfo_Manager>(
        17, _omitFieldNames ? '' : 'managers',
        subBuilder: FrsPageResIdl_DataRes_ForumInfo_Manager.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FrsPageResIdl_DataRes_ForumInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FrsPageResIdl_DataRes_ForumInfo copyWith(
          void Function(FrsPageResIdl_DataRes_ForumInfo) updates) =>
      super.copyWith(
              (message) => updates(message as FrsPageResIdl_DataRes_ForumInfo))
          as FrsPageResIdl_DataRes_ForumInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use FrsPageResIdl_DataRes_ForumInfo() / FrsPageResIdl_DataRes_ForumInfo.new instead')
  static FrsPageResIdl_DataRes_ForumInfo create() =>
      FrsPageResIdl_DataRes_ForumInfo._();
  static $pb.GeneratedMessage $_createMessage() =>
      FrsPageResIdl_DataRes_ForumInfo._();
  @$core.override
  FrsPageResIdl_DataRes_ForumInfo createEmptyInstance() =>
      FrsPageResIdl_DataRes_ForumInfo._();
  @$core.pragma('dart2js:noInline')
  static FrsPageResIdl_DataRes_ForumInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FrsPageResIdl_DataRes_ForumInfo>(
          FrsPageResIdl_DataRes_ForumInfo.$_createMessage);
  static FrsPageResIdl_DataRes_ForumInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get firstClass => $_getSZ(2);
  @$pb.TagNumber(3)
  set firstClass($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFirstClass() => $_has(2);
  @$pb.TagNumber(3)
  void clearFirstClass() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get secondClass => $_getSZ(3);
  @$pb.TagNumber(4)
  set secondClass($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSecondClass() => $_has(3);
  @$pb.TagNumber(4)
  void clearSecondClass() => $_clearField(4);

  @$pb.TagNumber(9)
  $core.int get memberNum => $_getIZ(4);
  @$pb.TagNumber(9)
  set memberNum($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(9)
  $core.bool hasMemberNum() => $_has(4);
  @$pb.TagNumber(9)
  void clearMemberNum() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get threadNum => $_getIZ(5);
  @$pb.TagNumber(10)
  set threadNum($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(10)
  $core.bool hasThreadNum() => $_has(5);
  @$pb.TagNumber(10)
  void clearThreadNum() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get postNum => $_getIZ(6);
  @$pb.TagNumber(11)
  set postNum($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(11)
  $core.bool hasPostNum() => $_has(6);
  @$pb.TagNumber(11)
  void clearPostNum() => $_clearField(11);

  @$pb.TagNumber(17)
  $pb.PbList<FrsPageResIdl_DataRes_ForumInfo_Manager> get managers =>
      $_getList(7);
}

class FrsPageResIdl_DataRes_NavTabInfo extends $pb.GeneratedMessage {
  factory FrsPageResIdl_DataRes_NavTabInfo({
    $core.Iterable<$4.FrsTabInfo>? tab,
  }) {
    final result = FrsPageResIdl_DataRes_NavTabInfo._();
    if (tab != null) result.tab.addAll(tab);
    return result;
  }

  FrsPageResIdl_DataRes_NavTabInfo._();

  factory FrsPageResIdl_DataRes_NavTabInfo.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FrsPageResIdl_DataRes_NavTabInfo()..mergeFromBuffer(data, registry);
  factory FrsPageResIdl_DataRes_NavTabInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FrsPageResIdl_DataRes_NavTabInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FrsPageResIdl.DataRes.NavTabInfo',
      createEmptyInstance: FrsPageResIdl_DataRes_NavTabInfo.$_createMessage)
    ..pPM<$4.FrsTabInfo>(1, _omitFieldNames ? '' : 'tab',
        subBuilder: $4.FrsTabInfo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FrsPageResIdl_DataRes_NavTabInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FrsPageResIdl_DataRes_NavTabInfo copyWith(
          void Function(FrsPageResIdl_DataRes_NavTabInfo) updates) =>
      super.copyWith(
              (message) => updates(message as FrsPageResIdl_DataRes_NavTabInfo))
          as FrsPageResIdl_DataRes_NavTabInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use FrsPageResIdl_DataRes_NavTabInfo() / FrsPageResIdl_DataRes_NavTabInfo.new instead')
  static FrsPageResIdl_DataRes_NavTabInfo create() =>
      FrsPageResIdl_DataRes_NavTabInfo._();
  static $pb.GeneratedMessage $_createMessage() =>
      FrsPageResIdl_DataRes_NavTabInfo._();
  @$core.override
  FrsPageResIdl_DataRes_NavTabInfo createEmptyInstance() =>
      FrsPageResIdl_DataRes_NavTabInfo._();
  @$core.pragma('dart2js:noInline')
  static FrsPageResIdl_DataRes_NavTabInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FrsPageResIdl_DataRes_NavTabInfo>(
          FrsPageResIdl_DataRes_NavTabInfo.$_createMessage);
  static FrsPageResIdl_DataRes_NavTabInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$4.FrsTabInfo> get tab => $_getList(0);
}

class FrsPageResIdl_DataRes_ForumRuleStatus extends $pb.GeneratedMessage {
  factory FrsPageResIdl_DataRes_ForumRuleStatus({
    $core.int? hasForumRule,
  }) {
    final result = FrsPageResIdl_DataRes_ForumRuleStatus._();
    if (hasForumRule != null) result.hasForumRule = hasForumRule;
    return result;
  }

  FrsPageResIdl_DataRes_ForumRuleStatus._();

  factory FrsPageResIdl_DataRes_ForumRuleStatus.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FrsPageResIdl_DataRes_ForumRuleStatus()..mergeFromBuffer(data, registry);
  factory FrsPageResIdl_DataRes_ForumRuleStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FrsPageResIdl_DataRes_ForumRuleStatus()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FrsPageResIdl.DataRes.ForumRuleStatus',
      createEmptyInstance:
          FrsPageResIdl_DataRes_ForumRuleStatus.$_createMessage)
    ..aI(4, _omitFieldNames ? '' : 'hasForumRule')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FrsPageResIdl_DataRes_ForumRuleStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FrsPageResIdl_DataRes_ForumRuleStatus copyWith(
          void Function(FrsPageResIdl_DataRes_ForumRuleStatus) updates) =>
      super.copyWith((message) =>
              updates(message as FrsPageResIdl_DataRes_ForumRuleStatus))
          as FrsPageResIdl_DataRes_ForumRuleStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use FrsPageResIdl_DataRes_ForumRuleStatus() / FrsPageResIdl_DataRes_ForumRuleStatus.new instead')
  static FrsPageResIdl_DataRes_ForumRuleStatus create() =>
      FrsPageResIdl_DataRes_ForumRuleStatus._();
  static $pb.GeneratedMessage $_createMessage() =>
      FrsPageResIdl_DataRes_ForumRuleStatus._();
  @$core.override
  FrsPageResIdl_DataRes_ForumRuleStatus createEmptyInstance() =>
      FrsPageResIdl_DataRes_ForumRuleStatus._();
  @$core.pragma('dart2js:noInline')
  static FrsPageResIdl_DataRes_ForumRuleStatus getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
              FrsPageResIdl_DataRes_ForumRuleStatus>(
          FrsPageResIdl_DataRes_ForumRuleStatus.$_createMessage);
  static FrsPageResIdl_DataRes_ForumRuleStatus? _defaultInstance;

  @$pb.TagNumber(4)
  $core.int get hasForumRule => $_getIZ(0);
  @$pb.TagNumber(4)
  set hasForumRule($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(4)
  $core.bool hasHasForumRule() => $_has(0);
  @$pb.TagNumber(4)
  void clearHasForumRule() => $_clearField(4);
}

class FrsPageResIdl_DataRes extends $pb.GeneratedMessage {
  factory FrsPageResIdl_DataRes({
    FrsPageResIdl_DataRes_ForumInfo? forum,
    $1.Page? page,
    $core.Iterable<$2.ThreadInfo>? threadList,
    $core.Iterable<$3.User>? userList,
    FrsPageResIdl_DataRes_NavTabInfo? navTabInfo,
    FrsPageResIdl_DataRes_ForumRuleStatus? forumRule,
  }) {
    final result = FrsPageResIdl_DataRes._();
    if (forum != null) result.forum = forum;
    if (page != null) result.page = page;
    if (threadList != null) result.threadList.addAll(threadList);
    if (userList != null) result.userList.addAll(userList);
    if (navTabInfo != null) result.navTabInfo = navTabInfo;
    if (forumRule != null) result.forumRule = forumRule;
    return result;
  }

  FrsPageResIdl_DataRes._();

  factory FrsPageResIdl_DataRes.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FrsPageResIdl_DataRes()..mergeFromBuffer(data, registry);
  factory FrsPageResIdl_DataRes.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FrsPageResIdl_DataRes()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FrsPageResIdl.DataRes',
      createEmptyInstance: FrsPageResIdl_DataRes.$_createMessage)
    ..aOM<FrsPageResIdl_DataRes_ForumInfo>(2, _omitFieldNames ? '' : 'forum',
        subBuilder: FrsPageResIdl_DataRes_ForumInfo.$_createMessage)
    ..aOM<$1.Page>(4, _omitFieldNames ? '' : 'page',
        subBuilder: $1.Page.$_createMessage)
    ..pPM<$2.ThreadInfo>(7, _omitFieldNames ? '' : 'threadList',
        subBuilder: $2.ThreadInfo.$_createMessage)
    ..pPM<$3.User>(17, _omitFieldNames ? '' : 'userList',
        subBuilder: $3.User.$_createMessage)
    ..aOM<FrsPageResIdl_DataRes_NavTabInfo>(
        37, _omitFieldNames ? '' : 'navTabInfo',
        subBuilder: FrsPageResIdl_DataRes_NavTabInfo.$_createMessage)
    ..aOM<FrsPageResIdl_DataRes_ForumRuleStatus>(
        105, _omitFieldNames ? '' : 'forumRule',
        subBuilder: FrsPageResIdl_DataRes_ForumRuleStatus.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FrsPageResIdl_DataRes clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FrsPageResIdl_DataRes copyWith(
          void Function(FrsPageResIdl_DataRes) updates) =>
      super.copyWith((message) => updates(message as FrsPageResIdl_DataRes))
          as FrsPageResIdl_DataRes;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use FrsPageResIdl_DataRes() / FrsPageResIdl_DataRes.new instead')
  static FrsPageResIdl_DataRes create() => FrsPageResIdl_DataRes._();
  static $pb.GeneratedMessage $_createMessage() => FrsPageResIdl_DataRes._();
  @$core.override
  FrsPageResIdl_DataRes createEmptyInstance() => FrsPageResIdl_DataRes._();
  @$core.pragma('dart2js:noInline')
  static FrsPageResIdl_DataRes getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FrsPageResIdl_DataRes>(
          FrsPageResIdl_DataRes.$_createMessage);
  static FrsPageResIdl_DataRes? _defaultInstance;

  @$pb.TagNumber(2)
  FrsPageResIdl_DataRes_ForumInfo get forum => $_getN(0);
  @$pb.TagNumber(2)
  set forum(FrsPageResIdl_DataRes_ForumInfo value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasForum() => $_has(0);
  @$pb.TagNumber(2)
  void clearForum() => $_clearField(2);
  @$pb.TagNumber(2)
  FrsPageResIdl_DataRes_ForumInfo ensureForum() => $_ensure(0);

  @$pb.TagNumber(4)
  $1.Page get page => $_getN(1);
  @$pb.TagNumber(4)
  set page($1.Page value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasPage() => $_has(1);
  @$pb.TagNumber(4)
  void clearPage() => $_clearField(4);
  @$pb.TagNumber(4)
  $1.Page ensurePage() => $_ensure(1);

  @$pb.TagNumber(7)
  $pb.PbList<$2.ThreadInfo> get threadList => $_getList(2);

  @$pb.TagNumber(17)
  $pb.PbList<$3.User> get userList => $_getList(3);

  @$pb.TagNumber(37)
  FrsPageResIdl_DataRes_NavTabInfo get navTabInfo => $_getN(4);
  @$pb.TagNumber(37)
  set navTabInfo(FrsPageResIdl_DataRes_NavTabInfo value) =>
      $_setField(37, value);
  @$pb.TagNumber(37)
  $core.bool hasNavTabInfo() => $_has(4);
  @$pb.TagNumber(37)
  void clearNavTabInfo() => $_clearField(37);
  @$pb.TagNumber(37)
  FrsPageResIdl_DataRes_NavTabInfo ensureNavTabInfo() => $_ensure(4);

  @$pb.TagNumber(105)
  FrsPageResIdl_DataRes_ForumRuleStatus get forumRule => $_getN(5);
  @$pb.TagNumber(105)
  set forumRule(FrsPageResIdl_DataRes_ForumRuleStatus value) =>
      $_setField(105, value);
  @$pb.TagNumber(105)
  $core.bool hasForumRule() => $_has(5);
  @$pb.TagNumber(105)
  void clearForumRule() => $_clearField(105);
  @$pb.TagNumber(105)
  FrsPageResIdl_DataRes_ForumRuleStatus ensureForumRule() => $_ensure(5);
}

class FrsPageResIdl extends $pb.GeneratedMessage {
  factory FrsPageResIdl({
    $0.Error? error,
    FrsPageResIdl_DataRes? data,
  }) {
    final result = FrsPageResIdl._();
    if (error != null) result.error = error;
    if (data != null) result.data = data;
    return result;
  }

  FrsPageResIdl._();

  factory FrsPageResIdl.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FrsPageResIdl()..mergeFromBuffer(data, registry);
  factory FrsPageResIdl.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FrsPageResIdl()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FrsPageResIdl',
      createEmptyInstance: FrsPageResIdl.$_createMessage)
    ..aOM<$0.Error>(1, _omitFieldNames ? '' : 'error',
        subBuilder: $0.Error.$_createMessage)
    ..aOM<FrsPageResIdl_DataRes>(2, _omitFieldNames ? '' : 'data',
        subBuilder: FrsPageResIdl_DataRes.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FrsPageResIdl clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FrsPageResIdl copyWith(void Function(FrsPageResIdl) updates) =>
      super.copyWith((message) => updates(message as FrsPageResIdl))
          as FrsPageResIdl;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use FrsPageResIdl() / FrsPageResIdl.new instead')
  static FrsPageResIdl create() => FrsPageResIdl._();
  static $pb.GeneratedMessage $_createMessage() => FrsPageResIdl._();
  @$core.override
  FrsPageResIdl createEmptyInstance() => FrsPageResIdl._();
  @$core.pragma('dart2js:noInline')
  static FrsPageResIdl getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FrsPageResIdl>(
          FrsPageResIdl.$_createMessage);
  static FrsPageResIdl? _defaultInstance;

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
  FrsPageResIdl_DataRes get data => $_getN(1);
  @$pb.TagNumber(2)
  set data(FrsPageResIdl_DataRes value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => $_clearField(2);
  @$pb.TagNumber(2)
  FrsPageResIdl_DataRes ensureData() => $_ensure(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
