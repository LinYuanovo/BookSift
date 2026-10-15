/// TiebaApi 边界抽象（调度器/测试注入点）+ 生产实现 ProtoTiebaApi。
///
/// 边界返回**纯数据模型**（tieba/src/models.dart），protobuf → 模型的转换
/// （fetch_poc.dart 同款字段路径）与异常统一映射都在本文件完成；
/// 调度器只见 [ThreadsPage]/[PostsPage]/[CollectRequestException]，
/// 测试用脚本化假实现（test/collector/support.dart）免网络免 proto。
library;

import 'package:dio/dio.dart';

import 'scheduler.dart';
import 'tieba/src/proto/Post.pb.dart';
import 'tieba/src/proto/ThreadInfo.pb.dart';
import 'tieba/src/proto/User.pb.dart';
import 'tieba/tieba_client.dart';

/// get_threads 一页（§8.7 步骤 1-3）。
class ThreadsPage {
  const ThreadsPage({
    required this.fid,
    required this.threads,
    required this.hasMore,
  });

  /// 吧 fid（0 = 响应未携带；addForum 以此判吧不存在）。
  final int fid;
  final List<ThreadSummary> threads;
  final bool hasMore;
}

/// get_posts 一页（§8.7 步骤 4：pn=1.. ≤20 页 rn=30 ASC，翻页由调度器循环）。
class PostsPage {
  const PostsPage({
    required this.floors,
    required this.hasMore,
    this.title = '',
    this.authorId = 0,
    this.author = '',
    this.authorUserName = '',
    this.createTime = 0,
    this.replyNum = 0,
  });

  final List<FloorInfo> floors;
  final bool hasMore;

  /// 帖元信息（本页 thread/user_list 携带则填，缺省 0/''——调度器跨页回退）。
  final String title;
  final int authorId;
  final String author;

  /// 楼主 user_name（唯一标识，posts.author_name；显示名走 [author]）。
  final String authorUserName;
  final int createTime;
  final int replyNum;
}

/// 采集调度器依赖的贴吧接口（get_threads / get_posts 两枚，§8.2）。
abstract interface class TiebaApi {
  Future<ThreadsPage> getThreads(String fname, {int pn = 1, int rn = 100});

  Future<PostsPage> getPosts(int tid, {int pn = 1, int rn = 30});

  void close();
}

/// 生产实现：包装 [TiebaClient]（app-proto 通道）。
///
/// 内部节流关闭（min=max=0）：全局间隔/预算由调度层的 [GlobalRateLimiter]
/// 统一核算（§8.8「必须一处核算」）；RiskMonitor 计数保留作观测。
class ProtoTiebaApi implements TiebaApi {
  ProtoTiebaApi({TiebaClient? client})
      : _client = client ??
            TiebaClient(minIntervalMs: 0, maxIntervalMs: 0),
        _ownsClient = client == null;

  /// 冒烟工具用：自带节流（1.5–3.0s）的客户端直连场景。
  ProtoTiebaApi.withOwnThrottle()
      : _client = TiebaClient(),
        _ownsClient = true;

  final TiebaClient _client;
  final bool _ownsClient;

  RiskMonitor get risk => _client.risk;

  @override
  Future<ThreadsPage> getThreads(String fname,
      {int pn = 1, int rn = 100}) async {
    final FrsPageResIdl res;
    try {
      res = await _client.getThreads(fname, pn: pn, rn: rn);
    } catch (e) {
      throw mapTiebaError(e);
    }
    final FrsPageResIdl_DataRes d = res.data;
    final Map<int, String> userNames = <int, String>{};
    for (final User u in d.userList) {
      userNames[u.id.toInt()] = displayName(u);
    }
    final List<ThreadSummary> threads = <ThreadSummary>[];
    for (final ThreadInfo t in d.threadList) {
      final int tid = t.id.toInt();
      if (tid == 0) continue;
      final int authorId = t.authorId.toInt();
      threads.add(ThreadSummary(
        tid: tid,
        title: t.title,
        authorId: authorId,
        author: userNames[authorId] ??
            (t.hasAuthor() ? displayName(t.author) : ''),
        createTime: t.createTime,
        lastTime: t.lastTimeInt,
        replyNum: t.replyNum,
        viewNum: t.viewNum,
        isTop: t.isTop != 0,
        isGood: t.isGood != 0,
        isDeleted: t.isDeleted != 0,
        isFrsMask: t.isFrsMask != 0,
        threadType: t.threadType,
      ));
    }
    return ThreadsPage(
      fid: d.hasForum() ? d.forum.id.toInt() : 0,
      threads: threads,
      hasMore: d.page.hasMore != 0,
    );
  }

  @override
  Future<PostsPage> getPosts(int tid, {int pn = 1, int rn = 30}) async {
    final PbPageResIdl res;
    try {
      res = await _client.getPosts(tid, pn: pn, rn: rn);
    } catch (e) {
      throw mapTiebaError(e);
    }
    final PbPageResIdl_DataRes d = res.data;
    final Map<int, String> displayNames = <int, String>{};
    final Map<int, String> userNames = <int, String>{};
    for (final User u in d.userList) {
      displayNames[u.id.toInt()] = displayName(u);
      userNames[u.id.toInt()] = u.name;
    }
    final int threadAuthorId =
        d.hasThread() ? d.thread.authorId.toInt() : 0;
    final List<FloorInfo> floors = <FloorInfo>[];
    for (final Post p in d.postList) {
      final int pid = p.id.toInt();
      final AssembledContent c = assembleContent(p.content);
      final int fAuthorId = p.authorId.toInt();
      floors.add(FloorInfo(
        pid: pid,
        seq: p.floor,
        authorId: fAuthorId,
        author: displayNames[fAuthorId] ??
            (p.hasAuthor() ? displayName(p.author) : ''),
        time: p.time,
        text: c.text,
        images: c.images,
        agreeNum: p.hasAgree() ? p.agree.agreeNum.toInt() : 0,
        subPostNumber: p.subPostNumber,
        isThreadAuthor: fAuthorId == threadAuthorId && threadAuthorId != 0,
      ));
    }
    return PostsPage(
      floors: floors,
      hasMore: d.page.hasMore != 0,
      title: d.hasThread() ? d.thread.title : '',
      authorId: threadAuthorId,
      author: displayNames[threadAuthorId] ?? '',
      authorUserName: userNames[threadAuthorId] ?? '',
      createTime: d.hasThread() ? d.thread.createTime : 0,
      replyNum: d.hasThread() ? d.thread.replyNum : 0,
    );
  }

  @override
  void close() {
    if (_ownsClient) _client.close();
  }
}

/// TiebaClient 异常族 → [CollectRequestException] 统一映射。
///
/// rate_limited 判定（§8.12：风控/封禁 = 429/110xxx）：
/// - errorno ∈ [110000, 111000)（登录态/风控类，§8.10 失效检测同源）；
/// - HTTP 429/403（tieba_client._onDioException 同款「风控特征」）；
/// - 验证码页（CaptchaDetectedException）。
CollectRequestException mapTiebaError(Object e) {
  if (e is CollectRequestException) return e;
  if (e is TiebaServerException) {
    final bool rateLimited = e.code >= 110000 && e.code < 111000;
    return CollectRequestException(
      kind: rateLimited
          ? CollectFailureKind.rateLimited
          : CollectFailureKind.serverError,
      code: e.code,
      message: 'errorno=${e.code} ${e.msg}',
    );
  }
  if (e is CaptchaDetectedException) {
    return CollectRequestException(
      kind: CollectFailureKind.rateLimited,
      message: '验证码页拦截（${e.evidence}）',
    );
  }
  if (e is CircuitBreakerException) {
    return const CollectRequestException(
      kind: CollectFailureKind.serverError,
      message: '客户端熔断（连续异常≥3）',
    );
  }
  if (e is DioException) {
    final int? status = e.response?.statusCode;
    if (status != null) {
      return CollectRequestException(
        kind: status == 429 || status == 403
            ? CollectFailureKind.rateLimited
            : CollectFailureKind.serverError,
        code: status,
        message: 'HTTP $status',
      );
    }
    return CollectRequestException(
      kind: CollectFailureKind.network,
      message: '网络异常 ${e.type.name}: ${e.message ?? ''}',
    );
  }
  return CollectRequestException(
    kind: CollectFailureKind.network,
    message: '$e',
  );
}
