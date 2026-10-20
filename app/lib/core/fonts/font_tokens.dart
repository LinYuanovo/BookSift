import 'package:flutter/foundation.dart';

/// 字体角色 token（设计系统 v1.4 §2.2）。
///
/// 十角色与 [AppTypography] 的字阶 getter 一一对应（bodyStrong 不是独立角色，
/// 复用 body 槽）。哪些位置用哪个字体只由「角色 → 槽」配置决定，组件层禁止
/// 硬编码 fontFamily（守卫测试 test/font_guard_test.dart）。
enum FontRole { display, title, headline, cardTitle, body, bodyRich, secondary, caption, label, mono }

/// 系统级家族常量（唯一定义处；其余代码只准引用这里的符号）。
abstract final class FontFamily {
  /// 平台通用等宽族名：mono 角色的 system 槽解析值。
  /// Android 解析为系统等宽字体；无匹配家族的平台由引擎回退默认字体（不崩溃）。
  static const String monospace = 'monospace';
}

/// 字体槽：角色的取值域 = `system`（默认）或 `imported:<fontId>`。
///
/// system = 不指定家族（fontFamily=null 走平台默认；mono 角色例外，
/// 解析为 [FontFamily.monospace]，见 FontService）。持久化格式即 [serialize] 的字符串。
@immutable
class FontSlot {
  const FontSlot.system() : fontId = null;

  const FontSlot.imported(String this.fontId);

  /// 引用的导入字体 id；null = system。
  final String? fontId;

  bool get isSystem => fontId == null;

  static const String systemValue = 'system';
  static const String importedPrefix = 'imported:';

  String serialize() => fontId == null ? systemValue : '$importedPrefix$fontId';

  /// 容错解析：null / 未知格式 / 空 fontId 一律回落 system。
  static FontSlot parse(String? raw) {
    if (raw == null || raw == systemValue) {
      return const FontSlot.system();
    }
    if (raw.startsWith(importedPrefix)) {
      final String id = raw.substring(importedPrefix.length);
      if (id.isNotEmpty) {
        return FontSlot.imported(id);
      }
    }
    return const FontSlot.system();
  }

  @override
  bool operator ==(Object other) => other is FontSlot && other.fontId == fontId;

  @override
  int get hashCode => fontId.hashCode;

  @override
  String toString() => 'FontSlot(${serialize()})';
}

/// 十角色的 family 解析结果（`FontRole → String?`，null = 平台系统默认）。
///
/// 由 FontService 依据「槽配置 × 导入注册表」解析产出，作为
/// `AppTypography.resolve(...)` 的唯一字体输入；本身不含任何字面量家族名
/// （mono 的默认值引用 [FontFamily.monospace] 常量）。
@immutable
class FontFamilySet {
  const FontFamilySet({
    this.display,
    this.title,
    this.headline,
    this.cardTitle,
    this.body,
    this.bodyRich,
    this.secondary,
    this.caption,
    this.label,
    this.mono = FontFamily.monospace,
  });

  /// 从角色查询函数构建（穷尽 switch 保证十角色全覆盖）。
  factory FontFamilySet.fromFamilyOf(String? Function(FontRole role) familyOf) => FontFamilySet(
    display: familyOf(FontRole.display),
    title: familyOf(FontRole.title),
    headline: familyOf(FontRole.headline),
    cardTitle: familyOf(FontRole.cardTitle),
    body: familyOf(FontRole.body),
    bodyRich: familyOf(FontRole.bodyRich),
    secondary: familyOf(FontRole.secondary),
    caption: familyOf(FontRole.caption),
    label: familyOf(FontRole.label),
    mono: familyOf(FontRole.mono),
  );

  final String? display;
  final String? title;
  final String? headline;
  final String? cardTitle;
  final String? body;
  final String? bodyRich;
  final String? secondary;
  final String? caption;
  final String? label;
  final String? mono;

  /// 默认配置：全部 system（零自定义字体加载）。
  static const FontFamilySet standard = FontFamilySet();

  String? familyOf(FontRole role) => switch (role) {
    FontRole.display => display,
    FontRole.title => title,
    FontRole.headline => headline,
    FontRole.cardTitle => cardTitle,
    FontRole.body => body,
    FontRole.bodyRich => bodyRich,
    FontRole.secondary => secondary,
    FontRole.caption => caption,
    FontRole.label => label,
    FontRole.mono => mono,
  };

  /// 单角色换 family（null = 回 system）。
  FontFamilySet copyWithFamily(FontRole role, String? family) =>
      FontFamilySet.fromFamilyOf((FontRole r) => r == role ? family : familyOf(r));

  @override
  bool operator ==(Object other) =>
      other is FontFamilySet &&
      other.display == display &&
      other.title == title &&
      other.headline == headline &&
      other.cardTitle == cardTitle &&
      other.body == body &&
      other.bodyRich == bodyRich &&
      other.secondary == secondary &&
      other.caption == caption &&
      other.label == label &&
      other.mono == mono;

  @override
  int get hashCode => Object.hash(display, title, headline, cardTitle, body, bodyRich, secondary, caption, label, mono);

  @override
  String toString() => 'FontFamilySet(${FontRole.values.map((FontRole r) => '${r.name}=${familyOf(r)}').join(', ')})';
}
