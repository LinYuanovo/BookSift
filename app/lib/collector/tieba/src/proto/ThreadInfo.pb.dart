// This is a generated file - do not edit.
//
// Generated from ThreadInfo.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'Agree.pb.dart' as $4;
import 'Media.pb.dart' as $6;
import 'PbContent.pb.dart' as $5;
import 'PollInfo.pb.dart' as $2;
import 'User.pb.dart' as $0;
import 'VideoInfo.pb.dart' as $3;
import 'Voice.pb.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class ThreadInfo_OriginThreadInfo extends $pb.GeneratedMessage {
  factory ThreadInfo_OriginThreadInfo({
    $core.String? title,
    $core.Iterable<$6.Media>? media,
    $core.String? fname,
    $core.String? tid,
    $fixnum.Int64? fid,
    $core.int? threadType,
    $core.int? isDeleted,
    $core.Iterable<$1.Voice>? voiceInfo,
    $3.VideoInfo? videoInfo,
    $core.Iterable<$5.PbContent>? content,
    $core.int? replyNum,
    $0.User? author,
    $4.Agree? agree,
    $core.int? sharedNum,
    $2.PollInfo? pollInfo,
    $fixnum.Int64? pid,
  }) {
    final result = ThreadInfo_OriginThreadInfo._();
    if (title != null) result.title = title;
    if (media != null) result.media.addAll(media);
    if (fname != null) result.fname = fname;
    if (tid != null) result.tid = tid;
    if (fid != null) result.fid = fid;
    if (threadType != null) result.threadType = threadType;
    if (isDeleted != null) result.isDeleted = isDeleted;
    if (voiceInfo != null) result.voiceInfo.addAll(voiceInfo);
    if (videoInfo != null) result.videoInfo = videoInfo;
    if (content != null) result.content.addAll(content);
    if (replyNum != null) result.replyNum = replyNum;
    if (author != null) result.author = author;
    if (agree != null) result.agree = agree;
    if (sharedNum != null) result.sharedNum = sharedNum;
    if (pollInfo != null) result.pollInfo = pollInfo;
    if (pid != null) result.pid = pid;
    return result;
  }

  ThreadInfo_OriginThreadInfo._();

  factory ThreadInfo_OriginThreadInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ThreadInfo_OriginThreadInfo()..mergeFromBuffer(data, registry);
  factory ThreadInfo_OriginThreadInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ThreadInfo_OriginThreadInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ThreadInfo.OriginThreadInfo',
      createEmptyInstance: ThreadInfo_OriginThreadInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'title')
    ..pPM<$6.Media>(2, _omitFieldNames ? '' : 'media',
        subBuilder: $6.Media.$_createMessage)
    ..aOS(4, _omitFieldNames ? '' : 'fname')
    ..aOS(5, _omitFieldNames ? '' : 'tid')
    ..aInt64(7, _omitFieldNames ? '' : 'fid')
    ..aI(8, _omitFieldNames ? '' : 'threadType')
    ..aI(9, _omitFieldNames ? '' : 'isDeleted')
    ..pPM<$1.Voice>(12, _omitFieldNames ? '' : 'voiceInfo',
        subBuilder: $1.Voice.$_createMessage)
    ..aOM<$3.VideoInfo>(13, _omitFieldNames ? '' : 'videoInfo',
        subBuilder: $3.VideoInfo.$_createMessage)
    ..pPM<$5.PbContent>(14, _omitFieldNames ? '' : 'content',
        subBuilder: $5.PbContent.$_createMessage)
    ..aI(16, _omitFieldNames ? '' : 'replyNum')
    ..aOM<$0.User>(18, _omitFieldNames ? '' : 'author',
        subBuilder: $0.User.$_createMessage)
    ..aOM<$4.Agree>(19, _omitFieldNames ? '' : 'agree',
        subBuilder: $4.Agree.$_createMessage)
    ..aI(20, _omitFieldNames ? '' : 'sharedNum')
    ..aOM<$2.PollInfo>(21, _omitFieldNames ? '' : 'pollInfo',
        subBuilder: $2.PollInfo.$_createMessage)
    ..aInt64(25, _omitFieldNames ? '' : 'pid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ThreadInfo_OriginThreadInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ThreadInfo_OriginThreadInfo copyWith(
          void Function(ThreadInfo_OriginThreadInfo) updates) =>
      super.copyWith(
              (message) => updates(message as ThreadInfo_OriginThreadInfo))
          as ThreadInfo_OriginThreadInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ThreadInfo_OriginThreadInfo() / ThreadInfo_OriginThreadInfo.new instead')
  static ThreadInfo_OriginThreadInfo create() =>
      ThreadInfo_OriginThreadInfo._();
  static $pb.GeneratedMessage $_createMessage() =>
      ThreadInfo_OriginThreadInfo._();
  @$core.override
  ThreadInfo_OriginThreadInfo createEmptyInstance() =>
      ThreadInfo_OriginThreadInfo._();
  @$core.pragma('dart2js:noInline')
  static ThreadInfo_OriginThreadInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ThreadInfo_OriginThreadInfo>(
          ThreadInfo_OriginThreadInfo.$_createMessage);
  static ThreadInfo_OriginThreadInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get title => $_getSZ(0);
  @$pb.TagNumber(1)
  set title($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearTitle() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$6.Media> get media => $_getList(1);

  @$pb.TagNumber(4)
  $core.String get fname => $_getSZ(2);
  @$pb.TagNumber(4)
  set fname($core.String value) => $_setString(2, value);
  @$pb.TagNumber(4)
  $core.bool hasFname() => $_has(2);
  @$pb.TagNumber(4)
  void clearFname() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get tid => $_getSZ(3);
  @$pb.TagNumber(5)
  set tid($core.String value) => $_setString(3, value);
  @$pb.TagNumber(5)
  $core.bool hasTid() => $_has(3);
  @$pb.TagNumber(5)
  void clearTid() => $_clearField(5);

  @$pb.TagNumber(7)
  $fixnum.Int64 get fid => $_getI64(4);
  @$pb.TagNumber(7)
  set fid($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(7)
  $core.bool hasFid() => $_has(4);
  @$pb.TagNumber(7)
  void clearFid() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get threadType => $_getIZ(5);
  @$pb.TagNumber(8)
  set threadType($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(8)
  $core.bool hasThreadType() => $_has(5);
  @$pb.TagNumber(8)
  void clearThreadType() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get isDeleted => $_getIZ(6);
  @$pb.TagNumber(9)
  set isDeleted($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(9)
  $core.bool hasIsDeleted() => $_has(6);
  @$pb.TagNumber(9)
  void clearIsDeleted() => $_clearField(9);

  @$pb.TagNumber(12)
  $pb.PbList<$1.Voice> get voiceInfo => $_getList(7);

  @$pb.TagNumber(13)
  $3.VideoInfo get videoInfo => $_getN(8);
  @$pb.TagNumber(13)
  set videoInfo($3.VideoInfo value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasVideoInfo() => $_has(8);
  @$pb.TagNumber(13)
  void clearVideoInfo() => $_clearField(13);
  @$pb.TagNumber(13)
  $3.VideoInfo ensureVideoInfo() => $_ensure(8);

  @$pb.TagNumber(14)
  $pb.PbList<$5.PbContent> get content => $_getList(9);

  @$pb.TagNumber(16)
  $core.int get replyNum => $_getIZ(10);
  @$pb.TagNumber(16)
  set replyNum($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(16)
  $core.bool hasReplyNum() => $_has(10);
  @$pb.TagNumber(16)
  void clearReplyNum() => $_clearField(16);

  @$pb.TagNumber(18)
  $0.User get author => $_getN(11);
  @$pb.TagNumber(18)
  set author($0.User value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasAuthor() => $_has(11);
  @$pb.TagNumber(18)
  void clearAuthor() => $_clearField(18);
  @$pb.TagNumber(18)
  $0.User ensureAuthor() => $_ensure(11);

  @$pb.TagNumber(19)
  $4.Agree get agree => $_getN(12);
  @$pb.TagNumber(19)
  set agree($4.Agree value) => $_setField(19, value);
  @$pb.TagNumber(19)
  $core.bool hasAgree() => $_has(12);
  @$pb.TagNumber(19)
  void clearAgree() => $_clearField(19);
  @$pb.TagNumber(19)
  $4.Agree ensureAgree() => $_ensure(12);

  @$pb.TagNumber(20)
  $core.int get sharedNum => $_getIZ(13);
  @$pb.TagNumber(20)
  set sharedNum($core.int value) => $_setSignedInt32(13, value);
  @$pb.TagNumber(20)
  $core.bool hasSharedNum() => $_has(13);
  @$pb.TagNumber(20)
  void clearSharedNum() => $_clearField(20);

  @$pb.TagNumber(21)
  $2.PollInfo get pollInfo => $_getN(14);
  @$pb.TagNumber(21)
  set pollInfo($2.PollInfo value) => $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasPollInfo() => $_has(14);
  @$pb.TagNumber(21)
  void clearPollInfo() => $_clearField(21);
  @$pb.TagNumber(21)
  $2.PollInfo ensurePollInfo() => $_ensure(14);

  @$pb.TagNumber(25)
  $fixnum.Int64 get pid => $_getI64(15);
  @$pb.TagNumber(25)
  set pid($fixnum.Int64 value) => $_setInt64(15, value);
  @$pb.TagNumber(25)
  $core.bool hasPid() => $_has(15);
  @$pb.TagNumber(25)
  void clearPid() => $_clearField(25);
}

class ThreadInfo extends $pb.GeneratedMessage {
  factory ThreadInfo({
    $fixnum.Int64? id,
    $core.String? title,
    $core.int? replyNum,
    $core.int? viewNum,
    $core.int? lastTimeInt,
    $core.int? isTop,
    $core.int? isGood,
    $core.int? isVoiceThread,
    $0.User? author,
    $0.User? lastReplyer,
    $core.Iterable<$1.Voice>? voiceInfo,
    $core.int? threadType,
    $fixnum.Int64? fid,
    $core.String? fname,
    $core.int? isLivepost,
    $fixnum.Int64? firstPostId,
    $core.int? createTime,
    $fixnum.Int64? postId,
    $fixnum.Int64? authorId,
    $core.int? validPostNum,
    $core.int? isAd,
    $2.PollInfo? pollInfo,
    $3.VideoInfo? videoInfo,
    $4.Agree? agree,
    $core.int? shareNum,
    ThreadInfo_OriginThreadInfo? originThreadInfo,
    $core.Iterable<$5.PbContent>? firstPostContent,
    $core.int? isShareThread,
    $core.int? tabId,
    $core.int? isDeleted,
    $core.int? collectNum,
    $core.int? isFrsMask,
  }) {
    final result = ThreadInfo._();
    if (id != null) result.id = id;
    if (title != null) result.title = title;
    if (replyNum != null) result.replyNum = replyNum;
    if (viewNum != null) result.viewNum = viewNum;
    if (lastTimeInt != null) result.lastTimeInt = lastTimeInt;
    if (isTop != null) result.isTop = isTop;
    if (isGood != null) result.isGood = isGood;
    if (isVoiceThread != null) result.isVoiceThread = isVoiceThread;
    if (author != null) result.author = author;
    if (lastReplyer != null) result.lastReplyer = lastReplyer;
    if (voiceInfo != null) result.voiceInfo.addAll(voiceInfo);
    if (threadType != null) result.threadType = threadType;
    if (fid != null) result.fid = fid;
    if (fname != null) result.fname = fname;
    if (isLivepost != null) result.isLivepost = isLivepost;
    if (firstPostId != null) result.firstPostId = firstPostId;
    if (createTime != null) result.createTime = createTime;
    if (postId != null) result.postId = postId;
    if (authorId != null) result.authorId = authorId;
    if (validPostNum != null) result.validPostNum = validPostNum;
    if (isAd != null) result.isAd = isAd;
    if (pollInfo != null) result.pollInfo = pollInfo;
    if (videoInfo != null) result.videoInfo = videoInfo;
    if (agree != null) result.agree = agree;
    if (shareNum != null) result.shareNum = shareNum;
    if (originThreadInfo != null) result.originThreadInfo = originThreadInfo;
    if (firstPostContent != null)
      result.firstPostContent.addAll(firstPostContent);
    if (isShareThread != null) result.isShareThread = isShareThread;
    if (tabId != null) result.tabId = tabId;
    if (isDeleted != null) result.isDeleted = isDeleted;
    if (collectNum != null) result.collectNum = collectNum;
    if (isFrsMask != null) result.isFrsMask = isFrsMask;
    return result;
  }

  ThreadInfo._();

  factory ThreadInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ThreadInfo()..mergeFromBuffer(data, registry);
  factory ThreadInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ThreadInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ThreadInfo',
      createEmptyInstance: ThreadInfo.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aOS(3, _omitFieldNames ? '' : 'title')
    ..aI(4, _omitFieldNames ? '' : 'replyNum')
    ..aI(5, _omitFieldNames ? '' : 'viewNum')
    ..aI(7, _omitFieldNames ? '' : 'lastTimeInt')
    ..aI(9, _omitFieldNames ? '' : 'isTop')
    ..aI(10, _omitFieldNames ? '' : 'isGood')
    ..aI(15, _omitFieldNames ? '' : 'isVoiceThread')
    ..aOM<$0.User>(18, _omitFieldNames ? '' : 'author',
        subBuilder: $0.User.$_createMessage)
    ..aOM<$0.User>(19, _omitFieldNames ? '' : 'lastReplyer',
        subBuilder: $0.User.$_createMessage)
    ..pPM<$1.Voice>(23, _omitFieldNames ? '' : 'voiceInfo',
        subBuilder: $1.Voice.$_createMessage)
    ..aI(26, _omitFieldNames ? '' : 'threadType')
    ..aInt64(27, _omitFieldNames ? '' : 'fid')
    ..aOS(28, _omitFieldNames ? '' : 'fname')
    ..aI(30, _omitFieldNames ? '' : 'isLivepost')
    ..aInt64(40, _omitFieldNames ? '' : 'firstPostId')
    ..aI(45, _omitFieldNames ? '' : 'createTime')
    ..aInt64(52, _omitFieldNames ? '' : 'postId')
    ..aInt64(56, _omitFieldNames ? '' : 'authorId')
    ..aI(57, _omitFieldNames ? '' : 'validPostNum',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(59, _omitFieldNames ? '' : 'isAd', fieldType: $pb.PbFieldType.OU3)
    ..aOM<$2.PollInfo>(74, _omitFieldNames ? '' : 'pollInfo',
        subBuilder: $2.PollInfo.$_createMessage)
    ..aOM<$3.VideoInfo>(79, _omitFieldNames ? '' : 'videoInfo',
        subBuilder: $3.VideoInfo.$_createMessage)
    ..aOM<$4.Agree>(126, _omitFieldNames ? '' : 'agree',
        subBuilder: $4.Agree.$_createMessage)
    ..aI(135, _omitFieldNames ? '' : 'shareNum')
    ..aOM<ThreadInfo_OriginThreadInfo>(
        141, _omitFieldNames ? '' : 'originThreadInfo',
        subBuilder: ThreadInfo_OriginThreadInfo.$_createMessage)
    ..pPM<$5.PbContent>(142, _omitFieldNames ? '' : 'firstPostContent',
        subBuilder: $5.PbContent.$_createMessage)
    ..aI(143, _omitFieldNames ? '' : 'isShareThread')
    ..aI(175, _omitFieldNames ? '' : 'tabId')
    ..aI(181, _omitFieldNames ? '' : 'isDeleted')
    ..aI(190, _omitFieldNames ? '' : 'collectNum',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(198, _omitFieldNames ? '' : 'isFrsMask')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ThreadInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ThreadInfo copyWith(void Function(ThreadInfo) updates) =>
      super.copyWith((message) => updates(message as ThreadInfo)) as ThreadInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ThreadInfo() / ThreadInfo.new instead')
  static ThreadInfo create() => ThreadInfo._();
  static $pb.GeneratedMessage $_createMessage() => ThreadInfo._();
  @$core.override
  ThreadInfo createEmptyInstance() => ThreadInfo._();
  @$core.pragma('dart2js:noInline')
  static ThreadInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ThreadInfo>(ThreadInfo.$_createMessage);
  static ThreadInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(3)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(3)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(3)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(3)
  void clearTitle() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get replyNum => $_getIZ(2);
  @$pb.TagNumber(4)
  set replyNum($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(4)
  $core.bool hasReplyNum() => $_has(2);
  @$pb.TagNumber(4)
  void clearReplyNum() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get viewNum => $_getIZ(3);
  @$pb.TagNumber(5)
  set viewNum($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(5)
  $core.bool hasViewNum() => $_has(3);
  @$pb.TagNumber(5)
  void clearViewNum() => $_clearField(5);

  @$pb.TagNumber(7)
  $core.int get lastTimeInt => $_getIZ(4);
  @$pb.TagNumber(7)
  set lastTimeInt($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(7)
  $core.bool hasLastTimeInt() => $_has(4);
  @$pb.TagNumber(7)
  void clearLastTimeInt() => $_clearField(7);

  @$pb.TagNumber(9)
  $core.int get isTop => $_getIZ(5);
  @$pb.TagNumber(9)
  set isTop($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(9)
  $core.bool hasIsTop() => $_has(5);
  @$pb.TagNumber(9)
  void clearIsTop() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get isGood => $_getIZ(6);
  @$pb.TagNumber(10)
  set isGood($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(10)
  $core.bool hasIsGood() => $_has(6);
  @$pb.TagNumber(10)
  void clearIsGood() => $_clearField(10);

  @$pb.TagNumber(15)
  $core.int get isVoiceThread => $_getIZ(7);
  @$pb.TagNumber(15)
  set isVoiceThread($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(15)
  $core.bool hasIsVoiceThread() => $_has(7);
  @$pb.TagNumber(15)
  void clearIsVoiceThread() => $_clearField(15);

  @$pb.TagNumber(18)
  $0.User get author => $_getN(8);
  @$pb.TagNumber(18)
  set author($0.User value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasAuthor() => $_has(8);
  @$pb.TagNumber(18)
  void clearAuthor() => $_clearField(18);
  @$pb.TagNumber(18)
  $0.User ensureAuthor() => $_ensure(8);

  @$pb.TagNumber(19)
  $0.User get lastReplyer => $_getN(9);
  @$pb.TagNumber(19)
  set lastReplyer($0.User value) => $_setField(19, value);
  @$pb.TagNumber(19)
  $core.bool hasLastReplyer() => $_has(9);
  @$pb.TagNumber(19)
  void clearLastReplyer() => $_clearField(19);
  @$pb.TagNumber(19)
  $0.User ensureLastReplyer() => $_ensure(9);

  @$pb.TagNumber(23)
  $pb.PbList<$1.Voice> get voiceInfo => $_getList(10);

  @$pb.TagNumber(26)
  $core.int get threadType => $_getIZ(11);
  @$pb.TagNumber(26)
  set threadType($core.int value) => $_setSignedInt32(11, value);
  @$pb.TagNumber(26)
  $core.bool hasThreadType() => $_has(11);
  @$pb.TagNumber(26)
  void clearThreadType() => $_clearField(26);

  @$pb.TagNumber(27)
  $fixnum.Int64 get fid => $_getI64(12);
  @$pb.TagNumber(27)
  set fid($fixnum.Int64 value) => $_setInt64(12, value);
  @$pb.TagNumber(27)
  $core.bool hasFid() => $_has(12);
  @$pb.TagNumber(27)
  void clearFid() => $_clearField(27);

  @$pb.TagNumber(28)
  $core.String get fname => $_getSZ(13);
  @$pb.TagNumber(28)
  set fname($core.String value) => $_setString(13, value);
  @$pb.TagNumber(28)
  $core.bool hasFname() => $_has(13);
  @$pb.TagNumber(28)
  void clearFname() => $_clearField(28);

  @$pb.TagNumber(30)
  $core.int get isLivepost => $_getIZ(14);
  @$pb.TagNumber(30)
  set isLivepost($core.int value) => $_setSignedInt32(14, value);
  @$pb.TagNumber(30)
  $core.bool hasIsLivepost() => $_has(14);
  @$pb.TagNumber(30)
  void clearIsLivepost() => $_clearField(30);

  @$pb.TagNumber(40)
  $fixnum.Int64 get firstPostId => $_getI64(15);
  @$pb.TagNumber(40)
  set firstPostId($fixnum.Int64 value) => $_setInt64(15, value);
  @$pb.TagNumber(40)
  $core.bool hasFirstPostId() => $_has(15);
  @$pb.TagNumber(40)
  void clearFirstPostId() => $_clearField(40);

  @$pb.TagNumber(45)
  $core.int get createTime => $_getIZ(16);
  @$pb.TagNumber(45)
  set createTime($core.int value) => $_setSignedInt32(16, value);
  @$pb.TagNumber(45)
  $core.bool hasCreateTime() => $_has(16);
  @$pb.TagNumber(45)
  void clearCreateTime() => $_clearField(45);

  @$pb.TagNumber(52)
  $fixnum.Int64 get postId => $_getI64(17);
  @$pb.TagNumber(52)
  set postId($fixnum.Int64 value) => $_setInt64(17, value);
  @$pb.TagNumber(52)
  $core.bool hasPostId() => $_has(17);
  @$pb.TagNumber(52)
  void clearPostId() => $_clearField(52);

  @$pb.TagNumber(56)
  $fixnum.Int64 get authorId => $_getI64(18);
  @$pb.TagNumber(56)
  set authorId($fixnum.Int64 value) => $_setInt64(18, value);
  @$pb.TagNumber(56)
  $core.bool hasAuthorId() => $_has(18);
  @$pb.TagNumber(56)
  void clearAuthorId() => $_clearField(56);

  @$pb.TagNumber(57)
  $core.int get validPostNum => $_getIZ(19);
  @$pb.TagNumber(57)
  set validPostNum($core.int value) => $_setUnsignedInt32(19, value);
  @$pb.TagNumber(57)
  $core.bool hasValidPostNum() => $_has(19);
  @$pb.TagNumber(57)
  void clearValidPostNum() => $_clearField(57);

  @$pb.TagNumber(59)
  $core.int get isAd => $_getIZ(20);
  @$pb.TagNumber(59)
  set isAd($core.int value) => $_setUnsignedInt32(20, value);
  @$pb.TagNumber(59)
  $core.bool hasIsAd() => $_has(20);
  @$pb.TagNumber(59)
  void clearIsAd() => $_clearField(59);

  @$pb.TagNumber(74)
  $2.PollInfo get pollInfo => $_getN(21);
  @$pb.TagNumber(74)
  set pollInfo($2.PollInfo value) => $_setField(74, value);
  @$pb.TagNumber(74)
  $core.bool hasPollInfo() => $_has(21);
  @$pb.TagNumber(74)
  void clearPollInfo() => $_clearField(74);
  @$pb.TagNumber(74)
  $2.PollInfo ensurePollInfo() => $_ensure(21);

  @$pb.TagNumber(79)
  $3.VideoInfo get videoInfo => $_getN(22);
  @$pb.TagNumber(79)
  set videoInfo($3.VideoInfo value) => $_setField(79, value);
  @$pb.TagNumber(79)
  $core.bool hasVideoInfo() => $_has(22);
  @$pb.TagNumber(79)
  void clearVideoInfo() => $_clearField(79);
  @$pb.TagNumber(79)
  $3.VideoInfo ensureVideoInfo() => $_ensure(22);

  @$pb.TagNumber(126)
  $4.Agree get agree => $_getN(23);
  @$pb.TagNumber(126)
  set agree($4.Agree value) => $_setField(126, value);
  @$pb.TagNumber(126)
  $core.bool hasAgree() => $_has(23);
  @$pb.TagNumber(126)
  void clearAgree() => $_clearField(126);
  @$pb.TagNumber(126)
  $4.Agree ensureAgree() => $_ensure(23);

  @$pb.TagNumber(135)
  $core.int get shareNum => $_getIZ(24);
  @$pb.TagNumber(135)
  set shareNum($core.int value) => $_setSignedInt32(24, value);
  @$pb.TagNumber(135)
  $core.bool hasShareNum() => $_has(24);
  @$pb.TagNumber(135)
  void clearShareNum() => $_clearField(135);

  @$pb.TagNumber(141)
  ThreadInfo_OriginThreadInfo get originThreadInfo => $_getN(25);
  @$pb.TagNumber(141)
  set originThreadInfo(ThreadInfo_OriginThreadInfo value) =>
      $_setField(141, value);
  @$pb.TagNumber(141)
  $core.bool hasOriginThreadInfo() => $_has(25);
  @$pb.TagNumber(141)
  void clearOriginThreadInfo() => $_clearField(141);
  @$pb.TagNumber(141)
  ThreadInfo_OriginThreadInfo ensureOriginThreadInfo() => $_ensure(25);

  @$pb.TagNumber(142)
  $pb.PbList<$5.PbContent> get firstPostContent => $_getList(26);

  @$pb.TagNumber(143)
  $core.int get isShareThread => $_getIZ(27);
  @$pb.TagNumber(143)
  set isShareThread($core.int value) => $_setSignedInt32(27, value);
  @$pb.TagNumber(143)
  $core.bool hasIsShareThread() => $_has(27);
  @$pb.TagNumber(143)
  void clearIsShareThread() => $_clearField(143);

  @$pb.TagNumber(175)
  $core.int get tabId => $_getIZ(28);
  @$pb.TagNumber(175)
  set tabId($core.int value) => $_setSignedInt32(28, value);
  @$pb.TagNumber(175)
  $core.bool hasTabId() => $_has(28);
  @$pb.TagNumber(175)
  void clearTabId() => $_clearField(175);

  @$pb.TagNumber(181)
  $core.int get isDeleted => $_getIZ(29);
  @$pb.TagNumber(181)
  set isDeleted($core.int value) => $_setSignedInt32(29, value);
  @$pb.TagNumber(181)
  $core.bool hasIsDeleted() => $_has(29);
  @$pb.TagNumber(181)
  void clearIsDeleted() => $_clearField(181);

  @$pb.TagNumber(190)
  $core.int get collectNum => $_getIZ(30);
  @$pb.TagNumber(190)
  set collectNum($core.int value) => $_setUnsignedInt32(30, value);
  @$pb.TagNumber(190)
  $core.bool hasCollectNum() => $_has(30);
  @$pb.TagNumber(190)
  void clearCollectNum() => $_clearField(190);

  @$pb.TagNumber(198)
  $core.int get isFrsMask => $_getIZ(31);
  @$pb.TagNumber(198)
  set isFrsMask($core.int value) => $_setSignedInt32(31, value);
  @$pb.TagNumber(198)
  $core.bool hasIsFrsMask() => $_has(31);
  @$pb.TagNumber(198)
  void clearIsFrsMask() => $_clearField(198);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
