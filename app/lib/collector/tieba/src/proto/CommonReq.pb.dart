// This is a generated file - do not edit.
//
// Generated from CommonReq.proto.

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

class CommonReq extends $pb.GeneratedMessage {
  factory CommonReq({
    $core.int? clientType,
    $core.String? clientVersion,
    $core.String? clientId,
    $core.String? phoneImei,
    $core.String? from,
    $core.String? cuid,
    $fixnum.Int64? timestamp,
    $core.String? model,
    $core.String? bDUSS,
    $core.String? tbs,
    $core.int? netType,
    $core.String? pversion,
    $core.String? osVersion,
    $core.String? brand,
    $core.String? legoLibVersion,
    $core.String? applist,
    $core.String? stoken,
    $core.String? zId,
    $core.String? cuidGalaxy2,
    $core.String? cuidGid,
    $core.String? c3Aid,
    $core.String? sampleId,
    $core.int? scrW,
    $core.int? scrH,
    $core.double? scrDip,
    $core.int? qType,
    $core.int? isTeenager,
    $core.String? sdkVer,
    $core.String? frameworkVer,
    $core.String? nawsGameVer,
    $fixnum.Int64? activeTimestamp,
    $fixnum.Int64? firstInstallTime,
    $fixnum.Int64? lastUpdateTime,
    $core.String? eventDay,
    $core.String? androidId,
    $core.int? cmode,
    $core.String? startScheme,
    $core.int? startType,
    $core.String? idfv,
    $core.String? extra,
    $core.String? userAgent,
    $core.int? personalizedRecSwitch,
    $core.String? deviceScore,
  }) {
    final result = CommonReq._();
    if (clientType != null) result.clientType = clientType;
    if (clientVersion != null) result.clientVersion = clientVersion;
    if (clientId != null) result.clientId = clientId;
    if (phoneImei != null) result.phoneImei = phoneImei;
    if (from != null) result.from = from;
    if (cuid != null) result.cuid = cuid;
    if (timestamp != null) result.timestamp = timestamp;
    if (model != null) result.model = model;
    if (bDUSS != null) result.bDUSS = bDUSS;
    if (tbs != null) result.tbs = tbs;
    if (netType != null) result.netType = netType;
    if (pversion != null) result.pversion = pversion;
    if (osVersion != null) result.osVersion = osVersion;
    if (brand != null) result.brand = brand;
    if (legoLibVersion != null) result.legoLibVersion = legoLibVersion;
    if (applist != null) result.applist = applist;
    if (stoken != null) result.stoken = stoken;
    if (zId != null) result.zId = zId;
    if (cuidGalaxy2 != null) result.cuidGalaxy2 = cuidGalaxy2;
    if (cuidGid != null) result.cuidGid = cuidGid;
    if (c3Aid != null) result.c3Aid = c3Aid;
    if (sampleId != null) result.sampleId = sampleId;
    if (scrW != null) result.scrW = scrW;
    if (scrH != null) result.scrH = scrH;
    if (scrDip != null) result.scrDip = scrDip;
    if (qType != null) result.qType = qType;
    if (isTeenager != null) result.isTeenager = isTeenager;
    if (sdkVer != null) result.sdkVer = sdkVer;
    if (frameworkVer != null) result.frameworkVer = frameworkVer;
    if (nawsGameVer != null) result.nawsGameVer = nawsGameVer;
    if (activeTimestamp != null) result.activeTimestamp = activeTimestamp;
    if (firstInstallTime != null) result.firstInstallTime = firstInstallTime;
    if (lastUpdateTime != null) result.lastUpdateTime = lastUpdateTime;
    if (eventDay != null) result.eventDay = eventDay;
    if (androidId != null) result.androidId = androidId;
    if (cmode != null) result.cmode = cmode;
    if (startScheme != null) result.startScheme = startScheme;
    if (startType != null) result.startType = startType;
    if (idfv != null) result.idfv = idfv;
    if (extra != null) result.extra = extra;
    if (userAgent != null) result.userAgent = userAgent;
    if (personalizedRecSwitch != null)
      result.personalizedRecSwitch = personalizedRecSwitch;
    if (deviceScore != null) result.deviceScore = deviceScore;
    return result;
  }

  CommonReq._();

  factory CommonReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonReq()..mergeFromBuffer(data, registry);
  factory CommonReq.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonReq()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CommonReq',
      createEmptyInstance: CommonReq.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'ClientType')
    ..aOS(2, _omitFieldNames ? '' : 'ClientVersion')
    ..aOS(3, _omitFieldNames ? '' : 'ClientId')
    ..aOS(5, _omitFieldNames ? '' : 'PhoneImei')
    ..aOS(6, _omitFieldNames ? '' : 'From')
    ..aOS(7, _omitFieldNames ? '' : 'cuid')
    ..aInt64(8, _omitFieldNames ? '' : 'Timestamp')
    ..aOS(9, _omitFieldNames ? '' : 'model')
    ..aOS(10, _omitFieldNames ? '' : 'BDUSS', protoName: 'BDUSS')
    ..aOS(11, _omitFieldNames ? '' : 'tbs')
    ..aI(12, _omitFieldNames ? '' : 'netType')
    ..aOS(24, _omitFieldNames ? '' : 'pversion')
    ..aOS(25, _omitFieldNames ? '' : 'OsVersion')
    ..aOS(26, _omitFieldNames ? '' : 'brand')
    ..aOS(28, _omitFieldNames ? '' : 'legoLibVersion')
    ..aOS(29, _omitFieldNames ? '' : 'applist')
    ..aOS(30, _omitFieldNames ? '' : 'stoken')
    ..aOS(31, _omitFieldNames ? '' : 'zId')
    ..aOS(32, _omitFieldNames ? '' : 'cuidGalaxy2')
    ..aOS(33, _omitFieldNames ? '' : 'cuidGid')
    ..aOS(35, _omitFieldNames ? '' : 'c3Aid')
    ..aOS(36, _omitFieldNames ? '' : 'sampleId')
    ..aI(37, _omitFieldNames ? '' : 'scrW')
    ..aI(38, _omitFieldNames ? '' : 'scrH')
    ..aD(39, _omitFieldNames ? '' : 'scrDip')
    ..aI(40, _omitFieldNames ? '' : 'qType')
    ..aI(41, _omitFieldNames ? '' : 'isTeenager')
    ..aOS(42, _omitFieldNames ? '' : 'sdkVer')
    ..aOS(43, _omitFieldNames ? '' : 'frameworkVer')
    ..aOS(44, _omitFieldNames ? '' : 'nawsGameVer')
    ..aInt64(49, _omitFieldNames ? '' : 'activeTimestamp')
    ..aInt64(50, _omitFieldNames ? '' : 'firstInstallTime')
    ..aInt64(51, _omitFieldNames ? '' : 'lastUpdateTime')
    ..aOS(53, _omitFieldNames ? '' : 'eventDay')
    ..aOS(54, _omitFieldNames ? '' : 'androidId')
    ..aI(55, _omitFieldNames ? '' : 'cmode')
    ..aOS(56, _omitFieldNames ? '' : 'startScheme')
    ..aI(57, _omitFieldNames ? '' : 'startType')
    ..aOS(60, _omitFieldNames ? '' : 'idfv')
    ..aOS(61, _omitFieldNames ? '' : 'extra')
    ..aOS(62, _omitFieldNames ? '' : 'userAgent')
    ..aI(63, _omitFieldNames ? '' : 'personalizedRecSwitch')
    ..aOS(70, _omitFieldNames ? '' : 'deviceScore')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonReq copyWith(void Function(CommonReq) updates) =>
      super.copyWith((message) => updates(message as CommonReq)) as CommonReq;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CommonReq() / CommonReq.new instead')
  static CommonReq create() => CommonReq._();
  static $pb.GeneratedMessage $_createMessage() => CommonReq._();
  @$core.override
  CommonReq createEmptyInstance() => CommonReq._();
  @$core.pragma('dart2js:noInline')
  static CommonReq getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CommonReq>(CommonReq.$_createMessage);
  static CommonReq? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get clientType => $_getIZ(0);
  @$pb.TagNumber(1)
  set clientType($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasClientType() => $_has(0);
  @$pb.TagNumber(1)
  void clearClientType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get clientVersion => $_getSZ(1);
  @$pb.TagNumber(2)
  set clientVersion($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasClientVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearClientVersion() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get clientId => $_getSZ(2);
  @$pb.TagNumber(3)
  set clientId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasClientId() => $_has(2);
  @$pb.TagNumber(3)
  void clearClientId() => $_clearField(3);

  @$pb.TagNumber(5)
  $core.String get phoneImei => $_getSZ(3);
  @$pb.TagNumber(5)
  set phoneImei($core.String value) => $_setString(3, value);
  @$pb.TagNumber(5)
  $core.bool hasPhoneImei() => $_has(3);
  @$pb.TagNumber(5)
  void clearPhoneImei() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get from => $_getSZ(4);
  @$pb.TagNumber(6)
  set from($core.String value) => $_setString(4, value);
  @$pb.TagNumber(6)
  $core.bool hasFrom() => $_has(4);
  @$pb.TagNumber(6)
  void clearFrom() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get cuid => $_getSZ(5);
  @$pb.TagNumber(7)
  set cuid($core.String value) => $_setString(5, value);
  @$pb.TagNumber(7)
  $core.bool hasCuid() => $_has(5);
  @$pb.TagNumber(7)
  void clearCuid() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get timestamp => $_getI64(6);
  @$pb.TagNumber(8)
  set timestamp($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(8)
  $core.bool hasTimestamp() => $_has(6);
  @$pb.TagNumber(8)
  void clearTimestamp() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get model => $_getSZ(7);
  @$pb.TagNumber(9)
  set model($core.String value) => $_setString(7, value);
  @$pb.TagNumber(9)
  $core.bool hasModel() => $_has(7);
  @$pb.TagNumber(9)
  void clearModel() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get bDUSS => $_getSZ(8);
  @$pb.TagNumber(10)
  set bDUSS($core.String value) => $_setString(8, value);
  @$pb.TagNumber(10)
  $core.bool hasBDUSS() => $_has(8);
  @$pb.TagNumber(10)
  void clearBDUSS() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get tbs => $_getSZ(9);
  @$pb.TagNumber(11)
  set tbs($core.String value) => $_setString(9, value);
  @$pb.TagNumber(11)
  $core.bool hasTbs() => $_has(9);
  @$pb.TagNumber(11)
  void clearTbs() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.int get netType => $_getIZ(10);
  @$pb.TagNumber(12)
  set netType($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(12)
  $core.bool hasNetType() => $_has(10);
  @$pb.TagNumber(12)
  void clearNetType() => $_clearField(12);

  @$pb.TagNumber(24)
  $core.String get pversion => $_getSZ(11);
  @$pb.TagNumber(24)
  set pversion($core.String value) => $_setString(11, value);
  @$pb.TagNumber(24)
  $core.bool hasPversion() => $_has(11);
  @$pb.TagNumber(24)
  void clearPversion() => $_clearField(24);

  @$pb.TagNumber(25)
  $core.String get osVersion => $_getSZ(12);
  @$pb.TagNumber(25)
  set osVersion($core.String value) => $_setString(12, value);
  @$pb.TagNumber(25)
  $core.bool hasOsVersion() => $_has(12);
  @$pb.TagNumber(25)
  void clearOsVersion() => $_clearField(25);

  @$pb.TagNumber(26)
  $core.String get brand => $_getSZ(13);
  @$pb.TagNumber(26)
  set brand($core.String value) => $_setString(13, value);
  @$pb.TagNumber(26)
  $core.bool hasBrand() => $_has(13);
  @$pb.TagNumber(26)
  void clearBrand() => $_clearField(26);

  @$pb.TagNumber(28)
  $core.String get legoLibVersion => $_getSZ(14);
  @$pb.TagNumber(28)
  set legoLibVersion($core.String value) => $_setString(14, value);
  @$pb.TagNumber(28)
  $core.bool hasLegoLibVersion() => $_has(14);
  @$pb.TagNumber(28)
  void clearLegoLibVersion() => $_clearField(28);

  @$pb.TagNumber(29)
  $core.String get applist => $_getSZ(15);
  @$pb.TagNumber(29)
  set applist($core.String value) => $_setString(15, value);
  @$pb.TagNumber(29)
  $core.bool hasApplist() => $_has(15);
  @$pb.TagNumber(29)
  void clearApplist() => $_clearField(29);

  @$pb.TagNumber(30)
  $core.String get stoken => $_getSZ(16);
  @$pb.TagNumber(30)
  set stoken($core.String value) => $_setString(16, value);
  @$pb.TagNumber(30)
  $core.bool hasStoken() => $_has(16);
  @$pb.TagNumber(30)
  void clearStoken() => $_clearField(30);

  @$pb.TagNumber(31)
  $core.String get zId => $_getSZ(17);
  @$pb.TagNumber(31)
  set zId($core.String value) => $_setString(17, value);
  @$pb.TagNumber(31)
  $core.bool hasZId() => $_has(17);
  @$pb.TagNumber(31)
  void clearZId() => $_clearField(31);

  @$pb.TagNumber(32)
  $core.String get cuidGalaxy2 => $_getSZ(18);
  @$pb.TagNumber(32)
  set cuidGalaxy2($core.String value) => $_setString(18, value);
  @$pb.TagNumber(32)
  $core.bool hasCuidGalaxy2() => $_has(18);
  @$pb.TagNumber(32)
  void clearCuidGalaxy2() => $_clearField(32);

  @$pb.TagNumber(33)
  $core.String get cuidGid => $_getSZ(19);
  @$pb.TagNumber(33)
  set cuidGid($core.String value) => $_setString(19, value);
  @$pb.TagNumber(33)
  $core.bool hasCuidGid() => $_has(19);
  @$pb.TagNumber(33)
  void clearCuidGid() => $_clearField(33);

  @$pb.TagNumber(35)
  $core.String get c3Aid => $_getSZ(20);
  @$pb.TagNumber(35)
  set c3Aid($core.String value) => $_setString(20, value);
  @$pb.TagNumber(35)
  $core.bool hasC3Aid() => $_has(20);
  @$pb.TagNumber(35)
  void clearC3Aid() => $_clearField(35);

  @$pb.TagNumber(36)
  $core.String get sampleId => $_getSZ(21);
  @$pb.TagNumber(36)
  set sampleId($core.String value) => $_setString(21, value);
  @$pb.TagNumber(36)
  $core.bool hasSampleId() => $_has(21);
  @$pb.TagNumber(36)
  void clearSampleId() => $_clearField(36);

  @$pb.TagNumber(37)
  $core.int get scrW => $_getIZ(22);
  @$pb.TagNumber(37)
  set scrW($core.int value) => $_setSignedInt32(22, value);
  @$pb.TagNumber(37)
  $core.bool hasScrW() => $_has(22);
  @$pb.TagNumber(37)
  void clearScrW() => $_clearField(37);

  @$pb.TagNumber(38)
  $core.int get scrH => $_getIZ(23);
  @$pb.TagNumber(38)
  set scrH($core.int value) => $_setSignedInt32(23, value);
  @$pb.TagNumber(38)
  $core.bool hasScrH() => $_has(23);
  @$pb.TagNumber(38)
  void clearScrH() => $_clearField(38);

  @$pb.TagNumber(39)
  $core.double get scrDip => $_getN(24);
  @$pb.TagNumber(39)
  set scrDip($core.double value) => $_setDouble(24, value);
  @$pb.TagNumber(39)
  $core.bool hasScrDip() => $_has(24);
  @$pb.TagNumber(39)
  void clearScrDip() => $_clearField(39);

  @$pb.TagNumber(40)
  $core.int get qType => $_getIZ(25);
  @$pb.TagNumber(40)
  set qType($core.int value) => $_setSignedInt32(25, value);
  @$pb.TagNumber(40)
  $core.bool hasQType() => $_has(25);
  @$pb.TagNumber(40)
  void clearQType() => $_clearField(40);

  @$pb.TagNumber(41)
  $core.int get isTeenager => $_getIZ(26);
  @$pb.TagNumber(41)
  set isTeenager($core.int value) => $_setSignedInt32(26, value);
  @$pb.TagNumber(41)
  $core.bool hasIsTeenager() => $_has(26);
  @$pb.TagNumber(41)
  void clearIsTeenager() => $_clearField(41);

  @$pb.TagNumber(42)
  $core.String get sdkVer => $_getSZ(27);
  @$pb.TagNumber(42)
  set sdkVer($core.String value) => $_setString(27, value);
  @$pb.TagNumber(42)
  $core.bool hasSdkVer() => $_has(27);
  @$pb.TagNumber(42)
  void clearSdkVer() => $_clearField(42);

  @$pb.TagNumber(43)
  $core.String get frameworkVer => $_getSZ(28);
  @$pb.TagNumber(43)
  set frameworkVer($core.String value) => $_setString(28, value);
  @$pb.TagNumber(43)
  $core.bool hasFrameworkVer() => $_has(28);
  @$pb.TagNumber(43)
  void clearFrameworkVer() => $_clearField(43);

  @$pb.TagNumber(44)
  $core.String get nawsGameVer => $_getSZ(29);
  @$pb.TagNumber(44)
  set nawsGameVer($core.String value) => $_setString(29, value);
  @$pb.TagNumber(44)
  $core.bool hasNawsGameVer() => $_has(29);
  @$pb.TagNumber(44)
  void clearNawsGameVer() => $_clearField(44);

  @$pb.TagNumber(49)
  $fixnum.Int64 get activeTimestamp => $_getI64(30);
  @$pb.TagNumber(49)
  set activeTimestamp($fixnum.Int64 value) => $_setInt64(30, value);
  @$pb.TagNumber(49)
  $core.bool hasActiveTimestamp() => $_has(30);
  @$pb.TagNumber(49)
  void clearActiveTimestamp() => $_clearField(49);

  @$pb.TagNumber(50)
  $fixnum.Int64 get firstInstallTime => $_getI64(31);
  @$pb.TagNumber(50)
  set firstInstallTime($fixnum.Int64 value) => $_setInt64(31, value);
  @$pb.TagNumber(50)
  $core.bool hasFirstInstallTime() => $_has(31);
  @$pb.TagNumber(50)
  void clearFirstInstallTime() => $_clearField(50);

  @$pb.TagNumber(51)
  $fixnum.Int64 get lastUpdateTime => $_getI64(32);
  @$pb.TagNumber(51)
  set lastUpdateTime($fixnum.Int64 value) => $_setInt64(32, value);
  @$pb.TagNumber(51)
  $core.bool hasLastUpdateTime() => $_has(32);
  @$pb.TagNumber(51)
  void clearLastUpdateTime() => $_clearField(51);

  @$pb.TagNumber(53)
  $core.String get eventDay => $_getSZ(33);
  @$pb.TagNumber(53)
  set eventDay($core.String value) => $_setString(33, value);
  @$pb.TagNumber(53)
  $core.bool hasEventDay() => $_has(33);
  @$pb.TagNumber(53)
  void clearEventDay() => $_clearField(53);

  @$pb.TagNumber(54)
  $core.String get androidId => $_getSZ(34);
  @$pb.TagNumber(54)
  set androidId($core.String value) => $_setString(34, value);
  @$pb.TagNumber(54)
  $core.bool hasAndroidId() => $_has(34);
  @$pb.TagNumber(54)
  void clearAndroidId() => $_clearField(54);

  @$pb.TagNumber(55)
  $core.int get cmode => $_getIZ(35);
  @$pb.TagNumber(55)
  set cmode($core.int value) => $_setSignedInt32(35, value);
  @$pb.TagNumber(55)
  $core.bool hasCmode() => $_has(35);
  @$pb.TagNumber(55)
  void clearCmode() => $_clearField(55);

  @$pb.TagNumber(56)
  $core.String get startScheme => $_getSZ(36);
  @$pb.TagNumber(56)
  set startScheme($core.String value) => $_setString(36, value);
  @$pb.TagNumber(56)
  $core.bool hasStartScheme() => $_has(36);
  @$pb.TagNumber(56)
  void clearStartScheme() => $_clearField(56);

  @$pb.TagNumber(57)
  $core.int get startType => $_getIZ(37);
  @$pb.TagNumber(57)
  set startType($core.int value) => $_setSignedInt32(37, value);
  @$pb.TagNumber(57)
  $core.bool hasStartType() => $_has(37);
  @$pb.TagNumber(57)
  void clearStartType() => $_clearField(57);

  @$pb.TagNumber(60)
  $core.String get idfv => $_getSZ(38);
  @$pb.TagNumber(60)
  set idfv($core.String value) => $_setString(38, value);
  @$pb.TagNumber(60)
  $core.bool hasIdfv() => $_has(38);
  @$pb.TagNumber(60)
  void clearIdfv() => $_clearField(60);

  @$pb.TagNumber(61)
  $core.String get extra => $_getSZ(39);
  @$pb.TagNumber(61)
  set extra($core.String value) => $_setString(39, value);
  @$pb.TagNumber(61)
  $core.bool hasExtra() => $_has(39);
  @$pb.TagNumber(61)
  void clearExtra() => $_clearField(61);

  @$pb.TagNumber(62)
  $core.String get userAgent => $_getSZ(40);
  @$pb.TagNumber(62)
  set userAgent($core.String value) => $_setString(40, value);
  @$pb.TagNumber(62)
  $core.bool hasUserAgent() => $_has(40);
  @$pb.TagNumber(62)
  void clearUserAgent() => $_clearField(62);

  @$pb.TagNumber(63)
  $core.int get personalizedRecSwitch => $_getIZ(41);
  @$pb.TagNumber(63)
  set personalizedRecSwitch($core.int value) => $_setSignedInt32(41, value);
  @$pb.TagNumber(63)
  $core.bool hasPersonalizedRecSwitch() => $_has(41);
  @$pb.TagNumber(63)
  void clearPersonalizedRecSwitch() => $_clearField(63);

  @$pb.TagNumber(70)
  $core.String get deviceScore => $_getSZ(42);
  @$pb.TagNumber(70)
  set deviceScore($core.String value) => $_setString(42, value);
  @$pb.TagNumber(70)
  $core.bool hasDeviceScore() => $_has(42);
  @$pb.TagNumber(70)
  void clearDeviceScore() => $_clearField(70);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
