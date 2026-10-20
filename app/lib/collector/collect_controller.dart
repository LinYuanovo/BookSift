/// 采集控制器（M2-① 真实现；契约名冻结——类名/provider 名/接口签名与桩版一致）。
///
/// [CollectRunNotifier] 在 build() 内经 `ref` 组装 [CollectService]
/// （依赖全部走 provider，测试可 override 注入假 API/假 worker/假时钟，
/// 见 test/collector/）。UI 只消费 [collectRunStateProvider] 快照与
/// [collectControllerProvider] 五个控制方法。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bduss.dart';
import '../data/repo/collect_repository_providers.dart';
import '../data/repo/database_provider.dart';
import 'collect_service.dart';
import 'collect_providers.dart';
import 'collect_state.dart';
import 'scheduler.dart';
import 'tieba_api.dart';

/// 采集控制入口（UI → 服务）。
abstract interface class CollectController {
  /// 立即采集：对所有 enabled 关注吧启动一轮增量采集（§8.7 流程）。
  /// 运行中再调用 = no-op。冷却中的吧跳过并给出日志。
  ///
  /// 返回的 future 在**整轮结束**时完成（按钮 handler 可 await 做 loading，
  /// 不会阻塞 UI；进度经 [collectRunStateProvider] 快照流实时发布）。
  Future<void> startAll();

  /// 取消采集（水位不推进，各吧分支尽快收尾；phase → stopping → idle）。
  Future<void> cancel();

  /// 添加关注吧：先拉 get_threads 第 1 页验证存在性（§5.9），成功写入 collection_state。
  /// 失败抛 [CollectAddForumException]（吧不存在 / 网络错误 / 风控）。
  Future<void> addForum(String fname);

  /// 启用/停用某吧（collection_state.enabled）。
  Future<void> setForumEnabled(String fname, bool enabled);

  /// 删除关注吧（仅删水位行，不删已入库内容）。
  Future<void> removeForum(String fname);
}

/// addForum 失败原因（UI 展示用文案已本地化）。
class CollectAddForumException implements Exception {
  const CollectAddForumException(this.reason);

  final String reason;

  @override
  String toString() => 'CollectAddForumException($reason)';
}

/// 运行态 Notifier（真实现；实现要点见 [CollectService] 与 §8.8 并发模型）。
///
/// BDUSS（需求 8/5）切换时机 = **每轮 run 启动时**：客户端（`tiebaApiProvider`，
/// 导入后已换新）与配额/间隔/并发档（`dailyBudgetFor` + `intervalMsFor` +
/// `effectiveConcurrency` 按 bdussImported 选档）都在 [startAll] 建本轮服务时取
/// `effectiveBdussProvider`（失效标记 → 匿名）的当下值。不在 build() 里 watch ——
/// 它是异步依赖，落定瞬间会把本 notifier 标记为 outdated（"dependency changed but
/// before rebuild"），与「运行中服务唯一、可取消」的语义冲突（controller_test 实测）。
class CollectRunNotifier extends Notifier<CollectRunState>
    implements CollectController {
  CollectService? _service;
  bool _disposed = false;

  @override
  CollectRunState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const CollectRunState.idle();
  }

  /// 新建本轮服务（装配依赖此处 `ref.read` 现取：bduss 导入/清除/失效后的档位
  /// 切换在下一轮采集生效；运行中不换档，避免半途换身份与孤儿服务）。
  CollectService _newService() {
    // 生效凭证（已标记失效 → null，按匿名档跑）。
    final String? bduss = ref.read(effectiveBdussProvider).value;
    final bool imported = (bduss ?? '').isNotEmpty;
    return CollectService(
      db: ref.read(appDatabaseProvider),
      repo: ref.read(collectRepositoryProvider),
      api: ref.read(tiebaApiProvider),
      workerFactory: ref.read(postWorkerFactoryProvider),
      networkGate: ref.read(networkGateProvider),
      clock: ref.read(collectClockProvider),
      sleeper: ref.read(collectSleeperProvider),
      budgetLimit: dailyBudgetFor(bduss),
      bdussImported: imported,
      // 账号档专用：登录态失效 → 本轮换匿名客户端（ProtoTiebaApi 不带凭证）
      // + 标记凭证失效（幂等；不删凭证，重导即清标记）。
      anonymousApiFactory: imported ? ProtoTiebaApi.new : null,
      onAccountInvalid: imported
          ? () => unawaited(ref.read(bdussControllerProvider).markInvalid())
          : null,
      onState: (CollectRunState s) {
        if (!_disposed) state = s;
      },
    );
  }

  @override
  Future<void> startAll() {
    final CollectService? current = _service;
    if (current != null && current.isRunning) {
      return current.completion; // 运行中再调 = no-op（同一轮）
    }
    final CollectService service = _newService();
    _service = service;
    return service.run();
  }

  @override
  Future<void> cancel() async {
    final CollectService? s = _service;
    if (s == null || !s.isRunning) return;
    s.requestCancel();
    await s.completion;
  }

  @override
  Future<void> addForum(String fname) async {
    final String name = fname.trim();
    if (name.isEmpty) throw const CollectAddForumException('吧名不能为空');
    final TiebaApi api = ref.read(tiebaApiProvider);
    final ThreadsPage page;
    try {
      // 验证存在性 = get_threads 第 1 页（§5.9）；单发请求不走全局限速器。
      page = await api.getThreads(name, pn: 1);
    } on CollectRequestException catch (e) {
      throw CollectAddForumException(switch (e.kind) {
        CollectFailureKind.rateLimited =>
          '触发贴吧风控/频控（${e.message}），请稍后再试',
        CollectFailureKind.serverError =>
          '吧「$name」不存在或接口异常（${e.message}）',
        CollectFailureKind.network => '网络错误：${e.message}',
      });
    } catch (e) {
      throw CollectAddForumException('网络错误：$e');
    }
    if (page.fid <= 0 && page.threads.isEmpty) {
      throw CollectAddForumException('吧「$name」不存在或无法访问');
    }
    await ref
        .read(collectRepositoryProvider)
        .addForum(name, fid: page.fid > 0 ? page.fid : null);
  }

  @override
  Future<void> setForumEnabled(String fname, bool enabled) =>
      ref.read(collectRepositoryProvider).setForumEnabled(fname, enabled);

  @override
  Future<void> removeForum(String fname) =>
      ref.read(collectRepositoryProvider).removeForum(fname);
}

/// 采集运行态（采集中心 UI 主数据源）。
final NotifierProvider<CollectRunNotifier, CollectRunState>
    collectRunStateProvider =
    NotifierProvider<CollectRunNotifier, CollectRunState>(CollectRunNotifier.new);

/// 控制入口（按钮/开关/添加吧对话框消费）。
final Provider<CollectController> collectControllerProvider =
    Provider<CollectController>((Ref ref) => ref.watch(collectRunStateProvider.notifier));
