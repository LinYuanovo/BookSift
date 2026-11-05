# 实施交接

## 当前状态

- 日期：2026-11-06。
- 工作树：`/home/dev/.codex/worktrees/booksift-performance-session-sources/BookSift`。
- 分支：`codex/performance-session-sources`，基线 `31dc9ac`。
- 主工作区 `/home/dev/code/BookSift` 保持原样。禁止推送远程。
- 计划见 `performance-session-sources-plan-2026-11-06.md`。
- 阶段：计划已落盘，开始性能与空间基线分析。

## 初步事实

- Flutter 3.41.9 SDK 在 `/home/dev/sdks/flutter`。
- 主工作区存在 CodeGraph，已先用它查询调用链；新工作树没有索引，不自动建索引。
- Hy Memory 的 `memory_search` 未在当前工具中找到，不阻塞。
- `main()` 在 `runApp` 前等待字体 bootstrap，需确认是否间接等待数据库打开。
- 启动首帧之后启动种子/FTS/数据维护；需测量与首页查询的竞争。
- 现有数据库 schema v5，保留导入原文、编辑保护、收藏与书签的既有约束。

## 验证与后续

### 第一阶段：首屏与存储

- 基线库：内置完整 lite 种子副本，39,348 帖 / 170,996 楼 / 53,591 条目，175,271,936 字节。
- Linux Dart JIT 基线：打开 149ms、首批时间线 59ms、首次热门榜 2328ms、随机书目 168ms。榜单分类在 UI isolate 执行，能阻塞内容绘制。
- 改后：字体 bootstrap 不阻塞 runApp，仅加载正在使用的字体；榜单分类在 isolate 运行、首页 feed 优先；随机书目先抽 ID 再关联正文，首次 65ms、后续 43–56ms（旧 81ms）。时间线首批 53ms。
- 榜单总耗时 JIT 仍为 1.6–2.5s，移出 UI isolate 改善的是响应性，不能宣称计算本身变快。需在原生 Release 进一步验收。
- 新增设置页空间统计、数据库 VACUUM、图片缓存/更新包清理；保留用户内容和字体。新增按 ABI APK 构建，保留通用 APK 更新契约；尚未触发 Actions。
- 聚焦测试 80/80 通过，flutter analyze 无问题。清理测试验证 VACUUM 前后内容和 integrity_check。
- Windows Flutter/VS Build Tools 可用；Linux Java 17/adb 已安装，Android SDK 正在补齐。当前没有 `/dev/kvm`。
