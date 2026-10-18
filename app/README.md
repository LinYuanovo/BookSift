# 扫书汇（BookSift）· Flutter 工程

应用源码、资源与测试都在这里。用法速查、功能清单与截图见[仓库根 README](../README.md)，
在线文档站见 <https://linyuanovo.github.io/BookSift/>。

工程内与代码同步维护的规范文档：

- [`HEADLESS.md`](HEADLESS.md) —— headless CLI 规格、字段契约、不变量与待补缺口清单
- [`test/TESTING.md`](test/TESTING.md) —— 测试纪律（FakeAsync 挂死根因与模式）

```powershell
flutter pub get
flutter run -d windows            # 或 flutter run -d <android-device-id>
flutter build apk --release
flutter build windows --release
```

测试**不要裸跑** `flutter test`，用仓库根的墙钟看门狗：

```powershell
pwsh ..\tools\run_tests_safe.ps1
```
