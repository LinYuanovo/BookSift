# 实施交接

## 当前状态

- 日期：2026-11-06。
- 工作树：`/home/dev/.codex/worktrees/booksift-performance-session-sources/BookSift`。
- 分支：`codex/performance-session-sources`，基线 `31dc9ac`。
- 主工作区 `/home/dev/code/BookSift` 保持原样。禁止推送远程。
- 计划见 `performance-session-sources-plan-2026-11-06.md`。
- 阶段：功能实现、原生验证、清理均完成，所有改动已本地提交；实站登录后书源验收限制见下文。

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

### 第二阶段：阅读恢复

- SQLite settings 保存首页页数/偏移和帖子身份/偏移，每 500ms 合并写入，生命周期切后台时 flush。
- 启动先保留上次快照，首页内容就绪后询问是否继续；拒绝则从首页开始。帖子用 tid 校验身份，删除后明确提示，防种子升级 id 重排跳错帖。
- 手机路由与桌面右槽复用恢复路径；支持退出应用后从新连接读回。异常 JSON/未知版本/越界位置忽略。
- 聚焦测试 43/43 通过，含真实文件数据库关闭重开和既有首页/详情/书签回归。
- 已加载 kvm_amd，得到 `/dev/kvm`；Android SDK 下载继续，Windows 原生工具链确认可用。

### 第三阶段：小说字数

- 统一提取明确标注的小说字数，支持万/w/千/百万、千分位、全角数字、逗号小数；书评/评论/章节长度排除，多书正文按书名分段。
- 自采入库和文档导入共用解析器；存量后台分批修复并更新书聚合，保留导入/人工编辑字段。首次修复约 18.8s，在后台进行；以后版本闸门跳过。
- 完整种子副本修复 28,986 行：原 27,492 条非空（最大 46,304，多为书评长度），修复后 2,857 条有明确小说字数（最大 15,910,000）。二刷改动 0，integrity_check=ok。
- schema v6 仅收窄 FTS UPDATE 触发器的监听列，改字数或类别不再无谓重写全文索引；保持关闭索引状态。
- 提取/采集/导入/榜单/维护测试通过；旧迁移断言的版本号正在同步为 v6。新增原生集成脚本，验收尚未完成。

### 第四阶段：书源搜索与下载

- 两站共用 Discuz 适配器：导航地址解析、配置 HTTPS 首页、系统安全存储 Cookie（绑定 origin）、formhash 搜索、GBK/UTF-8、附件选择、流式下载/取消/清理、原生保存位置对话框。
- 入口在搜索页和书籍详情页；明确展示连接、登录、验证码、权限和解析异常。
- 测试 7/7 通过；实站只验证导航和登录入口。尚香要求账号；搜书吧导航证书/404 异常。详见 `book-sources-2026-11-06.md`，未声称真实下载通过。
- 完整回归运行中。Windows 安装 ATL 后重试；Android 模拟器启动通过，但编译/模拟器并发出现内存压力，已停止模拟器并降低本任务 Gradle 内存并发后串行验证。

### 第五阶段：综合验收

- 完整 Flutter 回归：**1072 passed / 14 skipped**。四个首次回归失败均为新入口图标数/schema v6 的旧断言，修正后全量通过。
- 静态分析无问题，文档版本检查通过。
- Windows Profile 原生完整库测试通过。对照使用相同集成脚本与种子、旧版 `31dc9ac` 的首页/查询代码：旧版 first_content=1119ms / 最大事件循环间隔434ms；改后 first_content=269ms / 最大间隔142ms。**从挂载界面计时，包含数据库打开/迁移和查询，不包含 OS 进程启动、种子解压或首次导入**。维护/自动网络更新在此测试关闭，不外推到所有机器。
- Windows 帖子恢复提示/确认跳转通过。新增首页恢复实际偏移检查，最终源码再次构建中。
- 修复中文 Windows 编译：MSVC `/utf-8`，避免 GBK 默认代码页把 UTF-8 中文注释解析成语法错误；已安装缺失的 ATL 组件。
- 首次字数后台修复完成后，后续启动先查维护闸门；没有待办时不加载分类词典、不创建维护 isolate。
- Android Java 17 / SDK36 / NDK28 / emulator / API35 x86_64 镜像已安装，模拟器 boot completed 已确认；本任务构建使用临时 Maven 镜像/代理与 1.5GB Gradle heap，未改仓库远程仓库源。

## 最终验收记录

| 环境/验证 | 结果 | 边界 |
| --- | --- | --- |
| Windows Profile 旧版首页/查询对照 | 首批内容 1119ms；事件循环最大间隔 434ms | 同脚本、同种子、旧代码 `31dc9ac` |
| Windows Profile 改后两次 | 首批内容 269ms / 154ms；最大间隔 142ms / 41ms | 测试挂载后计时；非 OS 到内容冷启动 |
| Windows 原生恢复 | 帖子确认跳转、首页页数和 500px 偏移均通过 | 使用独立临时库 |
| Android API35 x86_64 模拟器 Profile | 首批内容 999ms；最大间隔 157ms | KVM + SwiftShader；同完整种子，无 Android 旧版对照 |
| Android adb 安装/启动及恢复 | 安装成功，原生测试全部通过，首页/帖子恢复通过 | adb COLD TotalTime=7285ms，含测试解压，不能代表产品冷启动 |
| Android 正式入口 Release 构建 | x86_64 APK 91.0MB 构建成功 | 本地默认 debug 证书签署的 Release；仅验收，不发布，清理时删除 |
| Android 正式入口 adb 操作 | 首次选择关闭索引后导入成功；force-stop 后 COLD TotalTime=3542ms；UIAutomator 确认首页正文可见、不再出现导入提示 | 完整库、Release、模拟器，不代表真实手机性能 |
| Android 强制终止恢复 | 点开帖子、滚动、force-stop、重启后显示正确帖名的「继续上次浏览？」 | 正式 main 入口，非注入会话状态 |
| 完整回归 | 1072 passed / 14 skipped | 跳过项来自已有环境/慢测试门槛 |
| 后续聚焦回归 | 34 passed / 1 skipped；37 passed；12 passed | 维护闸门、首页恢复、Cookie 轮转、取消/截断下载等最终补强 |
| 静态/文档 | app 下 analyze 无问题；文档版本检查通过 | 根目录独立 classifier 打包示例不在 app 分析范围 |
| 字数修复 | 28,986 行修正，2,857 条明确小说字数，二刷 0 改动 | 真实种子副本；用户库未触碰 |
| 数据库整理 | 175,370,240 → 175,222,784 字节，integrity=ok | 此副本本来没有空闲页，收益仅约144KiB；不能承诺所有库大幅变小 |

### 已知限制

- 新装首次解压/导入 61MiB 种子，以及首次18.8s的字数后台修复，仍有一次性成本；没有删除正文来换体积。
- 按 ABI 发布 APK 已加入本地 workflow；未触发 Actions，也未发布，因此尚无新通用/ARM64 安装包的同条件体积比较。
- 两个论坛的实站登录后搜索/下载未验收：尚香需账号，搜书吧导航证书/404。模拟接口测试通过不等于实站成功。
- 系统保存位置使用 file_picker 13 的原生 saveFile API；没有自动操作 Android/Windows 保存对话框做完整下载落盘实站验收。
- 阅读进度每500ms持久化；被系统强杀时，最后不足500ms的滚动可能丢失。首页按页数/像素恢复，内容新增或窗口宽度变化时可能有位置偏移。
- Java、Android SDK、Flutter SDK配置、Windows ATL 是可复用工具链，会保留；任务专用 AVD、Windows临时构建副本、测试库、截图和日志会清理。

## 本地提交

- `61f5a5d` 计划与交接。
- `cbb7d00` 首屏与存储整理。
- `1fc97fb` 阅读会话恢复。
- `7552d1e` 小说字数修复。
- `691dc01` 书源搜索与下载。
- `5a8a5b9` 原生验收与边界修复。
- 最后收尾提交包含下载截断/取消验证、测量记录与清理回执。

## 清理范围

仅清理本任务工作树生成的 build/.dart_tool/Android 构建残留、`/tmp/booksift-performance-20261106`、本任务工具安装下载临时文件、`C:\dev\booksift-native-20261106` 和 `booksift_20261106` AVD。保留项目原有 fixture、测试源码、内置种子和其他工作区产物；保留独立分支及工作树供审阅。主工作区 main 未修改，没有 push、PR、merge 或发布。

清理已执行完成：AVD 删除、任务浏览器会话关闭、Windows 临时副本删除；本任务 APK、构建缓存、测试库、UI dump 和日志已删除。分支和 main 均为干净状态。

## 追加：两站真实账号流程验收

用户追加授权测试账号登录，要求继续调查 GitHub 的搜书吧相关项目，并完成真实流程测试。继续在现有独立分支实施，不推送。

执行顺序：重新确认导航与可信论坛地址 → 浏览器登录 → 书名搜索 → 免费可下载附件 → 使用同一登录态验证生产 Dart 适配器 → 修复差异并回归 → 记录实际结果、本地提交、删除含凭证的会话和测试文件。账号、密码和 Cookie 不写入文档或仓库。状态：进行中。

追加实测：两站登录、真实书名搜索、生产 Dart 搜索均成功；搜书吧通过独立日本节点完成动态导航，最终域名也可直连。已修复搜书吧多级公开导航/404有效页面、尚香 `_dsign` 静态表达式跳转、下载按钮与文件名分离、付费附件提示。详情及2个待购买样本见 `book-sources-2026-11-06.md` 追加部分。

购买前阶段：准备样本需尚香1金钱、搜书吧1银币，当时已打开确认页核对价格并等待授权；后续已获授权并完成，见下文。

本轮验证：44项书源/既有页面回归通过，app 静态分析和文档检查通过，改动文件无登录态凭证。真实登录态与HTML诊断仅存于任务私有临时目录，收尾删除；测试代理使用独立配置和进程，停止时仅按本任务配置路径识别进程，不停止主代理。

用户随后授权这两笔站内积分，继续购买后下载、校验和保存验收。范围仍限于尚香 tid=293701 的1金钱附件，以及搜书吧 tid=1308036 的1银币附件；不重复购买已取得权限的附件。状态：已完成真实下载和Android指定位置保存。

两笔购买和浏览器/生产Dart下载已成功，文件大小及完整哈希见书源文档；无重复购买。新增可显式开启的 `integration_test/book_source_live_test.dart`，已在Android API35 x86_64完成生产UI真实搜索、附件选择、下载、DocumentsUI指定目录保存。ADB拉回两个文件，哈希与浏览器和Dart下载一致；原生测试全部通过。私有临时asset仅用于注入已授权登录态/测试代理，不入库。Windows Computer Use 因主机WSL路径兼容错误无法初始化，尚未验证Windows保存对话框。

本轮聚焦回归12项通过，app analyze无问题，文档检查通过。完成授权目标的Android真实流程和共享Dart下载验证；私有测试文件、下载书籍、截图/HTML/日志、含临时凭证的APK/asset、AVD、独立代理和构建目录均已清理。保留可复用测试源码及非敏感验收记录。主节点未切换，主工作区不改、无push。

## 追加：设计 token 审计与修复

发现：BookTheme 已覆盖大部分页面色板/卡片/按钮几何，但新增书源页仍使用默认 SegmentedButton（含 Material 勾选图标）、默认输入装饰/进度条、默认返回图标和 MaterialPageRoute；设置、阅读恢复和整理存储弹窗缺少显式字阶/间距/动效。此前功能验收不代表设计系统验收。

计划：改用现有 SegmentedPill、SVG 图标、共享页面转场；输入、弹窗、进度和结果卡显式消费 AppColors/AppTypography/AppSpacing/AppRadius/AppMotionTheme；覆盖窄屏、深色、主题色、字体放大、键盘、加载/错误与附件弹窗。仅修改本任务新增 UI，保留系统原生文件选择器的系统外观。完成后本地提交、清理临时渲染图片和构建产物，不推送。

已完成：

- 书源切换复用 SegmentedPill；返回按钮用 AppIcon SVG；入口复用 openCenterPage/MotionPage，在宽屏遵循中间栏栈，取消 MaterialPageRoute。
- 新增 AppTextField：AppTypography.body、raised背景、xl24圆角、borderStrong/accent焦点描边、inputHeight48下限、主题动效；无默认下划线输入装饰。书名、论坛地址、Cookie共用。
- 新增 AppDialog：headline/body字阶、cardPadding、420宽度token、可滚动内容和可换行操作区；书源设置、恢复提示、存储整理接入，弹窗动效统一dialogAnimationStyle。
- 附件选择仍使用框架SimpleDialog作为容器，但标题/行高/间距/字体/SVG均显式接入token，表面/圆角由BookTheme管理。
- 搜索结果改为项目Card与cardTitle/caption，状态文本使用语义色，进度条指定accent/sunken/pill并按减弱动效停止无限动画。页面统一滚动，键盘和大字体不会挤出固定头部。
- 额外修复设置弹窗退出动画完成前过早dispose控制器的问题。

验证：95 passed / 1 skipped（原有可选更新截图测试），app analyze无问题、文档检查/diff check通过。覆盖320px深色1.6倍字号、390px浅色、1280px宽屏；设置与附件弹窗、键盘300px inset、主题色/自定义字体槽、focus/加载/错误、恢复与整理弹窗、路由/SVG、已有首页/详情/更新UI。使用系统Noto字体渲染9张临时图片并目视检查浅色页面与深色大字设置弹窗；不把widget渲染称为新一轮Android/Windows原生验收。临时图片、测试日志和构建缓存清理，仅保留测试源码。

范围边界：项目本身基于Material3，允许使用经BookTheme及显式token约束的Material容器/按钮；这不等于采用未定制的Material外观。Android/Windows系统文件选择器保持系统外观，不套应用token。本次没有顺带重做原项目其他旧页面。
