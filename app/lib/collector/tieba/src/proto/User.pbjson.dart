// This is a generated file - do not edit.
//
// Generated from User.proto.

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

@$core.Deprecated('Use userDescriptor instead')
const User$json = {
  '1': 'User',
  '2': [
    {'1': 'id', '3': 2, '4': 1, '5': 3, '10': 'id'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'name_show', '3': 4, '4': 1, '5': 9, '10': 'nameShow'},
    {'1': 'portrait', '3': 5, '4': 1, '5': 9, '10': 'portrait'},
    {
      '1': 'iconinfo',
      '3': 17,
      '4': 3,
      '5': 11,
      '6': '.User.Icon',
      '10': 'iconinfo'
    },
    {'1': 'is_coreuser', '3': 20, '4': 1, '5': 5, '10': 'isCoreuser'},
    {'1': 'level_id', '3': 23, '4': 1, '5': 5, '10': 'levelId'},
    {'1': 'is_bawu', '3': 25, '4': 1, '5': 5, '10': 'isBawu'},
    {'1': 'bawu_type', '3': 26, '4': 1, '5': 9, '10': 'bawuType'},
    {'1': 'BDUSS', '3': 29, '4': 1, '5': 9, '10': 'BDUSS'},
    {'1': 'fans_num', '3': 30, '4': 1, '5': 5, '10': 'fansNum'},
    {'1': 'concern_num', '3': 31, '4': 1, '5': 5, '10': 'concernNum'},
    {'1': 'sex', '3': 32, '4': 1, '5': 5, '10': 'sex'},
    {'1': 'my_like_num', '3': 33, '4': 1, '5': 5, '10': 'myLikeNum'},
    {'1': 'intro', '3': 34, '4': 1, '5': 9, '10': 'intro'},
    {'1': 'post_num', '3': 37, '4': 1, '5': 5, '10': 'postNum'},
    {'1': 'tb_age', '3': 38, '4': 1, '5': 9, '10': 'tbAge'},
    {'1': 'is_mem', '3': 39, '4': 1, '5': 5, '10': 'isMem'},
    {'1': 'gender', '3': 42, '4': 1, '5': 5, '10': 'gender'},
    {
      '1': 'priv_sets',
      '3': 45,
      '4': 1,
      '5': 11,
      '6': '.User.PrivSets',
      '10': 'privSets'
    },
    {'1': 'is_friend', '3': 46, '4': 1, '5': 5, '10': 'isFriend'},
    {
      '1': 'likeForum',
      '3': 47,
      '4': 3,
      '5': 11,
      '6': '.User.LikeForumInfo',
      '10': 'likeForum'
    },
    {'1': 'is_guanfang', '3': 52, '4': 1, '5': 5, '10': 'isGuanfang'},
    {'1': 'thread_num', '3': 87, '4': 1, '5': 5, '10': 'threadNum'},
    {'1': 'is_fans', '3': 91, '4': 1, '5': 5, '10': 'isFans'},
    {
      '1': 'is_default_avatar',
      '3': 106,
      '4': 1,
      '5': 5,
      '10': 'isDefaultAvatar'
    },
    {'1': 'tieba_uid', '3': 120, '4': 1, '5': 9, '10': 'tiebaUid'},
    {'1': 'ip_address', '3': 127, '4': 1, '5': 9, '10': 'ipAddress'},
    {
      '1': 'user_growth',
      '3': 137,
      '4': 1,
      '5': 11,
      '6': '.User.UserGrowth',
      '10': 'userGrowth'
    },
  ],
  '3': [
    User_Icon$json,
    User_PrivSets$json,
    User_LikeForumInfo$json,
    User_UserGrowth$json
  ],
};

@$core.Deprecated('Use userDescriptor instead')
const User_Icon$json = {
  '1': 'Icon',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
  ],
};

@$core.Deprecated('Use userDescriptor instead')
const User_PrivSets$json = {
  '1': 'PrivSets',
  '2': [
    {'1': 'location', '3': 1, '4': 1, '5': 5, '10': 'location'},
    {'1': 'like', '3': 2, '4': 1, '5': 5, '10': 'like'},
    {'1': 'group', '3': 3, '4': 1, '5': 5, '10': 'group'},
    {'1': 'post', '3': 4, '4': 1, '5': 5, '10': 'post'},
    {'1': 'friend', '3': 5, '4': 1, '5': 5, '10': 'friend'},
    {'1': 'live', '3': 6, '4': 1, '5': 5, '10': 'live'},
    {'1': 'reply', '3': 7, '4': 1, '5': 5, '10': 'reply'},
    {'1': 'bazhu_show_inside', '3': 8, '4': 1, '5': 5, '10': 'bazhuShowInside'},
    {
      '1': 'bazhu_show_outside',
      '3': 9,
      '4': 1,
      '5': 5,
      '10': 'bazhuShowOutside'
    },
  ],
};

@$core.Deprecated('Use userDescriptor instead')
const User_LikeForumInfo$json = {
  '1': 'LikeForumInfo',
  '2': [
    {'1': 'forum_name', '3': 1, '4': 1, '5': 9, '10': 'forumName'},
    {'1': 'forum_id', '3': 2, '4': 1, '5': 4, '10': 'forumId'},
  ],
};

@$core.Deprecated('Use userDescriptor instead')
const User_UserGrowth$json = {
  '1': 'UserGrowth',
  '2': [
    {'1': 'level_id', '3': 1, '4': 1, '5': 13, '10': 'levelId'},
  ],
};

/// Descriptor for `User`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userDescriptor = $convert.base64Decode(
    'CgRVc2VyEg4KAmlkGAIgASgDUgJpZBISCgRuYW1lGAMgASgJUgRuYW1lEhsKCW5hbWVfc2hvdx'
    'gEIAEoCVIIbmFtZVNob3cSGgoIcG9ydHJhaXQYBSABKAlSCHBvcnRyYWl0EiYKCGljb25pbmZv'
    'GBEgAygLMgouVXNlci5JY29uUghpY29uaW5mbxIfCgtpc19jb3JldXNlchgUIAEoBVIKaXNDb3'
    'JldXNlchIZCghsZXZlbF9pZBgXIAEoBVIHbGV2ZWxJZBIXCgdpc19iYXd1GBkgASgFUgZpc0Jh'
    'd3USGwoJYmF3dV90eXBlGBogASgJUghiYXd1VHlwZRIUCgVCRFVTUxgdIAEoCVIFQkRVU1MSGQ'
    'oIZmFuc19udW0YHiABKAVSB2ZhbnNOdW0SHwoLY29uY2Vybl9udW0YHyABKAVSCmNvbmNlcm5O'
    'dW0SEAoDc2V4GCAgASgFUgNzZXgSHgoLbXlfbGlrZV9udW0YISABKAVSCW15TGlrZU51bRIUCg'
    'VpbnRybxgiIAEoCVIFaW50cm8SGQoIcG9zdF9udW0YJSABKAVSB3Bvc3ROdW0SFQoGdGJfYWdl'
    'GCYgASgJUgV0YkFnZRIVCgZpc19tZW0YJyABKAVSBWlzTWVtEhYKBmdlbmRlchgqIAEoBVIGZ2'
    'VuZGVyEisKCXByaXZfc2V0cxgtIAEoCzIOLlVzZXIuUHJpdlNldHNSCHByaXZTZXRzEhsKCWlz'
    'X2ZyaWVuZBguIAEoBVIIaXNGcmllbmQSMQoJbGlrZUZvcnVtGC8gAygLMhMuVXNlci5MaWtlRm'
    '9ydW1JbmZvUglsaWtlRm9ydW0SHwoLaXNfZ3VhbmZhbmcYNCABKAVSCmlzR3VhbmZhbmcSHQoK'
    'dGhyZWFkX251bRhXIAEoBVIJdGhyZWFkTnVtEhcKB2lzX2ZhbnMYWyABKAVSBmlzRmFucxIqCh'
    'Fpc19kZWZhdWx0X2F2YXRhchhqIAEoBVIPaXNEZWZhdWx0QXZhdGFyEhsKCXRpZWJhX3VpZBh4'
    'IAEoCVIIdGllYmFVaWQSHQoKaXBfYWRkcmVzcxh/IAEoCVIJaXBBZGRyZXNzEjIKC3VzZXJfZ3'
    'Jvd3RoGIkBIAEoCzIQLlVzZXIuVXNlckdyb3d0aFIKdXNlckdyb3d0aBoaCgRJY29uEhIKBG5h'
    'bWUYASABKAlSBG5hbWUagAIKCFByaXZTZXRzEhoKCGxvY2F0aW9uGAEgASgFUghsb2NhdGlvbh'
    'ISCgRsaWtlGAIgASgFUgRsaWtlEhQKBWdyb3VwGAMgASgFUgVncm91cBISCgRwb3N0GAQgASgF'
    'UgRwb3N0EhYKBmZyaWVuZBgFIAEoBVIGZnJpZW5kEhIKBGxpdmUYBiABKAVSBGxpdmUSFAoFcm'
    'VwbHkYByABKAVSBXJlcGx5EioKEWJhemh1X3Nob3dfaW5zaWRlGAggASgFUg9iYXpodVNob3dJ'
    'bnNpZGUSLAoSYmF6aHVfc2hvd19vdXRzaWRlGAkgASgFUhBiYXpodVNob3dPdXRzaWRlGkkKDU'
    'xpa2VGb3J1bUluZm8SHQoKZm9ydW1fbmFtZRgBIAEoCVIJZm9ydW1OYW1lEhkKCGZvcnVtX2lk'
    'GAIgASgEUgdmb3J1bUlkGicKClVzZXJHcm93dGgSGQoIbGV2ZWxfaWQYASABKA1SB2xldmVsSW'
    'Q=');
