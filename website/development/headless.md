# Headless CLI 与 API

App 的采集编排（`CollectService`）、检索（`Queries`）、分类器与入库管线都是**纯 Dart**，可以在不启动 Flutter 的前提下驱动 —— 排错、验证、脚本化采集都走这条路，不用起 GUI。

`app/lib/booksift.dart` 是它们对外的门面 barrel，刻意**只导出不依赖 flutter 的库**。

## 编译并自检

```powershell
cd app
& C:\flutter\bin\dart.bat build cli          # 一次编译，bundle 自带 sqlite3.dll
$exe = ".\build\cli\windows_x64\bundle\bin\booksift.exe"

& $exe doctor                                 # 环境自检（零网络）
& $exe --version                             # 输出 CLI 版本
```

发布前可用仓库根目录的 `pwsh tools/smoke_cli.ps1` 复建 bundle，并检查版本、分类、doctor、只读采集计划和网络闸门输出；整个过程有墙钟超时。

也可以用 `dart run bin/booksift.dart` 直接跑，但每次都会往 **stdout** 打一行 `Running build hooks...`，会污染 `--json` 输出 —— 要管道给 `jq` 就用编译好的 exe。

## 子命令

| 命令 | 作用 | 网络 |
| --- | --- | --- |
| `doctor` | 环境自检：runtime / sqlite3 / 库 / 词典 / 种子包 | 零 |
| `stats` | 各表行数、五维计数、关注吧水位、settings、数据截至日 | 零 |
| `query <词>` | 六维检索（≥3 字走 FTS，2 字词 LIKE 兜底）；`--suggest` 走书名联想 | 零 |
| `facets` | 按已选年份/月/旬/来源/类别返回五维联动候选计数 | 零 |
| `hot` / `random` / `timeline` | 热门书名、随机书荒与最新时间线 | 零 |
| `rank` | 推荐次数榜或字数榜；支持全时段、本年、本月、近 30 天 | 零 |
| `show book <gid>` | 书聚合头、三分计数和评价列表；支持筛选、排序与分页 | 零 |
| `show post <pid>` | 帖子、楼层、楼层图片和提及书目计数 | 零 |
| `classify` | 离线跑 v3 分类器：kind / flag / 命中规则 / 书名 / 词典锚点 | 零 |
| `logs` | 导出库里 `collection_logs` 的历史运行汇总 | 零 |
| `seed` | 体检内置种子包：manifest + zip 大小 / SHA256 | 零 |
| `collect` | 增量采集；**默认只出计划（零请求）** | `--net` + 环境变量双闸 |

```powershell
& $exe --json --db <path> stats
& $exe --db <path> query 诡秘之主 --limit 5
& $exe --json --db <path> facets --year 2026 --month 10
& $exe --json --db <path> rank --kind word --window year --limit 10
& $exe --json --db <path> show book 123 --filter recommend --sort time_desc --limit 50 --offset 0
& $exe --json --db <path> show post 456
& $exe classify --title "《某某》排雷" --floor "正文…"
& $exe --json --db $HOME\Documents\app.sqlite query 无限 --limit 5 | jq '.total,.items[0].name'
```

## 输出与日志约定

- 默认：人读文本 → stdout，运行日志同样 → stdout；
- `--json`：**结果 JSON → stdout，运行日志 JSONL → stderr**；失败时 stdout 仍为单个 `{"error":...}` 对象，所以 `... --json | jq .` 输出干净；
- `logs --run <run-id>` 或 `logs --file <path>`：回放逐条 JSONL 事件；可用 `--scope`、`--level`、`--event` 精确筛选，`--limit` 返回筛选结果末尾 N 条（0 为全部），不需要数据库；
- `--log-dir`（默认 `logs/`，已 gitignore）：每次运行落一份 `logs/<run_id>.jsonl`，一行一事件，字段固定 `run/seq/ts/level/scope/event/detail/data`；`seq` 单调，可查丢行；`run_id` = `yyyyMMdd-HHmmss-<pid>`；`--no-log-file` 可关；
- 退出码：`0` 成功 / `1` 采集或运行失败 / `2` 参数错误 / `3` 网络闸门未放行；运行中切离 Wi-Fi 也返回 3，并在结果里标记 `networkGateBlocked`。采集或解析失败结果带 `failed: true` 并返回 1。

## 网络闸门

只有 `collect --net` 会发真实请求，且必须**双闸同时放行**：命令行 `--net` + 环境变量 `BOOKSIFT_NET=1`，并受 `--budget` 上限约束。缺一个就直接以退出码 `3` 退出，不会偷偷发请求。启用「仅 Wi-Fi」时，Android / iOS / macOS App 查询系统活动网络；Windows CLI 查询默认路由网卡，Linux CLI 检查无线默认路由；无法确认时不发送请求。

## 编程接入（不走 CLI）

```dart
import 'package:booksift/booksift.dart';   // 纯 Dart barrel，零 flutter 依赖

final AppDatabase db = HeadlessEnv.openDb('path/to/app.sqlite');
final BookQueryApi api = BookQueryApi(db);
final SearchOutcome hits = await api.search(const SearchFilter(query: '无限流'));
await db.close();
```

装配约定：

- `lib/booksift.dart` **只导出不依赖 flutter 的库** —— 漏进一个 `package:flutter` 依赖，`dart run` 就会直接解析失败；
- riverpod 装配单独放在 `collect_providers.dart` / `collect_repository_providers.dart` / `queries_providers.dart`，不进 barrel；
- `CollectService` / `Queries` / `CollectRepository` 三个实现文件必须保持纯 Dart；
- 采集逐条日志走 `CollectService(onLog:)`（不裁剪），UI 快照的 `logs` 有 200 条上限，两者分工不同。

## 已知边界

- `--db` 缺省猜 macOS/Linux/Windows 的桌面落点（Windows 为 `~\Documents\app.sqlite`）；App 没跑过则文件不存在，需要显式 `--db`；
- CLI **不做种子导入**（`seed_import.dart` 依赖 `AssetBundle`，需要 Flutter 环境），`seed` 子命令只校验完整性；
- `show book` 返回聚合头、三分计数和评价列表；支持语义筛选、排序及 `--limit` / `--offset` 分页；
- 不要把 `--db` 指向研究产物库：drift 打开时会跑迁移并**改写文件**，先拷副本。

完整字段契约、不变量与待补缺口清单见 `app/HEADLESS.md`。
