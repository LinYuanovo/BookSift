/// 纯数据模型：与 pb 生成类解耦，便于 JSON 序列化与单测。
library;

class ImageInfo {
  ImageInfo({
    required this.urlOriginal,
    required this.urlPermanent,
    required this.hash,
    this.width = 0,
    this.height = 0,
  });

  final String urlOriginal;
  final String urlPermanent;
  final String hash;
  final int width;
  final int height;

  Map<String, dynamic> toJson() => {
        'url_original': urlOriginal,
        'url_permanent': urlPermanent,
        'hash': hash,
        if (width > 0) 'width': width,
        if (height > 0) 'height': height,
      };
}

class FloorInfo {
  FloorInfo({
    required this.pid,
    required this.seq,
    required this.authorId,
    required this.author,
    required this.time,
    required this.text,
    required this.images,
    this.agreeNum = 0,
    this.subPostNumber = 0,
    this.isThreadAuthor = false,
  });

  final int pid;
  final int seq;
  final int authorId;
  final String author;
  final int time;
  final String text;
  final List<ImageInfo> images;
  final int agreeNum;
  final int subPostNumber;
  final bool isThreadAuthor;

  Map<String, dynamic> toJson() => {
        'pid': pid,
        'seq': seq,
        'author_id': authorId,
        'author': author,
        'time': time,
        'time_str': beijingTimeStr(time),
        'text': text,
        'images': images.map((e) => e.toJson()).toList(),
        'agree_num': agreeNum,
        'sub_post_number': subPostNumber,
        'is_thread_author': isThreadAuthor,
      };
}

class ThreadSummary {
  ThreadSummary({
    required this.tid,
    required this.title,
    required this.authorId,
    required this.author,
    required this.createTime,
    required this.lastTime,
    required this.replyNum,
    required this.viewNum,
    required this.isTop,
    required this.isGood,
    required this.isDeleted,
    required this.isFrsMask,
    required this.threadType,
  });

  final int tid;
  final String title;
  final int authorId;
  final String author;
  final int createTime;
  final int lastTime;
  final int replyNum;
  final int viewNum;
  final bool isTop;
  final bool isGood;
  final bool isDeleted;
  final bool isFrsMask;
  final int threadType;

  Map<String, dynamic> toJson() => {
        'tid': tid,
        'title': title,
        'author_id': authorId,
        'author': author,
        'create_time': createTime,
        'create_time_str': beijingTimeStr(createTime),
        'last_time': lastTime,
        'reply_num': replyNum,
        'view_num': viewNum,
        'is_top': isTop,
        'is_good': isGood,
        'is_deleted': isDeleted,
        'is_frs_mask': isFrsMask,
        'thread_type': threadType,
      };
}

class PostDetail {
  PostDetail({
    required this.tid,
    required this.title,
    required this.authorId,
    required this.author,
    required this.createTime,
    required this.replyNum,
    required this.floors,
    required this.bookNames,
    this.partial = false,
    this.fetchError = '',
  });

  final int tid;
  final String title;
  final int authorId;
  final String author;
  final int createTime;
  final int replyNum;
  final List<FloorInfo> floors;
  final List<String> bookNames;
  final bool partial;
  final String fetchError;

  int get imageCount => floors.fold(0, (s, f) => s + f.images.length);

  Map<String, dynamic> toJson() => {
        'tid': tid,
        'title': title,
        'author_id': authorId,
        'author': author,
        'create_time': createTime,
        'create_time_str': beijingTimeStr(createTime),
        'reply_num': replyNum,
        'floor_count': floors.length,
        'image_count': imageCount,
        'book_names': bookNames,
        'partial': partial,
        if (fetchError.isNotEmpty) 'fetch_error': fetchError,
        'floors': floors.map((e) => e.toJson()).toList(),
      };
}

class ForumMeta {
  ForumMeta({
    required this.fid,
    required this.name,
    required this.memberNum,
    required this.threadNum,
  });

  final int fid;
  final String name;
  final int memberNum;
  final int threadNum;

  Map<String, dynamic> toJson() => {
        'fid': fid,
        'name': name,
        'member_num': memberNum,
        'thread_num': threadNum,
      };
}

/// epoch 秒 → 北京时间字符串（贴吧时间戳为东八区，对齐 Python PoC date_raw 口径）
String beijingTimeStr(int epochSec) {
  if (epochSec <= 0) return '';
  final dt = DateTime.fromMillisecondsSinceEpoch(epochSec * 1000, isUtc: true)
      .add(const Duration(hours: 8));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${dt.year.toString().padLeft(4, '0')}-${two(dt.month)}-${two(dt.day)} '
      '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
}
