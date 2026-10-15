/// 采集运行态模型（M2-① UI ↔ 服务共用契约）。
///
/// **契约文件**：字段/枚举由主控冻结；采集服务（lib/collector/ 实现侧）只允许
/// **增量添加**字段（带默认值），不得删改既有成员——采集中心 UI 按本契约消费。
/// 全部为纯 Dart 不可变对象，可跨 isolate 传递、可在 widget 测试中直接构造。
library;

/// 全局运行相位。
enum CollectPhase {
  /// 空闲（未运行）。
  idle,

  /// 运行中。
  running,

  /// 取消请求已发出、等待各吧分支收尾（水位不推进）。
  stopping,
}

/// 单吧运行子状态（§8.12 状态机的运行态投影；持久态在 collection_state.last_status）。
enum ForumStatus {
  /// 排队等待并发闸门。
  queued,

  /// ① 拉帖列表（get_threads 翻页中）。
  listing,

  /// ② 解析楼层 + 分类（get_posts → Isolate 解析中）。
  parsing,

  /// ③ 入库（drift 事务提交中）。
  ingesting,

  /// 本轮成功完成。
  done,

  /// 冷却中（429/110xxx/连续失败，§8.11：48h 或 48m 级倒计时）。
  cooldown,

  /// 失败终止（重试耗尽）。
  failed,

  /// 用户取消。
  canceled,
}

/// 四步流水（设计稿 06 采集进度页 steps：①拉帖列表 ②解析楼层+分类 ③入库/重建FTS ④完成汇总）。
enum CollectStep {
  list,
  parse,
  ingest,
  summary;

  /// ①②③④ 展示序号。
  int get number => index + 1;
}

/// 日志级别（设计稿 logbox 语义色：默认正文 / .ok 绿 / .warn 红 / .acc 强调）。
enum CollectLogLevel { info, ok, warn, accent }

/// 本轮累计计数（设计稿 stat-grid 六格：帖/楼层/书目/跳过重复/丢弃闲聊/排雷帖）。
class CollectStats {
  const CollectStats({
    this.threadsAdded = 0,
    this.floorsAdded = 0,
    this.entriesAdded = 0,
    this.skippedDup = 0,
    this.discardedChat = 0,
    this.mineThreads = 0,
  });

  const CollectStats.zero() : this();

  /// 新入库帖数（stat「+N 帖」，绿色）。
  final int threadsAdded;

  /// 新入库楼层数。
  final int floorsAdded;

  /// 新入库书目条目数。
  final int entriesAdded;

  /// 去重跳过数（灰色）。
  final int skippedDup;

  /// 日常闲聊丢弃数（灰色，仅计数不入库）。
  final int discardedChat;

  /// 排雷帖入库数。
  final int mineThreads;

  CollectStats operator +(CollectStats o) => CollectStats(
    threadsAdded: threadsAdded + o.threadsAdded,
    floorsAdded: floorsAdded + o.floorsAdded,
    entriesAdded: entriesAdded + o.entriesAdded,
    skippedDup: skippedDup + o.skippedDup,
    discardedChat: discardedChat + o.discardedChat,
    mineThreads: mineThreads + o.mineThreads,
  );

  CollectStats copyWith({
    int? threadsAdded,
    int? floorsAdded,
    int? entriesAdded,
    int? skippedDup,
    int? discardedChat,
    int? mineThreads,
  }) => CollectStats(
    threadsAdded: threadsAdded ?? this.threadsAdded,
    floorsAdded: floorsAdded ?? this.floorsAdded,
    entriesAdded: entriesAdded ?? this.entriesAdded,
    skippedDup: skippedDup ?? this.skippedDup,
    discardedChat: discardedChat ?? this.discardedChat,
    mineThreads: mineThreads ?? this.mineThreads,
  );

  @override
  bool operator ==(Object other) =>
      other is CollectStats &&
      other.threadsAdded == threadsAdded &&
      other.floorsAdded == floorsAdded &&
      other.entriesAdded == entriesAdded &&
      other.skippedDup == skippedDup &&
      other.discardedChat == discardedChat &&
      other.mineThreads == mineThreads;

  @override
  int get hashCode => Object.hash(
    threadsAdded, floorsAdded, entriesAdded, skippedDup, discardedChat, mineThreads,
  );
}

/// 单吧运行态（并发吧子进度；设计稿：主卡「yy小说吧 · 步骤① pn 12/18 · 并发 2」+
/// 宽屏 dash-forums 每吧一条 pbar，429 冷却红条不阻塞其余吧）。
class ForumRunState {
  const ForumRunState({
    required this.fname,
    this.fid,
    this.status = ForumStatus.queued,
    this.step = CollectStep.list,
    this.stepProgress = 0,
    this.stepDetail = '',
    this.overallProgress = 0,
    this.watermarkFrom = 0,
    this.watermarkTarget = 0,
    this.cooldownUntil,
    this.error,
    this.stats = const CollectStats.zero(),
  });

  /// 吧名。
  final String fname;

  /// 贴吧 fid（验证吧存在时获得，可空）。
  final int? fid;

  final ForumStatus status;

  /// 当前所处流水步骤（①..④）。
  final CollectStep step;

  /// 当前步骤内进度 0..1（①=pn/总页，②=tid i/N，③=事务批次，④=1）。
  final double stepProgress;

  /// 步骤细节文案（设计稿 small 行）：如 'pn 12/18'、'tid 7/37'、'冷却至 09:58'。
  final String stepDetail;

  /// 该吧整体进度 0..1（四步加权，pbar 宽度）。
  final double overallProgress;

  /// 开跑前水位（epoch 秒；0=冷启动）。
  final int watermarkFrom;

  /// 本轮预计推进到的水位（已见最大 create_time；成功批次提交后才落库，§8.7）。
  final int watermarkTarget;

  /// 冷却截止（status=cooldown 时展示倒计时）。
  final DateTime? cooldownUntil;

  /// 失败原因（status=failed 时展示）。
  final String? error;

  /// 该吧本轮计数。
  final CollectStats stats;

  ForumRunState copyWith({
    ForumStatus? status,
    CollectStep? step,
    double? stepProgress,
    String? stepDetail,
    double? overallProgress,
    int? watermarkFrom,
    int? watermarkTarget,
    DateTime? cooldownUntil,
    String? error,
    CollectStats? stats,
    bool clearCooldown = false,
    bool clearError = false,
  }) => ForumRunState(
    fname: fname,
    fid: fid,
    status: status ?? this.status,
    step: step ?? this.step,
    stepProgress: stepProgress ?? this.stepProgress,
    stepDetail: stepDetail ?? this.stepDetail,
    overallProgress: overallProgress ?? this.overallProgress,
    watermarkFrom: watermarkFrom ?? this.watermarkFrom,
    watermarkTarget: watermarkTarget ?? this.watermarkTarget,
    cooldownUntil: clearCooldown ? null : (cooldownUntil ?? this.cooldownUntil),
    error: clearError ? null : (error ?? this.error),
    stats: stats ?? this.stats,
  );
}

/// 实时日志一条（设计稿 logbox 行：`08:12:03 分类 tid=11097754039 → 扫书 (书名数=3≥3)`；
/// 宽屏 dtable 五列：时间/来源/事件/详情/状态）。
class CollectLogEntry {
  const CollectLogEntry({
    required this.time,
    required this.fname,
    required this.event,
    required this.detail,
    this.level = CollectLogLevel.info,
  });

  final DateTime time;

  /// 来源吧名；全局事件用 '全局'。
  final String fname;

  /// 事件类型：开始/拉列表/分类/入库/频控/完成/失败/取消。
  final String event;

  /// 详情文案（含 tid、命中规则、pn 等）。
  final String detail;

  final CollectLogLevel level;
}

/// 一次采集运行的完整快照（Notifier 状态；UI 只读消费）。
class CollectRunState {
  const CollectRunState({
    this.phase = CollectPhase.idle,
    this.startedAt,
    this.forums = const <ForumRunState>[],
    this.logs = const <CollectLogEntry>[],
    this.totals = const CollectStats.zero(),
    this.overallProgress = 0,
    this.globalStep,
    this.banner,
    this.finishedAt,
  });

  const CollectRunState.idle() : this();

  final CollectPhase phase;

  /// 本轮开始时间（logbox 首行「开始采集 · 并发=2 · 匿名 · 仅WiFi」同源）。
  final DateTime? startedAt;

  /// 各吧运行态（并发分支，顺序 = 启动顺序）。
  final List<ForumRunState> forums;

  /// 实时日志（**新在前**，滚动保留最近 200 条 = collection_logs 口径）。
  final List<CollectLogEntry> logs;

  /// 全局累计（stat-grid 六格数据源）。
  final CollectStats totals;

  /// 总进度 0..1（进度环 data-ring；各吧 overallProgress 的均值）。
  final double overallProgress;

  /// 全局步骤展示（dash-ring 徽标「步骤 ②/④」）：取未完成吧的最小 step；
  /// 全部完成 = summary；idle = null。
  final CollectStep? globalStep;

  /// 降级横幅（§8.12：如「贴吧接口似乎已变更」「今日请求预算已用完」）；null = 无。
  final String? banner;

  /// 本轮结束时间（phase 回到 idle 后保留最后一轮汇总展示用）。
  final DateTime? finishedAt;

  bool get isRunning => phase == CollectPhase.running || phase == CollectPhase.stopping;

  CollectRunState copyWith({
    CollectPhase? phase,
    DateTime? startedAt,
    List<ForumRunState>? forums,
    List<CollectLogEntry>? logs,
    CollectStats? totals,
    double? overallProgress,
    CollectStep? globalStep,
    String? banner,
    DateTime? finishedAt,
    bool clearBanner = false,
    bool clearGlobalStep = false,
  }) => CollectRunState(
    phase: phase ?? this.phase,
    startedAt: startedAt ?? this.startedAt,
    forums: forums ?? this.forums,
    logs: logs ?? this.logs,
    totals: totals ?? this.totals,
    overallProgress: overallProgress ?? this.overallProgress,
    globalStep: clearGlobalStep ? null : (globalStep ?? this.globalStep),
    banner: clearBanner ? null : (banner ?? this.banner),
    finishedAt: finishedAt ?? this.finishedAt,
  );
}
