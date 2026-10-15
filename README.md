# 扫书汇 · BookSift

贴吧「扫书帖」（小说推荐帖）离线浏览 + App 内增量采集的 Flutter 应用，M1 里程碑。
本仓库仅含 App 工程；逆向分析、数据管线等研究产物不在库内。

## 目录

- `app/` — Flutter 工程（android / ios / windows）
- `app/bin/booksift.dart` — headless CLI（脱 GUI 驱动检索/统计/分类/采集）
- `app/lib/booksift.dart` — 纯 Dart 门面 API（barrel）
- `tools/run_tests_safe.ps1` — 测试墙钟看门狗（超时杀进程树）

## 编译

```powershell
cd app
flutter pub get                 # Flutter ≥ 3.41（开发验证于 3.41.9）
flutter build windows --debug   # 或 flutter build apk
```

drift 生成代码（`*.g.dart`）已入库，clone 后无需跑 build_runner。

## 测试

```powershell
pwsh tools/run_tests_safe.ps1   # 禁止裸跑 flutter test（FakeAsync 挂死风险，见 app/test/TESTING.md）
```

## Headless CLI / API（agent 接入）

采集编排、分类、检索、入库都是**纯 Dart**，可在不启动 Flutter 的前提下驱动。

> 规格、字段契约、不变量与**待补缺口清单**见 [`app/HEADLESS.md`](app/HEADLESS.md)；本节只是用法速查。

### 两种运行方式

```powershell
cd app
# ① 直接跑：需要 sqlite3.dll 在 PATH
$env:PATH = "C:\ProgramData\anaconda3\Library\bin;$env:PATH"
& C:\flutter\bin\dart.bat run bin/booksift.dart --help

# ② 编译成自包含 exe（推荐：~0.3s 启动、无横幅、bundle 自带 sqlite3.dll）
& C:\flutter\bin\dart.bat build cli        # → build/cli/windows_x64/bundle/
.\build\cli\windows_x64\bundle\bin\booksift.exe doctor
```

> ⚠️ `dart run` 每次都往 **stdout** 打一行 `Running build hooks...`。要 `--json | jq`
> 请用 exe，或从输出里第一个 `{` 起截。

### 子命令

| 命令 | 作用 | 网络 |
|---|---|---|
| `doctor` | 环境自检：runtime / sqlite3 / 库 / 词典 / 种子包 | 零 |
| `stats` | 各表行数、五维计数、关注吧水位、settings、数据截至日 | 零 |
| `query <词>` | 六维检索（≥3 字走 FTS，2 字词 LIKE 兜底）；`--suggest` 走书名联想 | 零 |
| `classify` | 离线跑 v3 分类器：kind / flag / 命中规则 / 书名 / 词典锚点 | 零 |
| `logs` | 导出库里 `collection_logs` 的历史运行汇总 | 零 |
| `seed` | 体检内置种子包：manifest + zip 大小 / SHA256 | 零 |
| `collect` | 增量采集；**默认只出计划（零请求）** | `--net` + `BOOKSIFT_NET=1` 双闸 |

### 输出与日志约定

- 默认：人读文本 → stdout，运行日志也 → stdout
- `--json`：**结果 JSON → stdout，运行日志 JSONL → stderr**，故 `... --json | jq .` 输出干净
- `--log-dir`（默认 `logs/`，已 gitignore）：每次运行落一份 `logs/<run_id>.jsonl`，
  一行一事件，字段固定 `run/seq/ts/level/scope/event/detail/data`；`seq` 单调可查丢行，
  `run_id` = `yyyyMMdd-HHmmss-<pid>`
- 退出码：`0` 成功 / `1` 运行失败 / `2` 参数错误 / `3` 网络闸门未放行

```powershell
.\booksift.exe --json --db $HOME\Documents\app.sqlite query 诡秘之主 --limit 5 | jq '.total,.items[0].name'
```

### 编程接入（不走 CLI）

```dart
import 'package:booksift/booksift.dart';   // 纯 Dart barrel，零 flutter 依赖

final AppDatabase db = HeadlessEnv.openDb('path/to/app.sqlite');
final BookQueryApi api = BookQueryApi(db);
final SearchOutcome hits = await api.search(const SearchFilter(query: '诡秘之主'));
final DbOverview ov = await api.overview();
await db.close();
```

`lib/booksift.dart` 刻意**只导出不依赖 flutter 的库**：漏进一个 flutter 依赖，`dart run`
就会因解析不到 `package:flutter` 直接失败。riverpod 装配单独放在 `collect_providers.dart` /
`collect_repository_providers.dart` / `queries_providers.dart`，不在 barrel 内——
这也是 `CollectService`、`Queries`、`CollectRepository` 三个实现文件保持纯 Dart 的原因。

采集逐条日志走 `CollectService(onLog:)`（不裁剪），UI 快照的 `logs` 有 200 条上限，两者分工不同。

### 已知边界

- `--db` 缺省猜 `~/Documents/app.sqlite`（drift_flutter 桌面落点）；App 没跑过则不存在，需显式 `--db`
- CLI **不做种子导入**：`seed_import.dart` 经 `AssetBundle` 读资产、依赖 flutter。`seed` 子命令只校验完整性
- 不要把 `--db` 指向 `work/` 下的研究产物库：drift 打开时会跑迁移并改写文件，先拷副本

## 数据与字体

- 内置种子包 `app/assets/seed/`（deflate zip，首启自动导入 + 后台 FTS 重建，版本闸门升级不伤用户数据）
  - 包内数据**已固化清洗成果**：book_entries 去重（79355→53441）、posts 按 v3 分类器回填
    post_kind/recommend_flag（排雷帖 2628→15856）、book_entries.category 镜像同步（排雷条目
    1312→23635）；维护闸门随包落账 → 首启后台维护直接跳过（BENCH 用例对「0 删 0 改 0 同步」有硬断言）
  - schema v4：drift `_createQueryIndexes` 补 12 个查询索引（此前 app.sqlite 全程无索引，
    检索/榜单/维护都在全表扫；同一份维护 18.7s→9.8s）
  - 重打流水线与实测数字见 `work/seed_pack/种子包说明.md §12`
- 字体默认系统字体；设置页可导入 ttf/otf 并按字体角色令牌（FontRole→FontSlot）指派到标题/正文/等宽等位置
- 主题为 Claude 风格设计令牌（`app/lib/theme/` 四个 ThemeExtension + `core/fonts/`），light/dark，零硬编码色值/字号/圆角/动效
