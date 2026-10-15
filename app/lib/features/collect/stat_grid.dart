import 'package:flutter/material.dart';

import '../../collector/collect_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'count_up.dart';

/// 六格统计（设计稿 `.stat-grid`/`.stat` index.html:687–693 + 06 屏 1620–1627）。
///
/// - 1px gap 用「border 色背景 + 格子 surface-raised」实现（index.html:688）；
/// - 数字 = serif 700 20/1.2 · tabular-nums（display 槽承载 serif 角色，index.html:690）；
/// - `.green` = recommend（+N 帖）、`.gray` = text-muted（跳过重复/丢弃闲聊）；
/// - label = text-label 字阶 muted（index.html:693）；
/// - [columns] 3 = 手机 3×2 / medium c6 降档（index.html:994）；6 = expanded c6 一行（index.html:993）。
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.stats, this.columns = 3, this.stretch = false});

  final CollectStats stats;
  final int columns;

  /// 纵向拉伸填满父级给定高度（设计稿 W5d `.stat-grid.c6{height:100%}` index.html:2862/3452：
  /// expanded 统计区与 ring/forums 同行等高，六格铺满整行不留 gap 底色）。
  /// 仅在**有界高度**容器（宽屏仪表盘行）传 true；compact/medium 自然高度传 false。
  final bool stretch;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final List<Widget> cells = <Widget>[
      _StatCell(value: stats.threadsAdded, prefix: '+', label: '帖', color: c.recommend),
      _StatCell(value: stats.floorsAdded, prefix: '+', label: '楼层', color: c.text),
      _StatCell(value: stats.entriesAdded, prefix: '+', label: '书目', color: c.text),
      _StatCell(value: stats.skippedDup, label: '跳过重复', color: c.textMuted),
      _StatCell(value: stats.discardedChat, label: '丢弃闲聊', color: c.textMuted),
      _StatCell(value: stats.mineThreads, label: '排雷帖', color: c.text),
    ];
    final List<Widget> rows = <Widget>[];
    for (int start = 0; start < cells.length; start += columns) {
      final List<Widget> rowCells = cells.sublist(start, (start + columns).clamp(0, cells.length));
      if (rows.isNotEmpty) {
        rows.add(SizedBox(height: AppMetrics.hairline)); // 1px 行 gap（透出 border 色底）
      }
      final Widget row = Row(
        // 仅宽屏拉伸档（有界行高）让格子铺满行高；compact/medium 自然高度用默认对齐，
        // 避免在无界 ListView 里对 Row 施加 stretch 导致无限高约束崩溃。
        crossAxisAlignment: stretch ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
        children: <Widget>[
          for (int i = 0; i < rowCells.length; i++) ...<Widget>[
            if (i > 0) SizedBox(width: AppMetrics.hairline), // 1px 列 gap
            Expanded(child: rowCells[i]),
          ],
        ],
      );
      rows.add(stretch ? Expanded(child: row) : row);
    }
    return Container(
      decoration: BoxDecoration(
        color: c.border, // gap 底色 = border（index.html:688 background:var(--color-border)）
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: c.border, width: AppMetrics.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      // mainAxisSize.min：父级给松高约束（如 expanded 行 Align 屏蔽 stretch 后）时保持
      // 自然高度——默认 max 会贪吃到约束上限，重新撑出巨柱（灰柱回归用例见 collect_wide_test.dart）。
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label, required this.color, this.prefix = ''});

  final int value;
  final String label;
  final Color color;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    // index.html:690 `.stat b{font:700 20px/1.2 var(--font-serif);tabular-nums}`。
    final TextStyle numberStyle = AppTypography.tabular(
      t.display.copyWith(fontSize: 20, height: 1.2, fontWeight: FontWeight.w700, color: color),
    );
    return Container(
      color: c.surfaceRaised,
      alignment: Alignment.topCenter, // 拉伸时内容顶部对齐（index.html:689 内容流自顶）
      padding: EdgeInsets.symmetric(vertical: s.space4, horizontal: s.space2), // index.html:689
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CountUpInt(value: value, prefix: prefix, style: numberStyle),
          const SizedBox(height: 4), // index.html:693 margin-top:4px
          Text(label, style: t.label.copyWith(color: c.textMuted)),
        ],
      ),
    );
  }
}
