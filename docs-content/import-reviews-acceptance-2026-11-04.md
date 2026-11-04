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
- Linux 集成测试竖屏视口 **390×844 logical px**：**1 passed**；用真实微信 HTML、生产解析器和 SQLite，验证导入、编辑、帖子详情、书聚合跳转、搜索，以及无法识别书目的纯帖子兜底和分段正文完整回读。该用例用可注入文档源提供已解析样本，不代表竖屏原生文件选择框验收。日志 `app/build/test_logs/test-20261104-133133-738479.log`。
- SQLite 新增 / 幂等 / FTS / 聚合 / 收藏 / 书签 / 并发修改保护 / 重新采集保护 / 分类维护保护 / 种子升级保护有回归覆盖；真实 v4 只读库读取不迁移。
- 320 / 390 / 720 / 1180 宽度的统一编辑页面测试通过。

真实来源抓取走已打开的可见浏览器；系统文件选择在 WSL 的 XDG Desktop Portal 会话中运行。未在 Android / iOS 真机验证软键盘与文件选择器，也未在 Windows / macOS 原生宿主分别执行本次 E2E。

## 合并前审阅复验

2026-11-04 对完整功能差异及工作区竖屏验收补充进行审阅。修复并验证以下边界：

- 同帖同书的独立评价可正常编辑；真实 v4 样本升级到当前 schema 后，保留全部评价、小说作者与条目 ID，初次快照完整留档。
- 图片刷新在写入事务内再次检查本地编辑；网络请求期间完成的校对图片不会被刷新响应覆盖。
- 移除全部评价后的空书组收藏，经过种子升级仍保留名称、作者及有效组引用。
- 嵌入 SVG 在编辑预览、阅读缩略图与查看器使用矢量解码器；PNG 沿用位图路径，损坏地址保留错误占位。
- 来源链接先去除首尾空白再生成幂等键，重复导入仍返回原帖子。
- 空标题统一使用默认标题，帖子、收藏与书签一致；引用维护不把这些记录判为失效。

复验结果：

- 应用目录执行 `flutter analyze --no-pub`：**0 问题**；日志 `app/build/test_logs/review-analyze-final.log`。
- 完整测试：**1057 passed, 14 skipped**；日志 `app/build/test_logs/test-20261104-150911-771375.log`。
- Linux 原生集成测试：**1 passed**；Xvfb 中运行 390×844 logical px 竖屏视口，验证真实微信离线 HTML、生产解析器、SQLite、编辑、书页跳转、搜索、纯帖子兜底与数据库重开。文档源经注入提供，不执行系统文件选择框；日志 `app/build/test_logs/test-20261104-151150-773714.log`。
- 测试前后对全部受测应用源码、测试及依赖配置进行 SHA-256 校验，确认验证内容未变化。
- 文档生成一致性检查及 `git diff --check` 通过。

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
