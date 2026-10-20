# BookSift Headless 层 —— 日志 / API / CLI 交接文档

> **面向**：接手 headless 层的开发者与 agent。
> **配套**：根 `README.md`「Headless CLI / API」段（用法速查）、`AGENTS.md §7`（工作约定）、
> `test/TESTING.md`（测试纪律）。本文是**规格与边界**，不是使用手册。
> **口径**：文中每条判断都给到 `文件:行号`，可直接核对。

---

## 0. 一页速览

| 交付 | 落点 | 规模 | 状态 |
|---|---|---|---|
| 返回日志 | `lib/headless/logs.dart` | 246 行 | 完成，12 用例 |
| 门面 API | `lib/booksift.dart` + `lib/headless/{env,query,collect,seed,network_gate}.dart` | 纯 Dart 门面 | 完成，契约测试覆盖 |
| CLI | `bin/booksift.dart` | 13 子命令（含 `facets` / `hot` / `random` / `timeline` / `rank` / `show book|post`） | 完成，参数、成功 JSON 与失败路径有自动化契约测试 |

三者共享同一条**纯 Dart 边界**：不 import `package:flutter`，故 `dart run` / `dart build cli` 可脱 GUI 执行。

---

## 1. 架构与依赖边界

```
bin/booksift.dart                    CLI（args CommandRunner，13 子命令）
        │
lib/booksift.dart                    barrel —— 只导出纯 Dart 库
        │
lib/headless/                        适配层（为脱 GUI 而写）
  logs.dart    结构化日志：RunEvent / RunLog / 4 种 sink
  env.dart     环境：openDb / loadDictLines / doctor / tableRowCounts
  query.dart   检索门面：BookQueryApi / DbOverview / JSON 映射
  collect.dart 采集驱动：HeadlessCollect.plan|run / CollectPlan / CollectRunResult
  seed.dart    种子包体检：SeedInspector / SeedPackReport
  network_gate.dart Windows CLI 默认路由 Wi-Fi 探测
        │
lib/collector/*  lib/data/repo/{queries,collect_repository}.dart  lib/classify/*
        │                            业务实现（本体即纯 Dart，未重写一行）
lib/data/db/app_database.dart        drift schema

  ✗ 边界之外（直接或间接 import package:flutter，headless 一律不可引用）：
    features/**  theme/**  core/fonts/**  data/seed_import.dart
    data/repo/database_provider.dart  collector/collect_controller.dart
    *_providers.dart（riverpod 装配）
```

### 1.1 为什么不用重写编排逻辑

`CollectService`（39 KB 采集编排）、`Queries`（1400 行检索）、`CollectRepository`
三个类**本体原本就是纯 Dart 且全依赖注入**；flutter 触点只有两处，且都在类外的文件尾部：

| 原触点 | 位置 | 处理 |
|---|---|---|
| riverpod provider 装配块 | 三个实现文件的尾部 | 拆到 `*_providers.dart` |
| `rootBundle.loadString` 读词典 | 原 `collect_service.dart` provider 块内 | 随装配块一起移入 `collect_providers.dart`；headless 侧改用 `HeadlessEnv.loadDictLines`（`dart:io`） |

拆出的三个装配文件（新增，共 103 行）：

| 文件 | 行数 | 内容 |
|---|---|---|
| `lib/collector/collect_providers.dart` | 57 | clock / sleeper / networkGate / tiebaApi / bookDictLines / postWorkerFactory 六个 provider |
| `lib/data/repo/collect_repository_providers.dart` | 28 | collectRepository / collectForums / recentCollectLogs |
| `lib/data/repo/queries_providers.dart` | 18 | queriesProvider |

**代价**：14 个 UI/测试文件各补 import（Dart import 不传递，明细见 §10）。机械改动，由既有测试兜底。

---

## 2. 返回日志（`lib/headless/logs.dart`）

### 2.1 事件模型 —— 字段契约

`RunEvent`（`logs.dart:44`），`toJson()` 在 `logs.dart:79`：

| 字段 | 类型 | 含义 | 备注 |
|---|---|---|---|
| `run` | string | 运行 ID | 同进程内所有事件共享 |
| `seq` | int | 进程内单调序号，从 1 起 | **乱序/丢行判据** |
| `ts` | string | UTC ISO8601 | `toUtc().toIso8601String()`。**小数秒宽度可变**：Dart 截去尾零，实测 3~6 位（真实时钟 `.783727Z`，整毫秒 `.654Z`）——解析时不要假定固定宽度 |
| `level` | string | `info`/`ok`/`warn`/`error` | 走 `RunLevel.wire`（`logs.dart:27`），**不用 `enum.name`**，避免重命名破坏解析 |
| `scope` | string | 来源域 | 吧名 / `global` / 子命令名 |
| `event` | string | 事件类型 | 开始/拉列表/分类/入库/频控/进度/汇总/完成/失败/取消… |
| `detail` | string | 人读详情 | **空则整个键省略** |
| `data` | object | 机读附加字段 | **空则整个键省略** |

一行一事件（JSONL），`toJsonLine()` 保证不含裸换行（`logs_test.dart` 有断言）。

### 2.2 四种 sink（`RunLogSink`，`logs.dart:105`）

| sink | 行 | 用途 |
|---|---|---|
| `StdoutRunLogSink` | 111 | 文本模式的人读日志（`json:false`） |
| `StderrRunLogSink` | 126 | `--json` 模式：诊断走 stderr，让 stdout 只剩结果 |
| `FileRunLogSink` | 140 | JSONL 落盘；`open()` 自动建目录，追加写；**必须 `await close()`** 否则丢尾行（有回归用例） |
| `MemoryRunLogSink` | 164 | 测试与编程式消费，零 IO |

### 2.3 run_id

`RunLog.newRunId()`（`logs.dart:193`）= `yyyyMMdd-HHmmss-<pid>`，本地时区。
同秒多进程不撞；日志文件名即 run_id。

### 2.4 与 UI 日志的分工（重要）

| | 载体 | 上限 | 用途 |
|---|---|---|---|
| UI 快照 | `CollectRunState.logs` | **200 条**（内存裁剪在 `collect_service.dart:867`） | 界面 logbox 展示 |
| 持久汇总 | `collection_logs` 表 | **每轮一行，且同样只留 200 行**（`collect_repository.dart:18` 的 `kCollectionLogLimit`，滚动裁剪在 `:69`） | App 内「最近日志」列表；CLI `logs` 子命令读的是这个 |
| 逐条事件 | `CollectService(onLog:)` → `RunLog` | **不裁剪** | 落盘复盘、agent 机读 |

> 注意第二行：`collection_logs` 既不是逐条事件、也会被 200 行滚动裁掉。要完整复盘一轮采集，
> 只能靠第三行（`logs/<run_id>.jsonl`）。CLI 的 `logs` 子命令读的是第二行——这也是 §8-A3
> 提议补 JSONL 回放命令的原因。

`onLog` 是本次为 headless 加的**加法式**钩子：构造函数参数 `collect_service.dart:130`、
字段声明 `:159`、分发点 `:870`（在 200 条裁剪之后调用，故不受裁剪影响）。
默认 `null` → UI 路径零开销，既有调用方无需改动。

`RunLog.emitCollect()`（`logs.dart:232`）负责桥接：`CollectLogLevel` → `RunLevel`
（`accent` 是 UI 强调色、不代表严重度，归 `info`），`fname == '全局'` → `scope: 'global'`，
并打 `data.src = 'collect'` 以区分 CLI 自身事件。

### 2.5 落盘位置

`--log-dir`（默认 `logs/`，相对 CWD；从 `app/` 运行即 `app/logs/`），文件名 `<run_id>.jsonl`。
已加入根 `.gitignore`（`app/logs/`）。

---

## 3. 门面 API

### 3.1 barrel 规则（`lib/booksift.dart`）

导出 4 组：`headless/*`、`collector/{collect_service,collect_state,ingest,scheduler,tieba_api,watermark,worker}`、
`classify/classifier.dart`、`data/bduss_format.dart`（BDUSS 解析/掩码，纯 Dart）、`data/db/app_database.dart`、
`data/repo/{collect_repository,queries}`、`core/constants.dart`。

> **加导出前必须确认目标库 import 里没有 `package:flutter`**——漏一个，`dart run` 会因解析不到
> `package:flutter` 直接失败（不是运行时报错，是加载期）。riverpod 装配一律放 `*_providers.dart`，
> 不进 barrel。

### 3.2 `headless/env.dart`

| 成员 | 行 | 说明 |
|---|---|---|
| `HeadlessEnv.openDb(path)` | 76 | `AppDatabase(NativeDatabase(File(path)))`；不依赖 path_provider |
| `HeadlessEnv.openMemoryDb()` | 80 | 内存库，零 IO |
| `HeadlessEnv.sqliteHint` | 71 | sqlite3 原生库缺失时的统一修复提示 |
| `HeadlessEnv.loadDictLines(path)` | 83 | 剔空行；**文件缺失返回空表而非抛异常** → `BookDict.empty` → v3 退化 v2 |
| `HeadlessEnv.doctor({dbPath,dictPath,seedDir})` | 96 | 五项检查，见下 |
| `HeadlessEnv.tableRowCounts(db)` | 275 | 各表行数 |
| `DoctorCheck` / `DoctorReport` | 19 / 52 | `name/ok/detail/hint/data`；`report.ok` = 全部通过 |

**doctor 五项**：`runtime`（OS/Dart/pid/cwd/相关环境变量）、`sqlite3`（内存库 `SELECT 1`）、
`db`（存在性 → 可开 → `PRAGMA user_version` + 表行数）、`dict`（行数 + `BookDict` 可锚定名数）、
`seed`（manifest + zip 就位）。

`db` 项同时检查应用表与 FTS 同步触发器完整；缺 `book_entries_ai/ad/au` 或 `floors_ai/ad/au`
都会判定 schema 未就绪，避免“表在但新增内容永不入 FTS”的假健康。

两条设计约束（都有测试兜底）：

1. **doctor 只读**：库不存在时报 FAIL，**绝不顺手建库文件**——否则「库不存在」这个结论会被自己的副作用掩盖。
2. **`tableRowCounts` 排除 FTS5 影子表**：`book_fts_config` 恒有 1 行，混进来会让「新库应全为 0」失真。
   识别方式是通用的（`sqlite_master.sql` 含 `CREATE VIRTUAL TABLE` 者为基名，`<基名>_*` 即影子表），
   **不硬编码表名**；虚拟表本身（`book_fts`/`floor_fts`）保留，因为「FTS 是否建好/是否为空」正是搜索排错要看的。

### 3.3 `headless/query.dart`

| 成员 | 行 | 说明 |
|---|---|---|
| `BookQueryApi(db)` | 116 | 内部持有 `Queries` + `CollectRepository` |
| `.queries` / `.repo` | 126 / 129 | **直接暴露底层实现**，门面未覆盖的方法可经此调用，避免逐条转发造成重复 |
| `search / suggest / dimensionCounts / searchDimensions / categoryPreview / rank / hotBooks / randomBooks / timeline / dataCutoff / bookDetail / bookEntries / postDetail` | 134–184 | 转发到 `Queries` |
| `overview()` | 177 | `DbOverview`：`userVersion` + 表行数 + 关注吧水位 + settings |
| `recentLogs({limit})` | 192 | `collection_logs`，新在前 |
| `ForumWatermark` / `DbOverview` | 20 / 87 | 机读投影，各有 `toJson()` |

文件尾部一组**顶层 JSON 映射函数**：`dimCountJson` / `categoryCountsJson` / `groupHitJson` /
`searchOutcomeJson` / `entryRowJson` / `rankRowJson` / `hotBookJson` / `collectionLogJson`。
`entryRowJson` 投影条目展示、分类、分页溯源字段及 `recommendFlag`；`floorSeq` / `floorText` /
`postTitle` 用于保留楼层定位、原文预览和原帖语义，值为空时也保留对应 JSON 键。

> 为什么放在这里而不是 `queries.dart`：那些数据类是 **UI 视图模型**，本身没有序列化能力；
> 给它们加 `toJson` 要改 1400 行的大文件并牵动 UI 侧。补在 headless 层，改动面最小。

### 3.4 `headless/collect.dart`

| 成员 | 行 | 说明 |
|---|---|---|
| `HeadlessCollect.plan({db, budgetLimit, bduss?})` | 163 | **零请求**，只读 db；`bduss` 只影响档位展示（间隔/并发上限） |
| `HeadlessCollect.run({db, log, dictLines, networkGate, api?, budgetLimit, bduss?, useIsolateWorker, clock?, sleeper?})` | 208 | 真跑；网络闸门由调用方显式提供，返回 `CollectRunResult` |
| `CollectPlan` | 24 | 吧水位 / 可跑吧 / 冷却吧 / 预算 / 并发 / 仅WiFi / 限速区间 / 账号档（`accountTier`） |
| `CollectRunSummary` | 71 | `CollectRunState` 的机读投影 |
| `CollectRunResult` | 144 | `state` + `summary` + `logCount`（逐条日志真实计数） |

`plan` 的吧分类口径：`!enabled` → 既不进 `enabledForums` 也不进 `coolingForums`（**停用 ≠ 冷却**，
混在一起会误导排错），但仍出现在 `forums` 全量水位里。冷却判据 = `cooldownUntil != null && isAfter(now)`。

`run` 的三条接线约定：

- **日志**：`onLog` → `RunLog.emitCollect`（逐条不裁剪）；`onState` → 只在
  「相位/全局步骤/总进度/各吧 status+step」组成的签名串变化时发一条 `进度` 事件，**避免逐快照刷屏**。
- **worker**：`useIsolateWorker: true`（默认）走 `IsolatePostWorker.spawn`；`false` 走同 isolate 的
  `LocalPostWorker`（栈更直观，排错分类问题时更好用）。词典只建一次 `BookDict`。
- **资源所有权**：只有 `run()` 自己 new 的 `ProtoTiebaApi` 才由它 `close()`；
  调用方注入的 `api` **不会被关闭**（有专门用例）。

> **本层不做网络门控**：`plan` 零请求、`run` 必发请求。「是否允许发请求」由调用方把关（见 §4.4）。

### 3.5 `headless/seed.dart`

| 成员 | 行 | 说明 |
|---|---|---|
| `SeedInspector.inspect(dir, {verifyHash, onProgress})` | 87 | 解析 manifest + 流式 sha256 |
| `SeedPackReport` | 15 | `zipPresent` / `sizeMatches` / `shaMatches`（**`bool?`：null = 未校验，不谎报 true**）/ `ok` |
| `SeedInspectException` | 146 | manifest 缺失、`compression.zip_file` 缺失 |

sha256 走 `sha256.bind(file.openRead()).first`，流式、不整体读入内存。

> **只校验，不导入**。导入在 `data/seed_import.dart`，它经 `AssetBundle` 读资产、依赖 flutter，
> 无法在纯 Dart 下执行。把它改成可注入的文件源是另一件事，本层不越界。

---

## 4. CLI（`bin/booksift.dart`）

### 4.1 全局选项（`BookSiftRunner`，`:80`）

| 选项 | 默认 | 说明 |
|---|---|---|
| `--json` | off | 结果 JSON → stdout，日志 JSONL → stderr |
| `--db <path>` | `~/Documents/app.sqlite`（**推断值**） | SQLite 库路径 |
| `--dict <path>` | `assets/dict/book_dict.txt` | v3 书名词典 |
| `--log-dir <dir>` | `logs` | JSONL 落盘目录，不存在则创建 |
| `--[no-]log-file` | on | 是否落盘 |
| `--version` | off | 输出 CLI 版本，不读取数据库 |

全局选项须写在子命令**之前**：`booksift --json --db X query 剑来`。

### 4.2 子命令矩阵

| 命令 | 类:行 | 专属 flag | 网络 | 需 db |
|---|---|---|---|---|
| `doctor` | `bin/booksift.dart:419` | `--seed-dir` | 零 | 否 |
| `stats` | `bin/booksift.dart:484` | — | 零 | **是** |
| `query <词…>` | `bin/booksift.dart:564` | `--limit --offset --year --month --ten-day --channel --category --sort --suggest` | 零 | **是** |
| `facets` | `bin/booksift.dart` | `--year --month --ten-day --channel --category` | 零 | **是** |
| `hot` | `bin/booksift.dart:723` | `--limit` | 零 | **是** |
| `random` | `bin/booksift.dart:762` | `--count` | 零 | **是** |
| `timeline` | `bin/booksift.dart:796` | `--limit --offset` | 零 | **是** |
| `rank` | `bin/booksift.dart:841` | `--window --kind --limit` | 零 | **是** |
| `show book <gid>` | `bin/booksift.dart:933` | `--filter --sort --limit --offset` | 零 | **是** |
| `show post <pid>` | `bin/booksift.dart:1022` | — | 零 | **是** |
| `classify` | `bin/booksift.dart:1080` | `--title --floor`(可重复) `--text-file --no-dict` | 零 | 否 |
| `logs` | `bin/booksift.dart:1204` | 汇总：`--limit`；回放：`--run --file --scope --level --event --limit` | 零 | 汇总需库；回放不需库 |
| `seed` | `bin/booksift.dart:1392` | `--dir --[no-]verify` | 零 | 否 |
| `collect` | `bin/booksift.dart:1466` | `--net --budget --bduss（或环境变量 BOOKSIFT_BDUSS）--[no-]isolate --seed-forums --forum（可重复）` | **双闸** | **计划只读；`--seed-forums` / 真采集可写** |

多词查询：位置参数会被 `join(' ')` 成一个查询串（`query 剑来 番外` → `"剑来 番外"`，再按空格分词 AND）。

### 4.3 输出分流与退出码

| 模式 | stdout | stderr |
|---|---|---|
| 默认 | 人读日志 + 人读结果 | — |
| `--json` | **只有结果 JSON**（成功结果或 `{"error":...}`） | JSONL 日志 |

退出码（`ExitCode`，`:35`）：`0` 成功 / `1` 采集或运行失败 / `2` 参数错误 / `3` 网络闸门拦截。
可预期失败抛 `CliError`（`:43`，只打消息 + hint，不打栈）；未预期异常打栈并返回 1。

`--json` 下，参数错误、数据库/种子包读取失败和未预期异常也会写到 stdout 的单个错误对象：
`{"error":{"type":"usage|runtime|gated|internal","code":2,"message":"..."}}`；运行日志仍只走 stderr。

### 4.4 网络双闸

`collect --net` 需同时满足：`--net` 旗标 **且** 环境变量 `BOOKSIFT_NET=1`。
另有 `--budget`（默认 **8**，硬上限按档：匿名 `kDailyBudgetAnonymous`=300 / 带凭证 `kDailyBudgetBduss`=600，越界直接 exit 2）。
`--bduss <值>`（或环境变量 `BOOKSIFT_BDUSS`，**参数优先**）走账号档：请求间隔 1.0–2.0s、并发上限 4；
接受裸值或整段 `BDUSS=…` Cookie 片段（`parseBdussInput` 同源解析）；**凭证绝不进日志 / `--json`**（日志只打掩码，如 `FAKE_B……DE==`）。
headless 侧读不到系统加密存储（flutter_secure_storage），故凭证只走参数/环境变量——不要在共享终端里 export 真凭证。
`--seed-forums` 可在关注吧为空时播种默认两吧。
启用「仅 WiFi」时，Windows CLI 会检测默认路由网卡；Linux CLI 检查默认路由对应的无线接口；App 在 Android / iOS / macOS 读取系统活动网络。其他宿主平台或检测失败时按非 Wi-Fi 处理，不发送请求。可在 App 设置中关闭「仅 WiFi」以允许使用其他网络。`--forum` 可重复传入，计划和实际采集都只处理指定关注吧。

运行中每次请求在限速等待结束后还会复核「仅 WiFi」闸门；切换到非 Wi-Fi 会停止后续请求，未发出的请求不消耗预算，结果 JSON 的 `networkGateBlocked=true` 且退出码为 3。服务或 worker 失败会标记 `failed=true` 并返回退出码 1；因接口失败而进入冷却的吧也计作本轮失败。

`logs` 默认读取数据库中的 `collection_logs` 每轮汇总；需要逐条事件时用 `logs --run <run-id>`
（读取 `--log-dir/<run-id>.jsonl`）或 `logs --file <path>`。可附加 `--scope`、`--level`
（`info|ok|warn|error`）、`--event` 精确筛选，`--limit` 返回筛选结果末尾 N 条，0 表示全部。
JSONL 回放不需要 `--db`，并校验每行的 `RunEvent` 字段契约。

### 4.5 两种运行方式

| 方式 | 启动 | stdout 干净度 | sqlite3 |
|---|---|---|---|
| `dart run bin/booksift.dart` | 秒级 | ✗ 每次都打 `Running build hooks...` 到 **stdout** | 需 dll 在 PATH |
| `dart build cli` → `build/cli/windows_x64/bundle/bin/booksift.exe` | **~0.3 s** | ✓ | ✓ bundle 自带 `lib/sqlite3.dll` |

> 要 `--json | jq`，**用 exe**。（`dart compile exe` 不可用：报 "does not support build hooks, use 'dart build' instead"。）

---

## 5. 契约与不变量（改前必读）

1. `RunEvent` 的 JSON 键名与 `RunLevel.wire` 字面量是**对外契约**，改名等于破坏所有已落盘日志的解析。
2. JSONL 一行一事件，`detail` 里的换行由 `jsonEncode` 转义；`seq` 必须从 1 连续递增。
3. `lib/booksift.dart` 及其导出的每个库都不得 import `package:flutter`。
4. `CollectService` / `Queries` / `CollectRepository` 三个实现文件必须保持纯 Dart；要 provider 就写进 `*_providers.dart`。
5. `CollectService(onLog:)` 是可选参数，**不得改成必填**（会破坏 UI 侧与既有测试的构造调用）。
6. `doctor` 不得产生写副作用（尤其不得建库文件）。
7. `tableRowCounts` 必须排除 FTS 影子表、保留 FTS 虚拟表本身。
8. `SeedPackReport.shaMatches` 是 `bool?`：未校验必须是 `null`，不得退化成 `false` 或 `true`。
9. `HeadlessCollect.plan` 恒零请求；`run` 恒发请求。门控责任在调用方。
10. `run` 不关闭调用方注入的 `TiebaApi`。
11. `--json` 下 stdout 只能是结果 JSON 本身，任何诊断都走 stderr。
12. headless 测试一律 plain `test()`；碰真实 IO 的断言不得进 `testWidgets`（`test/TESTING.md §1`）。
13. `Queries(db)` 不传 `ftsMode` 时行为与旧版一致（尝试 FTS，异常才 `degraded=true`）；显式档位时 `off` 直接走 LIKE 且**不置 degraded**（用户主动选择，不是故障）。
14. `doctor` 的 FTS 表/触发器检查必须读取 `settings.fts_mode`：`off` 不要求任何 FTS 表，`book` 只要求 `book_fts` 与 `book_entries_*`，键缺失（老库）才沿用全量 6 触发的旧口径。

---

## 6. 测试覆盖（`app/test/headless/`，80 用例）

| 文件 | 用例 | 覆盖 |
|---|---|---|
| `logs_test.dart` | 12 | JSON 字段契约 / 空 detail·data 省略 / `level.wire` 固定 / JSONL 无裸换行 / 文本行毫秒三位 / seq 单调 / 多 sink 扇出 / `emitCollect` 级别映射与 `全局→global` / `newRunId` 格式 / 落盘逐行可解析 / **未 await close 会丢尾行** / 追加写不覆盖 |
| `env_test.dart` | 16 | 词典剔空行·缺失返空 / FTS 表计数 / doctor 只读、缺表与缺触发器诊断 |
| `query_test.dart` | 11 | 门面转发 / 联动计数与分类预览 / 推荐榜与字数榜 / overview 水位 / 日志排序 / DTO JSON 键 |
| `collect_test.dart` | 18 | plan 预算/仅 WiFi/吧过滤 / 非 WiFi 零请求 / 指定贴吧只调用目标吧 / 汇总与 API 所有权 |
| `seed_test.dart` | 11 | lite 包元数据 / sha/size 正反例 / nullable sha / 坏 JSON 与越界路径 / 进度阶段 |
| `network_gate_test.dart` | 1 | host 网络检测结果注入 |
| `../collector/network_gate_flutter_test.dart` | 10 | Android / Windows / iOS / macOS 通道读写与 fail-closed；Linux IPv4/IPv6 无线默认路由 |
| `cli_test.dart` | 13 | 参数拒绝 / `--` 分隔符 / BDUSS 脱敏 / doctor 与 seed 错误形状 / 无效 forum 不创建库 / JSONL 回放过滤、尾部 limit 与 seq 校验 / facets、rank、show、hot、random、timeline JSON / gated 退出码 |

跑法（**禁止裸跑 `flutter test`**）：

```powershell
pwsh tools/run_tests_safe.ps1 -TestTarget test/headless   # 只跑 headless
pwsh tools/run_tests_safe.ps1                             # 全量
```

> `collect_test.dart` 复用 `test/collector/support.dart` 的 `FakeTiebaApi`/`FakeClock`/`fakeSleeper`；
> 未脚本化的调用一律返回空页，故 **零真实网络**。它验的是「接线」，采集算法本身由
> `test/collector/service_test.dart` 覆盖。

---

## 7. 验证记录（可复现）

全量测试与静态分析（**最近一次：2026-10-13 18:30**；本仓库存在并发编辑会话，数字会随他人提交变化，
交接时请重跑一遍再采信）：

```
flutter analyze --no-pub      → No issues found!
pwsh tools/run_tests_safe.ps1 → 294 通过 / 7 skip / 0 失败
                                （历史记录中的 headless 数量已过时，当前数量见 §6）
```

CLI 逐条实跑（`dart build cli` 产物 exe）。**数据用的是 temp 副本，不是 `work/` 原件**
（drift 打开即跑迁移会改写文件，见 §9-1）；复现前先建副本：

```powershell
$tmp = "$env:TEMP\booksift_verify"; New-Item -ItemType Directory -Force $tmp | Out-Null
Copy-Item ..\work\seed_pack\_build\seed_lite.db "$tmp\app_copy.db" -Force
$db  = "$tmp\app_copy.db"
.\build\cli\windows_x64\bundle\bin\booksift.exe --db $db stats
```

实测结果：

| 命令 | 实测结果 |
|---|---|
| `doctor` | 五项全 ok；词典 22001 行 / 可锚定 21913（G2 剔除 88） |
| `stats --db <副本>` | schema v2、14 表；`book_entries` 74498、`posts` 29686；五维 total=74498；数据截至 2025-04-30 |
| `query 诡秘之主 --limit 4` | 命中 38 书；**该库无 FTS → 如实标注「LIKE 兜底 ⚠ 已降级」** |
| `query --json … \| ConvertFrom-Json` | stdout 首字符 `{`，可解析，`total=18` |
| `classify --title "《剑来》强烈推荐"` | `kind=扫书 flag=1 规则=T1d:标题扫书~推荐`，词典锚点「剑来」 |
| `classify --title "《诡秘之主》《大奉打更人》 排雷预警"` | `kind=排雷 flag=-1 规则=T1c`，锚点「大奉打更人」 |
| `logs --limit 3` | 0 条（种子库 `collection_logs` 为空，符合 manifest） |
| `seed --no-verify` | `seed_pack_lite v1`、zip 56985556 字节、大小一致、`shaMatches=null` |
| `collect` | 零请求出计划：两吧可跑、预算 0/8、间隔 1500~3000ms |
| `collect --net`（无环境变量） | **exit 3**，给出放行提示 |

顺带验证到的既有行为：drift 对 seed 库执行了 v1→v2 迁移（`posts` 加 `post_kind`/`recommend_flag`）。

### 当前工作区验证（2026-10-19）

| 检查 | 结果 |
|---|---|
| `dart analyze lib test` | No issues found |
| `pwsh tools/run_tests_safe.ps1 -TimeoutSec 1800` | 981 通过、3 skip、0 失败 |
| `pwsh tools/smoke_cli.ps1` | 成功：bundle build、版本/分类/doctor/hot/query/facets/show/logs/seed JSON、只读采集计划、网络闸门 exit 3；fixture SHA256 前后相同 |
| Android release APK | 签名有效；APK 含 armv7 / arm64 / x86_64 三份 `libsqlite3.so`；模拟器安装启动并 fully drawn，logcat 无 fatal / SQLite 加载错误 |
| `flutter build windows --release` | 成功；`dist_release/BookSift-windows-x64-v1.0.0.zip` 已重打包并核对 SHA256 |
| iOS / macOS Wi-Fi native handlers | 已静态复核 runner 通道和 `NWPathMonitor` 路径；本 Windows 主机无 Apple SDK，未做 Apple 构建 |

---

## 8. 已知边界与待补缺口

> 这是「查漏补缺」的主清单。**A/B/C 按影响面分级**，不是难度分级。

### A. 影响 agent 接入

| # | 缺口 | 现状 | 建议 |
|---|---|---|---|
| A1 | 已补 `collect --forum` 过滤 | `plan` 与 `run` 共用同一筛选集，未匹配的吧不会发请求 | 已在 `bin/booksift.dart`、`headless/collect.dart`、`collect_service.dart` 接线 |
| A2 | 查询面仍未全部映射到 CLI | 已补 `rank`、`show book <gid>`（含筛选评价列表）、`show post <pid>`、`hot`、`random`、`timeline`；查询门面均可从纯 Dart barrel 调用，并有稳定 JSON 契约测试 | 其余 `Queries` 方法属于 UI 状态/设置或批量领域操作，按明确 agent 场景再扩展 |
| A3 | JSONL 回放已接线 | `logs --run <id>` / `logs --file <path>` 读取逐条事件，支持 `scope` / `level` / `event` 过滤与尾部条数限制；现在校验 `seq` 从 1 连续递增；保留原 `collection_logs` 汇总默认行为 | 持续维护字段契约与回放测试 |
| A4 | 已补 `--version` | 人读与 JSON 两种输出均不读取数据库 | 已有版本契约测试 |
| A5 | 无 JSON Schema | 字段契约只存在于代码与本文档 | 导出 `logs.schema.json` + 各子命令结果 schema，供 agent 机器校验 |
| A6 | `--db` 缺省是**推断**不是探测 | `defaultDbPath()`（`bin:181`）= `~/Documents/app.sqlite`，未做平台分支，也不检查 drift_flutter 实际落点 | 探测多候选路径并在 doctor 里列出；或干脆去掉缺省、强制显式 |
| A7 | 无传输层 | agent 必须能起子进程 | 若需远程/跨语言接入，再在 headless 之上加 HTTP 或 MCP 层——**headless 层已按「传输无关」设计，加传输不必改业务** |

### B. 影响排错能力

| # | 缺口 | 现状 | 建议 |
|---|---|---|---|
| B1 | `classify` 只能单帖 | 无批量文件输入 | 加 `classify --batch <file>`（JSONL），输出逐项结果与 kind 分布；parity 对比仍由专用测试夹具负责 |
| B2 | doctor 检查面窄 | 不查 flutter/dart 版本是否满足 `pubspec`、`build/cli` bundle 是否过期、磁盘余量、`logs/` 体积 | 按需增项；`DoctorCheck` 结构已支持任意扩展 |
| B3 | 日志无级别过滤 | 无 `--verbose` / `--quiet` | `RunLog` 加 `minLevel`，sink 前置过滤 |
| B4 | **日志无轮转/清理** | `logs/` 会无限增长（每次运行一个文件） | 加保留策略（按份数/天数）或 `logs --gc` |
| B5 | 采集失败时无请求/响应快照 | JSONL 里只有 `CollectService` 产出的文案 | 排查「贴吧接口是否变更」仍需抓包；可在 `tieba_api.dart` 层加可选的响应体摘要回调 |
| B6 | `seed` 不能解包 | 只校验；导入依赖 Flutter `AssetBundle` 和数据库迁移流程 | 如确需 CLI 直接检查种子库，再新增受路径与体积校验的解包命令，并独立验证 zip 条目 |

### C. 工程化

| # | 缺口 | 现状 | 建议 |
|---|---|---|---|
| C1 | CLI 自动化测试覆盖命令级契约 | `tools/smoke_cli.ps1` 验证真实 bundle 的版本、分类、doctor、hot/query/facets/show/logs/seed、只读数据库哈希与网络闸门 | 将 smoke 脚本纳入 CI |
| C2 | 无 CI | 靠人跑 analyze + 测试 | 加 workflow：`flutter analyze` → `run_tests_safe.ps1` → `dart build cli` → CLI 冒烟（`doctor`/`classify`） |
| C3 | CLI release bundle 冒烟 | 已补 `tools/smoke_cli.ps1`：墙钟限制构建并验证 JSON、只读数据库与网络闸门契约 | CI 复用此脚本，避免本机与 CI 使用不同检查 |
| C4 | `dart run` 的 build hooks 横幅污染 stdout | 未在代码层规避，只有文档提醒 | 无法从 Dart 侧消除（是 `dart run` 自身输出）；结论就是**统一用 exe** |
| C5 | `onLog` 只被 headless 用 | UI 侧未接 | 若要在 App 内落盘诊断日志（用户反馈时导出），需在 `collect_controller.dart` 侧接同一套 sink |

---

## 9. 交接注意事项 / 踩过的坑

1. **`--db` 不要指向 `work/` 下的研究产物库**。drift 一打开就跑迁移并**改写文件**
   （本次验证即观测到 seed 库被 v1→v2 迁移）。一律先拷副本到 temp。
2. **PowerShell 写文件必须保留原行尾**。本仓库行尾是**混合**的（多数 LF，少数 CRLF，如
   `test/support/harness.dart`）。用 `-split "`r`n"` 处理 LF 文件会得到单个元素、静默失配；
   用 `$lines -join "`r`n"` 回写会整体转换行尾。安全做法：`[regex]::Replace` 配 `(?m)^…\r?\n`，
   原样保留。
3. **长命令会被墙钟超时截断在写入中途**。本次一条批量改 import 的命令超时被杀，导致
   `test/support/fake_book_repository.dart` 写到一半被截断（602 行 → 240 行）。
   批量文件改写应拆成小批、或先备份。恢复方式见 §10 备注。
4. **本仓库工作区有并发编辑会话**（实证 + 推断分开记）：
   - **实证**：`lib/features/rank/rank_page.dart` 于 17:17:37 被另一进程新建（我会话期间），
     中途一度带 10 个编译错误，同时 `home_page.dart` 被重构；`test/collect/collect_idle_test.dart`
     于 16:38 被另一进程改写（断言从「单 span 含 `冷却中 48m`」改为「分别找 `冷却中` 与 `48m` 两个 span」）；
     `test/support/fake_book_repository.dart` 事后又 +35 行（rank 相关）。
   - **推断（未能直接举证）**：`lib/features/collect/forum_cards.dart:110-119` 的「冷却中」去重逻辑
     是在 15:35 那次全绿运行之后、我 16:11 打 import 补丁之前由另一进程加入的。之所以只能推断：
     该文件 mtime 被我的补丁覆盖，且它未纳入 git（`??`）无基线可 diff。
     支持该推断的证据是：15:35 全绿 → 15:54 有人专门生成采集页空闲态截图 → 该去重逻辑的注释
     正是「避免『冷却中 冷却中 48m』重复」（截图能看见的问题）→ 16:21 该用例失败 → 16:38 他人改测试使其通过。
   - **由此得出的操作纪律**：
     - `flutter analyze` 的报错要先分清是不是自己的文件；
     - 未跟踪文件（`git status` 的 `??`）**没有 git 基线可 diff**，改前先备份；
     - 别用 `git checkout` 回滚——工作区有大量未提交的他人在途工作；
     - 用 mtime 做「谁改的」推断时要留意：自己的写入会覆盖 mtime，形成盲区。
5. **`dart compile exe` 不可用**（不支持 build hooks），要用 `dart build cli`。
6. **测试跑法**：`pwsh tools/run_tests_safe.ps1`，禁止裸跑 `flutter test`（FakeAsync 挂死，见 `test/TESTING.md`）。
7. `assets/dict/book_dict.txt`、`assets/seed/` 的相对路径以 **CWD = `app/`** 为准；
   exe 从别处运行时要显式传 `--dict` / `--seed-dir`。

---

## 10. 变更清单

### 新增（16 个文件）

| 文件 | 行 | 作用 |
|---|---|---|
| `HEADLESS.md` | 本文 | 交接文档 |
| `bin/booksift.dart` | CLI 入口，13 子命令 |
| `lib/booksift.dart` | 50 | 纯 Dart barrel |
| `lib/headless/logs.dart` | 246 | 结构化日志 |
| `lib/headless/env.dart` | 304 | 环境自检 |
| `lib/headless/query.dart` | 284 | 检索门面 + JSON 映射 |
| `lib/headless/collect.dart` | 310 | 采集驱动 |
| `lib/headless/seed.dart` | 153 | 种子包体检 |
| `lib/collector/collect_providers.dart` | 57 | 从 `collect_service.dart` 拆出的 riverpod 装配 |
| `lib/data/repo/collect_repository_providers.dart` | 28 | 同上（repo） |
| `lib/data/repo/queries_providers.dart` | 18 | 同上（queries） |
| `test/headless/{logs,env,query,collect,seed}_test.dart` | 221/240/257/363/210 | 66 用例 |

### 修改

| 文件 | 改了什么 |
|---|---|
| `lib/collector/collect_service.dart` | 移除尾部 provider 块与 `dart:convert`/`flutter.services`/`flutter_riverpod` 三个 import；**新增可选 `onLog` 钩子**（`:130`/`:159`/`:870`） |
| `lib/data/repo/collect_repository.dart` | 移除尾部 3 个 provider 与 `flutter_riverpod`/`database_provider` import |
| `lib/data/repo/queries.dart` | 移除尾部 `queriesProvider` 与 `flutter_riverpod`/`database_provider` import |
| 14 个 UI/测试文件 | 各补 `*_providers.dart` import（Dart import 不传递），其中 4 个同时删掉因拆分而失效的旧 import。明细见下表 |
| `pubspec.yaml` | 新增 `args: ^2.7.0`（原为传递依赖，显式声明以满足 `depend_on_referenced_packages`；版本与 lock 一致，未改解析结果） |
| `pubspec.lock` | `args` 由 `transitive` 变 `direct main`，版本仍 2.7.0 |
| 根 `.gitignore` | 加 `app/logs/` |
| 根 `README.md` | 目录段 + 新增「Headless CLI / API（agent 接入）」整节 |
| 根 `AGENTS.md` | §2 目录树补 `app/`；**新增 §7「Headless CLI / API（agent 接入点）」**。§5/§6 编号未动（`tool/smoke_collect.dart` 有对「§6 = 合规」的既有引用） |

#### 14 个 import 改动明细

| 文件 | 新增 | 删除（拆分后失效） |
|---|---|---|
| `lib/app_shell.dart` | `queries_providers` | — |
| `lib/features/search/dimension_chips.dart`（原 `lib/features/category/category_page.dart`，分类 Tab 已删除，`DimensionChips`/`dimensionCountsProvider` 迁入此文件） | `queries_providers` | — |
| `lib/features/content/book_detail_page.dart` | `queries_providers` | — |
| `lib/features/content/content_detail_page.dart` | `queries_providers` | — |
| `lib/features/content/detail_slot.dart` | `queries_providers` | — |
| `lib/features/home/home_page.dart` | `queries_providers` | — |
| `lib/features/profile/profile_page.dart` | `queries_providers` | — |
| `lib/features/search/search_page.dart` | `queries_providers` | — |
| `lib/features/search/search_state.dart` | `queries_providers` | — |
| `lib/collector/collect_controller.dart` | `collect_providers`、`collect_repository_providers` | `collect_repository` |
| `lib/features/collect/forum_cards.dart` | `collect_repository_providers` | `collect_repository` |
| `test/support/fake_collect.dart` | `collect_repository_providers` | `collect_repository` |
| `test/support/harness.dart` | `queries_providers` | `queries` |
| `test/collector/controller_test.dart` | `collect_providers` | `collect_service` |

**未产生净改动**（只在注释里提到 provider 名，非代码引用，故不需要 import）：
`lib/features/collect/collect_page.dart`、`test/app_shell_test.dart`、`test/support/fake_book_repository.dart`。

> **备注（§9-3 的恢复过程）**：`test/support/fake_book_repository.dart` 被超时命令截断后，
> 用「`git show HEAD:` 版本 + 当时的测试文件重建」恢复，并以残骸前 239 行做
> **逐字节交叉验证**（一致）；`git diff -U0` 亦证明预存改动只有 rename 两个 hunk。现 602 行，测试通过。
