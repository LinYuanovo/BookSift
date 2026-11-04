# 扫书导入与统一编辑验收

日期：2026-11-04。分支：`codex/import-book-reviews`。对应 [Issue #1](https://github.com/LinYuanovo/BookSift/issues/1)。

## 实现

- 入口：主页 / 采集页「导入扫书」；任意本地帖子详情「更多 → 编辑帖子」。
- 输入：粘贴、公开网页链接、TXT / Markdown / HTML / DOCX。
- 同一编辑器校对帖子信息、正文、图片及书目评价；保存同步全文检索、书级聚合、收藏和书签。
- 原始文档以字节留档，后续编辑不改写；无法识别书目时完整保留为可检索的帖子。
- 多书段落完整评价保留；单书文档中的别名和相关推荐不被错误拆成主书评价。

## 微信真实样本

四篇通过可见浏览器读取，保存已渲染正文，再经生产 DocumentReader / ContentStore 导入真实 SQLite；所有文本逐段比对浏览器正文，图片下载后嵌入并再次入库回读。

| 样本 | 识别书名 | 小说作者 | 可见图片 / 入库图片 | 缺失文字段 | 原始字节回读 |
| --- | --- | --- | --- | --- | --- |
| [1](https://mp.weixin.qq.com/s/cp6OIXZzN3nugE-dTPECow) | 阴阳造化炉 | 青烽不醉 | 21 / 21 | 0 | SHA-256 一致 |
| [2](https://mp.weixin.qq.com/s/gEsk2xB4XV6M0T2mvJtupA) | 逆流纯真年代 | 人间武库 | 22 / 22 | 0 | SHA-256 一致 |
| [3](https://mp.weixin.qq.com/s/ZCEli9aQpkHmU071X2lqRA) | 红龙执政官 | 如墨 | 22 / 22 | 0 | SHA-256 一致 |
| [4](https://mp.weixin.qq.com/s/cAiladfMhdDiHIGPEzeHaA) | 副作用越大我越强，道祖心态崩了 | 肥猫警长 | 14 / 14 | 0 | SHA-256 一致 |

合计 79 张图片全部成功下载并嵌入。各主书评价保留 4388 / 6752 / 6977 / 6756 字符，未按识别窗口截断。

验收口径：上述结果证实**完整 HTML / 文档导入**成功，不代表微信 URL 在所有设备均可免验证直读。微信会动态生成公众号卡片等内容；服务器原始 HTML 与浏览器最终正文不同。链接遇验证页会拒绝入库并提示保存完整 HTML 或粘贴。第 4 篇 SVG 装饰保留在原始 HTML，阅读页提示媒体；排版按项目阅读样式重排，不承诺与公众号页面逐像素一致。

## 测试

- `flutter analyze`：0 问题。
- 完整测试：**1049 passed, 14 skipped**；墙钟保护执行，日志 `app/build/test_logs/test-20261104-115156-691014.log`。
- Linux 可见桌面真实 E2E：**1 passed**，通过实际系统文件选择框选择样本 1 HTML，导入、编辑书评人 / 小说作者、搜索 / 书页 / 原文回读、数据库关闭重开均通过。日志 `app/build/test_logs/test-20261104-114755-689990.log`。
- SQLite 新增 / 幂等 / FTS / 聚合 / 收藏 / 书签 / 并发修改保护 / 重新采集保护 / 分类维护保护 / 种子升级保护有回归覆盖；真实 v4 只读库读取不迁移。
- 320 / 390 / 720 / 1180 宽度的统一编辑页面测试通过。

真实来源抓取走已打开的可见浏览器；系统文件选择在 WSL 的 XDG Desktop Portal 会话中运行。未在 Windows / Android / iOS / macOS 原生宿主分别执行本次 E2E。

## 本地证据

`app/build/acceptance/wechat/` 下保留原始响应、浏览器正文、完整 HTML、离线 HTML、`report-complete.json`、`report-offline.json`、`images-report.json`、`native-e2e.json` 和系统选择框截图。这些真实样本与构建证据为本地文件，未纳入 Git。

可复验步骤：

```bash
cd app
node tool/prepare_wechat_snapshots.mjs
dart run tool/preserve_wechat_images.dart
dart run tool/verify_wechat_import.dart build/acceptance/wechat complete
dart run tool/verify_wechat_import.dart build/acceptance/wechat offline
cd ..
FLUTTER_BIN=/path/to/flutter/bin/flutter bash tools/run_tests_safe.sh --concurrency=4
```

本次仅本地提交，未推送远程，未创建 PR 或关闭 issue。
