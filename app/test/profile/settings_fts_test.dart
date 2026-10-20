// 设置页「数据与存储」渲染测试（docs/2026-10-20_FTS索引可选化改造方案.md §8）。
//
// testWidgets 全内存：harness 的 appDatabaseProvider 哨兵 + NoopSeedImporter；
// _FtsIndexSection._load 的路径解析失败会回落 full，不阻塞渲染（零真实 IO）。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booksift/features/profile/settings_page.dart';

import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import '../support/harness.dart';

void main() {
  testWidgets('数据与存储：渲染三档 / 重建索引 / 删除索引', (WidgetTester tester) async {
    await tester.pumpWidget(testApp(
      FakeBookRepository(library: demoLibrary()),
      home: const SettingsPage(),
    ));
    await tester.pumpAndSettle();

    final Finder scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('全文索引'), 400, scrollable: scrollable);
    expect(find.text('数据与存储'), findsOneWidget);
    expect(find.text('全文索引'), findsOneWidget);
    expect(find.text('重建索引'), findsOneWidget);
    expect(find.text('删除索引'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);
    expect(find.text('基础'), findsOneWidget);
    expect(find.text('完整'), findsOneWidget);
  });
}
