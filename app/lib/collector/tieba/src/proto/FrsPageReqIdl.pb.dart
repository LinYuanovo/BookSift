// This is a generated file - do not edit.
//
// Generated from FrsPageReqIdl.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'CommonReq.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class FrsPageReqIdl_DataReq extends $pb.GeneratedMessage {
  factory FrsPageReqIdl_DataReq({
    $core.String? kw,
    $core.int? rn,
    $core.int? rnNeed,
    $core.int? isGood,
    $core.int? cid,
    $core.int? pn,
    $0.CommonReq? common,
    $core.int? sortType,
  }) {
    final result = FrsPageReqIdl_DataReq._();
    if (kw != null) result.kw = kw;
    if (rn != null) result.rn = rn;
    if (rnNeed != null) result.rnNeed = rnNeed;
    if (isGood != null) result.isGood = isGood;
    if (cid != null) result.cid = cid;
    if (pn != null) result.pn = pn;
    if (common != null) result.common = common;
    if (sortType != null) result.sortType = sortType;
    return result;
  }

  FrsPageReqIdl_DataReq._();

  factory FrsPageReqIdl_DataReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FrsPageReqIdl_DataReq()..mergeFromBuffer(data, registry);
  factory FrsPageReqIdl_DataReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FrsPageReqIdl_DataReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FrsPageReqIdl.DataReq',
      createEmptyInstance: FrsPageReqIdl_DataReq.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'kw')
    ..aI(2, _omitFieldNames ? '' : 'rn')
    ..aI(3, _omitFieldNames ? '' : 'rnNeed')
    ..aI(4, _omitFieldNames ? '' : 'isGood')
    ..aI(5, _omitFieldNames ? '' : 'cid')
    ..aI(15, _omitFieldNames ? '' : 'pn')
    ..aOM<$0.CommonReq>(39, _omitFieldNames ? '' : 'common',
        subBuilder: $0.CommonReq.$_createMessage)
    ..aI(47, _omitFieldNames ? '' : 'sortType')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FrsPageReqIdl_DataReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FrsPageReqIdl_DataReq copyWith(
          void Function(FrsPageReqIdl_DataReq) updates) =>
      super.copyWith((message) => updates(message as FrsPageReqIdl_DataReq))
          as FrsPageReqIdl_DataReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use FrsPageReqIdl_DataReq() / FrsPageReqIdl_DataReq.new instead')
  static FrsPageReqIdl_DataReq create() => FrsPageReqIdl_DataReq._();
  static $pb.GeneratedMessage $_createMessage() => FrsPageReqIdl_DataReq._();
  @$core.override
  FrsPageReqIdl_DataReq createEmptyInstance() => FrsPageReqIdl_DataReq._();
  @$core.pragma('dart2js:noInline')
  static FrsPageReqIdl_DataReq getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FrsPageReqIdl_DataReq>(
          FrsPageReqIdl_DataReq.$_createMessage);
  static FrsPageReqIdl_DataReq? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get kw => $_getSZ(0);
  @$pb.TagNumber(1)
  set kw($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKw() => $_has(0);
  @$pb.TagNumber(1)
  void clearKw() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get rn => $_getIZ(1);
  @$pb.TagNumber(2)
  set rn($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRn() => $_has(1);
  @$pb.TagNumber(2)
  void clearRn() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get rnNeed => $_getIZ(2);
  @$pb.TagNumber(3)
  set rnNeed($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRnNeed() => $_has(2);
  @$pb.TagNumber(3)
  void clearRnNeed() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get isGood => $_getIZ(3);
  @$pb.TagNumber(4)
  set isGood($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIsGood() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsGood() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get cid => $_getIZ(4);
  @$pb.TagNumber(5)
  set cid($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCid() => $_has(4);
  @$pb.TagNumber(5)
  void clearCid() => $_clearField(5);

  @$pb.TagNumber(15)
  $core.int get pn => $_getIZ(5);
  @$pb.TagNumber(15)
  set pn($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(15)
  $core.bool hasPn() => $_has(5);
  @$pb.TagNumber(15)
  void clearPn() => $_clearField(15);

  @$pb.TagNumber(39)
  $0.CommonReq get common => $_getN(6);
  @$pb.TagNumber(39)
  set common($0.CommonReq value) => $_setField(39, value);
  @$pb.TagNumber(39)
  $core.bool hasCommon() => $_has(6);
  @$pb.TagNumber(39)
  void clearCommon() => $_clearField(39);
  @$pb.TagNumber(39)
  $0.CommonReq ensureCommon() => $_ensure(6);

  @$pb.TagNumber(47)
  $core.int get sortType => $_getIZ(7);
  @$pb.TagNumber(47)
  set sortType($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(47)
  $core.bool hasSortType() => $_has(7);
  @$pb.TagNumber(47)
  void clearSortType() => $_clearField(47);
}

class FrsPageReqIdl extends $pb.GeneratedMessage {
  factory FrsPageReqIdl({
    FrsPageReqIdl_DataReq? data,
  }) {
    final result = FrsPageReqIdl._();
    if (data != null) result.data = data;
    return result;
  }

  FrsPageReqIdl._();

  factory FrsPageReqIdl.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FrsPageReqIdl()..mergeFromBuffer(data, registry);
  factory FrsPageReqIdl.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FrsPageReqIdl()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FrsPageReqIdl',
      createEmptyInstance: FrsPageReqIdl.$_createMessage)
    ..aOM<FrsPageReqIdl_DataReq>(1, _omitFieldNames ? '' : 'data',
        subBuilder: FrsPageReqIdl_DataReq.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FrsPageReqIdl clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FrsPageReqIdl copyWith(void Function(FrsPageReqIdl) updates) =>
      super.copyWith((message) => updates(message as FrsPageReqIdl))
          as FrsPageReqIdl;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use FrsPageReqIdl() / FrsPageReqIdl.new instead')
  static FrsPageReqIdl create() => FrsPageReqIdl._();
  static $pb.GeneratedMessage $_createMessage() => FrsPageReqIdl._();
  @$core.override
  FrsPageReqIdl createEmptyInstance() => FrsPageReqIdl._();
  @$core.pragma('dart2js:noInline')
  static FrsPageReqIdl getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FrsPageReqIdl>(
          FrsPageReqIdl.$_createMessage);
  static FrsPageReqIdl? _defaultInstance;

  @$pb.TagNumber(1)
  FrsPageReqIdl_DataReq get data => $_getN(0);
  @$pb.TagNumber(1)
  set data(FrsPageReqIdl_DataReq value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasData() => $_has(0);
  @$pb.TagNumber(1)
  void clearData() => $_clearField(1);
  @$pb.TagNumber(1)
  FrsPageReqIdl_DataReq ensureData() => $_ensure(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
