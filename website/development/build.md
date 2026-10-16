# 从源码构建

## 环境要求

- **Flutter SDK**：≥ 3.41.9（开发验证于 3.41.9）
- **Dart SDK**：≥ 3.11.5
- **Windows 桌面构建**：Visual Studio 2022（含「使用 C++ 的桌面开发」工作负载）
- **Android 构建**：Android SDK（build-tools 35.0.0 已验证）+ JDK 21

## 克隆与运行

```powershell
git clone https://github.com/booksift-app/booksift.git
cd booksift\app

flutter pub get
flutter run -d windows      # 或 flutter run -d <android-device-id>
```

drift 的生成代码（`*.g.dart`）**已入库**，clone 之后不需要跑 `build_runner`。

## 构建发布版

```powershell
cd app

# Android
flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk

# Windows 桌面
flutter build windows --release
# 产物：build/windows/x64/runner/Release/  （整个目录打包分发）
```

Android 侧还可以用仓库里的打包脚本一键走完「preflight → 构建（带超时看门狗）→ apksigner 验签 → 权限闸门 → 组装 `dist_release/`」：

```powershell
pwsh tools/make_release.ps1               # 版本号取自 app/pubspec.yaml
pwsh tools/make_release.ps1 -SkipSeed     # 只要 APK，跳过种子包哈希
pwsh tools/make_release.ps1 -Publish      # 额外执行 gh release create（需已配 origin 且 gh 已登录）
```

脚本**不**改版本号、**不**建远程仓库、**不**打 tag —— 这些仍是人工确认的动作。

## 测试

::: warning 不要裸跑 flutter test
本项目的 widget 测试跑在 FakeAsync 假时钟下，dart:io / Isolate / 平台通道 / 真实数据库调用都可能让测试**永久挂死**（flutter 自身的超时在假时钟下不会触发）。

一律用仓库里的墙钟看门狗跑测试：

```powershell
pwsh tools/run_tests_safe.ps1
```

超时会杀掉整棵进程树并清理孤儿进程。真实 IO 的断言请写成 plain `test()`，规范见 `app/test/TESTING.md`。
:::

## 项目结构

```
booksift/
├── app/                          # Flutter 工程（android / ios / windows）
│   ├── bin/booksift.dart         # headless CLI 入口
│   ├── lib/
│   │   ├── booksift.dart         # 纯 Dart 门面 barrel（不导出任何依赖 flutter 的库）
│   │   ├── headless/             # 脱 GUI 适配层：logs / env / query / collect / seed
│   │   ├── classify/             # v3 分类器（规则 R1–R8 + 书名词典锚点）
│   │   ├── collector/            # 采集编排、调度限速、protobuf 通道、入库管线
│   │   ├── data/                 # drift 数据库、查询、仓库、种子导入、存量维护
│   │   ├── features/             # 页面：home / search / content / collect / rank / export / share / profile
│   │   ├── core/                 # 主题无关的基础件：字体、图标、更新检查、外链、窗口尺寸
│   │   └── theme/                # 设计令牌：AppColors / AppTypography / AppSpacing / AppRadius / AppMotion
│   ├── assets/                   # 种子包 / SVG 图标 / 书名词典
│   ├── tool/                     # 开发用小工具（冒烟、种子包生成）
│   └── test/                     # 测试（含 headless/ 与 TESTING.md 规范）
├── tools/                        # 测试看门狗与发布脚本
└── website/                      # 本站（VitePress）
```

## 技术栈

| 技术 | 版本 | 用途 |
| --- | --- | --- |
| [Flutter](https://flutter.dev) | 3.41.9 | 跨平台 UI 框架 |
| [Dart](https://dart.dev) | 3.11.5 | 编程语言 |
| [Riverpod](https://riverpod.dev) | ^2.6.1 | 状态管理 |
| [drift](https://drift.simonbinder.eu/) + sqlite3 | 2.34.x | 本地数据库与 FTS5 全文索引 |
| [go_router](https://pub.dev/packages/go_router) | ^17.5.0 | 路由与共享轴转场 |
| [dio](https://pub.dev/packages/dio) | ^5.11.1 | HTTP 客户端（采集 / 在线搜索 / 更新检查） |
| [protobuf](https://pub.dev/packages/protobuf) | ^6.1.0 | 贴吧 app-proto 通道的报文编解码 |
| [flutter_svg](https://pub.dev/packages/flutter_svg) | ^2.2.0 | 全量内联 SVG 图标 |
| [share_plus](https://pub.dev/packages/share_plus) | ^13.3.1 | 分享图 / 书单的系统分享面板 |

## 相关文档

仓库内与代码同步维护的说明文档：

- `app/HEADLESS.md` —— headless CLI 规格、字段契约、不变量与待补缺口清单
- `app/test/TESTING.md` —— 测试纪律（FakeAsync 挂死根因与模式）
