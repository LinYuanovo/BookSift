// This is a generated file - do not edit.
//
// Generated from PollInfo.proto.

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

@$core.Deprecated('Use pollInfoDescriptor instead')
const PollInfo$json = {
  '1': 'PollInfo',
  '2': [
    {'1': 'is_multi', '3': 2, '4': 1, '5': 5, '10': 'isMulti'},
    {'1': 'total_num', '3': 3, '4': 1, '5': 3, '10': 'totalNum'},
    {
      '1': 'options',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.PollInfo.PollOption',
      '10': 'options'
    },
    {'1': 'total_poll', '3': 11, '4': 1, '5': 3, '10': 'totalPoll'},
    {'1': 'title', '3': 12, '4': 1, '5': 9, '10': 'title'},
  ],
  '3': [PollInfo_PollOption$json],
};

@$core.Deprecated('Use pollInfoDescriptor instead')
const PollInfo_PollOption$json = {
  '1': 'PollOption',
  '2': [
    {'1': 'num', '3': 2, '4': 1, '5': 3, '10': 'num'},
    {'1': 'text', '3': 3, '4': 1, '5': 9, '10': 'text'},
  ],
};

/// Descriptor for `PollInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pollInfoDescriptor = $convert.base64Decode(
    'CghQb2xsSW5mbxIZCghpc19tdWx0aRgCIAEoBVIHaXNNdWx0aRIbCgl0b3RhbF9udW0YAyABKA'
    'NSCHRvdGFsTnVtEi4KB29wdGlvbnMYCSADKAsyFC5Qb2xsSW5mby5Qb2xsT3B0aW9uUgdvcHRp'
    'b25zEh0KCnRvdGFsX3BvbGwYCyABKANSCXRvdGFsUG9sbBIUCgV0aXRsZRgMIAEoCVIFdGl0bG'
    'UaMgoKUG9sbE9wdGlvbhIQCgNudW0YAiABKANSA251bRISCgR0ZXh0GAMgASgJUgR0ZXh0');
