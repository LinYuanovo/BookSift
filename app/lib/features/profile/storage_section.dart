import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as paths;
import 'package:path_provider/path_provider.dart';

import '../../collector/collect_controller.dart';
import '../../core/icons.dart';
import '../../core/nav/overlay_motion.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/update/update_download_controller.dart';
import '../../core/widgets/app_toast.dart';
import '../../data/repo/database_provider.dart';
import '../../data/seed_import_providers.dart';
import '../../data/storage_maintenance.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

final storageUsageProvider = FutureProvider<StorageUsage>(
  (ref) => readStorageUsage(ref.watch(appDatabaseProvider)),
);

class StorageSection extends ConsumerStatefulWidget {
  const StorageSection({super.key});

  @override
  ConsumerState<StorageSection> createState() => _StorageSectionState();
}

class _StorageSectionState extends ConsumerState<StorageSection> {
  bool _busy = false;

  String _size(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';

  Future<void> _clean() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      animationStyle: dialogAnimationStyle(context),
      builder: (dialogContext) => AppDialog(
        title: '整理存储空间？',
        content: const Text(
          '回收数据库空闲页，清除可重新下载的图片缓存和更新安装包。'
          '帖子、收藏、字体、导入原文和书籍下载会保留。整理期间请保持应用打开。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('整理'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _blocked) return;
    setState(() => _busy = true);
    try {
      await compactLibrary(ref.read(appDatabaseProvider));
      await DefaultCacheManager().emptyCache();
      await clearUpdateCache(
        Directory(
          paths.join(
            (await getApplicationSupportDirectory()).path,
            'update-cache',
          ),
        ),
      );
      ref.invalidate(updateDownloadControllerProvider);
      ref.invalidate(storageUsageProvider);
      if (mounted) showAppToast(context, '空间整理完成');
    } catch (_) {
      ref.invalidate(storageUsageProvider);
      if (mounted) showAppToast(context, '整理未完成，请关闭正在进行的任务后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _blocked =>
      _busy ||
      ref.read(collectRunStateProvider).isRunning ||
      ref.read(seedBootstrapProvider).isImporting ||
      ref.read(updateDownloadControllerProvider).status ==
          UpdateDownloadStatus.downloading;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AppSpacing spacing = AppSpacing.of(context);
    final AppTypography typography = AppTypography.of(context);
    final AsyncValue<StorageUsage> usage = ref.watch(storageUsageProvider);
    ref.watch(collectRunStateProvider);
    ref.watch(seedBootstrapProvider);
    ref.watch(updateDownloadControllerProvider);
    return Card(
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: spacing.cardPadding,
          vertical: spacing.space2,
        ),
        leading: AppIcon('db', color: colors.textMuted),
        title: Text(
          '整理存储空间',
          style: typography.bodyStrong.copyWith(
            color: _blocked ? colors.textMuted : colors.text,
          ),
        ),
        subtitle: Text(
          _busy
              ? '正在整理…'
              : usage.when(
                  data: (value) =>
                      '数据库 ${_size(value.databaseBytes)} · 可回收空闲页 ${_size(value.reclaimableBytes)}',
                  loading: () => '正在统计数据库大小…',
                  error: (error, stack) => '清理缓存、回收数据库空闲页',
                ),
          style: typography.caption.copyWith(color: colors.textMuted),
        ),
        enabled: !_blocked,
        onTap: _blocked ? null : _clean,
      ),
    );
  }
}
