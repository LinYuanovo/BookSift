// headless 查询门面测试（query.dart）。
//
// plain test()：走 NativeDatabase（真实 FFI 同步执行，TESTING.md §1 允许），
// 但 createTemp/文件 IO 一律不进 testWidgets。
//
// 覆盖：门面转发是否真的落到 drift 实现 / overview() 的三块数据（表行数·水位·settings）/
// recentLogs 排序与 limit / ForumWatermark 与 JSON 映射的字段契约。
// 六维搜索的正确性由 features_test 与真实数据 CLI 验证覆盖，此处只验门面不吞异常。

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/collect_repository.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/headless/env.dart';
import 'package:booksift/headless/query.dart';

void main() {
  late AppDatabase db;
  late BookQueryApi api;

  setUp(() {
    db = HeadlessEnv.openMemoryDb();
    api = BookQueryApi(db);
  });

  tearDown(() async => db.close());

  Future<void> insertEntry({
    required String name,
    required String hash,
    String channel = 'yy小说吧',
    String category = '扫书',
    String? date = '2024-05-06',
  }) => db
      .into(db.bookEntries)
      .insert(
        BookEntriesCompanion.insert(
          name: name,
          nameNorm: name,
          channel: channel,
          contentHash: hash,
          category: Value<String>(category),
          date: Value<String?>(date),
        ),
      );

  group('门面转发', () {
    test('queries / repo 暴露的就是 drift 实现本体（不是空壳包装）', () {
      expect(api.queries, isA<Queries>());
      expect(api.repo, isA<CollectRepository>());
    });

    test('dimensionCounts 反映真实插入的行', () async {
      expect((await api.dimensionCounts()).total, 0);
      await insertEntry(name: '诡秘之主', hash: 'h1');
      await insertEntry(name: '大奉打更人', hash: 'h2', category: '排雷');

      final CategoryCounts c = await api.dimensionCounts();
      expect(c.total, 2);
      final DimCount mine = c.categories.firstWhere(
        (DimCount d) => d.value == CategoryKind.avoid,
      );
      expect(mine.count, 1);
    });

    test('search 不吞异常且返回可用的空结果形状', () async {
      final SearchOutcome out = await api.search(
        const SearchFilter(query: '不存在的书名'),
      );
      expect(out.page.items, isEmpty);
      expect(out.page.total, 0);
      expect(out.usedFts, isA<bool>());
      expect(out.degraded, isA<bool>());
    });
  });

  group('overview()', () {
    test('空库：schema v4、表齐、水位与 settings 为空', () async {
      final DbOverview ov = await api.overview();
      expect(ov.userVersion, 4);
      expect(
        ov.tables.keys,
        containsAll(<String>['book_entries', 'posts', 'collection_state']),
      );
      expect(ov.tables['book_entries'], 0);
      expect(ov.forums, isEmpty);
      expect(ov.settings, isEmpty);
    });

    test('表行数 / 水位 / settings 三块都跟得上真实写入', () async {
      await insertEntry(name: '诡秘之主', hash: 'h1');
      await insertEntry(name: '剑来', hash: 'h2');
      await api.repo.addForum('yy小说吧', fid: 123);
      await api.repo.setSetting('collect_budget_count', '7');

      final DbOverview ov = await api.overview();
      expect(ov.tables['book_entries'], 2);
      expect(ov.forums, hasLength(1));
      expect(ov.forums.single.fname, 'yy小说吧');
      expect(ov.forums.single.fid, 123);
      expect(ov.settings['collect_budget_count'], '7');
    });

    test('toJson 可直接序列化（agent 机读路径不能抛）', () async {
      await api.repo.addForum('哀伤雪刃');
      final Map<String, Object?> j = (await api.overview()).toJson();
      expect(j['userVersion'], 4);
      expect(j['tables'], isA<Map<String, int>>());
      expect(j['forums'], isA<List<Object?>>());
      expect(j['settings'], isA<Map<String, String>>());
    });
  });

  group('ForumWatermark', () {
    test('从 drift 行投影，字段不丢，JSON 键名稳定', () async {
      await api.repo.addForum('yy小说吧', fid: 42);
      final CollectionStateEntry row = (await api.repo.forums()).single;
      final ForumWatermark w = ForumWatermark.of(row);

      expect(w.fname, 'yy小说吧');
      expect(w.fid, 42);
      expect(w.enabled, isTrue);
      expect(w.lastStatus, row.lastStatus);
      expect(w.lastThreadTime, row.lastThreadTime);

      final Map<String, Object?> j = w.toJson();
      expect(j.keys.toSet(), <String>{
        'fname',
        'fid',
        'enabled',
        'lastStatus',
        'lastThreadTime',
        'lastRunAt',
        'lastTid',
        'consecutiveFailures',
        'cooldownUntil',
        'totalThreads',
        'totalFloors',
        'newSinceVisit',
        'lastError',
      });
    });
  });

  group('recentLogs', () {
    test('新在前，limit 生效，JSON 映射字段齐全', () async {
      expect(await api.recentLogs(), isEmpty);

      for (int i = 1; i <= 3; i++) {
        await api.repo.appendLog(
          CollectionLogsCompanion.insert(
            fname: 'yy小说吧',
            runAt: DateTime(2026, 10, 10 + i),
            status: i == 2 ? 'rate_limited' : 'ok',
            threadsAdded: Value<int>(i * 10),
            detail: Value<String?>('第 $i 轮'),
          ),
        );
      }

      final List<CollectionLog> all = await api.recentLogs();
      expect(all, hasLength(3));
      expect(all.first.runAt.isAfter(all.last.runAt), isTrue, reason: '新在前');

      expect(await api.recentLogs(limit: 2), hasLength(2));

      final Map<String, Object?> j = collectionLogJson(all.first);
      expect(j.keys.toSet(), <String>{
        'id',
        'fname',
        'runAt',
        'status',
        'threadsAdded',
        'floorsAdded',
        'entriesAdded',
        'skippedDup',
        'detail',
      });
      expect(j['threadsAdded'], 30);
    });
  });

  group('JSON 映射', () {
    test('entryRowJson / groupHitJson / searchOutcomeJson 键名固定', () {
      const EntryRow e = EntryRow(
        id: 1,
        name: '诡秘之主',
        nameNorm: '诡秘之主',
        channel: 'yy小说吧',
        category: '扫书',
        origin: 'builtin',
        quality: 3,
      );
      final Map<String, Object?> j = entryRowJson(e);
      expect(j['name'], '诡秘之主');
      expect(j['quality'], 3);
      expect(j.containsKey('recommendFlag'), isTrue);

      const GroupHit g = GroupHit(
        groupId: 9,
        name: '诡秘之主',
        nameNorm: '诡秘之主',
        hitCount: 3,
        recommendCount: 2,
        avoidCount: 1,
        channels: <String>['yy小说吧'],
        bestEntryId: 1,
        bestFlag: 1,
      );
      expect(groupHitJson(g)['avoidCount'], 1);

      const SearchOutcome out = SearchOutcome(
        page: Paged<GroupHit>(items: <GroupHit>[g], total: 1),
        usedFts: true,
        words: <String>['诡秘'],
      );
      final Map<String, Object?> oj = searchOutcomeJson(out);
      expect(oj['total'], 1);
      expect(oj['usedFts'], isTrue);
      expect(oj['words'], <String>['诡秘']);
      expect((oj['items'] as List).single, isA<Map<String, Object?>>());
    });
  });
}
