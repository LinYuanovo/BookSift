/// 贴吧客户端（app-proto 通道；默认匿名，可传 [TiebaClient.bduss] 切账号档）。
/// 请求形态对齐 aiotieba core/http.py pack_proto_request + get_threads/get_posts _api.py：
///   POST multipart/form-data; boundary=-*_r1999，单 part name="data"; filename="file"
///   （part 无 Content-Type），头 x_bd_data_type: protobuf；protobuf 通道免 APP_SALT 签名。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fixnum/fixnum.dart';

import 'src/proto/CommonReq.pb.dart';
import 'src/proto/FrsPageReqIdl.pb.dart';
import 'src/proto/FrsPageResIdl.pb.dart';
import 'src/proto/PbPageReqIdl.pb.dart';
import 'src/proto/PbPageResIdl.pb.dart';

export 'src/models.dart';
export 'src/parse.dart';
export 'src/proto/FrsPageResIdl.pb.dart';
export 'src/proto/PbPageResIdl.pb.dart';

const String kAppHost = 'tiebac.baidu.com'; // aiotieba const.py APP_BASE_HOST
const String kLegacyVersion = '12.64.1.1'; // aiotieba const.py LEGACY_VERSION
const String kUserAgent = 'aiotieba/22.12.1.0'; // 任意稳定 UA 即可（原型文档 §8.2）
const int kFrsPageCmd = 301001; // get_threads
const int kPbPageCmd = 302001; // get_posts
const String kBoundary = '-*_r1999'; // 与 aiotieba 一致，便于抓包比对

/// frs sort_type（enums.py ThreadSortType）
class ThreadSort {
  static const int create = 1;
  static const int hot = 3;
  static const int reply = 6;
}

/// pb r 排序（enums.py PostSortType）
class PostSort {
  static const int asc = 0;
  static const int desc = 1;
  static const int hot = 2;
}

class TiebaServerException implements Exception {
  TiebaServerException(this.code, this.msg);
  final int code;
  final String msg;
  @override
  String toString() => 'TiebaServerException(code=$code, msg=$msg)';
}

class CaptchaDetectedException implements Exception {
  CaptchaDetectedException(this.evidence);
  final String evidence;
  @override
  String toString() => 'CaptchaDetectedException($evidence)';
}

class CircuitBreakerException implements Exception {
  @override
  String toString() => 'CircuitBreakerException(连续失败>=3, 熔断)';
}

/// 风控/异常信号计数（验收口径：全部为 0 即"风控观察为零"）
class RiskMonitor {
  int requests = 0;
  int errornoCount = 0; // error.errorno != 0
  int captchaCount = 0; // HTML/验证码页特征
  int httpErrorCount = 0; // 非 200（含 302/403/429）
  int networkErrorCount = 0; // 连接/超时/TLS 异常
  int consecutiveFailures = 0;
  int breakerTrips = 0;
  final List<String> signals = [];

  bool get tripped => consecutiveFailures >= 3;
  int get totalAnomalies =>
      errornoCount + captchaCount + httpErrorCount + networkErrorCount;

  void signal(String s) {
    signals.add(s);
    if (signals.length > 50) signals.removeAt(0);
  }

  Map<String, dynamic> toJson() => {
        'requests': requests,
        'errorno_count': errornoCount,
        'captcha_count': captchaCount,
        'http_error_count': httpErrorCount,
        'network_error_count': networkErrorCount,
        'consecutive_failures': consecutiveFailures,
        'breaker_trips': breakerTrips,
        'total_anomalies': totalAnomalies,
        'signals': signals,
      };
}

class TiebaClient {
  TiebaClient({
    Random? random,
    this.minIntervalMs = 1500,
    this.maxIntervalMs = 3000,
    this.bduss,
    Dio? dio,
  })  : _rng = random ?? Random(),
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 15),
              followRedirects: false, // 302 视为风控信号，不跟随
            ));

  final Dio _dio;
  final Random _rng;
  final RiskMonitor risk = RiskMonitor();
  final int minIntervalMs;
  final int maxIntervalMs;

  /// 贴吧登录凭证（null = 匿名档）。非空时写入每个请求 `common.BDUSS`
  /// （账号维度配额 300→600，原型 §8.11）；值只在内存中传递，不落盘、不写日志。
  final String? bduss;

  /// 1.5~3.0s 均匀随机抖动（原型文档 §8.11 匿名档）
  Future<void> _throttle() async {
    final span = maxIntervalMs - minIntervalMs;
    final ms = minIntervalMs + (span > 0 ? _rng.nextInt(span + 1) : 0);
    await Future<void>.delayed(Duration(milliseconds: ms));
  }

  /// common 请求体。proto 通道免 APP_SALT 签名（aiotieba core/http.py:122-154
  /// pack_proto_request）；BDUSS 非空时写 `common.BDUSS`（aiotieba
  /// api/get_posts/_api.py:38 同口径）；匿名档不触碰该字段 —— 请求体字节与历史一致。
  CommonReq _common() {
    final CommonReq req = CommonReq()
      ..clientType = 2
      ..clientVersion = kLegacyVersion;
    final String? bduss = this.bduss;
    if (bduss != null && bduss.isNotEmpty) {
      req.bDUSS = bduss;
    }
    return req;
  }

  Future<Uint8List> _postProto(String url, Uint8List protoBytes) async {
    if (risk.tripped) {
      risk.breakerTrips++;
      throw CircuitBreakerException();
    }
    await _throttle();
    risk.requests++;

    // 手写 multipart body：单 part、无 part 级 Content-Type（core/http.py:134-142）
    final head = utf8.encode(
        '--$kBoundary\r\nContent-Disposition: form-data; name="data"; filename="file"\r\n\r\n');
    final tail = utf8.encode('\r\n--$kBoundary--\r\n');
    final body = (BytesBuilder()
          ..add(head)
          ..add(protoBytes)
          ..add(tail))
        .toBytes();

    try {
      final resp = await _dio.post<Uint8List>(
        url,
        data: body,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'User-Agent': kUserAgent,
            'x_bd_data_type': 'protobuf',
            'Accept-Encoding': 'gzip',
            'Connection': 'keep-alive',
            'Content-Type': 'multipart/form-data; boundary=$kBoundary',
          },
          validateStatus: (s) => s == 200,
        ),
      );
      final bytes = resp.data ?? Uint8List(0);
      _checkCaptcha(resp, bytes); // 命中即 throw，计入 captchaCount
      return bytes;
    } on DioException catch (e) {
      _onDioException(url, e);
      rethrow;
    }
  }

  /// 验证码页/HTML 特征识别：Content-Type=text/html、或 body 前 1KB 含
  /// wappass/<!DOCTYPE/<html/安全验证 等（protobuf 响应首字节为 field tag，不会是 '<'）
  void _checkCaptcha(Response<Uint8List> resp, Uint8List bytes) {
    final ct = resp.headers.value('content-type') ?? '';
    String? evidence;
    if (ct.contains('text/html')) {
      evidence = 'content-type=$ct';
    } else if (bytes.isNotEmpty) {
      final probe =
          utf8.decode(bytes.sublist(0, min(bytes.length, 1024)),
              allowMalformed: true);
      for (final marker in ['wappass', '<!DOCTYPE', '<html', '安全验证', '验证码']) {
        if (probe.contains(marker)) {
          evidence = 'body contains "$marker"';
          break;
        }
      }
    }
    if (evidence != null) {
      risk.captchaCount++;
      risk.consecutiveFailures++;
      risk.signal('captcha@${resp.realUri}: $evidence');
      throw CaptchaDetectedException(evidence);
    }
  }

  void _onDioException(String url, DioException e) {
    risk.consecutiveFailures++;
    final status = e.response?.statusCode;
    if (status != null) {
      risk.httpErrorCount++;
      risk.signal(
          'http_$status@$url${status == 429 || status == 403 ? ' (风控特征)' : ''}');
    } else {
      risk.networkErrorCount++;
      risk.signal('net_${e.type.name}@$url: ${e.message}');
    }
  }

  /// get_threads：吧内主题列表。pn 为 1 基页码（首页映射 pn=0，get_threads/_api.py:23）
  Future<FrsPageResIdl> getThreads(
    String fname, {
    int pn = 1,
    int rn = 100,
    int sortType = ThreadSort.create,
    bool isGood = false,
  }) async {
    final data = FrsPageReqIdl_DataReq()
      ..common = _common()
      ..kw = fname
      ..pn = pn == 1 ? 0 : pn
      ..rn = rn
      ..rnNeed = rn + 5
      ..isGood = isGood ? 1 : 0
      ..sortType = sortType;
    final req = FrsPageReqIdl()..data = data;

    final bytes = await _postProto(
        'http://$kAppHost/c/f/frs/page?cmd=$kFrsPageCmd', req.writeToBuffer());
    final res = FrsPageResIdl.fromBuffer(bytes);
    _checkErrorno(res.error.errorno, res.error.errmsg, 'frs/page pn=$pn');
    risk.consecutiveFailures = 0;
    return res;
  }

  /// get_posts：主题帖楼层。pn 从 1 开始；rn ∈ [2,30]（get_posts/_api.py:34）；
  /// 本版不抓楼中楼（with_floor 未开；日后要抓需 with_floor=1 且 common.BDUSS 非空，
  /// 原型 §8.7 行 1309）。
  Future<PbPageResIdl> getPosts(
    int tid, {
    int pn = 1,
    int rn = 30,
    int sort = PostSort.asc,
    bool onlyThreadAuthor = false,
  }) async {
    final data = PbPageReqIdl_DataReq()
      ..common = _common()
      ..kz = Int64(tid)
      ..pn = pn
      ..rn = rn.clamp(2, 30)
      ..r = sort
      ..lz = onlyThreadAuthor ? 1 : 0;
    final req = PbPageReqIdl()..data = data;

    final bytes = await _postProto(
        'https://$kAppHost/c/f/pb/page?cmd=$kPbPageCmd', req.writeToBuffer());
    final res = PbPageResIdl.fromBuffer(bytes);
    _checkErrorno(res.error.errorno, res.error.errmsg, 'pb/page tid=$tid pn=$pn');
    risk.consecutiveFailures = 0;
    return res;
  }

  void _checkErrorno(int errorno, String errmsg, String where) {
    if (errorno != 0) {
      risk.errornoCount++;
      risk.consecutiveFailures++;
      risk.signal('errorno=$errorno@$where: $errmsg');
      throw TiebaServerException(errorno, errmsg);
    }
  }

  void close() => _dio.close(force: true);
}
