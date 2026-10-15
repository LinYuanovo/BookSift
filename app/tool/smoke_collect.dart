/// 真实网络冒烟（M2-① 可选加分项）：≤4 个请求验证采集管线端到端。
///
/// **环境变量门控**：`SMOKE=1` 才会发起真实请求，否则直接跳过（exit 0）。
/// 合规（AGENTS.md §6 / §8.11）：仅 get_threads yy小说吧 1 页 + 最新 1 帖楼层
/// （≤2 页），请求间隔 ≥1.5s（TiebaClient 内置抖动），**严禁大规模抓取**。
///
/// 运行（sqlite3.dll 需在 PATH，anaconda Library\bin 有）：
/// ```powershell
/// $env:SMOKE='1'
/// $env:PATH = "C:\ProgramData\anaconda3\Library\bin;$env:PATH"
/// & C:\flutter\bin\dart.bat run tool/smoke_collect.dart
/// ```
///
/// **诚实标注**：lib/classify 的 v3 分类器真实现由并行任务落地中，本冒烟用
/// 标题关键词粗分类（_naiveClassify）代替，仅验证通道+解析+入库管线，
/// 不代表 §8.9 分类质量。
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:booksift/classify/classifier.dart';
import 'package:booksift/collector/ingest.dart';
import 'package:booksift/collector/tieba/src/models.dart';
import 'package:booksift/collector/tieba_api.dart';
import 'package:booksift/collector/worker.dart';
import 'package:booksift/data/db/app_database.dart';

const String kForum = 'yy小说吧';
const int kMaxRequests = 4; // 1 threads + ≤2 posts 页 + 1 冗余上限

/// 冒烟专用粗分类（真 v3 未落地；见库注释）。
ClassifyResult _naiveClassify({
  required String title,
  required String firstFloor,
  required String fullText,
  required List<String> booknames,
}) {
  if (RegExp(r'排雷|避雷|踩雷|扫雷|慎入|剧毒|粪作').hasMatch(title)) {
    return ClassifyResult(
        kind: PostKind.mine,
        flag: kindFlag[PostKind.mine]!,
        hitRules: const <String>['smoke-naive-mine'],
        booknames: booknames);
  }
  if (RegExp(r'求书|书荒|求推荐|跪求').hasMatch(title)) {
    return ClassifyResult(
        kind: PostKind.seek,
        flag: kindFlag[PostKind.seek]!,
        hitRules: const <String>['smoke-naive-seek'],
        booknames: booknames);
  }
  if (RegExp(r'^(水贴|闲聊|日常)').hasMatch(title)) {
    return ClassifyResult(
        kind: null,
        flag: 0,
        hitRules: const <String>['smoke-naive-chat'],
        booknames: booknames);
  }
  return ClassifyResult(
      kind: PostKind.scan,
      flag: kindFlag[PostKind.scan]!,
      hitRules: const <String>['smoke-naive-scan'],
      booknames: booknames);
}

Future<void> main() async {
  if (Platform.environment['SMOKE'] != '1') {
    stdout.writeln('SMOKE != 1，跳过真实网络冒烟（零请求）。');
    return;
  }
  stdout.writeln('== M2-① 采集冒烟（≤$kMaxRequests 请求，间隔≥1.5s）==');
  final ProtoTiebaApi api = ProtoTiebaApi.withOwnThrottle();
  final AppDatabase db = AppDatabase(NativeDatabase.memory());
  int requests = 0;
  int exitCode = 0;
  try {
    // ① 主题列表 1 页
    final ThreadsPage page = await api.getThreads(kForum, pn: 1, rn: 30);
    requests++;
    stdout.writeln('[frs] fid=${page.fid} 本页 ${page.threads.length} 条 '
        'hasMore=${page.hasMore}');
    if (page.threads.isEmpty) {
      stdout.writeln('[frs] 空页，无法冒烟（网络或接口变更？）');
      exitCode = 2;
      return;
    }
    // 最新一个可采候选（排除置顶/删除/屏蔽）
    final List<ThreadSummary> candidates = page.threads
        .where((ThreadSummary t) => !t.isTop && !t.isDeleted && !t.isFrsMask)
        .toList()
      ..sort((ThreadSummary a, ThreadSummary b) =>
          b.createTime.compareTo(a.createTime));
    final ThreadSummary picked = candidates.first;
    stdout.writeln('[pick] tid=${picked.tid} 《${picked.title}》 '
        'create=${beijingTimeStr(picked.createTime)} 回复=${picked.replyNum}');

    // ② 该楼层（≤2 页）
    final List<FloorInfo> floors = <FloorInfo>[];
    final Set<int> seenPid = <int>{};
    String title = picked.title;
    String author = picked.author;
    String authorUserName = '';
    int authorId = picked.authorId;
    int createTime = picked.createTime;
    bool partial = false;
    for (int pn = 1; pn <= 2 && requests < kMaxRequests; pn++) {
      final PostsPage pp = await api.getPosts(picked.tid, pn: pn, rn: 30);
      requests++;
      if (pp.title.isNotEmpty) title = pp.title;
      if (pp.author.isNotEmpty) author = pp.author;
      if (pp.authorUserName.isNotEmpty) authorUserName = pp.authorUserName;
      if (pp.authorId != 0) authorId = pp.authorId;
      if (pp.createTime != 0) createTime = pp.createTime;
      for (final FloorInfo f in pp.floors) {
        if (f.pid == 0 || seenPid.add(f.pid)) floors.add(f);
      }
      if (!pp.hasMore) break;
      if (pn == 2) partial = true;
    }
    stdout.writeln('[pb] 楼层=${floors.length} partial=$partial');

    // ③ 分析 + 入内存库
    final ThreadRecord rec = ThreadRecord(
      fname: kForum,
      tid: picked.tid,
      title: title,
      authorId: authorId,
      author: author,
      authorUserName: authorUserName,
      createTime: createTime,
      floors: floors,
      partial: partial,
    );
    final LocalPostWorker worker = LocalPostWorker(_naiveClassify);
    final ThreadAnalysis analysis = await worker.analyze(ThreadInput(
      tid: rec.tid,
      title: rec.title,
      author: rec.author,
      createTime: rec.createTime,
      floors: <FloorInput>[
        for (final FloorInfo f in rec.floors)
          FloorInput(pid: f.pid, seq: f.seq, text: f.text),
      ],
    ));
    stdout.writeln('[classify] kind=${analysis.kind ?? "日常(丢弃)"} '
        'flag=${analysis.flag} 书名数=${analysis.booknames.length} '
        '规则=${analysis.hitRules.join(";")}');
    final IngestResult r = await IngestPipeline(db)
        .ingestThread(rec, analysis, collectedAt: DateTime.now());
    stdout.writeln('[ingest] newPost=${r.newPost} +${r.floorsAdded}楼 '
        '+${r.imagesAdded}图 +${r.entriesAdded}书目 dup=${r.skippedDup}');

    // ④ 字段完整率
    final int posts = await db.posts.count().getSingle();
    final int floorRows = await db.floors.count().getSingle();
    final int imageRows = await db.images.count().getSingle();
    final int entryRows = await db.bookEntries.count().getSingle();
    final int groupRows = await db.bookGroups.count().getSingle();
    final int floorsWithContent = floors
        .where((FloorInfo f) => f.text.trim().isNotEmpty || f.images.isNotEmpty)
        .length;
    final List<ImageInfo> allImages =
        floors.expand((FloorInfo f) => f.images).toList();
    final int imagesNormalized = allImages
        .where((ImageInfo i) =>
            i.urlPermanent.startsWith('https://imgsrc.baidu.com/forum/pic/item/'))
        .length;
    String rate(int ok, int n) =>
        n == 0 ? 'n/a' : '${(ok / n * 100).toStringAsFixed(1)}%';
    stdout.writeln('[rows] posts=$posts floors=$floorRows images=$imageRows '
        'entries=$entryRows groups=$groupRows');
    stdout.writeln('[完整率] 主题title=${rate(title.trim().isNotEmpty ? 1 : 0, 1)} '
        'author=${rate(author.trim().isNotEmpty ? 1 : 0, 1)} '
        'create_time=${rate(createTime > 1600000000 && createTime < 2000000000 ? 1 : 0, 1)} '
        '楼层有内容=${rate(floorsWithContent, floors.length)} '
        '图片永久链=${rate(imagesNormalized, allImages.length)}');

    // ⑤ 风控计数（验收口径：全零 = 零风控）
    final Map<String, dynamic> risk = api.risk.toJson();
    stdout.writeln('[risk] $risk');
    if (api.risk.totalAnomalies > 0) exitCode = 2;
  } catch (e, st) {
    stdout.writeln('[smoke] 异常：$e\n$st');
    exitCode = 2;
  } finally {
    stdout.writeln('[smoke] 请求总数=$requests（上限 $kMaxRequests）');
    api.close();
    await db.close();
  }
  exit(exitCode);
}
