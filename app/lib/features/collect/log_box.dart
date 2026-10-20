import 'package:flutter/material.dart';

import '../../collector/collect_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'collect_format.dart';

/// 实时日志流（设计稿 `.logbox` index.html:505–514 + 06 屏 1641–1648）。
///
/// - sunken 底 + 1px border + radius-lg + padding space4；
/// - mono 11.5px / 行高 20（index.html:508）；
/// - 每行 `HH:mm:ss {fname} {event} {detail}`：时间列 muted（`.t`），
///   event/detail 按 level 染色（info=正文 secondary / ok=recommend / warn=danger /
///   accent=accent-strong，index.html:511–514）；
/// - 新在前（契约 CollectRunState.logs 已按新在前发布），限高内滚。
class LogBox extends StatelessWidget {
  const LogBox({super.key, required this.entries, this.maxVisibleRows = 7});

  final List<CollectLogEntry> entries;

  /// 可见行数上限（06 屏示例 7 行 = 140px 内容高）；超出内滚。
  final int maxVisibleRows;

  /// 行高 20（index.html:508 `font:400 11.5px/20px`）。
  static const double rowHeight = 20;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final double height = (entries.length.clamp(0, maxVisibleRows) * rowHeight).toDouble();
    return Container(
      padding: EdgeInsets.all(s.space4), // index.html:507
      decoration: BoxDecoration(
        color: c.surfaceSunken,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: c.border, width: AppMetrics.hairline),
      ),
      child: SizedBox(
        height: height,
        child: entries.isEmpty
            ? null
            : ListView(
                padding: EdgeInsets.zero,
                itemExtent: rowHeight,
                children: <Widget>[for (final CollectLogEntry e in entries) LogRow(entry: e)],
              ),
      ),
    );
  }
}

/// logbox / dtable 共用的单行富文本（时间列 muted + 级别语义色）。
class LogRow extends StatelessWidget {
  const LogRow({super.key, required this.entry, this.fontSize = 11.5, this.lineHeight = 20});

  final CollectLogEntry entry;
  final double fontSize;
  final double lineHeight;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final TextStyle base = t.mono.copyWith(
      fontSize: fontSize,
      height: lineHeight / fontSize,
      color: c.textSecondary,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: <InlineSpan>[
          TextSpan(
            text: formatHms(entry.time),
            style: base.copyWith(color: c.textMuted), // `.logbox .t`
          ),
          TextSpan(text: ' ${entry.fname} '),
          TextSpan(
            text: '${entry.event} ${entry.detail}',
            style: base.copyWith(color: logLevelColor(context, entry.level)),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.clip,
    );
  }
}
