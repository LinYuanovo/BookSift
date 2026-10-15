// This is a generated file - do not edit.
//
// Generated from SubPostList.proto.

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

@$core.Deprecated('Use subPostListDescriptor instead')
const SubPostList$json = {
  '1': 'SubPostList',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {
      '1': 'content',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.PbContent',
      '10': 'content'
    },
    {'1': 'time', '3': 3, '4': 1, '5': 13, '10': 'time'},
    {'1': 'author_id', '3': 4, '4': 1, '5': 3, '10': 'authorId'},
    {'1': 'title', '3': 5, '4': 1, '5': 9, '10': 'title'},
    {'1': 'floor', '3': 6, '4': 1, '5': 13, '10': 'floor'},
    {'1': 'author', '3': 7, '4': 1, '5': 11, '6': '.User', '10': 'author'},
    {'1': 'agree', '3': 9, '4': 1, '5': 11, '6': '.Agree', '10': 'agree'},
  ],
};

/// Descriptor for `SubPostList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subPostListDescriptor = $convert.base64Decode(
    'CgtTdWJQb3N0TGlzdBIOCgJpZBgBIAEoA1ICaWQSJAoHY29udGVudBgCIAMoCzIKLlBiQ29udG'
    'VudFIHY29udGVudBISCgR0aW1lGAMgASgNUgR0aW1lEhsKCWF1dGhvcl9pZBgEIAEoA1IIYXV0'
    'aG9ySWQSFAoFdGl0bGUYBSABKAlSBXRpdGxlEhQKBWZsb29yGAYgASgNUgVmbG9vchIdCgZhdX'
    'Rob3IYByABKAsyBS5Vc2VyUgZhdXRob3ISHAoFYWdyZWUYCSABKAsyBi5BZ3JlZVIFYWdyZWU=');

@$core.Deprecated('Use subPostDescriptor instead')
const SubPost$json = {
  '1': 'SubPost',
  '2': [
    {'1': 'pid', '3': 1, '4': 1, '5': 4, '10': 'pid'},
    {
      '1': 'sub_post_list',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.SubPostList',
      '10': 'subPostList'
    },
  ],
};

/// Descriptor for `SubPost`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subPostDescriptor = $convert.base64Decode(
    'CgdTdWJQb3N0EhAKA3BpZBgBIAEoBFIDcGlkEjAKDXN1Yl9wb3N0X2xpc3QYAiADKAsyDC5TdW'
    'JQb3N0TGlzdFILc3ViUG9zdExpc3Q=');
