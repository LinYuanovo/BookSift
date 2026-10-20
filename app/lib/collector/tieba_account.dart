/// BDUSS 有效性探测（设置页「测试」按钮消费）：app-form 通道 `c/s/initNickname`。
///
/// 规格出处 aiotieba a5472be `api/get_selfinfo_initNickname/_api.py:27-37`：
/// 参数 `BDUSS` + `_client_version=LATEST_VERSION`，`pack_form_request` 走
/// APP_SALT 签名（与 searchpost 同款 [computeFormSign]）；响应 JSON
/// `error_code`/`error_msg` + `user_info{user_name,name_show,tieba_uid}`
/// （`_classdef.py:29-34`）。
///
/// 只做**一次**请求、零重试；凭证只在请求体里、不写日志。测试用脚本化 dio
/// override（[tiebaAccountProbeProvider]），零真实网络。
library;

import 'dart:convert';

import 'package:dio/dio.dart';

import 'scheduler.dart' show kLoginInvalidHints;
import 'tieba/tieba_client.dart' show kAppHost, kUserAgent;
import 'tieba_search.dart' show computeFormSign, kLatestClientVersion;

/// initNickname 端点（https；aiotieba `URL.build(scheme="https", host=APP_BASE_HOST)`）。
const String kInitNicknameUrl = 'https://$kAppHost/c/s/initNickname';

/// 探测结论类别。
enum TiebaAccountProbeKind {
  /// 凭证有效（error_code=0）。
  ok,

  /// 登录态失效（errorno ∈ [110000,111000) 或未登录语义）→ 应重新导入。
  invalid,

  /// 风控/验证码/HTTP 429·403 → 结论不明，稍后再试。
  risk,

  /// 网络异常/超时。
  network,

  /// 其他服务端错误 / 响应格式异常。
  server,
}

/// 单次探测结果。
class TiebaAccountProbeResult {
  const TiebaAccountProbeResult(this.kind, {this.nickname = '', this.message = ''});

  final TiebaAccountProbeKind kind;

  /// 昵称（[TiebaAccountProbeKind.ok] 时有值；取不到回落 user_name，可能为空）。
  final String nickname;

  /// 失败细节（errorno 文案 / HTTP 状态 / 异常摘要），供 UI 提示。
  final String message;
}

/// 探测客户端（dio 可注入）。
class TiebaAccountProbe {
  TiebaAccountProbe({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              followRedirects: false, // 302 视为风控信号（TiebaClient 同款）
            ));

  final Dio _dio;

  /// 校验 [bduss]：成功返回昵称；失败按 风控/网络/服务端 分档（文案由 UI 组装）。
  Future<TiebaAccountProbeResult> check(String bduss) async {
    final Map<String, String> params = <String, String>{
      'BDUSS': bduss,
      '_client_version': kLatestClientVersion,
    };
    params['sign'] = computeFormSign(params);
    final String body = params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    final Response<String> resp;
    try {
      resp = await _dio.post<String>(
        kInitNicknameUrl,
        data: body,
        options: Options(
          responseType: ResponseType.plain,
          headers: <String, dynamic>{
            'User-Agent': kUserAgent,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          validateStatus: (int? s) => s == 200,
        ),
      );
    } on DioException catch (e) {
      final int? status = e.response?.statusCode;
      if (status != null) {
        return TiebaAccountProbeResult(
          status == 429 || status == 403
              ? TiebaAccountProbeKind.risk
              : TiebaAccountProbeKind.server,
          message: 'HTTP $status',
        );
      }
      return TiebaAccountProbeResult(TiebaAccountProbeKind.network,
          message: '${e.type.name}: ${e.message ?? ''}');
    }

    final String text = resp.data ?? '';
    // 验证码页/HTML 特征（TiebaSearchClient._checkCaptcha 同款标记集）。
    final String probe = text.length > 1024 ? text.substring(0, 1024) : text;
    for (final String marker in const <String>['wappass', '<!DOCTYPE', '<html', '安全验证', '验证码']) {
      if (probe.contains(marker)) {
        return TiebaAccountProbeResult(TiebaAccountProbeKind.risk,
            message: '命中验证码页特征（$marker）');
      }
    }

    dynamic json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      return const TiebaAccountProbeResult(TiebaAccountProbeKind.server,
          message: '响应不是 JSON');
    }
    if (json is! Map) {
      return const TiebaAccountProbeResult(TiebaAccountProbeKind.server,
          message: '响应根节点非对象');
    }
    final Map<String, dynamic> root = Map<String, dynamic>.from(json);
    final int code = _intOf(root['error_code']);
    if (code != 0) {
      final String msg = '${root['error_msg'] ?? ''}';
      final bool loginInvalid = (code >= 110000 && code < 111000) ||
          kLoginInvalidHints.any((String h) => msg.contains(h));
      return TiebaAccountProbeResult(
        loginInvalid ? TiebaAccountProbeKind.invalid : TiebaAccountProbeKind.server,
        message: 'errorno=$code $msg'.trim(),
      );
    }
    final dynamic user = root['user_info'];
    String nickname = '';
    if (user is Map) {
      nickname = '${user['name_show'] ?? ''}'.trim();
      if (nickname.isEmpty) {
        nickname = '${user['user_name'] ?? ''}'.trim();
      }
    }
    return TiebaAccountProbeResult(TiebaAccountProbeKind.ok, nickname: nickname);
  }

  static int _intOf(Object? v) => v is int ? v : (int.tryParse('$v') ?? 0);

  void close() => _dio.close(force: true);
}
