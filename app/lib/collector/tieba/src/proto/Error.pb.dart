// This is a generated file - do not edit.
//
// Generated from Error.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class Error extends $pb.GeneratedMessage {
  factory Error({
    $core.int? errorno,
    $core.String? errmsg,
  }) {
    final result = Error._();
    if (errorno != null) result.errorno = errorno;
    if (errmsg != null) result.errmsg = errmsg;
    return result;
  }

  Error._();

  factory Error.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Error()..mergeFromBuffer(data, registry);
  factory Error.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Error()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Error',
      createEmptyInstance: Error.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'errorno')
    ..aOS(2, _omitFieldNames ? '' : 'errmsg')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Error clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Error copyWith(void Function(Error) updates) =>
      super.copyWith((message) => updates(message as Error)) as Error;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Error() / Error.new instead')
  static Error create() => Error._();
  static $pb.GeneratedMessage $_createMessage() => Error._();
  @$core.override
  Error createEmptyInstance() => Error._();
  @$core.pragma('dart2js:noInline')
  static Error getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Error>(Error.$_createMessage);
  static Error? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get errorno => $_getIZ(0);
  @$pb.TagNumber(1)
  set errorno($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasErrorno() => $_has(0);
  @$pb.TagNumber(1)
  void clearErrorno() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get errmsg => $_getSZ(1);
  @$pb.TagNumber(2)
  set errmsg($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasErrmsg() => $_has(1);
  @$pb.TagNumber(2)
  void clearErrmsg() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
