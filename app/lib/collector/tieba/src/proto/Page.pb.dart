// This is a generated file - do not edit.
//
// Generated from Page.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class Page extends $pb.GeneratedMessage {
  factory Page({
    $core.int? pageSize,
    $core.int? currentPage,
    $core.int? totalCount,
    $core.int? totalPage,
    $core.int? hasMore,
    $core.int? hasPrev,
  }) {
    final result = Page._();
    if (pageSize != null) result.pageSize = pageSize;
    if (currentPage != null) result.currentPage = currentPage;
    if (totalCount != null) result.totalCount = totalCount;
    if (totalPage != null) result.totalPage = totalPage;
    if (hasMore != null) result.hasMore = hasMore;
    if (hasPrev != null) result.hasPrev = hasPrev;
    return result;
  }

  Page._();

  factory Page.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Page()..mergeFromBuffer(data, registry);
  factory Page.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Page()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Page',
      createEmptyInstance: Page.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'pageSize')
    ..aI(3, _omitFieldNames ? '' : 'currentPage')
    ..aI(4, _omitFieldNames ? '' : 'totalCount')
    ..aI(5, _omitFieldNames ? '' : 'totalPage')
    ..aI(6, _omitFieldNames ? '' : 'hasMore')
    ..aI(7, _omitFieldNames ? '' : 'hasPrev')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Page clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Page copyWith(void Function(Page) updates) =>
      super.copyWith((message) => updates(message as Page)) as Page;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Page() / Page.new instead')
  static Page create() => Page._();
  static $pb.GeneratedMessage $_createMessage() => Page._();
  @$core.override
  Page createEmptyInstance() => Page._();
  @$core.pragma('dart2js:noInline')
  static Page getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Page>(Page.$_createMessage);
  static Page? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get pageSize => $_getIZ(0);
  @$pb.TagNumber(1)
  set pageSize($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPageSize() => $_has(0);
  @$pb.TagNumber(1)
  void clearPageSize() => $_clearField(1);

  @$pb.TagNumber(3)
  $core.int get currentPage => $_getIZ(1);
  @$pb.TagNumber(3)
  set currentPage($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(3)
  $core.bool hasCurrentPage() => $_has(1);
  @$pb.TagNumber(3)
  void clearCurrentPage() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get totalCount => $_getIZ(2);
  @$pb.TagNumber(4)
  set totalCount($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(4)
  $core.bool hasTotalCount() => $_has(2);
  @$pb.TagNumber(4)
  void clearTotalCount() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get totalPage => $_getIZ(3);
  @$pb.TagNumber(5)
  set totalPage($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(5)
  $core.bool hasTotalPage() => $_has(3);
  @$pb.TagNumber(5)
  void clearTotalPage() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get hasMore => $_getIZ(4);
  @$pb.TagNumber(6)
  set hasMore($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(6)
  $core.bool hasHasMore() => $_has(4);
  @$pb.TagNumber(6)
  void clearHasMore() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get hasPrev => $_getIZ(5);
  @$pb.TagNumber(7)
  set hasPrev($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(7)
  $core.bool hasHasPrev() => $_has(5);
  @$pb.TagNumber(7)
  void clearHasPrev() => $_clearField(7);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
