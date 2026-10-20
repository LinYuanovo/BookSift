// This is a generated file - do not edit.
//
// Generated from Agree.proto.

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

class Agree extends $pb.GeneratedMessage {
  factory Agree({
    $fixnum.Int64? agreeNum,
    $fixnum.Int64? disagreeNum,
  }) {
    final result = Agree._();
    if (agreeNum != null) result.agreeNum = agreeNum;
    if (disagreeNum != null) result.disagreeNum = disagreeNum;
    return result;
  }

  Agree._();

  factory Agree.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Agree()..mergeFromBuffer(data, registry);
  factory Agree.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Agree()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Agree',
      createEmptyInstance: Agree.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'agreeNum')
    ..aInt64(4, _omitFieldNames ? '' : 'disagreeNum')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Agree clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Agree copyWith(void Function(Agree) updates) =>
      super.copyWith((message) => updates(message as Agree)) as Agree;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Agree() / Agree.new instead')
  static Agree create() => Agree._();
  static $pb.GeneratedMessage $_createMessage() => Agree._();
  @$core.override
  Agree createEmptyInstance() => Agree._();
  @$core.pragma('dart2js:noInline')
  static Agree getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Agree>(Agree.$_createMessage);
  static Agree? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get agreeNum => $_getI64(0);
  @$pb.TagNumber(1)
  set agreeNum($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAgreeNum() => $_has(0);
  @$pb.TagNumber(1)
  void clearAgreeNum() => $_clearField(1);

  @$pb.TagNumber(4)
  $fixnum.Int64 get disagreeNum => $_getI64(1);
  @$pb.TagNumber(4)
  set disagreeNum($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(4)
  $core.bool hasDisagreeNum() => $_has(1);
  @$pb.TagNumber(4)
  void clearDisagreeNum() => $_clearField(4);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
