# 扫书汇（saoshuhui）

贴吧「扫书帖」（小说推荐帖）离线浏览 + App 内增量采集的 Flutter 应用，M1 里程碑。
本仓库仅含 App 工程；逆向分析、数据管线等研究产物不在库内。

## 目录

- `app/` — Flutter 工程（android / ios / windows）
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

## 数据与字体

- 内置种子包 `app/assets/seed/`（deflate zip，首启自动导入 + 后台 FTS 重建，版本闸门升级不伤用户数据）
- 字体默认系统字体；设置页可导入 ttf/otf 并按字体角色令牌（FontRole→FontSlot）指派到标题/正文/等宽等位置
- 主题为 Claude 风格设计令牌（`app/lib/theme/` 四个 ThemeExtension + `core/fonts/`），light/dark，零硬编码色值/字号/圆角/动效
