/// BDUSS 接入测试（需求 8 + 需求 5）：proto / searchpost 双通道携带口径、配额档位、
/// 间隔/并发两档映射、登录态失效自动降级、失效标记与 effective 凭证、
/// initNickname 有效性探测、tiebaApiProvider 装配链路与账号卡文案。
///
/// 全部零真实网络：dio 用脚本化 adapter 捕获真实请求体字节（TESTING.md 纪律；
/// 断言不触碰 secure storage —— bdussProvider 一律 override 注入）。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/collector/collect_providers.dart';
import 'package:booksift/collector/collect_state.dart';
import 'package:booksift/collector/scheduler.dart';
import 'package:booksift/collector/tieba/src/proto/CommonReq.pb.dart';
import 'package:booksift/collector/tieba/src/proto/PbPageReqIdl.pb.dart';
import 'package:booksift/collector/tieba/tieba_client.dart';
import 'package:booksift/collector/tieba_account.dart';
import 'package:booksift/collector/tieba_api.dart';
import 'package:booksift/collector/tieba_search.dart';
import 'package:booksift/data/bduss.dart';
import 'package:booksift/features/collect/collect_page.dart';

import '../support/fake_book_repository.dart';
import '../support/fake_collect.dart';
import '../support/harness.dart';
import 'support.dart';

/// 假 BDUSS（形状同真值：足够长 + base64 风格字符集）。
const String kFakeBduss = 'FAKE_Bduss_0123456789abcdefghijklmnopqrstuvwxyzABCDE==';

/// 捕获请求体的 dio adapter（发起零网络；响应脚本化）。
class _CaptureAdapter implements HttpClientAdapter {
  _CaptureAdapter(this.responder, {this.status = 200, this.throwType = false});

  final Uint8List Function(RequestOptions options) responder;
  final int status;

  /// true = fetch 直接抛 connectionError（探测的 network 档用）。
  final bool throwType;
  final List<RequestOptions> requests = <RequestOptions>[];
  final List<Uint8List> bodies = <Uint8List>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final List<int> collected = <int>[];
    if (requestStream != null) {
      await for (final Uint8List chunk in requestStream) {
        collected.addAll(chunk);
      }
    }
    bodies.add(Uint8List.fromList(collected));
    if (throwType) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: '连接错误（测试注入）',
      );
    }
    return ResponseBody.fromBytes(
      responder(options),
      status,
      headers: <String, List<String>>{
        'content-type': <String>['application/octet-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioOf(_CaptureAdapter adapter) {
  final Dio dio = Dio(BaseOptions(validateStatus: (int? s) => s == 200));
  dio.httpClientAdapter = adapter;
  return dio;
}

/// 扣掉 multipart 包装头尾（tieba_client 手写单 part），返回 protobuf 原始 payload；
/// 包装头尾逐字节与历史一致本身也是断言。
Uint8List _protoPayload(Uint8List body) {
  final List<int> head = utf8.encode(
      '--$kBoundary\r\nContent-Disposition: form-data; name="data"; filename="file"\r\n\r\n');
  final List<int> tail = utf8.encode('\r\n--$kBoundary--\r\n');
  expect(body.length, greaterThan(head.length + tail.length));
  expect(body.sublist(0, head.length), orderedEquals(head),
      reason: 'multipart 头应保持历史字节');
  expect(body.sublist(body.length - tail.length), orderedEquals(tail),
      reason: 'multipart 尾应保持历史字节');
  return Uint8List.fromList(body.sublist(head.length, body.length - tail.length));
}

/// 独立重算 getPosts(tid, pn=1, rn=30, ASC) 的期望请求体（不经 client 代码路径）。
PbPageReqIdl _expectedPostsReqIdl(int tid, {String? bduss}) {
  final CommonReq common = CommonReq()
    ..clientType = 2
    ..clientVersion = kLegacyVersion;
  if (bduss != null) {
    common.bDUSS = bduss;
  }
  return PbPageReqIdl()
    ..data = (PbPageReqIdl_DataReq()
      ..common = common
      ..kz = Int64(tid)
      ..pn = 1
      ..rn = 30
      ..r = PostSort.asc
      ..lz = 0);
}

Map<String, String> _parseForm(String body) {
  final Map<String, String> out = <String, String>{};
  for (final String pair in body.split('&')) {
    final int eq = pair.indexOf('=');
    out[Uri.decodeQueryComponent(pair.substring(0, eq))] =
        Uri.decodeQueryComponent(pair.substring(eq + 1));
  }
  return out;
}

class _MapBudgetStore implements BudgetStore {
  final Map<String, String> map = <String, String>{};

  @override
  Future<String?> read(String key) async => map[key];

  @override
  Future<void> write(String key, String value) async => map[key] = value;
}

class _BdussHolder {
  _BdussHolder(this.value);

  String? value;
}

/// 内存机密存储（provider 装配 / 失效标记测试；真实实现是 flutter_secure_storage）。
class _MemorySecrets implements SecretStore {
  _MemorySecrets([Map<String, String>? initial])
      : map = initial ?? <String, String>{};

  final Map<String, String> map;

  @override
  Future<String?> read(String key) async => map[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      map.remove(key);
    } else {
      map[key] = value;
    }
  }
}

const String _okSearchJson =
    '{"post_list":[],"page":{"has_more":0,"current_page":1,"total_page":1,"total_count":0}}';

void main() {
  group('proto 通道（app-proto，免签名）', () {
    test('匿名档：common 不含 BDUSS，请求体字节与现状独立重算逐字节一致', () async {
      final _CaptureAdapter adapter =
          _CaptureAdapter((_) => PbPageResIdl().writeToBuffer());
      final TiebaClient client = TiebaClient(
        dio: _dioOf(adapter),
        minIntervalMs: 0,
        maxIntervalMs: 0,
      );
      await client.getPosts(12345);

      final Uint8List payload = _protoPayload(adapter.bodies.single);
      final PbPageReqIdl req = PbPageReqIdl.fromBuffer(payload);
      expect(req.data.common.hasBDUSS(), isFalse,
          reason: '匿名档不得写出 BDUSS 字段（含空字段）');
      expect(payload, orderedEquals(_expectedPostsReqIdl(12345).writeToBuffer()),
          reason: '匿名请求体必须与无 BDUSS 的独立构造逐字节一致');
    });

    test('BDUSS 档：common.bDUSS = 所传值，且仅多出这一个字段', () async {
      final _CaptureAdapter adapter =
          _CaptureAdapter((_) => PbPageResIdl().writeToBuffer());
      final TiebaClient client = TiebaClient(
        dio: _dioOf(adapter),
        minIntervalMs: 0,
        maxIntervalMs: 0,
        bduss: kFakeBduss,
      );
      await client.getPosts(12345);

      final Uint8List payload = _protoPayload(adapter.bodies.single);
      final PbPageReqIdl req = PbPageReqIdl.fromBuffer(payload);
      expect(req.data.common.hasBDUSS(), isTrue);
      expect(req.data.common.bDUSS, kFakeBduss);
      expect(payload,
          orderedEquals(_expectedPostsReqIdl(12345, bduss: kFakeBduss).writeToBuffer()),
          reason: '带 BDUSS 的请求体 = 匿名请求体 + common.BDUSS 字段');
      expect(adapter.requests.single.headers['x_bd_data_type'], 'protobuf');
    });
  });

  group('searchpost 通道（app-form，BDUSS 参与签名）', () {
    test('匿名档：参数表与历史完全一致（无 BDUSS 键），sign 按无 BDUSS 计算', () async {
      final _CaptureAdapter adapter = _CaptureAdapter(
          (_) => Uint8List.fromList(utf8.encode(_okSearchJson)));
      final TiebaSearchClient client = TiebaSearchClient(
        dio: _dioOf(adapter),
        minIntervalMs: 0,
        maxIntervalMs: 0,
      );
      await client.search('yy小说吧', '关键词');

      final Map<String, String> params =
          _parseForm(utf8.decode(adapter.bodies.single));
      expect(
        params.keys.toSet(),
        <String>{
          '_client_type',
          '_client_version',
          'kw',
          'only_thread',
          'pn',
          'rn',
          'sm',
          'word',
          'sign',
        },
        reason: '匿名表单键集与历史一致（不得混入 BDUSS）',
      );
      final String sign = params.remove('sign')!;
      expect(sign, computeFormSign(params));
    });

    test('BDUSS 档：BDUSS 作为普通参数参与 sign（sign 与匿名档不同）', () async {
      final _CaptureAdapter anon = _CaptureAdapter(
          (_) => Uint8List.fromList(utf8.encode(_okSearchJson)));
      final _CaptureAdapter authed = _CaptureAdapter(
          (_) => Uint8List.fromList(utf8.encode(_okSearchJson)));
      await TiebaSearchClient(
        dio: _dioOf(anon),
        minIntervalMs: 0,
        maxIntervalMs: 0,
      ).search('yy小说吧', '关键词');
      await TiebaSearchClient(
        dio: _dioOf(authed),
        minIntervalMs: 0,
        maxIntervalMs: 0,
        bduss: kFakeBduss,
      ).search('yy小说吧', '关键词');

      final Map<String, String> params =
          _parseForm(utf8.decode(authed.bodies.single));
      expect(params['BDUSS'], kFakeBduss);
      final String sign = params.remove('sign')!;
      expect(sign, computeFormSign(params), reason: 'sign 必须包含 BDUSS 参数');

      final String anonSign =
          _parseForm(utf8.decode(anon.bodies.single))['sign']!;
      expect(sign, isNot(anonSign));
    });
  });

  group('每日预算档位（§8.11）', () {
    test('dailyBudgetFor：null/空 → 300，有值 → 600', () {
      expect(dailyBudgetFor(null), kDailyBudgetAnonymous);
      expect(dailyBudgetFor(''), kDailyBudgetAnonymous);
      expect(dailyBudgetFor(kFakeBduss), kDailyBudgetBduss);
      expect(kDailyBudgetBduss, 600);
    });

    test('BDUSS 档 600：第 301 次消费仍放行；越限抛 BudgetExhaustedException', () async {
      final FakeClock clock = FakeClock();
      final _MapBudgetStore store = _MapBudgetStore();
      final DailyBudget budget = DailyBudget(
        store: store,
        clock: clock,
        limit: kDailyBudgetBduss,
      );
      for (int i = 0; i < 301; i++) {
        await budget.consume();
      }
      expect(budget.used, 301);

      for (int i = 301; i < kDailyBudgetBduss; i++) {
        await budget.consume();
      }
      expect(budget.exhausted, isTrue, reason: '600 次用满即触顶');
      await expectLater(budget.consume(), throwsA(isA<BudgetExhaustedException>()));
    });
  });

  group('失效标记与 effective 凭证（需求 5）', () {
    test('markInvalid 幂等且不删凭证；effective 转 null；重新导入/清除清标记', () async {
      final _MemorySecrets secrets =
          _MemorySecrets(<String, String>{kSecretKeyBduss: kFakeBduss});
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          secretStoreProvider.overrideWithValue(secrets),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(effectiveBdussProvider.future), kFakeBduss);

      final BdussController ctl = container.read(bdussControllerProvider);
      expect(await ctl.markInvalid(), isTrue, reason: '首次标记返回 true（UI 只提示一次）');
      expect(await ctl.markInvalid(), isFalse, reason: '重复标记幂等，不再返回 true');
      expect(secrets.map[kSecretKeyBduss], kFakeBduss, reason: '失效标记不删用户凭证');
      expect(secrets.map[kSecretKeyBdussInvalid], '1');
      expect(await container.read(effectiveBdussProvider.future), isNull,
          reason: '失效 → 全装配链路按匿名档运行');

      await ctl.save(kFakeBduss); // 重新导入 = 清标记
      expect(secrets.map[kSecretKeyBdussInvalid], isNull);
      expect(await container.read(effectiveBdussProvider.future), kFakeBduss);

      await ctl.markInvalid();
      await ctl.clear(); // 清除 = 一并清标记
      expect(secrets.map[kSecretKeyBduss], isNull);
      expect(secrets.map[kSecretKeyBdussInvalid], isNull);
      expect(await container.read(effectiveBdussProvider.future), isNull);
    });
  });

  group('装配链路（tiebaApiProvider ← effectiveBdussProvider）', () {
    test('导入/失效/清除：客户端按生效凭证重建（失效自动回匿名）', () async {
      final _BdussHolder holder = _BdussHolder(null);
      bool invalid = false;
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          bdussProvider.overrideWith((Ref ref) async => holder.value),
          bdussInvalidProvider.overrideWith((Ref ref) async => invalid),
        ],
      );
      addTearDown(container.dispose);

      await container.read(effectiveBdussProvider.future);
      ProtoTiebaApi api = container.read(tiebaApiProvider) as ProtoTiebaApi;
      expect(api.bduss, isNull, reason: '首帧（无凭证）应为匿名档');

      holder.value = kFakeBduss; // 用户在设置页导入
      container.invalidate(bdussProvider);
      await container.read(effectiveBdussProvider.future);
      api = container.read(tiebaApiProvider) as ProtoTiebaApi;
      expect(api.bduss, kFakeBduss, reason: '导入后应换用带凭证的新客户端');

      invalid = true; // 采集命中登录态失效 → 标记落定
      container.invalidate(bdussInvalidProvider);
      await container.read(effectiveBdussProvider.future);
      api = container.read(tiebaApiProvider) as ProtoTiebaApi;
      expect(api.bduss, isNull, reason: '失效后 tiebaApiProvider 自动回匿名客户端');

      holder.value = null; // 清除
      container.invalidate(bdussProvider);
      await container.read(effectiveBdussProvider.future);
      api = container.read(tiebaApiProvider) as ProtoTiebaApi;
      expect(api.bduss, isNull, reason: '清除后保持匿名');
    });
  });

  group('档位接线（需求 5：间隔 1.0–2.0s / 并发上限 4）', () {
    test('BDUSS 档运行间隔落在 [1000,2000]ms（匿名档 1.5–3.0s 回归在 service_test）', () async {
      final TestEnv env = await TestEnv.create(
          forums: <String>['A吧', 'B吧'], bdussImported: true);
      addTearDown(env.dispose);
      for (int i = 0; i < 2; i++) {
        final String f = <String>['A吧', 'B吧'][i];
        final int tid = 700 + i;
        env.api.scriptThreads(
            f,
            1,
            ThreadsPage(fid: 10 + i, threads: <ThreadSummary>[mkThread(tid: tid, createTime: 300)], hasMore: false));
        env.api.scriptPosts(tid, 1, mkPostsPage(tid), forum: f);
      }

      await env.service.run();

      final List<ApiCall> sorted = env.api.calls.toList()
        ..sort((ApiCall a, ApiCall b) => a.startedAt.compareTo(b.startedAt));
      expect(sorted, hasLength(4)); // 2 列表 + 2 帖
      for (int i = 1; i < sorted.length; i++) {
        final int gap =
            sorted[i].startedAt.difference(sorted[i - 1].startedAt).inMilliseconds;
        expect(gap, greaterThanOrEqualTo(kMinIntervalBdussMs));
        expect(gap, lessThanOrEqualTo(kMaxIntervalBdussMs),
            reason: 'BDUSS 档间隔上限 2.0s（匿名档为 3.0s，见 service_test 回归）');
      }
    });

    test('concurrent_forums=4：BDUSS 档真并发 4（匿名档钳到 3 在 scheduler_test）', () async {
      final TestEnv env = await TestEnv.create(
          forums: <String>['A吧', 'B吧', 'C吧', 'D吧'],
          concurrency: 4,
          holdTicks: 30,
          bdussImported: true);
      addTearDown(env.dispose);
      for (int i = 0; i < 4; i++) {
        env.api.scriptThreads(
            <String>['A吧', 'B吧', 'C吧', 'D吧'][i],
            1,
            ThreadsPage(fid: 20 + i, threads: <ThreadSummary>[], hasMore: false));
      }

      await env.service.run();

      expect(env.api.maxActive, 4, reason: 'BDUSS 档并发上限 4 应实际放行 4 条在途请求');
    });
  });

  group('登录态失效自动降级（需求 5 / §8.10）', () {
    test('列表命中 110001 → 换匿名客户端重试当次请求 + 只回调一次 + 降级日志 + 轮末关匿名端', () async {
      final FakeClock clock = FakeClock();
      late FakeTiebaApi anonApi;
      int invalidCalls = 0;
      final TestEnv env = await TestEnv.create(
        forums: <String>['A吧'],
        clock: clock,
        bdussImported: true,
        anonymousApiFactory: () {
          anonApi = FakeTiebaApi(clock, holdTicks: 0)
            ..scriptThreads(
                'A吧',
                1,
                const ThreadsPage(fid: 7, threads: <ThreadSummary>[], hasMore: false));
          return anonApi;
        },
        onAccountInvalid: () => invalidCalls++,
      );
      addTearDown(env.dispose);

      // 主（账号档）客户端：列表第一次直接 110001（需登录 / 登录态失效）。
      env.api.failThreads('A吧', err110001());

      await env.service.run();

      expect(invalidCalls, 1, reason: '同一轮只回调一次（幂等口径）');
      expect(env.api.countCalls((ApiCall c) => c.isThreads), 1,
          reason: '失败后不得再用账号档客户端重试');
      expect(anonApi.countCalls((ApiCall c) => c.isThreads), 1,
          reason: '重试走降级后的匿名客户端（不再带 BDUSS）');
      expect(anonApi.closed, isTrue, reason: '本服务自建的匿名客户端在轮末 close');
      final List<CollectLogEntry> logs = env.last.logs
          .where((CollectLogEntry e) => e.event == '降级')
          .toList();
      expect(logs, hasLength(1));
      expect(logs.single.detail, contains('登录态失效'));
      expect(logs.single.detail, contains('重新导入'));
    });

    test('匿名档（未导入）不触发降级；429 风控不算登录失效', () async {
      int invalidCalls = 0;
      final TestEnv env = await TestEnv.create(
        forums: <String>['A吧'],
        onAccountInvalid: () => invalidCalls++,
      );
      addTearDown(env.dispose);
      env.api.failThreads('A吧', err429());
      await env.service.run();
      expect(invalidCalls, 0, reason: '匿名档 429 只算风控，不标记账号失效');
      expect(env.last.logs.where((CollectLogEntry e) => e.event == '降级'), isEmpty);
    });

    test('账号档 429 风控也不降级（只认 110xxx / 未登录语义）', () async {
      int invalidCalls = 0;
      int factoryCalls = 0;
      final FakeClock clock = FakeClock();
      final TestEnv env = await TestEnv.create(
        forums: <String>['A吧'],
        clock: clock,
        bdussImported: true,
        anonymousApiFactory: () {
          factoryCalls++;
          return FakeTiebaApi(clock, holdTicks: 0);
        },
        onAccountInvalid: () => invalidCalls++,
      );
      addTearDown(env.dispose);
      env.api.failThreads('A吧', err429());
      await env.service.run();
      expect(invalidCalls, 0);
      expect(factoryCalls, 0, reason: '429 不触发换客户端');
    });
  });

  group('账号有效性探测（initNickname，需求 5）', () {
    test('成功：返回昵称；请求体 = BDUSS + LATEST 版本 + APP_SALT 合法 sign', () async {
      final _CaptureAdapter adapter = _CaptureAdapter((_) => Uint8List.fromList(utf8.encode(
          '{"error_code":0,"user_info":{"user_name":"u1","name_show":"昵称A","tieba_uid":9}}')));
      final TiebaAccountProbeResult r =
          await TiebaAccountProbe(dio: _dioOf(adapter)).check(kFakeBduss);

      expect(r.kind, TiebaAccountProbeKind.ok);
      expect(r.nickname, '昵称A');
      expect(adapter.requests.single.uri.toString(), kInitNicknameUrl);
      final Map<String, String> params = _parseForm(utf8.decode(adapter.bodies.single));
      expect(params['BDUSS'], kFakeBduss);
      expect(params['_client_version'], kLatestClientVersion);
      final String sign = params.remove('sign')!;
      expect(sign, computeFormSign(params), reason: 'sign 必须与 App 侧 computeFormSign 同源且包含 BDUSS');
    });

    test('110001 / 未登录文案 → invalid；去昵称回落 user_name', () async {
      final _CaptureAdapter adapter = _CaptureAdapter((_) => Uint8List.fromList(
          utf8.encode('{"error_code":110001,"error_msg":"请先登录"}')));
      final TiebaAccountProbeResult r =
          await TiebaAccountProbe(dio: _dioOf(adapter)).check(kFakeBduss);
      expect(r.kind, TiebaAccountProbeKind.invalid);
      expect(r.message, contains('110001'));
    });

    test('HTTP 429 → risk；连接错误 → network；未知 errorno → server', () async {
      final _CaptureAdapter busy =
          _CaptureAdapter((_) => Uint8List.fromList(<int>[]), status: 429);
      expect((await TiebaAccountProbe(dio: _dioOf(busy)).check(kFakeBduss)).kind,
          TiebaAccountProbeKind.risk);

      final _CaptureAdapter boom = _CaptureAdapter((_) => Uint8List(0), throwType: true);
      expect((await TiebaAccountProbe(dio: _dioOf(boom)).check(kFakeBduss)).kind,
          TiebaAccountProbeKind.network);

      final _CaptureAdapter weird = _CaptureAdapter((_) => Uint8List.fromList(
          utf8.encode('{"error_code":4,"error_msg":"unknown"}')));
      expect((await TiebaAccountProbe(dio: _dioOf(weird)).check(kFakeBduss)).kind,
          TiebaAccountProbeKind.server);
    });
  });

  group('账号卡文案（采集页空闲态）', () {
    Future<void> pumpCollect(WidgetTester tester, {String? bduss}) async {
      useSurface(tester);
      await tester.pumpWidget(
        testApp(
          FakeBookRepository(),
          home: const CollectPage(),
          extraOverrides: <Override>[
            ...collectTestOverrides(notifier: FakeCollectRunNotifier()),
            bdussProvider.overrideWith((Ref ref) async => bduss),
            // 失效标记：widget 测试里真实安全存储读取不会完成（平台通道无宿主），
            // 固定为 false 让 effectiveBdussProvider 走确定分支。
            bdussInvalidProvider.overrideWith((Ref ref) async => false),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
    }

    testWidgets('未导入：匿名模式徽标 + 每日配额 300', (WidgetTester tester) async {
      await pumpCollect(tester);
      expect(find.text('未导入 BDUSS · 每日配额 300'), findsOneWidget);
      expect(find.text('匿名模式'), findsWidgets);
      expect(find.text('账号模式'), findsNothing);
    });

    testWidgets('已导入：账号模式徽标 + 每日配额 600', (WidgetTester tester) async {
      await pumpCollect(tester, bduss: kFakeBduss);
      expect(find.text('已导入 BDUSS · 每日配额 600'), findsOneWidget);
      // AppBar 徽标（collect_page.dart）与账号卡徽标同口径 → 同屏两处命中。
      expect(find.text('账号模式'), findsNWidgets(2));
    });

    testWidgets('失效标记：按匿名档运行 + 行内提示重新导入（需求 5）', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(
        testApp(
          FakeBookRepository(),
          home: const CollectPage(),
          extraOverrides: <Override>[
            ...collectTestOverrides(notifier: FakeCollectRunNotifier()),
            bdussProvider.overrideWith((Ref ref) async => kFakeBduss),
            bdussInvalidProvider.overrideWith((Ref ref) async => true),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('BDUSS 已失效 · 请到设置页重新导入 · 当前每日配额 300'),
          findsOneWidget);
      expect(find.text('账号模式'), findsNothing, reason: '失效后按匿名档运行');
      expect(find.text('匿名模式'), findsWidgets);
      // 新标记落定 → 顶部 toast 说明（需求 5「toast/日志说明」的 toast 侧）。
      expect(find.textContaining('BDUSS 已失效，已自动回退匿名档'), findsOneWidget);
      await dismissSnackBars(tester);
    });
  });
}