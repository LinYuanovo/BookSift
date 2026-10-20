import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/constants.dart';
import 'package:booksift/core/icons.dart';
import 'package:booksift/core/widgets/scroll_chrome.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/features/content/book_detail_page.dart';
import 'package:booksift/features/rank/rank_page.dart';
import 'package:booksift/theme/app_colors.dart';

import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import '../support/harness.dart';

// M2-② 独立热门榜页（设计稿 09 屏 index.html:1928–1980 / 原型 §5.13）。
//
// testWidgets 一律内存 fake（TESTING.md §3.1，零真实 IO）；
// wordRankRows/rankRows 的 SQL 正确性归 rank_queries_test.dart（plain test，真库副本）。

/// 字数榜（库B子集）语料：MAX(word_count) 可判定 + word_count NULL 出榜但进推荐榜。
FakeLibrary wordRankLibrary() {
  EntryRow e({
    required int id,
    required String nameNorm,
    required String date,
    int? wordCount,
    int? groupId,
    String? bookGrade,
    String author = '佚',
  }) =>
      EntryRow(
        id: id,
        name: '《$nameNorm》',
        nameNorm: nameNorm,
        author: author,
        date: date,
        channel: 'yy小说吧',
        category: CategoryKind.scan,
        bookGrade: bookGrade,
        origin: Origin.builtin,
        quality: 2,
        wordCount: wordCount,
        bookGroupId: groupId,
      );
  BookGroup g({required int id, required String nameNorm, String? author}) => BookGroup(
        id: id,
        nameNorm: nameNorm,
        authorEffNorm: author ?? '',
        nameDisplay: nameNorm,
        authorDisplay: author,
        entryTotal: 1,
        distinctComment: 1,
        channels: '["yy小说吧"]',
      );
  return FakeLibrary(
    posts: const <Post>[],
    floors: const <int, List<FloorData>>{},
    entries: <EntryRow>[
      // 长剑行：MAX(word_count)=3,000,000 → 字数榜榜首「300 万字」。
      e(id: 1, nameNorm: '长剑行', date: '2023-01-01', wordCount: 3000000, groupId: 910, bookGrade: '#11850A', author: '作者甲'),
      e(id: 2, nameNorm: '长剑行', date: '2025-04-10', wordCount: 2450000, groupId: 910, bookGrade: '#11850A', author: '作者甲'),
      // 小城烟火：980,000 → 「98 万字」。
      e(id: 3, nameNorm: '小城烟火', date: '2025-04-20', wordCount: 980000, groupId: 911, bookGrade: '#11850A', author: '作者乙'),
      // 无字数书：word_count NULL → 不进字数榜，进推荐次数榜（2 条）。
      e(id: 4, nameNorm: '无字数书', date: '2025-04-21', groupId: 912, bookGrade: '#11850A', author: '作者丙'),
      e(id: 5, nameNorm: '无字数书', date: '2025-04-22', groupId: 912, bookGrade: '#11850A', author: '作者丙'),
      e(id: 6, nameNorm: '第四名书', date: '2025-04-23', wordCount: 500000, groupId: 913, bookGrade: '#11850A', author: '作者丁'),
    ],
    groups: <BookGroup>[
      g(id: 910, nameNorm: '长剑行', author: '作者甲'),
      g(id: 911, nameNorm: '小城烟火', author: '作者乙'),
      g(id: 912, nameNorm: '无字数书', author: '作者丙'),
      g(id: 913, nameNorm: '第四名书', author: '作者丁'),
    ],
  );
}

void main() {
  late FakeBookRepository repo;

  setUp(() {
    repo = FakeBookRepository(library: demoLibrary());
  });

  testWidgets('四时段切换 → 榜单重排 + scope 文案（§5.13，锚 2025-04-30）', (WidgetTester tester) async {
    useSurface(tester, height: 1400);
    await tester.pumpWidget(testApp(repo, initial: '/rank', rankToday: DateTime(2025, 4, 30)));
    await tester.pumpAndSettle();

    // 默认：推荐次数榜 · 全时段；badge kind = 「推荐次数」；榜首《世子很凶》188 推口径（fake 语料 5 推）。
    expect(find.text('推荐次数榜 · 全时段 Top10'), findsOneWidget);
    expect(find.text('推荐次数'), findsOneWidget);
    expect(find.text('《世子很凶》'), findsOneWidget);
    expect(find.text('5 推'), findsOneWidget);

    // 切「本月」→ 重排：仅保留帖子标题带推书语义的条目；scope 带锚点年月。
    await tester.tap(find.text('本月'));
    await tester.pumpAndSettle();
    expect(find.text('推荐次数榜 · 本月 · 2025-04 Top10'), findsOneWidget);
    expect(find.text('《篡水浒》'), findsOneWidget);
    expect(find.text('《世子很凶》'), findsNothing);
    expect(repo.calls['rankRows:${RankWindow.thisMonth}'], greaterThanOrEqualTo(1));

    // 切「本年」→ scope 「本年 · 2025」。
    await tester.tap(find.text('本年'));
    await tester.pumpAndSettle();
    expect(find.text('推荐次数榜 · 本年 · 2025 Top10'), findsOneWidget);
    expect(repo.calls['rankRows:${RankWindow.thisYear}'], greaterThanOrEqualTo(1));

    // 切「近30天」（锚 2025-04-30 与本月同窗）→ scope 文案不带年月。
    await tester.tap(find.text('近30天'));
    await tester.pumpAndSettle();
    expect(find.text('推荐次数榜 · 近30天 Top10'), findsOneWidget);
    expect(repo.calls['rankRows:${RankWindow.last30}'], greaterThanOrEqualTo(1));
  });

  testWidgets('榜种切换：appbar badge 点击（底部按钮已删）、MAX 字数降序、NULL 出榜、口径说明', (WidgetTester tester) async {
    useSurface(tester, height: 1400);
    final FakeBookRepository wordRepo = FakeBookRepository(library: wordRankLibrary());
    await tester.pumpWidget(testApp(wordRepo, initial: '/rank', rankToday: DateTime(2025, 4, 30)));
    await tester.pumpAndSettle();

    // 推荐次数榜：无字数书在榜（2 条推荐）；底部切换按钮已移除（问题B）。
    expect(find.text('《无字数书》'), findsOneWidget);
    expect(find.text('切换字数榜（库B子集年榜）'), findsNothing);
    expect(find.text('切换推荐次数榜'), findsNothing);

    // 右上角 badge = 唯一切换入口：文案显示当前榜名，点击切到字数榜。
    await tester.tap(find.text('推荐次数'));
    await tester.pumpAndSettle();

    // scope/badge 随榜种切换；字数榜口径诚实说明在场（问题D）；
    // word_count NULL 的《无字数书》出榜。
    expect(find.text('字数榜 · 全时段 Top10'), findsOneWidget);
    expect(find.text('字数'), findsOneWidget);
    expect(find.text('字数榜仅收录带字数数据的书目；自采书目匹配到内置库同书后自动入榜'), findsOneWidget);
    expect(find.text('《无字数书》'), findsNothing);
    // MAX(word_count) 降序：长剑行(3,000,000→300 万字) 榜首，小城烟火(980,000→98 万字) 次席。
    expect(
      find.descendant(of: find.byKey(const ValueKey<String>('rank-row-0')), matching: find.text('《长剑行》')),
      findsOneWidget,
    );
    expect(find.text('300 万字'), findsOneWidget);
    expect(find.text('98 万字'), findsOneWidget);
    expect(wordRepo.calls['wordRankRows:${RankWindow.allTime}'], greaterThanOrEqualTo(1));

    // 再点 badge 切回推荐次数榜（口径说明随之消失）。
    await tester.tap(find.text('字数'));
    await tester.pumpAndSettle();
    expect(find.text('推荐次数榜 · 全时段 Top10'), findsOneWidget);
    expect(find.text('字数榜仅收录带字数数据的书目；自采书目匹配到内置库同书后自动入榜'), findsNothing);
    expect(find.text('《无字数书》'), findsOneWidget);
  });

  testWidgets('Top3 衬线序号强调：23px accent-strong / 其余 17px muted（index.html:793–797）', (WidgetTester tester) async {
    useSurface(tester, height: 1400);
    final FakeBookRepository rankRepo = FakeBookRepository(library: wordRankLibrary());
    await tester.pumpWidget(testApp(rankRepo, initial: '/rank', rankToday: DateTime(2025, 4, 30)));
    await tester.pumpAndSettle();

    final Text no1 = tester.widget<Text>(find.byKey(const ValueKey<String>('rank-no-0')));
    expect(no1.style?.fontSize, 23);
    expect(no1.style?.fontWeight, FontWeight.w700);
    expect(no1.style?.color, AppColors.light.accentStrong);
    final Text no4 = tester.widget<Text>(find.byKey(const ValueKey<String>('rank-no-3')));
    expect(no4.style?.fontSize, 17);
    expect(no4.style?.color, AppColors.light.textMuted);
  });

  testWidgets('榜单行点击 → push /book/{groupId} 书聚合页（§5.13 → §5.5）', (WidgetTester tester) async {
    useSurface(tester, height: 1400);
    await tester.pumpWidget(testApp(repo, initial: '/rank', rankToday: DateTime(2025, 4, 30)));
    await tester.pumpAndSettle();

    // demo 语料榜首 世子很凶 → book_groups.id 842。
    await tester.tap(find.byKey(const ValueKey<String>('rank-row-0')));
    await tester.pumpAndSettle();
    expect(find.byType(BookDetailPage), findsOneWidget);
  });

  testWidgets('空态「该时段暂无推荐」+ [看看全时段] 回全时段（§5.13）', (WidgetTester tester) async {
    useSurface(tester, height: 1400);
    // 锚 2025-06-15：demo 语料最晚 2025-04-28 → 「本月」窗口为空。
    await tester.pumpWidget(testApp(repo, initial: '/rank', rankToday: DateTime(2025, 6, 15)));
    await tester.pumpAndSettle();
    expect(find.text('《世子很凶》'), findsOneWidget, reason: '全时段仍有数据');

    await tester.tap(find.text('本月'));
    await tester.pumpAndSettle();
    expect(find.text('该时段暂无推荐'), findsOneWidget);

    await tester.tap(find.text('看看全时段'));
    await tester.pumpAndSettle();
    expect(find.text('推荐次数榜 · 全时段 Top10'), findsOneWidget);
    expect(find.text('《世子很凶》'), findsOneWidget);
  });

  testWidgets('reduceMotion：切换退化仍收敛且内容在场（§6.8）', (WidgetTester tester) async {
    useSurface(tester, height: 1400);
    await tester.pumpWidget(
      testApp(
        repo,
        home: Builder(
          builder: (BuildContext context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const RankPage(),
          ),
        ),
      ),
    );
    // 关键断言：假时钟区内 pumpAndSettle 可收敛（无限动画即挂死判失败）。
    await tester.pumpAndSettle();
    expect(find.text('推荐次数榜 · 全时段 Top10'), findsOneWidget);
    expect(find.text('《世子很凶》'), findsOneWidget);
  });

  testWidgets('图标守卫：/rank 页图标全为设计稿 SVG，零 Material Icon', (WidgetTester tester) async {
    useSurface(tester, height: 1400);
    await tester.pumpWidget(testApp(repo, initial: '/rank', rankToday: DateTime(2025, 4, 30)));
    await tester.pumpAndSettle();

    final Finder page = find.byType(RankPage);
    expect(page, findsOneWidget);
    // back(24) + badge flame(12) + rank-note db(13) + ScrollChrome 跳顶/跳底 chev(20)×2 = 5 个 SVG 档位图标。
    expect(find.descendant(of: page, matching: find.byType(AppIcon)), findsNWidgets(5));
    expect(find.descendant(of: page, matching: find.byType(SvgPicture)), findsNWidgets(5));
    expect(find.descendant(of: page, matching: find.byType(Icon)), findsNothing);
  });

  testWidgets('ScrollChrome 接入榜单主滚动区（常驻滚动条 + 跳顶跳底）', (WidgetTester tester) async {
    useSurface(tester, height: 1400);
    await tester.pumpWidget(testApp(repo, initial: '/rank', rankToday: DateTime(2025, 4, 30)));
    await tester.pumpAndSettle();
    expect(find.byType(ScrollChrome), findsOneWidget);
  });

  testWidgets('首页热门榜 tile：rank-mini 副标题预览 + 点击 push /rank（设计稿 01 entry-tile）', (WidgetTester tester) async {
    useSurface(tester, height: 1400);
    await tester.pumpWidget(testApp(repo, initial: '/home', rankToday: DateTime(2025, 4, 30)));
    await tester.pumpAndSettle();

    // 内嵌大榜已移除（设计 01 首页仅 entry-tile 入口），副标题 = 全时段 Top1 书名。
    expect(find.byKey(const Key('rank-board')), findsNothing);
    expect(find.text('推荐次数 Top · 世子很凶'), findsOneWidget);

    await tester.tap(find.text('热门榜'));
    await tester.pumpAndSettle();
    expect(find.byType(RankPage), findsOneWidget);
    expect(find.text('推荐次数榜 · 全时段 Top10'), findsOneWidget);
  });
}
