import 'package:flutter/material.dart';

import '../../collector/collect_state.dart';
import '../../core/icons.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'collect_format.dart';

/// 四步流水时间线（设计稿 `.steps`/`.step` index.html:517–532 + 06 屏 1634–1639）。
///
/// - done：recommend 底 + 白勾（12px stroke2 `-s` 档，色值取 surfaceRaised token =
///   设计 #FFFDF8 的深色模式自适应等价）；
/// - active：accent 描边 + accent-strong 数字 + pulseRing 1.6s 无限循环
///   （index.html:528–529；**reduceMotion 关闭脉冲**，测试勿 pumpAndSettle 常规态）；
/// - pending：灰描边 + muted 数字 + 标题 muted w400（index.html:532）；
/// - 连接线 1.5px border 色，left 11 / top 26 / bottom 0（index.html:520），末步无线。
class StepsTimeline extends StatelessWidget {
  const StepsTimeline({super.key, required this.globalStep, this.activeDetail = ''});

  /// 当前全局步骤（之前 = done，之后 = pending）。
  final CollectStep globalStep;

  /// active 步骤小标题的动态段（主吧 stepDetail，如 'pn 12/18' / 'tid 7/37'）。
  final String activeDetail;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppSpacing s = AppSpacing.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final CollectStep step in CollectStep.values)
          Stack(
            children: <Widget>[
              if (step != CollectStep.values.last)
                Positioned(
                  left: 11, // index.html:520 left:11px
                  top: 26, // index.html:520 top:26px
                  bottom: 0,
                  width: 1.5, // index.html:520 width:1.5px
                  child: Container(color: c.border),
                ),
              Padding(
                padding: EdgeInsets.only(bottom: step == CollectStep.values.last ? 0 : s.space5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _StepDot(step: step, current: globalStep),
                    SizedBox(width: s.space3),
                    Expanded(
                      child: _StepText(
                        step: step,
                        state: _stateOf(step),
                        detail: activeDetail,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  _StepState _stateOf(CollectStep step) {
    if (step.index < globalStep.index) {
      return _StepState.done;
    }
    return step == globalStep ? _StepState.active : _StepState.pending;
  }
}

enum _StepState { done, active, pending }

/// 23px 圆点（index.html:522–528）。
class _StepDot extends StatelessWidget {
  const _StepDot({required this.step, required this.current});

  final CollectStep step;
  final CollectStep current;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final int cmp = step.index.compareTo(current.index);
    final bool done = cmp < 0;
    final bool active = cmp == 0;

    final Color bg = done ? c.recommend : c.surfaceRaised;
    final Color borderColor = done ? c.recommend : (active ? c.accent : c.borderStrong);
    final Widget dot = Container(
      width: 23, // index.html:523
      height: 23,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5), // index.html:524 border 1.5px
      ),
      child: done
          // 白勾取 surfaceRaised token：light 下 = 设计 #FFFDF8（index.html:527），
          // dark 下自动换深勾保证与 recommend 底对比。
          ? AppIcon('check', size: 12, color: c.surfaceRaised) // index.html:1635 ic.xs 12px
          : Text(
              '${step.number}',
              style: t.label.copyWith(
                fontSize: 11, // index.html:525 font:600 11px/1
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                color: active ? c.accentStrong : c.textMuted,
              ),
            ),
    );
    if (!active) {
      return dot;
    }
    // pulseRing（index.html:528–529）：box-shadow 0→6px，accent 35%→透明；
    // 55% 关键帧 = 扩散峰值；reduceMotion 时控制器不 repeat（见 _PulseHaloState.didChangeDependencies），静态渲染。
    return SizedBox(
      width: 23,
      height: 23,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: <Widget>[
          _PulseHalo(),
          dot,
        ],
      ),
    );
  }
}

class _PulseHalo extends StatefulWidget {
  @override
  State<_PulseHalo> createState() => _PulseHaloState();
}

class _PulseHaloState extends State<_PulseHalo> with SingleTickerProviderStateMixin {
  // 周期取 AppMotionTheme.pulse（= index.html:528 pulseRing 1.6s，token 治理 §6.2：
  // 组件不硬编码毫秒数）；reduceMotion 退化集 pulse=0 → 不 repeat，静态渲染。
  late final AnimationController _controller = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppMotionTheme motion = AppMotionTheme.of(context);
    if (motion.pulse > Duration.zero) {
      _controller.duration = motion.pulse;
    }
    if (motion.reduceMotion || (_controller.duration ?? Duration.zero) == Duration.zero) {
      // reduceMotion 中途开启（系统开关/主题切换触发本回调）：停掉已 repeat 的控制器，退化静态。
      if (_controller.isAnimating) {
        _controller.stop();
      }
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    if (!_controller.isAnimating) {
      return const SizedBox(width: 23, height: 23);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = _controller.value;
        // 关键帧：0%/100% = spread 0 · alpha .35；55% = spread 6px · alpha 0。
        final double p = t <= 0.55 ? t / 0.55 : 1 - (t - 0.55) / 0.45;
        return Container(
          width: 23,
          height: 23,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(color: c.accent.withValues(alpha: 0.35 * (1 - p)), spreadRadius: 6 * p),
            ],
          ),
        );
      },
    );
  }
}

/// 步骤文字（b = body-strong 14px；small = caption muted，index.html:530–532）。
class _StepText extends StatelessWidget {
  const _StepText({required this.step, required this.state, required this.detail});

  final CollectStep step;
  final _StepState state;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final bool pending = state == _StepState.pending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${stepCircled(step)} ${stepTitle(step)}',
          style: t.bodyStrong.copyWith(
            fontSize: 14, // index.html:530 font-size:14px
            color: pending ? c.textMuted : c.text,
            fontWeight: pending ? FontWeight.w400 : FontWeight.w500, // index.html:532
          ),
        ),
        Text(
          stepSubtitle(step, active: state == _StepState.active, detail: detail),
          style: t.caption.copyWith(color: c.textMuted),
        ),
      ],
    );
  }
}
