// 矩阵补缺：边界转换层（lib/collector/tieba_api.dart）。
//
// 缺口依据（docs/测试矩阵.md §3）：protobuf→纯模型转换（ThreadsPage/PostsPage）与
// mapTiebaError 异常族映射此前零直接测试——调度层测试注入的是 FakeTiebaApi，
// 映射表（§8.12 rate_limited 判定口径）漂移不会被任何既有用例抓到。
// 注入脚本化 dio adapter，全部 plain test()、零真实网络（TESTING.md §3.2）。
@Timeout(Duration(minutes: 2))
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:booksift/collector/scheduler.dart';
import 'package:booksift/collector/tieba/tieba_client.dart';
import 'package:booksift/collector/tieba/src/proto/Agree.pb.dart';
import 'package:booksift/collector/tieba/src/proto/Error.pb.dart' as pberr;
import 'package:booksift/collector/tieba/src/proto/Page.pb.dart';
import 'package:booksift/collector/tieba/src/proto/PbContent.pb.dart';
import 'package:booksift/collector/tieba/src/proto/Post.pb.dart';
import 'package:booksift/collector/tieba/src/proto/ThreadInfo.pb.dart';
import 'package:booksift/collector/tieba/src/proto/User.pb.dart';
import 'package:booksift/collector/tieba_api.dart';
import 'package:dio/dio.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

// ─────────────────────── 脚本化 dio adapter（与 proto_client_test 同款） ───

class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter(this.script);

  final List<ResponseBody> script;
  final List<RequestOptions> requests = <RequestOptions>[];
  bool closed = false;
  int _next = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (requestStream != null) {
      await requestStream.drain<void>();
    }
    requests.add(options);
    if (_next >= script.length) {
      throw StateError('ScriptedAdapter 脚本耗尽（第 ${_next + 1} 个请求）');
    }
    return script[_next++];
  }

  @override
  void close({bool force = false}) => closed = true;
}

ResponseBody protoBody(List<int> bytes,
        {int status = 200, String contentType = 'application/octet-stream'}) =>
    ResponseBody.fromBytes(bytes, status, headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[contentType],
    });

({ProtoTiebaApi api, ScriptedAdapter adapter}) scriptedApi(
    List<ResponseBody> script) {
  final a = ScriptedAdapter(script);
  final client = TiebaClient(
    random: Random(11),
    minIntervalMs: 0,
    maxIntervalMs: 0,
    dio: Dio()..httpClientAdapter = a,
  );
  return (api: ProtoTiebaApi(client: client), adapter: a);
}

DioException dioWithStatus(int status) {
  final ro = RequestOptions(path: '/c/f/frs/page');
  return DioException(
    requestOptions: ro,
    response: Response<void>(requestOptions: ro, statusCode: status),
    type: DioExceptionType.badResponse,
  );
}

void main() {
  group('mapTiebaError 异常族映射（§8.12 口径）', () {
    test('CollectRequestException 原样透传（同一实例）', () {
      const e = CollectRequestException(
          kind: CollectFailureKind.network, message: 'x');
      expect(identical(mapTiebaError(e), e), isTrue);
    });

    test('TiebaServerException：110xxx→rateLimited，边界外→serverError，code 保留',
        () {
      CollectRequestException m(int code) =>
          mapTiebaError(TiebaServerException(code, 'msg$code'));
      expect(m(110000).kind, CollectFailureKind.rateLimited);
      expect(m(110999).kind, CollectFailureKind.rateLimited);
      expect(m(109999).kind, CollectFailureKind.serverError);
      expect(m(111000).kind, CollectFailureKind.serverError);
      expect(m(2).kind, CollectFailureKind.serverError);
      expect(m(110001).code, 110001);
      expect(m(110001).message, contains('errorno=110001'));
    });

    test('CaptchaDetected→rateLimited（含证据）；CircuitBreaker→serverError', () {
      final cap = mapTiebaError(CaptchaDetectedException('body contains "wappass"'));
      expect(cap.kind, CollectFailureKind.rateLimited);
      expect(cap.message, contains('wappass'));
      expect(mapTiebaError(CircuitBreakerException()).kind,
          CollectFailureKind.serverError);
    });

    test('DioException：429/403→rateLimited，其余状态→serverError，无响应→network', () {
      expect(mapTiebaError(dioWithStatus(429)).kind,
          CollectFailureKind.rateLimited);
      expect(mapTiebaError(dioWithStatus(403)).kind,
          CollectFailureKind.rateLimited);
      expect(mapTiebaError(dioWithStatus(429)).code, 429);
      expect(mapTiebaError(dioWithStatus(500)).kind,
          CollectFailureKind.serverError);
      final net = mapTiebaError(DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionTimeout,
        message: 'boom',
      ));
      expect(net.kind, CollectFailureKind.network);
      expect(net.message, contains('connectionTimeout'));
      expect(net.message, contains('boom'));
    });

    test('未知异常兜底 → network，message 为原文', () {
      final e = mapTiebaError(StateError('库炸了'));
      expect(e.kind, CollectFailureKind.network);
      expect(e.message, contains('库炸了'));
    });
  });

  group('ProtoTiebaApi.getThreads 转换', () {
    test('全量字段：fid/hasMore/线程 13 字段 + userList 显示名映射', () async {
      final res = FrsPageResIdl()
        ..error = (pberr.Error()..errorno = 0)
        ..data = (FrsPageResIdl_DataRes()
          ..forum = (FrsPageResIdl_DataRes_ForumInfo()..id = Int64(77))
          ..page = (Page()..hasMore = 1)
          ..userList.add(User()
            ..id = Int64(5)
            ..name = 'uname5'
            ..nameShow = '显示名5')
          ..threadList.addAll([
            ThreadInfo()
              ..id = Int64(101)
              ..title = 't101'
              ..authorId = Int64(5)
              ..createTime = 1000
              ..lastTimeInt = 2000
              ..replyNum = 3
              ..viewNum = 4
              ..isTop = 1
              ..isGood = 0
              ..isDeleted = 0
              ..isFrsMask = 0
              ..threadType = 4,
            ThreadInfo()
              ..id = Int64(0)
              ..title = '应被跳过',
            ThreadInfo()
              ..id = Int64(102)
              ..title = 't102'
              ..authorId = Int64(9)
              ..author = (User()..nameShow = '内嵌作者'),
          ]));
      final s = scriptedApi([protoBody(res.writeToBuffer())]);
      final page = await s.api.getThreads('扫书');
      expect(page.fid, 77);
      expect(page.hasMore, isTrue);
      expect(page.threads, hasLength(2), reason: 'tid=0 条目必须跳过');
      final t0 = page.threads[0];
      expect(t0.tid, 101);
      expect(t0.author, '显示名5', reason: 'userList 命中 → displayName');
      expect(t0.createTime, 1000);
      expect(t0.lastTime, 2000);
      expect(t0.replyNum, 3);
      expect(t0.viewNum, 4);
      expect(t0.isTop, isTrue);
      expect(t0.isGood, isFalse);
      expect(t0.threadType, 4);
      expect(page.threads[1].author, '内嵌作者',
          reason: 'userList 未命中 → 回退 thread.author');
    });

    test('无 forum → fid=0；无 author 且 userList 未命中 → 空串', () async {
      final res = FrsPageResIdl()
        ..error = (pberr.Error()..errorno = 0)
        ..data = (FrsPageResIdl_DataRes()
          ..threadList.add(ThreadInfo()
            ..id = Int64(1)
            ..authorId = Int64(404)));
      final s = scriptedApi([protoBody(res.writeToBuffer())]);
      final page = await s.api.getThreads('扫书');
      expect(page.fid, 0);
      expect(page.hasMore, isFalse);
      expect(page.threads.single.author, '');
    });

    test('errorno≠0 → 已包成 CollectRequestException（不泄漏 TiebaServerException）',
        () async {
      final res = FrsPageResIdl()
        ..error = (pberr.Error()
          ..errorno = 110001
          ..errmsg = 'x');
      final s = scriptedApi([protoBody(res.writeToBuffer())]);
      await expectLater(
        s.api.getThreads('扫书'),
        throwsA(isA<CollectRequestException>()
            .having((e) => e.kind, 'kind', CollectFailureKind.rateLimited)
            .having((e) => e.code, 'code', 110001)),
      );
    });

    test('垃圾字节（非 pb）→ 兜底 network，不裸抛 InvalidProtocolBuffer', () async {
      final s = scriptedApi([protoBody([0xFF, 0xFF, 0xFF, 0xFF])]);
      await expectLater(
        s.api.getThreads('扫书'),
        throwsA(isA<CollectRequestException>()
            .having((e) => e.kind, 'kind', CollectFailureKind.network)),
      );
    });
  });

  group('ProtoTiebaApi.getPosts 转换', () {
    test('楼层拼装：文本+图片+视频占位、agree、subPostNumber、isThreadAuthor', () async {
      final res = PbPageResIdl()
        ..error = (pberr.Error()..errorno = 0)
        ..data = (PbPageResIdl_DataRes()
          ..page = (Page()..hasMore = 0)
          ..thread = (ThreadInfo()
            ..id = Int64(101)
            ..title = '帖题'
            ..authorId = Int64(5)
            ..createTime = 111
            ..replyNum = 9)
          ..userList.addAll([
            User()
              ..id = Int64(5)
              ..name = 'u5'
              ..nameShow = '五',
            User()
              ..id = Int64(6)
              ..name = 'u6',
          ])
          ..postList.addAll([
            Post()
              ..id = Int64(1001)
              ..floor = 1
              ..authorId = Int64(5)
              ..time = 1700000000
              ..subPostNumber = 2
              ..agree = (Agree()..agreeNum = Int64(7))
              ..content.addAll([
                PbContent()
                  ..type = 0
                  ..text = '推荐',
                PbContent()
                  ..type = 3
                  ..cdnSrc =
                      'https://tiebapic.baidu.com/forum/pic/item/0123456789abcdef0123456789abcdef.jpg'
                  ..bsize = '100,200',
                PbContent()..type = 5,
              ]),
            Post()
              ..id = Int64(1002)
              ..floor = 2
              ..authorId = Int64(6)
              ..time = 1,
          ]));
      final s = scriptedApi([protoBody(res.writeToBuffer())]);
      final page = await s.api.getPosts(101);
      expect(page.title, '帖题');
      expect(page.authorId, 5);
      expect(page.author, '五');
      expect(page.authorUserName, 'u5', reason: 'authorUserName 走 name 非显示名');
      expect(page.createTime, 111);
      expect(page.replyNum, 9);
      expect(page.hasMore, isFalse);
      expect(page.floors, hasLength(2));

      final f0 = page.floors[0];
      expect(f0.pid, 1001);
      expect(f0.seq, 1);
      expect(f0.text, '推荐[视频]');
      expect(f0.images, hasLength(1));
      expect(f0.images.single.hash, '0123456789abcdef0123456789abcdef');
      expect(f0.images.single.width, 100);
      expect(f0.agreeNum, 7);
      expect(f0.subPostNumber, 2);
      expect(f0.isThreadAuthor, isTrue);
      expect(f0.author, '五');

      final f1 = page.floors[1];
      expect(f1.agreeNum, 0, reason: '无 agree 字段 → 0');
      expect(f1.isThreadAuthor, isFalse);
      expect(f1.author, 'u6', reason: 'nameShow 空 → 回退 name');
    });

    test('无 thread 元信息 → 标题空/authorId 0，isThreadAuthor 全 false', () async {
      final res = PbPageResIdl()
        ..error = (pberr.Error()..errorno = 0)
        ..data = (PbPageResIdl_DataRes()
          ..postList.add(Post()
            ..id = Int64(1)
            ..floor = 1
            ..authorId = Int64(0)));
      final s = scriptedApi([protoBody(res.writeToBuffer())]);
      final page = await s.api.getPosts(999);
      expect(page.title, '');
      expect(page.authorId, 0);
      expect(page.createTime, 0);
      expect(page.floors.single.isThreadAuthor, isFalse,
          reason: 'threadAuthorId=0 时不得把 0 号作者判成楼主');
    });

    test('楼层作者 userList 未命中 → 回退 post.author 内嵌对象', () async {
      final res = PbPageResIdl()
        ..error = (pberr.Error()..errorno = 0)
        ..data = (PbPageResIdl_DataRes()
          ..postList.add(Post()
            ..id = Int64(1)
            ..floor = 1
            ..authorId = Int64(42)
            ..author = (User()..name = 'fallback42')));
      final s = scriptedApi([protoBody(res.writeToBuffer())]);
      final page = await s.api.getPosts(999);
      expect(page.floors.single.author, 'fallback42');
    });
  });

  group('资源所有权', () {
    test('注入 client → api.close() 不关底层 dio（HEADLESS 不变量 10 同源）', () {
      final s = scriptedApi(<ResponseBody>[]);
      s.api.close();
      expect(s.adapter.closed, isFalse);
    });

    test('risk 观测口透传：api.risk 即 client.risk', () async {
      final s = scriptedApi([
        protoBody((FrsPageResIdl()
              ..error = (pberr.Error()..errorno = 1))
            .writeToBuffer()),
      ]);
      await expectLater(s.api.getThreads('扫书'),
          throwsA(isA<CollectRequestException>()));
      expect(s.api.risk.errornoCount, 1);
    });
  });
}
