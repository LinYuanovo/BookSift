// This is a generated file - do not edit.
//
// Generated from PbPageReqIdl.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'CommonReq.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class PbPageReqIdl_DataReq extends $pb.GeneratedMessage {
  factory PbPageReqIdl_DataReq({
    $fixnum.Int64? kz,
    $core.int? lz,
    $core.int? r,
    $fixnum.Int64? pid,
    $core.int? withFloor,
    $core.int? floorRn,
    $core.int? rn,
    $core.int? pn,
    $0.CommonReq? common,
    $core.int? floorSortType,
  }) {
    final result = PbPageReqIdl_DataReq._();
    if (kz != null) result.kz = kz;
    if (lz != null) result.lz = lz;
    if (r != null) result.r = r;
    if (pid != null) result.pid = pid;
    if (withFloor != null) result.withFloor = withFloor;
    if (floorRn != null) result.floorRn = floorRn;
    if (rn != null) result.rn = rn;
    if (pn != null) result.pn = pn;
    if (common != null) result.common = common;
    if (floorSortType != null) result.floorSortType = floorSortType;
    return result;
  }

  PbPageReqIdl_DataReq._();

  factory PbPageReqIdl_DataReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PbPageReqIdl_DataReq()..mergeFromBuffer(data, registry);
  factory PbPageReqIdl_DataReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PbPageReqIdl_DataReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PbPageReqIdl.DataReq',
      createEmptyInstance: PbPageReqIdl_DataReq.$_createMessage)
    ..aInt64(4, _omitFieldNames ? '' : 'kz')
    ..aI(5, _omitFieldNames ? '' : 'lz')
    ..aI(6, _omitFieldNames ? '' : 'r')
    ..aInt64(7, _omitFieldNames ? '' : 'pid')
    ..aI(8, _omitFieldNames ? '' : 'withFloor')
    ..aI(9, _omitFieldNames ? '' : 'floorRn')
    ..aI(13, _omitFieldNames ? '' : 'rn')
    ..aI(18, _omitFieldNames ? '' : 'pn')
    ..aOM<$0.CommonReq>(25, _omitFieldNames ? '' : 'common',
        subBuilder: $0.CommonReq.$_createMessage)
    ..aI(74, _omitFieldNames ? '' : 'floorSortType')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PbPageReqIdl_DataReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PbPageReqIdl_DataReq copyWith(void Function(PbPageReqIdl_DataReq) updates) =>
      super.copyWith((message) => updates(message as PbPageReqIdl_DataReq))
          as PbPageReqIdl_DataReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use PbPageReqIdl_DataReq() / PbPageReqIdl_DataReq.new instead')
  static PbPageReqIdl_DataReq create() => PbPageReqIdl_DataReq._();
  static $pb.GeneratedMessage $_createMessage() => PbPageReqIdl_DataReq._();
  @$core.override
  PbPageReqIdl_DataReq createEmptyInstance() => PbPageReqIdl_DataReq._();
  @$core.pragma('dart2js:noInline')
  static PbPageReqIdl_DataReq getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PbPageReqIdl_DataReq>(
          PbPageReqIdl_DataReq.$_createMessage);
  static PbPageReqIdl_DataReq? _defaultInstance;

  @$pb.TagNumber(4)
  $fixnum.Int64 get kz => $_getI64(0);
  @$pb.TagNumber(4)
  set kz($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(4)
  $core.bool hasKz() => $_has(0);
  @$pb.TagNumber(4)
  void clearKz() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get lz => $_getIZ(1);
  @$pb.TagNumber(5)
  set lz($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(5)
  $core.bool hasLz() => $_has(1);
  @$pb.TagNumber(5)
  void clearLz() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get r => $_getIZ(2);
  @$pb.TagNumber(6)
  set r($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(6)
  $core.bool hasR() => $_has(2);
  @$pb.TagNumber(6)
  void clearR() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get pid => $_getI64(3);
  @$pb.TagNumber(7)
  set pid($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(7)
  $core.bool hasPid() => $_has(3);
  @$pb.TagNumber(7)
  void clearPid() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get withFloor => $_getIZ(4);
  @$pb.TagNumber(8)
  set withFloor($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(8)
  $core.bool hasWithFloor() => $_has(4);
  @$pb.TagNumber(8)
  void clearWithFloor() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get floorRn => $_getIZ(5);
  @$pb.TagNumber(9)
  set floorRn($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(9)
  $core.bool hasFloorRn() => $_has(5);
  @$pb.TagNumber(9)
  void clearFloorRn() => $_clearField(9);

  @$pb.TagNumber(13)
  $core.int get rn => $_getIZ(6);
  @$pb.TagNumber(13)
  set rn($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(13)
  $core.bool hasRn() => $_has(6);
  @$pb.TagNumber(13)
  void clearRn() => $_clearField(13);

  @$pb.TagNumber(18)
  $core.int get pn => $_getIZ(7);
  @$pb.TagNumber(18)
  set pn($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(18)
  $core.bool hasPn() => $_has(7);
  @$pb.TagNumber(18)
  void clearPn() => $_clearField(18);

  @$pb.TagNumber(25)
  $0.CommonReq get common => $_getN(8);
  @$pb.TagNumber(25)
  set common($0.CommonReq value) => $_setField(25, value);
  @$pb.TagNumber(25)
  $core.bool hasCommon() => $_has(8);
  @$pb.TagNumber(25)
  void clearCommon() => $_clearField(25);
  @$pb.TagNumber(25)
  $0.CommonReq ensureCommon() => $_ensure(8);

  @$pb.TagNumber(74)
  $core.int get floorSortType => $_getIZ(9);
  @$pb.TagNumber(74)
  set floorSortType($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(74)
  $core.bool hasFloorSortType() => $_has(9);
  @$pb.TagNumber(74)
  void clearFloorSortType() => $_clearField(74);
}

class PbPageReqIdl extends $pb.GeneratedMessage {
  factory PbPageReqIdl({
    PbPageReqIdl_DataReq? data,
  }) {
    final result = PbPageReqIdl._();
    if (data != null) result.data = data;
    return result;
  }

  PbPageReqIdl._();

  factory PbPageReqIdl.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PbPageReqIdl()..mergeFromBuffer(data, registry);
  factory PbPageReqIdl.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PbPageReqIdl()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PbPageReqIdl',
      createEmptyInstance: PbPageReqIdl.$_createMessage)
    ..aOM<PbPageReqIdl_DataReq>(1, _omitFieldNames ? '' : 'data',
        subBuilder: PbPageReqIdl_DataReq.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PbPageReqIdl clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PbPageReqIdl copyWith(void Function(PbPageReqIdl) updates) =>
      super.copyWith((message) => updates(message as PbPageReqIdl))
          as PbPageReqIdl;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PbPageReqIdl() / PbPageReqIdl.new instead')
  static PbPageReqIdl create() => PbPageReqIdl._();
  static $pb.GeneratedMessage $_createMessage() => PbPageReqIdl._();
  @$core.override
  PbPageReqIdl createEmptyInstance() => PbPageReqIdl._();
  @$core.pragma('dart2js:noInline')
  static PbPageReqIdl getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PbPageReqIdl>(
          PbPageReqIdl.$_createMessage);
  static PbPageReqIdl? _defaultInstance;

  @$pb.TagNumber(1)
  PbPageReqIdl_DataReq get data => $_getN(0);
  @$pb.TagNumber(1)
  set data(PbPageReqIdl_DataReq value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasData() => $_has(0);
  @$pb.TagNumber(1)
  void clearData() => $_clearField(1);
  @$pb.TagNumber(1)
  PbPageReqIdl_DataReq ensureData() => $_ensure(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
