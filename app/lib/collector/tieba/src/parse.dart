/// PbContent 碎片拼装 + 图片归一化 + 书名抽取（纯函数，无 IO）。
/// 分派规则对齐 aiotieba api/_classdef/contents.py 与原型文档 §8.6。
library;

import 'models.dart';
import 'proto/PbContent.pb.dart';
import 'proto/User.pb.dart';

final RegExp _imageHashExp = RegExp(r'/([a-z0-9]{32,})\.');
final RegExp _bookNameExp = RegExp(r'《([^《》\n]{1,60})》');
final RegExp _picFileExp = RegExp(r'^([a-f0-9]{32,40})(\.[a-zA-Z0-9]+)?$');

class AssembledContent {
  AssembledContent(this.text, this.images, this.unknownTypes);

  final String text;
  final List<ImageInfo> images;

  /// 未知碎片 type 打点（新碎片类型预警，原型文档 §8.6）
  final List<int> unknownTypes;
}

AssembledContent assembleContent(Iterable<PbContent> frags) {
  final buf = StringBuffer();
  final images = <ImageInfo>[];
  final unknown = <int>[];
  for (final f in frags) {
    switch (f.type) {
      // 0纯文本 9电话号 18话题 27百科词条 40梗百科
      case 0:
      case 9:
      case 18:
      case 27:
      case 40:
        buf.write(f.text);
      // 2/11 表情（text 形如 "(滑稽)"）
      case 2:
      case 11:
        buf.write(f.text);
      // 4 @用户（text 含 @昵称）
      case 4:
        buf.write(f.text);
      // 1 链接：拼锚文本，无锚文本回退 URL
      case 1:
        buf.write(f.text.isNotEmpty ? f.text : f.link);
      // 3/20 图片
      case 3:
      case 20:
        images.add(imageFromFrag(f));
      case 5:
        buf.write('[视频]');
      case 10:
        buf.write('[语音]');
      // 34/35/36/37 tiebaplus 广告、52 outdated vote：跳过不入库
      case 34:
      case 35:
      case 36:
      case 37:
      case 52:
        break;
      default:
        unknown.add(f.type);
    }
  }
  return AssembledContent(buf.toString(), images, unknown);
}

ImageInfo imageFromFrag(PbContent f) {
  final cdn = f.cdnSrc;
  final big = f.bigCdnSrc;
  final origin = f.originSrc;
  final urlOriginal = _firstNonEmpty([origin, big, cdn]);
  final permanent = normalizeImageUrl(_firstNonEmpty([cdn, big, origin]));
  final parts = f.bsize.split(',');
  final w = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
  final h = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return ImageInfo(
    urlOriginal: urlOriginal,
    urlPermanent: permanent,
    hash: imageHashFromUrl(cdn),
    width: w > 0 ? w : f.width,
    height: h > 0 ? h : f.height,
  );
}

String _firstNonEmpty(List<String> values) {
  for (final v in values) {
    if (v.isNotEmpty) return v;
  }
  return '';
}

/// 百度图床 hash：从 cdn src 提取 `/([a-z0-9]{32,})\.`（aiotieba contents.py _IMAGEHASH_EXP）
String imageHashFromUrl(String url) => _imageHashExp.firstMatch(url)?.group(1) ?? '';

/// 永久链归一化（原型文档 §5.7/§8.6）：tiebapic/imgsrc 域名 → 提取 path 末段
/// 32–40 位 hex 文件名（**含扩展名**）→ https://imgsrc.baidu.com/forum/pic/item/{file}{ext}；
/// 签名参数（sign=/tbpicau=）会过期，非贴吧图床域名原样返回。
/// 扩展名必须保留：丢 `.jpg` 的永久链实测 404，带扩展名才 200（真机「图片已失效」根因之一）。
String normalizeImageUrl(String url) {
  if (url.isEmpty) return url;
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final host = uri.host;
  if (!host.endsWith('tiebapic.baidu.com') && !host.endsWith('imgsrc.baidu.com')) {
    return url;
  }
  final seg = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
  final m = _picFileExp.firstMatch(seg);
  if (m == null) return url;
  return 'https://imgsrc.baidu.com/forum/pic/item/${m.group(1)}${m.group(2) ?? ''}';
}

/// 《》内书名抽取，保序去重（对齐 collect_poc.py extract_booknames）
List<String> extractBookNames(String text) {
  final seen = <String>{};
  final out = <String>[];
  for (final m in _bookNameExp.allMatches(text)) {
    final name = (m.group(1) ?? '').trim();
    if (name.isEmpty) continue;
    final key = name.replaceAll(RegExp(r'\s+'), '');
    if (key.isEmpty || !seen.add(key)) continue;
    out.add(name);
  }
  return out;
}

/// 显示名 = name_show 非空优先，否则 name（get_threads/_classdef.py:294）
String displayName(User u) => u.nameShow.isNotEmpty ? u.nameShow : u.name;
