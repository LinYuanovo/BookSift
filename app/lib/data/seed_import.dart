import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show QueryRow;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import 'db/app_database.dart';
import 'maintenance.dart' show dedupDoneValue;

// M1-③ 种子数据包导入。流程对标 原型 §7.5 / 种子包说明.md §6.2–§6.3：
//   版本闸门(settings.seed_version vs manifest.pack_version)
//   → asset/文件 流式解压(cacheDir) → SHA256 校验(zip + seed.db)
//   → ATTACH seed.db → 单事务清理重写(INSERT OR IGNORE, origin='seed')
//   → 闸门落账(版本 + 随包维护闸门) → DETACH → (lite) 后台 isolate 批式重建 FTS。
// 压缩格式注记：Dart archive 4.x 的 ZIP 解码不支持 method-14 (Zip-LZMA)
// （CompressionType 仅 none/deflate/bzip2/zstd），故内置 lite 档由
// work/seed_pack/repack_deflate.py 重打为 deflate（comment 截断 500→300 达标 ≤55MiB）。

/// 种子包 manifest（版本闸门比对对象，原型 §7.5 / §10.4）。
class SeedManifest {
  const SeedManifest({
    required this.version,
    this.fullVersion,
    this.sha256,
    this.schemaVersion,
    this.tier,
    this.dbFile = 'seed.db',
    this.dbSizeBytes,
    this.dbSha256,
    this.zipSha256,
    this.ftsPrebuilt = false,
    this.preDeduped = false,
    this.preClassifiedVersion,
    this.rows = const <String, int>{},
  });

  /// 解析 asset/包内 manifest.json（pack_version/schema_version/sha256/行数统计等）。
  factory SeedManifest.fromJson(Map<String, Object?> json) {
    final Map<String, Object?>? fullPack =
        json['full_pack'] as Map<String, Object?>?;
    final Map<String, Object?>? compression =
        json['compression'] as Map<String, Object?>?;
    final Map<String, Object?>? features =
        json['features'] as Map<String, Object?>?;
    final Map<String, Object?>? rows = json['rows'] as Map<String, Object?>?;
    return SeedManifest(
      version: (json['pack_version'] as num?)?.toInt() ?? 0,
      fullVersion: (fullPack?['pack_version'] as num?)?.toInt(),
      sha256: fullPack?['zip_sha256'] as String?,
      schemaVersion: (json['schema_version'] as num?)?.toInt(),
      tier: json['tier'] as String?,
      dbFile: json['db_file'] as String? ?? 'seed.db',
      dbSizeBytes: (json['db_size_bytes'] as num?)?.toInt(),
      dbSha256: json['db_sha256'] as String?,
      zipSha256: compression?['zip_sha256'] as String?,
      ftsPrebuilt: features?['fts_prebuilt'] as bool? ?? false,
      preDeduped: features?['pre_deduped'] as bool? ?? false,
      preClassifiedVersion: (features?['pre_classified_v3'] as num?)?.toInt(),
      rows: rows == null
          ? const <String, int>{}
          : rows.map(
              (String k, Object? v) =>
                  MapEntry<String, int>(k, (v as num?)?.toInt() ?? 0),
            ),
    );
  }

  /// 基础包版本（对应 settings.seed_version 闸门）。
  final int version;

  /// 完整包版本（settings.seed_full_version 独立闸门；null = 无完整包）。
  final int? fullVersion;

  /// 完整包下载校验（§10.4 sha256 清单，= 随包 manifest 的 full_pack.zip_sha256）。
  final String? sha256;

  /// seed.db 的 schema 版本（PRAGMA user_version 同值；与 App drift schemaVersion 是两套编号）。
  final int? schemaVersion;

  /// 'lite' / 'full'。
  final String? tier;

  /// zip 内数据库文件名。
  final String dbFile;
  final int? dbSizeBytes;

  /// zip 内 seed.db 的 sha256（解压后校验，§6.3 T3）。
  final String? dbSha256;

  /// 本 zip 整体的 sha256（随包 manifest 才有；zip 内嵌 manifest 无自指信息）。
  final String? zipSha256;

  /// full 档预建 FTS → 导入走影子表复制，跳过后台重建（§6.3 T9）。
  final bool ftsPrebuilt;

  /// 包内 book_entries **已去重**（`features.pre_deduped`；打包侧 `tool/bake_clean_seed.dart`
  /// 跑完 maintenance.dart 的 `dedupBookEntries` 后置真）→ 导入事务内直接落
  /// `settings.dedup_version` 闸门（完成值 `dedupDoneValue`），首启后台维护据此跳过全量扫描。
  /// 缺省 false（老包 / 未清洗档）= 一个闸门都不写，维护照跑，与本字段引入前行为一致。
  final bool preDeduped;

  /// 包内 posts 已回填到的 **v3 分类器版本**（`features.pre_classified_v3`；null = 未回填）
  /// → 导入事务内原样写进 `settings.classifier_version`，由 maintenance.dart 的
  /// `needsReclassify` 与 App 侧 `classifierVersion` 比对决定是否重跑（版本语义见
  /// `_copyInTransaction` 第 5 步注释）。
  final int? preClassifiedVersion;

  /// 各表行数统计（导入后对账提示用）。
  final Map<String, int> rows;
}

/// 导入阶段（§9.2 seedImportControllerProvider 状态机：idle/importing(progress)/done/error）。
enum SeedImportPhase { idle, extracting, importing, rebuildingFts, done, error }

/// 导入进度状态。
class SeedImportState {
  const SeedImportState({
    this.phase = SeedImportPhase.idle,
    this.progress = 0,
    this.message = '',
  });

  final SeedImportPhase phase;

  /// 0..1（每 2000 行 yield 一次刷进度，§7.5）。
  final double progress;
  final String message;

  bool get isImporting =>
      phase == SeedImportPhase.extracting ||
      phase == SeedImportPhase.importing ||
      phase == SeedImportPhase.rebuildingFts;

  SeedImportState copyWith({
    SeedImportPhase? phase,
    double? progress,
    String? message,
  }) => SeedImportState(
    phase: phase ?? this.phase,
    progress: progress ?? this.progress,
    message: message ?? this.message,
  );
}

/// 种子导入失败（校验不符/包结构异常等，message 可直接展示）。
class SeedImportException implements Exception {
  const SeedImportException(this.message);

  final String message;

  @override
  String toString() => 'SeedImportException: $message';
}

/// 种子导入服务接口（首启导入 + 完整包升级；版本闸门流程见原型 §7.5）。
abstract interface class SeedImporter {
  /// 读 settings.seed_version（不存在时 null）。
  Future<int?> readSeedVersion();

  /// 读 settings.seed_full_version。
  Future<int?> readSeedFullVersion();

  /// 读内置种子包 asset 内 manifest（无种子包时 null）。
  Future<SeedManifest?> readManifest();

  /// 基础包版本闸门：本地版本缺失或低于 manifest。
  Future<bool> needsBasicImport();

  /// 完整包版本闸门（独立闸门，不影响基础包）。
  Future<bool> needsFullImport();

  /// 首启导入：流式解压 → ATTACH → 单事务分表 INSERT OR REPLACE（只覆盖内容表，
  /// 用户表永不触碰）→ FTS rebuild → 写闸门（§7.5 ①–⑤）。
  Stream<SeedImportState> importBasic();

  /// 完整包导入（用户下载的 zipPath；sha256 校验与 Range 断点续传在下载侧，§7.5）。
  Stream<SeedImportState> importFull(String zipPath);

  /// FTS 后台重建完成标记（settings `fts_rebuild_done`='1'；缺失/中断为 false）。
  Future<bool> ftsRebuildDone();

  /// FTS 后台重建/续跑（幂等、批式 yield 进度，§6.3 T8）：lite 档导入完成后
  /// （ftsPrebuilt=false）或重建中断后续跑时调用；full 档预建索引无需调用。
  Stream<SeedImportState> rebuildFts();
}

/// [SeedImporter] 默认实现（M1-③）。
///
/// 依赖注入（均可缺省走真机默认）：
/// - [assetBundle]：默认 rootBundle（测试传目录 fake）；
/// - [workDirProvider]：解压临时目录，默认 getTemporaryDirectory()；
/// - [databasePathProvider]：app.db 路径（FTS 重建 isolate 开第二连接用），
///   默认按 drift_flutter 0.3.1 口径 = getApplicationDocumentsDirectory()/`<name>`.sqlite。
///
/// origin 词表（种子包说明 §6.1 / 路线图 M1-③）：种子行 origin='seed'（≈ builtin），
/// 用户采集行 'poc'/'live'（≈ collected），导入行 'imported'——清理重写只删 'seed'，
/// 用户行零损伤。UI 徽标映射（设计系统 §4）由展示层负责。
class DefaultSeedImporter implements SeedImporter {
  DefaultSeedImporter(
    this._db, {
    AssetBundle? assetBundle,
    Future<Directory> Function()? workDirProvider,
    Future<String> Function()? databasePathProvider,
    this.seedZipAssetKey = defaultSeedZipAssetKey,
    this.manifestAssetKey = defaultManifestAssetKey,
  }) : _bundle = assetBundle ?? rootBundle,
       _workDirProvider = workDirProvider,
       _databasePathProvider = databasePathProvider;

  /// 内置 lite 种子包 asset（repack_deflate.py 产物，deflate zip）。
  static const String defaultSeedZipAssetKey =
      'assets/seed/seed_pack_lite_v1.zip';

  /// 随包 manifest asset（含 zip_sha256 与 full_pack 下载校验块，无自指问题）。
  static const String defaultManifestAssetKey = 'assets/seed/manifest.json';

  /// 种子行 origin 值（种子包说明 §6.1；seed.db 内 posts/book_entries.origin 已预置同值，导入原样拷贝）。
  static const String seedOrigin = 'seed';

  /// FTS 后台重建完成标记（settings key；取消/中断后缺失 → 重启时可据此续跑重建）。
  static const String ftsRebuildDoneKey = 'fts_rebuild_done';

  /// FTS 批式重建步长（§7.5「每 2000 行 yield 一次刷进度」）。
  static const int ftsRebuildBatch = 2000;

  final AppDatabase _db;
  final AssetBundle _bundle;
  final Future<Directory> Function()? _workDirProvider;
  final Future<String> Function()? _databasePathProvider;
  final String seedZipAssetKey;
  final String manifestAssetKey;

  SendPort? _ftsControlPort;
  bool _ftsRunning = false;

  // ───────────────────────────── 版本闸门 ─────────────────────────────

  @override
  Future<bool> needsBasicImport() async {
    final SeedManifest? manifest = await readManifest();
    if (manifest == null) {
      return false;
    }
    final int? local = await readSeedVersion();
    return local == null || local < manifest.version;
  }

  @override
  Future<bool> needsFullImport() async {
    final SeedManifest? manifest = await readManifest();
    final int? full = manifest?.fullVersion;
    if (full == null) {
      return false;
    }
    final int? local = await readSeedFullVersion();
    return local == null || local < full;
  }

  @override
  Future<int?> readSeedVersion() => _readVersion(SettingsKeys.seedVersion);

  @override
  Future<int?> readSeedFullVersion() =>
      _readVersion(SettingsKeys.seedFullVersion);

  Future<int?> _readVersion(String key) async {
    final row = await (_db.select(
      _db.settings,
    )..where((tbl) => tbl.key.equals(key))).getSingleOrNull();
    return row == null ? null : int.tryParse(row.value);
  }

  @override
  Future<bool> ftsRebuildDone() async {
    final row = await (_db.select(
      _db.settings,
    )..where((tbl) => tbl.key.equals(ftsRebuildDoneKey))).getSingleOrNull();
    return row?.value == '1';
  }

  @override
  Future<SeedManifest?> readManifest() async {
    try {
      final String raw = await _bundle.loadString(manifestAssetKey);
      return SeedManifest.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on FlutterError {
      return null; // asset 不存在（未随包内置种子包）
    } on FormatException {
      return null; // manifest 非法 JSON 视同无种子包（闸门关闭，不阻塞启动）
    }
  }

  /// 流式 SHA256 校验磁盘 zip（64KB 分块，勿全量入内存；下载侧亦可复用）。
  Future<bool> verifyZipSha256(
    String zipPath,
    String expectedSha256Hex,
  ) async => await _fileSha256(zipPath) == expectedSha256Hex.toLowerCase();

  // ───────────────────────────── 首启导入 ─────────────────────────────

  @override
  Stream<SeedImportState> importBasic() async* {
    Directory? work;
    try {
      final SeedManifest? manifest = await readManifest();
      if (manifest == null) {
        yield const SeedImportState(
          phase: SeedImportPhase.error,
          message: '未找到内置种子包 manifest',
        );
        return;
      }
      yield const SeedImportState(
        phase: SeedImportPhase.extracting,
        progress: 0.02,
        message: '读取内置种子包…',
      );
      // asset 一次性物化为 ByteData（≈54MB，rootBundle 无真流式 API；对标扫书 App 首启同款做法），
      // 之后的 sha256/解压全部落盘流式处理，不再双份驻留内存。
      final ByteData zipBytes = await _bundle.load(seedZipAssetKey);
      final Directory w = await _prepareWorkDir('basic');
      work = w;
      yield const SeedImportState(
        phase: SeedImportPhase.extracting,
        progress: 0.08,
        message: '校验并解压 seed.db…',
      );
      final Uint8List bytes = zipBytes.buffer.asUint8List(
        zipBytes.offsetInBytes,
        zipBytes.lengthInBytes,
      );
      final _PrepareResult prepared = await Isolate.run(
        () => _prepareSeed(
          _PrepareJob(
            zipBytes: bytes,
            zipPath: p.join(w.path, 'seed_pack.zip'),
            outDir: w.path,
            expectedZipSha256: manifest.zipSha256,
            maxSizeBytes: _maxExtractBytes(manifest),
          ),
        ),
      );
      // 基础包以随包 asset manifest 为权威（zip/db sha、版本闸门值）。
      yield const SeedImportState(
        phase: SeedImportPhase.importing,
        progress: 0.40,
        message: '导入内容表…',
      );
      final _ImportOutcome outcome = await _importAttached(
        prepared.seedDbPath,
        manifest,
        full: false,
      );
      yield SeedImportState(
        phase: SeedImportPhase.done,
        progress: 1,
        message:
            '基础包 v${manifest.version} 导入完成 ${_countsSummary(outcome.counts)}'
            '${outcome.ftsReady ? '' : '（FTS 待后台重建 rebuildFts()）'}',
      );
    } on SeedImportException catch (e) {
      yield SeedImportState(phase: SeedImportPhase.error, message: e.message);
    } catch (e) {
      yield SeedImportState(
        phase: SeedImportPhase.error,
        message: '种子导入失败: $e',
      );
    } finally {
      _deleteQuietly(work);
    }
  }

  // ───────────────────────────── 完整包导入 ─────────────────────────────

  @override
  Stream<SeedImportState> importFull(String zipPath) async* {
    Directory? work;
    try {
      if (!File(zipPath).existsSync()) {
        yield SeedImportState(
          phase: SeedImportPhase.error,
          message: '完整包不存在: $zipPath',
        );
        return;
      }
      // 完整包 zip sha256 以下载清单（随包 asset manifest 的 full_pack 块）为准；缺失时信任下载侧校验。
      final SeedManifest? assetManifest = await readManifest();
      final Directory w = await _prepareWorkDir('full');
      work = w;
      yield const SeedImportState(
        phase: SeedImportPhase.extracting,
        progress: 0.05,
        message: '校验并解压完整包…',
      );
      final String? expectedZipSha = assetManifest?.sha256;
      final _PrepareResult prepared = await Isolate.run(
        () => _prepareSeed(
          _PrepareJob(
            zipPath: zipPath,
            outDir: w.path,
            expectedZipSha256: expectedZipSha,
            maxSizeBytes:
                1 << 31, // full 档 db ~711MB；内嵌 manifest 读出后由 _prepareSeed 收紧
          ),
        ),
      );
      // 完整包以 zip 内嵌 manifest 为权威（tier/db_sha256/fts_prebuilt/pack_version）。
      final SeedManifest embedded = SeedManifest.fromJson(
        jsonDecode(prepared.embeddedManifestJson) as Map<String, Object?>,
      );
      yield SeedImportState(
        phase: SeedImportPhase.importing,
        progress: 0.40,
        message: embedded.ftsPrebuilt ? '导入内容表（含预建 FTS 影子表）…' : '导入内容表…',
      );
      final _ImportOutcome outcome = await _importAttached(
        prepared.seedDbPath,
        embedded,
        full: true,
      );
      yield SeedImportState(
        phase: SeedImportPhase.done,
        progress: 1,
        message:
            '完整包 v${embedded.version} 导入完成 ${_countsSummary(outcome.counts)}；'
            '${outcome.ftsReady ? 'FTS 预建已就位，跳过重建' : 'FTS 待后台重建 rebuildFts()'
                      '${outcome.ftsError == null ? '' : '（影子表复制失败: ${outcome.ftsError}）'}'}',
      );
    } on SeedImportException catch (e) {
      yield SeedImportState(phase: SeedImportPhase.error, message: e.message);
    } catch (e) {
      yield SeedImportState(
        phase: SeedImportPhase.error,
        message: '完整包导入失败: $e',
      );
    } finally {
      _deleteQuietly(work);
    }
  }

  // ───────────────────────────── FTS 后台重建 ─────────────────────────────

  /// lite 档导入后的后台 FTS 重建（§6.3 T8）：独立 isolate 开第二个 drift 连接，
  /// delete-all 后按 [ftsRebuildBatch] 行分批填充 book_fts/floor_fts，每批 yield 进度；
  /// [cancelFtsRebuild]（或取消订阅）可中断，重跑本方法即幂等续全量。
  /// full 档 ftsPrebuilt 导入已复制影子表，无需调用。
  @override
  Stream<SeedImportState> rebuildFts() async* {
    if (_ftsRunning) {
      yield const SeedImportState(
        phase: SeedImportPhase.error,
        message: 'FTS 重建已在进行中',
      );
      return;
    }
    _ftsRunning = true;
    var completed = false;
    final ReceivePort events = ReceivePort();
    try {
      final String dbPath = await _databasePath();
      // 主连接并发预备：WAL（读写互不阻塞）+ busy_timeout（写写冲突等待而非立报 SQLITE_BUSY），
      // 与重建 isolate 侧同款 pragma 成对；WAL 为库文件级属性，首次切换后对全部连接持久生效。
      try {
        await _db.customStatement('PRAGMA busy_timeout=8000');
        await _db.customStatement('PRAGMA journal_mode=WAL');
      } catch (_) {}
      await Isolate.spawn(
        _ftsRebuildIsolate,
        _FtsJob(dbPath, events.sendPort),
        onError: events.sendPort,
        onExit: events.sendPort,
      );
      await for (final Object? msg in events) {
        if (msg is _FtsEvent) {
          switch (msg.kind) {
            case _FtsEventKind.ready:
              _ftsControlPort = msg.port;
            case _FtsEventKind.progress:
              yield SeedImportState(
                phase: SeedImportPhase.rebuildingFts,
                progress: msg.progress,
                message: msg.message,
              );
            case _FtsEventKind.done:
              completed = !msg.cancelled;
              yield msg.cancelled
                  ? const SeedImportState(
                      phase: SeedImportPhase.error,
                      message: 'FTS 重建已取消（可重新发起）',
                    )
                  : SeedImportState(
                      phase: SeedImportPhase.done,
                      progress: 1,
                      message: msg.message,
                    );
              return; // 注意：switch 内 break 只出 switch，须 return 终止生成器（finally 仍执行）
            case _FtsEventKind.failed:
              completed = true; // 失败不再补发 cancel
              yield SeedImportState(
                phase: SeedImportPhase.error,
                message: 'FTS 重建失败: ${msg.message}',
              );
              return;
          }
        } else if (msg == null) {
          yield const SeedImportState(
            phase: SeedImportPhase.error,
            message: 'FTS 重建 isolate 意外退出',
          );
          return;
        } else if (msg is List) {
          yield SeedImportState(
            phase: SeedImportPhase.error,
            message: 'FTS 重建 isolate 错误: ${msg.first}',
          );
          return;
        }
      }
    } finally {
      if (!completed) {
        _ftsControlPort?.send(
          _ftsCancelMessage,
        ); // 订阅取消/异常 → 通知 isolate 优雅收尾（批间检查后自行退出）
      }
      _ftsControlPort = null;
      _ftsRunning = false;
      events.close();
    }
  }

  /// 请求中断进行中的 FTS 重建（批间检查，秒级生效；索引处于部分态，重跑 rebuildFts 续全）。
  void cancelFtsRebuild() => _ftsControlPort?.send(_ftsCancelMessage);

  // ───────────────────────────── 导入内核 ─────────────────────────────

  /// ATTACH → 清触发器 → 单事务清理重写（§6.2 SQL 策略）→ 恢复触发器 → DETACH。
  /// ATTACH/DETACH 均须在事务外（SQLite 限制）。
  Future<_ImportOutcome> _importAttached(
    String seedDbPath,
    SeedManifest manifest, {
    required bool full,
  }) async {
    // 防御：上次异常中断可能残留 attach（同连接生命周期内）。
    try {
      await _db.customStatement('DETACH DATABASE seed');
    } catch (_) {}
    await _db.customStatement(
      "ATTACH DATABASE '${seedDbPath.replaceAll("'", "''")}' AS seed",
    );
    try {
      final bool seedHasKindColumns = await _seedPostsHasKindColumns();
      // 批量拷贝期间摘除 FTS 同步触发器（触发器逐行同步会把导入拖慢 ~30s 桌面口径，
      // lite 走后台重建、full 走影子表复制；DDL 与 app_database._createFts 保持一致）。
      await _dropFtsTriggers();
      Map<String, int> counts;
      try {
        counts = await _db.transaction(
          () => _copyInTransaction(manifest, full, seedHasKindColumns),
        );
      } finally {
        await _createFtsTriggers();
      }
      // full 档：复制 seed 预建 FTS 影子表（独立事务，失败整体回滚 → rebuildFts() 兜底自愈）。
      var ftsReady = false;
      String? ftsError;
      if (full && manifest.ftsPrebuilt) {
        try {
          await _db.transaction(() async {
            await _copyFtsShadowTables();
            await _upsertSettingRaw(ftsRebuildDoneKey, '1');
          });
          ftsReady = true;
        } catch (e) {
          ftsError = '$e';
        }
      }
      return _ImportOutcome(
        counts: counts,
        ftsReady: ftsReady,
        ftsError: ftsError,
      );
    } finally {
      try {
        await _db.customStatement('DETACH DATABASE seed');
      } catch (_) {}
    }
  }

  /// 单事务：保住用户组引用 → 清理旧 seed 行 → INSERT OR IGNORE 拷贝（显式 drift 列名单，
  /// seed-only 溯源列忽略）→ 用户条目按 name_norm 重挂组 → 闸门落账（§6.2 步骤 1–5）。
  /// 首启时清理步骤为空操作；重跑幂等（显式 id + 唯一键 + OR IGNORE + 事务原子性）。
  Future<Map<String, int>> _copyInTransaction(
    SeedManifest manifest,
    bool full,
    bool seedHasKindColumns,
  ) async {
    // 1) 保住用户条目→组的引用（组即将被全删重写；种子完全持有 book_groups，§6.1）。
    await _db.customStatement('''
      CREATE TEMP TABLE _ug AS
      SELECT b.id AS entry_id, g.name_norm
      FROM book_entries b JOIN book_groups g ON g.id = b.book_group_id
      WHERE b.origin <> '$seedOrigin'
    ''');
    // 2) 清理旧 seed 内容行；用户表与 origin<>'seed' 行永不触碰。
    //    posts 级联清 floors/images（FK ON DELETE CASCADE）；用户条目 post_ref/floor_ref 走 SET NULL。
    await _db.customStatement(
      "DELETE FROM book_entries WHERE origin = '$seedOrigin'",
    );
    await _db.customStatement("DELETE FROM posts WHERE origin = '$seedOrigin'");
    await _db.customStatement('DELETE FROM book_groups');
    // 3) 重写内容表（FK 依赖序：posts → floors → images → book_groups → book_entries）。
    //    OR IGNORE：显式 id/唯一键冲突行让位给先在库行（用户行零损伤）；
    //    EXISTS 过滤防「用户先占 id」时 FK 违例中断整包导入（悬空引用置 NULL，同 SET NULL 语义）。
    final String kindSelect = seedHasKindColumns
        ? 'post_kind, recommend_flag'
        : '''post_type,
           CASE post_type WHEN '扫书' THEN 1 WHEN '排雷' THEN -1 ELSE 0 END''';
    await _db.customStatement('''
      INSERT OR IGNORE INTO main.posts
        (id,tid,title,author,author_name,user_id,portrait,date,date_raw,channel,sub_channel,
         post_type,post_kind,recommend_flag,floor_count,image_count,origin,collected_at)
      SELECT id,tid,title,author,author_name,user_id,portrait,date,date_raw,channel,sub_channel,
             post_type,$kindSelect,floor_count,image_count,origin,collected_at
      FROM seed.posts
    ''');
    await _db.customStatement('''
      INSERT OR IGNORE INTO main.floors
        (id,post_id,seq,pid,text,text_norm_hash,char_count,created_at,author_id)
      SELECT f.id,f.post_id,f.seq,f.pid,f.text,f.text_norm_hash,f.char_count,f.created_at,f.author_id
      FROM seed.floors f
      WHERE EXISTS (SELECT 1 FROM main.posts mp WHERE mp.id = f.post_id)
    ''');
    await _db.customStatement('''
      INSERT OR IGNORE INTO main.images
        (id,floor_id,url_original,url_permanent,width,height)
      SELECT i.id,i.floor_id,i.url_original,i.url_permanent,i.width,i.height
      FROM seed.images i
      WHERE EXISTS (SELECT 1 FROM main.floors mf WHERE mf.id = i.floor_id)
    ''');
    await _db.customStatement('''
      INSERT OR IGNORE INTO main.book_groups
        (id,name_norm,author_eff_norm,name_display,author_display,entry_total,
         distinct_comment,channels,date_min,date_max,word_count_max)
      SELECT id,name_norm,author_eff_norm,name_display,author_display,entry_total,
             distinct_comment,channels,date_min,date_max,word_count_max
      FROM seed.book_groups
    ''');
    await _db.customStatement('''
      INSERT OR IGNORE INTO main.book_entries
        (id,name,name_norm,author,author_norm,author_kind,recommender,comment,comment_src,
         comment_norm_hash,date,date_raw,channel,sub_channel,category,post_ref,floor_ref,
         src_tid,src_url,word_count,book_grade,quality,content_hash,book_group_id,origin,collected_at)
      SELECT s.id,s.name,s.name_norm,s.author,s.author_norm,s.author_kind,s.recommender,s.comment,
             s.comment_src,s.comment_norm_hash,s.date,s.date_raw,s.channel,s.sub_channel,s.category,
             (SELECT mp.id FROM main.posts mp WHERE mp.id = s.post_ref),
             (SELECT mf.id FROM main.floors mf WHERE mf.id = s.floor_ref),
             s.src_tid,s.src_url,s.word_count,s.book_grade,s.quality,s.content_hash,
             s.book_group_id,s.origin,s.collected_at
      FROM seed.book_entries s
    ''');
    // 4) 用户条目按 name_norm 重挂新组（组已消失则置 NULL，App 容忍悬空，§6.2）。
    await _db.customStatement('''
      UPDATE book_entries SET book_group_id =
        (SELECT g.id FROM book_groups g WHERE g.name_norm = _ug.name_norm)
      FROM _ug WHERE book_entries.id = _ug.entry_id
    ''');
    // 5) 闸门落账（full ⊇ basic 内容，双闸门同记；与拷贝同事务 → 中断重跑无半态）。
    await _upsertSetting(SettingsKeys.seedVersion, manifest.version);
    if (full) {
      await _upsertSetting(SettingsKeys.seedFullVersion, manifest.version);
    }
    // 5b) 维护闸门随包走：包若声明「已去重 / 已按 vN 回填分类」，就地落 maintenance.dart 的
    //     两个 settings 闸门，让首启后台维护（seed_import_providers.dart
    //     `_runMaintenanceInBackground`）直接跳过——包内已是收敛态，全量扫一遍（桌面实测
    //     18.7s）结果必然是 0 删 0 改的白扫。同样与内容拷贝同事务：中断则整体回滚，
    //     不会出现「内容半态 + 闸门已落」的假收敛。
    //     版本语义（**不是 bug，勿改成写 App 侧常量**）：落的是**包声明的版本**，
    //     `needsReclassify` 用 `!=` 与 App 的 `classifierVersion`（lib/classify/classifier.dart）比：
    //       包 3 / App 3 → 匹配 → 跳过（当前发行包这一档）；
    //       包 3 / App 4 → 不匹配 → 首启自动重跑 v4 回填并落 4（App 升级后自愈）；
    //       包无标记（老包 / 未清洗档）→ 一个闸门都不写 → 维护照跑（向后兼容）。
    if (manifest.preDeduped) {
      await _upsertSettingRaw(SettingsKeys.dedupVersion, dedupDoneValue);
    }
    final int? preClassified = manifest.preClassifiedVersion;
    if (preClassified != null) {
      await _upsertSettingRaw(SettingsKeys.classifierVersion, '$preClassified');
    }
    // FTS 重建完成标记随内容重写失效（lite 需重建；full 影子表复制成功后另行落账）。
    await _db.customStatement(
      "DELETE FROM settings WHERE key = '$ftsRebuildDoneKey'",
    );
    await _db.customStatement('DROP TABLE IF EXISTS _ug');

    // 行数对账（信息性，写进 done message；硬性一致性由 zip/db sha256 保证）。
    final Map<String, int> counts = <String, int>{
      for (final MapEntry<String, String> e in _seedCountQueries.entries)
        e.key: await _countOne(e.value),
    };
    return counts;
  }

  /// seed 行口径的对账查询（floors/images 无 origin 列，随父帖 origin，§6.1）。
  static const Map<String, String> _seedCountQueries = <String, String>{
    'posts': "SELECT COUNT(*) AS n FROM posts WHERE origin = '$seedOrigin'",
    'floors':
        "SELECT COUNT(*) AS n FROM floors f JOIN posts p ON p.id = f.post_id WHERE p.origin = '$seedOrigin'",
    'images':
        'SELECT COUNT(*) AS n FROM images i JOIN floors f ON f.id = i.floor_id '
        "JOIN posts p ON p.id = f.post_id WHERE p.origin = '$seedOrigin'",
    'book_entries':
        "SELECT COUNT(*) AS n FROM book_entries WHERE origin = '$seedOrigin'",
    'book_groups': 'SELECT COUNT(*) AS n FROM book_groups',
  };

  Future<int> _countOne(String sql) async =>
      _row(await _db.customSelect(sql).getSingle());

  /// full 档：复制 seed 预建 FTS 影子表（external-content rowid 与显式 id 拷贝一致 → 直接可用）。
  /// FTS5 影子 schema 版本不符或复制失败 → 抛出（调用侧回滚并回退后台 rebuildFts()）。
  Future<void> _copyFtsShadowTables() async {
    const List<String> tables = <String>['book_fts', 'floor_fts'];
    // external-content FTS5 无 _content 影子表（正文存于内容表本体）
    const List<String> suffixes = <String>[
      '_data',
      '_idx',
      '_docsize',
      '_config',
    ];
    for (final String t in tables) {
      // FTS5 config 影子表列名为 k/v（CREATE TABLE x_config(id INTEGER PRIMARY KEY CHECK(id=1), k, v)）
      final QueryRow mainV = await _db
          .customSelect(
            "SELECT v AS ver FROM main.${t}_config WHERE k = 'version'",
          )
          .getSingle();
      final QueryRow seedV = await _db
          .customSelect(
            "SELECT v AS ver FROM seed.${t}_config WHERE k = 'version'",
          )
          .getSingle();
      if (mainV.data['ver'] != seedV.data['ver']) {
        // FTS5 版本差异，宁重建不冒索引损坏风险
        throw SeedImportException(
          'FTS5 影子表版本不符（main=${mainV.data['ver']} seed=${seedV.data['ver']}）',
        );
      }
      for (final String s in suffixes) {
        await _db.customStatement('DELETE FROM main.$t$s');
        await _db.customStatement(
          'INSERT INTO main.$t$s SELECT * FROM seed.$t$s',
        );
      }
    }
  }

  /// seed.posts 是否已带分类列（当前打包 ETL 未产出 → 导入侧按 post_type 派生；
  /// 未来 ETL 补上（§7.4 Phase S2）则直迁，无需改导入代码）。
  Future<bool> _seedPostsHasKindColumns() async {
    final List<QueryRow> cols = await _db
        .customSelect('PRAGMA seed.table_info(posts)')
        .get();
    final Set<String> names = cols
        .map((QueryRow r) => r.data['name'] as String)
        .toSet();
    return names.contains('post_kind') && names.contains('recommend_flag');
  }

  Future<void> _upsertSetting(String key, int value) =>
      _upsertSettingRaw(key, '$value');

  Future<void> _upsertSettingRaw(
    String key,
    String value,
  ) => _db.customStatement(
    "INSERT INTO settings(key,value) VALUES('$key','${value.replaceAll("'", "''")}') "
    'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
  );

  // 触发器 DDL 与 app_database.dart _createFts 保持一致（那里是权威源；本文件因跨库私有性复制）。
  static const List<String> _ftsTriggerDdl = <String>[
    '''CREATE TRIGGER IF NOT EXISTS book_entries_ai AFTER INSERT ON book_entries BEGIN
       INSERT INTO book_fts(rowid,name,author,recommender,comment)
       VALUES (new.id,new.name,new.author,new.recommender,new.comment); END''',
    '''CREATE TRIGGER IF NOT EXISTS book_entries_ad AFTER DELETE ON book_entries BEGIN
       INSERT INTO book_fts(book_fts,rowid,name,author,recommender,comment)
       VALUES ('delete',old.id,old.name,old.author,old.recommender,old.comment); END''',
    '''CREATE TRIGGER IF NOT EXISTS book_entries_au AFTER UPDATE ON book_entries BEGIN
       INSERT INTO book_fts(book_fts,rowid,name,author,recommender,comment)
       VALUES ('delete',old.id,old.name,old.author,old.recommender,old.comment);
       INSERT INTO book_fts(rowid,name,author,recommender,comment)
       VALUES (new.id,new.name,new.author,new.recommender,new.comment); END''',
    '''CREATE TRIGGER IF NOT EXISTS floors_ai AFTER INSERT ON floors BEGIN
       INSERT INTO floor_fts(rowid,text) VALUES (new.id,new.text); END''',
    '''CREATE TRIGGER IF NOT EXISTS floors_ad AFTER DELETE ON floors BEGIN
       INSERT INTO floor_fts(floor_fts,rowid,text) VALUES ('delete',old.id,old.text); END''',
    '''CREATE TRIGGER IF NOT EXISTS floors_au AFTER UPDATE ON floors BEGIN
       INSERT INTO floor_fts(floor_fts,rowid,text) VALUES ('delete',old.id,old.text);
       INSERT INTO floor_fts(rowid,text) VALUES (new.id,new.text); END''',
  ];

  Future<void> _dropFtsTriggers() async {
    for (final String name in <String>[
      'book_entries_ai',
      'book_entries_ad',
      'book_entries_au',
      'floors_ai',
      'floors_ad',
      'floors_au',
    ]) {
      await _db.customStatement('DROP TRIGGER IF EXISTS $name');
    }
  }

  Future<void> _createFtsTriggers() async {
    for (final String ddl in _ftsTriggerDdl) {
      await _db.customStatement(ddl);
    }
  }

  // ───────────────────────────── 路径/杂项 ─────────────────────────────

  Future<Directory> _prepareWorkDir(String tag) async {
    final Directory base = _workDirProvider == null
        ? await getTemporaryDirectory()
        : await _workDirProvider();
    final Directory dir = Directory(p.join(base.path, 'seed_import_$tag'));
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true); // 重入卫生：清掉上次中断的半成品
    }
    dir.createSync(recursive: true);
    return dir;
  }

  Future<String> _databasePath() async {
    if (_databasePathProvider != null) {
      return _databasePathProvider();
    }
    // drift_flutter 0.3.1 默认口径：getApplicationDocumentsDirectory()/<name>.sqlite
    final Directory dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, '${AppConstants.databaseName}.sqlite');
  }

  static int _maxExtractBytes(SeedManifest manifest) {
    final int db = manifest.dbSizeBytes ?? (1 << 28);
    return (db * 1.2).round() + (16 << 20); // db + manifest 余量，防 zip bomb
  }

  static String _countsSummary(Map<String, int> counts) =>
      '(${counts.entries.map((MapEntry<String, int> e) => '${e.key} ${e.value}').join(', ')})';

  static void _deleteQuietly(Directory? dir) {
    try {
      if (dir != null && dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    } catch (_) {}
  }
}

/// 导入结果（内部）：行数对账 + full 档 FTS 影子表是否就位（失败原因随 ftsError 透出）。
class _ImportOutcome {
  const _ImportOutcome({
    required this.counts,
    required this.ftsReady,
    this.ftsError,
  });

  final Map<String, int> counts;
  final bool ftsReady;
  final String? ftsError;
}

/// 解压+校验后台任务（Isolate.run 消息，须可跨 isolate 传输）。
class _PrepareJob {
  const _PrepareJob({
    this.zipBytes,
    required this.zipPath,
    required this.outDir,
    this.expectedZipSha256,
    required this.maxSizeBytes,
  });

  /// importBasic：asset 物化字节（写盘后与 zipPath 同途处理）。
  final Uint8List? zipBytes;

  /// zip 落盘路径（importFull 直接传磁盘路径，zipBytes 为 null）。
  final String zipPath;
  final String outDir;

  /// zip 整体 sha256（流式校验；null = 跳过，信任下载侧）。
  final String? expectedZipSha256;
  final int maxSizeBytes;
}

class _PrepareResult {
  const _PrepareResult(this.seedDbPath, this.embeddedManifestJson);

  final String seedDbPath;
  final String embeddedManifestJson;
}

/// 后台 isolate：落盘 zip → 流式 sha256 校验 → 读内嵌 manifest → 流式解压 → 校验 seed.db。
Future<_PrepareResult> _prepareSeed(_PrepareJob job) async {
  final File zipFile = File(job.zipPath);
  if (job.zipBytes != null) {
    await zipFile.writeAsBytes(job.zipBytes!, flush: true);
  }
  if (job.expectedZipSha256 != null) {
    final String actual = await _fileSha256(job.zipPath);
    if (actual != job.expectedZipSha256!.toLowerCase()) {
      throw SeedImportException(
        'zip SHA256 校验失败（期望 ${job.expectedZipSha256}，实际 $actual）',
      );
    }
  }
  // 先读内嵌 manifest.json（小条目），拿到 db_file/db_sha256/尺寸上限再解大包。
  String manifestJson;
  final InputFileStream zipIn = InputFileStream(job.zipPath);
  try {
    final Archive probe = ZipDecoder().decodeStream(zipIn);
    final ArchiveFile? mf = probe.findFile('manifest.json');
    if (mf == null) {
      throw const SeedImportException('种子包内缺少 manifest.json');
    }
    manifestJson = utf8.decode(mf.content as List<int>);
    await probe.clear();
  } on SeedImportException {
    rethrow;
  } catch (e) {
    throw SeedImportException('种子包 zip 解析失败: $e');
  } finally {
    await zipIn.close();
  }
  final SeedManifest embedded = SeedManifest.fromJson(
    jsonDecode(manifestJson) as Map<String, Object?>,
  );
  final int maxSize = embedded.dbSizeBytes != null
      ? (embedded.dbSizeBytes! * 1.2).round() + (16 << 20)
      : job.maxSizeBytes;
  await extractFileToDisk(job.zipPath, job.outDir, maxSize: maxSize);
  final String seedDbPath = p.join(job.outDir, embedded.dbFile);
  final File seedDb = File(seedDbPath);
  if (!seedDb.existsSync()) {
    throw SeedImportException('解压后未找到 ${embedded.dbFile}');
  }
  if (embedded.dbSizeBytes != null &&
      seedDb.lengthSync() != embedded.dbSizeBytes) {
    throw SeedImportException(
      'seed.db 尺寸不符（期望 ${embedded.dbSizeBytes}，实际 ${seedDb.lengthSync()}）',
    );
  }
  if (embedded.dbSha256 != null) {
    final String actual = await _fileSha256(seedDbPath);
    if (actual != embedded.dbSha256!.toLowerCase()) {
      throw SeedImportException('seed.db SHA256 校验失败（数据损坏，请重试）');
    }
  }
  return _PrepareResult(seedDbPath, manifestJson);
}

/// 流式 SHA256（64KB 分块读文件，勿全量入内存）。
Future<String> _fileSha256(String path) async {
  late final String hex;
  final ByteConversionSink input = sha256.startChunkedConversion(
    ChunkedConversionSink<Digest>.withCallback(
      (List<Digest> digests) => hex = digests.single.toString(),
    ),
  );
  await for (final List<int> chunk in File(path).openRead()) {
    input.add(chunk);
  }
  input.close();
  return hex;
}

// ───────────────────────────── FTS 重建 isolate ─────────────────────────────

const String _ftsCancelMessage = 'cancel';

enum _FtsEventKind { ready, progress, done, failed }

class _FtsEvent {
  const _FtsEvent(
    this.kind, {
    this.port,
    this.progress = 0,
    this.message = '',
    this.cancelled = false,
  });

  final _FtsEventKind kind;
  final SendPort? port;
  final double progress;
  final String message;
  final bool cancelled;
}

class _FtsJob {
  const _FtsJob(this.dbPath, this.events);

  final String dbPath;
  final SendPort events;
}

/// 后台 isolate 入口：独立 drift 连接（WAL + busy_timeout，与主连接并发安全），
/// delete-all 后分批重建 book_fts/floor_fts（external-content 直插 rowid），每批回报进度，
/// 批间检查取消。完成后落 settings.fts_rebuild_done=1（重启续跑判据）。
///
/// 范围：全部行（种子 + 既有用户行——升级重导后 delete-all 会把用户行索引一并清掉，
/// 必须全量重填）；起点快照 MAX(id)，快照后的新写入行 id 必大于快照值（AUTOINCREMENT），
/// 由已恢复的触发器负责，重建批次不会重复索引。
Future<void> _ftsRebuildIsolate(_FtsJob job) async {
  final ReceivePort control = ReceivePort();
  job.events.send(_FtsEvent(_FtsEventKind.ready, port: control.sendPort));
  var cancelled = false;
  control.listen((Object? msg) {
    if (msg == _ftsCancelMessage) {
      cancelled = true;
    }
  });
  final AppDatabase db = AppDatabase(
    NativeDatabase(
      File(job.dbPath),
      setup: (d) {
        d.execute('PRAGMA busy_timeout=8000');
        d.execute('PRAGMA journal_mode=WAL');
      },
    ),
  );
  final Stopwatch sw = Stopwatch()..start();
  const int batch = DefaultSeedImporter.ftsRebuildBatch;
  try {
    // 幂等起点：清空旧索引（取消后重跑 / 升级重导后重建 都从这里开始）。
    await db.customStatement(
      "INSERT INTO book_fts(book_fts) VALUES('delete-all')",
    );
    await db.customStatement(
      "INSERT INTO floor_fts(floor_fts) VALUES('delete-all')",
    );
    await db.customStatement(
      "DELETE FROM settings WHERE key = '${DefaultSeedImporter.ftsRebuildDoneKey}'",
    );
    final int maxEntryId = _row(
      await db
          .customSelect('SELECT COALESCE(MAX(id),0) AS n FROM book_entries')
          .getSingle(),
    );
    final int maxFloorId = _row(
      await db
          .customSelect('SELECT COALESCE(MAX(id),0) AS n FROM floors')
          .getSingle(),
    );
    final int totalBooks = _row(
      await db
          .customSelect(
            'SELECT COUNT(*) AS n FROM book_entries WHERE id <= $maxEntryId',
          )
          .getSingle(),
    );
    final int totalFloors = _row(
      await db
          .customSelect(
            'SELECT COUNT(*) AS n FROM floors WHERE id <= $maxFloorId',
          )
          .getSingle(),
    );
    final int total = totalBooks + totalFloors;
    var processed = 0;
    // book_fts：id 游标分批（external-content 表直插 rowid，绕过触发器）。
    var cursor = 0;
    while (!cancelled) {
      final int? maxId =
          (await db
                      .customSelect(
                        'SELECT MAX(id) AS m FROM (SELECT id FROM book_entries '
                        'WHERE id > $cursor AND id <= $maxEntryId '
                        'ORDER BY id LIMIT $batch)',
                      )
                      .getSingle())
                  .data['m']
              as int?;
      if (maxId == null) {
        break;
      }
      await db.customStatement(
        'INSERT INTO book_fts(rowid,name,author,recommender,comment) '
        'SELECT id,name,author,recommender,comment FROM book_entries '
        'WHERE id > $cursor AND id <= $maxId',
      );
      processed += _row(
        await db.customSelect('SELECT changes() AS n').getSingle(),
      );
      cursor = maxId;
      job.events.send(
        _FtsEvent(
          _FtsEventKind.progress,
          progress: total == 0 ? 1 : processed / total,
          message: 'book_fts $processed/$total',
        ),
      );
      // NativeDatabase 同步执行 → await 链全走微任务，须显式让出事件循环，
      // 否则控制端口的 cancel 消息在重建结束前得不到处理。
      await Future<void>.delayed(Duration.zero);
    }
    // floor_fts：同型。
    cursor = 0;
    while (!cancelled) {
      final int? maxId =
          (await db
                      .customSelect(
                        'SELECT MAX(id) AS m FROM (SELECT id FROM floors '
                        'WHERE id > $cursor AND id <= $maxFloorId '
                        'ORDER BY id LIMIT $batch)',
                      )
                      .getSingle())
                  .data['m']
              as int?;
      if (maxId == null) {
        break;
      }
      await db.customStatement(
        'INSERT INTO floor_fts(rowid,text) '
        'SELECT id, text FROM floors '
        'WHERE id > $cursor AND id <= $maxId',
      );
      processed += _row(
        await db.customSelect('SELECT changes() AS n').getSingle(),
      );
      cursor = maxId;
      job.events.send(
        _FtsEvent(
          _FtsEventKind.progress,
          progress: total == 0 ? 1 : processed / total,
          message: 'floor_fts $processed/$total',
        ),
      );
      await Future<void>.delayed(Duration.zero); // 同上：让出事件循环收 cancel
    }
    if (cancelled) {
      job.events.send(
        const _FtsEvent(_FtsEventKind.done, cancelled: true, message: '已取消'),
      );
    } else {
      await db.customStatement(
        "INSERT INTO settings(key,value) VALUES('${DefaultSeedImporter.ftsRebuildDoneKey}','1') "
        'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      );
      job.events.send(
        _FtsEvent(
          _FtsEventKind.done,
          progress: 1,
          message:
              'FTS 重建完成：$processed 行 / ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s',
        ),
      );
    }
  } catch (e) {
    job.events.send(_FtsEvent(_FtsEventKind.failed, message: '$e'));
  } finally {
    await db.close();
    control.close();
  }
}

int _row(QueryRow row) => row.read<int>('n');
