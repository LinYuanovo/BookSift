import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/constants.dart';
import 'package:booksift/core/icons.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/features/home/cards.dart';
import 'package:booksift/theme/app_colors.dart';
import 'package:booksift/theme/book_theme.dart';

import '../support/harness.dart';

// 共享 UI 原子保真守卫（M2-①）：cards.dart 的 CountDuo / SemanticBadge / BookEntryCard /
// AppEmptyState 已迁到设计稿 SVG 体系，本文件锁死「数字在前 + 零 Material 图标」等设计口径。
//
// 出处：work/ui_design/claude/index.html
//   · CountDuo   行 1449–1452 + CSS 542–555（`[.n rec/dgr 数字][标签]`，无图标）
//   · Badge      行 1465/1479（`.ic.xs` #i-check / #i-alert）
//   · 原帖按钮   行 1469（`原帖 ↗` 纯文本，↗ 为字符）
//   · 空态线稿   §4（SVG accent 64px）
//
// 全部 testWidgets 零真实 IO（仅 BookTheme + 纯展示原子；SvgPicture 走测试资源包，
// 与 rank_page_test / features_test 同机制）。

/// 用明色主题包裹单个原子（AppColors/AppTypography/AppSpacing 扩展均来自 BookTheme.light）。
Widget _atom(Widget child) => MaterialApp(
      theme: BookTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('CountDuo（设计 04 行 1449–1452 / CSS 542–555）', () {
    testWidgets('数字在前、标签在后 + 零 Material Icon（Icons.circle 已删）', (WidgetTester tester) async {
      await tester.pumpWidget(_atom(const CountDuo(recommend: 5, avoid: 1)));
      await tester.pumpAndSettle();

      // 硬红线：计数对比不得残留任何 Material 图标（原为 Icon(Icons.circle, 8)）。
      expect(find.byType(Icon), findsNothing);
      expect(find.byIcon(Icons.circle), findsNothing);

      final Finder recNum = find.text('5');
      final Finder recLabel = find.text('推荐');
      final Finder avoidNum = find.text('1');
      final Finder avoidLabel = find.text('排雷');
      expect(recNum, findsOneWidget);
      expect(recLabel, findsOneWidget);
      expect(avoidNum, findsOneWidget);
      expect(avoidLabel, findsOneWidget);

      // 数字在前：数字 x 坐标严格小于同侧标签 x 坐标。
      expect(tester.getTopLeft(recNum).dx, lessThan(tester.getTopLeft(recLabel).dx));
      expect(tester.getTopLeft(avoidNum).dx, lessThan(tester.getTopLeft(avoidLabel).dx));
    });

    testWidgets('数字 = 衬线 700 17px tabular，推荐绿 / 排雷红（CSS 553–555）', (WidgetTester tester) async {
      await tester.pumpWidget(_atom(const CountDuo(recommend: 5, avoid: 1)));
      await tester.pumpAndSettle();

      final Text recNum = tester.widget<Text>(find.text('5'));
      expect(recNum.style?.fontSize, 17);
      expect(recNum.style?.fontWeight, FontWeight.w700);
      expect(recNum.style?.color, AppColors.light.recommend);
      expect(
        recNum.style?.fontFeatures?.any((FontFeature f) => f.feature == 'tnum'),
        isTrue,
        reason: 'CSS 553 font-variant-numeric:tabular-nums',
      );

      final Text avoidNum = tester.widget<Text>(find.text('1'));
      expect(avoidNum.style?.color, AppColors.light.danger);
      expect(avoidNum.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('点击标签仍触发语义筛选回调（onRecommendTap/onAvoidTap 语义保留）', (WidgetTester tester) async {
      int rec = 0;
      int avoid = 0;
      await tester.pumpWidget(_atom(CountDuo(
        recommend: 5,
        avoid: 1,
        onRecommendTap: () => rec++,
        onAvoidTap: () => avoid++,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('排雷'));
      await tester.pumpAndSettle();
      expect(avoid, 1);
      expect(rec, 0);

      await tester.tap(find.text('推荐'));
      await tester.pumpAndSettle();
      expect(rec, 1);
    });
  });

  group('SemanticBadge（设计 04 行 1465/1479）', () {
    testWidgets('recommend→check-s.svg / avoid→alert-s.svg，零 Material Icon', (WidgetTester tester) async {
      await tester.pumpWidget(_atom(const Column(
        children: <Widget>[
          SemanticBadge(tone: SemanticTone.recommend, animate: false),
          SemanticBadge(tone: SemanticTone.avoid, animate: false),
        ],
      )));
      await tester.pumpAndSettle();

      // 硬红线：徽标内不得残留 Material check_rounded / warning_amber。
      expect(find.byType(Icon), findsNothing);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);

      // 13px ≤ xs 档 → 自动选 stroke2 的 -s 变体（AppIcon.assetName 契约）。
      final Iterable<String> assets =
          tester.widgetList<AppIcon>(find.byType(AppIcon)).map((AppIcon i) => i.assetName);
      expect(assets, containsAll(<String>['assets/icons/check-s.svg', 'assets/icons/alert-s.svg']));
      expect(find.byType(SvgPicture), findsNWidgets(2));
    });

    testWidgets('scan 档 = 灰「扫书」徽标（sunken 底 + textSecondary 字，无图标）', (WidgetTester tester) async {
      await tester.pumpWidget(_atom(const SemanticBadge(tone: SemanticTone.scan, animate: false)));
      await tester.pumpAndSettle();

      expect(SemanticBadge.labelOf(SemanticTone.scan), '扫书');
      final Finder label = find.text('扫书');
      expect(label, findsOneWidget);
      // 与 ask 档同规格的灰徽标：无图标、sunken 底；字色 textSecondary（sunken 底上 textMuted 偏淡）。
      expect(find.byType(SvgPicture), findsNothing, reason: '中性档不带图标');
      expect(find.byType(Icon), findsNothing);
      expect(tester.widget<Text>(label).style?.color, AppColors.light.textSecondary);
      final Finder box = find.ancestor(of: label, matching: find.byType(Container)).first;
      expect((tester.widget<Container>(box).decoration! as BoxDecoration).color, AppColors.light.surfaceSunken);
      // 色条比 neutral 深一档（borderStrong），卡片才看得出「有语义」。
      final BuildContext context = tester.element(label);
      expect(barColorOf(context, SemanticTone.scan), AppColors.light.borderStrong);
      expect(barColorOf(context, SemanticTone.neutral), AppColors.light.border);
    });

    test('toneOf：flag 优先，flag==0 再按类别分档（扫书=scan / 求书=ask / 其余=neutral）', () {
      expect(toneOf(flag: 1, category: CategoryKind.scan), SemanticTone.recommend);
      expect(toneOf(flag: 1, category: CategoryKind.avoid), SemanticTone.recommend, reason: 'flag 优先于类别');
      expect(toneOf(flag: -1, category: CategoryKind.scan), SemanticTone.avoid);
      expect(toneOf(flag: 0, category: CategoryKind.scan), SemanticTone.scan);
      expect(toneOf(flag: 0, category: CategoryKind.ask), SemanticTone.ask);
      // 排雷类无红标 = 中性：entryFlagOf 只在 grade 为空且 category=排雷 时给 −1，不会走到这一档。
      expect(toneOf(flag: 0, category: CategoryKind.avoid), SemanticTone.neutral);
      expect(toneOf(flag: 0, category: CategoryKind.daily), SemanticTone.neutral);
      expect(toneOf(flag: 0, category: null), SemanticTone.neutral);
    });

    test('postToneOf：帖子级按 post_kind 定档，不看 recommend_flag（扫书=scan 灰徽标）', () {
      // 帖子级没有「原帖背书颜色」，recommend_flag 只是 post_kind 的派生存列
      // （扫书+1/排雷−1/求书0）——若按 flag 判，全部扫书帖都会挂绿「推荐」，与条目级口径打架。
      expect(postToneOf(postKind: CategoryKind.scan), SemanticTone.scan);
      expect(postToneOf(postKind: CategoryKind.avoid), SemanticTone.avoid);
      expect(postToneOf(postKind: CategoryKind.ask), SemanticTone.ask);
      expect(postToneOf(postKind: CategoryKind.daily), SemanticTone.neutral);
      expect(postToneOf(postKind: null), SemanticTone.neutral);
    });
  });

  group('BookEntryCard 查看（设计 04 行 1469）', () {
    testWidgets('「查看」纯文本，north_east 图标已删', (WidgetTester tester) async {
      const EntryRow entry = EntryRow(
        id: 1,
        name: '《测试书》',
        nameNorm: '测试书',
        channel: 'yy小说吧',
        category: CategoryKind.scan,
        origin: Origin.builtin,
        quality: 2,
      );
      await tester.pumpWidget(_atom(BookEntryCard(entry: entry, onSourceTap: () {})));
      await tester.pumpAndSettle();

      expect(find.text('查看'), findsOneWidget);
      expect(find.text('原帖 ↗'), findsNothing, reason: '「原帖」已改「查看」（点击是进原帖详情，非外链语义）');
      expect(find.byIcon(Icons.north_east_rounded), findsNothing);
    });
  });

  group('BookEntryCard 首行与摘录', () {
    /// 造一条扫书条目（无颜色标记 → 中性扫书档）。
    EntryRow entry({String? comment, String date = '2025-04-28'}) => EntryRow(
          id: 1,
          name: '《测试书》',
          nameNorm: '测试书',
          channel: 'yy小说吧',
          category: CategoryKind.scan,
          origin: Origin.builtin,
          quality: 2,
          date: date,
          comment: comment,
        );

    testWidgets('折叠态摘录 = comment 前 100 字符 + …；展开全文后显示全文', (WidgetTester tester) async {
      final String comment = "推${'字' * 120}尾";
      expect(comment.runes.length, 122);
      await tester.pumpWidget(_atom(BookEntryCard(entry: entry(comment: comment), expandableComment: true)));
      await tester.pumpAndSettle();

      // 按字符（runes）截断，不是按行数：折叠态恰为前 100 字 + 省略号。
      final String preview = '${String.fromCharCodes(comment.runes.take(100))}…';
      expect(find.text(preview), findsOneWidget);
      expect(find.text(comment), findsNothing, reason: '折叠态不渲染全文');

      await tester.tap(find.text('展开全文'));
      await tester.pumpAndSettle();
      expect(find.text(comment), findsOneWidget);
      expect(find.text(preview), findsNothing);

      await tester.tap(find.text('收起'));
      await tester.pumpAndSettle();
      expect(find.text(preview), findsOneWidget);
    });

    testWidgets('不足 100 字不截断、不给「展开全文」；未开 expandableComment 时全文照登', (WidgetTester tester) async {
      const String short = '稳更的长篇，节奏不错。';
      await tester.pumpWidget(_atom(BookEntryCard(entry: entry(comment: short), expandableComment: true)));
      await tester.pumpAndSettle();
      expect(find.text(short), findsOneWidget);
      expect(find.text('展开全文'), findsNothing);

      final String long = "长${'字' * 130}";
      await tester.pumpWidget(_atom(BookEntryCard(entry: entry(comment: long))));
      await tester.pumpAndSettle();
      expect(find.text(long), findsOneWidget, reason: '分类预览/随机书荒不做折叠');
      expect(find.text('展开全文'), findsNothing);
    });

    testWidgets('hideBookName：首行不渲染书名，日期仍在（书聚合页整页同书）', (WidgetTester tester) async {
      await tester.pumpWidget(_atom(BookEntryCard(entry: entry(), hideBookName: true)));
      await tester.pumpAndSettle();
      expect(find.text('《测试书》'), findsNothing);
      expect(find.text('2025-04-28'), findsOneWidget);

      await tester.pumpWidget(_atom(BookEntryCard(entry: entry())));
      await tester.pumpAndSettle();
      expect(find.text('《测试书》'), findsOneWidget, reason: '默认仍显示书名（随机书荒/分类预览）');
    });

    testWidgets('扫书作者名（推荐人）按 6 字符截断：超出补「…」，≤6 字原样',
        (WidgetTester tester) async {
      EntryRow withRec(String rec) => EntryRow(
            id: 1,
            name: '《测试书》',
            nameNorm: '测试书',
            recommender: rec,
            channel: 'yy小说吧',
            category: CategoryKind.scan,
            origin: Origin.builtin,
            quality: 2,
            date: '2025-04-28',
          );
      // 8 字 → 前 6 字 + …。
      await tester.pumpWidget(_atom(BookEntryCard(
        entry: withRec('扫书作者一二三四五'),
        showRecommender: true,
        onSourceTap: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.text('扫书作者一二…'), findsOneWidget);
      expect(find.text('扫书作者一二三四五'), findsNothing);

      // 5 字 → 原样（不截断）。
      await tester.pumpWidget(_atom(BookEntryCard(
        entry: withRec('短名字五'),
        showRecommender: true,
        onSourceTap: () {},

      )));
      await tester.pumpAndSettle();
      expect(find.text('短名字五'), findsOneWidget);
    });

    testWidgets('首行三段同一中线；日期钉在行尾（书名长短/有无都不挪位）', (WidgetTester tester) async {
      await tester.pumpWidget(_atom(BookEntryCard(entry: entry(), hideBookName: true)));
      await tester.pumpAndSettle();

      final Rect badgeRect = tester.getRect(find.text('扫书'));
      final Rect hiddenNameDate = tester.getRect(find.text('2025-04-28'));
      // 中线对齐：徽标 pill 与 caption 日期垂直中心差 ≤ 1px（原 start 对齐把日期顶到行首之上）。
      expect((badgeRect.center.dy - hiddenNameDate.center.dy).abs(), lessThanOrEqualTo(1));

      // 书名换成超长名 → 书名单行省略，日期右边界不动（Expanded 书名槽吃掉全部余量）。
      final EntryRow longName = EntryRow(
        id: 2,
        name: '《${'很长的书名' * 8}》',
        nameNorm: '很长的书名',
        channel: 'yy小说吧',
        category: CategoryKind.scan,
        origin: Origin.builtin,
        quality: 2,
        date: '2025-04-28',
      );
      await tester.pumpWidget(_atom(BookEntryCard(entry: longName)));
      await tester.pumpAndSettle();
      final Rect longNameDate = tester.getRect(find.text('2025-04-28'));
      expect(longNameDate.right, closeTo(hiddenNameDate.right, 0.5));
      expect(longNameDate.center.dy, closeTo(hiddenNameDate.center.dy, 0.5));

      // 日期取固有宽 → 未被挤成省略号（宽度 = 同字体松散约束下的自然宽）。
      final TextStyle dateStyle = tester.widget<Text>(find.text('2025-04-28')).style!;
      await tester.pumpWidget(_atom(Text('2025-04-28', maxLines: 1, style: dateStyle)));
      await tester.pumpAndSettle();
      expect(longNameDate.width, closeTo(tester.getSize(find.text('2025-04-28')).width, 0.5));
    });
  });

  group('PostCard 底行日期', () {
    PostCardData card({required String author, String date = '2025-04-28'}) => PostCardData(
          post: Post(
            id: 7,
            title: '【扫书】四月下旬合集',
            author: author,
            portrait: '',
            date: date,
            channel: 'yy小说吧',
            postType: CategoryKind.scan,
            postKind: CategoryKind.scan,
            recommendFlag: 1,
            floorCount: 1,
            imageCount: 0,
            origin: Origin.builtin,
          ),
          books: const <BookChip>[],
          entryCount: 0,
        );

    /// compact 手机（390dp 视口 + 16dp 页边距）里的 PostCard：与首页时间线同宽口径。
    Widget phone(PostCardData data) => MaterialApp(
          theme: BookTheme.light,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.topCenter,
                child: PostCard(data: data, onTap: () {}, onBookTap: (String _) {}),
              ),
            ),
          ),
        );

    /// 同字体在松散约束下的自然宽 = 未截断时应有的宽度。
    Future<double> naturalWidthOf(WidgetTester tester, String text, TextStyle style) async {
      await tester.pumpWidget(_atom(Text(text, maxLines: 1, style: style)));
      await tester.pumpAndSettle();
      return tester.getSize(find.text(text)).width;
    }

    testWidgets('日期完整且贴死行尾；收缩压力落在作者名（ellipsis）', (WidgetTester tester) async {
      useSurface(tester); // 390×844 compact（口径同首页时间线）
      const String date = '2025-04-28';
      const String longAuthor = '这是一个特别长的扫书作者名专门用来吃掉整行可用宽度';
      await tester.pumpWidget(phone(card(author: longAuthor)));
      await tester.pumpAndSettle();

      final Finder dateFinder = find.text(date);
      expect(dateFinder, findsOneWidget);
      final Rect dateRect = tester.getRect(dateFinder);
      final TextStyle dateStyle = tester.widget<Text>(dateFinder).style!;
      final Finder authorFinder = find.text(longAuthor);
      expect(authorFinder, findsOneWidget);
      final double authorWidth = tester.getSize(authorFinder).width;
      final TextStyle authorStyle = tester.widget<Text>(authorFinder).style!;
      expect(tester.widget<Text>(authorFinder).overflow, TextOverflow.ellipsis);

      // 日期槽拿到弹性余量的双份 → 装得下完整日期（旧口径作者/Spacer/日期三等分，
      // 日期只剩 ~64dp 被砍成「2025-0…」，正是真机反馈的「日期显示不全」）。
      expect(
        dateRect.width,
        greaterThanOrEqualTo(await naturalWidthOf(tester, date, dateStyle) - 0.5),
        reason: '日期不得被截断',
      );
      // 作者名先让位：宽度 < 自然宽 → 省略号落在作者名上。
      expect(authorWidth, lessThan(await naturalWidthOf(tester, longAuthor, authorStyle)));

      // 日期右边界与作者名长短无关（Expanded 紧约束 + textAlign.end 贴死行尾）。
      await tester.pumpWidget(phone(card(author: '甲')));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text(date)).right, closeTo(dateRect.right, 0.5));
    });

    testWidgets('日期为空时不占位、不抛异常', (WidgetTester tester) async {
      await tester.pumpWidget(phone(card(author: '扫书人甲', date: '')));
      await tester.pumpAndSettle();
      expect(find.text('2025-04-28'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('AppEmptyState（§4 空态线稿）', () {
    testWidgets('svgIcon 单一口径 → 设计 SVG 线稿 accent，零 Material Icon', (WidgetTester tester) async {
      await tester.pumpWidget(_atom(const AppEmptyState(title: '空', svgIcon: 'flame')));
      await tester.pumpAndSettle();

      final AppIcon icon = tester.widget<AppIcon>(find.byType(AppIcon));
      expect(icon.assetName, 'assets/icons/flame.svg'); // 64px > 13 → 非 -s 档
      expect(icon.color, AppColors.light.accent);
      expect(find.byType(SvgPicture), findsOneWidget);
      // 硬红线：空态不再回落任何 Material IconData（图标槽已收敛为 svgIcon 单轨）。
      expect(find.byType(Icon), findsNothing);
    });
  });
}

