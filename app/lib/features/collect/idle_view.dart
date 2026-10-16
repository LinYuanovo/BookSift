import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../collector/collect_controller.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/window_size.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../home/cards.dart';
import 'buttons.dart';
import 'forum_cards.dart';

/// 空闲态视图（原型 §5.9：账号卡 / 关注吧卡片列表 / + 添加贴吧 / 立即采集大按钮 /
/// 最近日志列表）。
///
/// 宽屏（medium+）沿用 v1.3 宽屏语汇的双栏排布（§9.6/§9.3：关注吧 + 操作左栏，
/// 日志右栏；仪表盘只在运行态）——不强行仪表盘化。
class CollectIdleView extends ConsumerWidget {
  const CollectIdleView({super.key, required this.wide});

  final bool wide;

  Future<void> _startAll(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(collectControllerProvider).startAll();
    } catch (_) {
      if (context.mounted) {
        showAppToast(context, '启动失败');
      }
    }
  }

  /// 「立即采集」大按钮（§5.9 '▶ 立即采集(预计2分钟)'；btn-accent 全宽，index.html:324/333）。
  Widget _startButton(BuildContext context, WidgetRef ref) {
    return CollectButton(
      label: '立即采集（预计2分钟）',
      iconName: 'play',
      block: true,
      onPressed: () => _startAll(context, ref),
    );
  }

  EdgeInsets _listPadding(BuildContext context) {
    final AppSpacing s = AppSpacing.of(context);
    // .pad：space3 space5 space5（index.html:248）。
    return EdgeInsets.fromLTRB(s.pagePadding, s.space3, s.pagePadding, s.space5);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSpacing s = AppSpacing.of(context);
    if (!wide) {
      return ListView(
        padding: _listPadding(context),
        children: <Widget>[
          const AccountCard(),
          const SectionTitle(label: '关注吧'),
          const ForumSection(),
          SizedBox(height: s.space4),
          _startButton(context, ref),
          const SectionTitle(label: '最近日志'),
          const RecentLogsList(),
        ],
      );
    }
    // medium+/expanded：双栏（左 = 账号 + 关注吧 + 操作 ≤720 阅读列语汇，右 = 日志栏）。
    return ConstrainedContent(
      maxWidth: 1200, // §9.2 --content-max（超大窗口内容上限）
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            flex: 3,
            child: ListView(
              padding: _listPadding(context),
              children: <Widget>[
                const AccountCard(),
                const SectionTitle(label: '关注吧'),
                const ForumSection(),
                SizedBox(height: s.space4),
                _startButton(context, ref),
              ],
            ),
          ),
          VerticalDivider(
            width: AppMetrics.hairline,
            thickness: AppMetrics.hairline,
            color: AppColors.of(context).border,
          ),
          Expanded(
            flex: 2,
            child: ListView(
              padding: _listPadding(context),
              children: <Widget>[
                const SectionTitle(label: '最近日志'),
                const RecentLogsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
