import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';

/// 进度环（MI-6 · 设计稿 `.ring` index.html:497–502 + 06 屏 116px / W5t 100px）。
///
/// - track = surface-sunken，bar = accent，圆头弧（stroke-linecap round），起点 -90°；
/// - 弧长动画：`--motion-slow` 500ms · `--curve-standard`（index.html:500），determinate；
/// - 中心 pct = serif 600 · tabular-nums（display 槽承载 serif 角色），small = 11px sans muted
///   letterSpacing .06em（index.html:501–502）；
/// - reduceMotion：时长退化 ≤100ms（AppMotionTheme.reducedTokens 通道）。
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 116,
    this.strokeWidth = 9,
    this.pctFontSize = 26,
    this.label = '总进度',
  });

  /// 0..1。
  final double progress;

  /// 116（06 屏，stroke 9 / r50，index.html:1604–1607）或 100（W5t/W5d，stroke 8 / r43，index.html:2838–2839）。
  final double size;
  final double strokeWidth;

  /// 中心百分比字号：26（06 屏）/ 20（W5t 内联 style，index.html:2840）。
  final double pctFontSize;
  final String label;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppMotionTheme motion = AppMotionTheme.of(context);
    final double target = progress.clamp(0.0, 1.0);
    // pct 数值样式：600 · serif 角色走 display 槽（v1.4 §2.2：组件禁家族字面量）· tabular。
    final TextStyle pctStyle = AppTypography.tabular(
      t.display.copyWith(fontSize: pctFontSize, height: 1, fontWeight: FontWeight.w600, color: c.text),
    );
    final TextStyle labelStyle = t.label.copyWith(color: c.textMuted, letterSpacing: 0.66); // .06em×11px

    Widget ring(double animated) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            CustomPaint(
              size: Size(size, size),
              painter: _RingPainter(
                progress: animated,
                strokeWidth: strokeWidth,
                trackColor: c.surfaceSunken,
                barColor: c.accent,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('${(animated * 100).round()}%', style: pctStyle),
                const SizedBox(height: 5), // index.html:502 margin-top:5px
                Text(label, style: labelStyle),
              ],
            ),
          ],
        ),
      );
    }

    if (motion.reduceMotion) {
      return ring(target);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: motion.slow, // MI-6：环 slow 500ms
      curve: motion.standard,
      builder: (BuildContext context, double v, Widget? child) => ring(v),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
    required this.barColor,
  });

  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final Color barColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);
    if (progress <= 0) {
      return;
    }
    final Paint bar = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round // index.html:500 stroke-linecap:round
      ..color = barColor;
    // 起点 -90°（index.html:498 `.ring svg{transform:rotate(-90deg)}`）。
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress.clamp(0.0, 1.0), false, bar);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.barColor != barColor;
}

/// 进度条（`.pbar` index.html:701–703：6px 高 pill · track=surface-sunken ·
/// bar=accent（dgr 变体 danger）· 宽度过渡 motion-slow decelerate）。
class CollectProgressBar extends StatelessWidget {
  const CollectProgressBar({super.key, required this.value, this.danger = false});

  /// 0..1。
  final double value;

  /// `.pbar.dgr`（index.html:703，429 冷却红条）。
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppMotionTheme motion = AppMotionTheme.of(context);
    final Color barColor = danger ? c.danger : c.accent;
    final double target = value.clamp(0.0, 1.0);
    Widget track(double v) => Container(
      height: 6, // index.html:701 height:6px
      decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: AppRadius.pillBorder),
      clipBehavior: Clip.antiAlias,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(widthFactor: v, child: Container(color: barColor)),
      ),
    );
    if (motion.reduceMotion) {
      return track(target);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: motion.slow,
      curve: motion.decelerate,
      builder: (BuildContext context, double v, Widget? child) => track(v),
    );
  }
}
