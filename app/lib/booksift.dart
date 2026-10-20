/// 扫书汇 · BookSift 的**纯 Dart 门面 API**。
///
/// 本文件是 headless 入口：CLI（`bin/booksift.dart`）、脚本、测试与后续 agent
/// 一律经此接入，不必知道内部目录结构。
///
/// ## 边界（重要）
/// 这里导出的每个库都**不依赖 `package:flutter`**，因此可在纯 Dart VM 下运行：
///
/// ```powershell
/// cd app
/// $env:PATH = "C:\ProgramData\anaconda3\Library\bin;$env:PATH"   # sqlite3.dll
/// & C:\flutter\bin\dart.bat run bin/booksift.dart doctor
/// ```
///
/// 反过来说，凡是 import 了 flutter 的东西（widget、theme、riverpod provider 装配、
/// `seed_import.dart` 的 AssetBundle 路径、`*_providers.dart`）**一律不在此列**——
/// 一旦从这里漏出去，`dart run` 就会因为解析不到 `package:flutter` 而直接失败。
/// 新增导出前先确认目标库的 import 里没有 flutter。
///
/// ## 分层
/// - `headless/` — 为脱 GUI 运行而写的适配层（结构化日志、环境自检、门面、种子体检）
/// - `collector/` `classify/` `data/` — 既有的业务实现，本身即纯 Dart，直接复用
library;

// ── headless 适配层 ────────────────────────────────────────────────────────
export 'headless/collect.dart';
export 'headless/env.dart';
export 'headless/logs.dart';
export 'headless/network_gate.dart';
export 'headless/query.dart';
export 'headless/seed.dart';

// ── 采集 ──────────────────────────────────────────────────────────────────
export 'collector/collect_service.dart';
export 'collector/collect_state.dart';
export 'collector/ingest.dart';
export 'collector/scheduler.dart';
export 'collector/tieba_api.dart';
export 'collector/watermark.dart';
export 'collector/worker.dart';

// ── 分类器 ────────────────────────────────────────────────────────────────
export 'classify/classifier.dart';

// ── 数据层 ────────────────────────────────────────────────────────────────
export 'data/bduss_format.dart';
export 'data/db/app_database.dart';
export 'data/repo/collect_repository.dart';
export 'data/repo/queries.dart';

// ── 常量 ──────────────────────────────────────────────────────────────────
export 'core/constants.dart';
