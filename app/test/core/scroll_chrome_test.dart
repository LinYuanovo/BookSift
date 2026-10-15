import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booksift/core/widgets/scroll_chrome.dart';

import '../support/fake_book_repository.dart';
import '../support/harness.dart';

void main() {
  testWidgets('ScrollChrome: 滚动时显示跳转按钮，停留后隐藏；跳底/跳顶生效', (WidgetTester tester) async {
    useSurface(tester);
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(testApp(
      FakeBookRepository(),
      home: Scaffold(
        body: ScrollChrome(
          controller: controller,
          child: ListView.builder(
            controller: controller,
            itemCount: 200,
            itemBuilder: (BuildContext context, int i) => SizedBox(height: 60, child: Text('row $i')),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    // 初始：内容可滚动但无滚动活动 → 按钮透明（ IgnorePointer 不响应）。
    AnimatedOpacity panel = tester.widget(find.byType(AnimatedOpacity));
    expect(panel.opacity, 0);

    // 滚动 → 按钮出现。
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump();
    panel = tester.widget(find.byType(AnimatedOpacity));
    expect(panel.opacity, 1);

    // 停留超过隐藏计时 → 按钮消失。
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pump();
    panel = tester.widget(find.byType(AnimatedOpacity));
    expect(panel.opacity, 0);

    // 再滚动 → 跳底 → 接近 maxScrollExtent。
    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pump();
    await tester.tap(find.byTooltip('跳到底部'));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(1000));

    // 跳顶 → 回到 0。
    await tester.tap(find.byTooltip('跳到顶部'));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
  });
}
