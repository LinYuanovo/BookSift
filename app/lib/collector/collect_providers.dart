/// 采集层生产 provider 接线（Flutter / riverpod 侧）。
///
/// **从 `collect_service.dart` 拆出的唯一目的**：让 [CollectService] 本体保持
/// 纯 Dart（零 `package:flutter` 依赖），从而能被 headless CLI 直接组装复用
/// （`dart run bin/booksift.dart collect`，见 `lib/headless/collect.dart`），
/// 不必为脱 GUI 而复制编排逻辑。
///
/// UI 仍只消费 `collect_controller.dart` 的两个契约 provider；下列 provider
/// 供测试 `override` 注入假实现（见 `test/collector/controller_test.dart`）。
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bduss.dart';
import 'network_gate_flutter.dart';
import 'scheduler.dart';
import 'tieba_account.dart';
import 'tieba_api.dart';
import 'worker.dart';

/// 时钟（测试注入假时钟免真等）。
final Provider<CollectClock> collectClockProvider =
    Provider<CollectClock>((Ref ref) => const SystemClock());

/// 睡眠器（测试注入「推进假时钟立即返回」实现）。
final Provider<Sleeper> collectSleeperProvider =
    Provider<Sleeper>((Ref ref) => (Duration d) => Future<void>.delayed(d));

/// Wi-Fi 闸门（各桌面/移动 runner 检查当前默认网络；不可用时按非 Wi-Fi 处理）。
final Provider<NetworkGate> networkGateProvider =
    Provider<NetworkGate>((Ref ref) => const PlatformNetworkGate());

/// 生产贴吧客户端（app-proto 通道；内部节流关闭，间隔由全局限速器统一核算）。
///
/// BDUSS（需求 8/5）：watch [effectiveBdussProvider] 的**值**（select）—— 导入/
/// 清除/失效标记变化 → 本 provider 重建（旧客户端 dispose）→ 后续请求自动换
/// 账号身份；失效降级后 effective 为 null，本 provider 自动回匿名客户端；匿名
/// （null）档行为不变。select 过滤掉启动时 loading→data(null) 的状态跳变，
/// 避免刚建好客户端就因异步落定被无谓重建。
final Provider<TiebaApi> tiebaApiProvider = Provider<TiebaApi>((Ref ref) {
  final String? bduss =
      ref.watch(effectiveBdussProvider.select((AsyncValue<String?> s) => s.value));
  final ProtoTiebaApi api = ProtoTiebaApi(bduss: bduss);
  ref.onDispose(api.close);
  return api;
});

/// 账号有效性探测（设置页「BDUSS 测试」按钮消费；initNickname app-form 通道，
/// 测试用脚本化 dio override，零真实网络）。
final Provider<TiebaAccountProbe> tiebaAccountProbeProvider =
    Provider<TiebaAccountProbe>((Ref ref) {
  final TiebaAccountProbe probe = TiebaAccountProbe();
  ref.onDispose(probe.close);
  return probe;
});

/// v3 书名词典行（assets/dict/book_dict.txt，主 isolate 读字符串再传入 worker
/// isolate——任务书要求）。词典缺失 → 空表 → BookDict.empty → v3 退化 v2。
final FutureProvider<List<String>> bookDictLinesProvider =
    FutureProvider<List<String>>((Ref ref) async {
  try {
    final String text = await rootBundle.loadString('assets/dict/book_dict.txt');
    return const LineSplitter().convert(text);
  } catch (e) {
    return const <String>[];
  }
});

/// 每轮一个长驻后台 worker isolate（§8.8 CPU 下放；BookDict 只建一次）。
final Provider<PostWorkerFactory> postWorkerFactoryProvider =
    Provider<PostWorkerFactory>((Ref ref) => () async {
          final List<String> lines = await ref.read(bookDictLinesProvider.future);
          return IsolatePostWorker.spawn(dictLines: lines);
        });
