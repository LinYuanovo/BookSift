import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/fonts/font_service.dart';
import '../../core/icons.dart';
import '../../core/nav/center_slot.dart';
import '../../core/nav/overlay_motion.dart';
import '../../core/nav/page_transition.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/update/update_controller.dart';
import '../../core/update/update_download_controller.dart';
import '../../core/update/update_downloader.dart';
import '../../core/update/update_platform.dart';
import '../../core/update/update_service.dart';
import '../../theme/app_accent.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../theme/appearance_settings.dart';
import '../../collector/collect_controller.dart';
import '../../collector/collect_providers.dart';
import '../../collector/scheduler.dart';
import '../../collector/tieba_account.dart';
import '../../data/bduss.dart';
import '../../data/fts_index.dart';
import '../../data/seed_import.dart';
import '../../data/seed_import_providers.dart';
import '../collect/collect_settings.dart';
import '../home/cards.dart';
import 'about_page.dart';
import 'font_manage_page.dart';

/// 设置页（字体管理 / 主题模式 / 主题色 swatch / 减弱动效开关 / BDUSS / 数据包 / 并发 / 关于）。
///
/// v1.4：字体管理已实装（角色字体槽 + 用户导入字体）。
/// M2：主题模式分段（跟随系统/浅色/深色）与减弱动效开关已实装
/// （theme/appearance_settings.dart；settings 表 theme / reduce_motion 键，app.dart 顶层联动）。
/// 其余设置项不在 M1-④ 范围（M1-④ = 五维搜索 / 分类手风琴 / 富文本渲染 / 书签收藏历史）。
/// 采集并发 / 仅 WiFi / BDUSS 已实装（落 settings 表 KV，键名见 core/constants.dart: SettingsKeys）；
/// 数据包管理仍未实装，见 docs/开发路线图.md Phase 4、原型 §5.10 设置项清单。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  /// 父级→子级 = vertical 共享轴（§6.3，与 /settings 路由同族转场）。
  void _openFontManage(BuildContext context) {
    Navigator.of(context).push(
      MotionPage<void>(
        type: SharedAxisTransitionType.vertical,
        child: const FontManagePage(),
      ).createRoute(context),
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
        padding: EdgeInsets.fromLTRB(
          space.pagePadding,
          space.space4,
          space.pagePadding,
          space.space8,
        ),
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(bottom: space.space3),
            child: Text('外观', style: t.label.copyWith(color: colors.textMuted)),
          ),
          Card(
            child: ListTile(
              // 设计 sprite 无字体/排版专属资产；字体管理属「外观」小节 → 取 i-palette（外观定制）最贴。
              leading: AppIcon('palette', size: 20, color: colors.accent),
              title: Text(
                '字体管理',
                style: t.bodyStrong.copyWith(color: colors.text),
              ),
              subtitle: Text(
                fontSummary,
                style: t.caption.copyWith(color: colors.textMuted),
              ),
              trailing: RotatedBox(
                quarterTurns: 3,
                child: AppIcon('chev', size: 16, color: colors.textMuted),
              ),
              onTap: () => _openFontManage(context),
            ),
          ),
          // ── 主题模式（M2；设计稿 07 设置页 index.html:1679–1684）──
          Padding(
            padding: EdgeInsets.only(top: space.space4),
            child: const _ThemeModeSection(),
          ),
          // ── 主题色卡（M3 P2-3；设计稿 07 设置页 index.html:1686–1696）──
          Padding(
            padding: EdgeInsets.only(top: space.space4),
            child: const _AccentSection(),
          ),
          // ── 减弱动效（M2；设计稿 07 设置页 index.html:1697–1699）──
          Padding(
            padding: EdgeInsets.only(top: space.space3),
            child: const _ReduceMotionSection(),
          ),
          // ── 采集小节（M2-① 增量；设计稿 07 设置页 '采集' 组 index.html:1715–1726）──
          Padding(
            padding: EdgeInsets.only(top: space.space8, bottom: space.space3),
            child: Text('采集', style: t.label.copyWith(color: colors.textMuted)),
          ),
          const _CollectSection(),
          // ── 数据与存储（FTS 索引档位 / 删除 / 重建）──
          Padding(
            padding: EdgeInsets.only(top: space.space8, bottom: space.space3),
            child: Text('数据与存储', style: t.label.copyWith(color: colors.textMuted)),
          ),
          const _FtsIndexSection(),
          // ── 关于小节（M3 §10.1：版本显示 / 双源更新检查 / 备源 URL 自定义）──
          Padding(
            padding: EdgeInsets.only(top: space.space8, bottom: space.space3),
            child: Text('关于', style: t.label.copyWith(color: colors.textMuted)),
          ),
          const _AboutSection(),
        ],
      ),
    );
  }
}

/// 外观写入统一出口：失败（如 widget 测试的 DB 哨兵、首启竞态）只弹「保存失败」，
/// UI 保持读取侧原值（与 _CollectSection._write 同策略）。
Future<void> _writeAppearance(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function(AppearanceSettingsController) action,
) async {
  try {
    await action(ref.read(appearanceSettingsControllerProvider));
  } catch (_) {
    if (context.mounted) {
      showAppToast(context, '保存失败');
    }
  }
}

/// 主题模式（设计稿 07 index.html:1679–1684）：bodyStrong 标题 + 三档分段
/// （跟随系统/浅色/深色，复用 SegmentedPill）+ helper 说明。分段切换实时换全稿
/// token 集（设计系统 §3 #07）：写 settings → invalidate → app.dart 换 themeMode。
class _ThemeModeSection extends ConsumerWidget {
  const _ThemeModeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing space = AppSpacing.of(context);
    final AppearanceSettings settings =
        ref.watch(appearanceSettingsProvider).value ??
        const AppearanceSettings();
    return Card(
      child: Padding(
        padding: EdgeInsets.all(space.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('主题模式', style: t.bodyStrong.copyWith(color: colors.text)),
            SizedBox(height: space.space3),
            SegmentedPill<ThemeMode>(
              options: const <(ThemeMode, String)>[
                (ThemeMode.system, '跟随系统'),
                (ThemeMode.light, '浅色'),
                (ThemeMode.dark, '深色'),
              ],
              selected: settings.themeMode,
              onChanged: (ThemeMode v) => _writeAppearance(
                context,
                ref,
                (AppearanceSettingsController c) => c.setThemeMode(v),
              ),
            ),
            SizedBox(height: space.space2),
            Text(
              // 设计稿 07 helper 原文。
              '深色 = 暖炭灰而非纯黑 · 与浅色共用同一套动效 token',
              style: t.caption.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// 减弱动效开关行（设计稿 07 index.html:1697–1699；设计系统 §2.5）：开启 →
/// BookTheme.of 注入 AppMotionTheme.reducedTokens，全部动效退化为 ≤100ms opacity
/// 过渡，实时生效。行式仿 _CollectSection「仅 WiFi 采集」。
class _ReduceMotionSection extends ConsumerWidget {
  const _ReduceMotionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppearanceSettings settings =
        ref.watch(appearanceSettingsProvider).value ??
        const AppearanceSettings();
    return Card(
      child: ListTile(
        leading: AppIcon('motion', color: colors.textMuted),
        title: Text('减弱动效', style: t.bodyStrong.copyWith(color: colors.text)),
        subtitle: Text(
          '全部动效退化为 ≤100ms opacity · 实时生效',
          style: t.caption.copyWith(color: colors.textMuted),
        ),
        trailing: Switch(
          value: settings.reduceMotion,
          onChanged: (bool v) => _writeAppearance(
            context,
            ref,
            (AppearanceSettingsController c) => c.setReduceMotion(v),
          ),
        ),
      ),
    );
  }
}

/// 采集设置（settings 表 KV：wifi_only / concurrent_forums，键名 core/constants.dart；
/// BDUSS 行 = P2 诚实标注，不做假功能）。
class _CollectSection extends ConsumerWidget {
  const _CollectSection();

  Future<void> _write(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(CollectSettingsController) action,
  ) async {
    try {
      await action(ref.read(collectSettingsControllerProvider));
    } catch (_) {
      if (context.mounted) {
        showAppToast(context, '保存失败');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing space = AppSpacing.of(context);
    final CollectSettings settings =
        ref.watch(collectSettingsProvider).value ?? const CollectSettings();
    // 需求 5：并发上限按档位（匿名 3 / BDUSS 档 4）；读 effective（已失效 → 匿名口径）。
    final bool bdussImported =
        (ref.watch(effectiveBdussProvider).value ?? '').isNotEmpty;
    final int maxConcurrency = maxConcurrencyFor(bdussImported: bdussImported);
    final int concurrent = effectiveConcurrency(
      '${settings.concurrentForums}',
      bdussImported: bdussImported,
    );
    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: space.space2),
        child: Column(
          children: <Widget>[
            ListTile(
              leading: AppIcon('wifi', color: colors.textMuted),
              title: Text(
                '仅 WiFi 采集',
                style: t.bodyStrong.copyWith(color: colors.text),
              ),
              trailing: Switch(
                value: settings.wifiOnly,
                onChanged: (bool v) => _write(
                  context,
                  ref,
                  (CollectSettingsController c) => c.setWifiOnly(v),
                ),
              ),
            ),
            ListTile(
              leading: AppIcon('collect', color: colors.textMuted),
              title: Text(
                '跨吧并发数',
                style: t.bodyStrong.copyWith(color: colors.text),
              ),
              subtitle: Text(
                '默认 2 · 上限 $maxConcurrency（${bdussImported ? 'BDUSS 档' : '匿名档'}）· 提高并发有风控风险',
                style: t.caption.copyWith(color: colors.textMuted),
              ),
              trailing: SegmentedPill<int>(
                options: <(int, String)>[
                  for (int i = 2; i <= maxConcurrency; i++) (i, '$i'),
                ],
                selected: concurrent,
                onChanged: (int v) => _write(
                  context,
                  ref,
                  (CollectSettingsController c) => c.setConcurrentForums(v),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                space.pagePadding,
                0,
                space.pagePadding,
                space.space2,
              ),
              child: Text(
                // §8.8 风险说明（设置页并发配置项旁明示；上限数字按档位内插）。
                '并发调得越高，单位时间内的请求就越多，触发风控的概率也越高。'
                '调到上限（匿名 $kMaxConcurrencyAnonymous / BDUSS 档 $kMaxConcurrencyBduss）风险自担。'
                '另外，同一吧连续失败 $kForumFailureCooldown 次会进入 '
                '${kForumCooldownDuration.inHours} 小时冷却，全局连续失败 $kGlobalFailurePause 次会暂停整轮采集。',
                style: t.caption.copyWith(color: colors.textMuted),
              ),
            ),
            // BDUSS 导入 / 测试 / 清除（需求 8/5）：凭证只进设备本地系统加密存储，见 data/bduss.dart。
            const _BdussTile(),
          ],
        ),
      ),
    );
  }
}

/// 「数据与存储」：FTS 索引档位 + 删除 / 重建（docs/2026-10-20_FTS索引可选化改造方案.md §5）。
///
/// 档位三选一（关闭 / 基础 / 完整）；「重建索引」按当前档位先删后建；
/// 「删除索引」等价切到关闭。三者共用 SeedBootstrapController 的进度状态，
/// 运行中禁用并显示阶段文案。采集进行中禁用（VACUUM 会锁库）。
class _FtsIndexSection extends ConsumerStatefulWidget {
  const _FtsIndexSection();

  @override
  ConsumerState<_FtsIndexSection> createState() => _FtsIndexSectionState();
}

class _FtsIndexSectionState extends ConsumerState<_FtsIndexSection> {
  /// true = 首帧之后（首帧读 settings 全是 loading，直接显示 progress 会闪）。
  bool _ready = false;
  FtsMode? _mode;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final FtsIndexService service = await ref.read(ftsIndexServiceProvider.future);
      final FtsCapability cap = await service.detect();
      final FtsMode? desired = await ref
          .read(seedBootstrapProvider.notifier)
          .readFtsMode();
      if (!mounted) {
        return;
      }
      setState(() {
        _ready = true;
        _mode = desired ?? cap.mode;
      });
    } catch (_) {
      // 测试环境（真实 IO 被禁）/ 路径解析失败：按默认档显示，不阻塞设置页。
      if (!mounted) {
        return;
      }
      setState(() {
        _ready = true;
        _mode = FtsMode.full;
      });
    }
  }

  Future<void> _apply(FtsMode target, {bool rebuild = false}) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final FtsProgress result = await ref
          .read(seedBootstrapProvider.notifier)
          .applyFtsMode(target, rebuild: rebuild);
      if (!mounted) {
        return;
      }
      if (result.message.contains('失败') || result.cancelled) {
        showAppToast(context, result.message.isEmpty ? '索引操作失败' : result.message);
      } else {
        setState(() => _mode = target);
        final String? warning = result.warning;
        showAppToast(
          context,
          warning == null ? result.message : '${result.message}（$warning）',
        );
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, '索引操作失败：$e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _confirmDrop() async {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        icon: AppIcon('alert', size: AppMetrics.iconBase, color: c.danger),
        title: Text('删除索引？', style: t.headline.copyWith(color: c.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '删除后搜索会变慢（正文约 1–2 秒），并释放约 240 MB 存储。',
              style: t.body.copyWith(color: c.textSecondary),
            ),
            SizedBox(height: s.space2),
            Text(
              '之后可在本页「重建索引」随时恢复。',
              style: t.caption.copyWith(color: c.textMuted),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: c.danger,
              foregroundColor: c.onAccent,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _apply(FtsMode.off);
    }
  }

  Future<void> _confirmRebuild() async {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    // 删除后（off）也允许重建：默认按「完整」重建，随后可再切基础。
    final FtsMode mode = _mode == null || _mode == FtsMode.off ? FtsMode.full : _mode!;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        icon: AppIcon('refresh', size: AppMetrics.iconBase, color: c.accent),
        title: Text('重建索引？', style: t.headline.copyWith(color: c.text)),
        content: Text(
          '将删除当前索引并按「${mode.label}」重新建立，预计约 30 秒。期间搜索自动降级，完成后恢复。',
          style: t.body.copyWith(color: c.textSecondary),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('重建'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _apply(mode, rebuild: true);
    }
  }

  String _summary(FtsMode mode) => switch (mode) {
    FtsMode.off => '关闭 · 约 160 MB · 全部 LIKE，正文搜索约 1–2 秒',
    FtsMode.book => '基础 · 约 255 MB · 书名/作者/评语快，楼层正文走 LIKE',
    FtsMode.full => '完整 · 约 402 MB · 搜索最快',
  };

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final SeedImportState seed = ref.watch(seedBootstrapProvider);
    final bool importing = seed.isImporting || seed.phase == SeedImportPhase.awaitingChoice;
    final bool collectRunning = ref.watch(collectRunStateProvider).isRunning;
    final bool enabled = _ready && !_busy && !importing && !collectRunning;
    final FtsMode mode = _mode ?? FtsMode.full;
    final String blocking = importing
        ? '导入进行中，结束后可切换'
        : collectRunning
        ? '采集进行中，结束后可切换'
        : _busy
        ? seed.phase == SeedImportPhase.rebuildingFts && seed.message.isNotEmpty
              ? seed.message
              : '索引处理中…'
        : _summary(mode);

    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: s.space2),
        child: Column(
          children: <Widget>[
            ListTile(
              leading: AppIcon('db', color: c.textMuted),
              title: Text(
                '全文索引',
                style: t.bodyStrong.copyWith(color: c.text),
              ),
              subtitle: Text(
                blocking,
                style: t.caption.copyWith(color: c.textMuted),
              ),
              trailing: _busy
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.accent,
                      ),
                    )
                  : SegmentedPill<FtsMode>(
                      options: <(FtsMode, String)>[
                        for (final FtsMode m in FtsMode.values) (m, m.label),
                      ],
                      selected: mode,
                      onChanged: enabled ? (FtsMode v) => _apply(v) : (FtsMode _) {},
                    ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                s.pagePadding,
                0,
                s.pagePadding,
                s.space2,
              ),
              child: Text(
                '切换档位会重建/删除索引，期间搜索自动降级并如实提示。'
                '采集进行中为免锁库会暂时禁用。',
                style: t.caption.copyWith(color: c.textMuted),
              ),
            ),
            const Divider(height: AppMetrics.hairline, indent: 56),
            ListTile(
              leading: AppIcon(
                'refresh',
                color: enabled ? c.textMuted : c.borderStrong,
              ),
              title: Text(
                '重建索引',
                style: t.bodyStrong.copyWith(
                  color: enabled ? c.text : c.textMuted,
                ),
              ),
              subtitle: Text(
                mode == FtsMode.off
                    ? '当前未启用 · 点击按「完整」重新建立'
                    : '删除后按「${mode.label}」重新建立',
                style: t.caption.copyWith(color: c.textMuted),
              ),
              trailing: RotatedBox(
                quarterTurns: 3,
                child: AppIcon('chev', size: 16, color: c.textMuted),
              ),
              enabled: enabled,
              onTap: () => _confirmRebuild(),
            ),
            ListTile(
              leading: AppIcon(
                'close',
                color: enabled && mode != FtsMode.off ? c.danger : c.borderStrong,
              ),
              title: Text(
                '删除索引',
                style: t.bodyStrong.copyWith(
                  color: enabled && mode != FtsMode.off ? c.danger : c.textMuted,
                ),
              ),
              subtitle: Text(
                mode == FtsMode.off ? '当前未启用索引' : '释放约 240 MB；之后可随时重建',
                style: t.caption.copyWith(color: c.textMuted),
              ),
              trailing: RotatedBox(
                quarterTurns: 3,
                child: AppIcon('chev', size: 16, color: c.textMuted),
              ),
              enabled: enabled && mode != FtsMode.off,
              onTap: () => _confirmDrop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// BDUSS 导入 / 测试 / 清除（需求 8/5）：凭证只进**设备本地系统加密存储**
/// （data/bduss.dart），不进 settings 表、不写日志、不上传；导入后采集与在线搜索
/// 请求带账号身份，每日配额 300 → 600、间隔 1.0–2.0s、并发上限 4（原型 §8.11）；
/// 可随时清除回匿名档。失效（采集命中登录态特征自动降级，§8.10）时显示
/// 「已失效 · 请重新导入」，「测试」按钮可主动校验当前凭证。
class _BdussTile extends ConsumerStatefulWidget {
  const _BdussTile();

  @override
  ConsumerState<_BdussTile> createState() => _BdussTileState();
}

class _BdussTileState extends ConsumerState<_BdussTile> {
  /// 测试请求进行中（按钮禁用 + 转圈）。
  bool _testing = false;

  /// 导入 / 替换：整段 `BDUSS=…; STOKEN=…` Cookie 或裸值都接受
  /// （[parseBdussInput] 负责提取与粗校验）。
  Future<void> _import() async {
    final AppColors colors = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing space = AppSpacing.of(context);
    final TextEditingController controller = TextEditingController();
    final String? submitted = await showDialog<String>(
      context: context,
      animationStyle: dialogAnimationStyle(context),
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('BDUSS 导入'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '从贴吧 App / 网页版的 Cookie 里复制 BDUSS 粘贴到此处（只需 BDUSS，'
              '不要填账号密码）。凭证只存本机系统加密存储：不入库、不上传，可随时清除。',
              style: t.caption.copyWith(color: colors.textMuted),
            ),
            SizedBox(height: space.space3),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'BDUSS=…（或直接粘贴值）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    // controller 不手动 dispose（同 _editFallbackUrl：退场动画期间 TextField 仍挂载）。
    if (submitted == null || !mounted) return;
    final String? bduss = parseBdussInput(submitted);
    if (bduss == null) {
      showAppToast(context, '看起来不是 BDUSS（应为 40 位以上字母数字串）');
      return;
    }
    try {
      await ref.read(bdussControllerProvider).save(bduss);
      if (mounted) showAppToast(context, '已导入 BDUSS · 每日配额 $kDailyBudgetBduss');
    } catch (_) {
      if (mounted) showAppToast(context, '保存失败');
    }
  }

  /// 「测试」：用当前凭证调 initNickname（app-form + APP_SALT 签名，一次请求）；
  /// 成功显示昵称，失败按 无效/风控/网络 分档提示。凭证只在请求体里，不外泄。
  Future<void> _test(String bduss) async {
    if (_testing) return;
    setState(() => _testing = true);
    try {
      final TiebaAccountProbeResult r = await ref
          .read(tiebaAccountProbeProvider)
          .check(bduss);
      if (!mounted) return;
      final String message = switch (r.kind) {
        TiebaAccountProbeKind.ok =>
          'BDUSS 有效 · ${r.nickname.isEmpty ? '（昵称未取到）' : r.nickname}',
        TiebaAccountProbeKind.invalid => 'BDUSS 无效或已失效 · 请重新导入',
        TiebaAccountProbeKind.risk => '测试被风控拦截（${r.message}）· 稍后再试',
        TiebaAccountProbeKind.network => '测试失败：网络异常（${r.message}）',
        TiebaAccountProbeKind.server => '测试失败：接口异常（${r.message}）',
      };
      showAppToast(context, message);
      if (r.kind == TiebaAccountProbeKind.invalid) {
        // 与采集侧自动降级同源（幂等）；重新导入即清除标记。
        await ref.read(bdussControllerProvider).markInvalid();
      }
    } catch (_) {
      if (mounted) showAppToast(context, '测试失败：无法发起请求');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _clear() async {
    try {
      await ref.read(bdussControllerProvider).clear();
      if (mounted) showAppToast(context, '已清除 BDUSS · 回到匿名模式');
    } catch (_) {
      if (mounted) showAppToast(context, '清除失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final String? bduss = ref.watch(bdussProvider).value;
    final bool invalid = ref.watch(bdussInvalidProvider).value ?? false;
    return ListTile(
      leading: AppIcon('key', color: colors.textMuted),
      title: Text(
        invalid ? 'BDUSS 已失效' : (bduss == null ? 'BDUSS 导入' : 'BDUSS 已导入'),
        style: t.bodyStrong.copyWith(color: colors.text),
      ),
      subtitle: Text(
        bduss == null
            ? '匿名模式 · 每日配额 $kDailyBudgetAnonymous · 导入后 $kDailyBudgetBduss · 详见「关于与合规」'
            : (invalid
                  ? '已失效 · 请重新导入（当前按匿名档运行）'
                  : '${maskBduss(bduss)} · 每日配额 $kDailyBudgetBduss · 仅存本机加密存储'),
        style: t.caption.copyWith(color: colors.textMuted),
      ),
      // 已导入：行尾给「测试 / 清除」；点行本身 = 重新导入（替换）。
      trailing: bduss == null
          ? RotatedBox(
              quarterTurns: 3,
              child: AppIcon('chev', size: 16, color: colors.textMuted),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (_testing)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  TextButton(
                    onPressed: () => _test(bduss),
                    child: const Text('测试'),
                  ),
                TextButton(
                  onPressed: _testing ? null : _clear,
                  child: const Text('清除'),
                ),
              ],
            ),
      onTap: () => _import(),
    );
  }
}

/// 主题色卡（设计 07 index.html:1686–1696）：可折叠区块 —— 标题行（bodyStrong
/// 「主题色」+ 当前色名摘要 + chev 旋转指示）默认收起，展开后才是 13 枚 swatch
/// （默认陶土珊瑚 + 宝典 12 色）的 Wrap。展开态只随 State 在本次会话内保持，
/// 不落 settings。动效口径与搜索台筛选条收起一致（AnimatedCrossFade）：
/// 展开 = enter、收起 = exit（exit-faster-than-enter）、chev 旋转 = fast。
/// 选中 → AccentController 写 settings → invalidate → app.dart 顶层 watch 实时换色。
class _AccentSection extends ConsumerStatefulWidget {
  const _AccentSection();

  @override
  ConsumerState<_AccentSection> createState() => _AccentSectionState();
}

class _AccentSectionState extends ConsumerState<_AccentSection> {
  /// 默认折叠；用户展开后随 State 保持（会话级，不持久化）。
  bool _expanded = false;

  Future<void> _select(String id) async {
    try {
      await ref.read(accentControllerProvider).select(id);
    } catch (_) {
      if (mounted) {
        showAppToast(context, '保存失败');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing space = AppSpacing.of(context);
    final AppMotionTheme motion = AppMotionTheme.of(context);
    final AppAccentTheme current =
        ref.watch(accentThemeProvider).value ?? AppAccentTheme.defaults;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ListTile(
            onTap: () => setState(() => _expanded = !_expanded),
            title: Text(
              '主题色',
              style: t.bodyStrong.copyWith(color: colors.text),
            ),
            // 收起态摘要 = 当前色名（如「陶土珊瑚」），免展开即知现状。
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  current.label,
                  style: t.caption.copyWith(color: colors.textMuted),
                ),
                SizedBox(width: space.space2),
                // chev 旋转指示（˅ 收起 / ˄ 展开）：时长走 motion-fast 档（手风琴 + chevron 旋转）。
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0.0,
                  duration: motion.fast,
                  curve: motion.standard,
                  child: AppIcon('chev', size: 16, color: colors.textMuted),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: Padding(
              padding: EdgeInsets.fromLTRB(
                space.cardPadding,
                0,
                space.cardPadding,
                space.cardPadding,
              ),
              child: Wrap(
                spacing: space.space3, // 设计 605：.cmp-row gap = space-3
                runSpacing: space.space3,
                children: <Widget>[
                  for (final AppAccentTheme a in AppAccentTheme.all)
                    _AccentSwatch(
                      key: ValueKey<String>('swatch-${a.id}'),
                      accent: a,
                      selected: a.id == current.id,
                      onTap: () => _select(a.id),
                    ),
                ],
              ),
            ),
            secondChild: const SizedBox(width: double.infinity, height: 0),
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: motion.exit.duration,
            reverseDuration: motion.enter.duration,
            firstCurve: motion.standard,
            secondCurve: motion.standard,
            sizeCurve: motion.standard,
          ),
        ],
      ),
    );
  }
}

/// 单枚 swatch（像素级对齐设计 557–566 `.swatch`）：
/// 44px 圆片（seed 原色）· 选中 = outline 2px text 色 offset 3px（外框 54 = 44+2×(3+2)）
/// + 内 18px 白勾 · hover scale 1.08（motion-instant + spring，设计 560/563）。
class _AccentSwatch extends StatefulWidget {
  const _AccentSwatch({
    super.key,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final AppAccentTheme accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_AccentSwatch> createState() => _AccentSwatchState();
}

class _AccentSwatchState extends State<_AccentSwatch> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AppMotionTheme motion = AppMotionTheme.of(context);
    final String label = widget.selected
        ? '${widget.accent.label}（当前）'
        : widget.accent.label;
    return Semantics(
      button: true,
      selected: widget.selected,
      label:
          label, // 设计 aria-label（「陶土珊瑚（当前）」等）；不挂 Tooltip（hover timer 会污染 widget 测试假时钟区）。
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: SizedBox(
            width: 54,
            height: 54,
            child: AnimatedContainer(
              // outline-color 过渡 = motion-fast（设计 561：outline-color var(--motion-fast)）。
              duration: motion.fast,
              curve: motion.standard,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.selected
                      ? colors.text
                      : colors.text.withValues(alpha: 0),
                  width: 2, // 设计 560：outline 2px
                ),
              ),
              child: Center(
                child: AnimatedScale(
                  // 设计 563：hover scale(1.08)，过渡 motion-instant + spring；
                  // pressed 0.95 为补充按压反馈（设计稿无按压态）。
                  scale: _hover ? 1.08 : (_pressed ? 0.95 : 1.0),
                  duration: motion.instant,
                  curve: motion.springCurve,
                  child: Container(
                    width: 44, // 设计 558：.swatch 44×44 圆
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.accent.seed,
                    ),
                    child: widget.selected
                        ? Center(
                            // 设计 566：内勾 18px stroke 2.2 白 #FFFDF8 —— 取 -s 档（stroke 2）
                            // 资产直引（AppIcon 仅 ≤13px 自动选 -s，18px 档无 stroke 覆盖参数）。
                            child: SvgPicture.asset(
                              'assets/icons/check-s.svg',
                              width: 18,
                              height: 18,
                              colorFilter: const ColorFilter.mode(
                                AppAccentTheme.swatchCheckColor,
                                BlendMode.srcIn,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 关于区（M3 §10.1）：当前版本 + 检查更新（GitHub 主源 → 静态 version.json 备源，
/// 主源不可达/403/限流自动切源；双源失败静默「检查失败」）+ 备源 URL 编辑
/// （settings 键 `update_fallback_url`）+ 关于与合规入口（Phase 5，路由 `/about`）。
/// 更新卡片保留「前往下载」复制链接，同时提供应用内断点下载与平台动作。
class _AboutSection extends ConsumerWidget {
  const _AboutSection();

  void _snack(BuildContext context, String message) {
    showAppToast(context, message);
  }

  /// 手动检查（§10.1 检查时机之二）：三态分流 —— 有新版弹更新卡片；
  /// 已最新 / 失败走 SnackBar（失败不打扰原则只约束静默路径，手动检查必须给反馈）。
  Future<void> _manualCheck(BuildContext context, WidgetRef ref) async {
    final UpdateCheckResult result = await ref
        .read(updateControllerProvider.notifier)
        .manualCheck();
    if (!context.mounted) return;
    switch (result.outcome) {
      case UpdateOutcome.updateAvailable:
        final UpdateInfo? info = result.info;
        if (info != null) {
          await _showUpdateCard(context, info, forced: result.forced);
        }
      case UpdateOutcome.upToDate:
        _snack(context, '当前已是最新版本');
      case UpdateOutcome.failed:
        _snack(context, '检查失败，请稍后再试');
    }
  }

  /// 更新卡片（版本号 + 更新日志 + 按钮；强更 = min_force 高于本地 → 禁点遮罩、无「稍后」）。
  Future<void> _showUpdateCard(
    BuildContext pageContext,
    UpdateInfo info, {
    required bool forced,
  }) {
    return showDialog<void>(
      context: pageContext,
      barrierDismissible: !forced,
      animationStyle: dialogAnimationStyle(pageContext),
      builder: (BuildContext dialogContext) {
        return PopScope<void>(
          canPop: !forced,
          child: UpdateDialog(
            info: info,
            forced: forced,
            onCopy: (bool close) {
              if (close && dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              _copyDownloadLink(pageContext, info);
            },
            onDownload: (WidgetRef ref) =>
                _downloadUpdate(dialogContext, ref, info),
          ),
        );
      },
    );
  }

  Future<void> _downloadUpdate(
    BuildContext dialogContext,
    WidgetRef ref,
    UpdateInfo info,
  ) async {
    final TargetPlatform target = defaultTargetPlatform;
    final UpdateDownloadController controller = ref.read(
      updateDownloadControllerProvider.notifier,
    );
    final UpdateDownloadState current = ref.read(
      updateDownloadControllerProvider,
    );
    final String key = updateDownloadResourceKey(info, target);
    if (current.resourceKey != key) {
      await controller.download(info, target: target);
    } else if (current.status == UpdateDownloadStatus.downloading) {
      controller.cancel();
      return;
    } else if (current.status != UpdateDownloadStatus.ready) {
      await controller.download(info, target: target);
    }
    if (!dialogContext.mounted) return;
    final UpdateDownloadState state = ref.read(
      updateDownloadControllerProvider,
    );
    if (state.status != UpdateDownloadStatus.ready || state.result == null) {
      return;
    }
    try {
      final bool opened = await ref
          .read(updatePlatformProvider)
          .installDownloadedFile(state.result!.file.path, target);
      if (!opened && dialogContext.mounted) {
        _snack(dialogContext, '更新包已下载，请手动打开文件');
      }
    } on UpdatePlatformException catch (error) {
      if (dialogContext.mounted) _snack(dialogContext, error.message);
    } on Object {
      if (dialogContext.mounted) {
        _snack(dialogContext, '更新包已下载，但无法自动打开');
      }
    }
  }

  /// [前往下载] = 按当前平台复制下载链接；缺少本平台链接时如实提示。
  /// 平台判定用 defaultTargetPlatform 而非 Theme.platform —— 后者被静态
  /// BookTheme.light 缓存，测试注入 debugDefaultTargetPlatformOverride 不生效。
  void _copyDownloadLink(BuildContext context, UpdateInfo info) {
    if (!context.mounted) return;
    final String? url = switch (defaultTargetPlatform) {
      TargetPlatform.android => info.apkUrl,
      TargetPlatform.iOS => info.iosUrl,
      TargetPlatform.windows => info.windowsUrl,
      TargetPlatform.macOS => info.macosUrl,
      TargetPlatform.linux => info.linuxUrl,
      TargetPlatform.fuchsia => null,
    };
    if (url == null || url.isEmpty) {
      _snack(context, '该版本未提供下载链接');
      return;
    }
    Clipboard.setData(ClipboardData(text: url));
    _snack(context, '下载链接已复制');
  }

  /// 备源 URL 编辑：留空 = 恢复出厂缺省（未配置，仅主源）；非空须为绝对 http(s)。
  Future<void> _editFallbackUrl(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final AppColors colors = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing space = AppSpacing.of(context);
    final TextEditingController controller = TextEditingController(
      text: current,
    );
    final String? submitted = await showDialog<String>(
      context: context,
      animationStyle: dialogAnimationStyle(context),
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('更新备源'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '静态 version.json 地址；GitHub 主源不可达、被限流或返回 403 时自动切换。'
              '留空则恢复默认设置。',
              style: t.caption.copyWith(color: colors.textMuted),
            ),
            SizedBox(height: space.space3),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'https://…/version.json',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    // controller 不手动 dispose：showDialog 的 future 在 pop 时即完成，而退场动画期间
    // TextField 仍挂载；先 dispose 会让 TextField 卸载时 removeListener 触发已disposed断言。
    if (submitted == null || !context.mounted) return;
    final String url = submitted.trim();
    if (!isValidFallbackUrl(url)) {
      _snack(context, '请输入合法的 http(s) 地址');
      return;
    }
    try {
      await ref.read(updateSettingsControllerProvider).setFallbackUrl(url);
      if (context.mounted) _snack(context, url.isEmpty ? '已恢复默认设置' : '备源已保存');
    } catch (_) {
      if (context.mounted) _snack(context, '保存失败');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing space = AppSpacing.of(context);
    final UpdateCheckState check = ref.watch(updateControllerProvider);
    final LocalVersion? local = ref.watch(localVersionProvider).value;
    final String fallbackUrl = ref.watch(updateFallbackUrlProvider).value ?? '';

    final String versionText = local == null
        ? '获取版本中…'
        : !local.isKnown
        ? '版本未知'
        : local.buildNumber == null
        ? 'v${local.version}'
        : 'v${local.version} (${local.buildNumber})';
    final bool checking = check.status == UpdateStatus.checking;
    final String checkHint = switch (check.status) {
      UpdateStatus.idle => 'GitHub 主源和静态备源 · 主源失败时自动切换',
      UpdateStatus.checking => '检查中…',
      UpdateStatus.updateAvailable => '发现新版本 v${check.info?.version ?? ''}',
      UpdateStatus.upToDate => '已是最新版本',
      UpdateStatus.failed => '检查失败 · 双源均不可达',
    };

    return Card(
      child: Column(
        children: <Widget>[
          ListTile(
            leading: AppIcon('info', color: colors.textMuted),
            title: Text(
              '当前版本',
              style: t.bodyStrong.copyWith(color: colors.text),
            ),
            subtitle: Text(
              versionText,
              style: t.caption.copyWith(color: colors.textMuted),
            ),
          ),
          ListTile(
            leading: AppIcon('refresh', color: colors.textMuted),
            title: Text(
              '检查更新',
              style: t.bodyStrong.copyWith(color: colors.text),
            ),
            subtitle: Text(
              checkHint,
              style: t.caption.copyWith(
                color: checking ? colors.accentStrong : colors.textMuted,
              ),
            ),
            trailing: checking
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.accent,
                    ),
                  )
                : RotatedBox(
                    quarterTurns: 3,
                    child: AppIcon('chev', size: 16, color: colors.textMuted),
                  ),
            enabled: !checking,
            onTap: () => _manualCheck(context, ref),
          ),
          ListTile(
            leading: AppIcon('external', color: colors.textMuted),
            title: Text(
              '更新备源',
              style: t.bodyStrong.copyWith(color: colors.text),
            ),
            subtitle: Text(
              fallbackUrl.isEmpty ? '默认设置 · 仅检查 GitHub 主源' : fallbackUrl,
              style: t.caption.copyWith(color: colors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: RotatedBox(
              quarterTurns: 3,
              child: AppIcon('chev', size: 16, color: colors.textMuted),
            ),
            onTap: () => _editFallbackUrl(context, ref, fallbackUrl),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              space.pagePadding,
              0,
              space.pagePadding,
              space.space2,
            ),
            child: Text(
              // §10.1 免 token 双源口径（与并发风险说明同款：设置页明示，不做黑盒）。
              '检查更新无需 token：优先访问 GitHub Releases API，失败时切换到自定义的'
              '静态 version.json 地址。两个源都不可用时保持静默，不打扰你。',
              style: t.caption.copyWith(color: colors.textMuted),
            ),
          ),
          const Divider(height: AppMetrics.hairline, indent: 56),
          // Phase 5 合规文案入口（原型 §11.3/§11.4：关于页固定署名区 + 免责声明全文页）。
          ListTile(
            leading: AppIcon('alert', color: colors.textMuted),
            title: Text(
              '关于与合规',
              style: t.bodyStrong.copyWith(color: colors.text),
            ),
            subtitle: Text(
              '数据来源署名 · 贴吧使用提示 · BDUSS 与隐私',
              style: t.caption.copyWith(color: colors.textMuted),
            ),
            trailing: RotatedBox(
              quarterTurns: 3,
              child: AppIcon('chev', size: 16, color: colors.textMuted),
            ),
            onTap: () => openCenterPage(context, const AboutPage()),
          ),
        ],
      ),
    );
  }
}

final class UpdateDialog extends ConsumerWidget {
  const UpdateDialog({
    super.key,
    required this.info,
    required this.forced,
    required this.onCopy,
    required this.onDownload,
  });

  final UpdateInfo info;
  final bool forced;
  final void Function(bool close) onCopy;
  final Future<void> Function(WidgetRef ref) onDownload;

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _downloadHint(UpdateDownloadState state, AppColors colors) {
    final UpdateDownloadProgress? progress = state.progress;
    return switch (state.status) {
      UpdateDownloadStatus.idle => '下载到应用缓存，支持断点续传',
      UpdateDownloadStatus.downloading =>
        progress == null
            ? '下载中…'
            : progress.totalBytes <= 0
            ? '正在接收数据 · ${_formatBytes(progress.downloadedBytes)}'
            : '已完成 ${(progress.fraction! * 100).round()}%',
      UpdateDownloadStatus.ready =>
        '更新包已就绪 · ${_formatBytes(state.result?.bytes ?? 0)}',
      UpdateDownloadStatus.failed => '下载失败 · ${state.error ?? '请重试'}',
      UpdateDownloadStatus.canceled => '已取消下载 · 缓存已保留',
    };
  }

  String _downloadLabel(UpdateDownloadState state, TargetPlatform target) =>
      switch (state.status) {
        UpdateDownloadStatus.downloading => '取消下载',
        UpdateDownloadStatus.ready => switch (target) {
          TargetPlatform.android => '安装更新',
          TargetPlatform.iOS => '打开文件位置',
          TargetPlatform.windows || TargetPlatform.linux => '安装更新',
          TargetPlatform.macOS => '打开更新包',
          TargetPlatform.fuchsia => '当前平台不支持',
        },
        UpdateDownloadStatus.failed || UpdateDownloadStatus.canceled => '重新下载',
        UpdateDownloadStatus.idle => '下载更新',
      };

  String _platformName(TargetPlatform target) => switch (target) {
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iOS',
    TargetPlatform.windows => 'Windows',
    TargetPlatform.macOS => 'macOS',
    TargetPlatform.linux => 'Linux',
    TargetPlatform.fuchsia => '当前平台',
  };

  String _readyAction(TargetPlatform target) => switch (target) {
    TargetPlatform.android => '将唤起系统安装器；首次安装需允许“安装未知应用”',
    TargetPlatform.iOS => '将打开系统文件面板；IPA 仍需自行签名安装',
    TargetPlatform.windows => '将自动解压、备份并替换当前安装，然后重新启动',
    TargetPlatform.macOS => '将打开 macOS 程序包；未签名包可能被 Gatekeeper 拦截',
    TargetPlatform.linux => '将自动解压、备份并替换当前安装，然后重新启动',
    TargetPlatform.fuchsia => '当前平台不支持自动打开更新包',
  };

  Widget _downloadStatus(
    BuildContext context,
    TargetPlatform target,
    UpdatePlatformAsset asset,
    UpdateDownloadState state,
    AppColors colors,
    AppTypography t,
    AppSpacing space,
  ) {
    final UpdateDownloadProgress? progress = state.progress;
    final double? fraction = state.status == UpdateDownloadStatus.downloading
        ? progress?.fraction
        : null;
    final Color statusColor = switch (state.status) {
      UpdateDownloadStatus.failed => colors.danger,
      UpdateDownloadStatus.ready => colors.recommend,
      UpdateDownloadStatus.downloading => colors.accentStrong,
      _ => colors.textMuted,
    };
    final double statusRadius = 8;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(space.space3),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(statusRadius),
        border: Border.all(
          color: state.status == UpdateDownloadStatus.failed
              ? colors.danger
              : colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${_platformName(target)} · ${asset.fileName}',
                  style: t.bodyStrong.copyWith(color: colors.text),
                ),
              ),
              Text(
                state.status == UpdateDownloadStatus.ready ? '已校验' : 'SHA-256',
                style: t.caption.copyWith(color: colors.textMuted),
              ),
            ],
          ),
          SizedBox(height: space.space2),
          Text(
            _downloadHint(state, colors),
            style: t.bodyStrong.copyWith(color: statusColor),
          ),
          SizedBox(height: space.space1),
          Text(
            state.status == UpdateDownloadStatus.ready
                ? _readyAction(target)
                : '支持断点续传 · 完成后校验文件完整性',
            style: t.caption.copyWith(color: colors.textMuted),
          ),
          if (state.status == UpdateDownloadStatus.downloading) ...<Widget>[
            SizedBox(height: space.space2),
            ClipRRect(
              borderRadius: BorderRadius.circular(statusRadius),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: colors.border,
                color: colors.accent,
              ),
            ),
            SizedBox(height: space.space1),
            Text(
              progress == null || progress.totalBytes <= 0
                  ? _formatBytes(progress?.downloadedBytes ?? 0)
                  : '${_formatBytes(progress.downloadedBytes)} / ${_formatBytes(progress.totalBytes)}'
                        ' · ${progress.completedChunks}/${progress.totalChunks} 分块'
                        ' · ${progress.activeChunks} 路并发',
              style: AppTypography.tabular(
                t.caption,
              ).copyWith(color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing space = AppSpacing.of(context);
    final TargetPlatform target = defaultTargetPlatform;
    final UpdatePlatformAsset? asset = platformAsset(info, target);
    final String key = updateDownloadResourceKey(info, target);
    final UpdateDownloadState rawState = ref.watch(
      updateDownloadControllerProvider,
    );
    final UpdateDownloadState state = rawState.resourceKey == key
        ? rawState
        : const UpdateDownloadState.idle();
    final String actionLabel = _downloadLabel(state, target);
    final String actionTooltip = switch (state.status) {
      UpdateDownloadStatus.ready => switch (target) {
        TargetPlatform.android => '安装更新',
        TargetPlatform.iOS => '打开文件位置',
        TargetPlatform.windows || TargetPlatform.linux => '安装更新',
        TargetPlatform.macOS => '打开更新包',
        TargetPlatform.fuchsia => '当前平台不支持',
      },
      UpdateDownloadStatus.downloading => '取消下载',
      _ => '下载更新',
    };

    return AlertDialog(
      title: const Text('发现新版本'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'v${info.version}',
                style: t.title.copyWith(color: colors.text),
              ),
              SizedBox(height: space.space1),
              Text(
                '来源 ${info.source.label}',
                style: t.caption.copyWith(color: colors.textMuted),
              ),
              if (forced)
                Padding(
                  padding: EdgeInsets.only(top: space.space2),
                  child: Text(
                    '低于 v${info.minForce} 的版本需强制更新',
                    style: t.caption.copyWith(color: colors.danger),
                  ),
                ),
              if (info.notes.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: space.space3),
                  child: Text(
                    info.notes,
                    style: t.body.copyWith(color: colors.text),
                  ),
                ),
              Padding(
                padding: EdgeInsets.only(top: space.space3),
                child: asset == null
                    ? Text(
                        '该版本未提供当前平台下载链接',
                        style: t.caption.copyWith(color: colors.textMuted),
                      )
                    : _downloadStatus(
                        context,
                        target,
                        asset,
                        state,
                        colors,
                        t,
                        space,
                      ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        if (!forced)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('稍后'),
          ),
        TextButton.icon(
          onPressed: () => onCopy(!forced),
          icon: AppIcon('external', size: 16, color: colors.textSecondary),
          label: const Text('前往下载'),
        ),
        Tooltip(
          message: actionTooltip,
          child: FilledButton.icon(
            onPressed: asset == null ? null : () => onDownload(ref),
            icon: AppIcon(
              state.status == UpdateDownloadStatus.downloading
                  ? 'close'
                  : state.status == UpdateDownloadStatus.ready
                  ? 'external'
                  : 'refresh',
              size: 16,
            ),
            label: Text(actionLabel),
          ),
        ),
      ],
    );
  }
}
