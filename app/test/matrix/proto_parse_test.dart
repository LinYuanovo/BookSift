// 矩阵补缺：tieba proto 解析层纯函数（lib/collector/tieba/src/parse.dart + models.dart）。
//
// 缺口依据（docs/测试矩阵.md §3）：parse.dart 的碎片分派 / 图片归一化 / 书名抽取
// 此前零直接测试——service_test 走 FakeTiebaApi 免 proto，features_test 只测
// parseFloorSegments（渲染侧分段），拼装层（采集入库前的文本/图片口径）无人守。
// 全部 plain test()、零 IO、零网络（TESTING.md §3.2）。
@Timeout(Duration(minutes: 2))
library;

import 'package:booksift/collector/tieba/src/models.dart';
import 'package:booksift/collector/tieba/src/parse.dart';
import 'package:booksift/collector/tieba/src/proto/PbContent.pb.dart';
import 'package:booksift/collector/tieba/src/proto/User.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

PbContent frag(int type, {String text = '', String link = ''}) =>
    PbContent()
      ..type = type
      ..text = text
      ..link = link;

void main() {
  group('assembleContent 碎片分派（对齐 aiotieba contents.py / §8.6）', () {
    test('文本类 0/9/18/27/40 直接拼接，保序', () {
      final c = assembleContent([
        frag(0, text: '正文'),
        frag(9, text: '13800000000'),
        frag(18, text: '#话题#'),
        frag(27, text: '百科词条'),
        frag(40, text: '梗百科'),
      ]);
      expect(c.text, '正文13800000000#话题#百科词条梗百科');
      expect(c.images, isEmpty);
      expect(c.unknownTypes, isEmpty);
    });

    test('表情 2/11 与 @用户 4 入文本流', () {
      final c = assembleContent([
        frag(2, text: '(滑稽)'),
        frag(11, text: '(阴险)'),
        frag(4, text: '@楼主'),
      ]);
      expect(c.text, '(滑稽)(阴险)@楼主');
    });

    test('链接 1：有锚文本用锚文本，空锚文本回退 URL', () {
      final c = assembleContent([
        frag(1, text: '备份链接', link: 'https://a.b/1'),
        frag(1, link: 'https://a.b/2'),
      ]);
      expect(c.text, '备份链接https://a.b/2');
    });

    test('图片 3/20 进 images 不进文本流', () {
      final c = assembleContent([
        frag(0, text: '图：'),
        PbContent()
          ..type = 3
          ..cdnSrc = 'https://tiebapic.baidu.com/forum/pic/item/0123456789abcdef0123456789abcdef.jpg',
        PbContent()
          ..type = 20
          ..originSrc = 'https://imgsrc.baidu.com/forum/pic/item/fedcba9876543210fedcba9876543210.png',
      ]);
      expect(c.text, '图：');
      expect(c.images, hasLength(2));
      expect(c.images[0].hash, '0123456789abcdef0123456789abcdef');
      expect(c.unknownTypes, isEmpty);
    });

    test('视频 5 / 语音 10 落占位文案', () {
      final c = assembleContent([frag(5), frag(10)]);
      expect(c.text, '[视频][语音]');
    });

    test('广告与过期投票 34/35/36/37/52 静默跳过', () {
      final c = assembleContent([
        frag(0, text: '前'),
        for (final t in [34, 35, 36, 37, 52]) frag(t, text: '广告'),
        frag(0, text: '后'),
      ]);
      expect(c.text, '前后');
      expect(c.unknownTypes, isEmpty);
    });

    test('未知 type 打点进 unknownTypes（新碎片类型预警），文本流不留痕', () {
      final c = assembleContent([frag(0, text: 'ok'), frag(7), frag(99)]);
      expect(c.text, 'ok');
      expect(c.unknownTypes, [7, 99]);
    });
  });

  group('imageFromFrag', () {
    test('urlOriginal 优先 origin>big>cdn；urlPermanent 以 cdn 优先归一化', () {
      final f = PbContent()
        ..type = 3
        ..cdnSrc =
            'https://tiebapic.baidu.com/forum/pic/item/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg?sign=xx'
        ..bigCdnSrc = 'https://big.example/b.jpg'
        ..originSrc = 'https://origin.example/o.jpg';
      final img = imageFromFrag(f);
      expect(img.urlOriginal, 'https://origin.example/o.jpg');
      expect(img.urlPermanent,
          'https://imgsrc.baidu.com/forum/pic/item/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg');
      expect(img.hash, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
    });

    test('bsize "w,h" 有效优先；空/坏值回退 width/height 字段', () {
      final ok = imageFromFrag(PbContent()
        ..type = 3
        ..bsize = '600,800'
        ..width = 1
        ..height = 2);
      expect(ok.width, 600);
      expect(ok.height, 800);

      final fallback = imageFromFrag(PbContent()
        ..type = 3
        ..bsize = 'abc,def'
        ..width = 111
        ..height = 222);
      expect(fallback.width, 111);
      expect(fallback.height, 222);

      final halfBad = imageFromFrag(PbContent()
        ..type = 3
        ..bsize = '640'
        ..height = 480);
      expect(halfBad.width, 640);
      expect(halfBad.height, 480);
    });

    test('三个 src 全空：hash 与两条 URL 均为空串，不抛', () {
      final img = imageFromFrag(PbContent()..type = 3);
      expect(img.urlOriginal, '');
      expect(img.urlPermanent, '');
      expect(img.hash, '');
    });
  });

  group('imageHashFromUrl / normalizeImageUrl', () {
    test('hash 提取：/ 后 32+ 位小写字母数字 + 点号；未命中返回空串', () {
      expect(imageHashFromUrl('https://x.baidu.com/a/b/${'0' * 40}.jpeg'),
          '0' * 40);
      expect(imageHashFromUrl('https://x.baidu.com/short.jpg'), '');
      expect(imageHashFromUrl(''), '');
    });

    test('tiebapic/imgsrc 图床 → imgsrc 永久链，签名参数被剥掉、扩展名保留', () {
      expect(
        normalizeImageUrl(
            'https://tiebapic.baidu.com/forum/pic/item/0123456789abcdef0123456789abcdef.jpg?sign=abc&tbpicau=1'),
        'https://imgsrc.baidu.com/forum/pic/item/0123456789abcdef0123456789abcdef.jpg',
      );
      expect(
        normalizeImageUrl(
            'https://imgsrc.baidu.com/forum/pic/item/0123456789abcdef0123456789abcdef.png'),
        'https://imgsrc.baidu.com/forum/pic/item/0123456789abcdef0123456789abcdef.png',
      );
    });

    test('非图床域名 / 非 hex 文件名 / 空串 / 坏 URI 原样返回', () {
      final other = 'https://example.com/a/${'0' * 32}.jpg';
      expect(normalizeImageUrl(other), other);
      expect(normalizeImageUrl('https://tiebapic.baidu.com/forum/pic/item/中文文件名.jpg'),
          'https://tiebapic.baidu.com/forum/pic/item/中文文件名.jpg');
      expect(normalizeImageUrl(''), '');
      expect(normalizeImageUrl('http://['), 'http://[');
    });
  });

  group('extractBookNames（对齐 collect_poc.py extract_booknames）', () {
    test('保序去重：空白变体视为同名，输出保留首个写法', () {
      expect(
        extractBookNames('《诡秘之主》好看，《诡秘 之主》同上，《剑来》也在'),
        ['诡秘之主', '剑来'],
      );
    });

    test('边界：60 字命中、61 字不命中、空《》跳过、不跨行', () {
      final n60 = 'a' * 60;
      expect(extractBookNames('《$n60》'), [n60]);
      expect(extractBookNames('《${'a' * 61}》'), isEmpty);
      expect(extractBookNames('《》《 》'), isEmpty);
      expect(extractBookNames('《abc\ndef》'), isEmpty);
    });

    test('嵌套《《A》》命中内层', () {
      expect(extractBookNames('《《A》》'), ['A']);
    });
  });

  group('displayName / models 序列化契约', () {
    test('displayName：nameShow 优先，空回退 name', () {
      expect(displayName(User()..id = Int64(1)..name = 'u'..nameShow = 's'), 's');
      expect(displayName(User()..id = Int64(1)..name = 'u'), 'u');
    });

    test('beijingTimeStr：epoch 秒 → 东八区；≤0 返回空串', () {
      expect(beijingTimeStr(1700000000), '2023-11-15 06:13:20');
      expect(beijingTimeStr(0), '');
      expect(beijingTimeStr(-5), '');
    });

    test('ImageInfo.toJson：宽高仅在 >0 时出现；键名契约', () {
      final withSize = ImageInfo(
          urlOriginal: 'o', urlPermanent: 'p', hash: 'h', width: 3, height: 4);
      expect(withSize.toJson().keys,
          ['url_original', 'url_permanent', 'hash', 'width', 'height']);
      final noSize = ImageInfo(urlOriginal: 'o', urlPermanent: 'p', hash: 'h');
      expect(noSize.toJson().keys, ['url_original', 'url_permanent', 'hash']);
    });

    test('FloorInfo/ThreadSummary.toJson 键名契约（机读投影不回退）', () {
      final f = FloorInfo(
        pid: 1,
        seq: 2,
        authorId: 3,
        author: 'a',
        time: 1700000000,
        text: 't',
        images: const [],
      ).toJson();
      expect(
          f.keys,
          [
            'pid', 'seq', 'author_id', 'author', 'time', 'time_str', 'text',
            'images', 'agree_num', 'sub_post_number', 'is_thread_author',
          ]);
      expect(f['time_str'], '2023-11-15 06:13:20');

      final t = ThreadSummary(
        tid: 1,
        title: 'x',
        authorId: 2,
        author: 'a',
        createTime: 0,
        lastTime: 0,
        replyNum: 0,
        viewNum: 0,
        isTop: false,
        isGood: false,
        isDeleted: false,
        isFrsMask: false,
        threadType: 0,
      ).toJson();
      expect(t['create_time_str'], '');
      expect(t.keys, contains('is_frs_mask'));
      expect(t.keys, contains('thread_type'));
    });
  });
}
