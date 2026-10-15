// This is a generated file - do not edit.
//
// Generated from FrsPageResIdl.proto.

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

@$core.Deprecated('Use frsPageResIdlDescriptor instead')
const FrsPageResIdl$json = {
  '1': 'FrsPageResIdl',
  '2': [
    {'1': 'error', '3': 1, '4': 1, '5': 11, '6': '.Error', '10': 'error'},
    {
      '1': 'data',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.FrsPageResIdl.DataRes',
      '10': 'data'
    },
  ],
  '3': [FrsPageResIdl_DataRes$json],
};

@$core.Deprecated('Use frsPageResIdlDescriptor instead')
const FrsPageResIdl_DataRes$json = {
  '1': 'DataRes',
  '2': [
    {
      '1': 'forum',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.FrsPageResIdl.DataRes.ForumInfo',
      '10': 'forum'
    },
    {'1': 'page', '3': 4, '4': 1, '5': 11, '6': '.Page', '10': 'page'},
    {
      '1': 'thread_list',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.ThreadInfo',
      '10': 'threadList'
    },
    {
      '1': 'user_list',
      '3': 17,
      '4': 3,
      '5': 11,
      '6': '.User',
      '10': 'userList'
    },
    {
      '1': 'nav_tab_info',
      '3': 37,
      '4': 1,
      '5': 11,
      '6': '.FrsPageResIdl.DataRes.NavTabInfo',
      '10': 'navTabInfo'
    },
    {
      '1': 'forum_rule',
      '3': 105,
      '4': 1,
      '5': 11,
      '6': '.FrsPageResIdl.DataRes.ForumRuleStatus',
      '10': 'forumRule'
    },
  ],
  '3': [
    FrsPageResIdl_DataRes_ForumInfo$json,
    FrsPageResIdl_DataRes_NavTabInfo$json,
    FrsPageResIdl_DataRes_ForumRuleStatus$json
  ],
};

@$core.Deprecated('Use frsPageResIdlDescriptor instead')
const FrsPageResIdl_DataRes_ForumInfo$json = {
  '1': 'ForumInfo',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'first_class', '3': 3, '4': 1, '5': 9, '10': 'firstClass'},
    {'1': 'second_class', '3': 4, '4': 1, '5': 9, '10': 'secondClass'},
    {'1': 'member_num', '3': 9, '4': 1, '5': 5, '10': 'memberNum'},
    {'1': 'thread_num', '3': 10, '4': 1, '5': 5, '10': 'threadNum'},
    {'1': 'post_num', '3': 11, '4': 1, '5': 5, '10': 'postNum'},
    {
      '1': 'managers',
      '3': 17,
      '4': 3,
      '5': 11,
      '6': '.FrsPageResIdl.DataRes.ForumInfo.Manager',
      '10': 'managers'
    },
  ],
  '3': [FrsPageResIdl_DataRes_ForumInfo_Manager$json],
};

@$core.Deprecated('Use frsPageResIdlDescriptor instead')
const FrsPageResIdl_DataRes_ForumInfo_Manager$json = {
  '1': 'Manager',
};

@$core.Deprecated('Use frsPageResIdlDescriptor instead')
const FrsPageResIdl_DataRes_NavTabInfo$json = {
  '1': 'NavTabInfo',
  '2': [
    {'1': 'tab', '3': 1, '4': 3, '5': 11, '6': '.FrsTabInfo', '10': 'tab'},
  ],
};

@$core.Deprecated('Use frsPageResIdlDescriptor instead')
const FrsPageResIdl_DataRes_ForumRuleStatus$json = {
  '1': 'ForumRuleStatus',
  '2': [
    {'1': 'has_forum_rule', '3': 4, '4': 1, '5': 5, '10': 'hasForumRule'},
  ],
};

/// Descriptor for `FrsPageResIdl`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List frsPageResIdlDescriptor = $convert.base64Decode(
    'Cg1GcnNQYWdlUmVzSWRsEhwKBWVycm9yGAEgASgLMgYuRXJyb3JSBWVycm9yEioKBGRhdGEYAi'
    'ABKAsyFi5GcnNQYWdlUmVzSWRsLkRhdGFSZXNSBGRhdGEawAUKB0RhdGFSZXMSNgoFZm9ydW0Y'
    'AiABKAsyIC5GcnNQYWdlUmVzSWRsLkRhdGFSZXMuRm9ydW1JbmZvUgVmb3J1bRIZCgRwYWdlGA'
    'QgASgLMgUuUGFnZVIEcGFnZRIsCgt0aHJlYWRfbGlzdBgHIAMoCzILLlRocmVhZEluZm9SCnRo'
    'cmVhZExpc3QSIgoJdXNlcl9saXN0GBEgAygLMgUuVXNlclIIdXNlckxpc3QSQwoMbmF2X3RhYl'
    '9pbmZvGCUgASgLMiEuRnJzUGFnZVJlc0lkbC5EYXRhUmVzLk5hdlRhYkluZm9SCm5hdlRhYklu'
    'Zm8SRQoKZm9ydW1fcnVsZRhpIAEoCzImLkZyc1BhZ2VSZXNJZGwuRGF0YVJlcy5Gb3J1bVJ1bG'
    'VTdGF0dXNSCWZvcnVtUnVsZRqdAgoJRm9ydW1JbmZvEg4KAmlkGAEgASgDUgJpZBISCgRuYW1l'
    'GAIgASgJUgRuYW1lEh8KC2ZpcnN0X2NsYXNzGAMgASgJUgpmaXJzdENsYXNzEiEKDHNlY29uZF'
    '9jbGFzcxgEIAEoCVILc2Vjb25kQ2xhc3MSHQoKbWVtYmVyX251bRgJIAEoBVIJbWVtYmVyTnVt'
    'Eh0KCnRocmVhZF9udW0YCiABKAVSCXRocmVhZE51bRIZCghwb3N0X251bRgLIAEoBVIHcG9zdE'
    '51bRJECghtYW5hZ2VycxgRIAMoCzIoLkZyc1BhZ2VSZXNJZGwuRGF0YVJlcy5Gb3J1bUluZm8u'
    'TWFuYWdlclIIbWFuYWdlcnMaCQoHTWFuYWdlchorCgpOYXZUYWJJbmZvEh0KA3RhYhgBIAMoCz'
    'ILLkZyc1RhYkluZm9SA3RhYho3Cg9Gb3J1bVJ1bGVTdGF0dXMSJAoOaGFzX2ZvcnVtX3J1bGUY'
    'BCABKAVSDGhhc0ZvcnVtUnVsZQ==');
