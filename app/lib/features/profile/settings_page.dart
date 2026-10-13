import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fonts/font_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'font_manage_page.dart';

/// 设置页（字体管理 / 主题模式 / 主题色 swatch / 减弱动效开关 / BDUSS / 数据包 / 并发 / 关于）。
///
/// v1.4：字体管理已实装（角色字体槽 + 用户导入字体）。
/// 其余设置项不在 M1-④ 范围（M1-④ = 五维搜索 / 分类手风琴 / 富文本渲染 / 书签收藏历史）。
/// TODO(M2)：themeMode·reduceMotion 联动 + 数据包管理 + 采集并发/仅 WiFi + BDUSS 加密存储，
/// 落 settings 表 KV（键名已备于 core/constants.dart: SettingsKeys）；
/// 见 docs/开发路线图.md Phase 4、设计系统 v1.2 §3 #07、原型 §5.10 设置项清单。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  /// 父级→子级 = vertical 共享轴（§6.3，与 /settings 路由同族转场）。
  void _openFontManage(BuildContext context) {
    final AppMotionTheme motion = AppMotionTheme.of(context);
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: motion.transition.duration,
        reverseTransitionDuration: motion.transition.duration,
        pageBuilder: (context, animation, secondaryAnimation) => const FontManagePage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) => SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.vertical,
          fillColor: AppColors.of(context).canvas,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FontService fonts = ref.watch(fontServiceProvider);
    final AppTypography t = AppTypography.of(context);
    final AppColors colors = AppColors.of(context);
    final AppSpacing space = AppSpacing.of(context);
    final String fontSummary = fonts.registry.isEmpty
        ? '系统默认字体 · 可按角色换字体'
        : '已导入 ${fonts.registry.length} 个字体';

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(space.pagePadding, space.space4, space.pagePadding, space.space8),
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(bottom: space.space3),
            child: Text('外观', style: t.label.copyWith(color: colors.textMuted)),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.font_download_outlined, color: colors.accent),
              title: Text('字体管理', style: t.bodyStrong.copyWith(color: colors.text)),
              subtitle: Text(fontSummary, style: t.caption.copyWith(color: colors.textMuted)),
              trailing: Icon(Icons.chevron_right, color: colors.textMuted),
              onTap: () => _openFontManage(context),
            ),
          ),
        ],
      ),
    );
  }
}
