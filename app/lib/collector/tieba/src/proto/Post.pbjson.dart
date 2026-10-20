// This is a generated file - do not edit.
//
// Generated from Post.proto.

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

@$core.Deprecated('Use postDescriptor instead')
const Post$json = {
  '1': 'Post',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'floor', '3': 3, '4': 1, '5': 13, '10': 'floor'},
    {'1': 'time', '3': 4, '4': 1, '5': 13, '10': 'time'},
    {
      '1': 'content',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.PbContent',
      '10': 'content'
    },
    {'1': 'sub_post_number', '3': 13, '4': 1, '5': 13, '10': 'subPostNumber'},
    {'1': 'author_id', '3': 19, '4': 1, '5': 3, '10': 'authorId'},
    {
      '1': 'sub_post_list',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.Post.SubPost',
      '10': 'subPostList'
    },
    {
      '1': 'signature',
      '3': 21,
      '4': 1,
      '5': 11,
      '6': '.Post.SignatureData',
      '10': 'signature'
    },
    {'1': 'author', '3': 23, '4': 1, '5': 11, '6': '.User', '10': 'author'},
    {'1': 'agree', '3': 37, '4': 1, '5': 11, '6': '.Agree', '10': 'agree'},
    {'1': 'tid', '3': 46, '4': 1, '5': 3, '10': 'tid'},
    {
      '1': 'chat_content',
      '3': 78,
      '4': 1,
      '5': 11,
      '6': '.Post.ChatContent',
      '10': 'chatContent'
    },
    {
      '1': 'sprite_meme_info',
      '3': 79,
      '4': 1,
      '5': 11,
      '6': '.Post.SpriteMemeInfo',
      '10': 'spriteMemeInfo'
    },
  ],
  '3': [
    Post_SubPost$json,
    Post_SignatureData$json,
    Post_ChatContent$json,
    Post_SpriteMemeInfo$json
  ],
};

@$core.Deprecated('Use postDescriptor instead')
const Post_SubPost$json = {
  '1': 'SubPost',
  '2': [
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

@$core.Deprecated('Use postDescriptor instead')
const Post_SignatureData$json = {
  '1': 'SignatureData',
  '2': [
    {
      '1': 'content',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.Post.SignatureData.SignatureContent',
      '10': 'content'
    },
  ],
  '3': [Post_SignatureData_SignatureContent$json],
};

@$core.Deprecated('Use postDescriptor instead')
const Post_SignatureData_SignatureContent$json = {
  '1': 'SignatureContent',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 5, '10': 'type'},
    {'1': 'text', '3': 2, '4': 1, '5': 9, '10': 'text'},
  ],
};

@$core.Deprecated('Use postDescriptor instead')
const Post_ChatContent$json = {
  '1': 'ChatContent',
  '2': [
    {'1': 'bot_uk', '3': 1, '4': 1, '5': 9, '10': 'botUk'},
  ],
};

@$core.Deprecated('Use postDescriptor instead')
const Post_SpriteMemeInfo$json = {
  '1': 'SpriteMemeInfo',
  '2': [
    {'1': 'meme_id', '3': 1, '4': 1, '5': 3, '10': 'memeId'},
  ],
};

/// Descriptor for `Post`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List postDescriptor = $convert.base64Decode(
    'CgRQb3N0Eg4KAmlkGAEgASgDUgJpZBIUCgVmbG9vchgDIAEoDVIFZmxvb3ISEgoEdGltZRgEIA'
    'EoDVIEdGltZRIkCgdjb250ZW50GAUgAygLMgouUGJDb250ZW50Ugdjb250ZW50EiYKD3N1Yl9w'
    'b3N0X251bWJlchgNIAEoDVINc3ViUG9zdE51bWJlchIbCglhdXRob3JfaWQYEyABKANSCGF1dG'
    'hvcklkEjEKDXN1Yl9wb3N0X2xpc3QYDyABKAsyDS5Qb3N0LlN1YlBvc3RSC3N1YlBvc3RMaXN0'
    'EjEKCXNpZ25hdHVyZRgVIAEoCzITLlBvc3QuU2lnbmF0dXJlRGF0YVIJc2lnbmF0dXJlEh0KBm'
    'F1dGhvchgXIAEoCzIFLlVzZXJSBmF1dGhvchIcCgVhZ3JlZRglIAEoCzIGLkFncmVlUgVhZ3Jl'
    'ZRIQCgN0aWQYLiABKANSA3RpZBI0CgxjaGF0X2NvbnRlbnQYTiABKAsyES5Qb3N0LkNoYXRDb2'
    '50ZW50UgtjaGF0Q29udGVudBI+ChBzcHJpdGVfbWVtZV9pbmZvGE8gASgLMhQuUG9zdC5TcHJp'
    'dGVNZW1lSW5mb1IOc3ByaXRlTWVtZUluZm8aOwoHU3ViUG9zdBIwCg1zdWJfcG9zdF9saXN0GA'
    'IgAygLMgwuU3ViUG9zdExpc3RSC3N1YlBvc3RMaXN0GosBCg1TaWduYXR1cmVEYXRhEj4KB2Nv'
    'bnRlbnQYBCADKAsyJC5Qb3N0LlNpZ25hdHVyZURhdGEuU2lnbmF0dXJlQ29udGVudFIHY29udG'
    'VudBo6ChBTaWduYXR1cmVDb250ZW50EhIKBHR5cGUYASABKAVSBHR5cGUSEgoEdGV4dBgCIAEo'
    'CVIEdGV4dBokCgtDaGF0Q29udGVudBIVCgZib3RfdWsYASABKAlSBWJvdFVrGikKDlNwcml0ZU'
    '1lbWVJbmZvEhcKB21lbWVfaWQYASABKANSBm1lbWVJZA==');
