/// 需求 3 守卫：搜索六维筛选 chips（年/月/旬/来源/类别 + 时间↓）不再固定两行，
/// 改为**单一 Wrap 按容器宽度自适应**：
///  · 宽容器 → 单行（6 颗 chip 中心 y 一致、x 沿 年→时间 递增）；
///  · 窄容器（360）→ 按宽度换行、零 overflow、chips 全在场；
///  · 竖屏 390×844 整页搜索 → 面板换行零异常、仍能出结果。
///
/// 分组与边界（TESTING.md §1/§3）：全部 testWidgets —— 布局用例直接 pump 面板子树
/// （视口即容器宽），不依赖整页 shell；整页用例走 testApp + FakeBookRepository
/// （纯内存微任务），假时钟区内零真实 IO。
library;

import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/features/search/filter_panel.dart';
import 'package:booksift/theme/book_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import '../support/harness.dart';
import 'online_search_test.dart' show kQuery, searchRoute;

/// 六颗 chip 的可见文案（面板内唯一 → 可直接按 text 定位）。
const List<String> kChipLabels = <String>[
  '年·全部',
  '月·全部',
  '旬·全部',
  '来源·全部',
  '类别·全部',
  '时间↓',
];

/// 面板子树挂具：视口宽即容器可用宽（不套整页 shell，直接验证「按宽自适应」）。
Widget panelApp(FakeBookRepository repo) {
  return ProviderScope(
    overrides: testOverrides(repo),
    child: MaterialApp(
      theme: BookTheme.light,
      darkTheme: BookTheme.dark,
      themeMode: ThemeMode.light,
      home: Scaffold(
        body: SearchFilterPanel(filter: const SearchFilter(), onConfirm: () {}),
      ),
    ),
  );
}

/// chip 文本中心 y → 舍入行号集合（同一 run 内中心 y 相同）。
Set<int> chipRows(WidgetTester tester) => <int>{
  for (final String label in kChipLabels) tester.getCenter(find.text(label)).dy.round(),
};

void main() {
  late FakeBookRepository repo;
  setUp(() => repo = FakeBookRepository(library: demoLibrary()));

  testWidgets('宽容器（1400）：6 颗 chip 单行——中心 y 一致，且 x 沿 年→时间 递增',
      (WidgetTester tester) async {
    useSurface(tester, width: 1400, height: 800);
    await tester.pumpWidget(panelApp(repo));
    await tester.pumpAndSettle();

    for (final String label in kChipLabels) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull, reason: '宽容器零 overflow');
    expect(chipRows(tester), hasLength(1), reason: '宽度足够 → 单行（不再固定两行）');

    final List<double> xs = <double>[
      for (final String label in kChipLabels) tester.getTopLeft(find.text(label)).dx,
    ];
    for (int i = 1; i < xs.length; i++) {
      expect(xs[i], greaterThan(xs[i - 1]),
          reason: 'chip 顺序不变（${kChipLabels[i - 1]} → ${kChipLabels[i]}）');
    }
  });

  testWidgets('窄容器（360）：按宽度智能换行、零 overflow、chips 全在场', (WidgetTester tester) async {
    useSurface(tester, width: 360, height: 800);
    await tester.pumpWidget(panelApp(repo));
    await tester.pumpAndSettle();

    for (final String label in kChipLabels) {
      expect(find.text(label), findsOneWidget);
    }
    expect(chipRows(tester).length, greaterThan(1),
        reason: '360 宽放不下 6 颗 chip → 换行（行数由宽度决定，非固定 2 行）');
    expect(tester.takeException(), isNull, reason: 'Wrap 换行不产生 RenderFlex overflow');
  });

  testWidgets('竖屏 390×844 搜索页：面板换行零异常、仍能出结果', (WidgetTester tester) async {
    useSurface(tester); // 390×844@3x compact
    await tester.pumpWidget(testApp(repo, initial: searchRoute(kQuery)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: '竖屏换行零 overflow');
    for (final String label in kChipLabels) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('1 结果'), findsOneWidget, reason: '竖屏搜索仍能出结果（$kQuery，demo 语料 1 条）');
  });
}
