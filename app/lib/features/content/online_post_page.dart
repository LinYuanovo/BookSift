import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../collector/collect_providers.dart';
import '../../collector/post_refresh.dart';
import '../../collector/scheduler.dart' show CollectRequestException;
import '../../collector/tieba/src/models.dart' as models;
import '../../core/external_launch.dart';
import '../../core/icons.dart';
import '../../core/widgets/scroll_chrome.dart';
import '../../data/db/app_database.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../home/cards.dart';
import '../search/search_state.dart' show OnlineErrorKind, onlineErrorKindOf;
import 'content_detail_page.dart' show FloorImages;
import 'rich_text.dart';

// 贴吧在线帖详情（任务 3，路由 /online/:id，id = 贴吧主题 tid）：
// 替代旧「复制链接」出站口径——搜索结果点击后直接在本页按时间序渲染楼层。
// 数据只读不落库（在线内容不写本地库）；楼层富文本/图片视图与离线详情页同源复用。

/// 在线帖数据（autoDispose：离页即弃，不缓存线上内容）。
final onlinePostProvider = FutureProvider.autoDispose
    .family<OnlinePostData, int>(
      (Ref ref, int tid) => fetchOnlinePost(ref.watch(tiebaApiProvider), tid),
    );

class OnlinePostPage extends ConsumerStatefulWidget {
  const OnlinePostPage({super.key, required this.tid, this.onClose});

  /// 贴吧主题 id（/online/:id 路径参数）。
  final int tid;

  /// 右槽内嵌形态的关闭回调；null = 走路由返回（窄屏 / 路由页）。
  final VoidCallback? onClose;

  @override
  ConsumerState<OnlinePostPage> createState() => _OnlinePostPageState();
}

class _OnlinePostPageState extends ConsumerState<OnlinePostPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 「打开原帖」（外链单一出口 core/external_launch.dart）：Android 先定向贴吧 App，
  /// 未安装/非 Android 落系统浏览器，都没有则 SnackBar 如实告知——与搜索页在线结果卡
  /// 的同一按钮同口径（旧行为是复制链接，用户还得自己切浏览器粘贴）。
  void _openThread() => openThreadExternallyWithFeedback(
    context,
    'https://tieba.baidu.com/p/${widget.tid}',
  );

  @override
  Widget build(BuildContext context) {
    final AsyncValue<OnlinePostData> async = ref.watch(
      onlinePostProvider(widget.tid),
    );
    // valueOrNull：错误态的 value 会重抛（riverpod 2.6 AsyncError 语义），这里落到错误态分支。
    final String title = async.valueOrNull?.title ?? '';
    return Scaffold(
      appBar: AppBar(
        leading: widget.onClose == null
            ? null
            : IconButton(
                tooltip: '关闭',
                icon: AppIcon(
                  'close',
                  size: 20,
                  color: AppColors.of(context).textSecondary,
                ),
                onPressed: widget.onClose,
              ),
        title: Text(
          title.isNotEmpty ? title : '贴吧在线',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          IconButton(
            tooltip: '打开原帖',
            icon: AppIcon(
              'external',
              size: 20,
              color: AppColors.of(context).textSecondary,
            ),
            onPressed: _openThread,
          ),
        ],
      ),
      body: _body(async),
    );
  }

  Widget _body(AsyncValue<OnlinePostData> async) {
    final OnlinePostData? data = async.valueOrNull;
    if (data != null) {
      return _content(data);
    }
    if (async.isLoading) {
      return _skeleton();
    }
    if (async.hasError) {
      return _errorState(async.error!);
    }
    return const AppEmptyState(
      title: '帖子内容不可用',
      message: '原帖可能已被删除',
      svgIcon: 'book',
    );
  }

  Widget _content(OnlinePostData data) {
    final AppSpacing s = AppSpacing.of(context);
    return ScrollChrome(
      controller: _scrollController,
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          s.pagePadding,
          s.space4,
          s.pagePadding,
          s.space8,
        ),
        children: <Widget>[
          if (data.floors.isEmpty)
            const AppEmptyState(
              title: '帖子没有可显示的楼层',
              message: '原帖可能已被删除',
              svgIcon: 'book',
            ),
          for (final models.FloorInfo f in data.floors) ...<Widget>[
            FloorHeader(seq: f.seq),
            Padding(
              padding: EdgeInsets.only(left: s.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  FloorRichText(
                    text: f.text,
                    // 与离线详情页同一闭环：点《书名》→ 本地库搜索。
                    onBookTap: (String name) =>
                        context.go('/search?q=${Uri.encodeComponent(name)}'),
                  ),
                  if (f.images.isNotEmpty) ...<Widget>[
                    SizedBox(height: s.space2),
                    FloorImages(
                      images: <FloorImage>[
                        for (int i = 0; i < f.images.length; i++)
                          _asViewImage(f.seq, i, f.images[i]),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// ImageInfo → FloorImage 视图行映射（id/floorId 仅为满足数据类形态，无库语义）。
  static FloorImage _asViewImage(int seq, int index, models.ImageInfo img) =>
      FloorImage(
        id: index,
        floorId: seq,
        urlOriginal: img.urlOriginal.isEmpty ? null : img.urlOriginal,
        urlPermanent: img.urlPermanent.isEmpty ? null : img.urlPermanent,
        width: img.width,
        height: img.height,
      );

  Widget _skeleton() {
    final AppSpacing s = AppSpacing.of(context);
    return ListView(
      padding: EdgeInsets.all(s.pagePadding),
      children: <Widget>[
        for (int i = 0; i < 4; i++)
          Padding(
            padding: EdgeInsets.only(bottom: s.space4),
            child: SkeletonBlock(height: i == 0 ? 32 : 72),
          ),
      ],
    );
  }

  /// 在线错误态（文案口径同搜索页 _OnlineErrorState，§8.12 降级矩阵）。
  Widget _errorState(Object error) {
    final OnlineErrorKind kind = switch (error) {
      // proto 通道解析失败 = 接口结构变更信号（FormatException 族）。
      FormatException() => OnlineErrorKind.format,
      CollectRequestException() => onlineErrorKindOf(error),
      _ => OnlineErrorKind.network,
    };
    final String detail = error is CollectRequestException
        ? error.message
        : '$error';
    final (String title, String message, String svgIcon) = switch (kind) {
      OnlineErrorKind.format => (
        '贴吧接口似乎已变更',
        '在线接口返回结构与归档口径不符（$detail）。离线库检索不受影响；请检查 App 更新，或稍后再试。',
        'alert',
      ),
      OnlineErrorKind.rateLimited => (
        '触发贴吧风控',
        '匿名通道被限流（$detail）。请稍后再试，无需登录。',
        'clock',
      ),
      OnlineErrorKind.server => (
        '贴吧服务异常',
        detail.isEmpty ? '请稍后再试' : detail,
        'alert',
      ),
      _ => ('网络异常', '请检查网络连接后重试。', 'wifi'),
    };
    return AppEmptyState(
      title: title,
      message: message,
      svgIcon: svgIcon,
      action: AppButton(
        label: '重试',
        kind: AppButtonKind.outline,
        onPressed: () => ref.invalidate(onlinePostProvider(widget.tid)),
      ),
    );
  }
}
