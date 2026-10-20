// This is a generated file - do not edit.
//
// Generated from CommonReq.proto.

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

@$core.Deprecated('Use commonReqDescriptor instead')
const CommonReq$json = {
  '1': 'CommonReq',
  '2': [
    {'1': '_client_type', '3': 1, '4': 1, '5': 5, '10': 'ClientType'},
    {'1': '_client_version', '3': 2, '4': 1, '5': 9, '10': 'ClientVersion'},
    {'1': '_client_id', '3': 3, '4': 1, '5': 9, '10': 'ClientId'},
    {'1': '_phone_imei', '3': 5, '4': 1, '5': 9, '10': 'PhoneImei'},
    {'1': '_from', '3': 6, '4': 1, '5': 9, '10': 'From'},
    {'1': 'cuid', '3': 7, '4': 1, '5': 9, '10': 'cuid'},
    {'1': '_timestamp', '3': 8, '4': 1, '5': 3, '10': 'Timestamp'},
    {'1': 'model', '3': 9, '4': 1, '5': 9, '10': 'model'},
    {'1': 'BDUSS', '3': 10, '4': 1, '5': 9, '10': 'BDUSS'},
    {'1': 'tbs', '3': 11, '4': 1, '5': 9, '10': 'tbs'},
    {'1': 'net_type', '3': 12, '4': 1, '5': 5, '10': 'netType'},
    {'1': 'pversion', '3': 24, '4': 1, '5': 9, '10': 'pversion'},
    {'1': '_os_version', '3': 25, '4': 1, '5': 9, '10': 'OsVersion'},
    {'1': 'brand', '3': 26, '4': 1, '5': 9, '10': 'brand'},
    {'1': 'lego_lib_version', '3': 28, '4': 1, '5': 9, '10': 'legoLibVersion'},
    {'1': 'applist', '3': 29, '4': 1, '5': 9, '10': 'applist'},
    {'1': 'stoken', '3': 30, '4': 1, '5': 9, '10': 'stoken'},
    {'1': 'z_id', '3': 31, '4': 1, '5': 9, '10': 'zId'},
    {'1': 'cuid_galaxy2', '3': 32, '4': 1, '5': 9, '10': 'cuidGalaxy2'},
    {'1': 'cuid_gid', '3': 33, '4': 1, '5': 9, '10': 'cuidGid'},
    {'1': 'c3_aid', '3': 35, '4': 1, '5': 9, '10': 'c3Aid'},
    {'1': 'sample_id', '3': 36, '4': 1, '5': 9, '10': 'sampleId'},
    {'1': 'scr_w', '3': 37, '4': 1, '5': 5, '10': 'scrW'},
    {'1': 'scr_h', '3': 38, '4': 1, '5': 5, '10': 'scrH'},
    {'1': 'scr_dip', '3': 39, '4': 1, '5': 1, '10': 'scrDip'},
    {'1': 'q_type', '3': 40, '4': 1, '5': 5, '10': 'qType'},
    {'1': 'is_teenager', '3': 41, '4': 1, '5': 5, '10': 'isTeenager'},
    {'1': 'sdk_ver', '3': 42, '4': 1, '5': 9, '10': 'sdkVer'},
    {'1': 'framework_ver', '3': 43, '4': 1, '5': 9, '10': 'frameworkVer'},
    {'1': 'naws_game_ver', '3': 44, '4': 1, '5': 9, '10': 'nawsGameVer'},
    {'1': 'active_timestamp', '3': 49, '4': 1, '5': 3, '10': 'activeTimestamp'},
    {
      '1': 'first_install_time',
      '3': 50,
      '4': 1,
      '5': 3,
      '10': 'firstInstallTime'
    },
    {'1': 'last_update_time', '3': 51, '4': 1, '5': 3, '10': 'lastUpdateTime'},
    {'1': 'event_day', '3': 53, '4': 1, '5': 9, '10': 'eventDay'},
    {'1': 'android_id', '3': 54, '4': 1, '5': 9, '10': 'androidId'},
    {'1': 'cmode', '3': 55, '4': 1, '5': 5, '10': 'cmode'},
    {'1': 'start_scheme', '3': 56, '4': 1, '5': 9, '10': 'startScheme'},
    {'1': 'start_type', '3': 57, '4': 1, '5': 5, '10': 'startType'},
    {'1': 'idfv', '3': 60, '4': 1, '5': 9, '10': 'idfv'},
    {'1': 'extra', '3': 61, '4': 1, '5': 9, '10': 'extra'},
    {'1': 'user_agent', '3': 62, '4': 1, '5': 9, '10': 'userAgent'},
    {
      '1': 'personalized_rec_switch',
      '3': 63,
      '4': 1,
      '5': 5,
      '10': 'personalizedRecSwitch'
    },
    {'1': 'device_score', '3': 70, '4': 1, '5': 9, '10': 'deviceScore'},
  ],
};

/// Descriptor for `CommonReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commonReqDescriptor = $convert.base64Decode(
    'CglDb21tb25SZXESIAoMX2NsaWVudF90eXBlGAEgASgFUgpDbGllbnRUeXBlEiYKD19jbGllbn'
    'RfdmVyc2lvbhgCIAEoCVINQ2xpZW50VmVyc2lvbhIcCgpfY2xpZW50X2lkGAMgASgJUghDbGll'
    'bnRJZBIeCgtfcGhvbmVfaW1laRgFIAEoCVIJUGhvbmVJbWVpEhMKBV9mcm9tGAYgASgJUgRGcm'
    '9tEhIKBGN1aWQYByABKAlSBGN1aWQSHQoKX3RpbWVzdGFtcBgIIAEoA1IJVGltZXN0YW1wEhQK'
    'BW1vZGVsGAkgASgJUgVtb2RlbBIUCgVCRFVTUxgKIAEoCVIFQkRVU1MSEAoDdGJzGAsgASgJUg'
    'N0YnMSGQoIbmV0X3R5cGUYDCABKAVSB25ldFR5cGUSGgoIcHZlcnNpb24YGCABKAlSCHB2ZXJz'
    'aW9uEh4KC19vc192ZXJzaW9uGBkgASgJUglPc1ZlcnNpb24SFAoFYnJhbmQYGiABKAlSBWJyYW'
    '5kEigKEGxlZ29fbGliX3ZlcnNpb24YHCABKAlSDmxlZ29MaWJWZXJzaW9uEhgKB2FwcGxpc3QY'
    'HSABKAlSB2FwcGxpc3QSFgoGc3Rva2VuGB4gASgJUgZzdG9rZW4SEQoEel9pZBgfIAEoCVIDek'
    'lkEiEKDGN1aWRfZ2FsYXh5MhggIAEoCVILY3VpZEdhbGF4eTISGQoIY3VpZF9naWQYISABKAlS'
    'B2N1aWRHaWQSFQoGYzNfYWlkGCMgASgJUgVjM0FpZBIbCglzYW1wbGVfaWQYJCABKAlSCHNhbX'
    'BsZUlkEhMKBXNjcl93GCUgASgFUgRzY3JXEhMKBXNjcl9oGCYgASgFUgRzY3JIEhcKB3Njcl9k'
    'aXAYJyABKAFSBnNjckRpcBIVCgZxX3R5cGUYKCABKAVSBXFUeXBlEh8KC2lzX3RlZW5hZ2VyGC'
    'kgASgFUgppc1RlZW5hZ2VyEhcKB3Nka192ZXIYKiABKAlSBnNka1ZlchIjCg1mcmFtZXdvcmtf'
    'dmVyGCsgASgJUgxmcmFtZXdvcmtWZXISIgoNbmF3c19nYW1lX3ZlchgsIAEoCVILbmF3c0dhbW'
    'VWZXISKQoQYWN0aXZlX3RpbWVzdGFtcBgxIAEoA1IPYWN0aXZlVGltZXN0YW1wEiwKEmZpcnN0'
    'X2luc3RhbGxfdGltZRgyIAEoA1IQZmlyc3RJbnN0YWxsVGltZRIoChBsYXN0X3VwZGF0ZV90aW'
    '1lGDMgASgDUg5sYXN0VXBkYXRlVGltZRIbCglldmVudF9kYXkYNSABKAlSCGV2ZW50RGF5Eh0K'
    'CmFuZHJvaWRfaWQYNiABKAlSCWFuZHJvaWRJZBIUCgVjbW9kZRg3IAEoBVIFY21vZGUSIQoMc3'
    'RhcnRfc2NoZW1lGDggASgJUgtzdGFydFNjaGVtZRIdCgpzdGFydF90eXBlGDkgASgFUglzdGFy'
    'dFR5cGUSEgoEaWRmdhg8IAEoCVIEaWRmdhIUCgVleHRyYRg9IAEoCVIFZXh0cmESHQoKdXNlcl'
    '9hZ2VudBg+IAEoCVIJdXNlckFnZW50EjYKF3BlcnNvbmFsaXplZF9yZWNfc3dpdGNoGD8gASgF'
    'UhVwZXJzb25hbGl6ZWRSZWNTd2l0Y2gSIQoMZGV2aWNlX3Njb3JlGEYgASgJUgtkZXZpY2VTY2'
    '9yZQ==');
