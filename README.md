<h1 align="center">扫书汇</h1>

<p align="center">
  <b>BookSift</b>
</p>

<p align="center">
  <nobr>
    <img src="https://img.shields.io/badge/Flutter-3.41+-02569B?style=flat-square&logo=flutter" alt="Flutter">
    <img src="https://img.shields.io/badge/Dart-3.11+-0175C2?style=flat-square&logo=dart" alt="Dart">
    <img src="https://img.shields.io/badge/Platform-Android%20%7C%20Windows-3DDC84?style=flat-square&logo=android" alt="Platform">
    <img src="https://img.shields.io/github/v/release/booksift-app/booksift?style=flat-square&label=Version&color=D97757" alt="Version">
  </nobr>
</p>

<p align="center">
  <b>贴吧「扫书帖」离线书单浏览器</b><br>
  <i>离线书库 · 全文检索 · 推荐排雷标识 · 增量采集 · 分享导出</i>
</p>

***

扫书汇把贴吧各扫书吧里散落的推荐帖整理成一份可检索的本地书库：书名、推荐人、推荐语、排雷记录都能翻，装完即用，检索全程离线。内置种子包已固化清洗成果（53,441 条书目 / 25,862 本书，数据截至 2026-10-13），快照之后的新帖可以按需增量采集补齐。

- **不需要登录贴吧**：默认全程匿名即可采集与在线搜索；BDUSS 为可选导入（只存本机系统加密存储，可随时测试 / 清除），导入后每日配额 300 → 600、请求间隔放宽、并发上限提高
- **不依赖服务端**：没有自建后端，数据、书签、收藏都在你自己的设备上

## 界面预览

<p align="center">
  <img src="website/public/shots/01-home.png" width="240" alt="首页时间线">
  <img src="website/public/shots/02-search.png" width="240" alt="搜索台">
  <img src="website/public/shots/03-post.png" width="240" alt="帖子详情">
  <img src="website/public/shots/05-collect.png" width="240" alt="采集中心">
</p>

<p align="center">
  <img src="website/public/shots/06-rank.png" width="240" alt="热门榜">
  <img src="website/public/shots/07-settings.png" width="240" alt="设置">
  <img src="website/public/shots/08-wide-home.png" width="380" alt="宽屏双栏">
</p>

## 快速开始

### 环境要求

<details>
<summary>点击展开查看环境要求</summary>

#### 用户使用（直接下载）

- **Android**：7.0 及以上
- **Windows**：Windows 10 / 11（64 位）
- **磁盘空间**：安装包约 125 MB（Android）/ 78 MB（Windows），首启导入后另需约 60 MB
- **网络**：安装与首启导入**不需要联网**，安装包内已附带种子数据

#### 开发构建

- **Flutter SDK**：≥ 3.41.9
- **Dart SDK**：≥ 3.11.5
- **操作系统**：Windows 10 / 11（64 位）
- **内存**：建议 8GB+；磁盘 2GB+（含构建缓存）

</details>

### 安装步骤

#### 直接使用

到 [Releases 页面](https://github.com/booksift-app/booksift/releases) 下载：

| 平台 | 文件 |
| --- | --- |
| Android | `app-v1.0.0.apk`（直接安装，需允许「安装未知应用」） |
| Windows | `booksift-windows-v1.0.0-x64.zip`（**完整解压**后运行 `booksift.exe`） |
| 完整性 | 同名 `.sha256`，建议用 `certutil -hashfile <文件> SHA256` 核对 |

首次启动会解压内置种子包并重建全文索引，耐心等一下即可；导入只在种子包版本升高时重跑，不会动你的收藏、书签与采集数据。

#### 使用教程

- [在线文档站](https://booksift-app.github.io/booksift/)
- [常见问题](https://booksift-app.github.io/booksift/faq)
- [采集中心](https://booksift-app.github.io/booksift/guide/collect) / [数据来源与合规](https://booksift-app.github.io/booksift/guide/data)

#### 自行构建

<details>
<summary>点击展开查看自行构建方式</summary>

```powershell
git clone https://github.com/booksift-app/booksift.git
cd booksift\app

flutter pub get
flutter run -d windows            # 开发调试
flutter build apk --release       # → build/app/outputs/flutter-apk/app-release.apk
flutter build windows --release   # → build/windows/x64/runner/Release/
```

drift 生成代码（`*.g.dart`）已入库，clone 后无需跑 `build_runner`。

Android 发布包可让脚本一键走完「preflight → 构建 → apksigner 验签 → 权限闸门 → 组装 `dist_release/`」：

```powershell
pwsh tools/make_release.ps1        # 版本号取自 app/pubspec.yaml；-Publish 会执行 gh release create
```

测试**不要裸跑** `flutter test`（FakeAsync 假时钟下可能永久挂死），一律用墙钟看门狗：

```powershell
pwsh tools/run_tests_safe.ps1
```

</details>

## 功能特性

### 🔍 检索与浏览

- **全文搜索**：FTS5 trigram 索引，3 字及以上走全文，2 字词自动降级 LIKE 并如实提示
- **五维筛选**：年 / 月 / 旬 / 来源 / 类别，每个候选值带**真实（且联动）的命中计数**，多维度 AND 交集
- **结果双 Tab**：书级（含推荐 / 排雷计数对比）与帖级（带搜索词正文高亮），上滑无限加载
- **榜单**：推荐次数榜四时段切换（全时段 / 本年 / 本月 / 近 30 天）+ 字数榜
- **随机书荒**：一次 10 本随机书，想不到看什么就再点一次

<p align="center">
  <img src="website/public/shots/09-wide-search.png" width="560" alt="宽屏搜索结果">
</p>

### ⚖️ 推荐 / 排雷标识

- **v3 分类器**：R1–R8 规则 + 22,001 条书名实体词典锚点，420 条人工标注评测集准确率 **96.2%**
- **四处同源**：卡片色条徽标、搜索的排雷筛选、书聚合页推荐 / 排雷计数、帖子类型徽标
- **书聚合页**：把推荐过同一本书的帖子聚到一处，可按推荐 / 排雷 / 渠道再筛，条件可快照分享

### 📖 阅读体验

- **富文本楼层渲染**：保留原帖加粗 / 链接 / 引用 / 图片排版
- **楼层目录**：长帖一键跳到指定楼层
- **自由复制**：逐楼层勾选复制，保留横滑翻页
- **溯源**：一键复制 / 打开原帖（Android 优先唤起贴吧 App），无链接的条目如实提示「原帖已不可溯源」
- **三件套**：书签（含阅读位置快照 + 搜索条件快照）/ 收藏 / 搜索历史，实时刷新

### 📥 采集与更新

- **App 内增量采集**：跨吧并发（默认 2 / 上限 3；BDUSS 档 4）、吧内串行、前缀水位续采
- **温和限速**：全局 1.5–3.0s 间隔（BDUSS 档 1.0–2.0s）、每日预算 ≤300 请求（导入 BDUSS 后 ≤600）、单帖退避重试、吧级 48h 熔断
- **BDUSS 可选导入**：设置页粘贴贴吧 Cookie 里的 `BDUSS=…` 即生效（只填 BDUSS，不要填账号密码），行内「测试」按钮可校验有效性；命中登录态失效自动回退匿名档并标记「已失效 · 请重新导入」；凭证只进设备本地系统加密存储，不进数据库、不写日志、不上传
- **中断可续**：单帖单事务 + 三层去重，杀进程 / 断网 / 取消后重入不产生重复数据
- **在线搜索**：本地 / 贴吧在线双 Tab，手动单请求触发，在线内容只读不落库
- **更新检查**：GitHub Releases 主源 + 可配置静态 JSON 备源，免 token、不收集信息

### 🎨 个性化

- **13 档主题色**（默认陶土珊瑚）+ 浅色 / 深色实时切换，色值经对比度校验
- **字体管理**：导入 ttf/otf 并按 10 个角色（标题 / 正文 / 元信息 / 等宽…）指派
- **三档自适应**：手机底部导航 / 窄屏 Rail / 宽屏 Rail extended + 双栏（阅读列 ≤720dp）
- **可访问性**：正文对比度 ≥4.5:1、触控目标 ≥44px、图标全量 SVG、跟随系统 reduceMotion

### 🖼️ 分享与导出

- **文字转图**：4 配色（白 / 黑 / 绿 / 米）、字号与行距可调、水印可改，导出 2.5x PNG
- **书单导出**：Markdown / TXT，收藏夹、书聚合页、搜索结果三处入口

## 技术栈

| 技术 | 版本 | 用途 |
| --- | --- | --- |
| [Flutter](https://flutter.dev) | 3.41.9 | 跨平台 UI 框架 |
| [Dart](https://dart.dev) | 3.11.5 | 编程语言 |
| [Riverpod](https://riverpod.dev) | ^2.6.1 | 状态管理 |
| [drift](https://drift.simonbinder.eu/) + sqlite3 | 2.34.x | 本地数据库与 FTS5 全文索引 |
| [go_router](https://pub.dev/packages/go_router) | ^17.5.0 | 路由与共享轴转场 |
| [dio](https://pub.dev/packages/dio) | ^5.11.1 | HTTP 客户端（采集 / 在线搜索 / 更新检查） |
| [protobuf](https://pub.dev/packages/protobuf) | ^6.1.0 | 贴吧 app-proto 通道报文编解码 |
| [flutter_svg](https://pub.dev/packages/flutter_svg) | ^2.2.0 | 全量内联 SVG 图标 |
| [share_plus](https://pub.dev/packages/share_plus) | ^13.3.1 | 分享图 / 书单的系统分享面板 |

## 项目结构

<details>
<summary>点击展开查看目录结构</summary>

```
booksift/
├── app/                          # Flutter 工程（android / ios / windows）
│   ├── bin/booksift.dart         # headless CLI 入口
│   ├── lib/
│   │   ├── booksift.dart         # 纯 Dart 门面 barrel（不导出依赖 flutter 的库）
│   │   ├── headless/             # 脱 GUI 适配层：logs / env / query / collect / seed
│   │   ├── classify/             # v3 分类器（R1–R8 规则 + 书名词典锚点）
│   │   ├── collector/            # 采集编排、限速调度、protobuf 通道、入库管线
│   │   ├── data/                 # drift 数据库、查询、仓库、种子导入、存量维护
│   │   ├── features/             # 页面：home / search / content / collect / rank / export / share / profile
│   │   ├── core/                 # 字体、图标、更新检查、外链、窗口尺寸
│   │   └── theme/                # 设计令牌：Colors / Typography / Spacing / Radius / Motion
│   ├── assets/                   # 种子包 / SVG 图标 / 书名词典
│   ├── tool/                     # 开发用小工具
│   └── test/                     # 测试（TESTING.md：测试纪律与挂死根因）
├── tools/                        # 测试看门狗（run_tests_safe.ps1）与发布脚本
└── website/                      # VitePress 文档站（自动部署到 GitHub Pages）
```

</details>

## Headless CLI / API（agent 接入）

采集编排、分类、检索、入库都是**纯 Dart**，可在不启动 Flutter 的前提下驱动 —— 排错与验证优先走这条路，不用起 GUI。

> 规格、字段契约、不变量与**待补缺口清单**见 [`app/HEADLESS.md`](app/HEADLESS.md)，完整用法见[文档站](https://booksift-app.github.io/booksift/development/headless)。

```powershell
cd app
& C:\flutter\bin\dart.bat build cli          # 一次编译，bundle 自带 sqlite3.dll
$exe = ".\build\cli\windows_x64\bundle\bin\booksift.exe"

& $exe doctor                                 # 环境自检（零网络）
& $exe --json --db <path> stats               # 结果 JSON→stdout，日志 JSONL→stderr
& $exe --db <path> query 诡秘之主 --limit 5
& $exe classify --title "《某某》排雷" --floor "正文…"
& $exe --db <path> collect                    # 只出计划，零请求
```

| 要点 | 说明 |
| --- | --- |
| 子命令 | `doctor` / `stats` / `query` / `classify` / `logs` / `seed` / `collect` |
| 日志 | 每次运行落 `app/logs/<run_id>.jsonl`，一行一事件，字段 `run/seq/ts/level/scope/event/detail/data`；`--no-log-file` 可关 |
| `--json` | 数据走 stdout、诊断走 stderr，可直接管道给 `jq` |
| 退出码 | `0` 成功 / `1` 运行失败 / `2` 参数错误 / `3` 网络闸门未放行 |
| 网络 | 只有 `collect --net` 发真请求，须**双闸**：`--net` + 环境变量 `BOOKSIFT_NET=1`，并受 `--budget` 上限约束 |
| `dart run` 的坑 | 每次都往 stdout 打 `Running build hooks...`；要干净 JSON 就用 exe |

```dart
import 'package:booksift/booksift.dart';   // 纯 Dart barrel，零 flutter 依赖

final AppDatabase db = HeadlessEnv.openDb('path/to/app.sqlite');
final BookQueryApi api = BookQueryApi(db);
final SearchOutcome hits = await api.search(const SearchFilter(query: '无限流'));
await db.close();
```

## 数据说明

- **来源**：百度贴吧扫书相关吧（yy小说吧 / 哀伤雪刃 / 雪群推书 / 大佬贴吧扫书 / 大佬专栏 / 丫丫书屋 / 龙空论坛…）的公开帖子，数据窗口 2010-02-04 ~ 2026-10-13（v1.0.0）
- **出厂即已整理**：同帖重复合并（79,355 → 53,441 条）；38,905 个帖子按 v3 分类器重判帖型（排雷帖 2,628 → 15,856）；书目分类与帖判定对齐（排雷条目 1,312 → 23,635）。快照装完即是最终形态，不必再等后台整理
- **两档种子包**：内置 lite（约 60 MB，推荐语截前 300 字）；full（约 300 MB，推荐语不截断 + 原始正文 + 预建 FTS 索引）随 Releases 发布，本版暂无应用内下载入口
- **数据包与程序分离**：App 更新不会顶掉数据，数据包升级也不会覆盖用户数据

## 合规与免责

- 书目、推荐语与排雷信息均由社区用户自发发布，**版权归原作者与发帖人所有**；本项目只做离线整理与检索，不商用，不提供原帖全文批量导出，权利人可经项目渠道申请移除
- 采集与在线搜索走的是贴吧**非公开的逆向接口**，非百度官方 API：接口随时可能变更或失效，高频采集存在被风控的风险，请按需低频使用、风险自担
- **隐私**：默认全程匿名；BDUSS 为可选导入，仅存设备本地系统加密存储（flutter_secure_storage）、绝不入库 / 上传 / 写日志，可随时清除回匿名档（失效自动降级只做标记、不删凭证）；本地数据不上传；应用不含统计或广告 SDK
- 完整声明见站内[数据来源与合规](https://booksift-app.github.io/booksift/guide/data)，或 App 内「我的 → 关于 → 关于与合规」

## 致谢

- [aiotieba](https://github.com/lumina37/aiotieba) —— 贴吧接口的 protobuf 定义与协议行为参考
- 所有在贴吧写扫书帖的推荐人：这份书库的内容全部来自你们

## 文档站本地预览

```powershell
cd website
npm install
npm run docs:dev       # http://localhost:5173/booksift/
npm run docs:build     # 产物 → .vitepress/dist
```

