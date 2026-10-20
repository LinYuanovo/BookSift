import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/features/export/booklist_export.dart';

import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import 'support.dart';

// 书单导出生成器（M3 P2-4）纯函数单测：MD/TXT 结构、署名行、排雷标记、
// 空收藏文案、摘要截断、文件名，以及两个收集器对 FakeBookRepository 的补全。
//
// 全部 plain test()（零 widget、零真实 IO；FakeBookRepository 只有微任务）。

void main() {
  group('renderMarkdown', () {
    test('收藏夹文档：标题 + 时间戳元信息 + 每书分组字段 + 署名行', () {
      final String md = renderMarkdown(demoFavoritesDoc());
      expect(md, contains('# 我的收藏书单'));
      expect(md, contains('> 生成时间: 2026-10-13 12:00 · 共 2 本书 · 共 1 帖'));
      // 书块：书名/作者/推荐人/渠道/日期（含条数）分组齐活。
      expect(md, contains('### 《十日终焉》'));
      expect(md, contains('- 作者: 杀虫队队员'));
      expect(md, contains('- 推荐人: 推荐人2009'));
      expect(md, contains('- 渠道: yy小说吧 / 大佬专栏'));
      expect(md, contains('- 日期: 2024-12-05 ~ 2025-04-28 · 共 2 条推荐'));
      // 推荐语摘要 = 引用块。
      expect(md, contains('> 无限流佳作，副本设计很有想法，群像写得扎实。'));
      // 帖子段。
      expect(md, contains('## 帖子'));
      expect(md, contains('- 「排雷：这几本千万别踩」 · 避雷使者 · 哀伤雪刃 · 2025-04-20 · ⚠ 排雷'));
      // 署名行收尾。
      expect(md.trimRight(), endsWith(kBooklistAttribution));
      expect(md, contains('---'));
    });

    test('排雷标记只在含排雷的书上出现', () {
      final String md = renderMarkdown(demoFavoritesDoc());
      final String first = md.substring(md.indexOf('### 《十日终焉》'), md.indexOf('### 《逍遥小书生》'));
      final String second = md.substring(md.indexOf('### 《逍遥小书生》'), md.indexOf('## 帖子'));
      expect(first, isNot(contains('排雷标记')), reason: '十日终焉 avoidCount=0');
      expect(second, contains('- ⚠ 排雷标记: 含 1 条排雷提示'));
    });

    test('单书文档：书目信息 + 推荐明细逐条编号，排雷条目显式标注', () {
      final String md = renderMarkdown(demoBookDoc());
      expect(md, contains('# 《逍遥小书生》推荐单'));
      expect(md, contains('> 生成时间: 2026-10-13 12:00 · 共 2 条 · 推荐 1 · 排雷 1'));
      expect(md, contains('## 书目信息'));
      expect(md, contains('- 作者: 荣荣'));
      expect(md, contains('- 统计: 共 2 条 · 推荐 1 · 排雷 1'));
      expect(md, contains('## 推荐明细'));
      expect(md, contains('### 推荐 1 · 推荐人2013 · 2025-03-30 · yy小说吧'));
      expect(md, contains('> 轻松日常向，主角讨喜，适合下饭，更新也稳定。'));
      expect(md, contains('### ⚠ 排雷 2 · 推荐人2014 · 2024-06-11 · 哀伤雪刃'));
      expect(md, contains('> （该条无推荐语）'), reason: '无推荐语不静默丢条目');
      expect(md.trimRight(), endsWith(kBooklistAttribution));
    });

    test('空收藏：完整文档骨架 + 空态文案 + 署名行', () {
      final String md = renderMarkdown(demoEmptyDoc());
      expect(md, contains('# 我的收藏书单'));
      expect(md, contains('> 生成时间: 2026-10-13 12:00'));
      expect(md, contains(kEmptyFavoritesMessage));
      expect(md, isNot(contains('## 书籍')));
      expect(md.trimRight(), endsWith(kBooklistAttribution));
    });
  });

  group('renderText', () {
    test('收藏夹文档：分隔线 + 分区 + 全角标签对齐 + 署名行', () {
      final String txt = renderText(demoFavoritesDoc());
      final List<String> lines = txt.split('\n');
      expect(lines[0], '我的收藏书单');
      expect(lines[1], '生成时间: 2026-10-13 12:00 · 共 2 本书 · 共 1 帖');
      expect(lines[2], startsWith('═'), reason: '文档头重分隔线');
      expect(txt, contains('【书籍】'));
      expect(txt, contains('《十日终焉》'));
      // 全角空格填充到 3 字宽 → 值列对齐。
      expect(txt, contains('  作\u3000者: 杀虫队队员'));
      expect(txt, contains('  推荐人: 推荐人2009'));
      expect(txt, contains('  渠\u3000道: yy小说吧 / 大佬专栏'));
      expect(txt, contains('  日\u3000期: 2024-12-05 ~ 2025-04-28（共 2 条推荐）'));
      expect(txt, contains('  摘\u3000要: 「无限流佳作，副本设计很有想法，群像写得扎实。」'));
      expect(txt, contains('【帖子】'));
      expect(txt, contains('「排雷：这几本千万别踩」'));
      expect(txt, contains('发帖人: 避雷使者 · 渠道: 哀伤雪刃 · 日期: 2025-04-20 · ⚠ 排雷'));
      expect(txt.trimRight(), endsWith(kBooklistAttribution));
      expect(txt, contains('────'), reason: '署名脚细分隔线');
    });

    test('排雷标记行只出现在含排雷的书上', () {
      final String txt = renderText(demoFavoritesDoc());
      final String first = txt.substring(txt.indexOf('《十日终焉》'), txt.indexOf('《逍遥小书生》'));
      final String second = txt.substring(txt.indexOf('《逍遥小书生》'), txt.indexOf('【帖子】'));
      expect(first, isNot(contains('排\u3000雷')));
      expect(second, contains('  排\u3000雷: 含 1 条排雷提示'));
    });

    test('单书文档：书目信息 + 明细编号 + 无推荐语占位', () {
      final String txt = renderText(demoBookDoc());
      expect(txt.split('\n')[0], '《逍遥小书生》推荐单');
      expect(txt, contains('【书目信息】'));
      expect(txt, contains('  作\u3000者: 荣荣'));
      expect(txt, contains('  统\u3000计: 共 2 条 · 推荐 1 · 排雷 1'));
      expect(txt, contains('【推荐明细】'));
      expect(txt, contains('  [推荐 1] 推荐人2013 · 2025-03-30 · yy小说吧'));
      expect(txt, contains('      轻松日常向，主角讨喜，适合下饭，更新也稳定。'));
      expect(txt, contains('  [⚠ 排雷 2] 推荐人2014 · 2024-06-11 · 哀伤雪刃'));
      expect(txt, contains('      （该条无推荐语）'));
      expect(txt.trimRight(), endsWith(kBooklistAttribution));
    });

    test('空收藏：空态文案 + 署名行', () {
      final String txt = renderText(demoEmptyDoc());
      expect(txt, contains(kEmptyFavoritesMessage));
      expect(txt, isNot(contains('【书籍】')));
      expect(txt.trimRight(), endsWith(kBooklistAttribution));
    });
  });

  group('工具纯函数', () {
    test('renderBooklist 按格式分派', () {
      final BooklistDoc doc = demoFavoritesDoc();
      expect(renderBooklist(doc, BooklistFormat.markdown), renderMarkdown(doc));
      expect(renderBooklist(doc, BooklistFormat.text), renderText(doc));
    });

    test('summarizeComment：压平换行 / 截断加省略号 / 空白归 null', () {
      expect(summarizeComment('  第一段\n\n  第二段  '), '第一段 第二段');
      expect(summarizeComment(null), isNull);
      expect(summarizeComment('   '), isNull);
      final String long = summarizeComment('长' * 61)!;
      expect(long, '${'长' * 60}…');
      expect(summarizeComment('短' * 60)!, '短' * 60, reason: '恰好 60 字不截断');
    });

    test('defaultBooklistFileName：时间戳 + 格式扩展名', () {
      expect(
        defaultBooklistFileName(BooklistFormat.markdown, now: demoExportNow),
        'booksift_booklist_20261013_120000.md',
      );
      expect(
        defaultBooklistFileName(BooklistFormat.text, now: demoExportNow),
        'booksift_booklist_20261013_120000.txt',
      );
    });

    test('stripBookMarks / parseChannels', () {
      expect(stripBookMarks('《十日终焉》'), '十日终焉');
      expect(stripBookMarks('《书名》 suffix'), '《书名》 suffix');
      expect(parseChannels('["yy小说吧","大佬专栏"]'), <String>['yy小说吧', '大佬专栏']);
      expect(parseChannels('yy小说吧,大佬专栏'), <String>['yy小说吧', '大佬专栏']);
      expect(parseChannels(null), isEmpty);
    });
  });

  group('收集器（FakeBookRepository 纯内存）', () {
    test('buildFavoritesDoc：书粒度补全作者/渠道/日期跨度/摘要，帖粒度带排雷语义', () async {
      final FakeBookRepository repo = FakeBookRepository(library: demoLibrary());
      await repo.toggleFavorite(
        targetType: FavoriteTarget.bookGroup,
        targetId: 901,
        title: '《十日终焉》',
        subtitle: '杀虫队队员',
      );
      await repo.toggleFavorite(
        targetType: FavoriteTarget.post,
        targetId: 14403,
        title: '排雷：这几本千万别踩',
      );

      final BooklistDoc doc = await buildFavoritesDoc(
        repo: repo,
        favorites: repo.favorites,
        now: demoExportNow,
      );
      expect(doc.kind, BooklistDocKind.favorites);
      expect(doc.heading, '我的收藏书单');
      expect(doc.generatedAt, demoExportNow);

      expect(doc.books, hasLength(1));
      final ExportBook book = doc.books.single;
      expect(book.title, '十日终焉', reason: '收藏标题两侧《》被剥掉');
      expect(book.author, '杀虫队队员');
      expect(book.channels, <String>['yy小说吧']);
      expect(book.dateRange, '2024-12-05 ~ 2025-04-28');
      expect(book.entryCount, 2);
      expect(book.avoidCount, 0);
      // 摘要取 quality 最高且有推荐语的那条（2009）。
      final ExportRecommendation rec = book.recommendations.single;
      expect(rec.recommender, '推荐人2009');
      expect(rec.comment, contains('无限流佳作'));
      expect(rec.comment!.length, lessThanOrEqualTo(kSummaryMaxChars + 1));

      expect(doc.posts, hasLength(1));
      final ExportPost post = doc.posts.single;
      expect(post.title, '排雷：这几本千万别踩');
      expect(post.author, '避雷使者');
      expect(post.channel, '哀伤雪刃');
      expect(post.date, '2025-04-20');
      expect(post.avoid, isTrue);
    });

    test('buildFavoritesDoc：书目已被移除 → 退化为收藏行字段，不丢行', () async {
      final FakeBookRepository repo = FakeBookRepository(library: demoLibrary());
      await repo.toggleFavorite(
        targetType: FavoriteTarget.bookGroup,
        targetId: 99999,
        title: '《不存在的书》',
        subtitle: '佚名',
      );
      final BooklistDoc doc = await buildFavoritesDoc(
        repo: repo,
        favorites: repo.favorites,
        now: demoExportNow,
      );
      expect(doc.books, hasLength(1));
      expect(doc.books.single.title, '不存在的书');
      expect(doc.books.single.author, '佚名', reason: 'group 缺失时回退收藏 subtitle');
      expect(doc.books.single.recommendations, isEmpty);
      // 渲染不炸且给占位。
      expect(renderMarkdown(doc), contains('推荐语摘要: （暂无推荐语）'));
    });

    test('buildBookDoc：当前筛选条目全量进明细，排雷/推荐计数跟随筛选', () async {
      final FakeBookRepository repo = FakeBookRepository(library: demoLibrary());
      final BookDetailData data = (await repo.bookDetail(904))!;
      final List<EntryRow> entries = await repo.bookEntries(904, SemanticFilter.all);

      final BooklistDoc doc = buildBookDoc(data: data, entries: entries, now: demoExportNow);
      expect(doc.kind, BooklistDocKind.singleBook);
      expect(doc.heading, '《逍遥小书生》推荐单');
      final ExportBook book = doc.books.single;
      expect(book.title, '逍遥小书生');
      expect(book.author, '荣荣');
      expect(book.recommendations, hasLength(2));
      expect(book.recommendations.where((ExportRecommendation r) => r.avoid), hasLength(1));
      expect(doc.metaLine, contains('共 2 条 · 推荐 1 · 排雷 1'));

      // 仅推荐筛选 → 明细只剩 1 条、排雷计数归 0（与页面所见一致）。
      final List<EntryRow> onlyRec = await repo.bookEntries(904, SemanticFilter.recommend);
      final BooklistDoc filtered = buildBookDoc(data: data, entries: onlyRec, now: demoExportNow);
      expect(filtered.books.single.recommendations, hasLength(1));
      expect(filtered.metaLine, contains('共 1 条 · 推荐 1 · 排雷 0'));
    });
  });
}
