// This is a generated file - do not edit.
//
// Generated from Voice.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class Voice extends $pb.GeneratedMessage {
  factory Voice({
    $core.int? duringTime,
    $core.String? voiceMd5,
  }) {
    final result = Voice._();
    if (duringTime != null) result.duringTime = duringTime;
    if (voiceMd5 != null) result.voiceMd5 = voiceMd5;
    return result;
  }

  Voice._();

  factory Voice.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Voice()..mergeFromBuffer(data, registry);
  factory Voice.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Voice()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Voice',
      createEmptyInstance: Voice.$_createMessage)
    ..aI(2, _omitFieldNames ? '' : 'duringTime')
    ..aOS(3, _omitFieldNames ? '' : 'voiceMd5')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Voice clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Voice copyWith(void Function(Voice) updates) =>
      super.copyWith((message) => updates(message as Voice)) as Voice;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Voice() / Voice.new instead')
  static Voice create() => Voice._();
  static $pb.GeneratedMessage $_createMessage() => Voice._();
  @$core.override
  Voice createEmptyInstance() => Voice._();
  @$core.pragma('dart2js:noInline')
  static Voice getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Voice>(Voice.$_createMessage);
  static Voice? _defaultInstance;

  @$pb.TagNumber(2)
  $core.int get duringTime => $_getIZ(0);
  @$pb.TagNumber(2)
  set duringTime($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(2)
  $core.bool hasDuringTime() => $_has(0);
  @$pb.TagNumber(2)
  void clearDuringTime() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get voiceMd5 => $_getSZ(1);
  @$pb.TagNumber(3)
  set voiceMd5($core.String value) => $_setString(1, value);
  @$pb.TagNumber(3)
  $core.bool hasVoiceMd5() => $_has(1);
  @$pb.TagNumber(3)
  void clearVoiceMd5() => $_clearField(3);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
