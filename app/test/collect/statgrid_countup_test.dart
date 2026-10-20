import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/collector/collect_state.dart';
import 'package:booksift/features/collect/stat_grid.dart';
import 'package:booksift/theme/book_theme.dart';

// CountUpInt 补间回归（真机 compact 竖屏「数字变化瞬间六格撑成全屏巨柱」bug）。
//
// 根因：count_up.dart 曾用 Tween<int>，其 lerp = begin+(end-begin)*t，int*double→double，
// 与声明返回类型 int 冲突 → 补间中途 build 抛「Cannot lerp between "0" and "N"」→ CountUpInt
// 退化为 ErrorWidget（RenderErrorBox 在无界高约束下自取 100000px）→ 该行 StatGrid 被撑成巨柱。
// 修复：改用 IntTween（lerp 结果 round() 回 int）。
//
// 断言：value 变化后 motion.normal(300ms) 补间窗口内逐 16ms 短帧 pump，StatGrid 的 RenderBox
// 高度须恒等于静止高度（不允许任何一帧突增）。修复前会在补间中途突增到 ~100000 并抛异常。
// 本用例零真实 IO（纯 widget + 假时钟短帧 pump，符合 TESTING.md §1）。

/// 承载一个可变 [CollectStats] 的 StatGrid（compact：ListView 无界高），暴露 bump 触发补间。
class _Host extends StatefulWidget {
  const _Host({required this.initial, this.columns = 3, this.stretch = false, this.boxHeight});

  final CollectStats initial;
  final int columns;
  final bool stretch;

  /// 非空 = 用有界高 SizedBox 包裹（模拟宽屏 stretch 档的有界行高）。
  final double? boxHeight;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late CollectStats stats = widget.initial;

  void bump(CollectStats next) => setState(() => stats = next);

  @override
  Widget build(BuildContext context) {
    final Widget grid = StatGrid(stats: stats, columns: widget.columns, stretch: widget.stretch);
    return MaterialApp(
      theme: BookTheme.light,
      home: Scaffold(
        body: widget.boxHeight == null
            ? ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: <Widget>[
                  const SizedBox(height: 120, child: ColoredBox(color: Color(0x22000000))),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: grid),
                ],
              )
            : Center(child: SizedBox(width: 358, height: widget.boxHeight, child: grid)),
      ),
    );
  }
}

/// 补间窗口（motion.normal=300ms）内逐 16ms 短帧 pump，回调每帧观测。
Future<void> stepThroughTween(WidgetTester tester, {int frames = 22}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  Future<double> pumpRest(WidgetTester tester, _Host host) async {
    await tester.pumpWidget(host);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // 初始补间（若有）收敛到静止
    return tester.getSize(find.byType(StatGrid)).height;
  }

  testWidgets('compact 竖屏：数字变化补间窗口内 StatGrid 高度恒定，不撑成巨柱', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // 静止基线（全 0：无补间，CountUpInt 直接落终值）。
    final double rest = await pumpRest(tester, const _Host(initial: CollectStats.zero()));
    expect(rest, lessThan(200), reason: '静止高度本应自然（≈151），实测 $rest');

    // 触发补间：0 → +72/+1013（复现真机「两个有数字的格子」）。
    tester.state<_HostState>(find.byType(_Host)).bump(
      const CollectStats(threadsAdded: 72, floorsAdded: 1013, entriesAdded: 0),
    );

    // 补间窗口内逐帧断言高度恒定；修复前此处会突增到 ~100000。
    for (int i = 0; i < 22; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final double h = tester.getSize(find.byType(StatGrid)).height;
      expect(h, rest, reason: '第 ${i + 1} 帧 StatGrid 高度突增：$h != $rest（补间未撑柱则应恒定）');
    }
    await tester.pump(const Duration(milliseconds: 400)); // 收敛
    expect(tester.getSize(find.byType(StatGrid)).height, rest);

    // 补间期间不得抛「Cannot lerp」；takeException 清空并断言为空。
    expect(tester.takeException(), isNull, reason: 'CountUpInt 补间抛异常（Tween<int> lerp 回归）');
  });

  testWidgets('宽屏 stretch 档：有界行高下补间窗口内 StatGrid 高度=给定行高，且不抛异常', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // stretch 档：有界高 200 的容器内铺满，补间不得改变这个高度。
    final double rest = await pumpRest(
      tester,
      const _Host(initial: CollectStats.zero(), columns: 6, stretch: true, boxHeight: 200),
    );
    expect(rest, closeTo(200, 2), reason: 'stretch 有界档应铺满给定行高，实测 $rest');

    tester.state<_HostState>(find.byType(_Host)).bump(
      const CollectStats(threadsAdded: 72, floorsAdded: 1013, entriesAdded: 58, skippedDup: 12),
    );
    await stepThroughTween(tester);
    expect(tester.getSize(find.byType(StatGrid)).height, closeTo(200, 2));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getSize(find.byType(StatGrid)).height, closeTo(200, 2));
    expect(tester.takeException(), isNull, reason: 'stretch 档补间同样不得抛 lerp 异常');
  });
}
