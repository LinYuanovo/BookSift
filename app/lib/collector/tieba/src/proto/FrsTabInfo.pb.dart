// This is a generated file - do not edit.
//
// Generated from FrsTabInfo.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class FrsTabInfo extends $pb.GeneratedMessage {
  factory FrsTabInfo({
    $core.int? tabId,
    $core.String? tabName,
  }) {
    final result = FrsTabInfo._();
    if (tabId != null) result.tabId = tabId;
    if (tabName != null) result.tabName = tabName;
    return result;
  }

  FrsTabInfo._();

  factory FrsTabInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FrsTabInfo()..mergeFromBuffer(data, registry);
  factory FrsTabInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FrsTabInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FrsTabInfo',
      createEmptyInstance: FrsTabInfo.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'tabId')
    ..aOS(3, _omitFieldNames ? '' : 'tabName')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FrsTabInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FrsTabInfo copyWith(void Function(FrsTabInfo) updates) =>
      super.copyWith((message) => updates(message as FrsTabInfo)) as FrsTabInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use FrsTabInfo() / FrsTabInfo.new instead')
  static FrsTabInfo create() => FrsTabInfo._();
  static $pb.GeneratedMessage $_createMessage() => FrsTabInfo._();
  @$core.override
  FrsTabInfo createEmptyInstance() => FrsTabInfo._();
  @$core.pragma('dart2js:noInline')
  static FrsTabInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FrsTabInfo>(FrsTabInfo.$_createMessage);
  static FrsTabInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get tabId => $_getIZ(0);
  @$pb.TagNumber(1)
  set tabId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTabId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTabId() => $_clearField(1);

  @$pb.TagNumber(3)
  $core.String get tabName => $_getSZ(1);
  @$pb.TagNumber(3)
  set tabName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(3)
  $core.bool hasTabName() => $_has(1);
  @$pb.TagNumber(3)
  void clearTabName() => $_clearField(3);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
