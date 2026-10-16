// 条目三分类型（entryKindLabel：扫书 / 推书 / 排雷）口径守卫。
//
// 背景（用户口径）：存量库 posts.post_kind 把推书并进扫书（分类链有 Python parity 夹具，
// 判定顺序冻结），「明确是推荐、推书的帖子」在书卡上被显示为扫书。这里用
// 「颜色标记 + 帖标题 + 类别」还原三档，作为书卡计数、条目徽标与「仅推荐/仅排雷」筛选的
// 单一口径。纯函数表驱动，零 IO。

import 'package:booksift/classify/classifier.dart' show PostKind;
import 'package:booksift/classify/src/engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('entryKindLabel 三分口径', () {
    test('颜色标记优先：绿标→推书档、红标→排雷档（排雷帖里的绿标条目仍算推荐）', () {
      expect(entryKindLabel(category: '扫书', flag: 1), kRecommendKind);
      expect(entryKindLabel(category: '排雷', flag: 1), kRecommendKind);
      expect(entryKindLabel(category: '扫书', flag: -1), PostKind.mine);
      expect(entryKindLabel(category: '求书', flag: -1), PostKind.mine);
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
        entryKindLabel(
          category: '扫书',
          flag: 0,
          title: '个人向连载多女主文书单推荐，外加简扫',
        ),
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
