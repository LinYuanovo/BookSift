import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saoshuhui/core/constants.dart';
import 'package:saoshuhui/data/db/app_database.dart';
import 'package:saoshuhui/data/repo/queries.dart';
import 'package:saoshuhui/features/category/category_page.dart';
import 'package:saoshuhui/features/content/book_detail_page.dart';
import 'package:saoshuhui/features/content/content_detail_page.dart';
import 'package:saoshuhui/features/content/detail_slot.dart';
import 'package:saoshuhui/features/content/rich_text.dart';
import 'package:saoshuhui/features/home/cards.dart';
import 'package:saoshuhui/features/home/home_page.dart';
import 'package:saoshuhui/features/search/search_page.dart';
import 'package:saoshuhui/features/search/search_state.dart';
import 'package:saoshuhui/theme/app_colors.dart';

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
  expect(src.existsSync(), isTrue, reason: '先执行 dart run tool/make_dev_seed.dart');
  final Directory tmp = await Directory.systemTemp.createTemp('saoshuhui_ft${_tmpSeq++}');
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
      final SearchOutcome fts = await q.searchBooks(const SearchFilter(query: '十日终焉'));
      expect(fts.usedFts, isTrue, reason: '≥3字走 book_fts MATCH');
      expect(fts.degraded, isFalse);
      expect(fts.page.items, isNotEmpty);
      expect(fts.page.items.first.nameNorm, '十日终焉');

      final SearchOutcome like = await q.searchBooks(const SearchFilter(query: '终焉'));
      expect(like.usedFts, isFalse, reason: '2字词 trigram 恒 0 命中，降级 LIKE');
      expect(like.degraded, isFalse);
      expect(like.page.items.map((GroupHit g) => g.nameNorm), contains('十日终焉'));

      // 空词 = 纯条件浏览分支。
      final SearchOutcome browse = await q.searchBooks(const SearchFilter(category: '排雷'));
      expect(browse.page.total, greaterThan(0));
      expect(browse.page.items.every((GroupHit g) => g.avoidCount > 0 || g.recommendCount >= 0), isTrue);
    });

    test('五维计数（真实命中，诚实标注）', () async {
      final CategoryCounts c = await q.dimensionCounts();
      expect(c.total, 2000);
      expect(c.categories.firstWhere((DimCount d) => d.value == '排雷').count, 95);
      expect(c.channels.any((DimCount d) => d.value == ChannelFilter.otherBig && d.count > 0), isTrue);
      expect(c.years.any((DimCount d) => d.value == YearFilter.early), isTrue);
      expect(c.months, hasLength(12));
      expect(c.tenDays.map((DimCount d) => d.count).reduce((int a, int b) => a + b), greaterThan(0));
    });

    test('分类 AND 交集：计数收缩 + 六维组合过滤正确', () async {
      final CategoryPreview only2025 = await q.categoryPreview(const CategorySelection(year: '2025'));
      final CategoryPreview both = await q.categoryPreview(
          const CategorySelection(year: '2025', channel: 'yy小说吧', category: '扫书'));
      expect(both.count, lessThanOrEqualTo(only2025.count));
      expect(both.count, greaterThan(0));
      for (final EntryRow e in both.entries) {
        expect(e.date?.startsWith('2025'), isTrue);
        expect(e.channel, 'yy小说吧');
        expect(e.category, '扫书');
      }
      // 旬维度：上旬 = 日 1..10。
      final CategoryPreview upper = await q.categoryPreview(const CategorySelection(tenDay: TenDayFilter.upper));
      for (final EntryRow e in upper.entries) {
        expect(int.parse(e.date!.substring(8, 10)), inInclusiveRange(1, 10));
      }
    });

    test('热门榜四时段互异（锚 2025-04-30）', () async {
      final DateTime anchor = DateTime(2025, 4, 30);
      final List<RankRow> allTime = await q.rankRows(RankWindow.allTime, today: anchor);
      final List<RankRow> thisYear = await q.rankRows(RankWindow.thisYear, today: anchor);
      final List<RankRow> thisMonth = await q.rankRows(RankWindow.thisMonth, today: anchor);
      expect(Queries.rankFromDate(RankWindow.allTime, anchor), isNull);
      expect(Queries.rankFromDate(RankWindow.thisMonth, anchor), '2025-04-01');
      expect(Queries.rankFromDate(RankWindow.last30, anchor), '2025-04-01');
      expect(allTime.first.name, '世子很凶');
      expect(thisYear.first.name, '我加载了恋爱游戏');
      expect(thisMonth.first.name, '我不想和你一起重生');
      expect(thisMonth.first.name, isNot(allTime.first.name));
    });

    test('书聚合：计数对比 + 语义筛选只出对应 flag', () async {
      final int gid = (await db
              .customSelect("SELECT id FROM book_groups WHERE name_norm='逍遥小书生'")
              .getSingle())
          .data['id']! as int;
      final BookDetailData? d = await q.bookDetail(gid);
      expect(d, isNotNull);
      expect(d!.recommendCount, greaterThan(0));
      expect(d.avoidCount, greaterThan(0));
      final List<EntryRow> avoid = await q.bookEntries(gid, SemanticFilter.avoid);
      expect(avoid, hasLength(d.avoidCount));
      expect(avoid.every((EntryRow e) => e.recommendFlag == -1), isTrue);
      final List<EntryRow> rec = await q.bookEntries(gid, SemanticFilter.recommend);
      expect(rec.every((EntryRow e) => e.recommendFlag == 1), isTrue);
    });

    test('历史六维快照去重 + 书签/收藏 toggle', () async {
      await q.addHistory(const SearchFilter(query: '无限流', year: '2024', category: '扫书'));
      await q.addHistory(const SearchFilter(query: '无限流', year: '2024', category: '扫书'));
      final List<SearchHistoryEntry> h = await q.watchHistory().first;
      expect(h, hasLength(1), reason: '同条件去重');
      expect(SearchFilter.fromHistory(h.single).describe(), contains('无限流'));

      expect(
          await q.togglePostBookmark(
              postRef: 14403, title: 't', snapshot: const SearchFilter(query: 'kw', year: '2024')),
          isTrue);
      final Bookmark bm = (await q.watchBookmarks().first).single;
      expect(bm.snapQuery, 'kw');
      expect(bm.snapYear, '2024');
      expect(await q.togglePostBookmark(postRef: 14403, title: 't'), isFalse, reason: '再点取消');
      expect(await q.watchBookmarks().first, isEmpty);

      expect(await q.toggleFavorite(targetType: FavoriteTarget.bookGroup, targetId: 842, title: '世子很凶'), isTrue);
      expect((await q.watchFavorites().first).single.targetType, 'book_group');
      await q.toggleFavorite(targetType: FavoriteTarget.bookGroup, targetId: 842, title: '世子很凶');
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
      final List<FloorSegment> segs = parseFloorSegments('推荐《十日终焉》，备份 https://tieba.baidu.com/p/123 欢迎补充');
      expect(segs.map((FloorSegment s) => s.runtimeType).toList(),
          <Type>[PlainSegment, BookSegment, PlainSegment, UrlSegment, PlainSegment]);
      expect((segs[1] as BookSegment).name, '十日终焉');
      expect((segs[3] as UrlSegment).url, 'https://tieba.baidu.com/p/123');
    });

    test('URL 尾部中文标点/句读裁掉并归还为纯文本', () {
      final List<FloorSegment> segs = parseFloorSegments('看这里 https://a.b/c。下一句');
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
      final Finder bookSpan = find.text('《篡水浒》');
      expect(bookSpan, findsWidgets);
      expect(tester.widget<Text>(bookSpan.first).style?.color, AppColors.light.bookname);

      await tester.tap(bookSpan.first);
      await tester.pumpAndSettle();

      final SearchDraft draft = containerOf(tester, find.byType(SearchPage)).read(searchDraftProvider);
      expect(draft.filter.query, '篡水浒');
      expect(draft.submitted, isTrue, reason: '携 q= 进入即自动出结果');
    });

    testWidgets('楼层 URL → info 色下划线 span；点击复制并提示（§5.6 渲染管线 2）', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, initial: '/post/7'));
      await tester.pumpAndSettle();

      final Finder url = find.textContaining('https://tieba.baidu.com/p/11097754039');
      expect(url, findsOneWidget);
      final Text urlText = tester.widget<Text>(url);
      final TextSpan span = urlText.textSpan! as TextSpan;
      final List<TextSpan> kids = span.children!.cast<TextSpan>();
      final TextSpan urlSpan = kids.firstWhere((TextSpan s) => (s.text ?? '').startsWith('https://'));
      expect(urlSpan.style?.color, AppColors.light.info);
      expect(urlSpan.style?.decoration, TextDecoration.underline);
      expect(urlSpan.recognizer, isNotNull, reason: 'URL 必须可点');
    });

    testWidgets('排雷徽标语义色 = danger token + 风险提示横幅（P0-13）', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, initial: '/post/14403'));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((Widget w) => w is SemanticBadge && w.tone == SemanticTone.avoid),
        findsWidgets,
      );
      // 徽标文字着色 = AppColors.danger（非硬编码，随主题 token）。
      expect(tester.widget<Text>(find.text('排雷').first).style?.color, AppColors.light.danger);
      // 排雷帖风险提示横幅在场（§5.6：进排雷帖先提示）。
      expect(find.textContaining('排雷帖'), findsOneWidget);
      // 头部计数对比：1 推荐 / 1 排雷（语料 2012 排雷 + 帖内无推荐条目时为 0）。
      expect(find.byType(CountDuo), findsOneWidget);
    });

    testWidgets('分类五维手风琴独占展开（MI-8）+ 计数 chips 真实命中', (WidgetTester tester) async {
      // 高视口：五维组 + 结果区全部入屏（ListView 懒构建，结果区在 844dp 下不在树里）。
      useSurface(tester, height: 2200);
      await tester.pumpWidget(testApp(repo, initial: '/category'));
      await tester.pumpAndSettle();

      final ProviderContainer container = containerOf(tester, find.byType(CategoryPage));
      // 默认第一组「年份」展开：年值 chip 在场、月值 chip 不在场（独占）。
      expect(container.read(accordionOpenProvider), CategoryDim.year);
      expect(find.text('2025'), findsWidgets);
      expect(find.text('1月'), findsNothing);
      // 副标题带全库真实总数（§5.12 诚实标注）。
      expect(find.textContaining('全库 14 条'), findsOneWidget);

      // 点「月份」组头 → 独占展开：年收起、月展开。
      await tester.tap(find.text('月份'));
      await tester.pumpAndSettle();
      expect(container.read(accordionOpenProvider), CategoryDim.month);
      expect(find.text('1月'), findsWidgets);
      expect(find.text('2025'), findsNothing);

      // 再点已展开的「月份」→ 收起（null）。
      await tester.tap(find.text('月份'));
      await tester.pumpAndSettle();
      expect(container.read(accordionOpenProvider), isNull);

      // 选值 → 即时 AND 过滤：命中数收缩且预览卡刷新。
      await tester.tap(find.text('月份'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4月'));
      await tester.pumpAndSettle();
      expect(container.read(categorySelectionProvider).month, '4');
      expect(find.textContaining('命中 6 条'), findsOneWidget);
    });

    testWidgets('热门榜时段切换 → 榜单按范围内推荐次数重排（§5.13）', (WidgetTester tester) async {
      useSurface(tester, height: 1400);
      await tester.pumpWidget(testApp(repo, initial: '/home', rankToday: DateTime(2025, 4, 30)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('热门榜'));
      await tester.pumpAndSettle();
      final Finder board = find.byKey(const Key('rank-board'));
      expect(board, findsOneWidget);

      // 全时段：世子很凶(5) 榜首；我不想和你一起重生(3) 在榜。
      expect(find.descendant(of: board, matching: find.text('《世子很凶》')), findsOneWidget);
      expect(find.descendant(of: board, matching: find.text('推荐次数榜 · Top10')), findsOneWidget);

      // 切「本月」→ 重排：世子很凶 4 月无条目 → 离榜；我不想和你一起重生 上位。
      await tester.tap(find.text('本月'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: board, matching: find.text('《我不想和你一起重生》')), findsOneWidget);
      expect(find.descendant(of: board, matching: find.text('《世子很凶》')), findsNothing);
      expect(repo.calls['rankRows:${RankWindow.thisMonth}'], greaterThanOrEqualTo(1));
    });

    testWidgets('首页日期分组流：同日合组、异日各起组头（§5.2）', (WidgetTester tester) async {
      useSurface(tester, height: 2600); // 6 帖全展开须够高：ListView/Sliver 懒构建，屏外卡片不在树里
      await tester.pumpWidget(testApp(repo, initial: '/home'));
      await tester.pumpAndSettle();

      // 语料 6 帖进时间线（求书帖 20003 不进），落在 5 个不同日期上，其中 04-28 有 2 帖。
      for (final String d in <String>['2025-04-28', '2025-04-20', '2025-04-15', '2025-04-02', '2024-12-05']) {
        expect(find.byKey(ValueKey<String>('timeline-group-$d')), findsOneWidget, reason: '$d 应恰有一个组头');
      }
      expect(find.byKey(const ValueKey<String>('timeline-group-2024-06-11')), findsNothing,
          reason: 'post_kind=求书 的帖不进时间线');
      expect(find.text('求书：有没有类似世子很凶的'), findsNothing);
      // 同日两帖都渲染在同一组下。
      expect(find.text('【扫书】yy小说吧四月下旬合集'), findsOneWidget);
      expect(find.text('【扫书】哀伤雪刃四月补档'), findsOneWidget);
      // origin 三档徽标齐活。
      expect(find.text('自采'), findsWidgets);
      expect(find.text('导入'), findsWidgets);
      expect(find.text('内置'), findsWidgets);
    });

    testWidgets('详情操作条：书签写入含六维搜索条件快照，收藏双粒度（§5.6）', (WidgetTester tester) async {
      useSurface(tester);
      const SearchFilter snapshot = SearchFilter(query: '世子', year: '2024', channel: 'yy小说吧');
      await tester.pumpWidget(testApp(
        repo,
        home: const ContentDetailPage(
          selection: PostSelection(postId: 18293, position: 2, snapshot: snapshot),
        ),
      ));
      await tester.pumpAndSettle();

      expect(repo.bookmarks, isEmpty);
      await tester.tap(find.text('书签'));
      await tester.pumpAndSettle();
      expect(find.text('已加入书签（含搜索条件快照）'), findsOneWidget);
      expect(repo.bookmarks, hasLength(1));
      final Bookmark bm = repo.bookmarks.single;
      expect(bm.postRef, 18293);
      expect(bm.title, '【扫书】雪群推书四月精选');
      expect(bm.position, 2, reason: '结果列表位置随快照落库');
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
      await tester.pumpWidget(testApp(repo, home: const BookDetailPage(bookGroupId: 904)));
      await tester.pumpAndSettle();

      // 书名大标题（display 30）+ 2 张评价卡的书名 chip（cardTitle 16）= 3 处同文案。
      expect(find.text('《逍遥小书生》'), findsNWidgets(3));
      expect(
        find.byWidgetPredicate((Widget w) => w is Text && w.data == '《逍遥小书生》' && w.style?.fontSize == 30),
        findsOneWidget,
        reason: '书名大标题走 display 字阶 token（§3 #04）',
      );
      expect(find.textContaining('2 条独立推荐'), findsOneWidget);
      // 计数对比：1 推荐 / 1 排雷。
      final CountDuo duo = tester.widget<CountDuo>(find.byType(CountDuo));
      expect(duo.recommend, 1);
      expect(duo.avoid, 1);

      // 点计数对比里的「排雷」= 直接置「仅排雷」筛选（§5.5，P0-13）。
      // 注意 '排雷' 文案在页面上有两处（计数对比 label + 排雷条目的 SemanticBadge），须限定到 CountDuo 内。
      await tester.tap(find.descendant(of: find.byType(CountDuo), matching: find.text('排雷')));
      await tester.pumpAndSettle();
      expect(find.textContaining('全部评价 1'), findsOneWidget);
      expect(find.text('《逍遥小书生》'), findsNWidgets(2), reason: '书名大标题 + 仅存的 1 张排雷评价卡');

      // 语义 chips 回「全部」。
      await tester.tap(find.descendant(
          of: find.byType(SegmentedPill<SemanticFilter>), matching: find.text('全部')));
      await tester.pumpAndSettle();
      expect(find.textContaining('全部评价 2'), findsOneWidget);
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

      final ProviderContainer container = containerOf(tester, find.byType(SearchPage));
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
      await tester.tap(find.byIcon(Icons.history_rounded).hitTestable().first);
      await tester.pumpAndSettle();
      final SearchDraft replay = container.read(searchDraftProvider);
      expect(replay.submitted, isTrue);
      expect(replay.filter.query, '十日终焉');
      expect(repo.history, hasLength(1), reason: '同条件去重，不重复记账');
    });

    testWidgets('2 字词走 LIKE 兜底：结果区不挂 FTS 标记（§7.3）', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(repo, initial: '/search?q=%E7%BB%88%E7%84%89'));
      await tester.pumpAndSettle();

      final ProviderContainer container = containerOf(tester, find.byType(SearchPage));
      expect(container.read(searchDraftProvider).filter.query, '终焉');
      expect(find.text('FTS'), findsNothing, reason: '2 字词 trigram 不可用 → LIKE');
      expect(find.text('1 结果'), findsOneWidget);
    });

    testWidgets('我的页：书签/收藏/历史三段实时列表 + 点书签恢复六维快照（§5.10）', (WidgetTester tester) async {
      useSurface(tester, height: 1400);
      // 预置用户数据（fake 的写路径只有微任务，可在 testWidgets 体内 await）。
      await repo.togglePostBookmark(
        postRef: 7,
        title: '【扫书】yy小说吧四月下旬合集',
        author: '扫书人甲',
        channel: 'yy小说吧',
        position: 6,
        snapshot: const SearchFilter(query: '无限流', year: '2024', tenDay: TenDayFilter.upper, category: '扫书'),
      );
      await repo.toggleFavorite(targetType: FavoriteTarget.bookGroup, targetId: 901, title: '《十日终焉》');
      await repo.addHistory(const SearchFilter(query: '世子很凶', month: '4'));

      await tester.pumpWidget(testApp(repo, initial: '/profile'));
      await tester.pumpAndSettle();

      expect(find.text('书签夹 1'), findsOneWidget);
      expect(find.text('收藏夹 1'), findsOneWidget);
      expect(find.text('搜索历史 1'), findsOneWidget);
      // 书签行展示快照摘要与列表位置（§5.10 线框）。
      expect(find.textContaining('快照:'), findsOneWidget);
      expect(find.textContaining('第 7 条'), findsOneWidget);
      expect(find.text('《十日终焉》'), findsWidgets);

      // 点书签 = 携六维快照跳搜索台并自动出结果。
      await tester.tap(find.textContaining('「【扫书】yy小说吧四月下旬合集」'));
      await tester.pumpAndSettle();
      final SearchDraft draft = containerOf(tester, find.byType(SearchPage)).read(searchDraftProvider);
      expect(draft.submitted, isTrue);
      expect(draft.filter.query, '无限流');
      expect(draft.filter.year, '2024');
      expect(draft.filter.tenDay, TenDayFilter.upper);
      expect(draft.filter.category, '扫书');
    });

    testWidgets('采集页：本地库概览走真实计数，采集调度显式标注未实装（§5.9）', (WidgetTester tester) async {
      useSurface(tester, height: 1400);
      await tester.pumpWidget(testApp(repo, initial: '/collect'));
      await tester.pumpAndSettle();

      expect(find.text('库容量'), findsOneWidget);
      expect(find.text('14 条'), findsOneWidget, reason: '库容量 = demoLibrary 的 14 条目，不得显示假 0');
      expect(find.text('2025-04-28'), findsOneWidget, reason: '数据截至 = 条目最大日期');
      // 类别构成四档齐活。
      for (final String kind in CategoryKind.all) {
        expect(find.text(kind), findsWidgets);
      }
      // 溯源徽标图例三档。
      expect(find.byType(OriginBadge), findsNWidgets(3));
      // 采集调度属 M2-①：不做假 UI，显式标注。
      expect(find.textContaining('尚未实装'), findsOneWidget);
    });

    testWidgets('详情页：目录弹层跳楼层 + 上下帖 PageView（§5.6）', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(testApp(
        repo,
        home: const ContentDetailPage(
          selection: PostSelection(postId: 7, siblings: <int>[7, 14403], position: 3),
        ),
      ));
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
      final Iterable<BookEntryCard> cards = tester.widgetList<BookEntryCard>(find.byType(BookEntryCard));
      expect(cards.length, 4);
      for (final BookEntryCard card in cards) {
        expect(card.entry.category, CategoryKind.scan);
        expect(card.entry.comment!.length, greaterThanOrEqualTo(20));
      }

      // 换一批 = invalidate 重抽，面板不塌。
      await tester.tap(find.text('换一批'));
      await tester.pumpAndSettle();
      expect(tester.widgetList<BookEntryCard>(find.byType(BookEntryCard)), hasLength(4));
      expect(repo.calls['randomBooks'], greaterThanOrEqualTo(2));
    });

    testWidgets('expanded 双栏：帖子详情走 _DetailSlot 右槽原位切换（§9.7）', (WidgetTester tester) async {
      useSurface(tester, width: 1440, height: 900);
      await tester.pumpWidget(testApp(repo, initial: '/home'));
      await tester.pumpAndSettle();

      // 未选中 = 空态。
      expect(find.text('选择左侧内容查看详情'), findsOneWidget);

      // 点时间线卡片 → expanded 且不可 pop → 右槽原位接管，不 push 新路由。
      await tester.tap(find.text('【扫书】yy小说吧四月下旬合集').first);
      await tester.pumpAndSettle();
      final ProviderContainer container = containerOf(tester, find.byType(HomePage));
      expect(container.read(detailSelectionProvider)?.postId, 7);
      expect(find.textContaining('排雷帖'), findsNothing, reason: '扫书帖不挂排雷风险提示');
      expect(find.byType(ContentDetailPage), findsOneWidget);
      expect(find.text('选择左侧内容查看详情'), findsNothing);
    });
  });
}
