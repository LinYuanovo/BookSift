// 矩阵补缺：app-proto 传输层（lib/collector/tieba/tieba_client.dart）。
//
// 缺口依据（docs/测试矩阵.md §3）：此前 service_test/collect_test 全走 FakeTiebaApi，
// 真实 wire 形态（multipart 帧、cmd URL、pb 请求参数映射）、pb 响应解码、
// 验证码/HTTP/网络三类风控信号计数与客户端熔断零覆盖。
// 注入脚本化 dio adapter（与 test/search/online_search_test.dart 同款模式），
// 全部 plain test()、零真实网络（TESTING.md §3.2）。
@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:booksift/collector/tieba/tieba_client.dart';
import 'package:booksift/collector/tieba/src/proto/Error.pb.dart' as pberr;
import 'package:booksift/collector/tieba/src/proto/FrsPageReqIdl.pb.dart';
import 'package:booksift/collector/tieba/src/proto/PbPageReqIdl.pb.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// ─────────────────────── 脚本化 dio adapter ───────────────────────

class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter(this.script);

  final List<ResponseBody> script;
  final List<RequestOptions> requests = <RequestOptions>[];
  final List<Uint8List> bodies = <Uint8List>[];
  bool closed = false;
  int _next = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bb = BytesBuilder(copy: false);
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bb.add(chunk);
      }
    }
    requests.add(options);
    bodies.add(bb.toBytes());
    if (_next >= script.length) {
      throw StateError('ScriptedAdapter 脚本耗尽（第 ${_next + 1} 个请求）');
    }
    return script[_next++];
  }

  @override
  void close({bool force = false}) => closed = true;
}

class TimeoutAdapter implements HttpClientAdapter {
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

ResponseBody protoBody(List<int> bytes,
        {int status = 200, String contentType = 'application/octet-stream'}) =>
    ResponseBody.fromBytes(
      bytes,
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[contentType],
      },
    );

ResponseBody frsBody({int errorno = 0, String errmsg = ''}) {
  final res = FrsPageResIdl()
    ..error = (pberr.Error()
      ..errorno = errorno
      ..errmsg = errmsg);
  return protoBody(res.writeToBuffer());
}

ResponseBody pbBody({int errorno = 0, String errmsg = ''}) {
  final res = PbPageResIdl()
    ..error = (pberr.Error()
      ..errorno = errorno
      ..errmsg = errmsg);
  return protoBody(res.writeToBuffer());
}

TiebaClient scripted(ScriptedAdapter a) => TiebaClient(
      random: Random(7),
      minIntervalMs: 0,
      maxIntervalMs: 0,
      dio: Dio()..httpClientAdapter = a,
    );

Map<String, String> lowerHeaders(RequestOptions o) =>
    o.headers.map((k, v) => MapEntry(k.toLowerCase(), '$v'));

Uint8List multipartPayload(Uint8List body) {
  final head = utf8.encode(
      '--$kBoundary\r\nContent-Disposition: form-data; name="data"; filename="file"\r\n\r\n');
  final tail = utf8.encode('\r\n--$kBoundary--\r\n');
  expect(body.length, greaterThan(head.length + tail.length));
  expect(body.sublist(0, head.length), head,
      reason: 'multipart head 必须逐字节等于 aiotieba pack_proto_request 形态');
  expect(body.sublist(body.length - tail.length), tail, reason: 'multipart tail');
  return body.sublist(head.length, body.length - tail.length);
}

void main() {
  group('getThreads 请求形态（frs/page，cmd=301001）', () {
    test('URL/方法/头：http + cmd 查询参数、x_bd_data_type、boundary、UA', () async {
      final a = ScriptedAdapter(<ResponseBody>[frsBody()]);
      await scripted(a).getThreads('扫书');
      final o = a.requests.single;
      expect(o.method, 'POST');
      expect(o.uri.toString(),
          'http://$kAppHost/c/f/frs/page?cmd=$kFrsPageCmd');
      final h = lowerHeaders(o);
      expect(h['x_bd_data_type'], 'protobuf');
      expect(h['user-agent'], kUserAgent);
      final ct = (h['content-type'] ?? o.contentType ?? '').toString();
      expect(ct, 'multipart/form-data; boundary=$kBoundary');
    });

    test('multipart body：单 part 无 part 级 Content-Type，中段可 pb 反解', () async {
      final a = ScriptedAdapter(<ResponseBody>[frsBody()]);
      await scripted(a).getThreads('扫书');
      final payload = multipartPayload(a.bodies.single);
      expect(utf8.decode(payload, allowMalformed: true),
          isNot(contains('Content-Type')),
          reason: 'part 内不得出现 part 级 Content-Type（core/http.py:134-142）');
      expect(FrsPageReqIdl.fromBuffer(payload), isA<FrsPageReqIdl>());
    });

    test('参数映射：pn=1→0 / pn=3→3、rnNeed=rn+5、kw/sortType/isGood、common 常量',
        () async {
      final a = ScriptedAdapter(<ResponseBody>[frsBody(), frsBody()]);
      final c = scripted(a);
      await c.getThreads('扫书', pn: 1, rn: 100);
      await c.getThreads('扫书', pn: 3, rn: 50,
          sortType: ThreadSort.hot, isGood: true);
      final r1 = FrsPageReqIdl.fromBuffer(multipartPayload(a.bodies[0])).data;
      expect(r1.kw, '扫书');
      expect(r1.pn, 0, reason: '首页映射 pn=0（get_threads/_api.py:23）');
      expect(r1.rn, 100);
      expect(r1.rnNeed, 105);
      expect(r1.sortType, ThreadSort.create);
      expect(r1.isGood, 0);
      expect(r1.common.clientType, 2);
      expect(r1.common.clientVersion, kLegacyVersion);
      final r2 = FrsPageReqIdl.fromBuffer(multipartPayload(a.bodies[1])).data;
      expect(r2.pn, 3);
      expect(r2.rnNeed, 55);
      expect(r2.sortType, ThreadSort.hot);
      expect(r2.isGood, 1);
    });
  });

  group('getPosts 请求形态（pb/page，cmd=302001）', () {
    test('https + cmd；kz=tid、rn 钳制 [2,30]、r/lz 透传', () async {
      final a = ScriptedAdapter(<ResponseBody>[pbBody(), pbBody(), pbBody()]);
      final c = scripted(a);
      await c.getPosts(123456, pn: 2, rn: 1);
      await c.getPosts(123456, rn: 50, sort: PostSort.desc, onlyThreadAuthor: true);
      await c.getPosts(123456, rn: 15);
      expect(a.requests.first.uri.toString(),
          'https://$kAppHost/c/f/pb/page?cmd=$kPbPageCmd');
      final d1 = PbPageReqIdl.fromBuffer(multipartPayload(a.bodies[0])).data;
      expect(d1.kz.toInt(), 123456);
      expect(d1.pn, 2);
      expect(d1.rn, 2, reason: 'rn<2 钳到 2（get_posts/_api.py:34）');
      final d2 = PbPageReqIdl.fromBuffer(multipartPayload(a.bodies[1])).data;
      expect(d2.rn, 30, reason: 'rn>30 钳到 30');
      expect(d2.r, PostSort.desc);
      expect(d2.lz, 1);
      final d3 = PbPageReqIdl.fromBuffer(multipartPayload(a.bodies[2])).data;
      expect(d3.rn, 15);
      expect(d3.lz, 0);
    });
  });

  group('pb 响应解码与 errorno', () {
    test('errorno=0 → 返回 pb 对象；成功把 consecutiveFailures 归零', () async {
      final a = ScriptedAdapter(<ResponseBody>[frsBody()]);
      final c = scripted(a)..risk.consecutiveFailures = 2;
      final res = await c.getThreads('扫书');
      expect(res.error.errorno, 0);
      expect(c.risk.requests, 1);
      expect(c.risk.consecutiveFailures, 0);
    });

    test('errorno≠0 → TiebaServerException + errornoCount/consecutiveFailures/signal',
        () async {
      final a = ScriptedAdapter(<ResponseBody>[
        frsBody(errorno: 110001, errmsg: '登录态失效'),
      ]);
      final c = scripted(a);
      await expectLater(
        c.getThreads('扫书'),
        throwsA(isA<TiebaServerException>()
            .having((e) => e.code, 'code', 110001)
            .having((e) => e.msg, 'msg', '登录态失效')),
      );
      expect(c.risk.errornoCount, 1);
      expect(c.risk.consecutiveFailures, 1);
      expect(c.risk.signals.single, contains('errorno=110001'));
    });

    test('空 body（200 零字节）→ 默认实例成功，不误判风控', () async {
      final a = ScriptedAdapter(<ResponseBody>[protoBody(<int>[])]);
      final res = await scripted(a).getThreads('扫书');
      expect(res.error.errorno, 0);
      expect(res.data.threadList, isEmpty);
    });
  });

  group('风控信号（§8.12：验证码/HTTP/网络三类计数）', () {
    test('content-type text/html → CaptchaDetectedException + captchaCount', () async {
      final a = ScriptedAdapter(<ResponseBody>[
        protoBody(utf8.encode('<html><body>安全验证</body></html>'),
            contentType: 'text/html; charset=utf-8'),
      ]);
      final c = scripted(a);
      await expectLater(c.getThreads('扫书'),
          throwsA(isA<CaptchaDetectedException>()));
      expect(c.risk.captchaCount, 1);
      expect(c.risk.consecutiveFailures, 1);
      expect(c.risk.signals.single, contains('content-type=text/html'));
    });

    test('body 特征词 wappass（CT 仍是 octet-stream）→ 同样拦截', () async {
      final a = ScriptedAdapter(<ResponseBody>[
        protoBody(utf8.encode('${'x' * 200}wappass.baidu.com${'y' * 2000}')),
      ]);
      final c = scripted(a);
      await expectLater(c.getThreads('扫书'),
          throwsA(isA<CaptchaDetectedException>()
              .having((e) => e.evidence, 'evidence', contains('wappass'))));
      expect(c.risk.captchaCount, 1);
    });

    test('HTTP 429 → DioException rethrow + httpErrorCount + 风控特征 signal', () async {
      final a = ScriptedAdapter(<ResponseBody>[protoBody(<int>[], status: 429)]);
      final c = scripted(a);
      await expectLater(c.getThreads('扫书'), throwsA(isA<DioException>()));
      expect(c.risk.httpErrorCount, 1);
      expect(c.risk.consecutiveFailures, 1);
      expect(c.risk.signals.single, contains('(风控特征)'));
    });

    test('网络层异常 → networkErrorCount + net_ 前缀 signal，不计 httpError', () async {
      final c = TiebaClient(
        random: Random(1),
        minIntervalMs: 0,
        maxIntervalMs: 0,
        dio: Dio()..httpClientAdapter = TimeoutAdapter(),
      );
      await expectLater(c.getThreads('扫书'), throwsA(isA<DioException>()));
      expect(c.risk.networkErrorCount, 1);
      expect(c.risk.httpErrorCount, 0);
      expect(c.risk.signals.single, contains('net_connectionTimeout'));
    });
  });

  group('客户端熔断（连续失败 ≥3）', () {
    test('三连败后下一次请求零发包直接 CircuitBreakerException + breakerTrips',
        () async {
      final a = ScriptedAdapter(<ResponseBody>[
        frsBody(errorno: 1),
        frsBody(errorno: 1),
        frsBody(errorno: 1),
      ]);
      final c = scripted(a);
      for (var i = 0; i < 3; i++) {
        await expectLater(c.getThreads('扫书'),
            throwsA(isA<TiebaServerException>()));
      }
      expect(c.risk.tripped, isTrue);
      await expectLater(c.getThreads('扫书'),
          throwsA(isA<CircuitBreakerException>()));
      expect(a.requests, hasLength(3), reason: '熔断后不得再发包');
      expect(c.risk.breakerTrips, 1);
    });

    test('两败一成 → consecutiveFailures 归零，未触发熔断', () async {
      final a = ScriptedAdapter(<ResponseBody>[
        frsBody(errorno: 1),
        frsBody(errorno: 1),
        frsBody(),
      ]);
      final c = scripted(a);
      await expectLater(c.getThreads('扫书'), throwsA(anything));
      await expectLater(c.getThreads('扫书'), throwsA(anything));
      expect(c.risk.tripped, isFalse);
      await c.getThreads('扫书');
      expect(c.risk.consecutiveFailures, 0);
      expect(c.risk.breakerTrips, 0);
    });
  });

  group('RiskMonitor 契约', () {
    test('signal 环形上限 50：超出丢最旧', () {
      final m = RiskMonitor();
      for (var i = 0; i < 60; i++) {
        m.signal('s$i');
      }
      expect(m.signals, hasLength(50));
      expect(m.signals.first, 's10');
      expect(m.signals.last, 's59');
    });

    test('tripped 阈值 =3；totalAnomalies = 四类信号之和；toJson 键契约', () {
      final m = RiskMonitor()
        ..requests = 9
        ..errornoCount = 1
        ..captchaCount = 2
        ..httpErrorCount = 3
        ..networkErrorCount = 4
        ..consecutiveFailures = 2
        ..breakerTrips = 5;
      expect(m.tripped, isFalse);
      m.consecutiveFailures = 3;
      expect(m.tripped, isTrue);
      expect(m.totalAnomalies, 10);
      expect(
        m.toJson().keys,
        [
          'requests', 'errorno_count', 'captcha_count', 'http_error_count',
          'network_error_count', 'consecutive_failures', 'breaker_trips',
          'total_anomalies', 'signals',
        ],
      );
    });
  });

  group('节流', () {
    test('min=max=30ms → 每次请求前真实等待 ≥30ms（_throttle 生效）', () async {
      final a = ScriptedAdapter(<ResponseBody>[frsBody()]);
      final c = TiebaClient(
        random: Random(3),
        minIntervalMs: 30,
        maxIntervalMs: 30,
        dio: Dio()..httpClientAdapter = a,
      );
      final sw = Stopwatch()..start();
      await c.getThreads('扫书');
      sw.stop();
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(28));
    });
  });
}
