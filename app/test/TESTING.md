# 测试架构约定（TESTING.md）

> 本文件是 `app/test/**` 的**强制规范**。违反第 1 节的任何一条都会让 `flutter test` 无限挂死
> ——不是失败，是挂死，且 flutter 自己的超时机制也救不了（见第 2 节）。
> M1-④ 会话曾两次因此被取消。

---

## 1. 根因：testWidgets 的 FakeAsync 假时钟区

`testWidgets` 由 `AutomatedTestWidgetsFlutterBinding.runTest` 驱动，测试体运行在
**`FakeAsync` 假时钟区**内：

| 异步来源 | 完成于 | 在 testWidgets 体内 `await` 的结果 |
|---|---|---|
| `Future.microtask` / 纯 Dart `async` 函数 / `StreamController`（同步 add） | 微任务队列 | ✅ 正常，`pump`/`pumpAndSettle` 会冲刷 |
| `Timer` / `Future.delayed` / `AnimationController` / `tester.pump(d)` | **假时钟** | ✅ 正常，`tester.pump(duration)` 推进假时钟即触发 |
| `dart:io`（`File`/`Directory`/`Socket` 的**异步** API） | 真实事件循环 | ❌ **永不返回** |
| `Isolate.spawn` / `ReceivePort` / `SendPort` 回调 | 真实事件循环 | ❌ **永不返回** |
| 平台通道（path_provider / sqflite / secure_storage / file_picker） | 真实事件循环 | ❌ 永不返回（或 `MissingPluginException`，取决于插件） |
| `HttpOverrides` 之外的真实网络（dio / cached_network_image 落盘缓存） | 真实事件循环 | ❌ 永不返回 |
| `NativeDatabase.memory()` / `NativeDatabase(File)`（**非** background） | 当前 isolate 内 FFI **同步**执行，Future 以微任务完成 | ✅ 可用（见下方实测） |
| `NativeDatabase.createInBackground()` / `drift_flutter.driftDatabase()` | 后台 isolate + path_provider 平台通道 | ❌ **永不返回** |

### 实测证据（探针已删除，结论保留）

用一个临时探针文件在 `tools/run_tests_safe.ps1 -TimeoutSec 120` 下实跑：

```
00:00 +0: probe A: NativeDatabase.memory() 在 FakeAsync 区内查询
00:00 +1: probe B: 临时文件副本 + 真实 File IO          ← +1 = probe A 通过
（此后假时间停在 00:00，墙钟 120s 被看门狗杀掉）
```

- **probe A 通过**：`AppDatabase(NativeDatabase.memory())` + `customSelect('SELECT 1').get()`
  在 testWidgets 体内正常完成。drift 的非 background `NativeDatabase` 走 `dart:ffi` 在**当前
  isolate 同步**执行（`drift-2.34.4/lib/native.dart`：`_NativeDelegate` → `sqlite3.openInMemory()`），
  返回的 Future 以微任务完成，FakeAsync 可冲刷。
- **probe B 挂死**：`await Directory.systemTemp.createTemp(...)` 是真实 dart:io 异步 → 永不返回。

> ⚠️ 结论修正：挂死的**充分条件**不是「碰了 drift」，而是「碰了真实事件循环」。
> M1-④ 上会话的挂死点是 `test/features_test.dart` 的 `openFixture(tester)` ——
> 它在 testWidgets 体内做了 `Directory.systemTemp.createTemp()` + `File.copy()`（真实 IO），
> 而不是 `NativeDatabase` 本身。
>
> 尽管如此，本仓仍然执行第 3 节的「widget 测试一律内存 fake」，理由不是假时钟，而是：
> widget 测试不该依赖 10MB fixture、不该有文件句柄泄漏、不该因为数据变动而脆断。

---

## 2. 为什么 flutter 自己的超时救不了

`flutter_test` 的单用例超时（默认 30s，`--timeout` 可调）是用 **`Timer`** 实现的，
而这个 Timer 记在**假时钟**上。测试体卡在 `await 真实 IO` 时不会调用
`tester.pump()`，假时间就永远停在 `00:00`：

```
00:00 +6: 页面交互 书名点击 → 搜索状态预填
10:00 +6 -1: ... [E]  TimeoutException after 0:10:00.000000
```

上例（`work/ft_out.txt`）能报超时，是因为 `flutter test` 外层还有一道**真实墙钟**的
suite 级兜底（10 分钟）；但它只在整个 suite 层面生效，一旦命中就报废整轮，
且期间进程树一直挂着（本仓实测留下过 6 个孤儿 `dart.exe`，见第 6 节）。

**所以：进程外看门狗是必需的双保险，不是可选项。**

---

## 3. 修复模式（全仓贯彻）

### 3.1 widget 测试（`testWidgets`）—— 一律内存 fake

```dart
late FakeBookRepository repo;
setUp(() => repo = FakeBookRepository(library: demoLibrary()));

testWidgets('…', (WidgetTester tester) async {
  useSurface(tester);                                  // 视口，默认 390×844@3x
  await tester.pumpWidget(testApp(repo, initial: '/post/7'));
  await tester.pumpAndSettle();
  expect(…, …);
});
```

- `test/support/harness.dart` 的 `testOverrides(repo)` 一次性注入三件事：
  1. `queriesProvider.overrideWithValue(FakeBookRepository())` —— 领域层换纯内存实现
     （`test/support/fake_book_repository.dart`，只有微任务，零 IO / 零 Timer）；
  2. `fontServiceProvider.overrideWith(...)` —— 字体四端口（settings/picker/registrar/files）全 fake；
  3. **`appDatabaseProvider.overrideWith((ref) => throw StateError(...))`** —— 哨兵。
     任何组件路径漏走真库都会立刻炸成显式错误，而不是在假时钟区里静默挂死。
- 依赖倒置的接缝是 `lib/data/repo/queries.dart` 的 `abstract interface class BookRepository`；
  `Queries`（drift 实现）与 `FakeBookRepository` 各实现一次。新增数据访问方法时**必须**
  同时补三处：接口、`Queries`、`FakeBookRepository`（`implements` 会在编译期逼你补）。
- 语料在 `test/support/demo_data.dart`（`demoLibrary()`）：14 条目 / 7 帖 / 6 书组，
  形状刻意覆盖排雷帖、富文本楼层（《书名》+ URL）、热门榜时段可判定的重排、origin 三档。
  **语料一律无图**：`CachedNetworkImage` 会经 `flutter_cache_manager` 触 sqflite + path_provider。
- widget 测试体内只准做：`pump` / `pumpAndSettle` / `pump(Duration)` / `tap` / `enterText` /
  `expect` / 读 `containerOf(...)` 的 provider 值 / 读 fake 的内存态（`repo.bookmarks` 等）。

### 3.2 需要真实 IO 的断言 —— plain `test()`

plain `test()` 跑在**真实事件循环**（不套 FakeAsync），IO 正常。放这里的东西：

- drift 查询正确性：`test/features_test.dart` 的 `queries 数据层` 组，
  对 `test/fixtures/dev_seed.db` 的临时副本断言 FTS/LIKE 分支、五维计数、AND 交集、
  四时段榜单、书聚合语义筛选、历史/书签/收藏 CRUD。
- 种子导入全流程：`test/seed_import_test.dart`（zip SHA256 流式校验、ATTACH 单事务拷贝、
  FTS 后台重建 isolate、幂等重跑）。
- 字体注册表持久化 / 文件落盘：`test/font_service_test.dart`（用 fake 端口，plain test）。
- 源码级守卫（`Directory.listSync` 同步 IO）：`test/font_guard_test.dart`、
  `test/theme_tokens_test.dart`。同步 IO 在假时钟区里也是安全的，但仍归 plain test。

fixture 由 `dart run tool/make_dev_seed.dart` 生成（从 `work/seed_pack/_build/seed_lite.db`
——发行包同源的**已就地清洗**库——分层抽样 2000 条），**不进发行包**。
`post_kind` / `recommend_flag` / `category` 一律直迁源库值；源库缺 `posts.post_kind`
（即传了未清洗的库）时工具直接失败，不退回粗分类兜底。

### 3.3 `setUpAll` / `setUp` / `tearDown`

- 挂在**只含 plain `test()` 的 group** 上时，可以做真实 IO 准备（`openFixture()` 就是这样用的）。
- **绝不能**让一个既服务 `testWidgets` 又服务 `test()` 的 group 共享做 IO 的 `setUp`：
  `testWidgets` 的 `setUp` 同样跑在假时钟区内。
- widget 测试的准备一律是构造 fake（纯同步/微任务），可以放心写在 `setUp` 或体内。

### 3.4 确实必须在 testWidgets 内做真实异步

用 `tester.runAsync(() async { … })` 包裹，**范围最小化**：

```dart
final bytes = await tester.runAsync(() => File(p).readAsBytes());  // 真实事件循环
await tester.pumpWidget(…);                                        // 回到假时钟区
```

`runAsync` 期间假时钟暂停、真实事件循环接管；回调内**不要** `pump`。
本仓目前没有用例需要它——优先按 3.1/3.2 拆分。

### 3.5 收尾纪律

- SnackBar 的 4s 自动消失是**假时钟 Timer**：用例结束前必须
  `await dismissSnackBars(tester)`（= `pump(5s)` + `pumpAndSettle`），否则残留 pending timer 判失败。
- 输入联想的 200ms debounce 同理：`enterText` 后 `await tester.pump(const Duration(milliseconds: 250))`。
- `tester.view.physicalSize` 改动由 `useSurface` 内部 `addTearDown(tester.view.reset)` 兜住。

---

## 4. 跑测试：一律经看门狗

```powershell
# 全仓（默认墙钟上限 600s）
pwsh tools/run_tests_safe.ps1

# 单文件 / 单用例，收紧上限便于快速定位挂死
pwsh tools/run_tests_safe.ps1 -TestTarget test/features_test.dart -TimeoutSec 180
pwsh tools/run_tests_safe.ps1 -FlutterArgs '--name','手风琴' -TimeoutSec 120
```

`tools/run_tests_safe.ps1` 的行为：

- `Start-Process -PassThru -RedirectStandardOutput/-Error` 把 `flutter test` 的管道交给文件
  （不让子进程持有本 shell 的捕获管道 —— 那会让调用方一起挂死，AGENTS.md 进程纪律同源）；
- 每 30s 打印心跳（已用时 + 日志最后一行）；
- **墙钟**超时 → `taskkill /T /F` + CIM 进程树 BFS + 孤儿清扫 → 打印日志尾部 → `exit 1`；
  日志最后一行就是挂死用例名；
- 正常结束透传 flutter 的 exit code，全绿时打印总时长；
- 起飞前自动清扫上一轮遗留的 `dart.exe`（`flutter_tools.snapshot test` 且命令行含本工程路径），
  并在命中 `PathExistsException` 时清 `build/native_assets` 重跑一次（见第 6 节）。

**禁止**直接在会话 shell 里裸跑 `flutter test`。

### 看门狗自验证（2026-10-13 实测）

临时文件 `test/_zz_hang_probe_test.dart`（含 1 个 plain 对照 + 2 个 testWidgets 挂死探针），
`-TimeoutSec 30`：

```
00:00 +0: plain test 里的真实 IO 正常（对照组，应通过）
00:00 +1: 挂死探针 A：真实 dart:io future 在假时钟区永不完成   ← plain 通过，假时间停在 00:00
[watchdog] ✗ 超时 30s：已杀进程树 52936,54312,43260,52048,10752,56084,21124
[watchdog] 结果：TIMEOUT（墙钟 30s）  总耗时 32s     → exit code 1
```

验证后该文件已删除；`Get-CimInstance Win32_Process` 复查孤儿 = **0 个**。

---

## 5. 现有测试清单

| 文件 | 形态 | 是否碰真实 IO | 说明 |
|---|---|---|---|
| `features_test.dart` · `queries 数据层` | plain `test()` | ✅ drift on `fixtures/dev_seed.db` 副本 | SQL 正确性（FTS/LIKE、五维、榜单、聚合、CRUD） |
| `features_test.dart` · `页面交互` | `testWidgets` | ❌ 全内存 fake | 书名点击预填、URL span、排雷徽标语义色、手风琴独占、榜单时段重排、日期分组流、日期目录两段式跳转、ScrollChrome 接入（首页/分类）、书签快照、书聚合筛选、历史复现、LIKE 分支、expanded 详情槽 |
| `app_shell_test.dart` | `testWidgets` | ❌ 全内存 fake | 三档断点 + 1024 边界（ISSUE-1）+ 品牌头（ISSUE-3）+ Tab 切换 |
| `font_service_test.dart` | plain `test()` | ❌ 四端口 fake | bootstrap / 导入 / 角色槽 / 删除 / 降级 |
| `font_ui_test.dart` | `testWidgets` | ❌ 四端口 fake | 设置页入口、十角色行、样张换家族、下拉、恢复默认、导入、删除 |
| `font_tokens_test.dart` | plain `test()` | ❌ | FontSlot 编解码、FontFamilySet、字阶 token |
| `font_guard_test.dart` | plain `test()` | ✅ 同步 `Directory.listSync` | 字体家族字面量守卫（v1.4 §2.2） |
| `theme_tokens_test.dart` | plain `test()` | ✅ 同步 `Directory.listSync` | 4 个 ThemeExtension、WCAG 对比度、硬编码色值守卫 |
| `seed_import_test.dart` | plain `test()` | ✅ 文件 + isolate | 种子导入全流程（含 FTS 后台重建 isolate） |
| `window_size_test.dart` | plain `test()` | ❌ | 断点纯函数 |
| `support/harness.dart` | — | — | 挂具：`testOverrides` / `testApp` / `useSurface` / `containerOf` / `dismissSnackBars` |
| `support/fake_book_repository.dart` | — | — | `BookRepository` 纯内存实现 |
| `support/demo_data.dart` | — | — | `demoLibrary()` 语料 |

`support/**` 不以 `_test.dart` 结尾，不会被当成 suite 执行。
`font_ui_test.dart` / `support/harness.dart` 复用 `font_service_test.dart` 里的四个端口 fake
（单一出处，不复制第二份）。

---

## 6. 排错速查

**症状：`flutter test` 卡住不动，日志最后一行停在某个用例名，假时间恒为 `00:00`。**
→ 该用例（或它 pump 起的组件 build/init 路径）在 testWidgets 体内碰了真实事件循环。
按第 1 节表格定位；改造为 fake 或挪到 plain `test()`。**不要**靠调大 `--timeout` 解决。

**症状：`PathExistsException: Cannot copy file to 'build\native_assets\windows\sqlite3.dll' (errno 183)`。**
→ 上一轮挂死/被取消的 `dart.exe` 还活着，且已把 `sqlite3.dll` 加载进内存 → Windows 拒绝覆盖，
于是**之后每一次** `flutter test` 都崩在这里（与测试代码无关，本仓实测连续 6 次）。
看门狗已内置起飞前清扫；手工处理：

```powershell
Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'dart.exe' -and $_.CommandLine -like '*flutter_tools.snapshot*test*' }
taskkill /PID <pid> /T /F
Remove-Item app\build\native_assets -Recurse -Force
```

**症状：会话/CI 被取消后，后续命令莫名变慢或文件删不掉。**
→ 查孤儿：`Get-CimInstance Win32_Process | ? { $_.Name -match '^(dart|flutter_tester|booksift)' }`。
按 `CreationDate` 找长命进程，`taskkill /T /F` 收掉。

---

## 7. 新增测试 checklist

1. 是 `testWidgets` 吗？→ 组件树里有没有任何路径通向 `dart:io` / isolate / 平台通道 / 网络？
   （`appDatabaseProvider` 哨兵会帮你兜底报错，但别指望它。）
2. 需要新数据？→ 加到 `support/demo_data.dart` 的 `demoLibrary()`，**不要**在 widget 测试里开库。
3. 需要新的数据访问方法？→ `BookRepository` + `Queries` + `FakeBookRepository` 三处同步补。
4. 要断言 SQL 正确性？→ 写 plain `test()`，对 `fixtures/dev_seed.db` 副本断言。
5. 有 SnackBar / debounce / 动画？→ 显式 `pump(duration)` 推进假时钟，收尾 `dismissSnackBars`。
6. 屏外元素找不到？→ `ListView`/`Sliver` 懒构建，用 `useSurface(tester, height: …)` 加高视口
   或先 `scrollUntilVisible`，别断言不存在。
7. 同文案多处命中？→ 用 `find.descendant(of:…)` / `find.byKey` / `byWidgetPredicate` 收窄，
   别用 `.first` 掩盖歧义。
8. 跑：`pwsh tools/run_tests_safe.ps1`。
