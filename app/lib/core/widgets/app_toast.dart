import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 全局轻提示（Toast）：替代直连 ScaffoldMessenger 的 SnackBar。
///
/// 口径（需求 7）：
/// - **不拉满整宽**：宽屏（≥600dp，口径同 WindowSize compact/medium 分界）取
///   屏宽 1/3，钳制在 [_wideMinToastWidth]–[_wideMaxToastWidth]；窄屏取
///   「屏宽 − 2×space6」（左右各留 24）。水平居中、底部浮起。
/// - 挂根 Overlay（`rootOverlay: true`）而非 ScaffoldMessenger：任意栏位里的按钮
///   （紧凑页 / 中间功能区 / expanded 右槽）都只出**一条**居中 toast，不会各自弹各自的。
/// - 淡入淡出全走 [AppMotionTheme] token，跟随「减弱动效」设置自动退化（≤100ms）。
/// - 同一时刻只保留一条：新 toast 顶掉旧的（等价原 `clearSnackBars` / `hideCurrentSnackBar`）。
void showAppToast(BuildContext context, String message, {Duration? duration}) {
  final OverlayState overlay = Overlay.of(context, rootOverlay: true);
  _active?.remove(); // 顶掉旧 toast（旧 entry 连同其停留计时器一并撤掉）。
  _ToastHandle(message: message, hold: duration ?? _defaultHold).show(overlay);
}

/// Toast 根节点 Key：挂在 FadeTransition 上（几何尺寸与当前不透明度都能直接读，测试/调试定位用）。
const Key appToastKey = Key('app_toast');

/// 停留时长（输入时序参数，非动效 token；口径同 scroll_chrome.dart 的 `_idleHide`）。
const Duration _defaultHold = Duration(milliseconds: 2200);

/// 宽屏断点：600dp（`WindowSize.mediumMinWidth`，< 600 走 compact 窄屏档）。
const double _wideMinWidth = 600;

/// 宽屏 toast 宽度上下限（600dp 时屏宽 1/3 = 200 恰为下限）。
const double _wideMinToastWidth = 200;
const double _wideMaxToastWidth = 520;

/// 当前在屏 toast（同一时刻至多一条）。
_ToastHandle? _active;

/// toast 宽度：宽屏 = 屏宽/3（钳制上下限）；窄屏 = 屏宽 − 2×space6。绝不放任拉满整宽。
double _toastWidth(double screenWidth, AppSpacing s) {
  if (screenWidth >= _wideMinWidth) {
    return (screenWidth / 3).clamp(_wideMinToastWidth, _wideMaxToastWidth);
  }
  return screenWidth - s.space6 * 2;
}

/// 距屏底基线：系统安全区 + space5；compact（< 600dp，AppShell 走底部 NavigationBar 档）
/// 再抬一个底栏高度，避免压住底部导航（口径同 Scaffold 对 floating SnackBar 的让位）。
double _bottomInset(MediaQueryData mq, AppSpacing s) {
  final double navAllowance = mq.size.width < _wideMinWidth ? AppMetrics.bottomNavHeight : 0;
  return mq.padding.bottom + navAllowance + s.space5;
}

/// 单条 toast 的句柄：持 OverlayEntry，负责幂等摘除（自离场 / 被顶替 / 宿主销毁都安全）。
class _ToastHandle {
  _ToastHandle({required this.message, required this.hold});

  final String message;

  /// 停留时长（淡入结束 → 开始淡出）。
  final Duration hold;

  OverlayEntry? _entry;
  bool _removed = false;

  void show(OverlayState overlay) {
    _active = this;
    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext context) =>
          _AppToastView(message: message, hold: hold, onDismissed: remove),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  /// 摘除 toast：先 remove 再 dispose（entry 生命周期由本句柄独占）；重复调用无副作用。
  void remove() {
    if (_removed) {
      return;
    }
    _removed = true;
    if (identical(_active, this)) {
      _active = null;
    }
    final OverlayEntry? entry = _entry;
    if (entry == null) {
      return;
    }
    entry.remove();
    entry.dispose();
  }
}

/// Toast 本体：淡入 → 停留 → 淡出 → 交回 [onDismissed] 摘除。
class _AppToastView extends StatefulWidget {
  const _AppToastView({required this.message, required this.hold, required this.onDismissed});

  final String message;
  final Duration hold;
  final VoidCallback onDismissed;

  @override
  State<_AppToastView> createState() => _AppToastViewState();
}

class _AppToastViewState extends State<_AppToastView> with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  late final CurvedAnimation _opacity;
  late final VoidCallback _onDismissed;
  Timer? _holdTimer;
  bool _started = false;
  bool _notified = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _onDismissed = widget.onDismissed; // 先抓住回调：dispose 之后不再碰 widget。
    _fade = AnimationController(vsync: this, value: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppMotionTheme motion = AppMotionTheme.of(context);
    // 淡入 = fast 档时长（app_motion §6.2 语义：Toast/Snackbar 滑入 = `--motion-fast`）
    // + enter 方向曲线；淡出 = exit 语义键（fast + accelerate，exit-faster-than-enter）。
    // 减弱动效（设置项 reduceMotion / 系统 disableAnimations）由 AppMotionTheme.of 统一
    // 退化为 ≤100ms —— 本组件无需另设开关。
    final MotionSpec inSpec = (duration: motion.fast, curve: motion.enter.curve);
    final MotionSpec outSpec = motion.exit;
    if (_started) {
      _fade
        ..duration = inSpec.duration
        ..reverseDuration = outSpec.duration;
      if (motion.reduceMotion && !_reduceMotion && _fade.isAnimating) {
        _fade.value = _fade.status == AnimationStatus.reverse ? 0 : 1;
      }
      _reduceMotion = motion.reduceMotion;
      return;
    }
    _started = true;
    _reduceMotion = motion.reduceMotion;
    _opacity = CurvedAnimation(parent: _fade, curve: inSpec.curve, reverseCurve: outSpec.curve);
    _fade
      ..duration = inSpec.duration
      ..reverseDuration = outSpec.duration
      ..addStatusListener(_onStatus)
      ..forward();
    _holdTimer = Timer(widget.hold, _dismiss);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      _notifyDismissed();
    }
  }

  /// 停留结束 → 按 exit token 淡出（回落时 [_onStatus] 收尾）；已透明（极短自定义停留）直接收尾。
  void _dismiss() {
    _holdTimer = null;
    if (_fade.value <= 0) {
      _notifyDismissed();
      return;
    }
    _fade.reverse();
  }

  void _notifyDismissed() {
    if (_notified) {
      return;
    }
    _notified = true;
    _onDismissed();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _opacity.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final AppTypography t = AppTypography.of(context);
    final MediaQueryData mq = MediaQuery.of(context);
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(bottom: _bottomInset(mq, s)),
          child: FadeTransition(
            key: appToastKey,
            opacity: _opacity,
            // 观感跟项目浮层族（弹窗/菜单/浮层 toast）对齐：raised 底 + 1px 发丝描边
            // + --shadow-overlay 唯一阴影 token，圆角走设计系统 §2.4 的 Toast 档 pill。
            // 旧版 ink 深底是 SnackBar 语义，和纸感 UI 明显两套语言（用户反馈）。
            child: Container(
                width: _toastWidth(mq.size.width, s),
                padding: EdgeInsets.symmetric(horizontal: s.space4, vertical: s.space3),
                decoration: BoxDecoration(
                  color: c.surfaceRaised,
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: c.border, width: AppMetrics.hairline),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: c.shadowOverlay,
                      offset: const Offset(0, AppMetrics.shadowOverlayOffsetY),
                      blurRadius: AppMetrics.shadowOverlayBlur,
                    ),
                  ],
                ),
                // 必须自带 DefaultTextStyle：本 toast 挂在**根 Overlay**（无 Material 祖先），
                // 会继承 MaterialApp 那句「提醒你补 DefaultTextStyle」的兜底样式
                // （flutter/lib/src/material/app.dart:_errorTextStyle：monospace / w900 /
                // 黄色双下划线）——只写 Text 的 style 无法覆盖它未指定的字段
                // （decoration/decorationColor/decorationStyle/fontWeight 都会漏进去，
                // 用户反馈的「toast 底部莫名黄线」即此）。
                child: DefaultTextStyle(
                  style: t.body.copyWith(color: c.text),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(widget.message, textAlign: TextAlign.center),
                  ),
                ),
              ),
          ),
        ),
      ),
    );
  }
}
