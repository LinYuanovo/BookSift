import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/window_size.dart';
import '../../data/db/app_database.dart';
import '../../data/repo/queries.dart';

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
  });

  final int postId;

  /// 当前结果集内帖 id 序列（上一帖/下一帖 PageView，§5.6）。
  final List<int> siblings;

  /// 结果列表位置（书签快照，§5.6）。
  final int position;

  /// 六维搜索条件快照（书签用；无搜索上下文时 null）。
  final SearchFilter? snapshot;

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
  const BookNavArgs({this.snapshot, this.highlight, this.initialFilter = SemanticFilter.all});

  final SearchFilter? snapshot;
  final String? highlight;
  final SemanticFilter initialFilter;
}

/// expanded 右槽当前选中（null = 空态，app_shell.dart _DetailSlot 消费）。
final StateProvider<PostSelection?> detailSelectionProvider = StateProvider<PostSelection?>((Ref ref) => null);

/// 打开帖子详情：expanded 且在 shell 根部 → 右槽原位切换；否则 push（§9.7）。
void openPostDetail(BuildContext context, WidgetRef ref, PostSelection selection) {
  if (WindowSize.of(context) == WindowSizeClass.expanded && !context.canPop()) {
    ref.read(detailSelectionProvider.notifier).state = selection;
    return;
  }
  context.push('/post/${selection.postId}', extra: selection);
}

/// 打开书聚合页（§5.5：书卡进入走 horizontal 共享轴，push 语义三档一致）。
void openBookDetail(
  BuildContext context,
  int bookGroupId, {
  SearchFilter? snapshot,
  String? highlight,
  SemanticFilter initialFilter = SemanticFilter.all,
}) {
  context.push('/book/$bookGroupId',
      extra: BookNavArgs(snapshot: snapshot, highlight: highlight, initialFilter: initialFilter));
}

/// 书签流（详情页操作条状态 + 我的页共用，§9.2 bookmarksProvider）。
final StreamProvider<List<Bookmark>> bookmarksProvider =
    StreamProvider<List<Bookmark>>((Ref ref) => ref.watch(queriesProvider).watchBookmarks());

/// 收藏流（书/帖双粒度，§9.2 favoritesProvider）。
final StreamProvider<List<Favorite>> favoritesProvider =
    StreamProvider<List<Favorite>>((Ref ref) => ref.watch(queriesProvider).watchFavorites());
