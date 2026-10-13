import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_shell.dart';
import 'features/category/category_page.dart';
import 'features/collect/collect_page.dart';
import 'features/content/book_detail_page.dart';
import 'features/content/content_detail_page.dart';
import 'features/content/detail_slot.dart';
import 'features/home/home_page.dart';
import 'features/profile/profile_page.dart';
import 'features/profile/settings_page.dart';
import 'features/search/search_page.dart';
import 'theme/app_colors.dart';
import 'theme/app_motion.dart';

/// 全局路由（原型 §4 信息架构：5 Tab + 内容详情/书聚合/设置）。
///
/// 转场语义（§6.3）：Tab 根切换无转场（StatefulShellRoute.indexedStack instant 切换）；
/// 列表→详情 = horizontal 共享轴；父级→子级（设置）= vertical；时长/曲线取自 AppMotionTheme。
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((ref) => createAppRouter());

/// 路由表工厂（[initialLocation] 供 widget 测试直入指定页面）。
GoRouter createAppRouter({String initialLocation = '/home'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(path: '/home', builder: (context, state) => const HomePage()),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(path: '/category', builder: (context, state) => const CategoryPage()),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              // 搜索台携 URI 条件进入（书名点击 q= / 分类页「查看全部结果」五维 + browse=1，§5.6/§5.12）。
              GoRoute(
                path: '/search',
                builder: (context, state) => SearchPage(initialParams: state.uri.queryParameters),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(path: '/collect', builder: (context, state) => const CollectPage()),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/post/:id',
        pageBuilder: (context, state) => _sharedAxisPage(
          context: context,
          state: state,
          type: SharedAxisTransitionType.horizontal,
          child: ContentDetailPage(
            selection: state.extra is PostSelection
                ? state.extra! as PostSelection
                : PostSelection(postId: _idParam(state)),
          ),
        ),
      ),
      GoRoute(
        path: '/book/:id',
        pageBuilder: (context, state) => _sharedAxisPage(
          context: context,
          state: state,
          type: SharedAxisTransitionType.horizontal,
          child: BookDetailPage(
            bookGroupId: _idParam(state),
            args: state.extra is BookNavArgs ? state.extra! as BookNavArgs : null,
          ),
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => _sharedAxisPage(
          context: context,
          state: state,
          type: SharedAxisTransitionType.vertical,
          child: const SettingsPage(),
        ),
      ),
    ],
  );
}

int _idParam(GoRouterState state) => int.tryParse(state.pathParameters['id'] ?? '') ?? 0;

/// SharedAxis 页面工厂（§6.3 代码草图；fillColor 取 canvas 与页面底一致）。
CustomTransitionPage<void> _sharedAxisPage({
  required BuildContext context,
  required GoRouterState state,
  required SharedAxisTransitionType type,
  required Widget child,
}) {
  final AppMotionTheme motion = AppMotionTheme.of(context);
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: motion.transition.duration,
    reverseTransitionDuration: motion.transition.duration,
    transitionsBuilder: (context, animation, secondaryAnimation, pageChild) => SharedAxisTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      transitionType: type,
      fillColor: AppColors.of(context).canvas,
      child: pageChild,
    ),
    child: child,
  );
}
