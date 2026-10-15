/// 帖子图片签名刷新（纯 Dart，零 flutter 依赖）。
///
/// 背景：百度图床链接会过期（images.url_original/url_permanent 签名参数失效 → 403）。
/// 打开帖子详情时由 content_detail_page 后台触发一次本服务：按 posts.tid 在线拉取
/// 该帖全部楼层，用 parse.dart 产出的图片列表按 floors.pid（缺失时按位）对齐本地行，
/// 事务内逐楼层「删除旧行重插新行」（口径同 ingest.dart 的楼层更新分支）。
///
/// 失败语义：网络/验证码/熔断等异常一律向上抛（CollectRequestException，见
/// tieba_api.dart mapTiebaError），调用方（UI 层）负责静默兜底。
library;

import 'package:drift/drift.dart';

import '../data/db/app_database.dart';
import 'collect_service.dart' show kMaxPostPages, kPostRn;
import 'tieba/src/models.dart';
import 'tieba_api.dart';

/// 在线帖拉取结果（不落库）：标题 + 全部楼层（任务 2 图片刷新 / 任务 3 在线帖页共用）。
class OnlinePostData {
  const OnlinePostData({
    required this.tid,
    required this.title,
    required this.floors,
    this.partial = false,
  });

  final int tid;
  final String title;

  /// 全部楼层（按 seq 升序、pid 去重后）。
  final List<FloorInfo> floors;

  /// 超长帖截断标记（pn 触顶 [kMaxPostPages] 仍有后继页）。
  final bool partial;
}

/// 按 tid 拉取全部楼层（pn=1.. 页数上限与采集同口径：kMaxPostPages/kPostRn，§8.7 步骤 4）。
///
/// 异常直接向上抛（ CollectRequestException ）；本函数只做拉取与整形，不碰数据库。
Future<OnlinePostData> fetchOnlinePost(
  TiebaApi api,
  int tid, {
  int maxPages = kMaxPostPages,
}) async {
  final List<FloorInfo> floors = <FloorInfo>[];
  final Set<int> seenPid = <int>{};
  String title = '';
  bool partial = false;
  for (int pn = 1; pn <= maxPages; pn++) {
    final PostsPage page = await api.getPosts(tid, pn: pn, rn: kPostRn);
    if (page.title.isNotEmpty) {
      title = page.title;
    }
    for (final FloorInfo f in page.floors) {
      if (f.pid == 0 || seenPid.add(f.pid)) {
        floors.add(f);
      }
    }
    if (!page.hasMore) {
      break;
    }
    if (pn == maxPages) {
      partial = true;
    }
  }
  floors.sort((FloorInfo a, FloorInfo b) => a.seq.compareTo(b.seq));
  return OnlinePostData(
    tid: tid,
    title: title,
    floors: floors,
    partial: partial,
  );
}

/// 图片刷新统计（[changed] 决定 UI 是否需要 invalidate 重读）。
class PostRefreshResult {
  const PostRefreshResult({
    required this.floorsAligned,
    required this.imagesReplaced,
    required this.changed,
  });

  /// 线上楼层对齐到本地 floors 的数量（主键 pid，pid 缺失时按位兜底，见 [PostRefreshService.alignFloors]）。
  final int floorsAligned;

  /// 实际重插的图片行数。
  final int imagesReplaced;

  /// 是否有任一楼层的图片集合发生变化（无变化 = 未写库）。
  final bool changed;
}

class PostRefreshService {
  PostRefreshService({required this.db, required this.api});

  final AppDatabase db;
  final TiebaApi api;

  /// 刷新 [postId]（对应线上 tid）全部楼层的图片链接。
  ///
  /// 逐楼层先比对既有图片行与线上列表，**相同则跳过**（避免无效重写与 UI 抖动）；
  /// 不同才删除旧行重插新行（ingest.dart 楼层更新分支同款事务口径）。
  Future<PostRefreshResult> refreshPostImages({
    required int tid,
    required int postId,
  }) async {
    final OnlinePostData online = await fetchOnlinePost(api, tid);
    final List<Floor> locals = await (db.select(
      db.floors,
    )
          ..where((Floors t) => t.postId.equals(postId))
          // id 升序 = 入库序 = 楼层序（位置兜底配对依赖此顺序确定性）。
          ..orderBy([(Floors t) => OrderingTerm.asc(t.id)]))
        .get();
    final List<({FloorInfo online, Floor local})> pairs = alignFloors(
      online.floors,
      locals,
    );
    int replaced = 0;
    bool changed = false;
    await db.transaction(() async {
      for (final ({FloorInfo online, Floor local}) pair in pairs) {
        final Floor local = pair.local;
        final List<ImageInfo> next = pair.online.images;
        final List<FloorImage> old = await (db.select(
          db.images,
        )..where((Images t) => t.floorId.equals(local.id))).get();
        if (_sameImages(old, next)) {
          continue;
        }
        await (db.delete(
          db.images,
        )..where((Images t) => t.floorId.equals(local.id))).go();
        for (final ImageInfo img in next) {
          await db
              .into(db.images)
              .insert(
                ImagesCompanion.insert(
                  floorId: local.id,
                  urlOriginal: Value<String?>(
                    img.urlOriginal.isEmpty ? null : img.urlOriginal,
                  ),
                  urlPermanent: Value<String?>(
                    img.urlPermanent.isEmpty ? null : img.urlPermanent,
                  ),
                  width: Value<int>(img.width),
                  height: Value<int>(img.height),
                ),
              );
        }
        replaced += next.length;
        changed = true;
      }
    });
    return PostRefreshResult(
      floorsAligned: pairs.length,
      imagesReplaced: replaced,
      changed: changed,
    );
  }

  /// 线上楼层 ↔ 本地楼层对齐（任务 3）。
  ///
  /// 主键 **pid**（仅 >0 有效：种子库 22.3% 的楼层 pid=0，若一并入键，同帖所有
  /// pid=0 行会塌进同一个 map 项互相吞并，线上 pid=0 楼层还会把图写进错的楼层）。
  ///
  /// pid 缺失（NULL/0）的本地行退化为**按位**配对，且仅当两侧楼层数相等（无删楼/
  /// 补楼分歧）时启用；线上有而本地无的楼层不补（截断/删楼：只刷新既有楼层）。
  ///
  /// **不按 seq 值对齐**：种子库的 floors.seq 是稠密重编号，原帖删楼会让线上 seq
  /// 跳号——实测 tid=9379483707：本地 seq 7 ↔ 线上 seq 8、本地 12 ↔ 线上 14，
  /// 两侧都是 12 楼，按 seq 值匹配会整段错位写图。
  static List<({FloorInfo online, Floor local})> alignFloors(
    List<FloorInfo> online,
    List<Floor> locals,
  ) {
    final Map<int, Floor> byPid = <int, Floor>{
      for (final Floor f in locals)
        if (_hasPid(f.pid)) f.pid!: f,
    };
    final List<({FloorInfo online, Floor local})> pairs =
        <({FloorInfo online, Floor local})>[];
    final Set<int> usedLocal = <int>{};
    final Set<int> usedOnline = <int>{};
    for (int oi = 0; oi < online.length; oi++) {
      final FloorInfo f = online[oi];
      if (!_hasPid(f.pid)) {
        continue;
      }
      final Floor? hit = byPid[f.pid];
      if (hit != null && usedLocal.add(hit.id)) {
        usedOnline.add(oi);
        pairs.add((online: f, local: hit));
      }
    }
    if (online.length != locals.length) {
      return pairs;
    }
    for (int i = 0; i < locals.length; i++) {
      final Floor local = locals[i];
      // 有 pid 的行只认主键（位置猜测可能把它配到别的楼层）。
      if (_hasPid(local.pid) || usedOnline.contains(i)) {
        continue;
      }
      usedOnline.add(i);
      usedLocal.add(local.id);
      pairs.add((online: online[i], local: local));
    }
    return pairs;
  }

  /// pid 可用性：NULL 与 0 都视为「无 pid」（种子库用 0 占位缺失）。
  static bool _hasPid(int? pid) => pid != null && pid > 0;

  /// 既有图片行与线上图片列表的逐位比对（序敏感：与渲染顺序一致）。
  static bool _sameImages(List<FloorImage> old, List<ImageInfo> next) {
    if (old.length != next.length) {
      return false;
    }
    for (int i = 0; i < old.length; i++) {
      final ImageInfo img = next[i];
      final String? nextOriginal = img.urlOriginal.isEmpty
          ? null
          : img.urlOriginal;
      final String? nextPermanent = img.urlPermanent.isEmpty
          ? null
          : img.urlPermanent;
      if (old[i].urlOriginal != nextOriginal ||
          old[i].urlPermanent != nextPermanent ||
          old[i].width != img.width ||
          old[i].height != img.height) {
        return false;
      }
    }
    return true;
  }
}
