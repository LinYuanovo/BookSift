import 'package:flutter/material.dart';

import '../../theme/app_motion.dart';

AnimationStyle overlayAnimationStyle(BuildContext context) {
  final AppMotionTheme motion = AppMotionTheme.of(context);
  if (motion.reduceMotion) return AnimationStyle.noAnimation;
  return AnimationStyle(
    curve: motion.transition.curve,
    duration: motion.transition.duration,
    reverseCurve: motion.exit.curve,
    reverseDuration: motion.exit.duration,
  );
}

/// DialogRoute 没有独立的退场时长，只有 [AnimationStyle.duration]。
/// 若要退场使用 exit token，就必须让入场与退场统一为该时长。
AnimationStyle dialogAnimationStyle(BuildContext context) {
  final AppMotionTheme motion = AppMotionTheme.of(context);
  if (motion.reduceMotion) return AnimationStyle.noAnimation;
  return AnimationStyle(
    curve: motion.exit.curve,
    duration: motion.exit.duration,
    reverseCurve: motion.exit.curve,
    reverseDuration: motion.exit.duration,
  );
}

/// PopupMenuRoute 同样只读取 duration；菜单入场/退场统一使用 exit token。
AnimationStyle menuAnimationStyle(BuildContext context) {
  final AppMotionTheme motion = AppMotionTheme.of(context);
  if (motion.reduceMotion) return AnimationStyle.noAnimation;
  return AnimationStyle(
    curve: motion.exit.curve,
    duration: motion.exit.duration,
    reverseCurve: motion.exit.curve,
    reverseDuration: motion.exit.duration,
  );
}
