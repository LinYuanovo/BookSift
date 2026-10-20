// This is a generated file - do not edit.
//
// Generated from PbPageReqIdl.proto.

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

@$core.Deprecated('Use pbPageReqIdlDescriptor instead')
const PbPageReqIdl$json = {
  '1': 'PbPageReqIdl',
  '2': [
    {
      '1': 'data',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.PbPageReqIdl.DataReq',
      '10': 'data'
    },
  ],
  '3': [PbPageReqIdl_DataReq$json],
};

@$core.Deprecated('Use pbPageReqIdlDescriptor instead')
const PbPageReqIdl_DataReq$json = {
  '1': 'DataReq',
  '2': [
    {
      '1': 'common',
      '3': 25,
      '4': 1,
      '5': 11,
      '6': '.CommonReq',
      '10': 'common'
    },
    {'1': 'kz', '3': 4, '4': 1, '5': 3, '10': 'kz'},
    {'1': 'lz', '3': 5, '4': 1, '5': 5, '10': 'lz'},
    {'1': 'r', '3': 6, '4': 1, '5': 5, '10': 'r'},
    {'1': 'pid', '3': 7, '4': 1, '5': 3, '10': 'pid'},
    {'1': 'with_floor', '3': 8, '4': 1, '5': 5, '10': 'withFloor'},
    {'1': 'floor_rn', '3': 9, '4': 1, '5': 5, '10': 'floorRn'},
    {'1': 'rn', '3': 13, '4': 1, '5': 5, '10': 'rn'},
    {'1': 'pn', '3': 18, '4': 1, '5': 5, '10': 'pn'},
    {'1': 'floor_sort_type', '3': 74, '4': 1, '5': 5, '10': 'floorSortType'},
  ],
};

/// Descriptor for `PbPageReqIdl`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pbPageReqIdlDescriptor = $convert.base64Decode(
    'CgxQYlBhZ2VSZXFJZGwSKQoEZGF0YRgBIAEoCzIVLlBiUGFnZVJlcUlkbC5EYXRhUmVxUgRkYX'
    'RhGu8BCgdEYXRhUmVxEiIKBmNvbW1vbhgZIAEoCzIKLkNvbW1vblJlcVIGY29tbW9uEg4KAmt6'
    'GAQgASgDUgJrehIOCgJsehgFIAEoBVICbHoSDAoBchgGIAEoBVIBchIQCgNwaWQYByABKANSA3'
    'BpZBIdCgp3aXRoX2Zsb29yGAggASgFUgl3aXRoRmxvb3ISGQoIZmxvb3Jfcm4YCSABKAVSB2Zs'
    'b29yUm4SDgoCcm4YDSABKAVSAnJuEg4KAnBuGBIgASgFUgJwbhImCg9mbG9vcl9zb3J0X3R5cG'
    'UYSiABKAVSDWZsb29yU29ydFR5cGU=');
