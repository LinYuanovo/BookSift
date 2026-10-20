import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/collector/post_refresh.dart';
import 'package:booksift/collector/scheduler.dart' show CollectRequestException;
import 'package:booksift/collector/tieba/src/models.dart';
import 'package:booksift/collector/tieba_api.dart' show PostsPage;
import 'package:booksift/data/db/app_database.dart';

import '../collector/support.dart';

// 任务 2：帖子图片签名刷新（PostRefreshService）。
//
// 全部 plain test()（TESTING.md §3.2）：内存库 + FakeTiebaApi 脚本化分页，
// 零真实网络；图片落库口径对齐 ingest.dart「删除旧行重插新行」。
// 末段为任务 3 的对齐键回归：pid 主键 + pid 缺失（NULL/0）时按位兜底。

ImageInfo _img(String original, String permanent, {int w = 100, int h = 80}) =>
    ImageInfo(
      urlOriginal: original,
      urlPermanent: permanent,
      hash: 'h',
      width: w,
      height: h,
    );

void main() {
  group('PostRefreshService.refreshPostImages', () {
    late AppDatabase db;
    late FakeTiebaApi api;
    late PostRefreshService service;
    late int postId;

    Future<int> seedFloor({
      required int? pid,
      int seq = 1,
      List<ImageInfo> images = const <ImageInfo>[],
    }) async {
      final int floorId = await db
          .into(db.floors)
          .insert(
            FloorsCompanion.insert(
              postId: postId,
              seq: seq,
              pid: Value<int?>(pid),
            ),
          );
      for (final ImageInfo img in images) {
        await db
            .into(db.images)
            .insert(
              ImagesCompanion.insert(
                floorId: floorId,
                urlOriginal: Value<String?>(img.urlOriginal),
                urlPermanent: Value<String?>(img.urlPermanent),
                width: Value<int>(img.width),
                height: Value<int>(img.height),
              ),
            );
      }
      return floorId;
    }

    Future<List<FloorImage>> imagesOf(int floorId) => (db.select(
      db.images,
    )..where((Images t) => t.floorId.equals(floorId))).get();

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      api = FakeTiebaApi(
        FakeClock(),
        holdTicks: 0,
      ); // 零事件循环停顿（plain test 真实事件循环）
      service = PostRefreshService(db: db, api: api);
      postId = await db
          .into(db.posts)
          .insert(
            PostsCompanion.insert(
              tid: const Value<int?>(5001),
              title: const Value<String?>('刷新目标帖'),
              channel: 'yy小说吧',
            ),
          );
    });
    tearDown(() async => db.close());

    test('过期链接被线上新签名替换（删除旧行重插新行）', () async {
      final int floorId = await seedFloor(
        pid: 101,
        images: <ImageInfo>[_img('orig_old', 'perm_old')],
      );
      api.scriptPosts(
        5001,
        1,
        PostsPage(
          floors: <FloorInfo>[
            mkFloor(
              pid: 101,
              seq: 1,
              images: <ImageInfo>[_img('orig_new', 'perm_new')],
            ),
          ],
          hasMore: false,
        ),
      );

      final PostRefreshResult r = await service.refreshPostImages(
        tid: 5001,
        postId: postId,
      );

      expect(r.changed, isTrue);
      expect(r.floorsAligned, 1);
      expect(r.imagesReplaced, 1);
      final List<FloorImage> rows = await imagesOf(floorId);
      expect(rows, hasLength(1));
      expect(rows.single.urlOriginal, 'orig_new');
      expect(rows.single.urlPermanent, 'perm_new');
    });

    test('线上图片与本地一致 → 不重写（changed=false，行 id 不变）', () async {
      final int floorId = await seedFloor(
        pid: 101,
        images: <ImageInfo>[_img('orig', 'perm')],
      );
      final int oldRowId = (await imagesOf(floorId)).single.id;
      api.scriptPosts(
        5001,
        1,
        PostsPage(
          floors: <FloorInfo>[
            mkFloor(
              pid: 101,
              seq: 1,
              images: <ImageInfo>[_img('orig', 'perm')],
            ),
          ],
          hasMore: false,
        ),
      );

      final PostRefreshResult r = await service.refreshPostImages(
        tid: 5001,
        postId: postId,
      );

      expect(r.changed, isFalse);
      expect(r.imagesReplaced, 0);
      expect(
        (await imagesOf(floorId)).single.id,
        oldRowId,
        reason: '相同图片集合不产生写库抖动',
      );
    });

    test('分页拉全（页数上限内 hasMore 链），两页楼层图片均落位', () async {
      final int f1 = await seedFloor(
        pid: 101,
        seq: 1,
        images: <ImageInfo>[_img('o1', 'p1_old')],
      );
      final int f2 = await seedFloor(
        pid: 102,
        seq: 2,
        images: <ImageInfo>[_img('o2', 'p2_old')],
      );
      api.scriptPosts(
        5001,
        1,
        PostsPage(
          floors: <FloorInfo>[
            mkFloor(
              pid: 101,
              seq: 1,
              images: <ImageInfo>[_img('o1', 'p1_new')],
            ),
          ],
          hasMore: true,
        ),
      );
      api.scriptPosts(
        5001,
        2,
        PostsPage(
          floors: <FloorInfo>[
            mkFloor(
              pid: 102,
              seq: 2,
              images: <ImageInfo>[_img('o2', 'p2_new')],
            ),
          ],
          hasMore: false,
        ),
      );

      final PostRefreshResult r = await service.refreshPostImages(
        tid: 5001,
        postId: postId,
      );

      expect(r.floorsAligned, 2);
      expect((await imagesOf(f1)).single.urlPermanent, 'p1_new');
      expect((await imagesOf(f2)).single.urlPermanent, 'p2_new');
      expect(
        api.countCalls((ApiCall c) => !c.isThreads),
        2,
        reason: '按 pn=1,2 两页拉取',
      );
    });

    test('线上楼层在本地无对应 pid → 跳过（不补楼层、不写图）', () async {
      final int floorId = await seedFloor(
        pid: 101,
        images: <ImageInfo>[_img('orig', 'perm')],
      );
      api.scriptPosts(
        5001,
        1,
        PostsPage(
          floors: <FloorInfo>[
            mkFloor(
              pid: 101,
              seq: 1,
              images: <ImageInfo>[_img('orig', 'perm')],
            ),
            mkFloor(pid: 999, seq: 2, images: <ImageInfo>[_img('o_x', 'p_x')]),
          ],
          hasMore: false,
        ),
      );

      final PostRefreshResult r = await service.refreshPostImages(
        tid: 5001,
        postId: postId,
      );

      expect(r.floorsAligned, 1);
      expect(r.changed, isFalse);
      expect(await imagesOf(floorId), hasLength(1), reason: '本地行数不变');
    });

    test('网络/验证码/熔断异常向上抛（UI 层负责静默兜底）', () async {
      api.failPosts(5001, errNetwork());
      await expectLater(
        service.refreshPostImages(tid: 5001, postId: postId),
        throwsA(isA<CollectRequestException>()),
      );
    });

    // ── 对齐键（任务 3）：pid 主键 + pid 缺失时按位兜底 ──

    test('本地 pid 全 NULL → 按位对齐，线上新签名链落库（changed=true）', () async {
      final int f1 = await seedFloor(
        pid: null,
        seq: 1,
        images: <ImageInfo>[_img('o1_old', 'p1_old')],
      );
      final int f2 = await seedFloor(
        pid: null,
        seq: 2,
        images: <ImageInfo>[_img('o2_old', 'p2_old')],
      );
      api.scriptPosts(
        5001,
        1,
        PostsPage(
          floors: <FloorInfo>[
            mkFloor(
              pid: 201,
              seq: 1,
              images: <ImageInfo>[_img('o1_new?tbpicau=2026-10-25', 'p1_new')],
            ),
            mkFloor(
              pid: 202,
              seq: 2,
              images: <ImageInfo>[_img('o2_new?tbpicau=2026-10-25', 'p2_new')],
            ),
          ],
          hasMore: false,
        ),
      );

      final PostRefreshResult r = await service.refreshPostImages(
        tid: 5001,
        postId: postId,
      );

      expect(r.floorsAligned, 2, reason: 'pid 缺失不阻断对齐（旧实现 aligned=0）');
      expect(r.changed, isTrue);
      expect(
        (await imagesOf(f1)).single.urlOriginal,
        'o1_new?tbpicau=2026-10-25',
      );
      expect(
        (await imagesOf(f2)).single.urlOriginal,
        'o2_new?tbpicau=2026-10-25',
      );
    });

    test('本地 pid=0 占位（种子实况 22.3%）→ 不塌进同一键，各楼层各归其图', () async {
      final int f1 = await seedFloor(
        pid: 0,
        seq: 1,
        images: <ImageInfo>[_img('a_old', 'a')],
      );
      final int f2 = await seedFloor(
        pid: 0,
        seq: 2,
        images: <ImageInfo>[_img('b_old', 'b')],
      );
      api.scriptPosts(
        5001,
        1,
        PostsPage(
          floors: <FloorInfo>[
            mkFloor(pid: 0, seq: 1, images: <ImageInfo>[_img('a_new', 'a')]),
            mkFloor(pid: 0, seq: 2, images: <ImageInfo>[_img('b_new', 'b')]),
          ],
          hasMore: false,
        ),
      );

      final PostRefreshResult r = await service.refreshPostImages(
        tid: 5001,
        postId: postId,
      );

      expect(r.floorsAligned, 2);
      expect((await imagesOf(f1)).single.urlOriginal, 'a_new');
      expect(
        (await imagesOf(f2)).single.urlOriginal,
        'b_new',
        reason: '旧实现两行共用 byPid[0]，图会全写进同一楼层',
      );
    });

    test('两侧楼层数不等（线上删楼/本地截断）→ 不做位置猜测', () async {
      final int f1 = await seedFloor(
        pid: null,
        seq: 1,
        images: <ImageInfo>[_img('o_old', 'p_old')],
      );
      api.scriptPosts(
        5001,
        1,
        PostsPage(
          floors: <FloorInfo>[
            mkFloor(pid: 301, seq: 1, images: <ImageInfo>[_img('o_new', 'p_new')]),
            mkFloor(pid: 302, seq: 3, images: <ImageInfo>[_img('x', 'y')]),
          ],
          hasMore: false,
        ),
      );

      final PostRefreshResult r = await service.refreshPostImages(
        tid: 5001,
        postId: postId,
      );

      expect(r.floorsAligned, 0);
      expect(r.changed, isFalse);
      expect(
        (await imagesOf(f1)).single.urlOriginal,
        'o_old',
        reason: '无 pid 且楼层数分歧 → 宁可不刷新，也不把图写错楼层',
      );
    });

    test('线上 seq 跳号（原帖删楼）+ 本地 seq 稠密重编号 → 按 pid 精确对齐不错位', () async {
      // 实测 tid=9379483707：本地 seq 1..4 ↔ 线上 seq 1,2,4,5（线上 3 楼已删）。
      final List<int> ids = <int>[];
      for (int i = 0; i < 4; i++) {
        ids.add(
          await seedFloor(
            pid: 101 + i,
            seq: i + 1,
            images: <ImageInfo>[_img('old_$i', 'p_$i')],
          ),
        );
      }
      api.scriptPosts(
        5001,
        1,
        PostsPage(
          floors: <FloorInfo>[
            for (int i = 0; i < 4; i++)
              mkFloor(
                pid: 101 + i,
                seq: i < 2 ? i + 1 : i + 2,
                images: <ImageInfo>[_img('new_$i', 'p_$i')],
              ),
          ],
          hasMore: false,
        ),
      );

      final PostRefreshResult r = await service.refreshPostImages(
        tid: 5001,
        postId: postId,
      );

      expect(r.floorsAligned, 4);
      for (int i = 0; i < 4; i++) {
        expect(
          (await imagesOf(ids[i])).single.urlOriginal,
          'new_$i',
          reason: '本地第 ${i + 1} 行须拿到 pid=${101 + i} 的线上图（按 seq 值匹配会错位）',
        );
      }
    });

    test('线上 pid=0 楼层不抢已有 pid 的本地行', () async {
      final int f1 = await seedFloor(
        pid: 101,
        seq: 1,
        images: <ImageInfo>[_img('o_old', 'p_old')],
      );
      api.scriptPosts(
        5001,
        1,
        PostsPage(
          floors: <FloorInfo>[
            mkFloor(pid: 0, seq: 1, images: <ImageInfo>[_img('o_thief', 'p_thief')]),
          ],
          hasMore: false,
        ),
      );

      final PostRefreshResult r = await service.refreshPostImages(
        tid: 5001,
        postId: postId,
      );

      expect(r.floorsAligned, 0);
      expect(r.changed, isFalse);
      expect((await imagesOf(f1)).single.urlOriginal, 'o_old');
    });
  });
}
