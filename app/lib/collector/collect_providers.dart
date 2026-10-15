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

import 'scheduler.dart';
import 'tieba_api.dart';
import 'worker.dart';

/// 时钟（测试注入假时钟免真等）。
final Provider<CollectClock> collectClockProvider =
    Provider<CollectClock>((Ref ref) => const SystemClock());

/// 睡眠器（测试注入「推进假时钟立即返回」实现）。
final Provider<Sleeper> collectSleeperProvider =
    Provider<Sleeper>((Ref ref) => (Duration d) => Future<void>.delayed(d));

/// WiFi 闸门（connectivity_plus 未接入 → 恒 true，见 worker.dart NetworkGate 注释）。
final Provider<NetworkGate> networkGateProvider =
    Provider<NetworkGate>((Ref ref) => const AlwaysAllowNetworkGate());

/// 生产贴吧客户端（app-proto 通道；内部节流关闭，间隔由全局限速器统一核算）。
final Provider<TiebaApi> tiebaApiProvider = Provider<TiebaApi>((Ref ref) {
  final ProtoTiebaApi api = ProtoTiebaApi();
  ref.onDispose(api.close);
  return api;
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
