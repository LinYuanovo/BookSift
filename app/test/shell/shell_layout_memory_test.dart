// 三栏「功能区」布局记忆（导航栏宽 / 展开宽 / 详情栏占比）。
//
// 分组与边界（TESTING.md §1/§3）：
//  · 「存储」plain test() —— ShellLayoutStore 是纯 KV 逻辑，用内存端口断言；另有一例
//    走真实 drift 内存库，证明落点就是既有 settings 表（不新造表）。
//  · 「UI 恢复 / 写回」testWidgets —— shellLayoutStoreProvider 注入内存端口
//    （纯微任务，假时钟区安全），零真实 IO；分隔条位置 = 占比的可观测量。
library;

import 'package:booksift/app_shell.dart';
import 'package:booksift/core/constants.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/headless/env.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_book_repository.dart';
import '../support/harness.dart';

/// 内存 settings KV 端口（纯微任务；testWidgets 假时钟区安全）。
class MemoryKv implements SearchSettingsKv {
  final Map<String, String> values = <String, String>{};
  int reads = 0;
  int writes = 0;

  @override
  Future<String?> readSetting(String key) async {
    reads++;
    return values[key];
  }

  @override
  Future<void> writeSetting(String key, String value) async {
    writes++;
    values[key] = value;
  }
}

/// 长按后拖动分隔条（与 shell/wide_panes_test.dart 同款手势）。
Future<void> longPressDrag(WidgetTester tester, Finder target, double dx) async {
  final TestGesture gesture = await tester.startGesture(tester.getCenter(target));
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.moveBy(Offset(dx, 0));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  group('存储（settings KV）', () {
    test('空 KV → 缺省 256 / 256 / 0.4', () async {
      final ShellLayout layout = await ShellLayoutStore(MemoryKv()).read();
      expect(layout.railWidth, ShellLayoutStore.defaultRailWidth);
      expect(layout.railWidthExpanded, ShellLayoutStore.defaultRailWidth);
      expect(layout.detailFraction, ShellLayoutStore.defaultDetailFraction);
    });

    test('save → read 往返：三条键各占一个 settings 键（UPSERT）', () async {
      final MemoryKv kv = MemoryKv();
      final ShellLayoutStore store = ShellLayoutStore(kv);

      await store.save(const ShellLayout(railWidth: 316, railWidthExpanded: 316, detailFraction: 0.62));
      expect(kv.values.keys.toSet(), <String>{
        SettingsKeys.railWidth,
        SettingsKeys.railWidthExpanded,
        SettingsKeys.detailFraction,
      });

      final ShellLayout back = await store.read();
      expect(back.railWidth, 316);
      expect(back.railWidthExpanded, 316);
      expect(back.detailFraction, 0.62);

      await store.save(const ShellLayout(railWidth: 72, railWidthExpanded: 316, detailFraction: 0.62));
      expect((await store.read()).railWidth, 72, reason: '重复写同键 = UPSERT 覆盖');
      expect(kv.values.length, 3, reason: '始终只有三个键');
    });

    test('非法值（非数字 / NaN / ∞）回落缺省；越界值夹逼到值域', () async {
      final MemoryKv kv = MemoryKv();
      kv.values[SettingsKeys.railWidth] = 'abc';
      kv.values[SettingsKeys.railWidthExpanded] = 'NaN';
      kv.values[SettingsKeys.detailFraction] = 'Infinity';
      final ShellLayout fallback = await ShellLayoutStore(kv).read();
      expect(fallback.railWidth, ShellLayoutStore.defaultRailWidth);
      expect(fallback.railWidthExpanded, ShellLayoutStore.defaultRailWidth);
      expect(fallback.detailFraction, ShellLayoutStore.defaultDetailFraction);

      kv.values[SettingsKeys.railWidth] = '9999';
      kv.values[SettingsKeys.railWidthExpanded] = '-40';
      kv.values[SettingsKeys.detailFraction] = '0.99';
      final ShellLayout clamped = await ShellLayoutStore(kv).read();
      expect(clamped.railWidth, ShellLayoutStore.railMaxWidth);
      expect(clamped.railWidthExpanded, ShellLayoutStore.railMinWidth);
      expect(clamped.detailFraction, ShellLayoutStore.detailMaxFraction);
    });

    test('真实 drift：写进既有 settings 表（Queries 即 SearchSettingsKv，不新造表）', () async {
      final AppDatabase db = HeadlessEnv.openMemoryDb();
      addTearDown(db.close);
      final Queries queries = Queries(db);
      expect(queries, isA<SearchSettingsKv>());

      final ShellLayoutStore store = ShellLayoutStore(queries);
      await store.save(const ShellLayout(railWidth: 300, railWidthExpanded: 300, detailFraction: 0.55));
      expect((await store.read()).detailFraction, 0.55);

      final Setting? row = await (db.select(db.settings)
            ..where((Settings t) => t.key.equals(SettingsKeys.railWidth)))
          .getSingleOrNull();
      expect(row, isNotNull, reason: '落点 = settings 表的 rail_width 行');
      expect(row!.value, '300.0');
      final int extraTables = ((await db
                  .customSelect(
                      "SELECT COUNT(*) AS c FROM sqlite_master WHERE type='table' AND name LIKE '%layout%'")
                  .getSingle())
              .data['c']! as num)
          .toInt();
      expect(extraTables, 0, reason: '没有为布局记忆新建表');
    });
  });

  group('UI 恢复 / 写回（widget，内存端口）', () {
    late FakeBookRepository repo;

    setUp(() => repo = FakeBookRepository());

    Future<void> pumpShell(WidgetTester tester, {MemoryKv? kv}) async {
      useSurface(tester, width: 1440, height: 900);
      await tester.pumpWidget(
        testApp(
          repo,
          extraOverrides: <Override>[
            if (kv != null) shellLayoutStoreProvider.overrideWithValue(ShellLayoutStore(kv)),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('KV 有记录 → 重建后按记忆恢复（导航栏宽 + 详情占比）', (WidgetTester tester) async {
      final MemoryKv kv = MemoryKv();
      kv.values[SettingsKeys.railWidth] = '316';
      kv.values[SettingsKeys.railWidthExpanded] = '316';
      kv.values[SettingsKeys.detailFraction] = '0.6';

      await pumpShell(tester, kv: kv);

      expect(tester.getSize(find.byType(NavigationRail)).width, closeTo(316, 1),
          reason: '导航栏宽按记忆恢复（缺省 256）');
      // 详情分隔条中心 x = 316（导航栏）+ 8（分隔条）+ 中间栏（余量 40%）+ 4（半条）。
      // 占比 0.6 = 详情栏占 60% → 分隔条左移到 40% 处（缺省 0.4 时在 60% 处）。
      final double expected = 316 + 8 + (1440 - 316 - 16) * 0.4 + 4;
      expect(tester.getCenter(find.byTooltip('拖动 · 调整详情栏占比')).dx, closeTo(expected, 3),
          reason: '详情栏占比按记忆恢复');
    });

    testWidgets('拖分隔条 / 收起展开 → 三条键落 KV（拖动过程不写、结束才写）', (WidgetTester tester) async {
      final MemoryKv kv = MemoryKv();
      await pumpShell(tester, kv: kv);
      expect(kv.writes, 0, reason: '仅渲染不写盘');

      await longPressDrag(tester, find.byTooltip('拖动 · 调整导航栏宽度'), 60);
      expect(double.parse(kv.values[SettingsKeys.railWidth]!), closeTo(316, 1));
      final int writesAfterRailDrag = kv.writes;

      await longPressDrag(tester, find.byTooltip('拖动 · 调整详情栏占比'), -120);
      expect(kv.writes, greaterThan(writesAfterRailDrag), reason: '拖动结束才落盘');
      final double rest = 1440 - 316 - 16;
      expect(double.parse(kv.values[SettingsKeys.detailFraction]!), closeTo(0.4 + 120 / rest, 0.01),
          reason: '左拖 120 = 详情栏变宽 120/余量');

      await tester.tap(find.byTooltip('收起导航栏'));
      await tester.pumpAndSettle();
      expect(double.parse(kv.values[SettingsKeys.railWidth]!), 72);
      expect(double.parse(kv.values[SettingsKeys.railWidthExpanded]!), closeTo(316, 1),
          reason: '收起前的展开宽单独记，重新展开才回得去');

      await tester.tap(find.byTooltip('展开导航栏'));
      await tester.pumpAndSettle();
      expect(double.parse(kv.values[SettingsKeys.railWidth]!), closeTo(316, 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('内存仓不带 KV（widget 测试哨兵挂具）→ 记忆停用，拖拽仍正常且零异常', (WidgetTester tester) async {
      await pumpShell(tester);
      expect(tester.getSize(find.byType(NavigationRail)).width, 256, reason: '缺省展开宽');

      await longPressDrag(tester, find.byTooltip('拖动 · 调整导航栏宽度'), 60);
      expect(tester.getSize(find.byType(NavigationRail)).width, closeTo(316, 1));
      expect(tester.takeException(), isNull, reason: '端口缺失只是「不记忆」，不能抛错');
    });
  });
}
