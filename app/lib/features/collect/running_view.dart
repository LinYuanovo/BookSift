import 'package:flutter/material.dart';

import '../../collector/collect_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../home/cards.dart';
import 'buttons.dart';
import 'collect_format.dart';
import 'log_box.dart';
import 'progress_ring.dart';
import 'stat_grid.dart';
import 'steps_timeline.dart';
import 'status_banner.dart';
import 'watermark_card.dart';

/// 运行态手机视图（设计稿 06 采集进度页逐块复刻，index.html:1584–1660）。
///
/// 区块自上而下：降级横幅（§8.12，可选）→ 主卡（ring 116 + 主吧 + pbar + 冷却吧行）→
/// stat-grid 3×2 → watermark 卡 → steps 四步时间线 → 实时日志 logbox →
/// 取消按钮 btn-danger-soft 全宽。
class CollectRunningView extends StatelessWidget {
  const CollectRunningView({
    super.key,
    required this.state,
    required this.concurrency,
    required this.onCancel,
  });

  final CollectRunState state;

  /// 并发吧数（settings.concurrent_forums，caption '并发 N'）。
  final int concurrency;
  final VoidCallback onCancel;

  /// 主吧 = 第一个非冷却吧（设计稿主卡 yy小说吧；全冷却时取第一个）。
  ForumRunState? get _mainForum {
    if (state.forums.isEmpty) {
      return null;
    }
    for (final ForumRunState f in state.forums) {
      if (f.status != ForumStatus.cooldown) {
        return f;
      }
    }
    return state.forums.first;
  }

  Iterable<ForumRunState> get _cooldownForums =>
      state.forums.where((ForumRunState f) => f.status == ForumStatus.cooldown);

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final ForumRunState? main = _mainForum;
    final CollectStep globalStep = state.globalStep ?? main?.step ?? CollectStep.list;

    return ListView(
      // .pad：padding space3 space5 space5（index.html:248）
      padding: EdgeInsets.fromLTRB(s.pagePadding, s.space3, s.pagePadding, s.space5),
      children: <Widget>[
        AnimatedCollectStatusBanner(
          text: state.banner,
          bottomSpacing: s.space3,
        ),
        // ── 主卡（index.html:1603–1618）──
        Container(
          padding: EdgeInsets.all(s.cardPadding),
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: AppRadius.lgBorder,
            border: Border.all(color: c.border, width: AppMetrics.hairline),
          ),
          child: Row(
            children: <Widget>[
              ProgressRing(progress: state.overallProgress), // 116 / stroke 9 / pct 26
              SizedBox(width: s.space5), // index.html:1603 gap:var(--space-5)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (main != null) ...<Widget>[
                      Text(
                        main.fname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.headline.copyWith(color: c.text), // index.html:1612 text-headline
                      ),
                      Padding(
                        // index.html:1613 margin:4px 0 var(--space-3)
                        padding: EdgeInsets.only(top: 4, bottom: s.space3),
                        child: Text(
                          runningCaption(main, concurrency),
                          style: t.caption.copyWith(color: c.textMuted),
                        ),
                      ),
                      CollectProgressBar(value: main.overallProgress),
                    ],
                    // 冷却吧行（index.html:1615–1616：'{fname} · 接口 429 · 冷却中 48m' 红 + pbar dgr）。
                    for (final ForumRunState f in _cooldownForums) ...<Widget>[
                      Padding(
                        padding: EdgeInsets.only(top: s.space4),
                        child: _CooldownLine(forum: f),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: s.space2),
                        child: CollectProgressBar(value: f.overallProgress, danger: true),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        // ── stat-grid 3×2（index.html:1620–1627；margin space4 0，index.html:688）──
        Padding(
          padding: EdgeInsets.symmetric(vertical: s.space4),
          child: StatGrid(stats: state.totals),
        ),
        // ── watermark 卡（index.html:1629–1632）──
        WatermarkCard(
          fromEpoch: main?.watermarkFrom ?? 0,
          targetEpoch: main?.watermarkTarget ?? 0,
        ),
        // ── steps 四步时间线（index.html:1634–1639，margin-top space5）──
        Padding(
          padding: EdgeInsets.only(top: s.space5),
          child: StepsTimeline(globalStep: globalStep, activeDetail: main?.stepDetail ?? ''),
        ),
        // ── 实时日志（index.html:1641–1648）──
        const SectionTitle(label: '实时日志'),
        LogBox(entries: state.logs),
        // ── 取消（index.html:1650 btn-danger-soft btn-block，margin-top space4）──
        Padding(
          padding: EdgeInsets.only(top: s.space4),
          child: CollectButton(
            label: state.phase == CollectPhase.stopping ? '正在停止…' : '取消采集（水位不推进）',
            kind: CollectButtonKind.dangerSoft,
            block: true,
            onPressed: state.phase == CollectPhase.stopping ? null : onCancel,
          ),
        ),
        SizedBox(height: s.space4), // index.html:1651 底部留白
      ],
    );
  }
}

/// 冷却吧行：'{fname} · 接口 429 · 冷却中 48m'（fname = secondary，其余 danger，index.html:1615）。
class _CooldownLine extends StatelessWidget {
  const _CooldownLine({required this.forum});

  final ForumRunState forum;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final String reason = forum.error ?? '接口 429';
    final String remain = forum.cooldownUntil == null ? '' : cooldownRemain(forum.cooldownUntil!);
    // index.html:1615：'哀伤雪刃 · ' 为 secondary，'接口 429 · 冷却中 48m' 为 danger。
    return Text.rich(
      TextSpan(
        style: t.caption,
        children: <InlineSpan>[
          TextSpan(text: '${forum.fname} · ', style: t.caption.copyWith(color: c.textSecondary)),
          TextSpan(
            text: remain.isEmpty ? reason : '$reason · 冷却中 $remain',
            style: t.caption.copyWith(color: c.danger),
          ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
