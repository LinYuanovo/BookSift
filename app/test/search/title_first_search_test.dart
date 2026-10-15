// 两级检索回归守卫（真机反馈的检索质量 bug）。
//
// 现象：搜书名「我一个护林员」返回同楼层的其它书（《从气运词条开始成就人皇》
// 《从红楼开始纵横武侠世界》…），且每张卡显示同一段高亮摘要。
// 根因：book_entries.comment 存的是**整层帖子正文**——一个扫书楼里的所有书共用同一段
// comment，FTS/LIKE 匹配 comment 就把同楼所有书一并命中；FTS 的 snippet(comment)
// 又给这些名字没命中的书配上同一段楼层文字。
// 修复：searchBooks 改两级——第一级只匹配 name/name_norm/author/author_norm
// （FTS 用列过滤 {name author} : "词"），有命中即收口；零命中才放开到第二级
// （现状全列匹配，含 recommender/comment），保住「按推荐语/正文找书」的召回。
//
// plain test()：内存 drift + NativeDatabase 同步 FFI（TESTING.md §1 允许），
// 与 recall_norm_fallback_test.dart 同款骨架。

import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/headless/env.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

/// 一整层扫书楼的共用正文（三本书同楼 → comment 逐字相同，且含「护林员」）。
const String kFloorComment =
    '本月扫书楼汇总：《从气运词条开始成就人皇》走气运流，《从红楼开始纵横武侠世界》是武侠同人，'
    '《我在乡下种田》偏日常。另外提一句，护林员题材最近很火，喜欢山林流的可以关注。';

/// 书名命中那一本自己的推荐语（书名出现在正文中段，用于断言摘要锚点）。
const String kSelfComment =
    '这一楼扫了很多本，我个人最推荐《我一个护林员》，主角从护林员一路写到封神，节奏稳，人物立得住。';

void main() {
  late AppDatabase db;
  late Queries queries;

  setUp(() {
    db = HeadlessEnv.openMemoryDb();
    queries = Queries(db);
  });

  tearDown(() async => db.close());

  Future<void> insertEntry({
    required String name,
    required String nameNorm,
    required String hash,
    String? author,
    String? recommender,
    String? comment,
    String? date = '2025-04-20',
  }) =>
      db.into(db.bookEntries).insert(BookEntriesCompanion.insert(
            name: name,
            nameNorm: nameNorm,
            author: Value<String?>(author),
            recommender: Value<String?>(recommender),
            comment: Value<String?>(comment),
            channel: 'yy小说吧',
            contentHash: hash,
            date: Value<String?>(date),
          ));

  SearchFilter filter(String q) => SearchFilter(query: q);

  group('同层正文不再污染书名检索（第一级）', () {
    setUp(() async {
      // 同层 3 本：书名都不含「护林员」，但共用一段含「护林员」的整层正文。
      await insertEntry(
        name: '《从气运词条开始成就人皇》',
        nameNorm: '从气运词条开始成就人皇',
        hash: 'h1',
        comment: kFloorComment,
        date: '2025-04-20',
      );
      await insertEntry(
        name: '《从红楼开始纵横武侠世界》',
        nameNorm: '从红楼开始纵横武侠世界',
        hash: 'h2',
        comment: kFloorComment,
        date: '2025-04-19',
      );
      await insertEntry(
        name: '《我在乡下种田》',
        nameNorm: '我在乡下种田',
        hash: 'h3',
        comment: kFloorComment,
        date: '2025-04-18',
      );
      // 书名命中的那一本。
      await insertEntry(
        name: '《我一个护林员》',
        nameNorm: '我一个护林员',
        hash: 'h4',
        author: '山林客',
        comment: kSelfComment,
        date: '2025-04-21',
      );
      // 只有 recommender 命中：验证第一级不把推荐人列算进去。
      await insertEntry(
        name: '《雪原往事》',
        nameNorm: '雪原往事',
        hash: 'h5',
        recommender: '护林员爱好者',
        comment: '跟山林无关的一本都市文。',
        date: '2025-04-17',
      );
      // 书名命中但正文里没有书名：验证「无锚点则不出摘要」。
      await insertEntry(
        name: '《山中有灵》',
        nameNorm: '山中有灵',
        hash: 'h6',
        comment: '这段正文压根没提书名，只写了些别的感受，字数也不短，够长以便触发截窗逻辑。',
        date: '2025-04-16',
      );
    });

    test('搜书名（≥3 字走 FTS）只返回书名命中的那一本，不带出同楼其它书', () async {
      final SearchOutcome out = await queries.searchBooks(filter('护林员'));
      expect(out.page.total, 1, reason: '同楼共用 comment 的 3 本 + recommender 命中的 1 本都不该出现');
      expect(out.page.items.single.name, contains('我一个护林员'));
      expect(out.usedFts, isTrue, reason: '≥3 字仍走 book_fts（第一级用列过滤 {name author}）');
      expect(out.degraded, isFalse, reason: '列过滤在 trigram 下可用，不是异常降级');
    });

    test('第一级摘要以该书书名为锚截窗，不是楼层正文开头', () async {
      final SearchOutcome out = await queries.searchBooks(filter('护林员'));
      final String? snippet = out.page.items.single.snippet;
      expect(snippet, isNotNull);
      // `[词]` 标记落在书名上（FTS snippet(comment) 的旧口径会给名字命中的书配无关楼层文字）。
      expect(snippet, contains('[《我一个护林员》]'));
      expect(snippet, startsWith('…'), reason: '书名在正文中段 → 截窗前有省略号');
    });

    test('第一级命中但正文里没有书名 → 不出摘要（宁缺毋滥）', () async {
      final SearchOutcome out = await queries.searchBooks(filter('山中有灵'));
      expect(out.page.total, 1);
      expect(out.page.items.single.snippet, isNull, reason: '既不锚书名也不锚查询词 → null，而非正文开头');
    });

    test('2 字词 LIKE 路径同样只匹配书名/作者四列', () async {
      final SearchOutcome out = await queries.searchBooks(filter('护林'));
      expect(out.page.total, 1);
      expect(out.page.items.single.name, contains('我一个护林员'));
      expect(out.usedFts, isFalse, reason: '2 字词 trigram 恒零命中 → LIKE');
    });

    test('作者列仍参与第一级（书名不含查询词也能命中）', () async {
      final SearchOutcome out = await queries.searchBooks(filter('山林客'));
      expect(out.page.total, 1);
      expect(out.page.items.single.name, contains('我一个护林员'));
      expect(out.usedFts, isTrue);
    });
  });

  group('第二级：第一级零命中时维持现状全列召回', () {
    setUp(() async {
      await insertEntry(
        name: '《从气运词条开始成就人皇》',
        nameNorm: '从气运词条开始成就人皇',
        hash: 'h1',
        comment: kFloorComment,
      );
      await insertEntry(
        name: '《从红楼开始纵横武侠世界》',
        nameNorm: '从红楼开始纵横武侠世界',
        hash: 'h2',
        comment: kFloorComment,
      );
      await insertEntry(name: '《我在乡下种田》', nameNorm: '我在乡下种田', hash: 'h3', comment: kFloorComment);
      await insertEntry(
        name: '《雪原往事》',
        nameNorm: '雪原往事',
        hash: 'h5',
        recommender: '护林员爱好者',
        comment: '跟山林无关的一本都市文。',
      );
    });

    test('只出现在 comment 的词（≥3 字）零书名命中时仍能返回同楼各本', () async {
      final SearchOutcome out = await queries.searchBooks(filter('扫书楼'));
      expect(out.page.total, 3, reason: 'comment 全列匹配的第二级语义保留');
      expect(
        out.page.items.map((GroupHit g) => g.nameNorm).toSet(),
        <String>{'从气运词条开始成就人皇', '从红楼开始纵横武侠世界', '我在乡下种田'},
      );
      expect(out.usedFts, isTrue);
      expect(out.degraded, isFalse);
      // 第二级维持现状 snippet 口径 = FTS snippet(comment) 带 `[词]` 标记。
      expect(out.page.items.first.snippet, contains('[扫书楼]'));
    });

    test('只出现在 recommender 的词走第二级命中', () async {
      final SearchOutcome out = await queries.searchBooks(filter('护林员爱好者'));
      expect(out.page.total, 1);
      expect(out.page.items.single.nameNorm, '雪原往事');
    });

    test('2 字词只命中 comment → 第二级 LIKE 全列召回', () async {
      final SearchOutcome out = await queries.searchBooks(filter('扫书'));
      expect(out.page.total, 3);
      expect(out.usedFts, isFalse);
    });
  });

  group('buildExcerpt 锚点扩展', () {
    const String text = '这一楼扫了很多本，我个人最推荐《我一个护林员》，主角从护林员一路写到封神。';

    test('prefer 命中 → 以书名为中心截窗并加标记（优先于查询词）', () {
      final String? excerpt = buildExcerpt(
        text,
        <String>['护林员'],
        prefer: <String>['《我一个护林员》', '我一个护林员'],
      );
      expect(excerpt, contains('[《我一个护林员》]'));
      expect(excerpt, isNot(contains('[护林员]')), reason: '书名锚点优先，不再按查询词截窗');
    });

    test('prefer 落空 → 退回查询词截窗', () {
      final String? excerpt = buildExcerpt(text, <String>['护林员'], prefer: <String>['《不存在的书名》']);
      expect(excerpt, contains('[护林员]'));
    });

    test('nullWhenUnanchored：都没命中时返回 null（否则截正文开头）', () {
      expect(buildExcerpt(text, <String>['封神榜'], prefer: <String>['《别书》'], nullWhenUnanchored: true), isNull);
      expect(buildExcerpt(text, <String>['封神榜']), isNotNull, reason: '默认口径不变：截正文开头');
    });

    test('空 prefer / 空词不影响既有默认行为', () {
      expect(buildExcerpt(text, <String>['护林员']), contains('[护林员]'));
      expect(buildExcerpt(null, <String>['护林员']), isNull);
    });
  });

  group('搜索结果卡正文预览（所有卡片都要有正文，用户口径）', () {
    test('书名级命中（snippet 锚不到）→ preview 回退楼层正文，100 字截断', () async {
      // 帖 + 楼层（comment 为空 → 只能回退楼层正文）。
      final int postId = await db.into(db.posts).insert(PostsCompanion.insert(
            tid: const Value<int?>(999),
            title: const Value<String?>('多书帖'),
            channel: 'yy小说吧',
            date: const Value<String?>('2025-04-20'),
          ));
      final int floorId = await db.into(db.floors).insert(FloorsCompanion.insert(
            postId: postId,
            seq: 1,
            content: Value<String>(
              '这是一段很长的楼层正文，用来验证卡片预览的截断口径是否稳定：'
              '${'字' * 120}',
            ),
          ));
      await db.into(db.bookEntries).insert(BookEntriesCompanion.insert(
            name: '《回退预览书》',
            nameNorm: '回退预览书',
            channel: 'yy小说吧',
            contentHash: 'p1',
            date: const Value<String?>('2025-04-20'),
            postRef: Value<int?>(postId),
            floorRef: Value<int?>(floorId),
          ));
      final SearchOutcome out = await queries.searchBooks(filter('回退预览书'));
      final GroupHit hit = out.page.items.single;
      expect(hit.preview, isNotNull, reason: '书名级命中也要有正文预览（回退楼层正文）');
      expect(hit.preview!.endsWith('…'), isTrue, reason: '超 100 字截断加 …');
      expect(hit.preview!.runes.length, 101, reason: '100 字 + 省略号');
    });

    test('条件浏览（无搜索词）→ preview 取条目评语', () async {
      await insertEntry(
        name: '《条件浏览书》',
        nameNorm: '条件浏览书',
        hash: 'cb1',
        comment: '条件浏览下也要展示这段正文预览。',
      );
      final SearchOutcome out = await queries.searchBooks(const SearchFilter());
      final GroupHit hit = out.page.items.single;
      expect(hit.preview, '条件浏览下也要展示这段正文预览。');
    });
  });
}
