import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';

class MotionPage<T> extends Page<T> {
  const MotionPage({
    required this.child,
    required this.type,
    super.key,
    this.maintainState = true,
    this.fullscreenDialog = false,
  });

  final Widget child;
  final SharedAxisTransitionType type;
  final bool maintainState;
  final bool fullscreenDialog;

  @override
  Route<T> createRoute(BuildContext context) => _MotionPageRoute<T>(this);
}

class _MotionPageRoute<T> extends PageRoute<T> {
  _MotionPageRoute(MotionPage<T> page)
      : _currentPage = ValueNotifier<MotionPage<T>>(page),
        super(settings: page);

  final ValueNotifier<MotionPage<T>> _currentPage;
  MotionPage<T> get page => settings as MotionPage<T>;

  @override
  void changedInternalState() {
    super.changedInternalState();
    final MotionPage<T> updatedPage = page;
    if (_currentPage.value != updatedPage) _currentPage.value = updatedPage;
  }

  AppMotionTheme get motion {
    final BuildContext? context = navigator?.context;
    return context == null ? AppMotionTheme.standardTokens : AppMotionTheme.of(context);
  }

  @override
  Duration get transitionDuration => motion.transition.duration;

  @override
  Duration get reverseTransitionDuration => motion.exit.duration;

  @override
  bool didPop(T? result) {
    _syncAnimationDurations();
    return super.didPop(result);
  }

  void _syncAnimationDurations() {
    final AnimationController? active = controller;
    if (active == null) return;
    final Duration enter = transitionDuration;
    final Duration exit = reverseTransitionDuration;
    if (active.duration != enter) active.duration = enter;
    if (active.reverseDuration != exit) active.reverseDuration = exit;
  }

  void _finishTransitionForReducedMotion() {
    final AnimationController? active = controller;
    if (active == null || !active.isAnimating) return;
    final AnimationStatus direction = active.status;
    active.stop(canceled: false);
    active.value = direction == AnimationStatus.reverse ? 0 : 1;
  }

  @override
  bool get maintainState => page.maintainState;

  @override
  bool get fullscreenDialog => page.fullscreenDialog;

  @override
  void dispose() {
    _currentPage.dispose();
    super.dispose();
  }

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => ValueListenableBuilder<MotionPage<T>>(
    valueListenable: _currentPage,
    builder: (BuildContext context, MotionPage<T> current, Widget? child) => Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: current.child,
    ),
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    _syncAnimationDurations();
    return _MotionPageTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      type: page.type,
      finishTransition: _finishTransitionForReducedMotion,
      child: child,
    );
  }
}

class _MotionPageTransition extends StatefulWidget {
  const _MotionPageTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.type,
    required this.child,
    required this.finishTransition,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final SharedAxisTransitionType type;
  final Widget child;
  final VoidCallback finishTransition;

  @override
  State<_MotionPageTransition> createState() => _MotionPageTransitionState();
}

class _MotionPageTransitionState extends State<_MotionPageTransition> {
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduced = AppMotionTheme.of(context).reduceMotion;
    if (reduced && !_reduced) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && AppMotionTheme.of(context).reduceMotion) {
          widget.finishTransition();
        }
      });
    }
    _reduced = reduced;
  }

  @override
  Widget build(BuildContext context) => buildPageTransition(
    context: context,
    animation: widget.animation,
    secondaryAnimation: widget.secondaryAnimation,
    type: widget.type,
    child: widget.child,
  );
}

Widget buildPageTransition({
  required BuildContext context,
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required SharedAxisTransitionType type,
  required Widget child,
}) {
  final AppMotionTheme motion = AppMotionTheme.of(context);
  if (motion.reduceMotion) {
    return FadeTransition(opacity: animation, child: child);
  }
  return SharedAxisTransition(
    animation: animation,
    secondaryAnimation: secondaryAnimation,
    transitionType: type,
    fillColor: AppColors.of(context).canvas,
    child: child,
  );
}
