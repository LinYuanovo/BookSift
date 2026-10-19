import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../collector/collect_controller.dart';
import '../../collector/collect_state.dart';
import '../../data/bduss.dart';
import '../../core/icons.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/nav/center_slot.dart';
import '../../core/window_size.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../profile/settings_page.dart';
import 'badges.dart';
import 'buttons.dart';
import 'collect_settings.dart';
import 'debug_demo.dart';
import 'idle_view.dart';
import 'running_view.dart';
import 'wide_dashboard.dart';

// 采集中心（M2-①）。
//
// 三形态（设计稿 06 采集进度页 index.html:1584–1660 / W5t 2806–2905 / W5d 3400–3495，
// 空闲态线框 = 原型 §5.9 行 479–512）：
// - idle：账号卡 / 关注吧列表 / 添加吧 / 立即采集 / 最近日志（medium+ 双栏）；
// - running/stopping compact：06 屏逐块复刻（ring / stat-grid / watermark / steps / logbox / 取消）；
// - running/stopping 宽屏：仪表盘 grid（medium 2 列 / expanded 3 列 + dtable 日志表）。
//
// 运行态数据源 = 契约 collectRunStateProvider（只读消费，禁止改契约文件）；
// 空闲态数据源 = collectForumsProvider / recentCollectLogsProvider（真 DB）。

class CollectPage extends ConsumerStatefulWidget {
  const CollectPage({super.key});

  @override
  ConsumerState<CollectPage> createState() => _CollectPageState();
}

class _CollectPageState extends ConsumerState<CollectPage> {
  /// 调试演示态（kDebugMode 限定，release 树摇掉）：长按 AppBar「匿名模式」徽标
  /// 注入设计稿 06 屏演示快照（debug_demo.dart），用于无网络视觉验收与测试夹具复用。
  CollectRunState? _demo;

  void _toggleDemo() {
    setState(() {
      _demo = _demo != null ? null : debugDemoRunState();
    });
  }

  Future<void> _startAll() async {
    try {
      await ref.read(collectControllerProvider).startAll();
    } catch (_) {
      if (mounted) {
        showAppToast(context, '启动失败');
      }
    }
  }

  Future<void> _cancel() async {
    if (_demo != null) {
      // 演示态：取消 = 退出演示（不触真实控制器）。
      setState(() => _demo = null);
      return;
    }
    try {
      await ref.read(collectControllerProvider).cancel();
    } catch (_) {
      if (mounted) {
        showAppToast(context, '取消失败');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final CollectRunState real = ref.watch(collectRunStateProvider);
    final CollectRunState state = _demo ?? real;
    final bool running = state.isRunning;
    // 并发/仅WiFi 只在运行态展示（caption '并发 N' 与 W5d appbar badge），空闲态不触 DB。
    final CollectSettings settings = running
        ? ref.watch(collectSettingsProvider).value ?? const CollectSettings()
        : const CollectSettings();

    // 需求 5：采集命中「登录态失效」会自动降级并标记 → 只在新标记落定时提示一次
    // （toast + 采集日志里的「降级」事件；设置页 / 账号卡另行显示失效态文案）。
    ref.listen<AsyncValue<bool>>(bdussInvalidProvider,
        (AsyncValue<bool>? prev, AsyncValue<bool> next) {
      final bool before = prev?.value ?? false;
      if (!before && (next.value ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            showAppToast(context, 'BDUSS 已失效，已自动回退匿名档 · 请到设置页重新导入');
          }
        });
      }
    });

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final WindowSizeClass size = WindowSize.fromWidth(constraints.maxWidth);
        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Tab 页无返回键；标题口径：运行态 = 采集中心（index.html:1597），空闲 = 采集。
                Align(
                  alignment: Alignment.center,
                  widthFactor: 1,
                  child: Text(running ? '采集中心' : '采集'),
                ),
                SizedBox(width: s.space2),
                GestureDetector(
                  key: const ValueKey<String>('collect-anon-badge'),
                  onLongPress: kDebugMode ? _toggleDemo : null,
                  // 需求 8/5：导入 BDUSS 即账号模式（配额 600）；失效标记后按匿名档运行
                  // （effective 口径，与采集装配同源）。
                  child: Align(
                    alignment: Alignment.center,
                    heightFactor: 1,
                    child: CollectBadge(
                      label: ref.watch(effectiveBdussProvider).value == null
                          ? '匿名模式'
                          : '账号模式',
                      variant: CollectBadgeVariant.originSelf,
                    ),
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              // W5d appbar：'并发 2 · 仅 WiFi' badge kind + gear + 立即采集 btn-accent btn-sm
              //（index.html:3420–3422；medium W5t 仅 gear，index.html:2831）。
              if (running && size == WindowSizeClass.expanded) ...<Widget>[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: s.space2),
                  child: Center(
                    child: CollectBadge(
                      label: '并发 ${settings.concurrentForums}'
                          '${settings.wifiOnly ? ' · 仅 WiFi' : ''}',
                      variant: CollectBadgeVariant.kind,
                    ),
                  ),
                ),
              ],
              IconButton(
                tooltip: '采集设置',
                icon: AppIcon('gear', size: 20, color: c.textSecondary),
                onPressed: () => openCenterPage(context, const SettingsPage()),
              ),
              if (running && size == WindowSizeClass.expanded)
                Padding(
                  padding: EdgeInsets.only(right: s.space3),
                  child: Center(
                    child: CollectButton(
                      label: '立即采集',
                      small: true,
                      onPressed: _startAll,
                    ),
                  ),
                ),
            ],
          ),
          body: running
              ? (size == WindowSizeClass.compact
                    ? CollectRunningView(
                        state: state,
                        concurrency: settings.concurrentForums,
                        onCancel: _cancel,
                      )
                    : CollectWideDashboard(
                        state: state,
                        expanded: size == WindowSizeClass.expanded,
                        concurrency: settings.concurrentForums,
                        onCancel: _cancel,
                      ))
              : CollectIdleView(
                  wide: size != WindowSizeClass.compact,
                  banner: state.banner,
                ),
        );
      },
    );
  }
}
