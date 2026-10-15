import 'package:flutter/material.dart';

import '../../theme/app_motion.dart';

/// 「+N」计数滚动（MI-6，原型 §6.5 行 809/823：`TweenAnimationBuilder<int>`
/// normal 300ms · decelerate · tabular-nums 由调用方 style 携带）。
/// reduceMotion 时直接跳终值（不做补间）。
class CountUpInt extends StatelessWidget {
  const CountUpInt({super.key, required this.value, required this.style, this.prefix = ''});

  final int value;
  final TextStyle style;

  /// '+' 前缀（设计稿 stat '+37'，index.html:1621）。
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final AppMotionTheme motion = AppMotionTheme.of(context);
    if (motion.reduceMotion) {
      return Text('$prefix$value', style: style);
    }
    return TweenAnimationBuilder<int>(
      // 必须用 IntTween：基类 Tween<int>.lerp 计算 begin+(end-begin)*t，int*double 得 double，
      // 返回时与声明的 int 不符 → 补间中途抛「Cannot lerp between "0" and "N"」。该异常令
      // CountUpInt 退化成 ErrorWidget（RenderErrorBox 在无界高下取 100000px），compact ListView
      // 里把整行 StatGrid 撑成贯穿全屏的灰色巨柱（真机数字变化瞬间复现）。IntTween.lerp 对
      // 结果 round() 回 int，规避该缺陷；回归用例见 test/collect/statgrid_countup_test.dart。
      tween: IntTween(begin: 0, end: value),
      duration: motion.normal,
      curve: motion.decelerate,
      builder: (BuildContext context, int v, Widget? child) => Text('$prefix$v', style: style),
    );
  }
}
