import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../collector/collect_controller.dart';
import '../../core/icons.dart';
import '../../data/db/app_database.dart';
import '../../data/repo/collect_repository_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../home/cards.dart';
import 'badges.dart';
import 'buttons.dart';
import 'collect_format.dart';

// 采集中心空闲态组件（原型 §5.9 行 479–512：账号卡 / 关注吧卡片列表 / 添加吧 /
// 立即采集大按钮 / 最近日志列表；空态引导添加默认两吧）。

/// 防御性读取层：DB-backed 契约 provider 的优雅降级包装。
///
/// - 上游 loading → 本层同步 loading（await 上游 future，空闲态先骨架后数据，不闪空态）；
/// - 上游 error（真实设备上的 DB 异常）→ 降级空列表 → 空态引导，不做假数据、不崩页。
///
/// 注意：widget 测试渲染采集页时必须 override 上游契约 provider（哨兵 appDatabaseProvider
/// 一读即抛且 Riverpod 会把该错误上报 zone，包一层 catch 拦不住上报本身）——
/// 见 test/support/fake_collect.dart 的 collectTestOverrides。
final FutureProvider<List<CollectionStateEntry>> collectForumsSafeProvider =
    FutureProvider<List<CollectionStateEntry>>((Ref ref) async {
      try {
        return await ref.watch(collectForumsProvider.future);
      } catch (_) {
        return <CollectionStateEntry>[];
      }
    });

final FutureProvider<List<CollectionLog>> recentCollectLogsSafeProvider =
    FutureProvider<List<CollectionLog>>((Ref ref) async {
      try {
        return await ref.watch(recentCollectLogsProvider.future);
      } catch (_) {
        return <CollectionLog>[];
      }
    });



/// 账号卡：匿名模式徽标 + BDUSS 诚实标注（P2 不做假功能，§5.9 '[导入BDUSS提配额]'）。
class AccountCard extends StatelessWidget {
  const AccountCard({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    return Container(
      padding: EdgeInsets.all(s.cardPadding),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: c.border, width: AppMetrics.hairline),
      ),
      child: Row(
        children: <Widget>[
          AppIcon('user', size: 20, color: c.textMuted),
          SizedBox(width: s.space3),
          const CollectBadge(label: '匿名模式', variant: CollectBadgeVariant.originSelf),
          const Spacer(),
          // §8.13：匿名档四接口全可用；BDUSS 导入属 P2 —— 只标注，不做假入口。
          // Dynamic Type：标注可收缩省略（1.0 缩放取固有宽，视觉不变）。
          Flexible(
            child: Text(
              '导入 BDUSS 可提高配额（暂未提供）',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.caption.copyWith(color: c.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// 关注吧卡片（§5.9：吧名 + 启用开关 + 水位 + 上次结果 + 冷却倒计时 danger）。
class ForumCard extends StatelessWidget {
  const ForumCard({super.key, required this.entry, required this.onToggleEnabled, this.now});

  final CollectionStateEntry entry;
  final ValueChanged<bool> onToggleEnabled;

  /// 倒计时基准（测试注入；null = DateTime.now()）。
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final DateTime ref = now ?? DateTime.now();
    final bool cooling = entry.cooldownUntil != null && entry.cooldownUntil!.isAfter(ref);

    // 上次结果行（§5.9 '上次: 成功 +37帖 · 2小时前' / '上次: 接口异常(冷却中48m)'）。
    final Color statusColor = switch (entry.lastStatus) {
      'ok' => c.recommend,
      'api_error' || 'rate_limited' => c.danger,
      'partial' => c.accentStrong,
      _ => c.textMuted,
    };
    final List<InlineSpan> lastLine = <InlineSpan>[
      TextSpan(text: '上次: ', style: t.caption.copyWith(color: c.textMuted)),
      TextSpan(
        text: lastStatusLabel(entry.lastStatus),
        style: t.caption.copyWith(color: statusColor, fontWeight: FontWeight.w600),
      ),
    ];
    if (cooling) {
      final String remain = cooldownRemain(entry.cooldownUntil!, now: ref);
      // rate_limited 的状态标签本身即「冷却中」，避免「冷却中 冷却中 48m」重复。
      final bool labelHasCooling = lastStatusLabel(entry.lastStatus).contains('冷却中');
      lastLine.add(
        TextSpan(
          text: labelHasCooling ? ' $remain' : ' 冷却中 $remain',
          style: t.caption.copyWith(color: c.danger, fontWeight: FontWeight.w600),
        ),
      );
    }
    if (entry.lastRunAt != null) {
      if (entry.totalThreads > 0) {
        lastLine.add(
          TextSpan(
            text: ' · 累计 ${entry.totalThreads} 帖',
            style: AppTypography.tabular(t.caption.copyWith(color: c.textMuted)),
          ),
        );
      }
      lastLine.add(
        TextSpan(
          text: ' · ${relativeTime(entry.lastRunAt!, now: ref)}',
          style: t.caption.copyWith(color: c.textMuted),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(s.cardPadding),
      decoration: BoxDecoration(
        color: cooling ? c.dangerSoft.withValues(alpha: 0.35) : c.surfaceRaised,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: cooling ? c.danger : c.border, width: AppMetrics.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(entry.fname, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: t.cardTitle.copyWith(color: c.text)),
              ),
              Switch(value: entry.enabled, onChanged: onToggleEnabled),
            ],
          ),
          // 水位行（§5.9 '水位: 2026-10-11 18:32'；值 mono，与 watermark 卡同口径）。
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(text: '水位 ', style: t.caption.copyWith(color: c.textMuted)),
                TextSpan(
                  text: formatWatermark(entry.lastThreadTime),
                  style: AppTypography.tabular(
                    t.mono.copyWith(fontSize: 11.5, fontWeight: FontWeight.w500, color: c.text),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: s.space1),
          Text.rich(TextSpan(children: lastLine)),
        ],
      ),
    );
  }
}

/// 关注吧区（列表 / 骨架 / 空态引导，数据源 collectForumsProvider）。
class ForumSection extends ConsumerWidget {
  const ForumSection({super.key});

  Future<void> _seedDefaults(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(collectRepositoryProvider).seedDefaultsIfEmpty();
      ref.invalidate(collectForumsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('添加失败')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSpacing s = AppSpacing.of(context);
    final AsyncValue<List<CollectionStateEntry>> forums = ref.watch(collectForumsSafeProvider);
    final List<CollectionStateEntry>? data = forums.value;
    if (data == null) {
      // loading 骨架（safe 层保证不会进入 error 分支：DB 异常降级为空列表）。
      if (forums.isLoading) {
        return Column(
          children: <Widget>[
            const SkeletonBlock(height: 108),
            SizedBox(height: s.space3),
            const SkeletonBlock(height: 108),
          ],
        );
      }
    }
    if (data == null || data.isEmpty) {
      // §5.9 空态：无关注吧 → 引导添加默认两吧（正常流程 provider 已 seedDefaults，防御性）。
      return CollectEmptyForums(onSeed: () => _seedDefaults(context, ref));
    }
    return Column(
      children: <Widget>[
        for (final CollectionStateEntry entry in data) ...<Widget>[
          ForumCard(
            entry: entry,
            onToggleEnabled: (bool v) async {
              try {
                await ref.read(collectControllerProvider).setForumEnabled(entry.fname, v);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失败')));
                }
              }
              ref.invalidate(collectForumsProvider);
            },
          ),
          SizedBox(height: s.space3),
        ],
        CollectButton(
          label: '添加贴吧',
          kind: CollectButtonKind.outline,
          block: true,
          iconName: 'plus',
          onPressed: () => showAddForumDialog(context),
        ),
      ],
    );
  }
}

/// 空态（线稿 collect 64px accent + 引导按钮，§4 空态规格）。
class CollectEmptyForums extends StatelessWidget {
  const CollectEmptyForums({super.key, required this.onSeed});

  final VoidCallback onSeed;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: s.emptyStatePaddingV, horizontal: s.emptyStatePaddingH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 空态线稿 64px（§4 .empty .art；SVG stroke 随尺寸等比放大）。
          AppIcon('collect', size: AppMetrics.emptyStateIconSize, color: c.accent),
          SizedBox(height: s.space4),
          Text('还没有关注吧', style: t.headline.copyWith(color: c.text)),
          SizedBox(height: s.space2),
          Text('添加默认两大扫书贴吧，开始增量采集', style: t.secondary.copyWith(color: c.textMuted)),
          SizedBox(height: s.space5),
          CollectButton(label: '添加默认关注吧', onPressed: onSeed),
        ],
      ),
    );
  }
}

/// 添加贴吧对话框（§5.9：输入吧名 → 验证存在性 → 写入 collection_state；
/// 失败原因 [CollectAddForumException.reason] 以 danger 文案显示在对话框内）。
Future<void> showAddForumDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) => const _AddForumDialog(),
  );
}

class _AddForumDialog extends ConsumerStatefulWidget {
  const _AddForumDialog();

  @override
  ConsumerState<_AddForumDialog> createState() => _AddForumDialogState();
}

class _AddForumDialogState extends ConsumerState<_AddForumDialog> {
  final TextEditingController _input = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String name = _input.text.trim();
    if (name.isEmpty || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(collectControllerProvider).addForum(name);
      ref.invalidate(collectForumsProvider);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on CollectAddForumException catch (e) {
      setState(() {
        _error = e.reason;
        _busy = false;
      });
    } catch (_) {
      setState(() {
        _error = '添加失败';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    return AlertDialog(
      title: Text('添加贴吧', style: t.headline.copyWith(color: c.text)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _input,
            autofocus: true,
            enabled: !_busy,
            decoration: const InputDecoration(hintText: '吧名'),
            onSubmitted: (_) => _submit(),
            style: t.body.copyWith(color: c.text),
          ),
          if (_error != null) ...<Widget>[
            SizedBox(height: s.space2),
            Text(_error!, style: t.caption.copyWith(color: c.danger, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text('取消', style: t.bodyStrong.copyWith(color: c.textSecondary)),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: Text('确认', style: t.bodyStrong.copyWith(color: c.accentStrong)),
        ),
      ],
    );
  }
}

/// 最近日志列表（§5.9 '10-12 08:00 yy小说吧 +37/12楼'；≤50 条，数据源
/// recentCollectLogsProvider；状态徽标映射同 collection_state.last_status 口径）。
class RecentLogsList extends ConsumerWidget {
  const RecentLogsList({super.key});

  static (CollectBadgeVariant, String) _badgeOf(String status) => switch (status) {
    'ok' => (CollectBadgeVariant.rec, '成功'),
    'partial' => (CollectBadgeVariant.kind, '部分成功'),
    'api_error' => (CollectBadgeVariant.avoid, '接口异常'),
    'rate_limited' => (CollectBadgeVariant.avoid, '冷却中'),
    'canceled' => (CollectBadgeVariant.ask, '已取消'),
    _ => (CollectBadgeVariant.ask, status),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final AsyncValue<List<CollectionLog>> logs = ref.watch(recentCollectLogsSafeProvider);
    final List<CollectionLog> data = logs.value ?? <CollectionLog>[];
    if (logs.isLoading) {
      return const SkeletonBlock(height: 120);
    }
    if (data.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: s.space4),
        child: Text('暂无日志', style: t.caption.copyWith(color: c.textMuted)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: c.border, width: AppMetrics.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          for (int i = 0; i < data.length; i++) ...<Widget>[
            if (i > 0) Divider(height: AppMetrics.hairline, thickness: AppMetrics.hairline, color: c.border),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: s.space4, vertical: s.space3),
              child: Row(
                children: <Widget>[
                  // Dynamic Type：时间/计数 loose-Flexible 收缩省略，1.0 缩放取固有宽视觉不变。
                  Flexible(
                    child: Text(
                      formatMonthDayTime(data[i].runAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.tabular(
                        t.mono.copyWith(fontSize: 11.5, color: c.textMuted),
                      ),
                    ),
                  ),
                  SizedBox(width: s.space3),
                  Expanded(
                    child: Text(
                      data[i].fname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.caption.copyWith(color: c.textSecondary),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      '+${data[i].threadsAdded}帖/${data[i].floorsAdded}楼',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.tabular(t.caption.copyWith(color: c.text)),
                    ),
                  ),
                  SizedBox(width: s.space3),
                  CollectBadge(label: _badgeOf(data[i].status).$2, variant: _badgeOf(data[i].status).$1, height: 20),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
