// 搜索结果浏览位置记忆（C）：签名口径 + settings KV 存储（LRU 32）+ UI 恢复/写回。
//
// 分组与边界（TESTING.md §1/§3）：
//  · 「签名 / 存储」plain test() —— SearchPositionStore 是纯 KV + JSON 逻辑，内存端口
//    即可断言；另有一例走真实 drift 内存库，证明落点确实是既有 settings 表（不新造表）。
//  · 「UI 恢复 / 写回」testWidgets —— searchPositionStoreProvider 注入内存端口的
//    SearchPositionStore（纯微任务，假时钟区安全），零真实 IO。
library;

import 'dart:convert';

import 'package:booksift/core/constants.dart';
import 'package:booksift/core/widgets/scroll_chrome.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/features/search/search_state.dart';
import 'package:booksift/headless/env.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import '../support/harness.dart';

/// 筛选行收起动画的外层容器 key（search_page.dart 里 AnimatedCrossFade 的 key）。
const ValueKey<String> kFilterCollapseKey = ValueKey<String>('search-filter-collapse');

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

  /// 已存的位置 map（保序 = LRU 新旧序）。
  Map<String, dynamic> get positions =>
      jsonDecode(values[SettingsKeys.searchPositions]!) as Map<String, dynamic>;
}

void main() {
  group('条件签名', () {
    test('分页 limit/offset 不进签名（同一条件翻到第几页仍是同一次浏览）', () {
      const SearchFilter base = SearchFilter(query: '十日终焉');
      expect(
        searchPositionSignature(base.copyWith(limit: 80, offset: 0)),
        searchPositionSignature(base.copyWith(limit: 40, offset: 0)),
      );
      expect(searchPositionSignature(base), searchPositionSignature(base.copyWith(limit: 400)));
    });

    test('六维与排序各自独立成键；空条件（条件浏览）也是稳定签名', () {
      const SearchFilter none = SearchFilter();
      final Set<String> sigs = <String>{
        searchPositionSignature(none),
        searchPositionSignature(const SearchFilter(query: '十日终焉')),
        searchPositionSignature(const SearchFilter(year: '2025')),
        searchPositionSignature(const SearchFilter(month: '4')),
        searchPositionSignature(const SearchFilter(tenDay: TenDayFilter.upper)),
        searchPositionSignature(const SearchFilter(channel: 'yy小说吧')),
        searchPositionSignature(const SearchFilter(category: CategoryKind.avoid)),
        searchPositionSignature(const SearchFilter(sort: SearchSort.timeAsc)),
      };
      expect(sigs, hasLength(8), reason: '只筛选不搜索 / 不搜索不筛选 / 换排序 互不串位');
      expect(searchPositionSignature(none), searchPositionSignature(const SearchFilter(limit: 120)));
    });

    test('搜索词含分隔符也不串味（「年|2025」不等于「年 + 2025」两个条件）', () {
      expect(
        searchPositionSignature(const SearchFilter(query: 'x|2025')),
        isNot(searchPositionSignature(const SearchFilter(query: 'x', year: '2025'))),
      );
    });
  });

  group('存储（settings KV + LRU 32）', () {
    test('save → read 往返；JSON map 落在 SettingsKeys.searchPositions', () async {
      final MemoryKv kv = MemoryKv();
      final SearchPositionStore store = SearchPositionStore(kv);
      expect(await store.read('sig-a'), isNull);

      await store.save('sig-a', 123.5);
      expect(await store.read('sig-a'), 123.5);
      expect(kv.values.keys, <String>[SettingsKeys.searchPositions], reason: '只用一个 settings 键');
      expect(kv.positions, <String, dynamic>{'sig-a': 123.5});
    });

    test('超出 32 条按 LRU 淘汰最久未用者', () async {
      final MemoryKv kv = MemoryKv();
      final SearchPositionStore store = SearchPositionStore(kv);
      for (int i = 0; i < SearchPositionStore.maxEntries + 2; i++) {
        await store.save('sig-$i', i.toDouble());
      }
      expect(kv.positions, hasLength(SearchPositionStore.maxEntries));
      expect(await store.read('sig-0'), isNull, reason: '最久未用者被淘汰');
      expect(await store.read('sig-1'), isNull);
      expect(await store.read('sig-2'), 2.0, reason: '其余保留');
      expect(await store.read('sig-${SearchPositionStore.maxEntries + 1}'), isNotNull);
    });

    test('重复 save 同一签名 = 提到最近使用末尾（不会被先淘汰）', () async {
      final MemoryKv kv = MemoryKv();
      final SearchPositionStore store = SearchPositionStore(kv);
      for (int i = 0; i < SearchPositionStore.maxEntries; i++) {
        await store.save('sig-$i', i.toDouble());
      }
      await store.save('sig-0', 999); // 刷新最旧的一条
      await store.save('sig-new', 1); // 再挤进一条 → 淘汰当前的最旧者 sig-1
      expect(await store.read('sig-0'), 999);
      expect(await store.read('sig-1'), isNull);
      expect(kv.positions.keys.last, 'sig-new');
    });

    test('脏数据（非 JSON / 非 map / 值非数值）不抛，回落「无记忆」', () async {
      final MemoryKv kv = MemoryKv()..values[SettingsKeys.searchPositions] = 'not-json{';
      final SearchPositionStore store = SearchPositionStore(kv);
      expect(await store.read('sig-a'), isNull);

      kv.values[SettingsKeys.searchPositions] = '[1,2,3]';
      expect(await store.read('sig-a'), isNull);

      kv.values[SettingsKeys.searchPositions] = '{"sig-a":"abc","sig-b":12}';
      expect(await store.read('sig-a'), isNull, reason: '值不是数字 → 丢弃');
      expect(await store.read('sig-b'), 12.0, reason: '合法条目照常读出');
    });

    test('真实 drift：写进既有 settings 表（Queries 即 SearchSettingsKv，不新造表）', () async {
      final AppDatabase db = HeadlessEnv.openMemoryDb();
      addTearDown(db.close);
      final Queries queries = Queries(db);
      expect(queries, isA<SearchSettingsKv>());

      final SearchPositionStore store = SearchPositionStore(queries);
      await store.save('sig-real', 42);
      expect(await store.read('sig-real'), 42.0);

      final Setting? row = await (db.select(db.settings)
            ..where((Settings t) => t.key.equals(SettingsKeys.searchPositions)))
          .getSingleOrNull();
      expect(row, isNotNull, reason: '落点 = settings 表的 search_positions 行');
      expect(jsonDecode(row!.value), <String, dynamic>{'sig-real': 42});
      final int tables = ((await db
                  .customSelect("SELECT COUNT(*) AS c FROM sqlite_master WHERE type='table' AND name LIKE '%position%'")
                  .getSingle())
              .data['c']! as num)
          .toInt();
      expect(tables, 0, reason: '没有为位置记忆新建表');
    });
  });

  group('搜索草稿持久化（关 App 重开恢复）', () {
    test('save → read 往返：词 + 六维 + 排序 + 提交态落 settings KV', () async {
      final MemoryKv kv = MemoryKv();
      final SearchDraftStore store = SearchDraftStore(kv);
      expect(await store.read(), isNull);

      await store.save(const SearchDraft(
        filter: SearchFilter(query: '十日终焉', year: '2025', category: CategoryKind.avoid),
        submitted: true,
      ));
      final SearchDraft? back = await store.read();
      expect(back, isNotNull);
      expect(back!.submitted, isTrue);
      expect(back.filter.query, '十日终焉');
      expect(back.filter.year, '2025');
      expect(back.filter.category, CategoryKind.avoid);
      expect(kv.values.keys, <String>[SettingsKeys.searchDraft]);
    });

    test('未提交草稿也往返（词在、submitted=false）', () async {
      final MemoryKv kv = MemoryKv();
      final SearchDraftStore store = SearchDraftStore(kv);
      await store.save(const SearchDraft(filter: SearchFilter(query: 'abc')));
      final SearchDraft? back = await store.read();
      expect(back!.submitted, isFalse);
      expect(back.filter.query, 'abc');
    });

    test('脏数据不抛，回落 null（当无草稿）', () async {
      final MemoryKv kv = MemoryKv()..values[SettingsKeys.searchDraft] = 'not-json{';
      expect(await SearchDraftStore(kv).read(), isNull);
    });

    testWidgets('重开恢复：settings 有已提交草稿 → 直接展示结果区（非搜索台）', (WidgetTester tester) async {
      final FakeBookRepository r = FakeBookRepository(library: demoLibrary());
      final MemoryKv kv = MemoryKv();
      await SearchDraftStore(kv).save(
        const SearchDraft(filter: SearchFilter(query: '十日终焉'), submitted: true),
      );
      useSurface(tester);
      await tester.pumpWidget(testApp(
        r,
        initial: '/search',
        extraOverrides: <Override>[
          searchDraftStoreProvider.overrideWithValue(SearchDraftStore(kv)),
        ],
      ));
      await tester.pumpAndSettle();
      expect(find.text('搜索历史'), findsNothing, reason: '不是搜索台（console）');
      expect(find.text('1 结果'), findsOneWidget, reason: '恢复已提交草稿 → 直接出结果');
    });
  });

  group('搜索页恢复 / 写回', () {
    late FakeBookRepository repo;
    late MemoryKv kv;
    setUp(() {
      repo = FakeBookRepository(library: demoLibrary());
      kv = MemoryKv();
    });

    Widget subject() => testApp(
          repo,
          initial: '/search?q=', // 空词提交 = 条件浏览（6 书组，超一屏可滚）
          extraOverrides: <Override>[
            searchPositionStoreProvider.overrideWithValue(SearchPositionStore(kv)),
          ],
        );

    double offsetOf(WidgetTester tester) =>
        tester.widget<ScrollChrome>(find.byType(ScrollChrome)).controller.offset;

    testWidgets('有记忆 → 结果首帧后无动画恢复到上次偏移；筛选行不被误判成「下滑」而收起',
        (WidgetTester tester) async {
      kv.values[SettingsKeys.searchPositions] =
          jsonEncode(<String, double>{searchPositionSignature(const SearchFilter()): 100});
      useSurface(tester, height: 600);
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.text('条件浏览', skipOffstage: false), findsOneWidget, reason: '结果头行随列表滚出视口');
      expect(offsetOf(tester), 100, reason: '恢复到记忆的偏移');
      // 与「下滑收起筛选行」启发式互不干扰：恢复出的偏移不算用户下滑。
      expect(tester.getSize(find.byKey(kFilterCollapseKey)).height, greaterThan(0), reason: '筛选行仍展开');
    });

    testWidgets('记忆偏移超过当前可滚范围 → 夹到 maxScrollExtent（页数不同也不跳飞）',
        (WidgetTester tester) async {
      kv.values[SettingsKeys.searchPositions] =
          jsonEncode(<String, double>{searchPositionSignature(const SearchFilter()): 999999});
      useSurface(tester, height: 600);
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      final ScrollController controller = tester.widget<ScrollChrome>(find.byType(ScrollChrome)).controller;
      expect(controller.offset, controller.position.maxScrollExtent);
      expect(controller.offset, lessThan(999999));
    });

    testWidgets('无记忆 / 条件变了 → 停在顶部，不恢复别的条件的位置', (WidgetTester tester) async {
      // 记的是「2025 年」条件的位置，进来的是无条件浏览 → 不该恢复。
      kv.values[SettingsKeys.searchPositions] =
          jsonEncode(<String, double>{searchPositionSignature(const SearchFilter(year: '2025')): 200});
      useSurface(tester, height: 600);
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      expect(offsetOf(tester), 0);
    });

    testWidgets('用户滚动 → 滚动结束立即写回（不等 400ms 防抖）', (WidgetTester tester) async {
      useSurface(tester, height: 600);
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      expect(kv.writes, 0, reason: '刚进页面不写');

      // 拖动（手势上拖 → 下滑）结束后立即写回一次；无需等防抖到点。
      await tester.drag(find.byType(ScrollChrome), const Offset(0, -300));
      await tester.pump(); // 只推进一帧：若靠 400ms 防抖，此刻还不该写
      expect(offsetOf(tester), greaterThan(0));
      expect(kv.writes, 1, reason: '滚动结束 → 立即写回一次（不等 400ms 防抖）');
      final double saved = (kv.positions.values.single as num).toDouble();
      expect(saved, offsetOf(tester), reason: '写回的就是当前偏移');
      expect(
        kv.positions.keys.single,
        searchPositionSignature(const SearchFilter()),
        reason: '键 = 当前条件签名',
      );
    });

    testWidgets('关 App 重开往返：滚动 → 关闭（dispose）→ 重开 → 恢复到上次偏移', (WidgetTester tester) async {
      useSurface(tester, height: 600);
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ScrollChrome), const Offset(0, -300));
      await tester.pumpAndSettle();
      final double scrolled = offsetOf(tester);
      expect(scrolled, greaterThan(0));
      // 防抖到点写回。
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // 模拟关闭 App：整树卸载（dispose 里还有一次 best-effort 写回）。
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      // 重开：同一 KV（生产 = 同一 settings 表）。
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      expect(offsetOf(tester), closeTo(scrolled, 1.0), reason: '关 App 重开恢复到上次浏览偏移');
    });

    testWidgets('目录跳转（程序化滚动）期间不写回位置', (WidgetTester tester) async {
      useSurface(tester, height: 600);
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('目录'));
      await tester.pumpAndSettle();
      final Finder tiles = find.descendant(of: find.byType(BottomSheet), matching: find.byType(ListTile));
      expect(tiles, findsNWidgets(6));
      await tester.tap(tiles.last);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(offsetOf(tester), greaterThan(0), reason: '确实跳转滚动了');

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(kv.writes, 0, reason: '程序化滚动不污染用户浏览位置');
    });
  });
}
