import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants.dart';
import 'core/icons.dart';
import 'core/nav/center_slot.dart';
import 'core/window_size.dart';
import 'data/repo/queries.dart';
import 'data/repo/queries_providers.dart';
import 'features/content/content_detail_page.dart';
import 'features/content/detail_slot.dart';
import 'theme/app_colors.dart';
import 'theme/app_radius.dart';
import 'theme/app_spacing.dart';
import 'theme/app_typography.dart';

typedef _TabSpec = ({String label, String icon});

/// 自适应应用骨架（M1-②）：
/// compact(<600dp) → 底部 NavigationBar 4 Tab；
/// medium(600–1024dp，**含 1024**) → NavigationRail；
/// expanded(>1024dp) → 三栏「功能区」：左侧导航栏（可收起 / 可拖宽）+ 中间功能区
/// （当前 Tab **叠加**中间页面栈）+ 右侧详情槽；两条分隔条支持**长按拖动**改占比。
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell, this.location = ''});

  final StatefulNavigationShell navigationShell;

  /// go_router 当前 location（app_router.dart 注入）：一变即代表「换页 / 换 Tab」，
  /// 中间功能区页面栈随之回到根——否则从书聚合页里点作者跳搜索，搜索结果会被压在
  /// 书聚合页下面看不见。
  final String location;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// 导航栏展开宽度（NavigationRail extended 设计宽：品牌头 224 + 左右 padding 32）。
  static const double _railExpandedWidth = 256;

  /// 收起态宽度（= 展开判定阈值：≥ 此题才走 extended 形态，否则图标 + 短标签）。
  static const double _railCollapsedWidth = 72;

  /// 长按拖宽范围（下限同收起态；上限避免把中间功能区挤没）。
  static const double _railMinWidth = 72;
  static const double _railMaxWidth = 360;

  /// 中间功能区最小宽 / 右侧详情槽最小宽（拖拽夹逼下限）。
  static const double _centerMinWidth = 360;
  static const double _detailMinWidth = 300;

  /// 导航栏当前宽度（长按拖分隔条改；收起钮在 [_railCollapsedWidth] 与上次展开宽之间切换）。
  double _railWidth = _railExpandedWidth;

  /// 收起前的展开宽度（重新展开时恢复）。
  double _railWidthExpanded = _railExpandedWidth;

  /// 右侧详情槽占「中间 + 右侧」的比例（长按拖分隔条改）。
  double _detailFraction = 0.4;

  /// 中间功能区页面栈是否非空（PopScope：Android 系统返回键先退中间栈）。
  bool _centerHasRoutes = false;

  /// 拖动基准：起点指针**全局 x** + 起点值。位置一律用绝对位移换算
  /// （`起点值 + (当前 x - 起点 x)`），不做逐帧 delta 累加——方向与手感一次定死。
  double? _dragOriginX;
  double _dragOriginRail = 0;
  double _dragOriginFraction = 0;

  /// 最近一次布局里「中间 + 右侧」的总可分配宽（换算详情栏占比用）。
  double _lastRest = 0;

  void _railDragStart(double globalX) {
    _dragOriginX = globalX;
    _dragOriginRail = _railWidth;
  }

  /// 导航栏分隔条：分隔条跟着指针走（左拖变窄 / 右拖变宽）。
  void _railDragTo(double globalX) {
    final double? origin = _dragOriginX;
    if (origin == null) {
      return;
    }
    setState(() => _railWidth =
        (_dragOriginRail + (globalX - origin)).clamp(_railMinWidth, _railMaxWidth));
  }

  void _detailDragStart(double globalX) {
    _dragOriginX = globalX;
    _dragOriginFraction = _detailFraction;
  }

  /// 中间 | 详情分隔条：**分隔条跟手** —— 详情栏在分隔条右侧，故指针左移 = 详情栏变宽。
  void _detailDragTo(double globalX) {
    final double? origin = _dragOriginX;
    if (origin == null || _lastRest <= 0) {
      return;
    }
    // 取号与左侧导航栏那条相反：详情栏占「中间 + 右侧」的**右半**，
    // 分隔条左移（Δ<0）＝ 详情栏变宽 → fraction 增；旧写法 +Δ/rest 会让分隔条与
    // 指针反向（用户反馈：往左拖最右侧区域却缩小了）。
    setState(() => _detailFraction =
        (_dragOriginFraction - (globalX - origin) / _lastRest).clamp(0.15, 0.85));
  }

  void _dragEnd() => _dragOriginX = null;

  static const List<_TabSpec> _tabs = <_TabSpec>[
    (label: '首页', icon: 'home'),
    (label: '搜索', icon: 'search'),
    (label: '采集', icon: 'collect'),
    (label: '我的', icon: 'user'),
  ];

  /// 中间栈根路由的内容槽（= 当前 Tab 内容）：路由页只在首次 build 时取一次，
  /// 故 router 重建出的新 [StatefulNavigationShell] 实例经 didUpdateWidget 同步进来。
  late final ValueNotifier<Widget> _centerRoot;

  @override
  void initState() {
    super.initState();
    _centerRoot = ValueNotifier<Widget>(widget.navigationShell);
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 换页（含换 Tab、改搜索条件、中间页里 go）→ 中间栈回根。
    if (widget.location != oldWidget.location && _centerHasRoutes) {
      popCenterToRoot();
    }
    if (!identical(_centerRoot.value, widget.navigationShell)) {
      _centerRoot.value = widget.navigationShell;
    }
  }

  @override
  void dispose() {
    _centerRoot.dispose();
    super.dispose();
  }

  /// 导航图标（M2-①：设计稿 symbol sprite → assets/icons SVG，index.html:271 `.nav-item .ic{24px}`）。
  /// 选中态 = accent-strong、未选中 = text-muted（index.html:266–272 `.nav-item`/`.nav-item.active`，
  /// Rail 同语义 index.html:866–873；extended Rail 未选中 = text-secondary，index.html:882）。
  /// 同图不同色，icon/selectedIcon 均传 AppIcon。
  Widget _navIcon(BuildContext context, String name, {required bool selected, bool extended = false}) {
    final AppColors c = AppColors.of(context);
    final Color color = selected ? c.accentStrong : (extended ? c.textSecondary : c.textMuted);
    return AppIcon(name, size: 24, color: color);
  }

  /// 导航标签：选中 = accent-strong + 600（`.nav-item.active{font-weight:600}` index.html:272），
  /// 未选中 = text-muted（`.nav-item` index.html:266–270 / `.rail-item` index.html:866）。
  /// extended Rail 行内标签按 `.rail-ext-item`（index.html:882）：body-strong 字阶 + text-secondary。
  Widget _navLabel(BuildContext context, String label, {required bool selected, bool extended = false}) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final TextStyle base = extended ? t.bodyStrong : t.label;
    return Text(
      label,
      style: base.copyWith(
        color: selected ? c.accentStrong : (extended ? c.textSecondary : c.textMuted),
        fontWeight: selected ? FontWeight.w600 : base.fontWeight,
      ),
    );
  }

  void _onDestinationSelected(int index) {
    // 中间功能区还压着页面（如书聚合页）时，切 Tab = 离开该页 → 先退栈再切分支。
    popCenterToRoot();
    // 重复点击当前 Tab 回到该分支根位置（go_router 惯例）。
    widget.navigationShell.goBranch(index, initialLocation: index == widget.navigationShell.currentIndex);
  }

  /// 收起 / 展开左侧功能栏（底部按钮；收起 = 图标档宽，展开回到上次拖定的宽度）。
  void _toggleRail() {
    setState(() {
      if (_railWidth <= _railCollapsedWidth) {
        _railWidth = _railWidthExpanded;
      } else {
        _railWidthExpanded = _railWidth;
        _railWidth = _railCollapsedWidth;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return switch (WindowSize.fromWidth(constraints.maxWidth)) {
          WindowSizeClass.compact => _compact(context),
          WindowSizeClass.medium => _withRail(context, extended: false),
          WindowSizeClass.expanded => _expanded(context, constraints.maxWidth),
        };
      },
    );
  }

  Widget _compact(BuildContext context) {
    final int selected = widget.navigationShell.currentIndex;
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    return Scaffold(
      body: widget.navigationShell,
      // 局部主题仅覆盖 label 字样（设计 `.nav-item.active`：accent-strong + 600 /
      // 未选中 text-muted，index.html:266–272；NavigationDestination.label 只收 String，
      // 样式只能走 labelTextStyle）。其余几何逐项照抄全局 navigationBarTheme，不动结构。
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: c.surface,
          elevation: 0,
          height: AppMetrics.bottomNavHeight,
          indicatorColor: c.accentSoft,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (Set<WidgetState> states) => t.label.copyWith(
              color: states.contains(WidgetState.selected) ? c.accentStrong : c.textMuted,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: _onDestinationSelected,
          destinations: <NavigationDestination>[
            for (int i = 0; i < _tabs.length; i++)
              NavigationDestination(
                icon: _navIcon(context, _tabs[i].icon, selected: false),
                selectedIcon: _navIcon(context, _tabs[i].icon, selected: true),
                label: _tabs[i].label,
              ),
          ],
        ),
      ),
    );
  }

  Widget _withRail(BuildContext context, {required bool extended}) {
    return Scaffold(
      body: Row(
        children: <Widget>[
          _rail(context, extended: extended),
          const _HairlineV(),
          Expanded(child: widget.navigationShell),
        ],
      ),
    );
  }

  /// expanded 三栏：三块功能区 + 两条可长按拖动的分隔条（用户口径：占比可调）。
  Widget _expanded(BuildContext context, double totalWidth) {
    final double railWidth = _railWidth.clamp(_railMinWidth, _railMaxWidth);
    // 长按拖动改导航栏宽度时，中间栏会被压到 0 以下：按「中间栏 ≥ 最小宽」反推上限。
    final double railCeiling = math.max(
      _railMinWidth,
      totalWidth - _centerMinWidth - _detailMinWidth - _AppShellMetrics.splitterWidth * 2,
    );
    final double rail = railWidth.clamp(_railMinWidth, railCeiling);
    final double rest = math.max(0, totalWidth - rail - _AppShellMetrics.splitterWidth * 2);
    // 详情槽 = 剩余宽的 [_detailFraction]（夹逼到两个最小宽之间）。
    final double detailMin = math.min(_detailMinWidth, rest / 2);
    final double detailMax = math.max(rest - _centerMinWidth, rest / 2);
    final double detailWidth = (rest * _detailFraction).clamp(detailMin, math.max(detailMin, detailMax));
    final double centerWidth = rest - detailWidth;
    _lastRest = rest; // 供拖动换算（build 内普通赋值，不触发重建）。
    return Scaffold(
      body: PopScope(
        // Android 平板横屏：中间栈非空时系统返回键先退栈。
        canPop: !_centerHasRoutes,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (!didPop) {
            centerSlotNavigatorKey.currentState?.maybePop();
          }
        },
        child: Row(
          children: <Widget>[
            SizedBox(
              width: rail,
              child: _rail(context, extended: rail >= _railExpandedWidth, showToggle: true),
            ),
            _Splitter(
              tooltip: '拖动 · 调整导航栏宽度',
              onDragStart: _railDragStart,
              onDragTo: _railDragTo,
              onDragEnd: _dragEnd,
            ),
            SizedBox(width: centerWidth, child: _centerPane(context)),
            _Splitter(
              tooltip: '拖动 · 调整详情栏占比',
              onDragStart: _detailDragStart,
              onDragTo: _detailDragTo,
              onDragEnd: _dragEnd,
            ),
            SizedBox(width: detailWidth, child: const _DetailSlot()),
          ],
        ),
      ),
    );
  }

  /// 中间功能区：一层**嵌套 Navigator**，「中间页面栈」的栈底 = 当前 Tab 内容
  /// （[_centerRoot]），栈上是 openCenterPage 压入的页面——书聚合页 / 设置 / 关于 /
  /// 热门榜 / 在线帖等页面在 expanded 下压进这里（core/nav/center_slot.dart），
  /// 左导航与右详情槽保持可见（用户口径：不再单独弹全窗页）。
  ///
  /// 为什么栈底要放进路由里而不是用 Stack 垫在下面：ModalRoute 自带 ModalBarrier
  /// （routes.dart:1290+）会吃掉下层所有指针事件，垫在 Navigator 底下的 Tab 内容
  /// 将完全点不动（实测：首页齿轮钮点不中）。
  ///
  /// 嵌套 Navigator 让页面拿到真实 ModalRoute，故 AppBar 返回钮、页内
  /// `Navigator.of(context).push`（设置 → 字体管理）都天然落在中间栏内。
  Widget _centerPane(BuildContext context) {
    return Navigator(
      key: centerSlotNavigatorKey,
      observers: <NavigatorObserver>[_CenterDepthObserver(_onCenterDepth)],
      onGenerateRoute: (RouteSettings settings) => PageRouteBuilder<void>(
        settings: settings,
        pageBuilder: (BuildContext context, Animation<double> a, Animation<double> b) =>
            ValueListenableBuilder<Widget>(
          valueListenable: _centerRoot,
          builder: (BuildContext context, Widget value, Widget? child) => value,
        ),
      ),
    );
  }

  void _onCenterDepth(bool hasRoutes) {
    if (hasRoutes != _centerHasRoutes) {
      setState(() => _centerHasRoutes = hasRoutes);
    }
  }

  Widget _rail(BuildContext context, {required bool extended, bool showToggle = false}) {
    final int selected = widget.navigationShell.currentIndex;
    final NavigationRail rail = NavigationRail(
      extended: extended,
      // §9.5：extended Rail 顶部品牌头（rail-mark + serif 品牌名 + 库容量 caption）。
      // QA ISSUE-3。标准 Rail 保持原几何（M1-② 已验收 V3），不加 leading。
      leading: extended ? const _RailBrand() : null,
      selectedIndex: selected,
      onDestinationSelected: _onDestinationSelected,
      labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
      minWidth: _railMinWidth,
      minExtendedWidth: _railExpandedWidth,
      destinations: <NavigationRailDestination>[
        for (int i = 0; i < _tabs.length; i++)
          NavigationRailDestination(
            icon: _navIcon(context, _tabs[i].icon, selected: false, extended: extended),
            selectedIcon: _navIcon(context, _tabs[i].icon, selected: true, extended: extended),
            label: _navLabel(context, _tabs[i].label, selected: i == selected, extended: extended),
          ),
      ],
    );
    if (!showToggle) {
      // medium 档：原几何不变（仅 NavigationRail 本体，宽度由外层 SizedBox/Expanded 决定）。
      return rail;
    }
    return Column(
      children: <Widget>[
        Expanded(child: rail),
        _RailToggleButton(collapsed: _railWidth <= _railCollapsedWidth, onTap: _toggleRail),
      ],
    );
  }
}

/// 左侧功能栏底部的收起 / 展开钮（用户口径：左侧功能区底部要有一个收起和展开的按钮）。
class _RailToggleButton extends StatelessWidget {
  const _RailToggleButton({required this.collapsed, required this.onTap});

  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppSpacing s = AppSpacing.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(s.space2, 0, s.space2, s.space3),
      child: Tooltip(
        message: collapsed ? '展开导航栏' : '收起导航栏',
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mdBorder,
          child: SizedBox(
            height: AppMetrics.minTouchTarget,
            child: Center(
              // chev 原生朝下：旋 1/2 圈得朝上（收起）/ 0 圈朝下（展开）。
              child: RotatedBox(
                quarterTurns: collapsed ? 3 : 1,
                child: AppIcon('chev', size: 20, color: c.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 三栏之间的分隔条：1px 发丝线居中 + 8px 拖动热区（悬停高亮，鼠标指针变左右调整）。
///
/// 抓手统一为「**按住分隔条拖动**」（鼠标/触屏同款；用户口径：分隔条要跟手）。
/// 位移一律用**指针全局坐标的绝对差**换算（见 AppShell 的 _railDragTo/_detailDragTo）：
/// 起点由 onPanDown 记录，之后直接 `起点值 + (当前 x − 起点 x)`，不逐帧累加 delta，
/// 也不依赖手势相位——左拖就是变小、右拖就是变大（修「鼠标往左拖结果往右」）。
/// Tooltip 走 manual 触发，避免与拖动抢手势（鼠标悬停仍会显示提示，见 raw_tooltip.dart:118）。
class _Splitter extends StatefulWidget {
  const _Splitter({
    required this.tooltip,
    required this.onDragStart,
    required this.onDragTo,
    required this.onDragEnd,
  });

  final String tooltip;

  /// 拖动开始（参数 = 指针全局 x）。
  final ValueChanged<double> onDragStart;

  /// 拖动中（参数 = 指针全局 x）。
  final ValueChanged<double> onDragTo;

  final VoidCallback onDragEnd;

  @override
  State<_Splitter> createState() => _SplitterState();
}

class _SplitterState extends State<_Splitter> {
  bool _dragging = false;
  bool _hover = false;

  void _start(double globalX) {
    setState(() => _dragging = true);
    widget.onDragStart(globalX);
  }

  void _move(double globalX) {
    // 不按本地 _dragging 门禁：长按识别器与平移识别器同场竞争时，前者落败会先回调
    // onLongPressCancel，把「正在拖动」标志提前清掉（实测：详情分隔条因此整段拖动失效）。
    // 拖动是否继续由父侧「有没有起点」决定（AppShell._dragOriginX），这里只负责转发。
    widget.onDragTo(globalX);
  }

  void _end() {
    if (!_dragging) {
      return;
    }
    setState(() => _dragging = false);
    widget.onDragEnd();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final Color line = _dragging ? c.accent : (_hover ? c.borderStrong : c.border);
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Tooltip(
        message: widget.tooltip,
        triggerMode: TooltipTriggerMode.manual,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // 单一抓手：**按住即拖**（鼠标/触屏一致）。不用长按识别器 —— 它与平移识别器
          // 同场竞争时，落败回调（onLongPressCancel）会先于 onPanUpdate 到达，
          // 把拖动状态提前清掉（实测：详情分隔条整段拖动失效）。
          // 起点取 onPanDown（按下那一刻）：用 onPanStart 会把 slop 那段位移丢掉。
          onPanDown: (DragDownDetails d) => _start(d.globalPosition.dx),
          onPanUpdate: (DragUpdateDetails d) => _move(d.globalPosition.dx),
          onPanEnd: (DragEndDetails d) => _end(),
          onPanCancel: _end,
          child: SizedBox(
            width: _AppShellMetrics.splitterWidth,
            child: Center(
              child: Container(
                width: _dragging || _hover ? 3 : AppMetrics.hairline,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: line,
                  borderRadius: _dragging ? AppRadius.pillBorder : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 中间栈深度观察者（PopScope 的 canPop 依据）。
class _CenterDepthObserver extends NavigatorObserver {
  _CenterDepthObserver(this.onChanged);

  final ValueChanged<bool> onChanged;

  void _sync() => onChanged(navigator?.canPop() ?? false);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _sync();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _sync();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _sync();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _sync();
}

/// 骨架构型常量（分隔条宽 = 布局计算与 _Splitter 同源，禁止两处各写一份）。
abstract final class _AppShellMetrics {
  static const double splitterWidth = 8;
}

/// 库容量（品牌头 caption 用，§9.5）：五维计数聚合的 total 即全库条目数。
final FutureProvider<int> librarySizeProvider = FutureProvider<int>(
  (Ref ref) => ref.watch(queriesProvider).dimensionCounts().then((CategoryCounts c) => c.total),
);

/// extended Rail 品牌头（§9.5：rail-mark 40 圆 accent-soft 底 + serif 品牌名 + caption 库容量）。
///
/// QA ISSUE-3。品牌名字号走 headline 字阶 token（字体家族由 FontFamilySet 注入，
/// 不得出现字面量——守卫见 test/font_guard_test.dart）。
///
/// 宽度必须**显式给定**：NavigationRail 的 leading 在 extended 展开动画期间会拿到无界宽约束，
/// 此时 Row 里放 Expanded（非零 flex）会直接触发
/// 「RenderFlex children have non-zero flex but incoming width constraints are unbounded」。
class _RailBrand extends ConsumerWidget {
  const _RailBrand();

  /// 256（NavigationRail extended 默认宽）− 2×16（左右内边距）。
  static const double _contentWidth = 224;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final int? total = ref.watch(librarySizeProvider).value;
    // 库容量未就绪时退化为纯标签，不显示假 0（§5.12 诚实标注同源口径）。
    final String capacity = total == null ? '内置库' : '内置库 · $total 条';
    return Padding(
      padding: EdgeInsets.fromLTRB(s.space4, s.space5, s.space4, s.space4),
      child: SizedBox(
        width: _contentWidth,
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
              child: Text('书', style: t.title.copyWith(color: c.accentStrong)),
            ),
            SizedBox(width: s.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(AppConstants.appName, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: t.headline.copyWith(color: c.text)),
                  Text(capacity, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AppTypography.tabular(t.caption.copyWith(color: c.textMuted))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 发丝分隔线（1px，色值走 dividerTheme = AppColors.border）。
class _HairlineV extends StatelessWidget {
  const _HairlineV();

  @override
  Widget build(BuildContext context) {
    return const VerticalDivider(width: AppMetrics.hairline, thickness: AppMetrics.hairline);
  }
}

/// expanded 双栏右侧详情槽：阅读列 ≤720dp 居中（WindowSize.maxContentWidth）。
/// M1-④ 接线：帖子详情以 embedded 形态在右槽原位切换（detailSelectionProvider），
/// 未选中时显示空态（设计系统 §9.7 list-detail：expanded 详情常驻式）。
class _DetailSlot extends ConsumerWidget {
  const _DetailSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PostSelection? selection = ref.watch(detailSelectionProvider);
    if (selection != null) {
      return ContentDetailPage(
        key: ValueKey<int>(selection.postId),
        selection: selection,
        embedded: true,
      );
    }
    final AppColors colors = AppColors.of(context);
    final AppTypography typography = AppTypography.of(context);
    return ConstrainedContent(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // 空态规格（§4）：线稿 accent · 64px。阅读语义 → 设计稿 i-book。
          AppIcon('book', size: AppMetrics.emptyStateIconSize, color: colors.accent),
          SizedBox(height: AppSpacing.of(context).space4),
          Text('选择左侧内容查看详情', style: typography.secondary.copyWith(color: colors.textMuted)),
        ],
      ),
    );
  }
}
