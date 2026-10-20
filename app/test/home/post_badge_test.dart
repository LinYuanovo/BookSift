/// 帖级语义徽标按**标题**校正（需求 4）：分类链把「推书」并入扫书（Python parity 冻结口径），
/// 于是「推书:…／推荐一本…」的帖子原先挂灰「扫书」徽标，与它的书目卡片「1 推荐」自相矛盾。
/// 展示层改为把标题喂给同一判定函数 [entryKindLabel]（见 cards.dart postToneOf）。
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/data/db/app_database.dart';
import 'package:booksift/data/repo/queries.dart';
import 'package:booksift/features/home/cards.dart';
import 'package:booksift/theme/book_theme.dart';

import '../support/demo_data.dart';

Post _post({required String title, required String postKind}) => demoLibrary().posts.firstWhere(
      (Post p) => p.id == 7,
    ).copyWith(title: Value<String?>(title), postKind: postKind);

void main() {
  group('postToneOf：post_kind 打底 + 标题校正', () {
    test('标题写推书/推荐 → 推荐档（即使 post_kind 是扫书）', () {
      expect(postToneOf(postKind: '扫书', title: '推书:我的尸傀和仙子通感了'), SemanticTone.recommend);
      expect(postToneOf(postKind: '扫书', title: '推荐一本宝藏书，书名叫《修改后进入恋爱游戏》'), SemanticTone.recommend);
      expect(postToneOf(postKind: '扫书', title: '个人向连载多女主文书单推荐，外加简扫'), SemanticTone.recommend);
      expect(postToneOf(postKind: '扫书', title: '推＋扫:本月新书'), SemanticTone.recommend);
    });

    test('标题排雷词优先于 post_kind；求书/扫书不变', () {
      expect(postToneOf(postKind: '扫书', title: '排雷：这几本千万别踩'), SemanticTone.avoid);
      expect(postToneOf(postKind: '求书', title: '求书：有没有类似世子很凶的'), SemanticTone.ask);
      expect(postToneOf(postKind: '扫书', title: '【扫书】yy小说吧四月下旬合集'), SemanticTone.scan);
      expect(postToneOf(postKind: '扫书', title: '推书帖里的雷点总结'), SemanticTone.avoid, reason: '标题雷词优先');
    });

    test('无标题/空标题 → 退化为纯 post_kind 判档（老数据行为不变）', () {
      expect(postToneOf(postKind: '扫书', title: null), SemanticTone.scan);
      expect(postToneOf(postKind: '扫书', title: '  '), SemanticTone.scan);
      expect(postToneOf(postKind: '排雷', title: null), SemanticTone.avoid);
      expect(postToneOf(postKind: '求书', title: null), SemanticTone.ask);
    });
  });

  testWidgets('帖子卡徽标随标题变绿「推荐」（用户截图症状）', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BookTheme.light,
        home: Scaffold(
          body: PostCard(
            data: PostCardData(
              post: _post(title: '推书:我的尸傀和仙子通感了', postKind: '扫书'),
              books: const <BookChip>[],
              entryCount: 0,
            ),
            onTap: () {},
            onBookTap: (String _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('扫书'), findsNothing);
  });
}
