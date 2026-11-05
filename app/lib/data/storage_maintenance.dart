import 'dart:io';

import 'db/app_database.dart';

class StorageUsage {
  const StorageUsage({
    required this.databaseBytes,
    required this.reclaimableBytes,
  });

  final int databaseBytes;
  final int reclaimableBytes;
}

Future<StorageUsage> readStorageUsage(AppDatabase database) async {
  Future<int> pragma(String name) async =>
      (await database.customSelect('PRAGMA $name').getSingle())
              .data
              .values
              .first
          as int;
  final int pageSize = await pragma('page_size');
  return StorageUsage(
    databaseBytes: await pragma('page_count') * pageSize,
    reclaimableBytes: await pragma('freelist_count') * pageSize,
  );
}

Future<StorageUsage> compactLibrary(AppDatabase database) async {
  await database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
  await database.customStatement('VACUUM');
  await database.customStatement('PRAGMA optimize');
  await database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
  return readStorageUsage(database);
}

Future<int> clearUpdateCache(Directory directory) async {
  if (!await directory.exists()) return 0;
  int removedBytes = 0;
  await for (final FileSystemEntity entity in directory.list(
    followLinks: false,
  )) {
    if (entity is! File) continue;
    final String name = entity.uri.pathSegments.last;
    if (!RegExp(r'^[a-f0-9]{32}-').hasMatch(name)) continue;
    final int length = await entity.length();
    await entity.delete();
    removedBytes += length;
  }
  return removedBytes;
}
