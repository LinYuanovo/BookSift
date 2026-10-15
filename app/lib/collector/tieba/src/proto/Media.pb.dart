// This is a generated file - do not edit.
//
// Generated from Media.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class Media extends $pb.GeneratedMessage {
  factory Media({
    $core.int? type,
    $core.String? smallPic,
    $core.String? bigPic,
    $core.String? waterPic,
    $core.int? width,
    $core.int? height,
    $core.String? originPic,
    $core.int? originSize,
  }) {
    final result = Media._();
    if (type != null) result.type = type;
    if (smallPic != null) result.smallPic = smallPic;
    if (bigPic != null) result.bigPic = bigPic;
    if (waterPic != null) result.waterPic = waterPic;
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    if (originPic != null) result.originPic = originPic;
    if (originSize != null) result.originSize = originSize;
    return result;
  }

  Media._();

  factory Media.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Media()..mergeFromBuffer(data, registry);
  factory Media.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Media()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Media',
      createEmptyInstance: Media.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'type')
    ..aOS(2, _omitFieldNames ? '' : 'smallPic')
    ..aOS(3, _omitFieldNames ? '' : 'bigPic')
    ..aOS(4, _omitFieldNames ? '' : 'waterPic')
    ..aI(10, _omitFieldNames ? '' : 'width', fieldType: $pb.PbFieldType.OU3)
    ..aI(11, _omitFieldNames ? '' : 'height', fieldType: $pb.PbFieldType.OU3)
    ..aOS(15, _omitFieldNames ? '' : 'originPic')
    ..aI(16, _omitFieldNames ? '' : 'originSize',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Media clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Media copyWith(void Function(Media) updates) =>
      super.copyWith((message) => updates(message as Media)) as Media;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Media() / Media.new instead')
  static Media create() => Media._();
  static $pb.GeneratedMessage $_createMessage() => Media._();
  @$core.override
  Media createEmptyInstance() => Media._();
  @$core.pragma('dart2js:noInline')
  static Media getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Media>(Media.$_createMessage);
  static Media? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get type => $_getIZ(0);
  @$pb.TagNumber(1)
  set type($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get smallPic => $_getSZ(1);
  @$pb.TagNumber(2)
  set smallPic($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSmallPic() => $_has(1);
  @$pb.TagNumber(2)
  void clearSmallPic() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get bigPic => $_getSZ(2);
  @$pb.TagNumber(3)
  set bigPic($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBigPic() => $_has(2);
  @$pb.TagNumber(3)
  void clearBigPic() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get waterPic => $_getSZ(3);
  @$pb.TagNumber(4)
  set waterPic($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasWaterPic() => $_has(3);
  @$pb.TagNumber(4)
  void clearWaterPic() => $_clearField(4);

  @$pb.TagNumber(10)
  $core.int get width => $_getIZ(4);
  @$pb.TagNumber(10)
  set width($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(10)
  $core.bool hasWidth() => $_has(4);
  @$pb.TagNumber(10)
  void clearWidth() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get height => $_getIZ(5);
  @$pb.TagNumber(11)
  set height($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(11)
  $core.bool hasHeight() => $_has(5);
  @$pb.TagNumber(11)
  void clearHeight() => $_clearField(11);

  @$pb.TagNumber(15)
  $core.String get originPic => $_getSZ(6);
  @$pb.TagNumber(15)
  set originPic($core.String value) => $_setString(6, value);
  @$pb.TagNumber(15)
  $core.bool hasOriginPic() => $_has(6);
  @$pb.TagNumber(15)
  void clearOriginPic() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.int get originSize => $_getIZ(7);
  @$pb.TagNumber(16)
  set originSize($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(16)
  $core.bool hasOriginSize() => $_has(7);
  @$pb.TagNumber(16)
  void clearOriginSize() => $_clearField(16);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
