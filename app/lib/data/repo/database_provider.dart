import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../db/app_database.dart';

/// 数据库单例（原型 §9.2 databaseProvider：单例、lazy open）。
final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((ref) {
  final AppDatabase database = AppDatabase(driftDatabase(name: AppConstants.databaseName));
  ref.onDispose(database.close);
  return database;
});
