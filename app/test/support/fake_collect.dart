import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:booksift/collector/collect_controller.dart';
import 'package:booksift/collector/collect_state.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/collect_repository_providers.dart';
import 'package:booksift/features/collect/collect_settings.dart';
import 'package:booksift/features/collect/debug_demo.dart';

// 采集中心 widget 测试夹具（TESTING.md §3.1：testWidgets 体内零真实 IO/DB/网络/isolate）。
//
// 本文件只提供：假 Notifier（脚本化运行态 + 调用记录）、演示快照转发、
// 空闲态数据（collection_state / collection_logs 形状的纯内存行）与 override 助手。
// **禁止修改 harness.dart**；本文件与其并列、经 testApp(extraOverrides:) 注入。

/// 假运行态 Notifier：build 返回脚本化 [initial]，记录全部控制入口调用。
/// 零 Timer / 零 IO —— 方法体只有计数与微任务级 async。
class FakeCollectRunNotifier extends CollectRunNotifier {
  FakeCollectRunNotifier({this.initial = const CollectRunState.idle(), this.addForumError});

  final CollectRunState initial;

  /// 非空时 addForum 抛出该异常（对话框错误路径用例）。
  final CollectAddForumException? addForumError;

  int startAllCalls = 0;
  int cancelCalls = 0;
  final List<String> addedForums = <String>[];
  final List<(String, bool)> enabledCalls = <(String, bool)>[];
  final List<String> removedForums = <String>[];

  @override
  CollectRunState build() => initial;

  @override
  Future<void> startAll() async {
    startAllCalls++;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
  }

  @override
  Future<void> addForum(String fname) async {
    final CollectAddForumException? error = addForumError;
    if (error != null) {
      throw error;
    }
    addedForums.add(fname);
  }

  @override
  Future<void> setForumEnabled(String fname, bool enabled) async {
    enabledCalls.add((fname, enabled));
  }

  @override
  Future<void> removeForum(String fname) async {
    removedForums.add(fname);
  }
}

/// 设计稿 06 屏演示快照（lib/features/collect/debug_demo.dart 单一出处；
/// 页面内长按「匿名模式」徽标注入的即是同一份数据）。
CollectRunState demoRunState({DateTime? now}) => debugDemoRunState(now: now);

int epochOf(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

/// collection_state 行构造助手（drift 数据类全字段显式填充）。
CollectionStateEntry forumEntry({
  required String fname,
  int? fid,
  bool enabled = true,
  int lastThreadTime = 0,
  int lastTid = 0,
  DateTime? lastRunAt,
  String lastStatus = 'never',
  String? lastError,
  int consecutiveFailures = 0,
  DateTime? cooldownUntil,
  int newSinceVisit = 0,
  int totalThreads = 0,
  int totalFloors = 0,
}) {
  return CollectionStateEntry(
    fname: fname,
    fid: fid,
    enabled: enabled,
    lastThreadTime: lastThreadTime,
    lastTid: lastTid,
    lastRunAt: lastRunAt,
    lastStatus: lastStatus,
    lastError: lastError,
    consecutiveFailures: consecutiveFailures,
    cooldownUntil: cooldownUntil,
    newSinceVisit: newSinceVisit,
    totalThreads: totalThreads,
    totalFloors: totalFloors,
  );
}

/// 默认两吧（§8.7 kDefaultForums 形状）：yy小说吧 = 上次成功 + 水位；
/// 哀伤雪刃 = rate_limited + 48m 冷却倒计时（danger 色用例）。
List<CollectionStateEntry> demoForums({DateTime? now}) {
  final DateTime base = now ?? DateTime.now();
  return <CollectionStateEntry>[
    forumEntry(
      fname: 'yy小说吧',
      enabled: true,
      lastThreadTime: epochOf(DateTime(2026, 10, 11, 18, 32)),
      lastTid: 11097754039,
      lastRunAt: base.subtract(const Duration(hours: 2)),
      lastStatus: 'ok',
      totalThreads: 37,
      totalFloors: 212,
    ),
    forumEntry(
      fname: '哀伤雪刃',
      enabled: true,
      lastThreadTime: epochOf(DateTime(2026, 10, 10, 9, 15)),
      lastRunAt: base.subtract(const Duration(days: 1)),
      lastStatus: 'rate_limited',
      cooldownUntil: base.add(const Duration(minutes: 48)),
      totalThreads: 12,
      totalFloors: 40,
    ),
  ];
}

/// 最近日志（§5.9 '10-12 08:00 yy小说吧 +37/12楼' / '10-11 20:00 哀伤雪刃 失败:429'）。
List<CollectionLog> demoLogs() {
  return <CollectionLog>[
    CollectionLog(
      id: 2,
      fname: 'yy小说吧',
      runAt: DateTime(2026, 10, 12, 8, 0),
      status: 'ok',
      threadsAdded: 37,
      floorsAdded: 12,
      entriesAdded: 9,
      skippedDup: 3,
    ),
    CollectionLog(
      id: 1,
      fname: '哀伤雪刃',
      runAt: DateTime(2026, 10, 11, 20, 0),
      status: 'api_error',
      threadsAdded: 0,
      floorsAdded: 0,
      entriesAdded: 0,
      skippedDup: 0,
      detail: '429',
    ),
  ];
}

/// 采集中心全套 override（运行态假 Notifier + 空闲态数据 + 设置）。
/// 配合 harness.testApp(extraOverrides:) 使用。
List<Override> collectTestOverrides({
  required FakeCollectRunNotifier notifier,
  List<CollectionStateEntry>? forums,
  List<CollectionLog>? logs,
  CollectSettings settings = const CollectSettings(),
}) {
  final List<CollectionStateEntry> forumRows = forums ?? demoForums();
  final List<CollectionLog> logRows = logs ?? demoLogs();
  return <Override>[
    collectRunStateProvider.overrideWith(() => notifier),
    collectForumsProvider.overrideWith((Ref ref) async => forumRows),
    recentCollectLogsProvider.overrideWith((Ref ref) async => logRows),
    collectSettingsProvider.overrideWith((Ref ref) async => settings),
  ];
}
