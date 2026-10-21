# 下载与安装

**扫书汇（BookSift）** 是一个把百度贴吧「扫书帖」离线化的书单浏览器：内置一份整理好的书库种子数据，装上就能按书名、推荐人、年份、吧来源翻书，也能自己按需增量采集新帖。

它不是相机扫描工具，也不需要登录贴吧 —— 默认全程匿名。

## 环境要求

::: details 用户使用（直接下载）
- **Android**：7.0 及以上
- **Windows**：Windows 10 / 11（64 位）
- **磁盘空间**：安装包约 125 MB（Android）/ 78 MB（Windows），首启导入后占用量会再增加约 60 MB
- **网络**：安装与首启导入**不需要联网**，安装包内已附带种子数据
:::

::: details 开发构建
- **Flutter SDK**：≥ 3.41.9（开发验证于 3.41.9）
- **Dart SDK**：≥ 3.11.5
- **内存**：建议 8GB+；磁盘 2GB+（含构建缓存）
- **Windows 桌面构建** 还需 Visual Studio 2022（含「使用 C++ 的桌面开发」工作负载）

详见 [从源码构建](/development/build)。
:::

## 下载

在 [Releases 页面](https://github.com/LinYuanovo/BookSift/releases) 下载对应平台的包：

| 平台 | 文件 | 说明 |
| --- | --- | --- |
| Android | [`BookSift-android-v{{version}}.apk`](https://github.com/LinYuanovo/BookSift/releases/download/v{{version}}/BookSift-android-v{{version}}.apk) | 直接安装，无需 Google Play |
| Windows | [`BookSift-windows-x64-v{{version}}.zip`](https://github.com/LinYuanovo/BookSift/releases/download/v{{version}}/BookSift-windows-x64-v{{version}}.zip) | 解压即用，无需安装 |
| 完整性 | `同名 .sha256` | 一行 64 位十六进制摘要，用于校验下载文件 |

::: tip 建议校验一下
```powershell
certutil -hashfile .\BookSift-android-v{{version}}.apk SHA256
```
与 `.sha256` 文件里的值逐字对上再安装。
:::

## Android 安装

1. 把 APK 传到手机（数据线、网盘、QQ 传输都可以）；
2. 点开安装，系统提示「安装未知应用」时，允许当前来源（文件管理器 / 浏览器）安装；
3. 若杀毒或系统扫描提示风险，属于未上架应用常见的误报，可加白名单。

当前版本只提供 Android 与 Windows 桌面版，iOS 尚未发布。

## Windows 安装

1. 把 zip **完整解压**到任意目录（不要只把 `booksift.exe` 拖出来，同目录的 `data/`、`*.dll` 都是运行时依赖）；
2. 双击 `booksift.exe`。首次运行会解压内置种子包，请耐心等待；
3. Windows SmartScreen 可能提示「未知发布者」，选择「更多信息 → 仍要运行」。

## 第一次启动：导入内置书库

首启会先询问是否建立全文索引，然后自动做三件事，页面顶部有进度提示：

1. **校验**内置种子包（SHA256，防止包被改动）；
2. **解压 + 导入**书库到本地 SQLite（约 53,591 条书目）；
3. **建立全文索引**（选「暂不建立」则跳过，之后可在「设置 → 数据与存储」补建）。

导入只在**种子包版本升高时**才重跑一次（版本闸门），不会覆盖你自己的收藏、书签、搜索历史与采集数据；导入期间可以先浏览已有内容。

合规与数据来源说明在「我的 → 关于 → 关于与合规」里（数据来源署名 / 贴吧服务条款与使用提示 / BDUSS 与隐私声明三块固定文案），见[数据来源与合规](/guide/data)。

## 界面一览

底部四个 Tab：

| Tab | 职责 |
| --- | --- |
| **首页** | 最新扫书时间线、采集提示卡、热门榜与随机书荒入口 |
| **搜索** | 关键词 + 五维筛选、搜索历史、结果双 Tab、贴吧在线搜索 |
| **采集** | 关注吧管理、水位、立即采集、进度与日志 |
| **我的** | 收藏夹 / 书签夹 / 搜索历史，以及设置与关于 |

![首页](/shots/01-home.png){.shot-phone}

## 数据存在哪

- **Windows**：`%USERPROFILE%\Documents\app.sqlite`（drift 桌面默认落点）
- **Android**：应用私有数据目录内的 `app.sqlite`（随卸载一并清除）

内置种子数据、采集数据、收藏与书签都在这个库里；图片缓存是另外的缓存目录，可随时清空。升级程序（替换 exe / 覆盖安装 APK）不会动这份数据。

## 下一步

- [首页、榜单与随机书荒](/guide/browse) —— 先随便逛逛
- [搜索与五维筛选](/guide/search) —— 找一本书最快的方式
- [采集中心](/guide/collect) —— 想要快照之后的新帖
