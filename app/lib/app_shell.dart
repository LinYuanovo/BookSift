import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants.dart';
import 'core/window_size.dart';
import 'data/repo/queries.dart';
import 'features/content/content_detail_page.dart';
import 'features/content/detail_slot.dart';
import 'theme/app_colors.dart';
import 'theme/app_spacing.dart';
import 'theme/app_typography.dart';

typedef _TabSpec = ({String label, IconData icon, IconData selectedIcon});

/// 自适应应用骨架（M1-②）：
/// compact(<600dp) → 底部 NavigationBar 5 Tab；
/// medium(600–1024dp，**含 1024**) → NavigationRail；
/// expanded(>1024dp) → extended NavigationRail（品牌头）+ list-detail 双栏（右栏为详情槽位）。
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<_TabSpec> _tabs = <_TabSpec>[
    (label: '首页', icon: Icons.home_outlined, selectedIcon: Icons.home),
    (label: '分类', icon: Icons.category_outlined, selectedIcon: Icons.category),
    (label: '搜索', icon: Icons.search, selectedIcon: Icons.search),
    (label: '采集', icon: Icons.cloud_download_outlined, selectedIcon: Icons.cloud_download),
    (label: '我的', icon: Icons.person_outline, selectedIcon: Icons.person),
  ];

  void _onDestinationSelected(int index) {
    // 重复点击当前 Tab 回到该分支根位置（go_router 惯例）。
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return switch (WindowSize.fromWidth(constraints.maxWidth)) {
          WindowSizeClass.compact => _compact(),
          WindowSizeClass.medium => _withRail(extended: false),
          WindowSizeClass.expanded => _expanded(),
        };
      },
    );
  }

  Widget _compact() {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: <NavigationDestination>[
          for (final tab in _tabs)
            NavigationDestination(icon: Icon(tab.icon), selectedIcon: Icon(tab.selectedIcon), label: tab.label),
        ],
      ),
    );
  }

  Widget _withRail({required bool extended}) {
    return Scaffold(
      body: Row(
        children: <Widget>[
          _rail(extended),
          const _HairlineV(),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }

  Widget _expanded() {
    return Scaffold(
      body: Row(
        children: <Widget>[
          _rail(true),
          const _HairlineV(),
          // list-detail 双栏：左 = 当前 Tab 列表区，右 = 详情槽位（内容详情页于 M1-④ 接入右槽）。
          Expanded(flex: 3, child: navigationShell),
          const _HairlineV(),
          const Expanded(flex: 2, child: _DetailSlot()),
        ],
      ),
    );
  }

  Widget _rail(bool extended) {
    return NavigationRail(
      extended: extended,
      // §9.5：extended Rail 顶部品牌头（rail-mark + serif 品牌名 + 库容量 caption）。
      // QA ISSUE-3。标准 Rail 保持原几何（M1-② 已验收 V3），不加 leading。
      leading: extended ? const _RailBrand() : null,
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: _onDestinationSelected,
      labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
      destinations: <NavigationRailDestination>[
        for (final tab in _tabs)
          NavigationRailDestination(icon: Icon(tab.icon), selectedIcon: Icon(tab.selectedIcon), label: Text(tab.label)),
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
          // 空态规格（§4）：线稿 accent · 64px。
          Icon(Icons.auto_stories_outlined, size: AppMetrics.emptyStateIconSize, color: colors.accent),
          SizedBox(height: AppSpacing.of(context).space4),
          Text('选择左侧内容查看详情', style: typography.secondary.copyWith(color: colors.textMuted)),
        ],
      ),
    );
  }
}
