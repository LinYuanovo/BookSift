import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/constants.dart';
import 'package:booksift/core/icons.dart';
import 'package:booksift/core/widgets/scroll_chrome.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/features/content/book_detail_page.dart';
import 'package:booksift/features/content/content_detail_page.dart';
import 'package:booksift/features/content/detail_slot.dart';
import 'package:booksift/features/content/rich_text.dart';
import 'package:booksift/features/home/cards.dart';
import 'package:booksift/features/home/home_page.dart';
import 'package:booksift/features/search/search_page.dart';
import 'package:booksift/features/search/search_state.dart';
import 'package:booksift/theme/app_colors.dart';

import 'support/demo_data.dart';
import 'support/fake_book_repository.dart';
import 'support/harness.dart';

// M1-④ 核心业务页面 + queries 数据层测试。
//
// 分两组，边界不可混（详见 app/test/TESTING.md）：
//   · 「queries 数据层」= plain test()，跑在**真实事件循环**，可自由 await 真实 IO
//     （drift NativeDatabase 打开 test/fixtures/dev_seed.db 临时副本），断言 SQL 正确性；
//   · 「页面交互」= testWidgets，跑在 FakeAsync **假时钟区**，一律注入 FakeBookRepository
//     （纯内存、只有微任务），断言交互与视觉语义，绝不碰真库。

// ─────────────────── 真实库挂具（仅 plain test() 用）───────────────────

int _tmpSeq = 0;

/// 打开 fixture 的独立可写副本（drift NativeDatabase；触发 beforeOpen，user_version=2 无迁移）。
///
/// **只能在 plain test() / setUp 里调用**：内含 Directory.createTemp、File.copy 等真实
/// dart:io 异步，放进 testWidgets 会在假时钟区永不返回。
Future<AppDatabase> openFixture() async {
  final File src = File('test/fixtures/dev_seed.db');
  expect(
    src.existsSync(),
    isTrue,
    reason: '先执行 dart run tool/make_dev_seed.dart',
  );
  final Directory tmp = await Directory.systemTemp.createTemp(
    'booksift_ft${_tmpSeq++}',
  );
  final File copy = File('${tmp.path}${Platform.pathSeparator}dev_seed.db');
  await src.copy(copy.path);
  final AppDatabase db = AppDatabase(NativeDatabase(copy));
  await db.customSelect('SELECT 1').get();
  addTearDown(() async {
    await db.close();
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows 句柄延迟释放：临时目录留待系统清理，不影响用例结论。
    }
  });
  return db;
}

void main() {
  // ─────────────────── 数据层：queries.dart（plain test，真实 drift）───────────────────

  group('queries 数据层', () {
    late AppDatabase db;
    late Queries q;

    setUp(() async {
      db = await openFixture();
      q = Queries(db);
    });
    tearDown(() async => db.close());

    test('FTS ≥3字 / LIKE 2字兜底 分支', () async {
      final SearchOutcome fts = await q.searchBooks(
        const SearchFilter(query: '十日终焉'),
      );
      expect(fts.usedFts, isTrue, reason: '≥3字走 book_fts MATCH');
      expect(fts.degraded, isFalse);
      expect(fts.page.items, isNotEmpty);
      expect(fts.page.items.first.nameNorm, '十日终焉');

      final SearchOutcome like = await q.searchBooks(
        const SearchFilter(query: '终焉'),
      );
      expect(like.usedFts, isFalse, reason: '2字词 trigram 恒 0 命中，降级 LIKE');
      expect(like.degraded, isFalse);
      expect(like.page.items.map((GroupHit g) => g.nameNorm), contains('十日终焉'));

      // 空词 = 纯条件浏览分支。
      final SearchOutcome browse = await q.searchBooks(
        const SearchFilter(category: '排雷'),
      );
      expect(browse.page.total, greaterThan(0));
      expect(
        browse.page.items.every(
          (GroupHit g) => g.avoidCount > 0 || g.recommendCount >= 0,
        ),
        isTrue,
      );
    });

    test('五维计数（真实命中，诚实标注）', () async {
      final CategoryCounts c = await q.dimensionCounts();
      expect(c.total, 2000);
      // fixture 实查（SELECT category, COUNT(*) FROM book_entries GROUP BY 1）。
      // 2026-10-14 起源库是发行包同源的清洗库，category 已由 v3 回填镜像成所属帖的
      // post_kind（源库排雷条目 1312→23635），fixture 直迁该值、本地不再改标：
      // 排雷条目从 R1 标题启发式时代的 95 条涨到 795 条。
      expect(
        c.categories.firstWhere((DimCount d) => d.value == '排雷').count,
        795,
      );
      expect(
        c.channels.any(
          (DimCount d) => d.value == ChannelFilter.otherBig && d.count > 0,
        ),
        isTrue,
      );
      expect(c.years.any((DimCount d) => d.value == YearFilter.early), isTrue);
      expect(c.months, hasLength(12));
      expect(
        c.tenDays.map((DimCount d) => d.count).reduce((int a, int b) => a + b),
        greaterThan(0),
      );
    });

    test('搜索页六维联动计数：选年后各维（除该维自身）按条件收缩', () async {
      // 基准（无筛选）= 全局。
      final CategoryCounts base = await q.searchDimensionCounts(
        const SearchFilter(),
      );
      final CategoryPreview only2025 = await q.categoryPreview(
        const CategorySelection(year: '2025'),
      );
      // 选 2025：月份候选计数之和应等于 2025 全量（月份维撇开自身、受年筛选约束）。
      final CategoryCounts withYear = await q.searchDimensionCounts(
        const SearchFilter(year: '2025'),
      );
      final int monthSum = withYear.months
          .map((DimCount d) => d.count)
          .reduce((int a, int b) => a + b);
      expect(
        monthSum,
        only2025.count,
        reason: '选年后月份候选计数 = 该年条目数（联动收缩，非全局 2000）',
      );
      expect(monthSum, lessThan(base.months.map((DimCount d) => d.count).reduce((int a, int b) => a + b)));
      // 年份维撇开自身：仍列出全部年份（不受 year 筛选把自己过滤空）。
      expect(withYear.years, isNotEmpty);
      // 类别维（除类别自身外受年约束）计数之和 = 2025 条目数。
      expect(
        withYear.categories
            .map((DimCount d) => d.count)
            .reduce((int a, int b) => a + b),
        only2025.count,
      );
    });

    test('分类 AND 交集：计数收缩 + 六维组合过滤正确', () async {
      final CategoryPreview only2025 = await q.categoryPreview(
        const CategorySelection(year: '2025'),
      );
      final CategoryPreview both = await q.categoryPreview(
        const CategorySelection(year: '2025', channel: 'yy小说吧', category: '扫书'),
      );
      expect(both.count, lessThanOrEqualTo(only2025.count));
      expect(both.count, greaterThan(0));
      for (final EntryRow e in both.entries) {
        expect(e.date?.startsWith('2025'), isTrue);
        expect(e.channel, 'yy小说吧');
        expect(e.category, '扫书');
      }
      // 旬维度：上旬 = 日 1..10。
      final CategoryPreview upper = await q.categoryPreview(
        const CategorySelection(tenDay: TenDayFilter.upper),
      );
      for (final EntryRow e in upper.entries) {
        expect(int.parse(e.date!.substring(8, 10)), inInclusiveRange(1, 10));
      }
    });

    test('热门榜四时段互异（锚 2025-04-30）', () async {
      final DateTime anchor = DateTime(2025, 4, 30);
      final List<RankRow> allTime = await q.rankRows(
        RankWindow.allTime,
        today: anchor,
      );
      final List<RankRow> thisYear = await q.rankRows(
        RankWindow.thisYear,
        today: anchor,
      );
      final List<RankRow> thisMonth = await q.rankRows(
        RankWindow.thisMonth,
        today: anchor,
      );
      expect(Queries.rankFromDate(RankWindow.allTime, anchor), isNull);
      expect(Queries.rankFromDate(RankWindow.thisMonth, anchor), '2025-04-01');
      expect(Queries.rankFromDate(RankWindow.last30, anchor), '2025-04-01');
      // 三时段榜首（fixture 实查：COUNT(*) 降序 + name_norm 升序兜底）。2026-10-14 起源库
      // 换成清洗库后 allTime 首位位移：世子很凶 21→17 条（去重），让位给未变的魔魂启临 19 条。
      expect(allTime.first.name, '魔魂启临');
      expect(thisYear.first.name, '我加载了恋爱游戏');
      expect(thisMonth.first.name, '世子很凶');
      expect(thisMonth.first.name, isNot(allTime.first.name));
    });

    test('书聚合：计数对比 + 语义筛选只出对应 flag（条目级只认颜色标记）', () async {
      Future<int> gidOf(String nameNorm) async =>
          ((await db
                          .customSelect(
                            "SELECT id FROM book_groups WHERE name_norm = '$nameNorm'",
                          )
                          .getSingle())
                      .data['id']!
                  as num)
              .toInt();

      // fixture 实查（sqlite3 复核）：该书 3 条 = 扫书无标 1 + 排雷无标 1 + 扫书绿标 1
      // → 新口径下 1 推荐 / 1 排雷（旧口径会把扫书无标那条也算推荐 → 2 推荐）。
      final int gid = await gidOf('为何恋爱游戏的女主不太对劲');
      final BookDetailData? d = await q.bookDetail(gid);
      expect(d, isNotNull);
      expect(d!.recommendCount, 1);
      expect(d.avoidCount, 1);

      final List<EntryRow> all = await q.bookEntries(gid, SemanticFilter.all);
      expect(all, hasLength(3));
      // SQL 侧筛选/聚合 ↔ Dart 侧 entryFlagOf 逐条对账（_flagSql 不许与纯函数各漂一半）。
      final List<EntryRow> avoid = await q.bookEntries(
        gid,
        SemanticFilter.avoid,
      );
      expect(avoid, hasLength(d.avoidCount));
      expect(avoid.every((EntryRow e) => e.recommendFlag == -1), isTrue);
      expect(
        avoid.map((EntryRow e) => e.id).toSet(),
        all
            .where((EntryRow e) => e.recommendFlag == -1)
            .map((EntryRow e) => e.id)
            .toSet(),
      );
      final List<EntryRow> rec = await q.bookEntries(
        gid,
        SemanticFilter.recommend,
      );
      expect(rec, hasLength(d.recommendCount));
      expect(rec.every((EntryRow e) => e.recommendFlag == 1), isTrue);
      expect(
        rec.map((EntryRow e) => e.id).toSet(),
        all
            .where((EntryRow e) => e.recommendFlag == 1)
            .map((EntryRow e) => e.id)
            .toSet(),
      );

      // 无颜色标记的扫书存量 = 中性：逍遥小书生 16 条里 6 条排雷、0 条绿标 → 推荐归 0
      //（旧口径按 category=扫书 派生会虚报 10 条推荐）。口径表驱动见 test/data/entry_flag_test.dart。
      final BookDetailData? plain = await q.bookDetail(await gidOf('逍遥小书生'));
      expect(plain!.recommendCount, 0);
      expect(plain.avoidCount, 6);
    });

    test('历史六维快照去重 + 书签/收藏 toggle', () async {
      await q.addHistory(
        const SearchFilter(query: '无限流', year: '2024', category: '扫书'),
      );
      await q.addHistory(
        const SearchFilter(query: '无限流', year: '2024', category: '扫书'),
      );
      final List<SearchHistoryEntry> h = await q.watchHistory().first;
      expect(h, hasLength(1), reason: '同条件去重');
      expect(SearchFilter.fromHistory(h.single).describe(), contains('无限流'));

      expect(
        await q.togglePostBookmark(
          postRef: 14403,
          title: 't',
          snapshot: const SearchFilter(query: 'kw', year: '2024'),
        ),
        isTrue,
      );
      final Bookmark bm = (await q.watchBookmarks().first).single;
      expect(bm.snapQuery, 'kw');
      expect(bm.snapYear, '2024');
      expect(
        await q.togglePostBookmark(postRef: 14403, title: 't'),
        isFalse,
        reason: '再点取消',
      );
      expect(await q.watchBookmarks().first, isEmpty);

      expect(
        await q.toggleFavorite(
          targetType: FavoriteTarget.bookGroup,
          targetId: 842,
          title: '世子很凶',
        ),
        isTrue,
      );
      expect((await q.watchFavorites().first).single.targetType, 'book_group');
      await q.toggleFavorite(
        targetType: FavoriteTarget.bookGroup,
        targetId: 842,
        title: '世子很凶',
      );
      expect(await q.watchFavorites().first, isEmpty);
      expect(await q.watchHistory().first, hasLength(1));
    });

    test('种子行 origin=seed 与 builtin 同档（内置灰），collected/imported 各成一档', () {
      // 种子导入落库的 origin 值是 'seed'（lib/data/seed_import.dart: SeedImporter.seedOrigin），
      // 徽标须归「内置」灰档；只有自采/导入两档另着色。
      expect(OriginBadge.labelOf('seed'), '内置');
      expect(OriginBadge.labelOf(Origin.builtin), '内置');
      expect(OriginBadge.labelOf(Origin.collected), '自采');
      expect(OriginBadge.labelOf(Origin.imported), '导入');
      expect(Origin.seed, 'seed');
    });
  });

  // ─────────────────── 富文本渲染管线（§5.6，plain test：纯函数）───────────────────

  group('楼层富文本解析', () {
    test('《书名》/URL 交错单遍扫描，保持原文顺序', () {
      final List<FloorSegment> segs = parseFloorSegments(
        '推荐《十日终焉》，备份 https://tieba.baidu.com/p/123 欢迎补充',
      );
      expect(segs.map((FloorSegment s) => s.runtimeType).toList(), <Type>[
        PlainSegment,
        BookSegment,
        PlainSegment,
        UrlSegment,
        PlainSegment,
      ]);
      expect((segs[1] as BookSegment).name, '十日终焉');
      expect((segs[3] as UrlSegment).url, 'https://tieba.baidu.com/p/123');
    });

    test('URL 尾部中文标点/句读裁掉并归还为纯文本', () {
      final List<FloorSegment> segs = parseFloorSegments(
        '看这里 https://a.b/c。下一句',
      );
      expect((segs[1] as UrlSegment).url, 'https://a.b/c');
      expect((segs[2] as PlainSegment).text, '。下一句');
    });

    test('书名内含 http 时先到先得，不被 URL 正则二次吞并', () {
      final List<FloorSegment> segs = parseFloorSegments('《http入门》不错');
      expect(segs.whereType<BookSegment>().single.name, 'http入门');
      expect(segs.whereType<UrlSegment>(), isEmpty);
    });

    test('纯文本无片段；超长书名（>40 字）不当作书名', () {
      expect(parseFloorSegments('就是一段普通的话'), <Matcher>[isA<PlainSegment>()]);
      final String long = '《${'书' * 41}》';
      expect(parseFloorSegments(long).whereType<BookSegment>(), isEmpty);
    });

    test('百度图床防盗链 Referer 头就位（§9.4 三保险之二）', () {
      expect(FloorImages.refererHeaders['Referer'], 'https://imgsrc.baidu.com');
    });
  });

  // ─────────────────── Widget：交互与视觉语义（testWidgets，全内存 fake）───────────────────

  group('页面交互', () {
    late FakeBookRepository repo;

    setUp(() {
      repo = FakeBookRepository(library: demoLibrary());
    });

    testWidgets('书名点击 → 跳搜索台并预填自动提交（§5.6 核心交互闭环）', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, initial: '/post/7'));
      await tester.pumpAndSettle();

      // 首楼《篡水浒》渲染为独立可点 span，着色 = bookname token。
      // 限定正文：头部书目 chip（PostBookChip）也渲染同名 Text，点击语义不同（进书聚合）。
      final Finder bookSpan = find.descendant(
        of: find.byType(FloorRichText),
        matching: find.text('《篡水浒》'),
      );
      expect(bookSpan, findsOneWidget);
      expect(
        tester.widget<Text>(bookSpan.first).style?.color,
        AppColors.light.bookname,
      );

      await tester.tap(bookSpan.first);
      await tester.pumpAndSettle();

      final SearchDraft draft = containerOf(
        tester,
        find.byType(SearchPage),
      ).read(searchDraftProvider);
      expect(draft.filter.query, '篡水浒');
      expect(draft.submitted, isTrue, reason: '携 q= 进入即自动出结果');
    });

    testWidgets('楼层 URL → info 色下划线 span；点击复制并提示（§5.6 渲染管线 2）', (
      WidgetTester tester,
    ) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, initial: '/post/7'));
      await tester.pumpAndSettle();

      final Finder url = find.textContaining(
        'https://tieba.baidu.com/p/11097754039',
      );
      expect(url, findsOneWidget);
      final Text urlText = tester.widget<Text>(url);
      final TextSpan span = urlText.textSpan! as TextSpan;
      final List<TextSpan> kids = span.children!.cast<TextSpan>();
      final TextSpan urlSpan = kids.firstWhere(
        (TextSpan s) => (s.text ?? '').startsWith('https://'),
      );
      expect(urlSpan.style?.color, AppColors.light.info);
      expect(urlSpan.style?.decoration, TextDecoration.underline);
      expect(urlSpan.recognizer, isNotNull, reason: 'URL 必须可点');
    });

    testWidgets('排雷徽标语义色 = danger token + 风险提示横幅（P0-13）', (
      WidgetTester tester,
    ) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, initial: '/post/14403'));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (Widget w) => w is SemanticBadge && w.tone == SemanticTone.avoid,
        ),
        findsWidgets,
      );
      // 徽标文字着色 = AppColors.danger（非硬编码，随主题 token）。
      expect(
        tester.widget<Text>(find.text('排雷').first).style?.color,
        AppColors.light.danger,
      );
      // 排雷帖风险提示横幅在场（§5.6：进排雷帖先提示）。
      expect(find.textContaining('排雷帖'), findsOneWidget);
      // 头部书目 chips：帖内提及书的按帖排雷次数（语料 2012 排雷 → chip 带「N 排雷」）。
      expect(find.byType(PostBookChip), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(PostBookChip),
          matching: find.textContaining('排雷'),
        ),
        findsWidgets,
      );
    });

    // 热门榜时段重排的 widget 用例已随 M2-② 内嵌榜移除迁至 test/rank/rank_page_test.dart
    //（首页仅保留 entry-tile 入口 → push /rank）；数据层四时段断言见上方「queries 数据层」组。

    testWidgets('首页日期分组流：同日合组、异日各起组头（§5.2）', (WidgetTester tester) async {
      useSurface(
        tester,
        height: 2600,
      ); // 6 帖全展开须够高：ListView/Sliver 懒构建，屏外卡片不在树里
      await tester.pumpWidget(testApp(repo, initial: '/home'));
      await tester.pumpAndSettle();

      // 语料 6 帖进时间线（求书帖 20003 不进），落在 5 个不同日期上，其中 04-28 有 2 帖。
      for (final String d in <String>[
        '2025-04-28',
        '2025-04-20',
        '2025-04-15',
        '2025-04-02',
        '2024-12-05',
      ]) {
        expect(
          find.byKey(ValueKey<String>('timeline-group-$d')),
          findsOneWidget,
          reason: '$d 应恰有一个组头',
        );
      }
      expect(
        find.byKey(const ValueKey<String>('timeline-group-2024-06-11')),
        findsNothing,
        reason: 'post_kind=求书 的帖不进时间线',
      );
      expect(find.text('求书：有没有类似世子很凶的'), findsNothing);
      // 同日两帖都渲染在同一组下。
      expect(find.text('【扫书】yy小说吧四月下旬合集'), findsOneWidget);
      expect(find.text('【扫书】哀伤雪刃四月补档'), findsOneWidget);
      // origin 三档徽标齐活。
      expect(find.text('自采'), findsWidgets);
      expect(find.text('导入'), findsWidgets);
      expect(find.text('内置'), findsWidgets);
    });

    testWidgets('首页日期目录：弹层可打开、点击日期两段式滚动定位到目标组（§5.2）', (
      WidgetTester tester,
    ) async {
      useSurface(tester); // 默认 390×844：6 帖 + 5 组头溢出可视区，目标组初始未构建
      await tester.pumpWidget(testApp(repo, initial: '/home'));
      await tester.pumpAndSettle();

      // 入口：≥2 个日期组 → appbar 目录按钮，位于设置图标左侧。
      final Finder tocButton = find.byTooltip('目录');
      expect(tocButton, findsOneWidget);
      expect(
        tester.getTopLeft(tocButton).dx,
        lessThan(tester.getTopLeft(find.byTooltip('设置')).dx),
        reason: '目录按钮在设置图标之前',
      );

      await tester.tap(tocButton);
      await tester.pumpAndSettle();
      // 弹层每行 = 日期 + 当日帖数，倒序与页面一致；04-28 同日两帖合组为 2 帖。
      final Finder sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text('2025-04-28')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('2 帖')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('2024-12-05')),
        findsOneWidget,
      );

      // 最末组（2024-12-05）初始未构建 → 比例估算 animateTo + ensureVisible 二次定位。
      expect(
        find.byKey(const ValueKey<String>('timeline-group-2024-12-05')),
        findsNothing,
      );
      await tester.tap(
        find.descendant(of: sheet, matching: find.text('2024-12-05')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing, reason: '点击后弹层关闭');
      expect(
        find.byKey(const ValueKey<String>('timeline-group-2024-12-05')),
        findsOneWidget,
      );
      expect(
        find.text('【扫书】大佬专栏年度盘点').hitTestable(),
        findsOneWidget,
        reason: '目标组已滚入可视区',
      );
      expect(
        find.text('【扫书】yy小说吧四月下旬合集').hitTestable(),
        findsNothing,
        reason: '顶部首组已滚出可视区',
      );
    });

    testWidgets('ScrollChrome 接入首页主滚动区（常驻滚动条 + 跳顶跳底）', (
      WidgetTester tester,
    ) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, initial: '/home'));
      await tester.pumpAndSettle();
      expect(
        find.byType(ScrollChrome),
        findsOneWidget,
        reason: '首页时间线外裹 ScrollChrome',
      );
    });

    testWidgets('详情操作条：书签写入含六维搜索条件快照，收藏双粒度（§5.6）', (WidgetTester tester) async {
      useSurface(tester);
      const SearchFilter snapshot = SearchFilter(
        query: '世子',
        year: '2024',
        channel: 'yy小说吧',
      );
      await tester.pumpWidget(
        testApp(
          repo,
          home: const ContentDetailPage(
            selection: PostSelection(
              postId: 18293,
              position: 2,
              snapshot: snapshot,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.bookmarks, isEmpty);
      await tester.tap(find.text('书签'));
      await tester.pumpAndSettle();
      expect(find.text('已加入书签（含楼层位置）'), findsOneWidget);
      expect(repo.bookmarks, hasLength(1));
      final Bookmark bm = repo.bookmarks.single;
      expect(bm.postRef, 18293);
      expect(bm.title, '【扫书】雪群推书四月精选');
      expect(bm.position, 2, reason: '结果列表位置随快照落库');
      expect(bm.floorSeq, 1, reason: '任务 1：首个可见楼层 seq 随书签落库（单楼帖 = 1 楼）');
      expect(bm.snapQuery, '世子');
      expect(bm.snapYear, '2024');
      expect(bm.snapChannel, 'yy小说吧');
      expect(bm.snapSort, SearchSort.timeDesc.wire);
      await dismissSnackBars(tester);

      // 再点 = 取消（toggle 语义），操作条图标随之回落到未激活态。
      await tester.tap(find.text('书签'));
      await tester.pumpAndSettle();
      expect(repo.bookmarks, isEmpty);
      expect(find.text('已移除书签'), findsOneWidget);
      await dismissSnackBars(tester);

      await tester.tap(find.text('收藏'));
      await tester.pumpAndSettle();
      expect(repo.favorites, hasLength(1));
      expect(repo.favorites.single.targetType, FavoriteTarget.post);
      expect(repo.favorites.single.targetId, 18293);
      await dismissSnackBars(tester);
    });

    testWidgets('书聚合页：计数对比点击即筛选 + 语义 chips（§5.5）', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(
        testApp(repo, home: const BookDetailPage(bookGroupId: 904)),
      );
      await tester.pumpAndSettle();

      // 书名只在页头大标题出现一次（display 30）：评价卡走 hideBookName，整页同书不重复书名。
      expect(find.text('《逍遥小书生》'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (Widget w) =>
              w is Text && w.data == '《逍遥小书生》' && w.style?.fontSize == 30,
        ),
        findsOneWidget,
        reason: '书名大标题走 display 字阶 token（§3 #04）',
      );
      expect(find.textContaining('2 条独立评价'), findsOneWidget);
      // 计数对比：1 推荐（2013 绿标）/ 1 排雷（2014 红标）。
      final CountDuo duo = tester.widget<CountDuo>(find.byType(CountDuo));
      expect(duo.recommend, 1);
      expect(duo.avoid, 1);

      // 点计数对比里的「排雷」= 直接置「仅排雷」筛选（§5.5，P0-13）。
      // 注意 '排雷' 文案在页面上有多处（计数对比 label + 排雷条目的 SemanticBadge），须限定到 CountDuo 内。
      await tester.tap(
        find.descendant(of: find.byType(CountDuo), matching: find.text('排雷')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('全部评价 1'), findsOneWidget);
      expect(
        find.byType(BookEntryCard),
        findsOneWidget,
        reason: '仅存的 1 张排雷评价卡（书名不再在卡内重复）',
      );

      // 语义 chips 回「全部」。
      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedPill<SemanticFilter>),
          matching: find.text('全部'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('全部评价 2'), findsOneWidget);
    });

    testWidgets(
      '书聚合页对齐设计 04：eyebrow/无标题 appbar/页脚 hint + 图标守卫（零 Material Icon）',
      (WidgetTester tester) async {
        useSurface(tester);
        await tester.pumpWidget(
          testApp(repo, home: const BookDetailPage(bookGroupId: 904)),
        );
        await tester.pumpAndSettle();

        // eyebrow（index.html:1444）承接原 appbar 标题语义；appbar 本身无标题。
        expect(find.text('BOOK · 书聚合'), findsOneWidget);
        final Finder appbar = find.byType(AppBar);
        expect(
          find.descendant(of: appbar, matching: find.text('书聚合')),
          findsNothing,
        );

        // AppBar = list(目录) + star + more 三枚设计 SVG（home 挂具不可 pop → 无返回键），零 Material Icon。
        expect(
          find.descendant(of: appbar, matching: find.byType(SvgPicture)),
          findsNWidgets(3),
        );
        expect(
          find.descendant(of: appbar, matching: find.byType(Icon)),
          findsNothing,
        );

        // 排序控件：chev SVG（.ic.xs 13px → chev-s.svg），零 Material Icon。
        final Finder sortMenu = find.byType(PopupMenuButton<EntrySort>);
        expect(
          find.descendant(of: sortMenu, matching: find.byType(SvgPicture)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: sortMenu, matching: find.byType(Icon)),
          findsNothing,
        );
        // 13px ≤ xs 档 → 自动选 stroke2 的 chev-s.svg（AppIcon.assetName 契约）。
        expect(
          tester
              .widget<AppIcon>(
                find.descendant(of: sortMenu, matching: find.byType(AppIcon)),
              )
              .assetName,
          'assets/icons/chev-s.svg',
        );

        // 页脚 hint（index.html:1492，诚实口径：只列已实装交互）。
        expect(find.textContaining('点推荐人 → 以其为关键词搜索'), findsOneWidget);

        // 本页已移除的 Material 图标全局绝迹（共享组件 cards.dart 内部的 SemanticBadge/原帖↗ 等
        // Material 图标归 M2-① 统一迁移，不在本页守卫范围）。
        for (final IconData gone in <IconData>[
          Icons.star_rounded,
          Icons.star_border_rounded,
          Icons.more_vert_rounded,
          Icons.expand_more_rounded,
          Icons.error_outline_rounded,
        ]) {
          expect(find.byIcon(gone), findsNothing);
        }
      },
    );

    testWidgets('书聚合页空态：SVG 线稿（db/book/alert），全树零 Material Icon', (
      WidgetTester tester,
    ) async {
      useSurface(tester);
      // 不存在的聚合组 → 「书目不存在」空态；页面无评价卡 → 全树可断言零 Material Icon。
      await tester.pumpWidget(
        testApp(repo, home: const BookDetailPage(bookGroupId: 99999)),
      );
      await tester.pumpAndSettle();
      expect(find.text('书目不存在'), findsOneWidget);
      expect(find.byType(SvgPicture), findsWidgets);
      expect(find.byType(Icon), findsNothing);
      expect(find.byIcon(Icons.auto_stories_outlined), findsNothing);
    });

    testWidgets('搜索历史：提交写入 + 点历史行复现六维条件（§5.3）', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, initial: '/search'));
      await tester.pumpAndSettle();

      // 输入 4 字关键词并提交（显式推进 200ms 联想 debounce 的假时钟 timer）。
      await tester.enterText(find.byType(TextField).first, '十日终焉');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      final ProviderContainer container = containerOf(
        tester,
        find.byType(SearchPage),
      );
      expect(container.read(searchDraftProvider).submitted, isTrue);
      expect(repo.history, hasLength(1));
      expect(repo.history.first.query, '十日终焉');
      // ≥3 字 → FTS 路径，结果区挂 FTS 标记。
      expect(find.text('FTS'), findsOneWidget);
      expect(find.text('1 结果'), findsOneWidget);

      // 回搜索台 → 历史行在场；点击复现条件并直接出结果。
      await tester.tap(find.byTooltip('清空并回搜索台'));
      await tester.pumpAndSettle();
      expect(find.text('十日终焉'), findsWidgets, reason: '历史行摘要 + 输入框回显');
      // 历史行图标已 SVG 化（clock）→ 按行文本定位（摘要 Text 恰为关键词，热门 chips 带《》不冲突）。
      await tester.tap(
        find.widgetWithText(InkWell, '十日终焉').hitTestable().first,
      );
      await tester.pumpAndSettle();
      final SearchDraft replay = container.read(searchDraftProvider);
      expect(replay.submitted, isTrue);
      expect(replay.filter.query, '十日终焉');
      expect(repo.history, hasLength(1), reason: '同条件去重，不重复记账');
    });

    testWidgets('2 字词走 LIKE 兜底：结果区不挂 FTS 标记（§7.3）', (
      WidgetTester tester,
    ) async {
      useSurface(tester);
      await tester.pumpWidget(
        testApp(repo, initial: '/search?q=%E7%BB%88%E7%84%89'),
      );
      await tester.pumpAndSettle();

      final ProviderContainer container = containerOf(
        tester,
        find.byType(SearchPage),
      );
      expect(container.read(searchDraftProvider).filter.query, '终焉');
      expect(find.text('FTS'), findsNothing, reason: '2 字词 trigram 不可用 → LIKE');
      expect(find.text('1 结果'), findsOneWidget);
    });

    testWidgets('我的页：书签/收藏/历史三段实时列表 + 点书签打开帖子详情恢复楼层（§5.10，任务 1）', (
      WidgetTester tester,
    ) async {
      useSurface(tester, height: 1400);
      // 预置用户数据（fake 的写路径只有微任务，可在 testWidgets 体内 await）。
      await repo.togglePostBookmark(
        postRef: 7,
        title: '【扫书】yy小说吧四月下旬合集',
        author: '扫书人甲',
        channel: 'yy小说吧',
        position: 6,
        floorSeq: 2,
        snapshot: const SearchFilter(
          query: '无限流',
          year: '2024',
          tenDay: TenDayFilter.upper,
          category: '扫书',
        ),
      );
      await repo.toggleFavorite(
        targetType: FavoriteTarget.bookGroup,
        targetId: 901,
        title: '《十日终焉》',
      );
      await repo.addHistory(const SearchFilter(query: '世子很凶', month: '4'));

      await tester.pumpWidget(testApp(repo, initial: '/profile'));
      await tester.pumpAndSettle();

      expect(find.text('书签夹 1'), findsOneWidget);
      expect(find.text('收藏夹 1'), findsOneWidget);
      expect(find.text('搜索历史 1'), findsOneWidget);
      // 书签行展示快照摘要与列表位置（§5.10 线框）；任务 1：floorSeq 非空 → 副标题带楼层。
      expect(find.textContaining('快照:'), findsOneWidget);
      expect(find.textContaining('第 7 条'), findsOneWidget);
      expect(find.textContaining('2楼'), findsOneWidget);
      expect(find.text('《十日终焉》'), findsWidgets);

      // 点书签 = 打开帖子详情并携楼层位置定位（六维快照随行，供详情页再收藏沿用）。
      await tester.tap(find.textContaining('「【扫书】yy小说吧四月下旬合集」'));
      await tester.pumpAndSettle();
      final ContentDetailPage detail = tester.widget(
        find.byType(ContentDetailPage),
      );
      expect(detail.selection.postId, 7);
      expect(detail.selection.initialFloorSeq, 2);
      expect(detail.selection.snapshot?.query, '无限流');
      expect(detail.selection.snapshot?.year, '2024');
      expect(detail.selection.snapshot?.tenDay, TenDayFilter.upper);
      expect(detail.selection.snapshot?.category, '扫书');
    });

    testWidgets('详情页：目录弹层跳楼层 + 上下帖 PageView（§5.6）', (
      WidgetTester tester,
    ) async {
      useSurface(tester);
      await tester.pumpWidget(
        testApp(
          repo,
          home: const ContentDetailPage(
            selection: PostSelection(
              postId: 7,
              siblings: <int>[7, 14403],
              position: 3,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 多帖 = 标题带 1/2 计数。
      expect(find.text('帖子详情 1/2'), findsOneWidget);

      // 目录弹层：两楼各一行，点第二楼即定位。
      await tester.tap(find.text('目录'));
      await tester.pumpAndSettle();
      expect(find.text('1楼'), findsNWidgets(2), reason: '弹层行 + 正文楼层头');
      expect(find.textContaining('原帖备份'), findsWidgets);
      await tester.tap(find.text('2楼').last);
      await tester.pumpAndSettle();
      expect(find.text('目录'), findsOneWidget, reason: '弹层已关闭，回到正文');

      // 下一帖：左滑翻到 14403（排雷帖）。
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('帖子详情 2/2'), findsOneWidget);
      expect(find.textContaining('排雷帖'), findsOneWidget);
    });

    testWidgets('首页随机书荒面板 + 换一批重抽（P1-3）', (WidgetTester tester) async {
      useSurface(tester, height: 1400);
      await tester.pumpWidget(testApp(repo, initial: '/home'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('随机书荒'));
      await tester.pumpAndSettle();

      expect(find.text('换一批'), findsOneWidget);
      // 只抽有推荐语（≥20 字）的扫书条目：语料里 4 条命中（2001/2006/2009/2013）。
      final Iterable<BookEntryCard> cards = tester.widgetList<BookEntryCard>(
        find.byType(BookEntryCard),
      );
      expect(cards.length, 4);
      for (final BookEntryCard card in cards) {
        expect(card.entry.category, CategoryKind.scan);
        expect(card.entry.comment!.length, greaterThanOrEqualTo(20));
      }

      // 换一批 = invalidate 重抽，面板不塌。
      await tester.tap(find.text('换一批'));
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<BookEntryCard>(find.byType(BookEntryCard)),
        hasLength(4),
      );
      expect(repo.calls['randomBooks'], greaterThanOrEqualTo(2));
    });

    testWidgets('expanded 双栏：帖子详情走 _DetailSlot 右槽原位切换（§9.7）', (
      WidgetTester tester,
    ) async {
      useSurface(tester, width: 1440, height: 900);
      await tester.pumpWidget(testApp(repo, initial: '/home'));
      await tester.pumpAndSettle();

      // 未选中 = 空态。
      expect(find.text('选择左侧内容查看详情'), findsOneWidget);

      // 点时间线卡片 → expanded 且不可 pop → 右槽原位接管，不 push 新路由。
      await tester.tap(find.text('【扫书】yy小说吧四月下旬合集').first);
      await tester.pumpAndSettle();
      final ProviderContainer container = containerOf(
        tester,
        find.byType(HomePage),
      );
      expect(container.read(detailSelectionProvider)?.postId, 7);
      expect(find.textContaining('排雷帖'), findsNothing, reason: '扫书帖不挂排雷风险提示');
      expect(find.byType(ContentDetailPage), findsOneWidget);
      expect(find.text('选择左侧内容查看详情'), findsNothing);
    });
  });
}
