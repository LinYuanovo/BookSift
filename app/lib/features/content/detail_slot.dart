import 'package:animations/animations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/nav/center_slot.dart';
import '../../data/db/app_database.dart';
import '../../data/repo/queries.dart';
import '../../data/repo/queries_providers.dart';
import 'book_detail_page.dart';

// 详情页接线（M1-④）：compact/medium 走 push 路由；expanded 在 AppShell 双栏右槽
// （app_shell.dart _DetailSlot）原位切换（设计系统 §9.7 list-detail 语义）。

/// 帖子详情打开参数（路由 extra 与 expanded 右槽共用载荷）。
class PostSelection {
  const PostSelection({
    required this.postId,
    this.siblings = const <int>[],
    this.position = 0,
    this.snapshot,
    this.highlight,
    this.initialFloorSeq,
    this.initialFloorId,
  });

  final int postId;

  /// 当前结果集内帖 id 序列（上一帖/下一帖 PageView，§5.6）。
  final List<int> siblings;

  /// 结果列表位置（书签快照，§5.6）。
  final int position;

  /// 六维搜索条件快照（书签用；无搜索上下文时 null）。
  final SearchFilter? snapshot;

  /// 书签恢复的楼层定位（任务 1：进入详情后跳到该楼；null = 从头阅读）。
  final int? initialFloorSeq;

  /// 楼层精确定位锚点（floors.id，库内唯一）：多书帖（「大佬贴吧扫书」每卡片一记）
  /// 里同一帖的不同书目所在楼层 seq 全为 1，只靠 [initialFloorSeq] 会跳到首个同 seq 楼层
  /// —— 点某本书进帖却停在别的书那一楼。书聚合评价卡携带自身 floor_ref 走本字段。
  final int? initialFloorId;

  /// 搜索词高亮（结果页/书签进入时携带，§5.6 渲染管线 4）。
  final String? highlight;

  /// 帖 id 序列（无 siblings 时退化为单帖）。
  List<int> get ids => siblings.isEmpty ? <int>[postId] : siblings;

  int get initialIndex {
    final int i = ids.indexOf(postId);
    return i < 0 ? 0 : i;
  }
}

/// 书聚合页打开参数。
class BookNavArgs {
  const BookNavArgs({
    this.snapshot,
    this.highlight,
    this.initialFilter = SemanticFilter.all,
  });

  final SearchFilter? snapshot;
  final String? highlight;
  final SemanticFilter initialFilter;
}

/// expanded 右槽当前选中（null = 空态，app_shell.dart _DetailSlot 消费）。
final StateProvider<PostSelection?> detailSelectionProvider =
    StateProvider<PostSelection?>((Ref ref) => null);

/// expanded 右槽当前选中的贴吧在线帖（tid；null = 未选）。
/// 与 [detailSelectionProvider] 互斥：打开一类详情会清空另一类。
final StateProvider<int?> onlinePostDetailProvider =
    StateProvider<int?>((Ref ref) => null);

/// 打开帖子详情：expanded（三栏）→ 右槽原位切换；否则 push（§9.7）。
///
/// 判据用「中间功能区在场」而不是老的 `!context.canPop()`：中间栈压着页面（如在线帖）
/// 时 canPop 也为真，老判据会把详情盖成整窗页、把中间功能区挤掉。
void openPostDetail(
  BuildContext context,
  WidgetRef ref,
  PostSelection selection,
) {
  if (centerSlotMounted()) {
    ref.read(onlinePostDetailProvider.notifier).state = null;
    ref.read(detailSelectionProvider.notifier).state = selection;
    return;
  }
  context.push('/post/${selection.postId}', extra: selection);
}

/// 打开贴吧在线帖：expanded（三栏）→ 最右侧详情槽原位显示；否则 push /online/:tid。
void openOnlinePostDetail(BuildContext context, int tid) {
  if (centerSlotMounted()) {
    final ProviderContainer container = ProviderScope.containerOf(context, listen: false);
    container.read(detailSelectionProvider.notifier).state = null;
    container.read(onlinePostDetailProvider.notifier).state = tid;
    return;
  }
  context.push('/online/$tid');
}

/// 打开书聚合页（§5.5：书卡进入走 horizontal 共享轴）。
///
/// 用户口径：expanded 三栏下书聚合页不盖住整窗，直接显示在**中间功能区**
/// （core/nav/center_slot.dart）；compact/medium 无中间栏，等价于原全窗 push。
void openBookDetail(
  BuildContext context,
  int bookGroupId, {
  SearchFilter? snapshot,
  String? highlight,
  SemanticFilter initialFilter = SemanticFilter.all,
}) {
  final BookNavArgs args = BookNavArgs(
    snapshot: snapshot,
    highlight: highlight,
    initialFilter: initialFilter,
  );
  openCenterPage(
    context,
    BookDetailPage(bookGroupId: bookGroupId, args: args),
    type: SharedAxisTransitionType.horizontal,
    // 窄屏保持原路由（/book/:id + extra）语义。
    fullScreen: () => context.push('/book/$bookGroupId', extra: args),
  );
}

/// 书签流（详情页操作条状态 + 我的页共用，§9.2 bookmarksProvider）。
final StreamProvider<List<Bookmark>> bookmarksProvider =
    StreamProvider<List<Bookmark>>(
      (Ref ref) => ref.watch(queriesProvider).watchBookmarks(),
    );

/// 收藏流（书/帖双粒度，§9.2 favoritesProvider）。
final StreamProvider<List<Favorite>> favoritesProvider =
    StreamProvider<List<Favorite>>(
      (Ref ref) => ref.watch(queriesProvider).watchFavorites(),
    );
