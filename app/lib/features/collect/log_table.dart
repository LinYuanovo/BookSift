import 'package:flutter/material.dart';

import '../../collector/collect_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'badges.dart';
import 'collect_format.dart';

/// 数据表格变体（宽屏实时日志；设计稿 `.dtable` index.html:996–1009 + W5t/W5d 2886–2902）。
///
/// - 五列：时间 / 来源 / 事件 / 详情 / 状态；
/// - th：label 字阶 · letterSpacing .08em · muted · w500 · 高 40 · 底线 border-strong；
/// - td：行高 44（--row-h-table §9.2）· mono 12（时间列 muted tabular / 详情列 secondary）·
///   来源/事件列 sans 12.5 · 行分隔 hairline（末行无）；
/// - 桌面 hover 行染底（--color-hover = text 6% 覆盖层，§9.2/§9.6）；
/// - 状态列 badge h20：进行中=kind / 扫书=rec / 排雷=avoid / 已入库=origin-self /
///   冷却中=avoid / 已启动=ask（index.html:2892–2898）。
class LogTable extends StatelessWidget {
  const LogTable({super.key, required this.entries, this.maxVisibleRows = 8});

  final List<CollectLogEntry> entries;
  final int maxVisibleRows;

  /// 行高 44（index.html:1001 `height:var(--row-h-table)`）。
  static const double rowHeight = 44;

  /// 表头高 40（index.html:1000）。
  static const double headerHeight = 40;

  /// 日志事件 → 状态徽标（W5t 2892–2898 六行状态列的口径；未列事件按 level 兜底）。
  static (CollectBadgeVariant, String) statusBadgeOf(CollectLogEntry e) {
    switch (e.event) {
      case '开始':
        return (CollectBadgeVariant.ask, '已启动');
      case '拉列表':
        return (CollectBadgeVariant.kind, '进行中');
      case '分类':
        return e.detail.contains('排雷')
            ? (CollectBadgeVariant.avoid, '排雷')
            : (CollectBadgeVariant.rec, '扫书');
      case '入库':
        return (CollectBadgeVariant.originSelf, '已入库');
      case '频控':
        return (CollectBadgeVariant.avoid, '冷却中');
      case '失败':
        return (CollectBadgeVariant.avoid, '失败');
      case '完成':
        return (CollectBadgeVariant.rec, '完成');
      case '取消':
        return (CollectBadgeVariant.ask, '已取消');
      default:
        return switch (e.level) {
          CollectLogLevel.ok => (CollectBadgeVariant.rec, e.event),
          CollectLogLevel.warn => (CollectBadgeVariant.avoid, e.event),
          CollectLogLevel.accent => (CollectBadgeVariant.kind, e.event),
          CollectLogLevel.info => (CollectBadgeVariant.ask, e.event),
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bodyHeight = (entries.length.clamp(0, maxVisibleRows) * rowHeight).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _LogTableHeader(),
        SizedBox(
          height: bodyHeight,
          child: ListView(
            padding: EdgeInsets.zero,
            itemExtent: rowHeight,
            children: <Widget>[
              for (int i = 0; i < entries.length; i++)
                _LogTableRow(entry: entries[i], last: i == entries.length - 1),
            ],
          ),
        ),
      ],
    );
  }
}

/// 五列宽度分配（时间/状态定宽，来源/事件/详情按比例；对齐 W5t 表格观感）。
const double _kTimeWidth = 76;
const double _kStatusWidth = 76;
const int _kSourceFlex = 3;
const int _kEventFlex = 2;
const int _kDetailFlex = 5;

class _LogTableHeader extends StatelessWidget {
  const _LogTableHeader();

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    // index.html:1000：label 字阶 · ls .08em（11×0.08≈0.88）· muted · w500 · 底线 border-strong。
    final TextStyle th = t.label.copyWith(color: c.textMuted, fontWeight: FontWeight.w500, letterSpacing: 0.88);
    Widget cell(String text, {double? width, int? flex}) {
      final Widget label = Text(text, style: th, maxLines: 1, overflow: TextOverflow.clip);
      return width != null
          ? SizedBox(width: width, child: label)
          : Expanded(flex: flex!, child: label);
    }

    return Container(
      height: LogTable.headerHeight,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.borderStrong, width: AppMetrics.hairline)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12), // index.html:1000 padding space-2 space-3 的水平档
      child: Row(
        children: <Widget>[
          cell('时间', width: _kTimeWidth),
          cell('来源', flex: _kSourceFlex),
          cell('事件', flex: _kEventFlex),
          cell('详情', flex: _kDetailFlex),
          cell('状态', width: _kStatusWidth),
        ],
      ),
    );
  }
}

class _LogTableRow extends StatefulWidget {
  const _LogTableRow({required this.entry, required this.last});

  final CollectLogEntry entry;
  final bool last;

  @override
  State<_LogTableRow> createState() => _LogTableRowState();
}

class _LogTableRowState extends State<_LogTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final CollectLogEntry e = widget.entry;
    // index.html:1001–1002：mono 12/18 secondary；来源/事件 sans 12.5；时间列 muted tabular。
    final TextStyle mono = t.mono.copyWith(fontSize: 12, height: 18 / 12, color: c.textSecondary);
    final TextStyle timeStyle = AppTypography.tabular(mono.copyWith(color: c.textMuted));
    final TextStyle sans = t.caption.copyWith(fontSize: 12.5, height: 18 / 12.5, color: c.textSecondary);
    final (CollectBadgeVariant variant, String badgeLabel) = LogTable.statusBadgeOf(e);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        height: LogTable.rowHeight,
        decoration: BoxDecoration(
          // --color-hover = text 6% 覆盖层（§9.2；token 派生值，非新增 hex）。
          color: _hovered ? c.text.withValues(alpha: 0.06) : null,
          border: widget.last
              ? null
              : Border(bottom: BorderSide(color: c.border, width: AppMetrics.hairline)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: <Widget>[
            SizedBox(width: _kTimeWidth, child: Text(formatHms(e.time), style: timeStyle, maxLines: 1)),
            Expanded(flex: _kSourceFlex, child: Text(e.fname, style: sans, maxLines: 1, overflow: TextOverflow.ellipsis)),
            Expanded(flex: _kEventFlex, child: Text(e.event, style: sans, maxLines: 1, overflow: TextOverflow.ellipsis)),
            Expanded(
              flex: _kDetailFlex,
              // W5t 详情列为默认 secondary（index.html:2893 td 无染色 class，级别语义由状态列徽标承担）。
              child: Text(e.detail, style: mono, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            SizedBox(
              width: _kStatusWidth,
              child: CollectBadge(label: badgeLabel, variant: variant, height: 20),
            ),
          ],
        ),
      ),
    );
  }
}
