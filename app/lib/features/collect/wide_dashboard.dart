import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/bduss.dart';
import '../../collector/collect_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'badges.dart';
import 'buttons.dart';
import 'collect_format.dart';
import 'log_table.dart';
import 'progress_ring.dart';
import 'stat_grid.dart';
import 'steps_timeline.dart';
import 'status_banner.dart';
import 'watermark_card.dart';

/// 采集仪表盘（运行态宽屏；设计稿 W5t index.html:2806–2905 / W5d 3400–3495，
/// CSS `.wdash`/`.dash-card` 981–994）。
///
/// grid-areas：
/// - medium 2 列：`ring forums / stats stats / steps wm / log log`（index.html:984，stats 3×2）；
/// - expanded 3 列 `minmax(280,340) 1fr 1fr`：`ring forums stats / steps wm wm / log log log`
///   （index.html:985，stats c6 一行六格）。
class CollectWideDashboard extends StatelessWidget {
  const CollectWideDashboard({
    super.key,
    required this.state,
    required this.expanded,
    required this.concurrency,
    required this.onCancel,
  });

  final CollectRunState state;

  /// true = expanded 3 列；false = medium 2 列。
  final bool expanded;
  final int concurrency;
  final VoidCallback onCancel;

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

  @override
  Widget build(BuildContext context) {
    final AppSpacing s = AppSpacing.of(context);
    final ForumRunState? main = _mainForum;
    final CollectStep globalStep = state.globalStep ?? main?.step ?? CollectStep.list;
    // --pad-x：medium 24 / expanded 40（§9.2 作用域变量；space6/space10 同值 token）。
    final double padX = expanded ? s.space10 : s.space6;

    final Widget ring = _DashRing(
      state: state,
      globalStep: globalStep,
      onCancel: onCancel,
    );
    final Widget forums = _DashForums(state: state, concurrency: concurrency);
    // 统计条全断点自然高度：expanded 下不得参与首行 IntrinsicHeight 等高——_DashForums
    // 卡高 ≈ 吧数 × 行高（运行态快照含全部启用吧），吧数一多行高即病态，Row(stretch)
    // 会把六格拉成顶天立地灰柱（真机瞬时巨柱 bug；回归用例见 collect_wide_test.dart）。
    // 首行 stats 槽用 Align(topCenter) 屏蔽行拉伸，ring/forums 两卡仍等高。
    final Widget stats = StatGrid(stats: state.totals, columns: expanded ? 6 : 3);
    final Widget steps = _DashSteps(globalStep: globalStep, activeDetail: main?.stepDetail ?? '');
    final Widget wm = _DashWm(main: main);
    final Widget log = _DashLog(entries: state.logs);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // expanded 第一列 minmax(280px,340px)（index.html:985）。
        final double col1 = (constraints.maxWidth * 0.3).clamp(280.0, 340.0);
        final List<Widget> rows = expanded
            ? <Widget>[
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(width: col1, child: ring),
                      SizedBox(width: s.space5),
                      Expanded(child: forums),
                      SizedBox(width: s.space5),
                      // Align 吃掉 Row(stretch) 的紧高约束：StatGrid 保持自然高、顶对齐，
                      // 不再被同行病态行高拉成巨柱（上面注释的病根链在此断掉）。
                      Expanded(
                        child: Align(alignment: Alignment.topCenter, child: stats),
                      ),
                    ],
                  ),
                ),
                _gap(s),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(width: col1, child: steps),
                      SizedBox(width: s.space5),
                      Expanded(flex: 2, child: wm),
                    ],
                  ),
                ),
                _gap(s),
                log,
              ]
            : <Widget>[
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(child: ring),
                      SizedBox(width: s.space5),
                      Expanded(child: forums),
                    ],
                  ),
                ),
                _gap(s),
                stats,
                _gap(s),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(child: steps),
                      SizedBox(width: s.space5),
                      Expanded(child: wm),
                    ],
                  ),
                ),
                _gap(s),
                log,
              ];
        return SingleChildScrollView(
          // .wdash padding：space5 padX space6（index.html:982）
          padding: EdgeInsets.fromLTRB(padX, s.space5, padX, s.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AnimatedCollectStatusBanner(
                text: state.banner,
                bottomSpacing: s.space5,
              ),
              ...rows,
            ],
          ),
        );
      },
    );
  }

  Widget _gap(AppSpacing s) => SizedBox(height: s.space5); // grid gap space-5（index.html:982）
}

/// dash-card 卡壳（index.html:987：raised + 1px border + radius-lg + padding space5 + gap space3）。
class DashCard extends StatelessWidget {
  const DashCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppSpacing s = AppSpacing.of(context);
    return Container(
      padding: EdgeInsets.all(s.cardPadding),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: c.border, width: AppMetrics.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) SizedBox(height: s.space3),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// 卡头（index.html:988–990：b = cardtitle + badge margin-left auto）。
class _DashHd extends StatelessWidget {
  const _DashHd({required this.title, required this.badge});

  final String title;
  final Widget badge;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    return Row(
      children: <Widget>[
        Expanded(child: Text(title, style: t.cardTitle.copyWith(color: c.text), maxLines: 1, overflow: TextOverflow.ellipsis)),
        badge,
      ],
    );
  }
}

/// dash-ring：总进度环 100 + '+N 帖' + 取消 btn-sm（index.html:2835–2845）。
class _DashRing extends StatelessWidget {
  const _DashRing({required this.state, required this.globalStep, required this.onCancel});

  final CollectRunState state;
  final CollectStep globalStep;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final bool stopping = state.phase == CollectPhase.stopping;
    return DashCard(
      children: <Widget>[
        _DashHd(
          title: '总进度',
          badge: CollectBadge(
            label: '步骤 ${stepCircled(globalStep)}/④',
            variant: CollectBadgeVariant.kind,
          ),
        ),
        Row(
          children: <Widget>[
            // W5t/W5d：ring 100 · stroke 8 · pct 20（index.html:2838–2840）。
            ProgressRing(
              progress: state.overallProgress,
              size: 100,
              strokeWidth: 8,
              pctFontSize: 20,
            ),
            SizedBox(width: s.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // '+37' = text-title · tabular（index.html:2842）。
                  Text(
                    '+${state.totals.threadsAdded}',
                    style: AppTypography.tabular(t.title.copyWith(color: c.text)),
                  ),
                  Text(
                    '帖 · 今日新入库，首页将出现「自采」徽标',
                    style: t.caption.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        CollectButton(
          label: stopping ? '正在停止…' : '取消采集（水位不推进）',
          kind: CollectButtonKind.dangerSoft,
          block: true,
          small: true,
          onPressed: stopping ? null : onCancel,
        ),
      ],
    );
  }
}

/// dash-forums：并发吧每吧一行 pbar + 子状态（index.html:2846–2859）。
class _DashForums extends ConsumerWidget {
  const _DashForums({required this.state, required this.concurrency});

  final CollectRunState state;
  final int concurrency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    // 需求 8/5：与 AppBar 徽标同口径（导入 BDUSS = 账号模式；失效后按匿名档运行）。
    final String mode = ref.watch(effectiveBdussProvider).value == null ? '匿名' : '账号';
    return DashCard(
      children: <Widget>[
        _DashHd(
          title: '并发吧 · ${state.forums.length}',
          badge: CollectBadge(
            label: '$mode · 并发 $concurrency',
            variant: CollectBadgeVariant.originSelf,
          ),
        ),
        for (final ForumRunState f in state.forums) _ForumRunRow(forum: f),
        // 卡底 sub（index.html:2858 margin-top:auto）。
        const Spacer(),
        Text(
          '各吧水位独立推进 · 杀进程 / 断网 / 取消 三态可重入',
          style: t.caption.copyWith(color: c.textMuted),
        ),
      ],
    );
  }
}

class _ForumRunRow extends StatelessWidget {
  const _ForumRunRow({required this.forum});

  final ForumRunState forum;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final bool cooling = forum.status == ForumStatus.cooldown;
    final TextStyle nameStyle = t.bodyStrong.copyWith(color: c.text); // .bt-sans（index.html:719）
    final TextStyle subStyle = t.caption.copyWith(color: c.textMuted); // .dash-card .sub（index.html:991）

    final Widget sub = cooling
        ? Text(
            forum.cooldownUntil == null
                ? '不阻塞其余吧'
                : '冷却至 ${formatClock(forum.cooldownUntil!)} · 不阻塞其余吧',
            style: subStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        : Text(
            '${stepCircled(forum.step)} ${stepShortTitle(forum.step)}'
            '${forum.stepDetail.isEmpty ? '' : ' · ${forum.stepDetail}'}',
            style: subStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(forum.fname, style: nameStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (cooling) ...<Widget>[
              const SizedBox(width: 8), // index.html:2854 gap:var(--space-2)
              CollectBadge(
                label: '${forum.error ?? '429'} · 冷却 ${forum.cooldownUntil == null ? '—' : cooldownRemain(forum.cooldownUntil!)}',
                variant: CollectBadgeVariant.avoid,
              ),
            ],
            const Spacer(),
            Flexible(child: sub),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6), // index.html:2851 margin-top:6px
          child: CollectProgressBar(value: forum.overallProgress, danger: cooling),
        ),
      ],
    );
  }
}

/// dash-steps：面板标题 '四步流水'（i-play）+ steps（index.html:2870–2878）。
class _DashSteps extends StatelessWidget {
  const _DashSteps({required this.globalStep, required this.activeDetail});

  final CollectStep globalStep;
  final String activeDetail;

  @override
  Widget build(BuildContext context) {
    final AppSpacing s = AppSpacing.of(context);
    return DashCard(
      children: <Widget>[
        PanelTitle(label: '四步流水', iconName: 'play', marginBottom: s.space2),
        StepsTimeline(globalStep: globalStep, activeDetail: activeDetail),
      ],
    );
  }
}

/// dash-wm：watermark 无边框透明变体 + sub（index.html:2879–2885）。
class _DashWm extends StatelessWidget {
  const _DashWm({required this.main});

  final ForumRunState? main;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    return DashCard(
      children: <Widget>[
        WatermarkCard(
          fromEpoch: main?.watermarkFrom ?? 0,
          targetEpoch: main?.watermarkTarget ?? 0,
          plain: true,
        ),
        Text(
          '完成后自动重建 FTS 增量索引 · 约 3s',
          style: t.caption.copyWith(color: c.textMuted),
        ),
      ],
    );
  }
}

/// dash-log：dtable 表格变体（index.html:2886–2902，行 996–1009）。
class _DashLog extends StatelessWidget {
  const _DashLog({required this.entries});

  final List<CollectLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    return DashCard(
      children: <Widget>[
        PanelTitle(label: '实时日志 · 表格变体（宽屏）', iconName: 'list', marginBottom: 0),
        LogTable(entries: entries),
      ],
    );
  }
}
