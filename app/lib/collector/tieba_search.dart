/// 贴吧在线搜索客户端（app-form 通道 `c/s/searchpost`，匿名 + APP_SALT MD5 签名）。
///
/// 规格出处（docs/2026-10-12_产品原型设计-Flutter扫书App.md）：
/// - §8.2 接口总表（行 1268）：POST `http://tiebac.baidu.com/c/s/searchpost`，
///   `application/x-www-form-urlencoded`，匿名，🟢 low，吧内在线搜索（P2-2）；
/// - §8.4（行 1331–1366）sign 精确规则：全部参数（不含 sign）按 key 字典序升序、
///   `key=value` 无分隔符拼接 + APP_SALT `tiebaclient!!!` → MD5 32 位小写 hex；
///   签名仅用于 app-form 通道（protobuf 通道免签）；
/// - §8.2 固定参数值（行 1950）：searchpost 用 `_client_version=22.12.1.0`（LATEST）、
///   `_client_type=2`。
///
/// 字段口径对照 aiotieba commit a5472be（只读核对）：
/// - 请求参数：`api/search_in_forum/_api.py:26-45`（kw/only_thread/pn/rn/sm/word）
///   + `core/http.py pack_form_request:91-120`（sign → urlencode body）；
/// - 响应 JSON：`api/search_in_forum/_classdef.py`（顶层 `post_list`/`page`；
///   条目字段 tid/title/fname/author.name_show/time；`page.has_more`）；
/// - 签名：`helper/crypto/sign.py compute_sign` + `helper/crypto/const.py APP_SALT`。
///
/// 频控口径复用 collector（tieba/tieba_client.dart 同款）：[RiskMonitor] 计数、
/// 1.5~3.0s 均匀随机节流、连续失败 ≥3 熔断、验证码页/HTML 特征识别；异常统一映射
/// [CollectRequestException]（tieba_api.mapTiebaError 同一出口）；响应结构漂移
/// （疑似接口变更，§8.12 降级矩阵）抛 [TiebaSearchFormatException]。
///
/// **单请求手动触发**：一次 [search] 调用 = 一个 searchpost 请求，不做自动翻页/批量。
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../core/constants.dart' show AppConstants;
import 'scheduler.dart' show CollectRequestException;
import 'tieba/tieba_client.dart'
    show
        CaptchaDetectedException,
        CircuitBreakerException,
        RiskMonitor,
        TiebaServerException,
        kAppHost,
        kUserAgent;
import 'tieba_api.dart' show mapTiebaError;

/// searchpost 端点（§8.2：app-form 通道，http 明文，与 aiotieba URL.build 一致）。
const String kSearchPostUrl = 'http://$kAppHost/c/s/searchpost';

/// searchpost 用 LATEST_VERSION（aiotieba const.py:1；原型 §8.2 行 1950）。
const String kLatestClientVersion = '22.12.1.0';

/// APP_SALT（aiotieba helper/crypto/const.py:1；原型 §8.4）。
const String kAppSalt = 'tiebaclient!!!';

/// sm 搜索排序（aiotieba enums.py SearchInForumType；原型 §8.3 ④）。
abstract final class ForumSearchSort {
  /// 0 = 全部。
  static const int all = 0;

  /// 1 = 时间倒序。
  static const int time = 1;

  /// 2 = 相关性。
  static const int relation = 2;
}

/// sign = MD5(参数按 key 字典序升序 `key=value` 无分隔符拼接 + APP_SALT)，32 位小写 hex。
///
/// 精确规则见原型 §8.4 / aiotieba helper/crypto/sign.py compute_sign；
/// 入参不得含 sign 本身。测试向量见 test/search/online_search_test.dart。
String computeFormSign(Map<String, String> params) {
  final List<String> keys = params.keys.toList()..sort();
  final StringBuffer buf = StringBuffer();
  for (final String k in keys) {
    buf.write('$k=${params[k]}');
  }
  buf.write(kAppSalt);
  return md5.convert(utf8.encode(buf.toString())).toString();
}

/// 在线搜索单条结果（展示口径：标题/吧名/作者/回复数/时间）。
class OnlineThread {
  const OnlineThread({
    required this.tid,
    required this.title,
    required this.forumName,
    required this.author,
    required this.replyNum,
    required this.createTime,
    this.excerpt = '',
  });

  final int tid;
  final String title;
  final String forumName;
  final String author;

  /// 回复数；响应未携带 reply_num 字段时为 0（aiotieba _classdef.py 未解析该字段，宽松处理）。
  final int replyNum;

  /// Unix 秒（0 = 未携带）。
  final int createTime;

  /// 帖内命中摘要（searchpost 的 content/abstract；空 = 接口未带）。展示前已剥标签、截 100 字。
  final String excerpt;

  /// 原帖链接（行点击复制口径；原型附录 B 外链端点清单 `/p/{tid}`）。
  String get url => 'https://tieba.baidu.com/p/$tid';
}

/// searchpost 一页响应（post_list + Page_fsch，aiotieba _classdef.py 同构）。
class OnlineSearchPage {
  const OnlineSearchPage({
    required this.threads,
    required this.hasMore,
    this.currentPage = 0,
    this.totalPage = 0,
    this.totalCount = 0,
  });

  final List<OnlineThread> threads;
  final bool hasMore;
  final int currentPage;
  final int totalPage;
  final int totalCount;
}

/// 响应结构与归档口径不符（JSON 解析失败 / 缺 post_list / 字段漂移）→
/// 疑似接口变更（§8.12 降级矩阵「接口签名/协议变更」行，UI 出降级文案）。
class TiebaSearchFormatException implements Exception {
  const TiebaSearchFormatException(this.detail);

  final String detail;

  @override
  String toString() => 'TiebaSearchFormatException($detail)';
}

/// 匿名在线搜索客户端（dio 可注入；测试用 mock adapter 脚本化 JSON/错误，零真实网络）。
///
/// search() 只抛两类异常：[CollectRequestException]（网络/风控/服务端，collector
/// 统一口径）与 [TiebaSearchFormatException]（结构漂移，§8.12）。
class TiebaSearchClient {
  TiebaSearchClient({
    Dio? dio,
    Random? random,
    this.minIntervalMs = 1500,
    this.maxIntervalMs = 3000,
  })  : _rng = random ?? Random(),
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 15),
              followRedirects: false, // 302 视为风控信号，不跟随（TiebaClient 同款）
            ));

  final Dio _dio;
  final Random _rng;

  /// 风控/异常计数（与 collector 同一 [RiskMonitor] 口径；验收：totalAnomalies=0）。
  final RiskMonitor risk = RiskMonitor();

  /// 节流下限（ms）。默认 1500：单请求手动触发也走 ≥1.5s 节流（§8.11 匿名档）。
  final int minIntervalMs;

  /// 节流上限（ms）。
  final int maxIntervalMs;

  /// 1.5~3.0s 均匀随机抖动（TiebaClient._throttle 同款）。
  Future<void> _throttle() async {
    final int span = maxIntervalMs - minIntervalMs;
    final int ms = minIntervalMs + (span > 0 ? _rng.nextInt(span + 1) : 0);
    await Future<void>.delayed(Duration(milliseconds: ms));
  }

  /// 吧内搜索（search_in_forum 同参：aiotieba `search_in_forum(fname_or_fid, query,
  /// pn=1, rn=30, search_type=ALL, only_thread=False)`）。pn 从 1 起。
  Future<OnlineSearchPage> search(
    String forum,
    String query, {
    int pn = 1,
    int rn = 30,
    int sm = ForumSearchSort.all,
    bool onlyThread = false,
  }) async {
    // 表单参数（_api.py:27-35 + §8.2 行 1950 固定值；值一律字符串化后参与签名）。
    final Map<String, String> params = <String, String>{
      '_client_type': '2',
      '_client_version': kLatestClientVersion,
      'kw': forum,
      'only_thread': onlyThread ? '1' : '0',
      'pn': '$pn',
      'rn': '$rn',
      'sm': '$sm',
      'word': query,
    };
    params['sign'] = computeFormSign(params);
    // urlencode body（core/http.py:105-108：quote_plus 口径 = Uri.encodeQueryComponent，
    // 空格 → '+'；签名按原始值计算，编码只作用于传输层）。
    final String body = params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    if (risk.tripped) {
      risk.breakerTrips++;
      throw mapTiebaError(CircuitBreakerException());
    }
    await _throttle();
    risk.requests++;

    final Response<String> resp;
    try {
      resp = await _dio.post<String>(
        kSearchPostUrl,
        data: body,
        options: Options(
          responseType: ResponseType.plain, // 手动 jsonDecode：先过验证码页/HTML 特征检查
          headers: <String, dynamic>{
            'User-Agent': kUserAgent,
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept-Encoding': 'gzip',
            'Connection': 'keep-alive',
          },
          validateStatus: (int? s) => s == 200,
        ),
      );
    } on DioException catch (e) {
      _onDioException(e);
      throw mapTiebaError(e);
    }

    final String text = resp.data ?? '';
    try {
      _checkCaptcha(resp, text);
      return _parse(text, pn);
    } on CaptchaDetectedException catch (e) {
      throw mapTiebaError(e);
    } on TiebaServerException catch (e) {
      throw mapTiebaError(e);
    }
  }

  /// 验证码页/HTML 特征识别（TiebaClient._checkCaptcha 同款标记集）。
  void _checkCaptcha(Response<String> resp, String text) {
    final String ct = resp.headers.value('content-type') ?? '';
    String? evidence;
    if (ct.contains('text/html')) {
      evidence = 'content-type=$ct';
    } else if (text.isNotEmpty) {
      final String probe = text.length > 1024 ? text.substring(0, 1024) : text;
      for (final String marker in const <String>['wappass', '<!DOCTYPE', '<html', '安全验证', '验证码']) {
        if (probe.contains(marker)) {
          evidence = 'body contains "$marker"';
          break;
        }
      }
    }
    if (evidence != null) {
      risk.captchaCount++;
      risk.consecutiveFailures++;
      risk.signal('captcha@searchpost: $evidence');
      throw CaptchaDetectedException(evidence);
    }
  }

  void _onDioException(DioException e) {
    risk.consecutiveFailures++;
    final int? status = e.response?.statusCode;
    if (status != null) {
      risk.httpErrorCount++;
      risk.signal('http_$status@searchpost${status == 429 || status == 403 ? ' (风控特征)' : ''}');
    } else {
      risk.networkErrorCount++;
      risk.signal('net_${e.type.name}@searchpost: ${e.message}');
    }
  }

  /// 结构漂移统一记账 + 抛出（协议级异常计入 errorno 档，保证 totalAnomalies 口径完整）。
  Never _failFormat(String detail) {
    risk.errornoCount++;
    risk.consecutiveFailures++;
    risk.signal('format@searchpost: $detail');
    throw TiebaSearchFormatException(detail);
  }

  /// 响应 JSON → [OnlineSearchPage]（_classdef.py from_json 同构，字段宽松）。
  OnlineSearchPage _parse(String text, int pn) {
    dynamic json;
    try {
      json = jsonDecode(text);
    } on FormatException catch (e) {
      _failFormat('JSON 解析失败: ${e.message}');
    }
    if (json is! Map) {
      _failFormat('根节点非对象: ${json.runtimeType}');
    }
    Map<String, dynamic> root = Map<String, dynamic>.from(json);
    // 双口径兼容：aiotieba a5472be 在顶层解析 post_list/page（_classdef.py），
    // 原型 §8.3④ 示例为 data 包裹 → 取含 post_list 的一侧。
    if (!root.containsKey('post_list') && root['data'] is Map) {
      root = Map<String, dynamic>.from(root['data'] as Map);
    }
    final int code = _intOf(root['error_code']);
    if (code != 0) {
      final String msg = '${root['error_msg'] ?? ''}';
      risk.errornoCount++;
      risk.consecutiveFailures++;
      risk.signal('errorno=$code@searchpost: $msg');
      throw TiebaServerException(code, msg);
    }
    final dynamic rawList = root['post_list'];
    if (rawList is! List) {
      _failFormat('缺 post_list（实际键: ${root.keys.join(',')}）');
    }
    final List<OnlineThread> threads = <OnlineThread>[];
    for (final dynamic item in rawList) {
      if (item is! Map) continue;
      final int tid = _intOf(item['tid']);
      if (tid == 0) continue; // 删帖/异常条目跳过
      final dynamic author = item['author'];
      final Map? authorMap = author is Map ? author : null;
      threads.add(OnlineThread(
        tid: tid,
        title: _stripTags('${item['title'] ?? ''}'),
        forumName: '${item['fname'] ?? ''}',
        author: '${authorMap?['name_show'] ?? authorMap?['name'] ?? ''}',
        replyNum: _intOf(item['reply_num']),
        createTime: _intOf(item['time']),
        excerpt: _excerptOf(item),
      ));
    }
    // Page_fsch（_classdef.py）；缺失宽松处理为无后继页。
    bool hasMore = false;
    int currentPage = pn, totalPage = 0, totalCount = 0;
    final dynamic rawPage = root['page'];
    if (rawPage is Map) {
      hasMore = _intOf(rawPage['has_more']) != 0;
      currentPage = _intOf(rawPage['current_page']);
      totalPage = _intOf(rawPage['total_page']);
      totalCount = _intOf(rawPage['total_count']);
    }
    risk.consecutiveFailures = 0;
    return OnlineSearchPage(
      threads: threads,
      hasMore: hasMore,
      currentPage: currentPage,
      totalPage: totalPage,
      totalCount: totalCount,
    );
  }

  /// 数值字段宽松解析（服务端 int/string 混发，aiotieba 一律 int() 强转同口径）。
  static int _intOf(Object? v) => v is int ? v : (int.tryParse('$v') ?? 0);

  /// 搜索命中可能带 `<em>` 高亮标签，展示前剥掉。
  static final RegExp _tagRe = RegExp(r'<[^>]*>');

  static String _stripTags(String s) => s.replaceAll(_tagRe, '').trim();

  /// 帖内摘要：接口字段名不稳定（content / abstract / content_abstract），取第一个非空，
  /// 与本地卡预览同口径（100 字截断 + 「…」，[AppConstants.previewMaxChars]）。
  static String _excerptOf(Map<dynamic, dynamic> item) {
    for (final String key in const <String>['content', 'abstract', 'content_abstract']) {
      final String raw = _stripTags('${item[key] ?? ''}');
      if (raw.isNotEmpty) {
        final List<int> runes = raw.runes.toList();
        return runes.length > AppConstants.previewMaxChars
            ? '${String.fromCharCodes(runes.take(AppConstants.previewMaxChars))}…'
            : raw;
      }
    }
    return '';
  }

  void close() => _dio.close(force: true);
}
