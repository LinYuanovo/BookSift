// 种子引导控制器测试（P0-1 首启导入接线 = 原型 §9.2 seedImportControllerProvider 状态机）。
//
// 事故背景：M1-③ 交付了导入机制（DefaultSeedImporter，11 单测含 BENCH 真导入），
// 但全工程无调用点——首启自动导入从未接线，直到 2026-10-14 首次真机安装才暴露
// （首页恒显「书库为空」）。本文件与 home_seed_ui_test.dart 共同守卫接线本身。
//
// plain test()：fake importer 全同步微任务流，零真实 IO（TESTING.md §1）。

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/data/seed_import.dart';
import 'package:booksift/data/seed_import_providers.dart';

/// 脚本化 importer：闸门/流内容/调用计数全可控。
class ScriptedImporter implements SeedImporter {
  ScriptedImporter({
    this.needsBasic = false,
    this.basicStates = const <SeedImportState>[],
    this.ftsDone = true,
    this.ftsStates = const <SeedImportState>[],
    this.needsBasicThrows = false,
  });

  bool needsBasic;
  List<SeedImportState> basicStates;
  bool ftsDone;
  List<SeedImportState> ftsStates;
  bool needsBasicThrows;

  int basicCalls = 0;
  int ftsCalls = 0;

  /// 非空时 importBasic 返回手动流（重入守卫用例用）。
  StreamController<SeedImportState>? basicLive;

  @override
  Future<int?> readSeedVersion() async => 1;

  @override
  Future<int?> readSeedFullVersion() async => 1;

  @override
  Future<SeedManifest?> readManifest() async => null;

  @override
  Future<bool> needsBasicImport() async {
    if (needsBasicThrows) {
      throw StateError('manifest 读取失败');
    }
    return needsBasic;
  }

  @override
  Future<bool> needsFullImport() async => false;

  @override
  Stream<SeedImportState> importBasic() {
    basicCalls++;
    final StreamController<SeedImportState>? live = basicLive;
    if (live != null) {
      return live.stream;
    }
    return Stream<SeedImportState>.fromIterable(basicStates);
  }

  @override
  Stream<SeedImportState> importFull(String zipPath) => const Stream<SeedImportState>.empty();

  @override
  Future<bool> ftsRebuildDone() async => ftsDone;

  /// 测试默认：视为老库已回填 full（不进入 awaitingChoice）。
  FtsMode? ftsMode = FtsMode.full;
  FtsMode? builtMode = FtsMode.full;

  @override
  Future<FtsMode?> readFtsMode() async => ftsMode;

  @override
  Future<FtsMode?> readFtsBuiltMode() async => builtMode;

  @override
  Future<void> writeFtsMode(FtsMode desired, {FtsMode? built}) async {
    ftsMode = desired;
    if (built != null) {
      builtMode = built;
    }
  }

  @override
  Stream<SeedImportState> rebuildFts() {
    ftsCalls++;
    return Stream<SeedImportState>.fromIterable(ftsStates);
  }
}

const SeedImportState kExtracting =
    SeedImportState(phase: SeedImportPhase.extracting, progress: 0.08, message: '校验并解压 seed.db…');
const SeedImportState kImporting = SeedImportState(phase: SeedImportPhase.importing, progress: 0.4, message: '导入内容表…');
const SeedImportState kDone = SeedImportState(phase: SeedImportPhase.done, progress: 1, message: '基础包 v1 导入完成');

ProviderContainer boot(ScriptedImporter imp, List<SeedImportState> seen) {
  final ProviderContainer c =
      ProviderContainer(overrides: <Override>[seedImporterProvider.overrideWithValue(imp)]);
  addTearDown(c.dispose);
  c.listen<SeedImportState>(seedBootstrapProvider, (_, SeedImportState next) => seen.add(next),
      fireImmediately: true);
  return c;
}

void main() {
  test('闸门关闭且 FTS 就绪：done（种子已导入），不触导入/重建', () async {
    final ScriptedImporter imp = ScriptedImporter();
    final List<SeedImportState> seen = <SeedImportState>[];
    final ProviderContainer c = boot(imp, seen);
    await c.read(seedBootstrapProvider.notifier).ensureStarted();
    expect(c.read(seedBootstrapProvider).phase, SeedImportPhase.done);
    expect(imp.basicCalls, 0);
    expect(imp.ftsCalls, 0);
  });

  test('闸门开启：状态机依次映射 importBasic 流；FTS 未就绪静默续跑且不覆盖 done', () async {
    final ScriptedImporter imp = ScriptedImporter(
      needsBasic: true,
      basicStates: const <SeedImportState>[kExtracting, kImporting, kDone],
      ftsDone: false,
      ftsStates: const <SeedImportState>[
        SeedImportState(phase: SeedImportPhase.rebuildingFts, progress: 0.5, message: 'book_fts 50%'),
        SeedImportState(phase: SeedImportPhase.done, progress: 1, message: 'FTS 就绪'),
      ],
    );
    final List<SeedImportState> seen = <SeedImportState>[];
    final ProviderContainer c = boot(imp, seen);
    await c.read(seedBootstrapProvider.notifier).ensureStarted();
    expect(c.read(seedBootstrapProvider).phase, SeedImportPhase.done);
    expect(imp.basicCalls, 1);
    expect(imp.ftsCalls, 1);
    // UI 可见状态 = 导入三态；FTS 进度被吞（后台静默），不得出现在状态流里。
    expect(seen.map((SeedImportState s) => s.phase).toList(), <SeedImportPhase>[
      SeedImportPhase.idle,
      SeedImportPhase.extracting,
      SeedImportPhase.importing,
      SeedImportPhase.done,
    ]);
  });

  test('导入 error：保留错误消息；ensureStarted 可重入 = 重试成功', () async {
    final ScriptedImporter imp = ScriptedImporter(
      needsBasic: true,
      basicStates: const <SeedImportState>[
        kExtracting,
        SeedImportState(phase: SeedImportPhase.error, message: 'zip sha256 不符'),
      ],
    );
    final List<SeedImportState> seen = <SeedImportState>[];
    final ProviderContainer c = boot(imp, seen);
    final SeedBootstrapController ctl = c.read(seedBootstrapProvider.notifier);
    await ctl.ensureStarted();
    expect(c.read(seedBootstrapProvider).phase, SeedImportPhase.error);
    expect(c.read(seedBootstrapProvider).message, 'zip sha256 不符');
    expect(imp.ftsCalls, 0, reason: '导入失败不得继续 FTS 重建');
    // 修复后重试：闸门仍开（seed_version 未写入），第二次流给 done。
    imp.basicStates = const <SeedImportState>[kDone];
    await ctl.ensureStarted();
    expect(c.read(seedBootstrapProvider).phase, SeedImportPhase.done);
    expect(imp.basicCalls, 2);
  });

  test('重入守卫：importBasic 进行中再 ensureStarted 不重复执行', () async {
    final ScriptedImporter imp = ScriptedImporter(needsBasic: true)
      ..basicLive = StreamController<SeedImportState>();
    addTearDown(() => imp.basicLive!.close());
    final ProviderContainer c = boot(imp, <SeedImportState>[]);
    final SeedBootstrapController ctl = c.read(seedBootstrapProvider.notifier);
    final Future<void> first = ctl.ensureStarted();
    imp.basicLive!.add(kExtracting);
    await Future<void>.delayed(Duration.zero); // 让流事件与守卫标志就位
    await ctl.ensureStarted(); // 进行中重入 → 应立即返回不二次导入
    expect(imp.basicCalls, 1);
    imp.basicLive!.add(kDone);
    await imp.basicLive!.close();
    await first;
    expect(c.read(seedBootstrapProvider).phase, SeedImportPhase.done);
  });

  test('FTS 后台失败不升级为 error（best-effort，检索走 LIKE 降级）', () async {
    final ScriptedImporter imp = ScriptedImporter(
      needsBasic: true,
      basicStates: const <SeedImportState>[kDone],
      ftsDone: false,
      ftsStates: const <SeedImportState>[
        SeedImportState(phase: SeedImportPhase.error, message: 'isolate 崩溃'),
      ],
    );
    final ProviderContainer c = boot(imp, <SeedImportState>[]);
    await c.read(seedBootstrapProvider.notifier).ensureStarted();
    final SeedImportState s = c.read(seedBootstrapProvider);
    expect(s.phase, SeedImportPhase.done, reason: 'FTS 失败不得污染导入完成态');
    expect(s.message, kDone.message);
  });

  test('重启续跑场景：闸门关闭但 FTS 未就绪 → 不导入、只续重建', () async {
    final ScriptedImporter imp = ScriptedImporter(ftsDone: false);
    final ProviderContainer c = boot(imp, <SeedImportState>[]);
    await c.read(seedBootstrapProvider.notifier).ensureStarted();
    expect(imp.basicCalls, 0);
    expect(imp.ftsCalls, 1);
    expect(c.read(seedBootstrapProvider).phase, SeedImportPhase.done);
  });

  test('needsBasicImport 抛异常 → error 态（不炸启动）', () async {
    final ScriptedImporter imp = ScriptedImporter(needsBasicThrows: true);
    final ProviderContainer c = boot(imp, <SeedImportState>[]);
    await c.read(seedBootstrapProvider.notifier).ensureStarted();
    expect(c.read(seedBootstrapProvider).phase, SeedImportPhase.error);
    expect(c.read(seedBootstrapProvider).message, contains('种子导入失败'));
  });

  test('首启未选档位 → awaitingChoice 且不导入；chooseFtsMode(off) 后继续导入', () async {
    final ScriptedImporter imp = ScriptedImporter(
      needsBasic: true,
      basicStates: const <SeedImportState>[kDone],
    )..ftsMode = null;
    final ProviderContainer c = boot(imp, <SeedImportState>[]);
    final SeedBootstrapController ctl = c.read(seedBootstrapProvider.notifier);

    await ctl.ensureStarted();
    expect(c.read(seedBootstrapProvider).phase, SeedImportPhase.awaitingChoice);
    expect(imp.basicCalls, 0, reason: '未选档位不得开始导入');

    await ctl.chooseFtsMode(FtsMode.off);
    expect(imp.basicCalls, 1);
    expect(imp.ftsMode, FtsMode.off);
    expect(c.read(seedBootstrapProvider).phase, SeedImportPhase.done);
  });

  test('老库（无 fts_mode）→ 按能力回填 full，不弹框、不重建', () async {
    final ScriptedImporter imp = ScriptedImporter()
      ..ftsMode = null
      ..builtMode = null;
    final ProviderContainer c = boot(imp, <SeedImportState>[]);
    await c.read(seedBootstrapProvider.notifier).ensureStarted();
    expect(c.read(seedBootstrapProvider).phase, SeedImportPhase.done);
    expect(imp.ftsMode, FtsMode.full, reason: '测试环境缺省按 full 回填');
    expect(imp.builtMode, FtsMode.full);
    expect(imp.ftsCalls, 0);
  });
}
