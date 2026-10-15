// This is a generated file - do not edit.
//
// Generated from User.proto.

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

class User_Icon extends $pb.GeneratedMessage {
  factory User_Icon({
    $core.String? name,
  }) {
    final result = User_Icon._();
    if (name != null) result.name = name;
    return result;
  }

  User_Icon._();

  factory User_Icon.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      User_Icon()..mergeFromBuffer(data, registry);
  factory User_Icon.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      User_Icon()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'User.Icon',
      createEmptyInstance: User_Icon.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  User_Icon clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  User_Icon copyWith(void Function(User_Icon) updates) =>
      super.copyWith((message) => updates(message as User_Icon)) as User_Icon;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use User_Icon() / User_Icon.new instead')
  static User_Icon create() => User_Icon._();
  static $pb.GeneratedMessage $_createMessage() => User_Icon._();
  @$core.override
  User_Icon createEmptyInstance() => User_Icon._();
  @$core.pragma('dart2js:noInline')
  static User_Icon getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<User_Icon>(User_Icon.$_createMessage);
  static User_Icon? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);
}

class User_PrivSets extends $pb.GeneratedMessage {
  factory User_PrivSets({
    $core.int? location,
    $core.int? like,
    $core.int? group,
    $core.int? post,
    $core.int? friend,
    $core.int? live,
    $core.int? reply,
    $core.int? bazhuShowInside,
    $core.int? bazhuShowOutside,
  }) {
    final result = User_PrivSets._();
    if (location != null) result.location = location;
    if (like != null) result.like = like;
    if (group != null) result.group = group;
    if (post != null) result.post = post;
    if (friend != null) result.friend = friend;
    if (live != null) result.live = live;
    if (reply != null) result.reply = reply;
    if (bazhuShowInside != null) result.bazhuShowInside = bazhuShowInside;
    if (bazhuShowOutside != null) result.bazhuShowOutside = bazhuShowOutside;
    return result;
  }

  User_PrivSets._();

  factory User_PrivSets.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      User_PrivSets()..mergeFromBuffer(data, registry);
  factory User_PrivSets.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      User_PrivSets()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'User.PrivSets',
      createEmptyInstance: User_PrivSets.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'location')
    ..aI(2, _omitFieldNames ? '' : 'like')
    ..aI(3, _omitFieldNames ? '' : 'group')
    ..aI(4, _omitFieldNames ? '' : 'post')
    ..aI(5, _omitFieldNames ? '' : 'friend')
    ..aI(6, _omitFieldNames ? '' : 'live')
    ..aI(7, _omitFieldNames ? '' : 'reply')
    ..aI(8, _omitFieldNames ? '' : 'bazhuShowInside')
    ..aI(9, _omitFieldNames ? '' : 'bazhuShowOutside')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  User_PrivSets clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  User_PrivSets copyWith(void Function(User_PrivSets) updates) =>
      super.copyWith((message) => updates(message as User_PrivSets))
          as User_PrivSets;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use User_PrivSets() / User_PrivSets.new instead')
  static User_PrivSets create() => User_PrivSets._();
  static $pb.GeneratedMessage $_createMessage() => User_PrivSets._();
  @$core.override
  User_PrivSets createEmptyInstance() => User_PrivSets._();
  @$core.pragma('dart2js:noInline')
  static User_PrivSets getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<User_PrivSets>(
          User_PrivSets.$_createMessage);
  static User_PrivSets? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get location => $_getIZ(0);
  @$pb.TagNumber(1)
  set location($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLocation() => $_has(0);
  @$pb.TagNumber(1)
  void clearLocation() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get like => $_getIZ(1);
  @$pb.TagNumber(2)
  set like($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLike() => $_has(1);
  @$pb.TagNumber(2)
  void clearLike() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get group => $_getIZ(2);
  @$pb.TagNumber(3)
  set group($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasGroup() => $_has(2);
  @$pb.TagNumber(3)
  void clearGroup() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get post => $_getIZ(3);
  @$pb.TagNumber(4)
  set post($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPost() => $_has(3);
  @$pb.TagNumber(4)
  void clearPost() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get friend => $_getIZ(4);
  @$pb.TagNumber(5)
  set friend($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFriend() => $_has(4);
  @$pb.TagNumber(5)
  void clearFriend() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get live => $_getIZ(5);
  @$pb.TagNumber(6)
  set live($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasLive() => $_has(5);
  @$pb.TagNumber(6)
  void clearLive() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get reply => $_getIZ(6);
  @$pb.TagNumber(7)
  set reply($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasReply() => $_has(6);
  @$pb.TagNumber(7)
  void clearReply() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get bazhuShowInside => $_getIZ(7);
  @$pb.TagNumber(8)
  set bazhuShowInside($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasBazhuShowInside() => $_has(7);
  @$pb.TagNumber(8)
  void clearBazhuShowInside() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get bazhuShowOutside => $_getIZ(8);
  @$pb.TagNumber(9)
  set bazhuShowOutside($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasBazhuShowOutside() => $_has(8);
  @$pb.TagNumber(9)
  void clearBazhuShowOutside() => $_clearField(9);
}

class User_LikeForumInfo extends $pb.GeneratedMessage {
  factory User_LikeForumInfo({
    $core.String? forumName,
    $fixnum.Int64? forumId,
  }) {
    final result = User_LikeForumInfo._();
    if (forumName != null) result.forumName = forumName;
    if (forumId != null) result.forumId = forumId;
    return result;
  }

  User_LikeForumInfo._();

  factory User_LikeForumInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      User_LikeForumInfo()..mergeFromBuffer(data, registry);
  factory User_LikeForumInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      User_LikeForumInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'User.LikeForumInfo',
      createEmptyInstance: User_LikeForumInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'forumName')
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'forumId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  User_LikeForumInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  User_LikeForumInfo copyWith(void Function(User_LikeForumInfo) updates) =>
      super.copyWith((message) => updates(message as User_LikeForumInfo))
          as User_LikeForumInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use User_LikeForumInfo() / User_LikeForumInfo.new instead')
  static User_LikeForumInfo create() => User_LikeForumInfo._();
  static $pb.GeneratedMessage $_createMessage() => User_LikeForumInfo._();
  @$core.override
  User_LikeForumInfo createEmptyInstance() => User_LikeForumInfo._();
  @$core.pragma('dart2js:noInline')
  static User_LikeForumInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<User_LikeForumInfo>(
          User_LikeForumInfo.$_createMessage);
  static User_LikeForumInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get forumName => $_getSZ(0);
  @$pb.TagNumber(1)
  set forumName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasForumName() => $_has(0);
  @$pb.TagNumber(1)
  void clearForumName() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get forumId => $_getI64(1);
  @$pb.TagNumber(2)
  set forumId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasForumId() => $_has(1);
  @$pb.TagNumber(2)
  void clearForumId() => $_clearField(2);
}

class User_UserGrowth extends $pb.GeneratedMessage {
  factory User_UserGrowth({
    $core.int? levelId,
  }) {
    final result = User_UserGrowth._();
    if (levelId != null) result.levelId = levelId;
    return result;
  }

  User_UserGrowth._();

  factory User_UserGrowth.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      User_UserGrowth()..mergeFromBuffer(data, registry);
  factory User_UserGrowth.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      User_UserGrowth()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'User.UserGrowth',
      createEmptyInstance: User_UserGrowth.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'levelId', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  User_UserGrowth clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  User_UserGrowth copyWith(void Function(User_UserGrowth) updates) =>
      super.copyWith((message) => updates(message as User_UserGrowth))
          as User_UserGrowth;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use User_UserGrowth() / User_UserGrowth.new instead')
  static User_UserGrowth create() => User_UserGrowth._();
  static $pb.GeneratedMessage $_createMessage() => User_UserGrowth._();
  @$core.override
  User_UserGrowth createEmptyInstance() => User_UserGrowth._();
  @$core.pragma('dart2js:noInline')
  static User_UserGrowth getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<User_UserGrowth>(
          User_UserGrowth.$_createMessage);
  static User_UserGrowth? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get levelId => $_getIZ(0);
  @$pb.TagNumber(1)
  set levelId($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLevelId() => $_has(0);
  @$pb.TagNumber(1)
  void clearLevelId() => $_clearField(1);
}

class User extends $pb.GeneratedMessage {
  factory User({
    $fixnum.Int64? id,
    $core.String? name,
    $core.String? nameShow,
    $core.String? portrait,
    $core.Iterable<User_Icon>? iconinfo,
    $core.int? isCoreuser,
    $core.int? levelId,
    $core.int? isBawu,
    $core.String? bawuType,
    $core.String? bDUSS,
    $core.int? fansNum,
    $core.int? concernNum,
    $core.int? sex,
    $core.int? myLikeNum,
    $core.String? intro,
    $core.int? postNum,
    $core.String? tbAge,
    $core.int? isMem,
    $core.int? gender,
    User_PrivSets? privSets,
    $core.int? isFriend,
    $core.Iterable<User_LikeForumInfo>? likeForum,
    $core.int? isGuanfang,
    $core.int? threadNum,
    $core.int? isFans,
    $core.int? isDefaultAvatar,
    $core.String? tiebaUid,
    $core.String? ipAddress,
    User_UserGrowth? userGrowth,
  }) {
    final result = User._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (nameShow != null) result.nameShow = nameShow;
    if (portrait != null) result.portrait = portrait;
    if (iconinfo != null) result.iconinfo.addAll(iconinfo);
    if (isCoreuser != null) result.isCoreuser = isCoreuser;
    if (levelId != null) result.levelId = levelId;
    if (isBawu != null) result.isBawu = isBawu;
    if (bawuType != null) result.bawuType = bawuType;
    if (bDUSS != null) result.bDUSS = bDUSS;
    if (fansNum != null) result.fansNum = fansNum;
    if (concernNum != null) result.concernNum = concernNum;
    if (sex != null) result.sex = sex;
    if (myLikeNum != null) result.myLikeNum = myLikeNum;
    if (intro != null) result.intro = intro;
    if (postNum != null) result.postNum = postNum;
    if (tbAge != null) result.tbAge = tbAge;
    if (isMem != null) result.isMem = isMem;
    if (gender != null) result.gender = gender;
    if (privSets != null) result.privSets = privSets;
    if (isFriend != null) result.isFriend = isFriend;
    if (likeForum != null) result.likeForum.addAll(likeForum);
    if (isGuanfang != null) result.isGuanfang = isGuanfang;
    if (threadNum != null) result.threadNum = threadNum;
    if (isFans != null) result.isFans = isFans;
    if (isDefaultAvatar != null) result.isDefaultAvatar = isDefaultAvatar;
    if (tiebaUid != null) result.tiebaUid = tiebaUid;
    if (ipAddress != null) result.ipAddress = ipAddress;
    if (userGrowth != null) result.userGrowth = userGrowth;
    return result;
  }

  User._();

  factory User.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      User()..mergeFromBuffer(data, registry);
  factory User.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      User()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'User',
      createEmptyInstance: User.$_createMessage)
    ..aInt64(2, _omitFieldNames ? '' : 'id')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aOS(4, _omitFieldNames ? '' : 'nameShow')
    ..aOS(5, _omitFieldNames ? '' : 'portrait')
    ..pPM<User_Icon>(17, _omitFieldNames ? '' : 'iconinfo',
        subBuilder: User_Icon.$_createMessage)
    ..aI(20, _omitFieldNames ? '' : 'isCoreuser')
    ..aI(23, _omitFieldNames ? '' : 'levelId')
    ..aI(25, _omitFieldNames ? '' : 'isBawu')
    ..aOS(26, _omitFieldNames ? '' : 'bawuType')
    ..aOS(29, _omitFieldNames ? '' : 'BDUSS', protoName: 'BDUSS')
    ..aI(30, _omitFieldNames ? '' : 'fansNum')
    ..aI(31, _omitFieldNames ? '' : 'concernNum')
    ..aI(32, _omitFieldNames ? '' : 'sex')
    ..aI(33, _omitFieldNames ? '' : 'myLikeNum')
    ..aOS(34, _omitFieldNames ? '' : 'intro')
    ..aI(37, _omitFieldNames ? '' : 'postNum')
    ..aOS(38, _omitFieldNames ? '' : 'tbAge')
    ..aI(39, _omitFieldNames ? '' : 'isMem')
    ..aI(42, _omitFieldNames ? '' : 'gender')
    ..aOM<User_PrivSets>(45, _omitFieldNames ? '' : 'privSets',
        subBuilder: User_PrivSets.$_createMessage)
    ..aI(46, _omitFieldNames ? '' : 'isFriend')
    ..pPM<User_LikeForumInfo>(47, _omitFieldNames ? '' : 'likeForum',
        protoName: 'likeForum', subBuilder: User_LikeForumInfo.$_createMessage)
    ..aI(52, _omitFieldNames ? '' : 'isGuanfang')
    ..aI(87, _omitFieldNames ? '' : 'threadNum')
    ..aI(91, _omitFieldNames ? '' : 'isFans')
    ..aI(106, _omitFieldNames ? '' : 'isDefaultAvatar')
    ..aOS(120, _omitFieldNames ? '' : 'tiebaUid')
    ..aOS(127, _omitFieldNames ? '' : 'ipAddress')
    ..aOM<User_UserGrowth>(137, _omitFieldNames ? '' : 'userGrowth',
        subBuilder: User_UserGrowth.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  User clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  User copyWith(void Function(User) updates) =>
      super.copyWith((message) => updates(message as User)) as User;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use User() / User.new instead')
  static User create() => User._();
  static $pb.GeneratedMessage $_createMessage() => User._();
  @$core.override
  User createEmptyInstance() => User._();
  @$core.pragma('dart2js:noInline')
  static User getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<User>(User.$_createMessage);
  static User? _defaultInstance;

  @$pb.TagNumber(2)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(2)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(2)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(2)
  void clearId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get nameShow => $_getSZ(2);
  @$pb.TagNumber(4)
  set nameShow($core.String value) => $_setString(2, value);
  @$pb.TagNumber(4)
  $core.bool hasNameShow() => $_has(2);
  @$pb.TagNumber(4)
  void clearNameShow() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get portrait => $_getSZ(3);
  @$pb.TagNumber(5)
  set portrait($core.String value) => $_setString(3, value);
  @$pb.TagNumber(5)
  $core.bool hasPortrait() => $_has(3);
  @$pb.TagNumber(5)
  void clearPortrait() => $_clearField(5);

  @$pb.TagNumber(17)
  $pb.PbList<User_Icon> get iconinfo => $_getList(4);

  @$pb.TagNumber(20)
  $core.int get isCoreuser => $_getIZ(5);
  @$pb.TagNumber(20)
  set isCoreuser($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(20)
  $core.bool hasIsCoreuser() => $_has(5);
  @$pb.TagNumber(20)
  void clearIsCoreuser() => $_clearField(20);

  @$pb.TagNumber(23)
  $core.int get levelId => $_getIZ(6);
  @$pb.TagNumber(23)
  set levelId($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(23)
  $core.bool hasLevelId() => $_has(6);
  @$pb.TagNumber(23)
  void clearLevelId() => $_clearField(23);

  @$pb.TagNumber(25)
  $core.int get isBawu => $_getIZ(7);
  @$pb.TagNumber(25)
  set isBawu($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(25)
  $core.bool hasIsBawu() => $_has(7);
  @$pb.TagNumber(25)
  void clearIsBawu() => $_clearField(25);

  @$pb.TagNumber(26)
  $core.String get bawuType => $_getSZ(8);
  @$pb.TagNumber(26)
  set bawuType($core.String value) => $_setString(8, value);
  @$pb.TagNumber(26)
  $core.bool hasBawuType() => $_has(8);
  @$pb.TagNumber(26)
  void clearBawuType() => $_clearField(26);

  @$pb.TagNumber(29)
  $core.String get bDUSS => $_getSZ(9);
  @$pb.TagNumber(29)
  set bDUSS($core.String value) => $_setString(9, value);
  @$pb.TagNumber(29)
  $core.bool hasBDUSS() => $_has(9);
  @$pb.TagNumber(29)
  void clearBDUSS() => $_clearField(29);

  @$pb.TagNumber(30)
  $core.int get fansNum => $_getIZ(10);
  @$pb.TagNumber(30)
  set fansNum($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(30)
  $core.bool hasFansNum() => $_has(10);
  @$pb.TagNumber(30)
  void clearFansNum() => $_clearField(30);

  @$pb.TagNumber(31)
  $core.int get concernNum => $_getIZ(11);
  @$pb.TagNumber(31)
  set concernNum($core.int value) => $_setSignedInt32(11, value);
  @$pb.TagNumber(31)
  $core.bool hasConcernNum() => $_has(11);
  @$pb.TagNumber(31)
  void clearConcernNum() => $_clearField(31);

  @$pb.TagNumber(32)
  $core.int get sex => $_getIZ(12);
  @$pb.TagNumber(32)
  set sex($core.int value) => $_setSignedInt32(12, value);
  @$pb.TagNumber(32)
  $core.bool hasSex() => $_has(12);
  @$pb.TagNumber(32)
  void clearSex() => $_clearField(32);

  @$pb.TagNumber(33)
  $core.int get myLikeNum => $_getIZ(13);
  @$pb.TagNumber(33)
  set myLikeNum($core.int value) => $_setSignedInt32(13, value);
  @$pb.TagNumber(33)
  $core.bool hasMyLikeNum() => $_has(13);
  @$pb.TagNumber(33)
  void clearMyLikeNum() => $_clearField(33);

  @$pb.TagNumber(34)
  $core.String get intro => $_getSZ(14);
  @$pb.TagNumber(34)
  set intro($core.String value) => $_setString(14, value);
  @$pb.TagNumber(34)
  $core.bool hasIntro() => $_has(14);
  @$pb.TagNumber(34)
  void clearIntro() => $_clearField(34);

  @$pb.TagNumber(37)
  $core.int get postNum => $_getIZ(15);
  @$pb.TagNumber(37)
  set postNum($core.int value) => $_setSignedInt32(15, value);
  @$pb.TagNumber(37)
  $core.bool hasPostNum() => $_has(15);
  @$pb.TagNumber(37)
  void clearPostNum() => $_clearField(37);

  @$pb.TagNumber(38)
  $core.String get tbAge => $_getSZ(16);
  @$pb.TagNumber(38)
  set tbAge($core.String value) => $_setString(16, value);
  @$pb.TagNumber(38)
  $core.bool hasTbAge() => $_has(16);
  @$pb.TagNumber(38)
  void clearTbAge() => $_clearField(38);

  @$pb.TagNumber(39)
  $core.int get isMem => $_getIZ(17);
  @$pb.TagNumber(39)
  set isMem($core.int value) => $_setSignedInt32(17, value);
  @$pb.TagNumber(39)
  $core.bool hasIsMem() => $_has(17);
  @$pb.TagNumber(39)
  void clearIsMem() => $_clearField(39);

  @$pb.TagNumber(42)
  $core.int get gender => $_getIZ(18);
  @$pb.TagNumber(42)
  set gender($core.int value) => $_setSignedInt32(18, value);
  @$pb.TagNumber(42)
  $core.bool hasGender() => $_has(18);
  @$pb.TagNumber(42)
  void clearGender() => $_clearField(42);

  @$pb.TagNumber(45)
  User_PrivSets get privSets => $_getN(19);
  @$pb.TagNumber(45)
  set privSets(User_PrivSets value) => $_setField(45, value);
  @$pb.TagNumber(45)
  $core.bool hasPrivSets() => $_has(19);
  @$pb.TagNumber(45)
  void clearPrivSets() => $_clearField(45);
  @$pb.TagNumber(45)
  User_PrivSets ensurePrivSets() => $_ensure(19);

  @$pb.TagNumber(46)
  $core.int get isFriend => $_getIZ(20);
  @$pb.TagNumber(46)
  set isFriend($core.int value) => $_setSignedInt32(20, value);
  @$pb.TagNumber(46)
  $core.bool hasIsFriend() => $_has(20);
  @$pb.TagNumber(46)
  void clearIsFriend() => $_clearField(46);

  @$pb.TagNumber(47)
  $pb.PbList<User_LikeForumInfo> get likeForum => $_getList(21);

  @$pb.TagNumber(52)
  $core.int get isGuanfang => $_getIZ(22);
  @$pb.TagNumber(52)
  set isGuanfang($core.int value) => $_setSignedInt32(22, value);
  @$pb.TagNumber(52)
  $core.bool hasIsGuanfang() => $_has(22);
  @$pb.TagNumber(52)
  void clearIsGuanfang() => $_clearField(52);

  @$pb.TagNumber(87)
  $core.int get threadNum => $_getIZ(23);
  @$pb.TagNumber(87)
  set threadNum($core.int value) => $_setSignedInt32(23, value);
  @$pb.TagNumber(87)
  $core.bool hasThreadNum() => $_has(23);
  @$pb.TagNumber(87)
  void clearThreadNum() => $_clearField(87);

  @$pb.TagNumber(91)
  $core.int get isFans => $_getIZ(24);
  @$pb.TagNumber(91)
  set isFans($core.int value) => $_setSignedInt32(24, value);
  @$pb.TagNumber(91)
  $core.bool hasIsFans() => $_has(24);
  @$pb.TagNumber(91)
  void clearIsFans() => $_clearField(91);

  @$pb.TagNumber(106)
  $core.int get isDefaultAvatar => $_getIZ(25);
  @$pb.TagNumber(106)
  set isDefaultAvatar($core.int value) => $_setSignedInt32(25, value);
  @$pb.TagNumber(106)
  $core.bool hasIsDefaultAvatar() => $_has(25);
  @$pb.TagNumber(106)
  void clearIsDefaultAvatar() => $_clearField(106);

  @$pb.TagNumber(120)
  $core.String get tiebaUid => $_getSZ(26);
  @$pb.TagNumber(120)
  set tiebaUid($core.String value) => $_setString(26, value);
  @$pb.TagNumber(120)
  $core.bool hasTiebaUid() => $_has(26);
  @$pb.TagNumber(120)
  void clearTiebaUid() => $_clearField(120);

  @$pb.TagNumber(127)
  $core.String get ipAddress => $_getSZ(27);
  @$pb.TagNumber(127)
  set ipAddress($core.String value) => $_setString(27, value);
  @$pb.TagNumber(127)
  $core.bool hasIpAddress() => $_has(27);
  @$pb.TagNumber(127)
  void clearIpAddress() => $_clearField(127);

  @$pb.TagNumber(137)
  User_UserGrowth get userGrowth => $_getN(28);
  @$pb.TagNumber(137)
  set userGrowth(User_UserGrowth value) => $_setField(137, value);
  @$pb.TagNumber(137)
  $core.bool hasUserGrowth() => $_has(28);
  @$pb.TagNumber(137)
  void clearUserGrowth() => $_clearField(137);
  @$pb.TagNumber(137)
  User_UserGrowth ensureUserGrowth() => $_ensure(28);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
