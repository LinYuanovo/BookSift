/// worker 纯函数（分类接线 + 书目抽取 §8.7）与长驻 isolate 通道单测。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/classify/classifier.dart';
import 'package:booksift/collector/normalization.dart';
import 'package:booksift/collector/worker.dart';

import 'support.dart';

ClassifyResult _isoScanClassify({
  required String title,
  required String firstFloor,
  required String fullText,
  required List<String> booknames,
}) =>
    ClassifyResult(
      kind: PostKind.scan,
      flag: 1,
      hitRules: const <String>['iso-fake'],
      booknames: booknames,
    );

ThreadInput _input({
  required String title,
  required List<FloorInput> floors,
  int tid = 1,
}) =>
    ThreadInput(
      tid: tid,
      title: title,
      author: '楼主',
      createTime: 1760000000,
      floors: floors,
    );

void main() {
  group('analyzeThread：分类接线（假分类函数注入）', () {
    test('扫书帖 → kind/flag/hitRules 透传，booknames 来自 title+全文', () {
      List<String>? seenBooknames;
      final ThreadAnalysis a = analyzeThread(
        _input(title: '月度扫书', floors: <FloorInput>[
          const FloorInput(pid: 1, seq: 1, text: '《书A》好看'),
          const FloorInput(pid: 2, seq: 2, text: '《书B》也行'),
        ]),
        classify: ({
          required String title,
          required String firstFloor,
          required String fullText,
          required List<String> booknames,
        }) {
          seenBooknames = booknames;
          expect(firstFloor, '《书A》好看');
          expect(fullText, contains('月度扫书'));
          expect(fullText, contains('《书B》也行'));
          return fakeClassify(
              title: title,
              firstFloor: firstFloor,
              fullText: fullText,
              booknames: booknames);
        },
      );
      expect(a.kind, PostKind.scan);
      expect(a.flag, 1);
      expect(seenBooknames, <String>['书A', '书B']);
      expect(a.entries.length, 2, reason: '两楼层各一本书 → 2 条');
    });

    test('日常闲聊 → kind=null 且 entries 空（整帖丢弃仅计数，§8.9）', () {
      final ThreadAnalysis a = analyzeThread(
        _input(title: '水贴闲聊楼', floors: <FloorInput>[
          const FloorInput(pid: 1, seq: 1, text: '《书A》好看'),
        ]),
        classify: fakeClassify,
      );
      expect(a.kind, isNull);
      expect(a.entries, isEmpty);
    });

    test('求书帖 → 不触发书名抽取（§8.9 处置表）', () {
      final ThreadAnalysis a = analyzeThread(
        _input(title: '求书：书荒了', floors: <FloorInput>[
          const FloorInput(pid: 1, seq: 1, text: '想看《书A》这样的'),
        ]),
        classify: fakeClassify,
      );
      expect(a.kind, PostKind.seek);
      expect(a.entries, isEmpty);
    });

    test('排雷帖 → flag=-1 且正常抽取（§8.9：正常入库）', () {
      final ThreadAnalysis a = analyzeThread(
        _input(title: '排雷：《毒草》别看', floors: <FloorInput>[
          const FloorInput(pid: 1, seq: 1, text: '《毒草》 作者：某人 剧毒慎入'),
        ]),
        classify: fakeClassify,
      );
      expect(a.kind, PostKind.mine);
      expect(a.flag, -1);
      expect(a.entries.length, 1);
    });
  });

  group('书目抽取（§8.7：《》书名 + 作者 30 字窗口 + 推荐语窗口）', () {
    test('单书楼层：comment=全楼文本，作者窗口命中 → quality 3', () {
      final ThreadAnalysis a = analyzeThread(
        _input(title: '扫书', floors: <FloorInput>[
          const FloorInput(
              pid: 1, seq: 1, text: '《道诡异仙》 作者：狐尾的笔 好看死了'),
        ]),
        classify: fakeClassify,
      );
      final EntryDraft e = a.entries.single;
      expect(e.name, '道诡异仙');
      expect(e.nameNorm, normName('道诡异仙'));
      expect(e.author, '狐尾的笔');
      expect(e.authorNorm, '狐尾的笔');
      expect(e.comment, '《道诡异仙》 作者：狐尾的笔 好看死了');
      expect(e.quality, 3);
      expect(e.commentNormHash, h16(normText(e.comment)));
      expect(
        e.contentHash,
        entryContentHash(
            nameNorm: e.nameNorm,
            authorNorm: e.authorNorm,
            commentNormHash: e.commentNormHash),
      );
    });

    test('作者在 30 字窗口外 → author=null、quality 2', () {
      final String pad = '水' * 35; // 把「作者：」推出 30 字窗口
      final ThreadAnalysis a = analyzeThread(
        _input(title: '扫书', floors: <FloorInput>[
          FloorInput(pid: 1, seq: 1, text: '《书名A》$pad作者：某人 好看'),
        ]),
        classify: fakeClassify,
      );
      final EntryDraft e = a.entries.single;
      expect(e.author, isNull);
      expect(e.authorNorm, '');
      expect(e.quality, 2);
    });

    test('by 前缀同样命中作者窗口', () {
      final ThreadAnalysis a = analyzeThread(
        _input(title: '扫书', floors: <FloorInput>[
          const FloorInput(pid: 1, seq: 1, text: '《BookX》by AuthorY 好看'),
        ]),
        classify: fakeClassify,
      );
      expect(a.entries.single.author, 'AuthorY');
    });

    test('多书楼层：comment = 书名前后 200 字窗口（非全楼）', () {
      final String x = '甲' * 300;
      final String y = '乙' * 100;
      final String z = '丙' * 300;
      final ThreadAnalysis a = analyzeThread(
        _input(title: '扫书', floors: <FloorInput>[
          FloorInput(pid: 1, seq: 1, text: '$x《A书》$y《B书》$z'),
        ]),
        classify: fakeClassify,
      );
      expect(a.entries.length, 2);
      final EntryDraft ea = a.entries.firstWhere((EntryDraft e) => e.name == 'A书');
      final EntryDraft eb = a.entries.firstWhere((EntryDraft e) => e.name == 'B书');
      // 窗口 ≈ 前200+书名+后200，远小于全楼 700+ 字
      expect(ea.comment.length, lessThan(500));
      expect(ea.comment, contains('《A书》'));
      expect(ea.comment, isNot(contains(z))); // 300 丙 > 200 窗口
      expect(eb.comment, contains('《B书》'));
      expect(eb.comment, isNot(contains(x))); // 300 甲 > 200 窗口
    });

    test('同帖内同 content_hash 去重（两楼同书同推荐语 → 1 条）', () {
      const String text = '《重复书》 作者：某人 好看';
      final ThreadAnalysis a = analyzeThread(
        _input(title: '扫书', floors: <FloorInput>[
          const FloorInput(pid: 1, seq: 1, text: text),
          const FloorInput(pid: 2, seq: 2, text: text),
        ]),
        classify: fakeClassify,
      );
      expect(a.entries.length, 1);
      expect(a.entries.single.floorPid, 1, reason: 'keeper = 首现楼层');
    });

    test('无《》楼层不产出条目', () {
      final ThreadAnalysis a = analyzeThread(
        _input(title: '扫书', floors: <FloorInput>[
          const FloorInput(pid: 1, seq: 1, text: '纯聊天没有书名'),
        ]),
        classify: fakeClassify,
      );
      expect(a.kind, PostKind.scan);
      expect(a.entries, isEmpty);
    });
  });

  group('IsolatePostWorker（长驻后台 isolate，§8.8 CPU 下放）', () {
    test('spawn → analyze 往返 → close（假分类函数经闭包传入）', () async {
      final IsolatePostWorker w = await IsolatePostWorker.spawn(
        dictLines: const <String>[],
        classifier: _isoScanClassify,
      );
      addTearDown(w.close);
      final ThreadAnalysis a = await w.analyze(_input(
        title: '扫书帖',
        tid: 77,
        floors: <FloorInput>[
          const FloorInput(pid: 7, seq: 1, text: '《隔离书》 作者：隔人 推荐'),
        ],
      ));
      expect(a.kind, PostKind.scan);
      expect(a.hitRules, <String>['iso-fake']);
      expect(a.entries.single.name, '隔离书');
      expect(a.entries.single.author, '隔人');
      // 第二帖复用同一 isolate（BookDict/初始化只做一次的通道验证）
      final ThreadAnalysis b = await w.analyze(_input(
          title: '第二帖',
          tid: 78,
          floors: <FloorInput>[
            const FloorInput(pid: 8, seq: 1, text: '《第二书》好看'),
          ]));
      expect(b.entries.single.name, '第二书');
      await w.close();
      await expectLater(
          w.analyze(_input(title: 'x', floors: <FloorInput>[])),
          throwsA(isA<WorkerException>()));
    });
  });
}
