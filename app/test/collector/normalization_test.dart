/// 归一化四函数与 merge_etl.py 的口径向量断言（§8.7：同键空间保证）。
///
/// 全部期望值由 CPython 3.12 对 work/unified/merge_etl.py:59-92 同源实现
/// 实算后写死（2026-10-13，探针脚本输出见完成报告）——手算期望值口径。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/collector/normalization.dart';

void main() {
  group('normName（merge_etl.norm_name）', () {
    test('剥《》包裹', () {
      expect(normName('《雪中悍刀行》'), '雪中悍刀行');
      expect(normName('《道诡异仙》'), '道诡异仙');
    });
    test('NFKC 全角→半角 + 去空白 + 去标点 + 小写', () {
      expect(normName(' Ａ级－猎人　'), 'a级猎人');
      expect(normName('［＃１］凡人修仙传'), '#1凡人修仙传');
    });
    test('「」【】等包裹符同样剥离（PUNCT_RE 覆盖）', () {
      expect(normName('「剑来」'), '剑来');
      expect(normName('【括号名】'), '括号名');
    });
    test('空串', () {
      expect(normName(''), '');
    });
  });

  group('normPerson（merge_etl.norm_person）', () {
    test('去空白 + 小写，保留符号', () {
      expect(normPerson(' 烽火戏诸侯 '), '烽火戏诸侯');
      expect(normPerson('狐尾的笔'), '狐尾的笔');
      expect(normPerson('Ｎｉｃｋ'), 'nick');
    });
    test('NULLISH 占位归空', () {
      expect(normPerson('无'), '');
      expect(normPerson('——'), '');
      expect(normPerson('n/a'), '');
    });
  });

  group('normText（merge_etl.norm_text）', () {
    test('NFKC → 去空白 → 去标点 → 小写', () {
      expect(normText('这是一段，推荐语！'), '这是一段推荐语');
      expect(normText(' ＡＢＣ　１２３ '), 'abc123');
      expect(normText('《书》好看——真的！'), '书好看真的');
      expect(normText(''), '');
    });
  });

  group('h16 / content_hash（merge_etl.h16 与 book_entry.content_hash）', () {
    test('h16 = sha1 前 16 hex', () {
      expect(h16('abc'), 'a9993e364706816a');
      expect(h16(normText('天不生我李淳罡，剑道万古如长夜。')),
          'f2b9c4179412437f');
    });
    test('content_hash = sha1(name_norm 0x1f author_norm 0x1f comment_norm_hash)[:16]',
        () {
      expect(
        entryContentHash(
          nameNorm: normName('《雪中悍刀行》'),
          authorNorm: normPerson('烽火戏诸侯'),
          commentNormHash: h16(normText('天不生我李淳罡，剑道万古如长夜。')),
        ),
        '5e5b42b187fa6690',
      );
    });
    test('作者缺省按空串参与拼接（Python COALESCE 口径）', () {
      final String cch = h16(normText('坐而论道'));
      expect(
        entryContentHash(
            nameNorm: normName('《道诡异仙》'), authorNorm: '', commentNormHash: cch),
        '63c5847568b0ad64',
      );
    });
    test('按帖口径：postRef 追加 0x1f + post_ref 参与拼接（问题C）', () {
      final String n = normName('《雪中悍刀行》');
      final String a = normPerson('烽火戏诸侯');
      final String cch = h16(normText('天不生我李淳罡，剑道万古如长夜。'));
      expect(
        entryContentHash(nameNorm: n, authorNorm: a, commentNormHash: cch, postRef: 42),
        h16('$n\u001f$a\u001f$cch\u001f42'),
      );
      // 不同 postRef → hash 互异（跨帖各记一条）；同 postRef → 恒定（同帖幂等）。
      expect(
        entryContentHash(nameNorm: n, authorNorm: a, commentNormHash: cch, postRef: 42),
        entryContentHash(nameNorm: n, authorNorm: a, commentNormHash: cch, postRef: 42),
      );
      expect(
        entryContentHash(nameNorm: n, authorNorm: a, commentNormHash: cch, postRef: 42),
        isNot(entryContentHash(nameNorm: n, authorNorm: a, commentNormHash: cch, postRef: 43)),
      );
      // postRef 缺省 = 旧三参口径不变（种子导入路径沿用，上方向量 5e5b… 即此口径）。
      expect(
        entryContentHash(nameNorm: n, authorNorm: a, commentNormHash: cch),
        '5e5b42b187fa6690',
      );
    });
  });
}
