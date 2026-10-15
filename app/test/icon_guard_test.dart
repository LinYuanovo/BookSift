import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 全仓图标静态守卫（M2 图标收尾）。
///
/// 两条红线（用户口径：效果与设计稿一致，不得用默认 Material 图标 / emoji 充数）：
///   ① `lib/**/*.dart` 内 **零 Material `Icons.` 引用** —— 结构图标一律走设计稿 SVG
///      （`core/icons.dart` 的 [AppIcon]，资产 `assets/icons/*.svg` 提取自
///      `work/ui_design/claude/index.html` 的 `<symbol>` sprite）。
///   ② `lib/**/*.dart` 内 **零结构性 emoji** —— UI 不得拿 emoji 当图标。
///
/// 扫描写法参照 `theme_tokens_test.dart` 的硬编码色值守卫（逐行 regex + offenders 列表）。
/// 生成文件（`.g.dart` / protobuf `.pb*.dart`）不参与扫描。
void main() {
  /// 递归收集 `lib/` 下的手写 Dart 源文件（相对路径，正斜杠），跳过生成物。
  List<File> libSources() {
    final List<File> out = <File>[];
    for (final FileSystemEntity e in Directory('lib').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) {
        continue;
      }
      final String p = e.path.replaceAll(r'\', '/');
      final bool generated = p.endsWith('.g.dart') ||
          p.endsWith('.pb.dart') ||
          p.endsWith('.pbenum.dart') ||
          p.endsWith('.pbjson.dart') ||
          p.endsWith('.pbgrpc.dart') ||
          p.endsWith('.freezed.dart') ||
          p.endsWith('.mocks.dart');
      if (generated) {
        continue; // drift / protobuf / codegen 生成物
      }
      out.add(File(p));
    }
    return out;
  }

  group('图标红线①：Material Icons. 清零', () {
    test('lib/**/*.dart 无 `Icons.` 引用（结构图标全走设计稿 AppIcon）', () {
      // `\bIcons\.` 只命中独立 Material `Icons.`（不误伤 `CupertinoIcons.` / `User_Icon` / `IconData`）。
      final RegExp material = RegExp(r'\bIcons\.');
      // 显式白名单：仅允许「文档注释里提及」的行豁免，格式 `相对路径:行号`。
      // 当前为空 —— 全仓（含注释）零 `Icons.`；若日后需在注释里引用，请在此登记并注明原因。
      const Set<String> commentAllowlist = <String>{};

      final List<String> offenders = <String>[];
      for (final File f in libSources()) {
        final String path = f.path.replaceAll(r'\', '/');
        final List<String> lines = f.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          if (!material.hasMatch(lines[i])) {
            continue;
          }
          final String loc = '$path:${i + 1}';
          if (commentAllowlist.contains(loc)) {
            continue;
          }
          offenders.add('$loc  ${lines[i].trim()}');
        }
      }
      expect(offenders, isEmpty,
          reason: 'lib/ 内禁止 Material Icons.*，一律用 core/icons.dart 的 AppIcon（设计稿 SVG）。\n'
              '命中：\n${offenders.join('\n')}');
    });
  });

  group('图标红线②：结构性 emoji 清零', () {
    test('lib/**/*.dart 无以 emoji 当图标（数据/文档白名单除外）', () {
      // emoji 判定的 Unicode 块（绘文字/表情/交通/补充/几何扩展/杂项符号/杂项符号与箭头）。
      // 设计稿认可的标点·圈号·箭头·制表符（↗ U+2197、· U+00B7、① U+2460、─ U+2500、
      // ═ U+2550、▶ U+25B6、● U+25CF、→↓↑ U+2192/2193/2191、《》等）均在 U+2600 以下，
      // 不落入下列任一区间，天然放行、无需登记。
      const List<(int, int)> emojiRanges = <(int, int)>[
        (0x1F300, 0x1F5FF), // Misc Symbols and Pictographs
        (0x1F600, 0x1F64F), // Emoticons
        (0x1F680, 0x1F6FF), // Transport and Map
        (0x1F7E0, 0x1F7EB), // Geometric Shapes Extended（🟢🟩🟨 圆/方色块）
        (0x1F900, 0x1F9FF), // Supplemental Symbols and Pictographs
        (0x2600, 0x26FF), // Miscellaneous Symbols（含 ⚠）
        (0x2B00, 0x2BFF), // Misc Symbols and Arrows（含 ⬜⬛）
      ];
      bool isEmoji(int cp) => emojiRanges.any((r) => cp >= r.$1 && cp <= r.$2);

      // 白名单码点：确认为「正文数据内容」或「文档/导出文本」而非 UI 结构图标（逐条注明出处）。
      const Map<int, String> allowedEmoji = <int, String>{
        0x1F345: '🍅 classify 语料正则字面量（贴吧原帖 emoji = 数据内容，非 UI）',
        0x1F422: '🐢 classify 语料正则字面量（rules.dart 全表唯一非 BMP 字面量，折叠槽位 E001）',
        0x1F60B: '😋 classify 语料正则字面量（数据内容）',
        0x1F92E: '🤮 classify 语料正则字面量（数据内容）',
        0x1F7E2: '🟢 collector/tieba_search.dart 文档注释风险档标记（doc）',
        0x1F7E9: '🟩 share 文档注释引用原型 §5.11 线框 swatch 名（doc）',
        0x1F7E8: '🟨 share 文档注释引用原型 §5.11 线框 swatch 名（doc）',
        0x2B1C: '⬜ share 文档注释引用原型 §5.11 线框 swatch 名（doc）',
        0x2B1B: '⬛ share 文档注释引用原型 §5.11 线框 swatch 名（doc）',
        0x26A0: '⚠ booklist_export 导出 MD/TXT 文本标记（文档内容，非屏幕图标）',
      };

      final List<String> offenders = <String>[];
      for (final File f in libSources()) {
        final String path = f.path.replaceAll(r'\', '/');
        final List<String> lines = f.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          for (final int cp in lines[i].runes) {
            if (isEmoji(cp) && !allowedEmoji.containsKey(cp)) {
              offenders.add(
                '$path:${i + 1}  U+${cp.toRadixString(16).toUpperCase()} '
                '${String.fromCharCode(cp)}  |  ${lines[i].trim()}',
              );
            }
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'UI 代码禁止用 emoji 当图标（结构图标走 AppIcon）。\n'
              '数据/文档 emoji 需在测试白名单 allowedEmoji 中登记并注明。\n'
              '命中：\n${offenders.join('\n')}');
    });
  });
}
