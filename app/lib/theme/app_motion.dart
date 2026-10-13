import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// 动效语义组合：时长 + 曲线（原型文档 §6.2 语义命名，业务侧只引用语义键、不接触裸值）。
typedef MotionSpec = ({Duration duration, Curve curve});

/// 动效 token（ThemeExtension）。
///
/// 出处：原型文档 §6.2（时长四档 + 曲线集 + 语义键）与 `docs/设计系统-Claude-v1.2.md` §2.5（bezier 取值）。
/// 治理（§6.2 硬性约束）：组件禁止硬编码毫秒数与曲线；全仓唯一定义/注入点为本文件与 BookTheme。
/// 深浅色主题共用同一套动效 token（动效不分明暗）。
@immutable
class AppMotionTheme extends ThemeExtension<AppMotionTheme> {
  const AppMotionTheme({
    this.instant = const Duration(milliseconds: 100),
    this.fast = const Duration(milliseconds: 200),
    this.normal = const Duration(milliseconds: 300),
    this.slow = const Duration(milliseconds: 500),
    this.staggerDelay = const Duration(milliseconds: 40),
    this.decelerate = Curves.easeOutCubic,
    this.accelerate = Curves.easeInCubic,
    this.emphasize = Curves.easeInOutCubicEmphasized,
    this.standard = _standardCurve,
    this.springCurve = _springCurve,
    this.spring = _spring,
    this.reduceMotion = false,
  });

  static const Cubic _standardCurve = Cubic(0.4, 0.0, 0.2, 1.0); // --curve-standard
  static const Cubic _springCurve = Cubic(0.34, 1.4, 0.64, 1.0); // --curve-spring（easeOutBack 近似）
  static const SpringDescription _spring = SpringDescription(mass: 1.0, stiffness: 380.0, damping: 26.0);

  /// `--motion-instant` 100ms：按压反馈、徽标 pop-in。
  final Duration instant;

  /// `--motion-fast` 200ms：星标/心形 burst、Toast/Snackbar 滑入、手风琴收起 + chevron 旋转。
  final Duration fast;

  /// `--motion-normal` 300ms：转场、展开、指示器滑动、stagger 单项、手风琴展开。
  final Duration normal;

  /// `--motion-slow` 500ms：进度环、大面积入场。
  final Duration slow;

  /// `--motion-stagger` 40ms：列表 cascade 单位（规格区间 30–50ms 取中值，上限 8 项）。
  final Duration staggerDelay;

  /// enter 曲线 cubic-bezier(.33,1,.68,1) = easeOutCubic。
  final Curve decelerate;

  /// exit 曲线 cubic-bezier(.32,0,.67,0) = easeInCubic。
  final Curve accelerate;

  /// 转场/指示器曲线 cubic-bezier(.2,0,0,1) = M3 标准强调曲线。
  final Curve emphasize;

  /// 缺省曲线 cubic-bezier(.4,0,.2,1)。
  final Curve standard;

  /// widget 级 spring 近似曲线 cubic-bezier(.34,1.4,.64,1)（easeOutBack 变体）。
  final Curve springCurve;

  /// 物理动画参数（SpringSimulation 用）：mass 1.0 / stiffness 380 / damping 26，轻微回弹、一次震荡内收敛。
  final SpringDescription spring;

  /// 减弱动效开关（应用内设置项；系统级由 [of] 联动 MediaQuery.disableAnimations）。
  final bool reduceMotion;

  /// 标准 token 集（唯一注入点：BookTheme.extensions）。
  static const AppMotionTheme standardTokens = AppMotionTheme();

  /// 减弱动效退化集（§2.5/§6.8）：全部时长 ≤100ms、stagger 归零，
  /// 退化为纯 opacity/颜色 100ms 交叉淡入，保留可读性、避免内容闪烁。
  static const AppMotionTheme reducedTokens = AppMotionTheme(
    reduceMotion: true,
    instant: Duration(milliseconds: 100),
    fast: Duration(milliseconds: 100),
    normal: Duration(milliseconds: 100),
    slow: Duration(milliseconds: 100),
    staggerDelay: Duration.zero,
  );

  /// 读取动效 token，并联动系统「减弱动态效果」（MediaQuery.disableAnimations）：
  /// 主题声明 reduceMotion 或系统禁用动画时返回 [reducedTokens]。
  static AppMotionTheme of(BuildContext context) {
    final AppMotionTheme motion = Theme.of(context).extension<AppMotionTheme>() ?? standardTokens;
    if (motion.reduceMotion || MediaQuery.disableAnimationsOf(context)) {
      return reducedTokens;
    }
    return motion;
  }

  // ── 语义键（§6.2：新界面=enter、移除=exit、弹现=pop、原位切换=switch、页面转场=transition）──

  /// 页面/卡片/新元素入场：normal + decelerate。
  MotionSpec get enter => (duration: normal, curve: decelerate);

  /// 元素退场/移除：fast + accelerate（exit-faster-than-enter）。
  MotionSpec get exit => (duration: fast, curve: accelerate);

  /// 徽标/星标/心形弹现：instant + spring（widget 级近似曲线）。
  MotionSpec get pop => (duration: instant, curve: springCurve);

  /// 内容原位切换（AnimatedSwitcher）：normal + emphasize。`switch` 为 Dart 保留字，沿用文档 §6.2 命名。
  MotionSpec get switch_ => (duration: normal, curve: emphasize);

  /// 页面转场（SharedAxis）：normal + emphasize。
  MotionSpec get transition => (duration: normal, curve: emphasize);

  /// 列表 cascade 第 index 项延迟：40ms × index，上限前 8 项（§6.4）；reduceMotion 下归零。
  Duration staggerAt(int index) => reduceMotion ? Duration.zero : staggerDelay * index.clamp(0, 7);

  @override
  AppMotionTheme copyWith({
    Duration? instant,
    Duration? fast,
    Duration? normal,
    Duration? slow,
    Duration? staggerDelay,
    Curve? decelerate,
    Curve? accelerate,
    Curve? emphasize,
    Curve? standard,
    Curve? springCurve,
    SpringDescription? spring,
    bool? reduceMotion,
  }) {
    return AppMotionTheme(
      instant: instant ?? this.instant,
      fast: fast ?? this.fast,
      normal: normal ?? this.normal,
      slow: slow ?? this.slow,
      staggerDelay: staggerDelay ?? this.staggerDelay,
      decelerate: decelerate ?? this.decelerate,
      accelerate: accelerate ?? this.accelerate,
      emphasize: emphasize ?? this.emphasize,
      standard: standard ?? this.standard,
      springCurve: springCurve ?? this.springCurve,
      spring: spring ?? this.spring,
      reduceMotion: reduceMotion ?? this.reduceMotion,
    );
  }

  @override
  AppMotionTheme lerp(covariant AppMotionTheme? other, double t) {
    if (other == null) {
      return this;
    }
    Duration lerpDuration(Duration a, Duration b) => Duration(
      microseconds: lerpDouble(a.inMicroseconds.toDouble(), b.inMicroseconds.toDouble(), t)!.round(),
    );
    return AppMotionTheme(
      instant: lerpDuration(instant, other.instant),
      fast: lerpDuration(fast, other.fast),
      normal: lerpDuration(normal, other.normal),
      slow: lerpDuration(slow, other.slow),
      staggerDelay: lerpDuration(staggerDelay, other.staggerDelay),
      decelerate: t < 0.5 ? decelerate : other.decelerate,
      accelerate: t < 0.5 ? accelerate : other.accelerate,
      emphasize: t < 0.5 ? emphasize : other.emphasize,
      standard: t < 0.5 ? standard : other.standard,
      springCurve: t < 0.5 ? springCurve : other.springCurve,
      spring: t < 0.5 ? spring : other.spring,
      reduceMotion: t < 0.5 ? reduceMotion : other.reduceMotion,
    );
  }
}
