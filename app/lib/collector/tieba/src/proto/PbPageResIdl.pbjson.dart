// This is a generated file - do not edit.
//
// Generated from PbPageResIdl.proto.

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

@$core.Deprecated('Use pbPageResIdlDescriptor instead')
const PbPageResIdl$json = {
  '1': 'PbPageResIdl',
  '2': [
    {'1': 'error', '3': 1, '4': 1, '5': 11, '6': '.Error', '10': 'error'},
    {
      '1': 'data',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.PbPageResIdl.DataRes',
      '10': 'data'
    },
  ],
  '3': [PbPageResIdl_DataRes$json],
};

@$core.Deprecated('Use pbPageResIdlDescriptor instead')
const PbPageResIdl_DataRes$json = {
  '1': 'DataRes',
  '2': [
    {'1': 'forum', '3': 2, '4': 1, '5': 11, '6': '.SimpleForum', '10': 'forum'},
    {'1': 'page', '3': 3, '4': 1, '5': 11, '6': '.Page', '10': 'page'},
    {'1': 'post_list', '3': 6, '4': 3, '5': 11, '6': '.Post', '10': 'postList'},
    {
      '1': 'thread',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.ThreadInfo',
      '10': 'thread'
    },
    {
      '1': 'user_list',
      '3': 13,
      '4': 3,
      '5': 11,
      '6': '.User',
      '10': 'userList'
    },
    {'1': 'thread_freq_num', '3': 37, '4': 1, '5': 3, '10': 'threadFreqNum'},
  ],
};

/// Descriptor for `PbPageResIdl`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pbPageResIdlDescriptor = $convert.base64Decode(
    'CgxQYlBhZ2VSZXNJZGwSHAoFZXJyb3IYASABKAsyBi5FcnJvclIFZXJyb3ISKQoEZGF0YRgCIA'
    'EoCzIVLlBiUGFnZVJlc0lkbC5EYXRhUmVzUgRkYXRhGt0BCgdEYXRhUmVzEiIKBWZvcnVtGAIg'
    'ASgLMgwuU2ltcGxlRm9ydW1SBWZvcnVtEhkKBHBhZ2UYAyABKAsyBS5QYWdlUgRwYWdlEiIKCX'
    'Bvc3RfbGlzdBgGIAMoCzIFLlBvc3RSCHBvc3RMaXN0EiMKBnRocmVhZBgIIAEoCzILLlRocmVh'
    'ZEluZm9SBnRocmVhZBIiCgl1c2VyX2xpc3QYDSADKAsyBS5Vc2VyUgh1c2VyTGlzdBImCg90aH'
    'JlYWRfZnJlcV9udW0YJSABKANSDXRocmVhZEZyZXFOdW0=');
