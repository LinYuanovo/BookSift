// This is a generated file - do not edit.
//
// Generated from PbContent.proto.

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

@$core.Deprecated('Use pbContentDescriptor instead')
const PbContent$json = {
  '1': 'PbContent',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 13, '10': 'type'},
    {'1': 'text', '3': 2, '4': 1, '5': 9, '10': 'text'},
    {'1': 'link', '3': 3, '4': 1, '5': 9, '10': 'link'},
    {'1': 'src', '3': 4, '4': 1, '5': 9, '10': 'src'},
    {'1': 'bsize', '3': 5, '4': 1, '5': 9, '10': 'bsize'},
    {'1': 'cdn_src', '3': 8, '4': 1, '5': 9, '10': 'cdnSrc'},
    {'1': 'big_cdn_src', '3': 9, '4': 1, '5': 9, '10': 'bigCdnSrc'},
    {'1': 'c', '3': 11, '4': 1, '5': 9, '10': 'c'},
    {'1': 'voice_md5', '3': 12, '4': 1, '5': 9, '10': 'voiceMd5'},
    {'1': 'during_time', '3': 13, '4': 1, '5': 13, '10': 'duringTime'},
    {'1': 'uid', '3': 15, '4': 1, '5': 3, '10': 'uid'},
    {'1': 'width', '3': 18, '4': 1, '5': 13, '10': 'width'},
    {'1': 'height', '3': 19, '4': 1, '5': 13, '10': 'height'},
    {'1': 'origin_src', '3': 25, '4': 1, '5': 9, '10': 'originSrc'},
    {'1': 'origin_size', '3': 27, '4': 1, '5': 13, '10': 'originSize'},
    {'1': 'count', '3': 28, '4': 1, '5': 5, '10': 'count'},
    {'1': 'portrait', '3': 49, '4': 1, '5': 9, '10': 'portrait'},
    {
      '1': 'tiebaplus_info',
      '3': 40,
      '4': 1,
      '5': 11,
      '6': '.PbContent.TiebaPlusInfo',
      '10': 'tiebaplusInfo'
    },
    {
      '1': 'item',
      '3': 41,
      '4': 1,
      '5': 11,
      '6': '.PbContent.Item',
      '10': 'item'
    },
  ],
  '3': [PbContent_TiebaPlusInfo$json, PbContent_Item$json],
};

@$core.Deprecated('Use pbContentDescriptor instead')
const PbContent_TiebaPlusInfo$json = {
  '1': 'TiebaPlusInfo',
  '2': [
    {'1': 'title', '3': 1, '4': 1, '5': 9, '10': 'title'},
    {'1': 'desc', '3': 2, '4': 1, '5': 9, '10': 'desc'},
    {'1': 'jump_url', '3': 3, '4': 1, '5': 9, '10': 'jumpUrl'},
    {'1': 'app_icon', '3': 6, '4': 1, '5': 9, '10': 'appIcon'},
    {'1': 'target_type', '3': 12, '4': 1, '5': 5, '10': 'targetType'},
    {'1': 'h5_jump_type', '3': 13, '4': 1, '5': 5, '10': 'h5JumpType'},
    {'1': 'h5_jump_number', '3': 14, '4': 1, '5': 9, '10': 'h5JumpNumber'},
    {'1': 'h5_jump_param', '3': 15, '4': 1, '5': 9, '10': 'h5JumpParam'},
    {'1': 'jump_type', '3': 16, '4': 1, '5': 5, '10': 'jumpType'},
    {'1': 'button_desc', '3': 23, '4': 1, '5': 9, '10': 'buttonDesc'},
  ],
};

@$core.Deprecated('Use pbContentDescriptor instead')
const PbContent_Item$json = {
  '1': 'Item',
  '2': [
    {'1': 'item_name', '3': 2, '4': 1, '5': 9, '10': 'itemName'},
  ],
};

/// Descriptor for `PbContent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pbContentDescriptor = $convert.base64Decode(
    'CglQYkNvbnRlbnQSEgoEdHlwZRgBIAEoDVIEdHlwZRISCgR0ZXh0GAIgASgJUgR0ZXh0EhIKBG'
    'xpbmsYAyABKAlSBGxpbmsSEAoDc3JjGAQgASgJUgNzcmMSFAoFYnNpemUYBSABKAlSBWJzaXpl'
    'EhcKB2Nkbl9zcmMYCCABKAlSBmNkblNyYxIeCgtiaWdfY2RuX3NyYxgJIAEoCVIJYmlnQ2RuU3'
    'JjEgwKAWMYCyABKAlSAWMSGwoJdm9pY2VfbWQ1GAwgASgJUgh2b2ljZU1kNRIfCgtkdXJpbmdf'
    'dGltZRgNIAEoDVIKZHVyaW5nVGltZRIQCgN1aWQYDyABKANSA3VpZBIUCgV3aWR0aBgSIAEoDV'
    'IFd2lkdGgSFgoGaGVpZ2h0GBMgASgNUgZoZWlnaHQSHQoKb3JpZ2luX3NyYxgZIAEoCVIJb3Jp'
    'Z2luU3JjEh8KC29yaWdpbl9zaXplGBsgASgNUgpvcmlnaW5TaXplEhQKBWNvdW50GBwgASgFUg'
    'Vjb3VudBIaCghwb3J0cmFpdBgxIAEoCVIIcG9ydHJhaXQSPwoOdGllYmFwbHVzX2luZm8YKCAB'
    'KAsyGC5QYkNvbnRlbnQuVGllYmFQbHVzSW5mb1INdGllYmFwbHVzSW5mbxIjCgRpdGVtGCkgAS'
    'gLMg8uUGJDb250ZW50Lkl0ZW1SBGl0ZW0augIKDVRpZWJhUGx1c0luZm8SFAoFdGl0bGUYASAB'
    'KAlSBXRpdGxlEhIKBGRlc2MYAiABKAlSBGRlc2MSGQoIanVtcF91cmwYAyABKAlSB2p1bXBVcm'
    'wSGQoIYXBwX2ljb24YBiABKAlSB2FwcEljb24SHwoLdGFyZ2V0X3R5cGUYDCABKAVSCnRhcmdl'
    'dFR5cGUSIAoMaDVfanVtcF90eXBlGA0gASgFUgpoNUp1bXBUeXBlEiQKDmg1X2p1bXBfbnVtYm'
    'VyGA4gASgJUgxoNUp1bXBOdW1iZXISIgoNaDVfanVtcF9wYXJhbRgPIAEoCVILaDVKdW1wUGFy'
    'YW0SGwoJanVtcF90eXBlGBAgASgFUghqdW1wVHlwZRIfCgtidXR0b25fZGVzYxgXIAEoCVIKYn'
    'V0dG9uRGVzYxojCgRJdGVtEhsKCWl0ZW1fbmFtZRgCIAEoCVIIaXRlbU5hbWU=');
