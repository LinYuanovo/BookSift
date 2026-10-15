import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants.dart';
import 'core/icons.dart';
import 'core/window_size.dart';
import 'data/repo/queries.dart';
import 'data/repo/queries_providers.dart';
import 'features/content/content_detail_page.dart';
import 'features/content/detail_slot.dart';
import 'theme/app_colors.dart';
import 'theme/app_spacing.dart';
import 'theme/app_typography.dart';

typedef _TabSpec = ({String label, String icon});

/// 自适应应用骨架（M1-②）：
/// compact(<600dp) → 底部 NavigationBar 4 Tab；
/// medium(600–1024dp，**含 1024**) → NavigationRail；
/// expanded(>1024dp) → extended NavigationRail（品牌头）+ list-detail 双栏（右栏为详情槽位）。
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<_TabSpec> _tabs = <_TabSpec>[
    (label: '首页', icon: 'home'),
    (label: '搜索', icon: 'search'),
    (label: '采集', icon: 'collect'),
    (label: '我的', icon: 'user'),
  ];

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
    // 重复点击当前 Tab 回到该分支根位置（go_router 惯例）。
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return switch (WindowSize.fromWidth(constraints.maxWidth)) {
          WindowSizeClass.compact => _compact(context),
          WindowSizeClass.medium => _withRail(context, extended: false),
          WindowSizeClass.expanded => _expanded(context),
        };
      },
    );
  }

  Widget _compact(BuildContext context) {
    final int selected = navigationShell.currentIndex;
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    return Scaffold(
      body: navigationShell,
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
          _rail(context, extended),
          const _HairlineV(),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }

  Widget _expanded(BuildContext context) {
    return Scaffold(
      body: Row(
        children: <Widget>[
          _rail(context, true),
          const _HairlineV(),
          // list-detail 双栏：左 = 当前 Tab 列表区，右 = 详情槽位（内容详情页于 M1-④ 接入右槽）。
          Expanded(flex: 3, child: navigationShell),
          const _HairlineV(),
          const Expanded(flex: 2, child: _DetailSlot()),
        ],
      ),
    );
  }

  Widget _rail(BuildContext context, bool extended) {
    final int selected = navigationShell.currentIndex;
    return NavigationRail(
      extended: extended,
      // §9.5：extended Rail 顶部品牌头（rail-mark + serif 品牌名 + 库容量 caption）。
      // QA ISSUE-3。标准 Rail 保持原几何（M1-② 已验收 V3），不加 leading。
      leading: extended ? const _RailBrand() : null,
      selectedIndex: selected,
      onDestinationSelected: _onDestinationSelected,
      labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
      destinations: <NavigationRailDestination>[
        for (int i = 0; i < _tabs.length; i++)
          NavigationRailDestination(
            icon: _navIcon(context, _tabs[i].icon, selected: false, extended: extended),
            selectedIcon: _navIcon(context, _tabs[i].icon, selected: true, extended: extended),
            label: _navLabel(context, _tabs[i].label, selected: i == selected, extended: extended),
          ),
      ],
    );
  }
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

/// expanded 双栏右侧详情槽位：阅读列 ≤720dp 居中（WindowSize.maxContentWidth）。
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
