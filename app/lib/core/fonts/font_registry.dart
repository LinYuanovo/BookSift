import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'font_tokens.dart';

/// settings 表（KV）键名（字体域；单一出处）。
abstract final class FontSettingsKeys {
  /// 导入字体注册表（JSON 数组，元素见 [ImportedFont.toJson]）。
  static const String registry = 'fonts.registry';

  /// 角色 → 槽配置（JSON 对象：`{"display":"imported:<id>", ...}`，system 角色不落盘）。
  static const String roles = 'fonts.roles';
}

/// 一条用户导入字体的注册信息。
@immutable
class ImportedFont {
  const ImportedFont({
    required this.fontId,
    required this.familyName,
    required this.fileName,
    required this.importedAt,
  });

  /// 唯一 id（也是落盘文件名主干，见 [storedName]）。
  final String fontId;

  /// 注册到 Flutter 引擎的家族名（= 原始文件名去扩展名；导入时查重）。
  final String familyName;

  /// 原始文件名（展示用）。
  final String fileName;

  final DateTime importedAt;

  /// 落盘文件名 = `<fontId><原扩展名>`（规避用户文件名冲突/非法路径字符）。
  String get storedName {
    final int dot = fileName.lastIndexOf('.');
    return dot >= 0 ? '$fontId${fileName.substring(dot)}' : fontId;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'fontId': fontId,
    'familyName': familyName,
    'fileName': fileName,
    'importedAt': importedAt.toIso8601String(),
  };

  /// 容错反序列化：字段缺失/类型不符 → null（整条丢弃，不拖垮注册表）。
  static ImportedFont? fromJson(Map<String, dynamic> json) {
    final Object? fontId = json['fontId'];
    final Object? familyName = json['familyName'];
    final Object? fileName = json['fileName'];
    final Object? importedAt = json['importedAt'];
    if (fontId is! String || fontId.isEmpty) return null;
    if (familyName is! String || familyName.isEmpty) return null;
    if (fileName is! String || fileName.isEmpty) return null;
    return ImportedFont(
      fontId: fontId,
      familyName: familyName,
      fileName: fileName,
      importedAt:
          (importedAt is String ? DateTime.tryParse(importedAt) : null) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ImportedFont &&
      other.fontId == fontId &&
      other.familyName == familyName &&
      other.fileName == fileName &&
      other.importedAt == importedAt;

  @override
  int get hashCode => Object.hash(fontId, familyName, fileName, importedAt);
}

/// `fonts.registry` 编解码（decode 对坏 JSON/坏条目一律降级为空或跳过）。
abstract final class FontRegistryCodec {
  static String encode(List<ImportedFont> fonts) =>
      jsonEncode(<Map<String, dynamic>>[for (final ImportedFont f in fonts) f.toJson()]);

  static List<ImportedFont> decode(String? raw) {
    if (raw == null || raw.isEmpty) return const <ImportedFont>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return const <ImportedFont>[];
      final List<ImportedFont> result = <ImportedFont>[];
      for (final Object? item in decoded) {
        if (item is Map<String, dynamic>) {
          final ImportedFont? font = ImportedFont.fromJson(item);
          if (font != null) result.add(font);
        }
      }
      return result;
    } catch (_) {
      return const <ImportedFont>[];
    }
  }
}

/// `fonts.roles` 编解码（只存非 system 槽；缺角色 = system；未知键忽略）。
abstract final class FontRoleSlotsCodec {
  static String encode(Map<FontRole, FontSlot> slots) => jsonEncode(<String, String>{
    for (final MapEntry<FontRole, FontSlot> e in slots.entries) e.key.name: e.value.serialize(),
  });

  static Map<FontRole, FontSlot> decode(String? raw) {
    if (raw == null || raw.isEmpty) return const <FontRole, FontSlot>{};
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return const <FontRole, FontSlot>{};
      final Map<FontRole, FontSlot> result = <FontRole, FontSlot>{};
      for (final FontRole role in FontRole.values) {
        final Object? value = decoded[role.name];
        if (value is String) {
          final FontSlot slot = FontSlot.parse(value);
          if (!slot.isSystem) result[role] = slot;
        }
      }
      return result;
    } catch (_) {
      return const <FontRole, FontSlot>{};
    }
  }
}
