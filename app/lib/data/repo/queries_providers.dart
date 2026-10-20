/// 领域层 provider 接线（Flutter / riverpod 侧）。
///
/// 从 `queries.dart` 拆出，使 [Queries] / [BookRepository] 保持纯 Dart，
/// 可被 headless CLI 直接构造（见 `lib/headless/query.dart`）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_provider.dart';
import 'queries.dart';

/// 领域层单例（§9.2：随 databaseProvider 注入）。
///
/// 静态类型是 [BookRepository] 而非 [Queries]：widget 测试用
/// `queriesProvider.overrideWithValue(FakeBookRepository())` 注入纯内存实现，
/// 使 testWidgets 假时钟区内不出现任何真实 IO（见 app/test/TESTING.md）。
final Provider<BookRepository> queriesProvider =
    Provider<BookRepository>((Ref ref) => Queries(ref.watch(appDatabaseProvider)));
