/// 领域层 provider 接线（Flutter / riverpod 侧）。
///
/// 从 `queries.dart` 拆出，使 [Queries] / [BookRepository] 保持纯 Dart，
/// 可被 headless CLI 直接构造（见 `lib/headless/query.dart`）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../db/app_database.dart';
import '../fts_mode.dart';
import 'database_provider.dart';
import 'queries.dart';

/// 当前 FTS 档位（settings.fts_mode；缺失/读取失败 → null = 未注入，保持旧行为）。
///
/// 单独成 provider：切档后 invalidate 本 provider → [queriesProvider] 重建，
/// 让检索层拿到新档位（避免旧实例继续查已删除的 floor_fts）。
final FutureProvider<FtsMode?> ftsModeProvider = FutureProvider<FtsMode?>((Ref ref) async {
  try {
    final db = ref.watch(appDatabaseProvider);
    final Setting? row = await (db.select(
      db.settings,
    )..where((Settings t) => t.key.equals(SettingsKeys.ftsMode))).getSingleOrNull();
    return ftsModeFromWire(row?.value);
  } catch (_) {
    return null;
  }
});

/// 领域层单例（§9.2：随 databaseProvider 注入）。
///
/// 静态类型是 [BookRepository] 而非 [Queries]：widget 测试用
/// `queriesProvider.overrideWithValue(FakeBookRepository())` 注入纯内存实现，
/// 使 testWidgets 假时钟区内不出现任何真实 IO（见 app/test/TESTING.md）。
final Provider<BookRepository> queriesProvider = Provider<BookRepository>((Ref ref) {
  return Queries(
    ref.watch(appDatabaseProvider),
    ftsMode: ref.watch(ftsModeProvider).value,
  );
});
