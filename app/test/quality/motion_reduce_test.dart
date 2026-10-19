// 可访问性回归 · reduceMotion 双通道（Phase 5「可访问性与性能预算复核」）。
//
// 守卫三件事：
//  1. reducedTokens 退化集不变量：全部时长 ≤100ms、stagger/pulse 归零、语义键同步退化；
//  2. AppMotionTheme.of(context) 双通道联动：主题声明 reduceMotion **或** 系统
//     MediaQuery.disableAnimations 任一开启 → 返回 reducedTokens（§6.8 / 设计 v1.4 §2.5）；
//  3. 源码级守卫：lib/（theme 定义点除外）禁止硬编码动画时长/曲线字面量
//     （§6.2 治理：全仓唯一定义/注入点 = app_motion.dart + BookTheme），
//     与 theme_tokens_test.dart 的「硬编码色值守卫」同构。
//
// 全部 plain test / testWidgets 内存断言，零真实异步 IO（TESTING.md §3.1；
// 源码扫描用同步 Directory.listSync，按 §3.2 归 plain test）。
library;

import 'dart:io';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/collector/collect_state.dart';
import 'package:booksift/core/fonts/font_tokens.dart';
import 'package:booksift/core/nav/overlay_motion.dart';
import 'package:booksift/core/nav/page_transition.dart';
import 'package:booksift/features/collect/status_banner.dart';
import 'package:booksift/features/collect/steps_timeline.dart';
import 'package:booksift/theme/app_motion.dart';
import 'package:booksift/theme/book_theme.dart';

/// 读取当前 context 的动效 token（of() 双通道判定后的最终生效值）。
AppMotionTheme motionOf(BuildContext context) => AppMotionTheme.of(context);

void main() {
  group('reducedTokens 退化集不变量', () {
    test('关键动效时长全部 ≤100ms、stagger/pulse 归零', () {
      const AppMotionTheme m = AppMotionTheme.reducedTokens;
      expect(m.reduceMotion, isTrue);
      expect(m.instant, const Duration(milliseconds: 100));
      expect(m.fast, const Duration(milliseconds: 100));
      expect(m.normal, const Duration(milliseconds: 100));
      expect(m.slow, const Duration(milliseconds: 100));
      expect(m.staggerDelay, Duration.zero);
      expect(m.pulse, Duration.zero, reason: '循环脉冲退化=整体关闭而非缩短');
    });

    test('语义键（enter/exit/pop/switch/transition）同步退化 ≤100ms', () {
      const AppMotionTheme m = AppMotionTheme.reducedTokens;
      for (final MotionSpec spec in <MotionSpec>[m.enter, m.exit, m.pop, m.switch_, m.transition]) {
        expect(spec.duration, lessThanOrEqualTo(const Duration(milliseconds: 100)));
      }
    });

    test('staggerAt 任意 index 归零（cascade 关闭）', () {
      const AppMotionTheme m = AppMotionTheme.reducedTokens;
      for (int i = 0; i <= 16; i++) {
        expect(m.staggerAt(i), Duration.zero, reason: 'index=$i');
      }
    });

    test('standardTokens 对照：pulse=1600ms（index.html:528）、reduceMotion 缺省关闭', () {
      const AppMotionTheme m = AppMotionTheme.standardTokens;
      expect(m.reduceMotion, isFalse);
      expect(m.pulse, const Duration(milliseconds: 1600));
      expect(m.staggerAt(3), const Duration(milliseconds: 120));
    });
  });

  group('of(context) 双通道联动', () {
    testWidgets('缺省（主题标准集 + 系统未禁用）→ standardTokens', (WidgetTester tester) async {
      late AppMotionTheme resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: BookTheme.light,
          home: Builder(
            builder: (BuildContext context) {
              resolved = motionOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved, same(AppMotionTheme.standardTokens));
      expect(resolved.normal, const Duration(milliseconds: 300));
    });

    testWidgets('系统通道：MediaQuery.disableAnimations=true → reducedTokens', (WidgetTester tester) async {
      late AppMotionTheme resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: BookTheme.light,
          home: Builder(
            builder: (BuildContext context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: Builder(
                builder: (BuildContext inner) {
                  resolved = motionOf(inner);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      expect(resolved, same(AppMotionTheme.reducedTokens));
      expect(resolved.reduceMotion, isTrue);
      expect(resolved.enter.duration, lessThanOrEqualTo(const Duration(milliseconds: 100)));
    });

    testWidgets('应用内通道：主题扩展 reduceMotion=true → reducedTokens', (WidgetTester tester) async {
      late AppMotionTheme resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: BookTheme.light.copyWith(
            extensions: <ThemeExtension<dynamic>>[const AppMotionTheme(reduceMotion: true)],
          ),
          home: Builder(
            builder: (BuildContext context) {
              resolved = motionOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved, same(AppMotionTheme.reducedTokens));
    });

    testWidgets('两通道同开仍返回同一 reducedTokens 常量（幂等）', (WidgetTester tester) async {
      late AppMotionTheme resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: BookTheme.light.copyWith(
            extensions: <ThemeExtension<dynamic>>[const AppMotionTheme(reduceMotion: true)],
          ),
          home: Builder(
            builder: (BuildContext context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: Builder(
                builder: (BuildContext inner) {
                  resolved = motionOf(inner);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      expect(resolved, same(AppMotionTheme.reducedTokens));
    });
  });

  group('页面转场', () {
    testWidgets('标准模式保留共享轴转场', (WidgetTester tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Theme(
            data: BookTheme.light,
            child: MediaQuery(
              data: const MediaQueryData(),
              child: Builder(
                builder: (BuildContext context) => buildPageTransition(
                  context: context,
                  animation: const AlwaysStoppedAnimation<double>(1),
                  secondaryAnimation: const AlwaysStoppedAnimation<double>(0),
                  type: SharedAxisTransitionType.horizontal,
                  child: const SizedBox(),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(SharedAxisTransition), findsOneWidget);
    });

    testWidgets('减弱动效只使用淡入，不使用位移转场', (WidgetTester tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Theme(
            data: BookTheme.of(Brightness.light, FontFamilySet.standard, null, true),
            child: MediaQuery(
              data: const MediaQueryData(),
              child: Builder(
                builder: (BuildContext context) => buildPageTransition(
                  context: context,
                  animation: const AlwaysStoppedAnimation<double>(1),
                  secondaryAnimation: const AlwaysStoppedAnimation<double>(0),
                  type: SharedAxisTransitionType.horizontal,
                  child: const SizedBox(),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(SharedAxisTransition), findsNothing);
      expect(find.byType(FadeTransition), findsOneWidget);
    });
  });

  group('采集状态横幅', () {
    testWidgets('标准动效使用淡入与高度过渡', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BookTheme.light,
          home: const Scaffold(
            body: AnimatedCollectStatusBanner(text: '采集暂停'),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(AnimatedCollectStatusBanner),
          matching: find.byType(SizeTransition),
        ),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: find.byType(AnimatedCollectStatusBanner),
          matching: find.byType(FadeTransition),
        ),
        findsWidgets,
      );
      expect(find.text('采集暂停'), findsOneWidget);
    });

    testWidgets('减弱动效保留淡入且移除高度变化', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BookTheme.of(Brightness.light, FontFamilySet.standard, null, true),
          home: const Scaffold(
            body: AnimatedCollectStatusBanner(text: '采集暂停'),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(AnimatedCollectStatusBanner),
          matching: find.byType(SizeTransition),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AnimatedCollectStatusBanner),
          matching: find.byType(FadeTransition),
        ),
        findsWidgets,
      );
      expect(find.text('采集暂停'), findsOneWidget);
    });

  });

  group('模态浮层动效', () {
    testWidgets('标准模式的弹窗、菜单与底部面板使用语义动效 token', (WidgetTester tester) async {
      late AnimationStyle sheet;
      late AnimationStyle dialog;
      late AnimationStyle menu;
      await tester.pumpWidget(
        MaterialApp(
          theme: BookTheme.light,
          home: Builder(
            builder: (BuildContext context) {
              sheet = overlayAnimationStyle(context);
              dialog = dialogAnimationStyle(context);
              menu = menuAnimationStyle(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(sheet.duration, AppMotionTheme.standardTokens.transition.duration);
      expect(sheet.reverseDuration, AppMotionTheme.standardTokens.exit.duration);
      expect(dialog.duration, AppMotionTheme.standardTokens.exit.duration);
      expect(dialog.reverseDuration, AppMotionTheme.standardTokens.exit.duration);
      expect(menu.duration, AppMotionTheme.standardTokens.exit.duration);
      expect(menu.reverseDuration, AppMotionTheme.standardTokens.exit.duration);
    });

    testWidgets('应用内与系统减少动效都会关闭弹窗及底部面板动画', (WidgetTester tester) async {
      late AnimationStyle appStyle;
      late AnimationStyle systemStyle;
      await tester.pumpWidget(
        MaterialApp(
          theme: BookTheme.of(Brightness.light, FontFamilySet.standard, null, true),
          home: Builder(
            builder: (BuildContext context) {
              appStyle = overlayAnimationStyle(context);
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: Builder(
                  builder: (BuildContext inner) {
                    systemStyle = overlayAnimationStyle(inner);
                    return const SizedBox.shrink();
                  },
                ),
              );
            },
          ),
        ),
      );
      expect(appStyle, AnimationStyle.noAnimation);
      expect(systemStyle, AnimationStyle.noAnimation);
    });
  });

  testWidgets('已打开页面在系统关闭动画偏好变化后退场也读取新时长', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    addTearDown(tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: BookTheme.light,
        home: const SizedBox.shrink(),
      ),
    );
    final PageRoute<void> route = MotionPage<void>(
      type: SharedAxisTransitionType.horizontal,
      child: const SizedBox.shrink(),
    ).createRoute(navigatorKey.currentState!.context) as PageRoute<void>;
    navigatorKey.currentState!.push(route);
    await tester.pumpAndSettle();
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 200));

    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pump();
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 100));
    navigatorKey.currentState!.pop();
    await tester.pump(const Duration(milliseconds: 50));
    expect(route.animation!.value, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 60));
    expect(route.animation!.value, 0);
  });

  testWidgets('正在入场时启用系统减弱动效会立即完成转场', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    addTearDown(tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: BookTheme.light,
        home: const SizedBox.shrink(),
      ),
    );
    final PageRoute<void> route = MotionPage<void>(
      type: SharedAxisTransitionType.horizontal,
      child: const SizedBox.shrink(),
    ).createRoute(navigatorKey.currentState!.context) as PageRoute<void>;
    navigatorKey.currentState!.push(route);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(route.animation!.value, lessThan(1));

    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pump();
    expect(route.animation!.value, 1);
    expect(route.animation!.status, AnimationStatus.completed);
  });

  group('pulse live-toggle（Phase 5 集成审查 minor-1）', () {
    testWidgets('系统关动画中途开启 → 已 repeat 的脉冲停住（帧回调归零）', (WidgetTester tester) async {
      final ValueNotifier<bool> disable = ValueNotifier<bool>(false);
      addTearDown(disable.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: BookTheme.light,
          home: ValueListenableBuilder<bool>(
            valueListenable: disable,
            builder: (BuildContext context, bool v, Widget? child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: v),
              child: const StepsTimeline(globalStep: CollectStep.list),
            ),
          ),
        ),
      );
      await tester.pump();
      // 标准集：active 步的 pulse 控制器已 repeat → 有帧回调排程。
      expect(tester.binding.transientCallbackCount, greaterThan(0), reason: '前置条件：脉冲在跑');
      // 中途开启系统「关闭动画」→ didChangeDependencies 应 stop() 而非无操作。
      disable.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 0, reason: 'repeat 应已停止，不再排帧');
    });
  });

  group('源码守卫：动画时长/曲线不许硬编码（§6.2 治理）', () {
    test('lib/（app_motion.dart 定义点除外）无 duration: Duration(...) / curve: Curves.* 字面量', () {
      // duration: / transitionDuration: / reverseDuration: 直挂字面量 Duration 视为违规；
      // curve: Curves.xxx 视为违规（曲线必须取自动效 token）。
      final RegExp hardcoded = RegExp(r'(?:duration|curve):\s*(?:const\s+)?(?:Duration\(|Curves\.)');
      final List<String> offenders = <String>[];
      for (final FileSystemEntity entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart') || entity.path.endsWith('.g.dart')) {
          continue;
        }
        final String normalized = entity.path.replaceAll(r'\', '/');
        if (normalized == 'lib/theme/app_motion.dart') {
          continue; // 唯一定义点。
        }
        final List<String> lines = entity.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          if (hardcoded.hasMatch(lines[i])) {
            offenders.add('$normalized:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            '组件层禁止硬编码动画毫秒数/曲线（§6.2；设计 v1.4 §2.5）。'
            '请改走 AppMotionTheme.of(context) 语义键；确需新档位先加 token。违规：\n${offenders.join('\n')}',
      );
    });
  });
}
