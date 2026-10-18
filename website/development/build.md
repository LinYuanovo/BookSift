# 从源码构建

## 环境要求

- **Flutter SDK**：≥ 3.41.9（开发验证于 3.41.9）
- **Dart SDK**：≥ 3.11.5
- **iOS 目标版本**：iOS 14.0 及以上（file_picker iOS 实现要求）
- **Windows 桌面构建**：Visual Studio 2022（含「使用 C++ 的桌面开发」工作负载）
- **Android 构建**：Android SDK（build-tools 35.0.0 已验证）+ JDK 21
- **iOS / macOS 构建**：macOS 主机、Xcode 与 Apple 平台工具链；仓库 Actions 使用 `macos-14` runner。iOS 部署目标为 14.0
- **Linux 桌面构建**：Ubuntu 22.04+ 与 GTK3 / libsecret 开发依赖

## 克隆与运行

```powershell
git clone https://github.com/LinYuanovo/BookSift.git
cd BookSift\app

flutter pub get
flutter run -d windows      # 或 flutter run -d <android-device-id>
```

drift 的生成代码（`*.g.dart`）**已入库**，clone 之后不需要跑 `build_runner`。

## 构建发布版

五个原生平台的发布产物命名约定如下。GitHub Actions 为五端配置了构建 job；iOS 与 macOS 产物保持未签名状态。

| 平台 | 发布产物 | 当前 Actions |
| --- | --- | --- |
| Android | `android-v{version}.apk` | 已配置 |
| iOS | `ios-v{version}.ipa` | 已配置；未签名包需接收者自行签名后才能安装 |
| Windows | `windows-x64-v{version}.zip` | 已配置 |
| macOS | `macos-universal-v{version}.zip` | 已配置；目标包包含 arm64 与 x86_64，未签名包可能被 Gatekeeper 拦截 |
| Linux | `linux-x64-v{version}.tar.gz` | 已配置 |

Apple 平台的 Actions job 需要 `macos-*` runner 与 Xcode。未签名 iOS IPA 不含可供普通设备直接安装的签名；正式安装仍需匹配的 Apple Team、证书及 provisioning profile。macOS 未签名 ZIP 也未经过 notarization，公开分发时可能触发 Gatekeeper。

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

CI 会组装表中的五个平台产物。iOS job 使用 `flutter build ios --release --no-codesign` 后封装 `Payload/Runner.app`；macOS job 构建 universal `.app` 后压缩为 ZIP。两类 Apple 产物都不含签名或公证。

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
├── app/                          # Flutter 工程（android / ios / macos / windows / linux）
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
