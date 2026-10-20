// This is a generated file - do not edit.
//
// Generated from FrsPageReqIdl.proto.

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

@$core.Deprecated('Use frsPageReqIdlDescriptor instead')
const FrsPageReqIdl$json = {
  '1': 'FrsPageReqIdl',
  '2': [
    {
      '1': 'data',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.FrsPageReqIdl.DataReq',
      '10': 'data'
    },
  ],
  '3': [FrsPageReqIdl_DataReq$json],
};

@$core.Deprecated('Use frsPageReqIdlDescriptor instead')
const FrsPageReqIdl_DataReq$json = {
  '1': 'DataReq',
  '2': [
    {
      '1': 'common',
      '3': 39,
      '4': 1,
      '5': 11,
      '6': '.CommonReq',
      '10': 'common'
    },
    {'1': 'kw', '3': 1, '4': 1, '5': 9, '10': 'kw'},
    {'1': 'rn', '3': 2, '4': 1, '5': 5, '10': 'rn'},
    {'1': 'rn_need', '3': 3, '4': 1, '5': 5, '10': 'rnNeed'},
    {'1': 'is_good', '3': 4, '4': 1, '5': 5, '10': 'isGood'},
    {'1': 'cid', '3': 5, '4': 1, '5': 5, '10': 'cid'},
    {'1': 'pn', '3': 15, '4': 1, '5': 5, '10': 'pn'},
    {'1': 'sort_type', '3': 47, '4': 1, '5': 5, '10': 'sortType'},
  ],
};

/// Descriptor for `FrsPageReqIdl`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List frsPageReqIdlDescriptor = $convert.base64Decode(
    'Cg1GcnNQYWdlUmVxSWRsEioKBGRhdGEYASABKAsyFi5GcnNQYWdlUmVxSWRsLkRhdGFSZXFSBG'
    'RhdGEavgEKB0RhdGFSZXESIgoGY29tbW9uGCcgASgLMgouQ29tbW9uUmVxUgZjb21tb24SDgoC'
    'a3cYASABKAlSAmt3Eg4KAnJuGAIgASgFUgJybhIXCgdybl9uZWVkGAMgASgFUgZybk5lZWQSFw'
    'oHaXNfZ29vZBgEIAEoBVIGaXNHb29kEhAKA2NpZBgFIAEoBVIDY2lkEg4KAnBuGA8gASgFUgJw'
    'bhIbCglzb3J0X3R5cGUYLyABKAVSCHNvcnRUeXBl');
