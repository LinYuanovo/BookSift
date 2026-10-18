// 条目三分类型（entryKindLabel：扫书 / 推书 / 排雷）口径守卫。
//
// 背景（用户口径）：存量库 posts.post_kind 把推书并进扫书（分类链有 Python parity 夹具，
// 判定顺序冻结），「明确是推荐、推书的帖子」在书卡上被显示为扫书。这里用
// 「颜色标记 + 帖标题 + 类别」还原三档，作为书卡计数、条目徽标与「仅推荐/仅排雷」筛选的
// 单一口径。纯函数表驱动，零 IO。

import 'package:booksift/classify/classifier.dart' show PostKind;
import 'package:booksift/classify/src/engine.dart';
import 'package:booksift/data/repo/queries.dart' show Queries;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('entryKindLabel 三分口径', () {
    test('颜色标记优先：绿标→推书档、红标→排雷档（排雷帖里的绿标条目仍算推荐）', () {
      expect(entryKindLabel(category: '扫书', flag: 1), kRecommendKind);
      expect(entryKindLabel(category: '排雷', flag: 1), kRecommendKind);
      expect(entryKindLabel(category: '扫书', flag: -1), PostKind.mine);
      expect(entryKindLabel(category: '求书', flag: -1), PostKind.mine);
      expect(
        entryKindLabel(
          category: '排雷',
          flag: -1,
          bookGrade: '#FF0000',
          title: '作者避雷不错',
        ),
        PostKind.mine,
      );
    });

    test('无标记按标题：推书词 → 推书档（「明确是推书却显示为扫书」的修复点）', () {
      expect(
        entryKindLabel(category: '扫书', flag: 0, title: '推荐十本近期仙草'),
        kRecommendKind,
      );
      expect(
        entryKindLabel(category: '扫书', flag: 0, title: '推书：本月完结合集'),
        kRecommendKind,
      );
      expect(
        entryKindLabel(category: '扫书', flag: 0, title: '扫书之余安利几本'),
        kRecommendKind,
      );
    });

    test('存量真实样本：帖标题明确写推荐/推书 → 无标条目算推书档', () {
      // 2026-10-16 用户反馈的两个真实书名，帖标题在 work/seed_pack/_build/seed_lite.db
      // 与用户库 Documents/app.sqlite 实查如下（后者为回归基准，书卡/书聚合页 rec=1）。
      expect(
        entryKindLabel(category: '扫书', flag: 0, title: '推荐一本宝藏书'),
        kRecommendKind,
      );
      expect(
        entryKindLabel(category: '扫书', flag: 0, title: '推书:我的尸傀和仙子通感了'),
        kRecommendKind,
      );
      expect(
        entryKindLabel(category: '扫书', flag: 0, title: '个人向连载多女主文书单推荐，外加简扫'),
        kRecommendKind,
      );
    });

    test('无标记按标题：排雷词 → 排雷档', () {
      expect(
        entryKindLabel(category: '扫书', flag: 0, title: '排雷：这几本千万别踩'),
        PostKind.mine,
      );
      expect(
        entryKindLabel(category: '扫书', flag: 0, title: '避雷贴汇总'),
        PostKind.mine,
      );
    });

    test('避雷语境按评价对象区分推荐、元讨论与书籍排雷', () {
      expect(
        entryKindLabel(category: '扫书', flag: 0, title: '作者避雷不错'),
        kRecommendKind,
      );
      expect(
        entryKindLabel(category: '扫书', flag: 0, title: '作者的避雷建议不靠谱'),
        PostKind.mine,
      );
      expect(
        entryKindLabel(category: '扫书', flag: 0, title: '作者避雷不错个鬼'),
        PostKind.mine,
      );
      expect(
        entryKindLabel(category: '排雷', flag: -1, title: '作者的避雷建议不靠谱'),
        PostKind.mine,
      );
      expect(
        entryKindLabel(category: '排雷', flag: -1, title: '作者避雷不错'),
        kRecommendKind,
      );
      expect(
        entryKindLabel(category: '扫书', flag: 0, title: '不是排雷，是推荐这本'),
        kRecommendKind,
      );
      expect(
        entryKindLabel(category: '扫书', flag: 0, title: '不排雷，而是推荐这本'),
        kRecommendKind,
      );
      expect(
        entryKindLabel(category: '扫书', flag: 0, title: '没有避雷，是来扫书的'),
        PostKind.scan,
      );
      expect(
        entryKindLabel(category: '扫书', flag: 0, title: '反向避雷，安利这本'),
        kRecommendKind,
      );
      expect(
        entryKindLabel(category: '扫书', flag: 0, title: '排雷？不存在的，推荐这本'),
        kRecommendKind,
      );
      expect(
        entryKindLabel(category: '扫书', flag: 0, title: '《某书》不是很雷'),
        PostKind.scan,
      );
      expect(
        entryKindLabel(category: '扫书', flag: 0, title: '作者避雷不错，但《某书》主角很雷'),
        PostKind.mine,
      );
      expect(
        entryKindLabel(category: '扫书', flag: 0, title: '排雷《某书》主角降智，慎入'),
        PostKind.mine,
      );
      expect(
        entryKindLabel(category: '扫书', flag: 0, title: '扫书合集'),
        PostKind.scan,
      );
    });

    test('SQL 聚合载荷沿用相同的语境分类结果', () {
      expect(Queries.kindCountsOf('排雷\u001f-1\u001f作者避雷不错\u001f'), (0, 1, 0));
      expect(Queries.kindCountsOf('扫书\u001f0\u001f排雷《某书》主角降智，慎入\u001f'), (
        0,
        0,
        1,
      ));
      expect(Queries.kindCountsOf('扫书\u001f0\u001f作者的避雷建议不靠谱\u001f'), (
        0,
        0,
        1,
      ));
      expect(Queries.kindCountsOf('扫书\u001f0\u001f作者避雷不错个鬼\u001f'), (0, 0, 1));
      expect(Queries.kindCountsOf('扫书\u001f0\u001f扫书合集\u001f'), (1, 0, 0));
      expect(Queries.kindCountsOf('排雷\u001f-1\u001f作者避雷不错\u001f#FF0000'), (
        0,
        0,
        1,
      ));
    });

    test('求书类别保留求书档；其余（含纯扫书 / 无标题）归扫书', () {
      expect(entryKindLabel(category: '求书', flag: 0), PostKind.seek);
      expect(
        entryKindLabel(category: '求书', flag: 0, title: '求书：类似世子很凶的'),
        PostKind.seek,
      );
      expect(
        entryKindLabel(category: '扫书', flag: 0, title: '扫书合集'),
        PostKind.scan,
      );
      expect(entryKindLabel(category: '扫书', flag: 0), PostKind.scan);
      expect(entryKindLabel(category: '', flag: 0, title: null), PostKind.scan);
    });
  });
}
