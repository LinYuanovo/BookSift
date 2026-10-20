import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/collector/collect_providers.dart';
import 'package:booksift/collector/scheduler.dart'
    show CollectFailureKind, CollectRequestException;
import 'package:booksift/collector/tieba/src/models.dart' as models;
import 'package:booksift/collector/tieba_api.dart';
import 'package:booksift/features/home/cards.dart';

import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import '../support/harness.dart';

// 任务 3：贴吧在线帖详情页（/online/:id）。
//
// 全部 testWidgets 零真实网络（TESTING.md §1）：TiebaApi 接口级假实现
// （tieba_api.dart 注释指明的测试接缝）——纯 async 微任务，FakeAsync 区可冲刷；
// 加载态用 Completer 手工控制，避免 pumpAndSettle 等一个永不完成的 future。

/// 微任务级脚本化 TiebaApi（仅 getPosts 参与；getThreads 不该被本页调用）。
class _ScriptedTiebaApi implements TiebaApi {
  final Map<int, PostsPage> pages = <int, PostsPage>{};
  Object? error;

  /// 非 null 时 getPosts 挂起在 completer 上（加载态用例专用）。
  Completer<PostsPage>? pending;
  int calls = 0;

  @override
  Future<PostsPage> getPosts(int tid, {int pn = 1, int rn = 30}) {
    calls++;
    final Completer<PostsPage>? p = pending;
    if (p != null) {
      return p.future;
    }
    final Object? e = error;
    if (e != null) {
      return Future<PostsPage>.error(e);
    }
    return Future<PostsPage>.value(
      pages[pn] ??
          const PostsPage(floors: <models.FloorInfo>[], hasMore: false),
    );
  }

  @override
  Future<ThreadsPage> getThreads(String fname, {int pn = 1, int rn = 100}) =>
      Future<ThreadsPage>.error(StateError('在线帖页不应调用 getThreads'));

  @override
  void close() {}
}

models.FloorInfo _floor(int pid, int seq, String text) => models.FloorInfo(
  pid: pid,
  seq: seq,
  authorId: 1,
  author: '层主',
  time: 1760000000,
  text: text,
  images: const <models.ImageInfo>[], // 语料无图：CachedNetworkImage 会触真实网络/磁盘缓存
);

/// 捕获 Clipboard.setData（测试环境平台通道 mock，不触真实剪贴板）。
List<String> _mockClipboard(WidgetTester tester) {
  final List<String> copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map<dynamic, dynamic>)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}

/// mock「打开原帖」外链通道（core/external_launch.dart）：记录 url 并回报成功。
/// 测试环境 defaultTargetPlatform = android → 走原生定向分支；不 mock 会落到
/// url_launcher 的 MissingPluginException 分支（返回 false → 出「没有可打开原帖的应用」）。
List<String> _mockExternalLaunch(WidgetTester tester, {bool ok = true}) {
  final List<String> opened = <String>[];
  const MethodChannel channel = MethodChannel('booksift/external_launch');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (MethodCall call) async {
      opened.add((call.arguments as Map<dynamic, dynamic>)['url'] as String);
      return ok;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    ),
  );
  return opened;
}

void main() {
  group('在线帖详情页', () {
    late FakeBookRepository repo;
    late _ScriptedTiebaApi api;

    setUp(() {
      repo = FakeBookRepository(library: demoLibrary());
      api = _ScriptedTiebaApi();
    });

    Widget subject() => testApp(
      repo,
      initial: '/online/4242',
      extraOverrides: <Override>[tiebaApiProvider.overrideWithValue(api)],
    );

    testWidgets('按时间序渲染楼层（楼层头 + 富文本正文），AppBar 落帖子标题', (
      WidgetTester tester,
    ) async {
      api.pages[1] = PostsPage(
        floors: <models.FloorInfo>[
          _floor(11, 1, '本期主推《诡秘之主》，另见 https://tieba.baidu.com/p/4242 备份'),
          _floor(12, 2, '二楼补充《宿命之环》。'),
        ],
        hasMore: false,
        title: '在线扫书帖',
      );
      useSurface(tester);
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.text('在线扫书帖'), findsOneWidget, reason: 'AppBar 标题 = 线上帖标题');
      expect(find.text('1楼'), findsOneWidget);
      expect(find.text('2楼'), findsOneWidget);
      expect(find.textContaining('本期主推'), findsOneWidget);
      expect(find.textContaining('二楼补充'), findsOneWidget);
      expect(api.calls, 1, reason: 'hasMore=false 单页收口');
      // 楼层流接 ScrollChrome（常驻细滚动条）。
      expect(find.byType(Scrollbar), findsOneWidget);
    });

    testWidgets('「打开原帖」→ 外链通道拿到原帖 url（不再写剪贴板）', (WidgetTester tester) async {
      api.pages[1] = PostsPage(
        floors: <models.FloorInfo>[_floor(11, 1, '正文')],
        hasMore: false,
      );
      final List<String> copied = _mockClipboard(tester);
      final List<String> opened = _mockExternalLaunch(tester);
      useSurface(tester);
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('打开原帖'));
      await tester.pumpAndSettle();

      expect(opened, <String>['https://tieba.baidu.com/p/4242']);
      expect(copied, isEmpty, reason: '旧口径是复制到剪贴板，现已改为直接打开原帖');
    });

    testWidgets('加载态出骨架块，完成后渲染楼层', (WidgetTester tester) async {
      final Completer<PostsPage> gate = Completer<PostsPage>();
      api.pending = gate;
      useSurface(tester);
      await tester.pumpWidget(subject());
      await tester.pump();

      expect(find.byType(SkeletonBlock), findsWidgets);
      expect(find.text('1楼'), findsNothing);

      gate.complete(
        PostsPage(
          floors: <models.FloorInfo>[_floor(11, 1, '迟到的正文')],
          hasMore: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1楼'), findsOneWidget);
      expect(find.textContaining('迟到的正文'), findsOneWidget);
    });

    testWidgets('错误态：风控 → 分类文案 + 重试恢复（§8.12 口径）', (WidgetTester tester) async {
      api.error = const CollectRequestException(
        kind: CollectFailureKind.rateLimited,
        code: 110001,
        message: 'errorno=110001 需登录',
      );
      useSurface(tester);
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.text('触发贴吧风控'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);

      api.error = null;
      api.pages[1] = PostsPage(
        floors: <models.FloorInfo>[_floor(11, 1, '重试后的正文')],
        hasMore: false,
      );
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();

      expect(find.textContaining('重试后的正文'), findsOneWidget);
      expect(api.calls, 2, reason: '重试 = invalidate 重新拉取一次');
    });

    testWidgets('空态：线上无楼层 → 空态文案', (WidgetTester tester) async {
      api.pages[1] = const PostsPage(
        floors: <models.FloorInfo>[],
        hasMore: false,
      );
      useSurface(tester);
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.text('帖子没有可显示的楼层'), findsOneWidget);
    });
  });
}
