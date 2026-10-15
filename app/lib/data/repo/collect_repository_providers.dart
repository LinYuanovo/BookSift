/// 采集持久层 provider 接线（Flutter / riverpod 侧）。
///
/// 从 `collect_repository.dart` 拆出，使 [CollectRepository] 保持纯 Dart，
/// 可被 headless CLI 直接构造（见 `lib/headless/`）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import 'collect_repository.dart';
import 'database_provider.dart';

final Provider<CollectRepository> collectRepositoryProvider =
    Provider<CollectRepository>((Ref ref) => CollectRepository(ref.watch(appDatabaseProvider)));

/// 关注吧列表（含默认播种；采集中心空闲态「关注吧」卡片数据源）。
final FutureProvider<List<CollectionStateEntry>> collectForumsProvider =
    FutureProvider<List<CollectionStateEntry>>((Ref ref) async {
      final CollectRepository repo = ref.watch(collectRepositoryProvider);
      await repo.seedDefaultsIfEmpty();
      return repo.forums();
    });

/// 最近运行日志（采集中心空闲态「最近日志」列表数据源）。
final FutureProvider<List<CollectionLog>> recentCollectLogsProvider =
    FutureProvider<List<CollectionLog>>(
      (Ref ref) => ref.watch(collectRepositoryProvider).recentLogs(),
    );
