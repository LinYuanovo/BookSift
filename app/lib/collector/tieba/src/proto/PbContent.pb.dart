// This is a generated file - do not edit.
//
// Generated from PbContent.proto.

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

class PbContent_TiebaPlusInfo extends $pb.GeneratedMessage {
  factory PbContent_TiebaPlusInfo({
    $core.String? title,
    $core.String? desc,
    $core.String? jumpUrl,
    $core.String? appIcon,
    $core.int? targetType,
    $core.int? h5JumpType,
    $core.String? h5JumpNumber,
    $core.String? h5JumpParam,
    $core.int? jumpType,
    $core.String? buttonDesc,
  }) {
    final result = PbContent_TiebaPlusInfo._();
    if (title != null) result.title = title;
    if (desc != null) result.desc = desc;
    if (jumpUrl != null) result.jumpUrl = jumpUrl;
    if (appIcon != null) result.appIcon = appIcon;
    if (targetType != null) result.targetType = targetType;
    if (h5JumpType != null) result.h5JumpType = h5JumpType;
    if (h5JumpNumber != null) result.h5JumpNumber = h5JumpNumber;
    if (h5JumpParam != null) result.h5JumpParam = h5JumpParam;
    if (jumpType != null) result.jumpType = jumpType;
    if (buttonDesc != null) result.buttonDesc = buttonDesc;
    return result;
  }

  PbContent_TiebaPlusInfo._();

  factory PbContent_TiebaPlusInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PbContent_TiebaPlusInfo()..mergeFromBuffer(data, registry);
  factory PbContent_TiebaPlusInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PbContent_TiebaPlusInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PbContent.TiebaPlusInfo',
      createEmptyInstance: PbContent_TiebaPlusInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'title')
    ..aOS(2, _omitFieldNames ? '' : 'desc')
    ..aOS(3, _omitFieldNames ? '' : 'jumpUrl')
    ..aOS(6, _omitFieldNames ? '' : 'appIcon')
    ..aI(12, _omitFieldNames ? '' : 'targetType')
    ..aI(13, _omitFieldNames ? '' : 'h5JumpType')
    ..aOS(14, _omitFieldNames ? '' : 'h5JumpNumber')
    ..aOS(15, _omitFieldNames ? '' : 'h5JumpParam')
    ..aI(16, _omitFieldNames ? '' : 'jumpType')
    ..aOS(23, _omitFieldNames ? '' : 'buttonDesc')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PbContent_TiebaPlusInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PbContent_TiebaPlusInfo copyWith(
          void Function(PbContent_TiebaPlusInfo) updates) =>
      super.copyWith((message) => updates(message as PbContent_TiebaPlusInfo))
          as PbContent_TiebaPlusInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use PbContent_TiebaPlusInfo() / PbContent_TiebaPlusInfo.new instead')
  static PbContent_TiebaPlusInfo create() => PbContent_TiebaPlusInfo._();
  static $pb.GeneratedMessage $_createMessage() => PbContent_TiebaPlusInfo._();
  @$core.override
  PbContent_TiebaPlusInfo createEmptyInstance() => PbContent_TiebaPlusInfo._();
  @$core.pragma('dart2js:noInline')
  static PbContent_TiebaPlusInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PbContent_TiebaPlusInfo>(
          PbContent_TiebaPlusInfo.$_createMessage);
  static PbContent_TiebaPlusInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get title => $_getSZ(0);
  @$pb.TagNumber(1)
  set title($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearTitle() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get desc => $_getSZ(1);
  @$pb.TagNumber(2)
  set desc($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDesc() => $_has(1);
  @$pb.TagNumber(2)
  void clearDesc() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get jumpUrl => $_getSZ(2);
  @$pb.TagNumber(3)
  set jumpUrl($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasJumpUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearJumpUrl() => $_clearField(3);

  @$pb.TagNumber(6)
  $core.String get appIcon => $_getSZ(3);
  @$pb.TagNumber(6)
  set appIcon($core.String value) => $_setString(3, value);
  @$pb.TagNumber(6)
  $core.bool hasAppIcon() => $_has(3);
  @$pb.TagNumber(6)
  void clearAppIcon() => $_clearField(6);

  @$pb.TagNumber(12)
  $core.int get targetType => $_getIZ(4);
  @$pb.TagNumber(12)
  set targetType($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(12)
  $core.bool hasTargetType() => $_has(4);
  @$pb.TagNumber(12)
  void clearTargetType() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.int get h5JumpType => $_getIZ(5);
  @$pb.TagNumber(13)
  set h5JumpType($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(13)
  $core.bool hasH5JumpType() => $_has(5);
  @$pb.TagNumber(13)
  void clearH5JumpType() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.String get h5JumpNumber => $_getSZ(6);
  @$pb.TagNumber(14)
  set h5JumpNumber($core.String value) => $_setString(6, value);
  @$pb.TagNumber(14)
  $core.bool hasH5JumpNumber() => $_has(6);
  @$pb.TagNumber(14)
  void clearH5JumpNumber() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.String get h5JumpParam => $_getSZ(7);
  @$pb.TagNumber(15)
  set h5JumpParam($core.String value) => $_setString(7, value);
  @$pb.TagNumber(15)
  $core.bool hasH5JumpParam() => $_has(7);
  @$pb.TagNumber(15)
  void clearH5JumpParam() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.int get jumpType => $_getIZ(8);
  @$pb.TagNumber(16)
  set jumpType($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(16)
  $core.bool hasJumpType() => $_has(8);
  @$pb.TagNumber(16)
  void clearJumpType() => $_clearField(16);

  @$pb.TagNumber(23)
  $core.String get buttonDesc => $_getSZ(9);
  @$pb.TagNumber(23)
  set buttonDesc($core.String value) => $_setString(9, value);
  @$pb.TagNumber(23)
  $core.bool hasButtonDesc() => $_has(9);
  @$pb.TagNumber(23)
  void clearButtonDesc() => $_clearField(23);
}

class PbContent_Item extends $pb.GeneratedMessage {
  factory PbContent_Item({
    $core.String? itemName,
  }) {
    final result = PbContent_Item._();
    if (itemName != null) result.itemName = itemName;
    return result;
  }

  PbContent_Item._();

  factory PbContent_Item.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PbContent_Item()..mergeFromBuffer(data, registry);
  factory PbContent_Item.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PbContent_Item()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PbContent.Item',
      createEmptyInstance: PbContent_Item.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'itemName')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PbContent_Item clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PbContent_Item copyWith(void Function(PbContent_Item) updates) =>
      super.copyWith((message) => updates(message as PbContent_Item))
          as PbContent_Item;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PbContent_Item() / PbContent_Item.new instead')
  static PbContent_Item create() => PbContent_Item._();
  static $pb.GeneratedMessage $_createMessage() => PbContent_Item._();
  @$core.override
  PbContent_Item createEmptyInstance() => PbContent_Item._();
  @$core.pragma('dart2js:noInline')
  static PbContent_Item getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PbContent_Item>(
          PbContent_Item.$_createMessage);
  static PbContent_Item? _defaultInstance;

  @$pb.TagNumber(2)
  $core.String get itemName => $_getSZ(0);
  @$pb.TagNumber(2)
  set itemName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(2)
  $core.bool hasItemName() => $_has(0);
  @$pb.TagNumber(2)
  void clearItemName() => $_clearField(2);
}

class PbContent extends $pb.GeneratedMessage {
  factory PbContent({
    $core.int? type,
    $core.String? text,
    $core.String? link,
    $core.String? src,
    $core.String? bsize,
    $core.String? cdnSrc,
    $core.String? bigCdnSrc,
    $core.String? c,
    $core.String? voiceMd5,
    $core.int? duringTime,
    $fixnum.Int64? uid,
    $core.int? width,
    $core.int? height,
    $core.String? originSrc,
    $core.int? originSize,
    $core.int? count,
    PbContent_TiebaPlusInfo? tiebaplusInfo,
    PbContent_Item? item,
    $core.String? portrait,
  }) {
    final result = PbContent._();
    if (type != null) result.type = type;
    if (text != null) result.text = text;
    if (link != null) result.link = link;
    if (src != null) result.src = src;
    if (bsize != null) result.bsize = bsize;
    if (cdnSrc != null) result.cdnSrc = cdnSrc;
    if (bigCdnSrc != null) result.bigCdnSrc = bigCdnSrc;
    if (c != null) result.c = c;
    if (voiceMd5 != null) result.voiceMd5 = voiceMd5;
    if (duringTime != null) result.duringTime = duringTime;
    if (uid != null) result.uid = uid;
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    if (originSrc != null) result.originSrc = originSrc;
    if (originSize != null) result.originSize = originSize;
    if (count != null) result.count = count;
    if (tiebaplusInfo != null) result.tiebaplusInfo = tiebaplusInfo;
    if (item != null) result.item = item;
    if (portrait != null) result.portrait = portrait;
    return result;
  }

  PbContent._();

  factory PbContent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PbContent()..mergeFromBuffer(data, registry);
  factory PbContent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PbContent()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PbContent',
      createEmptyInstance: PbContent.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'type', fieldType: $pb.PbFieldType.OU3)
    ..aOS(2, _omitFieldNames ? '' : 'text')
    ..aOS(3, _omitFieldNames ? '' : 'link')
    ..aOS(4, _omitFieldNames ? '' : 'src')
    ..aOS(5, _omitFieldNames ? '' : 'bsize')
    ..aOS(8, _omitFieldNames ? '' : 'cdnSrc')
    ..aOS(9, _omitFieldNames ? '' : 'bigCdnSrc')
    ..aOS(11, _omitFieldNames ? '' : 'c')
    ..aOS(12, _omitFieldNames ? '' : 'voiceMd5')
    ..aI(13, _omitFieldNames ? '' : 'duringTime',
        fieldType: $pb.PbFieldType.OU3)
    ..aInt64(15, _omitFieldNames ? '' : 'uid')
    ..aI(18, _omitFieldNames ? '' : 'width', fieldType: $pb.PbFieldType.OU3)
    ..aI(19, _omitFieldNames ? '' : 'height', fieldType: $pb.PbFieldType.OU3)
    ..aOS(25, _omitFieldNames ? '' : 'originSrc')
    ..aI(27, _omitFieldNames ? '' : 'originSize',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(28, _omitFieldNames ? '' : 'count')
    ..aOM<PbContent_TiebaPlusInfo>(40, _omitFieldNames ? '' : 'tiebaplusInfo',
        subBuilder: PbContent_TiebaPlusInfo.$_createMessage)
    ..aOM<PbContent_Item>(41, _omitFieldNames ? '' : 'item',
        subBuilder: PbContent_Item.$_createMessage)
    ..aOS(49, _omitFieldNames ? '' : 'portrait')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PbContent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PbContent copyWith(void Function(PbContent) updates) =>
      super.copyWith((message) => updates(message as PbContent)) as PbContent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PbContent() / PbContent.new instead')
  static PbContent create() => PbContent._();
  static $pb.GeneratedMessage $_createMessage() => PbContent._();
  @$core.override
  PbContent createEmptyInstance() => PbContent._();
  @$core.pragma('dart2js:noInline')
  static PbContent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PbContent>(PbContent.$_createMessage);
  static PbContent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get type => $_getIZ(0);
  @$pb.TagNumber(1)
  set type($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get text => $_getSZ(1);
  @$pb.TagNumber(2)
  set text($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasText() => $_has(1);
  @$pb.TagNumber(2)
  void clearText() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get link => $_getSZ(2);
  @$pb.TagNumber(3)
  set link($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLink() => $_has(2);
  @$pb.TagNumber(3)
  void clearLink() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get src => $_getSZ(3);
  @$pb.TagNumber(4)
  set src($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSrc() => $_has(3);
  @$pb.TagNumber(4)
  void clearSrc() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get bsize => $_getSZ(4);
  @$pb.TagNumber(5)
  set bsize($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBsize() => $_has(4);
  @$pb.TagNumber(5)
  void clearBsize() => $_clearField(5);

  @$pb.TagNumber(8)
  $core.String get cdnSrc => $_getSZ(5);
  @$pb.TagNumber(8)
  set cdnSrc($core.String value) => $_setString(5, value);
  @$pb.TagNumber(8)
  $core.bool hasCdnSrc() => $_has(5);
  @$pb.TagNumber(8)
  void clearCdnSrc() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get bigCdnSrc => $_getSZ(6);
  @$pb.TagNumber(9)
  set bigCdnSrc($core.String value) => $_setString(6, value);
  @$pb.TagNumber(9)
  $core.bool hasBigCdnSrc() => $_has(6);
  @$pb.TagNumber(9)
  void clearBigCdnSrc() => $_clearField(9);

  @$pb.TagNumber(11)
  $core.String get c => $_getSZ(7);
  @$pb.TagNumber(11)
  set c($core.String value) => $_setString(7, value);
  @$pb.TagNumber(11)
  $core.bool hasC() => $_has(7);
  @$pb.TagNumber(11)
  void clearC() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get voiceMd5 => $_getSZ(8);
  @$pb.TagNumber(12)
  set voiceMd5($core.String value) => $_setString(8, value);
  @$pb.TagNumber(12)
  $core.bool hasVoiceMd5() => $_has(8);
  @$pb.TagNumber(12)
  void clearVoiceMd5() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.int get duringTime => $_getIZ(9);
  @$pb.TagNumber(13)
  set duringTime($core.int value) => $_setUnsignedInt32(9, value);
  @$pb.TagNumber(13)
  $core.bool hasDuringTime() => $_has(9);
  @$pb.TagNumber(13)
  void clearDuringTime() => $_clearField(13);

  @$pb.TagNumber(15)
  $fixnum.Int64 get uid => $_getI64(10);
  @$pb.TagNumber(15)
  set uid($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(15)
  $core.bool hasUid() => $_has(10);
  @$pb.TagNumber(15)
  void clearUid() => $_clearField(15);

  @$pb.TagNumber(18)
  $core.int get width => $_getIZ(11);
  @$pb.TagNumber(18)
  set width($core.int value) => $_setUnsignedInt32(11, value);
  @$pb.TagNumber(18)
  $core.bool hasWidth() => $_has(11);
  @$pb.TagNumber(18)
  void clearWidth() => $_clearField(18);

  @$pb.TagNumber(19)
  $core.int get height => $_getIZ(12);
  @$pb.TagNumber(19)
  set height($core.int value) => $_setUnsignedInt32(12, value);
  @$pb.TagNumber(19)
  $core.bool hasHeight() => $_has(12);
  @$pb.TagNumber(19)
  void clearHeight() => $_clearField(19);

  @$pb.TagNumber(25)
  $core.String get originSrc => $_getSZ(13);
  @$pb.TagNumber(25)
  set originSrc($core.String value) => $_setString(13, value);
  @$pb.TagNumber(25)
  $core.bool hasOriginSrc() => $_has(13);
  @$pb.TagNumber(25)
  void clearOriginSrc() => $_clearField(25);

  @$pb.TagNumber(27)
  $core.int get originSize => $_getIZ(14);
  @$pb.TagNumber(27)
  set originSize($core.int value) => $_setUnsignedInt32(14, value);
  @$pb.TagNumber(27)
  $core.bool hasOriginSize() => $_has(14);
  @$pb.TagNumber(27)
  void clearOriginSize() => $_clearField(27);

  @$pb.TagNumber(28)
  $core.int get count => $_getIZ(15);
  @$pb.TagNumber(28)
  set count($core.int value) => $_setSignedInt32(15, value);
  @$pb.TagNumber(28)
  $core.bool hasCount() => $_has(15);
  @$pb.TagNumber(28)
  void clearCount() => $_clearField(28);

  @$pb.TagNumber(40)
  PbContent_TiebaPlusInfo get tiebaplusInfo => $_getN(16);
  @$pb.TagNumber(40)
  set tiebaplusInfo(PbContent_TiebaPlusInfo value) => $_setField(40, value);
  @$pb.TagNumber(40)
  $core.bool hasTiebaplusInfo() => $_has(16);
  @$pb.TagNumber(40)
  void clearTiebaplusInfo() => $_clearField(40);
  @$pb.TagNumber(40)
  PbContent_TiebaPlusInfo ensureTiebaplusInfo() => $_ensure(16);

  @$pb.TagNumber(41)
  PbContent_Item get item => $_getN(17);
  @$pb.TagNumber(41)
  set item(PbContent_Item value) => $_setField(41, value);
  @$pb.TagNumber(41)
  $core.bool hasItem() => $_has(17);
  @$pb.TagNumber(41)
  void clearItem() => $_clearField(41);
  @$pb.TagNumber(41)
  PbContent_Item ensureItem() => $_ensure(17);

  @$pb.TagNumber(49)
  $core.String get portrait => $_getSZ(18);
  @$pb.TagNumber(49)
  set portrait($core.String value) => $_setString(18, value);
  @$pb.TagNumber(49)
  $core.bool hasPortrait() => $_has(18);
  @$pb.TagNumber(49)
  void clearPortrait() => $_clearField(49);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
