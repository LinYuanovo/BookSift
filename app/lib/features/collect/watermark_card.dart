import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../core/icons.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'collect_format.dart';

/// 水位卡（设计稿 `.watermark` index.html:694–700 + 06 屏 1629–1632）。
///
/// - raised 底 + **1px dashed** border-strong 描边（index.html:696；Flutter 无虚线
///   Border，用 [_DashedRectPainter] 复刻）+ radius-lg + padding space4/space5；
/// - i-clock 图标 16 · info 色（index.html:699）；
/// - 正文 caption muted；水位值 b = mono 11.5 w500 text 色（index.html:700）；
/// - [plain] = 宽屏 dash-wm 无边框透明变体（index.html:2880 内联 border:none;padding:0;background:transparent）。
class WatermarkCard extends StatelessWidget {
  const WatermarkCard({super.key, required this.fromEpoch, required this.targetEpoch, this.plain = false});

  /// 开跑前水位（epoch 秒；0 → '未采集'）。
  final int fromEpoch;

  /// 本轮成功后推进到的水位（epoch 秒）。
  final int targetEpoch;
  final bool plain;

  /// 值样式：mono 11.5 w500 text 色（index.html:700）。
  static TextStyle _valueStyle(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    return t.mono.copyWith(fontSize: 11.5, fontWeight: FontWeight.w500, color: c.text, height: 17 / 11.5);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final TextStyle body = t.caption.copyWith(color: c.textMuted, height: 20 / 12);
    final Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // index.html:699 `.watermark .ic{color:var(--color-info);width:16px}`
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: AppIcon('clock', size: 16, color: c.info),
        ),
        SizedBox(width: s.space2),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: body,
              children: <InlineSpan>[
                const TextSpan(text: '水位 '),
                TextSpan(text: formatWatermark(fromEpoch), style: _valueStyle(context)),
                const TextSpan(text: ' → 本轮成功后推进至 '),
                TextSpan(text: formatWatermark(targetEpoch), style: _valueStyle(context)),
                const TextSpan(text: '（取消可重入）'),
              ],
            ),
          ),
        ),
      ],
    );
    if (plain) {
      return content;
    }
    return CustomPaint(
      painter: _DashedRectPainter(color: c.borderStrong),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: s.space5, vertical: s.space4), // index.html:697
        decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: AppRadius.lgBorder),
        child: content,
      ),
    );
  }
}

/// 1px 虚线描边（沿圆角矩形路径 4px 段 / 3px 隙，对齐设计 dashed 视觉密度）。
class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppMetrics.hairline;
    final Path path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
        const Radius.circular(AppRadius.lg),
      ));
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double end = (distance + 4).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 7; // 4px 段 + 3px 隙
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRectPainter oldDelegate) => oldDelegate.color != color;
}
