// This is a generated file - do not edit.
//
// Generated from PollInfo.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class PollInfo_PollOption extends $pb.GeneratedMessage {
  factory PollInfo_PollOption({
    $fixnum.Int64? num,
    $core.String? text,
  }) {
    final result = PollInfo_PollOption._();
    if (num != null) result.num = num;
    if (text != null) result.text = text;
    return result;
  }

  PollInfo_PollOption._();

  factory PollInfo_PollOption.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PollInfo_PollOption()..mergeFromBuffer(data, registry);
  factory PollInfo_PollOption.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PollInfo_PollOption()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PollInfo.PollOption',
      createEmptyInstance: PollInfo_PollOption.$_createMessage)
    ..aInt64(2, _omitFieldNames ? '' : 'num')
    ..aOS(3, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PollInfo_PollOption clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PollInfo_PollOption copyWith(void Function(PollInfo_PollOption) updates) =>
      super.copyWith((message) => updates(message as PollInfo_PollOption))
          as PollInfo_PollOption;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use PollInfo_PollOption() / PollInfo_PollOption.new instead')
  static PollInfo_PollOption create() => PollInfo_PollOption._();
  static $pb.GeneratedMessage $_createMessage() => PollInfo_PollOption._();
  @$core.override
  PollInfo_PollOption createEmptyInstance() => PollInfo_PollOption._();
  @$core.pragma('dart2js:noInline')
  static PollInfo_PollOption getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PollInfo_PollOption>(
          PollInfo_PollOption.$_createMessage);
  static PollInfo_PollOption? _defaultInstance;

  @$pb.TagNumber(2)
  $fixnum.Int64 get num => $_getI64(0);
  @$pb.TagNumber(2)
  set num($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(2)
  $core.bool hasNum() => $_has(0);
  @$pb.TagNumber(2)
  void clearNum() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get text => $_getSZ(1);
  @$pb.TagNumber(3)
  set text($core.String value) => $_setString(1, value);
  @$pb.TagNumber(3)
  $core.bool hasText() => $_has(1);
  @$pb.TagNumber(3)
  void clearText() => $_clearField(3);
}

class PollInfo extends $pb.GeneratedMessage {
  factory PollInfo({
    $core.int? isMulti,
    $fixnum.Int64? totalNum,
    $core.Iterable<PollInfo_PollOption>? options,
    $fixnum.Int64? totalPoll,
    $core.String? title,
  }) {
    final result = PollInfo._();
    if (isMulti != null) result.isMulti = isMulti;
    if (totalNum != null) result.totalNum = totalNum;
    if (options != null) result.options.addAll(options);
    if (totalPoll != null) result.totalPoll = totalPoll;
    if (title != null) result.title = title;
    return result;
  }

  PollInfo._();

  factory PollInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PollInfo()..mergeFromBuffer(data, registry);
  factory PollInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PollInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PollInfo',
      createEmptyInstance: PollInfo.$_createMessage)
    ..aI(2, _omitFieldNames ? '' : 'isMulti')
    ..aInt64(3, _omitFieldNames ? '' : 'totalNum')
    ..pPM<PollInfo_PollOption>(9, _omitFieldNames ? '' : 'options',
        subBuilder: PollInfo_PollOption.$_createMessage)
    ..aInt64(11, _omitFieldNames ? '' : 'totalPoll')
    ..aOS(12, _omitFieldNames ? '' : 'title')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PollInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PollInfo copyWith(void Function(PollInfo) updates) =>
      super.copyWith((message) => updates(message as PollInfo)) as PollInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PollInfo() / PollInfo.new instead')
  static PollInfo create() => PollInfo._();
  static $pb.GeneratedMessage $_createMessage() => PollInfo._();
  @$core.override
  PollInfo createEmptyInstance() => PollInfo._();
  @$core.pragma('dart2js:noInline')
  static PollInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PollInfo>(PollInfo.$_createMessage);
  static PollInfo? _defaultInstance;

  @$pb.TagNumber(2)
  $core.int get isMulti => $_getIZ(0);
  @$pb.TagNumber(2)
  set isMulti($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(2)
  $core.bool hasIsMulti() => $_has(0);
  @$pb.TagNumber(2)
  void clearIsMulti() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get totalNum => $_getI64(1);
  @$pb.TagNumber(3)
  set totalNum($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(3)
  $core.bool hasTotalNum() => $_has(1);
  @$pb.TagNumber(3)
  void clearTotalNum() => $_clearField(3);

  @$pb.TagNumber(9)
  $pb.PbList<PollInfo_PollOption> get options => $_getList(2);

  @$pb.TagNumber(11)
  $fixnum.Int64 get totalPoll => $_getI64(3);
  @$pb.TagNumber(11)
  set totalPoll($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(11)
  $core.bool hasTotalPoll() => $_has(3);
  @$pb.TagNumber(11)
  void clearTotalPoll() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get title => $_getSZ(4);
  @$pb.TagNumber(12)
  set title($core.String value) => $_setString(4, value);
  @$pb.TagNumber(12)
  $core.bool hasTitle() => $_has(4);
  @$pb.TagNumber(12)
  void clearTitle() => $_clearField(12);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
