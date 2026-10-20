// 可访问性回归 · Dynamic Type（Phase 5「可访问性与性能预算复核」）。
//
// 核心页在系统字体缩放 textScaler=2.0（放大极限）与 0.85（缩小极限）下：
// 无 RenderFlex overflow、无未捕获布局/构建异常。
//
// 口径与限制（详见 docs/质量预算复核.md §3）：
//  - 视口 390×1600dp 定值；ListView/Sliver 懒构建 → 只覆盖可视范围内条目；
//  - 一律定步 pump（禁 pumpAndSettle：采集页 pulseRing 为无限动画，TESTING.md §1）；
//  - testWidgets 体内零真实 IO：数据走 FakeBookRepository，更新检查走脚本化 dio
//    （test/update/support.dart），字体走 harness fake（TESTING.md §3.1）。
//  - 溢出错误经 FlutterError.onError 收集后**显式断言**：范围外页面的已知违规
//    登记在 [_knownOut]（与 docs/质量预算复核.md 违规清单一一对应），其余一律判红。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/features/collect/collect_page.dart';
import 'package:booksift/features/profile/settings_page.dart';

import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import '../support/fake_collect.dart';
import '../support/harness.dart';
import '../update/support.dart';

/// 范围外（他人所有权）页面的**已知**溢出登记：页名 → 允许的溢出消息特征。
/// 每条必须对应 docs/质量预算复核.md 违规清单里的一行（file:line + 处置），
/// 修复后应从这里删除并让断言收紧。当前为空 = 无豁免。
const Map<String, List<String>> _knownOut = <String, List<String>>{};

/// 收集 pump 期间 FlutterError.reportError 的全部异常，按「溢出/其他」分桶。
class _ErrorSink {
  final List<String> overflows = <String>[];
  final List<String> others = <String>[];

  void handle(FlutterErrorDetails details) {
    final String msg = details.exceptionAsString();
    final String where = details.context?.toDescription() ?? details.library ?? '?';
    // informationCollector 里含 DiagnosticsDebugCreator（widget 归因链），整体截断保留。
    String creator = '';
    final Iterable<DiagnosticsNode>? info = details.informationCollector?.call();
    if (info != null) {
      final String joined = info.map((DiagnosticsNode n) => n.toStringDeep()).join(' | ');
      final int at = joined.indexOf('creator');
      creator = at >= 0 ? joined.substring(at, (at + 500).clamp(0, joined.length)) : '';
    }
    if (msg.contains('overflowed')) {
      overflows.add('$msg @ $where${creator.isEmpty ? '' : '\n  …$creator'}');
    } else {
      others.add('$msg @ $where');
    }
  }
}

void main() {
  late FakeBookRepository repo;
  late FakeCollectRunNotifier collectFake;

  setUp(() {
    repo = FakeBookRepository(library: demoLibrary());
    collectFake = FakeCollectRunNotifier();
  });

  /// 页面泵配方（路由/直挂 + 专属 override），全部内存 fake。
  Map<String, Widget Function()> pages() => <String, Widget Function()>{
    'home': () => testApp(repo, initial: '/home', rankToday: DateTime(2025, 4, 30)),
    'search': () => testApp(repo, initial: '/search'),
    'about': () => testApp(
      repo,
      initial: '/about',
      extraOverrides: updateTestOverrides(adapter: ScriptedAdapter(<String, ScriptedResponse>{})),
    ),
    'collect': () => testApp(
      repo,
      home: const CollectPage(),
      extraOverrides: collectTestOverrides(notifier: collectFake),
    ),
    'profile': () => testApp(repo, initial: '/profile'),
    'settings': () => testApp(
      repo,
      home: const SettingsPage(),
      extraOverrides: updateTestOverrides(adapter: ScriptedAdapter(<String, ScriptedResponse>{})),
    ),
    'rank': () => testApp(repo, initial: '/rank', rankToday: DateTime(2025, 4, 30)),
  };

  /// 在字体缩放 [scale] 下渲染一页，返回 (溢出, 其他异常) 两组消息。
  Future<({List<String> overflows, List<String> others})> pumpScaled(
    WidgetTester tester, {
    required String page,
    required double scale,
  }) async {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    useSurface(tester, height: 1600);

    final _ErrorSink sink = _ErrorSink();
    final FlutterExceptionHandler? previous = FlutterError.onError;
    FlutterError.onError = sink.handle;
    try {
      await tester.pumpWidget(pages()[page]!());
      // 定步推进：入场 stagger(≤580ms)/switch(300ms) 走完；采集页脉冲不 settle（禁挂死）。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(seconds: 1));
    } finally {
      FlutterError.onError = previous;
    }
    return (overflows: sink.overflows, others: sink.others);
  }

  for (final double scale in <double>[2.0, 0.85]) {
    group('Dynamic Type textScaler=$scale', () {
      // 逐页独立 testWidgets：失败即定位到页，不连坐。
      for (final String page in <String>[
        'home',
        'search',
        'about',
        'collect',
        'profile',
        'settings',
        'rank',
      ]) {
        testWidgets('$page 页无 overflow / 无未捕获异常', (WidgetTester tester) async {
          final ({List<String> overflows, List<String> others}) r = await pumpScaled(tester, page: page, scale: scale);

          final List<String> allowed = _knownOut[page] ?? const <String>[];
          final List<String> unexpected = r.overflows
              .where((String m) => !allowed.any(m.contains))
              .toList();
          expect(
            unexpected,
            isEmpty,
            reason: '$page@$scale 出现 RenderFlex 溢出（修复或按所有权登记 _knownOut + 报告）：\n'
                '${unexpected.take(8).join('\n')}',
          );
          expect(r.others, isEmpty, reason: '$page@$scale 存在非溢出异常：\n${r.others.take(4).join('\n')}');
        });
      }
    });
  }
}
