/// M3 P2-2 贴吧在线搜索（c/s/searchpost 匿名 app-form 通道）测试。
///
/// 分组与边界（TESTING.md §1/§3）：
///  · 「sign 签名向量」plain test() —— 期望 MD5 **写死**，已与 aiotieba
///    `helper/crypto/sign.py compute_sign`（python 实测输出）+ 手算 hashlib.md5 双核对；
///  · 「请求装配 / 响应解析 / 风控」plain test() —— mock dio adapter 脚本化 JSON/错误，
///    零真实网络、零真实 IO（节流 min=max=0 免真等）；
///  · 「在线搜索 UI」testWidgets —— 双 Tab / 手动触发 / 复制钮复制链接 / 空·错误态 /
///    零 Material Icon 守卫；全部内存 fake + mock dio，假时钟区内只有微任务与零时长 Timer。
///
/// 真实网络冒烟在**独立文件** online_search_smoke_test.dart（同 suite 混入 testWidgets 后
/// TestWidgetsFlutterBinding 会把真实 HttpClient 一律 400，冒烟永不可达网络）。
library;

import 'dart:convert';

import 'package:booksift/collector/scheduler.dart' show CollectFailureKind, CollectRequestException;
import 'package:booksift/collector/tieba_search.dart';
import 'package:booksift/core/icons.dart';
import 'package:booksift/features/search/search_page.dart';
import 'package:booksift/features/search/search_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import '../support/harness.dart';

// ─────────────────────── mock dio（零真实网络） ───────────────────────

/// 脚本化 dio adapter：按序回放预置响应，并记录每次请求（uri/headers/urlencoded body）。
/// 脚本耗尽 = 编程错误，抛 StateError（配合 requests 计数断言防自动批量）。
class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter(this.script);

  final List<ResponseBody> script;
  final List<RequestOptions> requests = <RequestOptions>[];
  final List<String> bodies = <String>[];
  int _next = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // 消费请求流拿到真实 wire body（纯内存流，微任务完成，FakeAsync 区安全）。
    final List<int> bytes =
        requestStream == null ? <int>[] : await requestStream.expand((List<int> x) => x).toList();
    requests.add(options);
    bodies.add(utf8.decode(bytes));
    if (_next >= script.length) {
      throw StateError('ScriptedAdapter 脚本耗尽（第 ${_next + 1} 个请求）——不应有自动批量请求');
    }
    return script[_next++];
  }

  @override
  void close({bool force = false}) {}
}

/// 网络层异常 adapter（模拟连接超时，无响应对象）。
class _TimeoutAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionTimeout,
      message: '测试注入 connectionTimeout',
    );
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(String text, {int status = 200}) => ResponseBody.fromString(
      text,
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json; charset=utf-8'],
      },
    );

ResponseBody htmlBody(String text, {int status = 200}) => ResponseBody.fromString(
      text,
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['text/html; charset=utf-8'],
      },
    );

TiebaSearchClient scriptedClient(HttpClientAdapter adapter) => TiebaSearchClient(
      dio: Dio()..httpClientAdapter = adapter,
      minIntervalMs: 0, // 免真等；生产默认 1500~3000（下方口径测试单独断言）
      maxIntervalMs: 0,
    );

// ─────────────────────── 响应 JSON fixture ───────────────────────

/// searchpost post_list 单条（字段名 = aiotieba _classdef.py SearchInForum.from_json 口径）。
Map<String, dynamic> postItem({
  Object tid = 101,
  String title = '【扫书】十日终焉',
  String fname = 'yy小说吧',
  String author = '扫书人甲',
  int time = 1760000000,
  int replyNum = 12,
}) =>
    <String, dynamic>{
      'tid': tid,
      'title': title,
      'content': '正文片段：《十日终焉》强烈推荐',
      'fname': fname,
      'is_floor': 0,
      'pid': 9001,
      'cid': 0,
      'time': time,
      'reply_num': replyNum,
      'author': <String, dynamic>{'name_show': author, 'name': 'u_$author'},
    };

/// Page_fsch（_classdef.py：has_more 等为 int 0/1）。
Map<String, dynamic> pageInfo({
  int hasMore = 0,
  int currentPage = 1,
  int totalPage = 1,
  int totalCount = 0,
}) =>
    <String, dynamic>{
      'page_size': 30,
      'current_page': currentPage,
      'total_page': totalPage,
      'total_count': totalCount,
      'has_more': hasMore,
      'has_prev': 0,
    };

String searchJson({
  List<Map<String, dynamic>> posts = const <Map<String, dynamic>>[],
  Map<String, dynamic>? page,
  String errorCode = '0',
  String errorMsg = '',
}) =>
    jsonEncode(<String, dynamic>{
      'error_code': errorCode,
      'error_msg': errorMsg,
      'post_list': posts,
      'page': ?page,
    });

// ─────────────────────── UI 挂具 ───────────────────────

const String kQuery = '十日终焉';

String searchRoute(String q) => '/search?q=${Uri.encodeComponent(q)}';

/// 捕获 Clipboard.setData 的文本（测试环境平台通道 mock，不触真实剪贴板）。
List<String> mockClipboard(WidgetTester tester) {
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
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  return copied;
}

/// mock「打开原帖」外链通道（core/external_launch.dart 的 booksift/external_launch）：
/// 记录每次要打开的 url 并回报成功。测试环境 defaultTargetPlatform = android，
/// 故走的是原生定向分支；不 mock 的话会落到 url_launcher 的 MissingPluginException
/// 分支（openThreadExternally 返回 false → SnackBar「没有可打开原帖的应用」）。
List<String> mockExternalLaunch(WidgetTester tester, {bool ok = true}) {
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
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
  );
  return opened;
}

Widget onlineApp(FakeBookRepository repo, ScriptedAdapter adapter, {required String initial}) =>
    testApp(repo, initial: initial, extraOverrides: <Override>[
      tiebaSearchClientProvider.overrideWithValue(scriptedClient(adapter)),
    ]);

/// 切到在线 Tab 并手动触发一次搜索（返回时首个脚本响应已消费）。
Future<void> gotoOnlineAndSearch(WidgetTester tester) async {
  await tester.tap(find.text('贴吧在线'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('搜索贴吧'));
  await tester.pumpAndSettle();
}

void main() {
  // ── sign 签名向量（§8.4；期望值写死，出处见文件头） ─────────────────────

  group('sign 签名向量（§8.4：key 字典序拼接 + APP_SALT + MD5 小写 hex）', () {
    test('完整参数向量（含中文 UTF-8；期望 = aiotieba compute_sign 实测输出）', () {
      // 拼接串 = _client_type=2_client_version=22.12.1.0kw=yy小说吧only_thread=1pn=1rn=30sm=0word=十日终焉
      //          + tiebaclient!!!
      expect(
        computeFormSign(<String, String>{
          '_client_type': '2',
          '_client_version': '22.12.1.0',
          'kw': 'yy小说吧',
          'only_thread': '1',
          'pn': '1',
          'rn': '30',
          'sm': '0',
          'word': '十日终焉',
        }),
        'df64b52b5f2ea6bc529ef0810d2ef341',
      );
    });

    test('最小 ASCII 向量：md5("kw=abcword=xtiebaclient!!!")', () {
      expect(
        computeFormSign(<String, String>{'kw': 'abc', 'word': 'x'}),
        '7ef2847d91b2633c718a6b2322952ce5',
      );
    });

    test('与插入顺序无关（按 key 字典序升序，`_` < 小写字母）', () {
      final String a = computeFormSign(<String, String>{
        'word': 'x',
        'sm': '0',
        'kw': 'abc',
        '_client_version': '22.12.1.0',
      });
      final String b = computeFormSign(<String, String>{
        '_client_version': '22.12.1.0',
        'kw': 'abc',
        'sm': '0',
        'word': 'x',
      });
      expect(a, b);
    });
  });

  // ── 请求装配（aiotieba search_in_forum/_api.py + pack_form_request 口径） ──

  group('请求装配', () {
    test('POST urlencoded → c/s/searchpost：8 固定参数 + sign 自洽，版本 22.12.1.0', () async {
      final ScriptedAdapter adapter = ScriptedAdapter(<ResponseBody>[jsonBody(searchJson())]);
      final TiebaSearchClient client = scriptedClient(adapter);
      addTearDown(client.close);
      await client.search('yy小说吧', '十日终焉', pn: 2);

      final RequestOptions req = adapter.requests.single;
      expect(req.uri.toString(), 'http://tiebac.baidu.com/c/s/searchpost');
      expect(req.method, 'POST');
      expect(req.headers['Content-Type'], contains('application/x-www-form-urlencoded'));
      expect(req.headers['User-Agent'], 'aiotieba/22.12.1.0');

      final Map<String, String> form = Uri.splitQueryString(adapter.bodies.single);
      expect(form.keys.toSet(), <String>{
        '_client_type', '_client_version', 'kw', 'only_thread', 'pn', 'rn', 'sm', 'word', 'sign',
      });
      expect(form['_client_type'], '2');
      expect(form['_client_version'], '22.12.1.0', reason: 'searchpost 用 LATEST（§8.2 行 1950）');
      expect(form['kw'], 'yy小说吧');
      expect(form['word'], '十日终焉');
      expect(form['pn'], '2');
      expect(form['rn'], '30');
      expect(form['sm'], '0');
      expect(form['only_thread'], '0', reason: '客户端默认 false（aiotieba search_in_forum 口径）');
      // sign 与其余参数重算一致（装配自洽；绝对向量已在上一组写死）。
      final Map<String, String> unsigned = Map<String, String>.from(form)..remove('sign');
      expect(form['sign'], computeFormSign(unsigned));
      expect(client.risk.requests, 1);
      expect(client.risk.totalAnomalies, 0);
    });

    test('默认节流口径 ≥1.5s（1500~3000ms 均匀抖动，§8.11 匿名档）', () {
      final TiebaSearchClient client = TiebaSearchClient();
      addTearDown(client.close);
      expect(client.minIntervalMs, 1500);
      expect(client.maxIntervalMs, 3000);
    });
  });

  // ── 响应解析 / 错误 / 风控（RiskMonitor 口径） ─────────────────────────

  group('响应解析与风控', () {
    test('post_list/page → OnlineThread + hasMore（string 数值宽松、<em> 剥离、tid=0 跳过）', () async {
      final ScriptedAdapter adapter = ScriptedAdapter(<ResponseBody>[
        jsonBody(searchJson(
          posts: <Map<String, dynamic>>[
            postItem(tid: 101, title: '<em>十日终焉</em>扫书帖', replyNum: 12, time: 1760000000),
            postItem(tid: '202', title: '求书帖', author: '书荒人乙', fname: '哀伤雪刃', replyNum: 0, time: 0),
            postItem(tid: 0, title: '已删帖'),
          ],
          page: pageInfo(hasMore: 1, currentPage: 1, totalPage: 3, totalCount: 80),
        )),
      ]);
      final TiebaSearchClient client = scriptedClient(adapter);
      addTearDown(client.close);
      final OnlineSearchPage page = await client.search('yy小说吧', '十日终焉');

      expect(page.threads, hasLength(2), reason: 'tid=0 跳过');
      final OnlineThread t0 = page.threads[0];
      expect(t0.tid, 101);
      expect(t0.title, '十日终焉扫书帖', reason: '<em> 高亮标签剥离');
      expect(t0.forumName, 'yy小说吧');
      expect(t0.author, '扫书人甲');
      expect(t0.replyNum, 12);
      expect(t0.createTime, 1760000000);
      expect(t0.url, 'https://tieba.baidu.com/p/101');
      expect(page.threads[1].tid, 202, reason: 'string tid 宽松解析');
      expect(page.hasMore, isTrue);
      expect(page.currentPage, 1);
      expect(page.totalPage, 3);
      expect(page.totalCount, 80);
      expect(client.risk.totalAnomalies, 0);
      expect(client.risk.consecutiveFailures, 0);
    });

    test('data 包裹口径兼容（§8.3④ 示例形态）+ page 缺失宽松（hasMore=false）', () async {
      final ScriptedAdapter adapter = ScriptedAdapter(<ResponseBody>[
        jsonBody(jsonEncode(<String, dynamic>{
          'error_code': '0',
          'error_msg': '',
          'data': <String, dynamic>{
            'post_list': <Map<String, dynamic>>[postItem(tid: 7)],
          },
        })),
      ]);
      final TiebaSearchClient client = scriptedClient(adapter);
      addTearDown(client.close);
      final OnlineSearchPage page = await client.search('f', 'x');
      expect(page.threads.single.tid, 7);
      expect(page.hasMore, isFalse);
    });

    test('error_code≠0 → CollectRequestException(serverError) + errorno 计数', () async {
      final ScriptedAdapter adapter = ScriptedAdapter(<ResponseBody>[
        jsonBody(searchJson(errorCode: '4', errorMsg: '参数错误')),
      ]);
      final TiebaSearchClient client = scriptedClient(adapter);
      addTearDown(client.close);
      await expectLater(
        client.search('f', 'x'),
        throwsA(isA<CollectRequestException>()
            .having((CollectRequestException e) => e.kind, 'kind', CollectFailureKind.serverError)
            .having((CollectRequestException e) => e.code, 'code', 4)),
      );
      expect(client.risk.errornoCount, 1);
      expect(client.risk.consecutiveFailures, 1);
      expect(client.risk.totalAnomalies, 1);
    });

    test('errorno=110001 → rateLimited（§8.12 风控档 110xxx）', () async {
      final ScriptedAdapter adapter = ScriptedAdapter(<ResponseBody>[
        jsonBody(searchJson(errorCode: '110001', errorMsg: '需登录')),
      ]);
      final TiebaSearchClient client = scriptedClient(adapter);
      addTearDown(client.close);
      await expectLater(
        client.search('f', 'x'),
        throwsA(isA<CollectRequestException>()
            .having((CollectRequestException e) => e.kind, 'kind', CollectFailureKind.rateLimited)
            .having((CollectRequestException e) => e.code, 'code', 110001)),
      );
      expect(client.risk.errornoCount, 1);
    });

    test('验证码页/HTML 特征 → rateLimited + captchaCount', () async {
      final ScriptedAdapter adapter = ScriptedAdapter(<ResponseBody>[
        htmlBody('<html><body>安全验证，请完成验证后继续访问</body></html>'),
      ]);
      final TiebaSearchClient client = scriptedClient(adapter);
      addTearDown(client.close);
      await expectLater(
        client.search('f', 'x'),
        throwsA(isA<CollectRequestException>()
            .having((CollectRequestException e) => e.kind, 'kind', CollectFailureKind.rateLimited)),
      );
      expect(client.risk.captchaCount, 1);
      expect(client.risk.consecutiveFailures, 1);
    });

    test('HTTP 429 → rateLimited + httpErrorCount（风控特征）', () async {
      final ScriptedAdapter adapter = ScriptedAdapter(<ResponseBody>[
        jsonBody('{"error_code":"0"}', status: 429),
      ]);
      final TiebaSearchClient client = scriptedClient(adapter);
      addTearDown(client.close);
      await expectLater(
        client.search('f', 'x'),
        throwsA(isA<CollectRequestException>()
            .having((CollectRequestException e) => e.kind, 'kind', CollectFailureKind.rateLimited)
            .having((CollectRequestException e) => e.code, 'code', 429)),
      );
      expect(client.risk.httpErrorCount, 1);
    });

    test('连接超时 → network + networkErrorCount', () async {
      final TiebaSearchClient client = TiebaSearchClient(
        dio: Dio()..httpClientAdapter = _TimeoutAdapter(),
        minIntervalMs: 0,
        maxIntervalMs: 0,
      );
      addTearDown(client.close);
      await expectLater(
        client.search('f', 'x'),
        throwsA(isA<CollectRequestException>()
            .having((CollectRequestException e) => e.kind, 'kind', CollectFailureKind.network)),
      );
      expect(client.risk.networkErrorCount, 1);
    });

    test('非法 JSON → TiebaSearchFormatException（疑似接口变更，§8.12）', () async {
      final ScriptedAdapter adapter = ScriptedAdapter(<ResponseBody>[
        jsonBody('这不是 JSON{{'),
      ]);
      final TiebaSearchClient client = scriptedClient(adapter);
      addTearDown(client.close);
      await expectLater(client.search('f', 'x'), throwsA(isA<TiebaSearchFormatException>()));
      expect(client.risk.errornoCount, 1, reason: '协议级异常计入 errorno 档（totalAnomalies 口径完整）');
      expect(client.risk.consecutiveFailures, 1);
    });

    test('缺 post_list → TiebaSearchFormatException', () async {
      final ScriptedAdapter adapter = ScriptedAdapter(<ResponseBody>[
        jsonBody('{"error_code":"0","error_msg":""}'),
      ]);
      final TiebaSearchClient client = scriptedClient(adapter);
      addTearDown(client.close);
      await expectLater(
        client.search('f', 'x'),
        throwsA(isA<TiebaSearchFormatException>()
            .having((TiebaSearchFormatException e) => e.detail, 'detail', contains('post_list'))),
      );
    });

    test('连续失败 ≥3 熔断：第 4 次不发请求，breakerTrips=1', () async {
      final ScriptedAdapter adapter = ScriptedAdapter(<ResponseBody>[
        jsonBody(searchJson(errorCode: '4')),
        jsonBody(searchJson(errorCode: '4')),
        jsonBody(searchJson(errorCode: '4')),
      ]);
      final TiebaSearchClient client = scriptedClient(adapter);
      addTearDown(client.close);
      for (int i = 0; i < 3; i++) {
        await expectLater(client.search('f', 'x'), throwsA(isA<CollectRequestException>()));
      }
      await expectLater(
        client.search('f', 'x'),
        throwsA(isA<CollectRequestException>()
            .having((CollectRequestException e) => e.kind, 'kind', CollectFailureKind.serverError)
            .having((CollectRequestException e) => e.message, 'message', contains('熔断'))),
      );
      expect(client.risk.breakerTrips, 1);
      expect(client.risk.requests, 3, reason: '熔断在节流/请求之前触发');
      expect(adapter.requests, hasLength(3));
    });
  });

  // ── UI（testWidgets：内存 fake + mock dio，零真实 IO/网络） ─────────────

  group('在线搜索 UI', () {
    late FakeBookRepository repo;
    setUp(() => repo = FakeBookRepository(library: demoLibrary()));

    testWidgets('双 Tab 切换：本地结果 ↔ 在线手动触发入口（实时联网·匿名徽标）', (WidgetTester tester) async {
      final ScriptedAdapter adapter = ScriptedAdapter(<ResponseBody>[]);
      useSurface(tester);
      await tester.pumpWidget(onlineApp(repo, adapter, initial: searchRoute(kQuery)));
      await tester.pumpAndSettle();

      // 本地 Tab 默认：结果在场，在线徽标不在场。
      expect(find.text('本地库'), findsOneWidget);
      expect(find.text('贴吧在线'), findsOneWidget);
      expect(find.text('1 结果'), findsOneWidget);
      expect(find.text('实时联网·匿名'), findsNothing);
      expect(find.text('年·全部'), findsOneWidget, reason: '六维筛选面板属本地库');
      expect(find.byTooltip('确认筛选'), findsOneWidget, reason: '确认钮在场（本地库 Tab 行，设计令牌图标）');

      await tester.tap(find.text('贴吧在线'));
      await tester.pumpAndSettle();
      expect(find.text('实时联网·匿名'), findsOneWidget);
      expect(find.text('1 结果'), findsNothing, reason: '本地结果视图退出树');
      expect(find.text('年·全部'), findsNothing, reason: '在线 Tab 隐藏六维筛选面板');
      expect(find.text('搜索贴吧'), findsOneWidget, reason: 'idle = 手动触发入口');
      expect(adapter.requests, isEmpty, reason: '切 Tab 不发请求（单请求手动触发口径）');

      await tester.tap(find.text('本地库'));
      await tester.pumpAndSettle();
      expect(find.text('1 结果'), findsOneWidget);
      expect(adapter.requests, isEmpty);
    });

    testWidgets('手动触发 → 结果行（标题/吧名/作者/回复数/时间）+ 外链钮打开原帖', (WidgetTester tester) async {
      final ScriptedAdapter adapter = ScriptedAdapter(<ResponseBody>[
        jsonBody(searchJson(
          posts: <Map<String, dynamic>>[
            postItem(tid: 101, title: '【扫书】十日终焉 超好看', replyNum: 12, time: 1760000000),
            postItem(tid: 202, title: '十日终焉 求书', author: '书荒人乙', fname: '哀伤雪刃', replyNum: 0, time: 1760086400),
          ],
          page: pageInfo(hasMore: 0, totalCount: 2),
        )),
      ]);
      final List<String> copied = mockClipboard(tester);
      final List<String> opened = mockExternalLaunch(tester);
      useSurface(tester);
      await tester.pumpWidget(onlineApp(repo, adapter, initial: searchRoute(kQuery)));
      await tester.pumpAndSettle();
      await gotoOnlineAndSearch(tester);

      expect(adapter.requests, hasLength(1));
      // UI 口径 only_thread=1（仅主题帖，行=帖子粒度）。
      expect(Uri.splitQueryString(adapter.bodies.single)['only_thread'], '1');
      expect(find.text('【扫书】十日终焉 超好看'), findsOneWidget);
      expect(find.text('十日终焉 求书'), findsOneWidget);
      // 吧名 MetaChip 限定在结果区内找：Tab 行的吧切换分段控件也带同样的吧名文本。
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('online-results-view')),
          matching: find.text('yy小说吧'),
        ),
        findsOneWidget,
        reason: '吧名 MetaChip',
      );
      expect(find.text('扫书人甲'), findsOneWidget);
      expect(find.text('12 回复'), findsOneWidget);
      expect(find.text(formatOnlineDate(1760000000)), findsOneWidget);
      expect(find.text('2 条'), findsOneWidget, reason: '头部计数');
      expect(find.text('加载更多'), findsNothing, reason: 'hasMore=0');

      // 零 Material Icon 守卫（在线子树）：结构图标全 AppIcon → SVG。
      final Finder online = find.byKey(const ValueKey<String>('online-results-view'));
      expect(find.descendant(of: online, matching: find.byType(Icon)), findsNothing,
          reason: '在线子树结构图标单一出口 = assets/icons SVG');
      expect(find.descendant(of: online, matching: find.byType(AppIcon)), findsWidgets);
      expect(find.descendant(of: online, matching: find.byType(SvgPicture)), findsWidgets);

      // 右上角按钮 = 打开原帖外链（openThreadExternallyWithFeedback：Android 先定向贴吧
      // App，其余落系统浏览器）；整卡点击已改为 push 在线帖子页（/online/{tid}），由
      // search_chrome_test.dart 的自定义路由用例覆盖 —— 本挂具的真实路由表尚无
      // /online/{tid}，点整卡会抛 GoException。
      final Finder openButtons = find.byTooltip('打开原帖');
      expect(openButtons, findsNWidgets(2), reason: '每张结果卡一个显式外链钮');
      await tester.tap(openButtons.first);
      await tester.pumpAndSettle();
      expect(opened, <String>['https://tieba.baidu.com/p/101']);
      expect(copied, isEmpty, reason: '不再走剪贴板');
    });

    testWidgets('加载更多：hasMore=1 → 手动翻页（pn+1、按 tid 去重追加）', (WidgetTester tester) async {
      final ScriptedAdapter adapter = ScriptedAdapter(<ResponseBody>[
        jsonBody(searchJson(
          posts: <Map<String, dynamic>>[postItem(tid: 1, title: '第一页帖')],
          page: pageInfo(hasMore: 1, currentPage: 1, totalPage: 2),
        )),
        jsonBody(searchJson(
          posts: <Map<String, dynamic>>[
            postItem(tid: 1, title: '第一页帖'),
            postItem(tid: 2, title: '第二页帖'),
          ],
          page: pageInfo(hasMore: 0, currentPage: 2, totalPage: 2),
        )),
      ]);
      useSurface(tester);
      await tester.pumpWidget(onlineApp(repo, adapter, initial: searchRoute(kQuery)));
      await tester.pumpAndSettle();
      await gotoOnlineAndSearch(tester);

      expect(find.text('第一页帖'), findsOneWidget);
      expect(find.text('加载更多'), findsOneWidget);
      await tester.tap(find.text('加载更多'));
      await tester.pumpAndSettle();

      expect(adapter.requests, hasLength(2));
      expect(Uri.splitQueryString(adapter.bodies[1])['pn'], '2');
      expect(find.text('第一页帖'), findsOneWidget, reason: '跨页重复 tid 去重');
      expect(find.text('第二页帖'), findsOneWidget);
      expect(find.text('加载更多'), findsNothing, reason: 'hasMore=0 收口');
    });

    testWidgets('空态：post_list 空 → 提示文案（零 Material Icon）', (WidgetTester tester) async {
      final ScriptedAdapter adapter = ScriptedAdapter(<ResponseBody>[
        jsonBody(searchJson(page: pageInfo())),
      ]);
      useSurface(tester);
      await tester.pumpWidget(onlineApp(repo, adapter, initial: searchRoute(kQuery)));
      await tester.pumpAndSettle();
      await gotoOnlineAndSearch(tester);

      expect(find.textContaining('贴吧里没有搜到与 "$kQuery" 相关的帖子'), findsOneWidget);
      final Finder online = find.byKey(const ValueKey<String>('online-results-view'));
      expect(find.descendant(of: online, matching: find.byType(Icon)), findsNothing);
      expect(find.descendant(of: online, matching: find.byType(AppIcon)), findsWidgets);
    });

    testWidgets('错误态：非法 JSON → 「贴吧接口似乎已变更」降级文案（§8.12）+ 重试恢复', (WidgetTester tester) async {
      final ScriptedAdapter adapter = ScriptedAdapter(<ResponseBody>[
        jsonBody('接口返回了奇怪的东西<<>>'),
        jsonBody(searchJson(posts: <Map<String, dynamic>>[postItem(tid: 5, title: '重试成功帖')])),
      ]);
      useSurface(tester);
      await tester.pumpWidget(onlineApp(repo, adapter, initial: searchRoute(kQuery)));
      await tester.pumpAndSettle();
      await gotoOnlineAndSearch(tester);

      expect(find.text('贴吧接口似乎已变更'), findsOneWidget);
      expect(find.textContaining('离线库检索不受影响'), findsOneWidget);
      final Finder online = find.byKey(const ValueKey<String>('online-results-view'));
      expect(find.descendant(of: online, matching: find.byType(Icon)), findsNothing);

      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('重试成功帖'), findsOneWidget);
      expect(adapter.requests, hasLength(2));
    });

    testWidgets('错误态：风控（errorno=110001）→ 风控文案 + 计数徽标不在场', (WidgetTester tester) async {
      final ScriptedAdapter adapter = ScriptedAdapter(<ResponseBody>[
        jsonBody(searchJson(errorCode: '110001', errorMsg: '需登录')),
      ]);
      useSurface(tester);
      await tester.pumpWidget(onlineApp(repo, adapter, initial: searchRoute(kQuery)));
      await tester.pumpAndSettle();
      await gotoOnlineAndSearch(tester);

      expect(find.text('触发贴吧风控'), findsOneWidget);
      expect(find.textContaining('稍后再试'), findsWidgets);
      expect(find.text('重试'), findsOneWidget);
    });

    testWidgets('本地空态 → 「贴吧在线搜索」入口 = 切 Tab 并触发一次（§5.3 行 393）', (WidgetTester tester) async {
      final ScriptedAdapter adapter = ScriptedAdapter(<ResponseBody>[
        jsonBody(searchJson(
          posts: <Map<String, dynamic>>[postItem(tid: 9, title: '在线命中帖')],
          page: pageInfo(),
        )),
      ]);
      useSurface(tester, height: 1000);
      await tester.pumpWidget(onlineApp(repo, adapter, initial: searchRoute('不存在书名xyz')));
      await tester.pumpAndSettle();

      expect(find.textContaining('相关的书'), findsOneWidget, reason: '本地 0 结果空态');
      // 空态动作钮可能落在底部导航遮挡区/折叠线以下 → 先滚入可视区再点。
      await tester.ensureVisible(find.text('贴吧在线搜索'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('贴吧在线搜索'));
      await tester.pumpAndSettle();

      expect(find.text('实时联网·匿名'), findsOneWidget, reason: '已切到在线 Tab');
      expect(adapter.requests, hasLength(1), reason: '入口点击 = 手动触发一次');
      expect(find.text('在线命中帖'), findsOneWidget);
    });

    testWidgets('在线 Tab 激活时键盘搜索 = 手动触发在线搜索（单请求）', (WidgetTester tester) async {
      final ScriptedAdapter adapter = ScriptedAdapter(<ResponseBody>[
        jsonBody(searchJson(posts: <Map<String, dynamic>>[postItem(tid: 3, title: '键盘触发帖')])),
      ]);
      useSurface(tester);
      await tester.pumpWidget(onlineApp(repo, adapter, initial: '/search'));
      await tester.pumpAndSettle();

      // 先进入在线 Tab（需 submitted 才有 Tab 行：先提交一次本地搜索）。
      await tester.enterText(find.byType(TextField).first, kQuery);
      await tester.pump(const Duration(milliseconds: 250)); // 联想 debounce（TESTING.md §3.5）
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('贴吧在线'));
      await tester.pumpAndSettle();
      expect(adapter.requests, isEmpty);

      // 在线 Tab 上再次键盘搜索 → 恰好一个请求。
      // （首次提交已 unfocus，需重新聚焦输入框才有活动的 TextInput 连接。）
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(adapter.requests, hasLength(1));
      expect(find.text('键盘触发帖'), findsOneWidget);
    });

    testWidgets('吧切换：切到「哀伤雪刃」→ 旧结果作废、再触发时 kw 换吧（用户口径：加哀伤雪刃吧）',
        (WidgetTester tester) async {
      final ScriptedAdapter adapter = ScriptedAdapter(<ResponseBody>[
        jsonBody(searchJson(
          posts: <Map<String, dynamic>>[postItem(tid: 1, title: 'yy 结果帖')],
          page: pageInfo(),
        )),
        jsonBody(searchJson(
          posts: <Map<String, dynamic>>[postItem(tid: 2, title: '雪刃结果帖', fname: '哀伤雪刃')],
          page: pageInfo(),
        )),
      ]);
      useSurface(tester);
      await tester.pumpWidget(onlineApp(repo, adapter, initial: searchRoute(kQuery)));
      await tester.pumpAndSettle();
      await gotoOnlineAndSearch(tester);

      expect(find.text('yy 结果帖'), findsOneWidget);
      expect(Uri.splitQueryString(adapter.bodies.single)['kw'], 'yy小说吧', reason: '默认第一个关注吧');

      // 切吧 = 旧吧结果作废回手动入口（不发请求），提示文案跟着换吧名。
      await tester.tap(find.text('哀伤雪刃'));
      await tester.pumpAndSettle();
      expect(find.text('yy 结果帖'), findsNothing, reason: '跨吧结果不作数');
      expect(adapter.requests, hasLength(1), reason: '切吧本身不发请求（单请求手动触发口径）');
      expect(find.textContaining('在「哀伤雪刃」内实时搜索'), findsOneWidget);

      // 再手动触发：请求体 kw = 新吧。
      await tester.tap(find.text('搜索贴吧'));
      await tester.pumpAndSettle();
      expect(adapter.requests, hasLength(2));
      expect(Uri.splitQueryString(adapter.bodies[1])['kw'], '哀伤雪刃');
      expect(find.text('雪刃结果帖'), findsOneWidget);
    });
  });
}
