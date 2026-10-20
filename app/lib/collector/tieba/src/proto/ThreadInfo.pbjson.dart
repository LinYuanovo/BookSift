// This is a generated file - do not edit.
//
// Generated from ThreadInfo.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use threadInfoDescriptor instead')
const ThreadInfo$json = {
  '1': 'ThreadInfo',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'title', '3': 3, '4': 1, '5': 9, '10': 'title'},
    {'1': 'reply_num', '3': 4, '4': 1, '5': 5, '10': 'replyNum'},
    {'1': 'view_num', '3': 5, '4': 1, '5': 5, '10': 'viewNum'},
    {'1': 'last_time_int', '3': 7, '4': 1, '5': 5, '10': 'lastTimeInt'},
    {'1': 'is_top', '3': 9, '4': 1, '5': 5, '10': 'isTop'},
    {'1': 'is_good', '3': 10, '4': 1, '5': 5, '10': 'isGood'},
    {'1': 'is_voice_thread', '3': 15, '4': 1, '5': 5, '10': 'isVoiceThread'},
    {'1': 'author', '3': 18, '4': 1, '5': 11, '6': '.User', '10': 'author'},
    {
      '1': 'last_replyer',
      '3': 19,
      '4': 1,
      '5': 11,
      '6': '.User',
      '10': 'lastReplyer'
    },
    {
      '1': 'voice_info',
      '3': 23,
      '4': 3,
      '5': 11,
      '6': '.Voice',
      '10': 'voiceInfo'
    },
    {'1': 'thread_type', '3': 26, '4': 1, '5': 5, '10': 'threadType'},
    {'1': 'fid', '3': 27, '4': 1, '5': 3, '10': 'fid'},
    {'1': 'fname', '3': 28, '4': 1, '5': 9, '10': 'fname'},
    {'1': 'is_livepost', '3': 30, '4': 1, '5': 5, '10': 'isLivepost'},
    {'1': 'first_post_id', '3': 40, '4': 1, '5': 3, '10': 'firstPostId'},
    {'1': 'create_time', '3': 45, '4': 1, '5': 5, '10': 'createTime'},
    {'1': 'post_id', '3': 52, '4': 1, '5': 3, '10': 'postId'},
    {'1': 'author_id', '3': 56, '4': 1, '5': 3, '10': 'authorId'},
    {'1': 'valid_post_num', '3': 57, '4': 1, '5': 13, '10': 'validPostNum'},
    {'1': 'is_ad', '3': 59, '4': 1, '5': 13, '10': 'isAd'},
    {
      '1': 'poll_info',
      '3': 74,
      '4': 1,
      '5': 11,
      '6': '.PollInfo',
      '10': 'pollInfo'
    },
    {
      '1': 'video_info',
      '3': 79,
      '4': 1,
      '5': 11,
      '6': '.VideoInfo',
      '10': 'videoInfo'
    },
    {'1': 'agree', '3': 126, '4': 1, '5': 11, '6': '.Agree', '10': 'agree'},
    {'1': 'share_num', '3': 135, '4': 1, '5': 5, '10': 'shareNum'},
    {
      '1': 'origin_thread_info',
      '3': 141,
      '4': 1,
      '5': 11,
      '6': '.ThreadInfo.OriginThreadInfo',
      '10': 'originThreadInfo'
    },
    {
      '1': 'first_post_content',
      '3': 142,
      '4': 3,
      '5': 11,
      '6': '.PbContent',
      '10': 'firstPostContent'
    },
    {'1': 'is_share_thread', '3': 143, '4': 1, '5': 5, '10': 'isShareThread'},
    {'1': 'tab_id', '3': 175, '4': 1, '5': 5, '10': 'tabId'},
    {'1': 'is_deleted', '3': 181, '4': 1, '5': 5, '10': 'isDeleted'},
    {'1': 'collect_num', '3': 190, '4': 1, '5': 13, '10': 'collectNum'},
    {'1': 'is_frs_mask', '3': 198, '4': 1, '5': 5, '10': 'isFrsMask'},
  ],
  '3': [ThreadInfo_OriginThreadInfo$json],
};

@$core.Deprecated('Use threadInfoDescriptor instead')
const ThreadInfo_OriginThreadInfo$json = {
  '1': 'OriginThreadInfo',
  '2': [
    {'1': 'title', '3': 1, '4': 1, '5': 9, '10': 'title'},
    {'1': 'media', '3': 2, '4': 3, '5': 11, '6': '.Media', '10': 'media'},
    {'1': 'fname', '3': 4, '4': 1, '5': 9, '10': 'fname'},
    {'1': 'tid', '3': 5, '4': 1, '5': 9, '10': 'tid'},
    {'1': 'fid', '3': 7, '4': 1, '5': 3, '10': 'fid'},
    {'1': 'thread_type', '3': 8, '4': 1, '5': 5, '10': 'threadType'},
    {'1': 'is_deleted', '3': 9, '4': 1, '5': 5, '10': 'isDeleted'},
    {
      '1': 'voice_info',
      '3': 12,
      '4': 3,
      '5': 11,
      '6': '.Voice',
      '10': 'voiceInfo'
    },
    {
      '1': 'video_info',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.VideoInfo',
      '10': 'videoInfo'
    },
    {
      '1': 'content',
      '3': 14,
      '4': 3,
      '5': 11,
      '6': '.PbContent',
      '10': 'content'
    },
    {'1': 'reply_num', '3': 16, '4': 1, '5': 5, '10': 'replyNum'},
    {'1': 'author', '3': 18, '4': 1, '5': 11, '6': '.User', '10': 'author'},
    {'1': 'agree', '3': 19, '4': 1, '5': 11, '6': '.Agree', '10': 'agree'},
    {'1': 'shared_num', '3': 20, '4': 1, '5': 5, '10': 'sharedNum'},
    {
      '1': 'poll_info',
      '3': 21,
      '4': 1,
      '5': 11,
      '6': '.PollInfo',
      '10': 'pollInfo'
    },
    {'1': 'pid', '3': 25, '4': 1, '5': 3, '10': 'pid'},
  ],
};

/// Descriptor for `ThreadInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List threadInfoDescriptor = $convert.base64Decode(
    'CgpUaHJlYWRJbmZvEg4KAmlkGAEgASgDUgJpZBIUCgV0aXRsZRgDIAEoCVIFdGl0bGUSGwoJcm'
    'VwbHlfbnVtGAQgASgFUghyZXBseU51bRIZCgh2aWV3X251bRgFIAEoBVIHdmlld051bRIiCg1s'
    'YXN0X3RpbWVfaW50GAcgASgFUgtsYXN0VGltZUludBIVCgZpc190b3AYCSABKAVSBWlzVG9wEh'
    'cKB2lzX2dvb2QYCiABKAVSBmlzR29vZBImCg9pc192b2ljZV90aHJlYWQYDyABKAVSDWlzVm9p'
    'Y2VUaHJlYWQSHQoGYXV0aG9yGBIgASgLMgUuVXNlclIGYXV0aG9yEigKDGxhc3RfcmVwbHllch'
    'gTIAEoCzIFLlVzZXJSC2xhc3RSZXBseWVyEiUKCnZvaWNlX2luZm8YFyADKAsyBi5Wb2ljZVIJ'
    'dm9pY2VJbmZvEh8KC3RocmVhZF90eXBlGBogASgFUgp0aHJlYWRUeXBlEhAKA2ZpZBgbIAEoA1'
    'IDZmlkEhQKBWZuYW1lGBwgASgJUgVmbmFtZRIfCgtpc19saXZlcG9zdBgeIAEoBVIKaXNMaXZl'
    'cG9zdBIiCg1maXJzdF9wb3N0X2lkGCggASgDUgtmaXJzdFBvc3RJZBIfCgtjcmVhdGVfdGltZR'
    'gtIAEoBVIKY3JlYXRlVGltZRIXCgdwb3N0X2lkGDQgASgDUgZwb3N0SWQSGwoJYXV0aG9yX2lk'
    'GDggASgDUghhdXRob3JJZBIkCg52YWxpZF9wb3N0X251bRg5IAEoDVIMdmFsaWRQb3N0TnVtEh'
    'MKBWlzX2FkGDsgASgNUgRpc0FkEiYKCXBvbGxfaW5mbxhKIAEoCzIJLlBvbGxJbmZvUghwb2xs'
    'SW5mbxIpCgp2aWRlb19pbmZvGE8gASgLMgouVmlkZW9JbmZvUgl2aWRlb0luZm8SHAoFYWdyZW'
    'UYfiABKAsyBi5BZ3JlZVIFYWdyZWUSHAoJc2hhcmVfbnVtGIcBIAEoBVIIc2hhcmVOdW0SSwoS'
    'b3JpZ2luX3RocmVhZF9pbmZvGI0BIAEoCzIcLlRocmVhZEluZm8uT3JpZ2luVGhyZWFkSW5mb1'
    'IQb3JpZ2luVGhyZWFkSW5mbxI5ChJmaXJzdF9wb3N0X2NvbnRlbnQYjgEgAygLMgouUGJDb250'
    'ZW50UhBmaXJzdFBvc3RDb250ZW50EicKD2lzX3NoYXJlX3RocmVhZBiPASABKAVSDWlzU2hhcm'
    'VUaHJlYWQSFgoGdGFiX2lkGK8BIAEoBVIFdGFiSWQSHgoKaXNfZGVsZXRlZBi1ASABKAVSCWlz'
    'RGVsZXRlZBIgCgtjb2xsZWN0X251bRi+ASABKA1SCmNvbGxlY3ROdW0SHwoLaXNfZnJzX21hc2'
    'sYxgEgASgFUglpc0Zyc01hc2sa6wMKEE9yaWdpblRocmVhZEluZm8SFAoFdGl0bGUYASABKAlS'
    'BXRpdGxlEhwKBW1lZGlhGAIgAygLMgYuTWVkaWFSBW1lZGlhEhQKBWZuYW1lGAQgASgJUgVmbm'
    'FtZRIQCgN0aWQYBSABKAlSA3RpZBIQCgNmaWQYByABKANSA2ZpZBIfCgt0aHJlYWRfdHlwZRgI'
    'IAEoBVIKdGhyZWFkVHlwZRIdCgppc19kZWxldGVkGAkgASgFUglpc0RlbGV0ZWQSJQoKdm9pY2'
    'VfaW5mbxgMIAMoCzIGLlZvaWNlUgl2b2ljZUluZm8SKQoKdmlkZW9faW5mbxgNIAEoCzIKLlZp'
    'ZGVvSW5mb1IJdmlkZW9JbmZvEiQKB2NvbnRlbnQYDiADKAsyCi5QYkNvbnRlbnRSB2NvbnRlbn'
    'QSGwoJcmVwbHlfbnVtGBAgASgFUghyZXBseU51bRIdCgZhdXRob3IYEiABKAsyBS5Vc2VyUgZh'
    'dXRob3ISHAoFYWdyZWUYEyABKAsyBi5BZ3JlZVIFYWdyZWUSHQoKc2hhcmVkX251bRgUIAEoBV'
    'IJc2hhcmVkTnVtEiYKCXBvbGxfaW5mbxgVIAEoCzIJLlBvbGxJbmZvUghwb2xsSW5mbxIQCgNw'
    'aWQYGSABKANSA3BpZA==');
