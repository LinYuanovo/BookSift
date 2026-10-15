import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/icons.dart';
import '../../data/db/app_database.dart';
import '../../data/repo/queries.dart';
import '../../data/repo/queries_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../content/detail_slot.dart';
import '../export/booklist_export.dart';
import '../export/export_sheet.dart';
import '../home/cards.dart';
import '../search/search_state.dart';
import '../share/share_card.dart';
import '../share/share_sheet.dart';

// 我的页（原型 §5.10）：书签夹 / 收藏夹 / 搜索历史 三段实时列表 + 设置 / 关于入口。
//
// 三个列表都直接吃 BookRepository 的 watch 流（书签含六维快照、收藏双粒度、历史去重），
// 写入即刷新；行点击 = 恢复条件或打开对应详情（§5.10「点击=完整恢复六维快照」）。
// 左滑删除走同一套 toggle/CRUD 接口，不引入第二套写路径。

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  void _showAbout(BuildContext context) {
    final AppTypography t = AppTypography.of(context);
    final AppColors c = AppColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.of(context).pagePadding,
            0,
            AppSpacing.of(context).pagePadding,
            AppSpacing.of(context).space8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                AppConstants.appName,
                style: t.headline.copyWith(color: c.text),
              ),
              SizedBox(height: AppSpacing.of(context).space3),
              Text(
                '数据来源：百度贴吧公开「扫书帖」的离线整理，书目与推荐语版权归原作者与发帖人所有。'
                '本应用默认仅做本地检索与阅读，在线采集与在线搜索均由您手动发起；'
                '接口与合规详情见 设置 → 关于与合规。',
                style: t.secondary.copyWith(color: c.textSecondary),
              ),
              SizedBox(height: AppSpacing.of(context).space3),
              Text(
                '离线本地库 · 不上传任何数据',
                style: t.caption.copyWith(color: c.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSpacing s = AppSpacing.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          s.pagePadding,
          s.space4,
          s.pagePadding,
          s.space8,
        ),
        children: <Widget>[
          const _BookmarksSection(),
          SizedBox(height: s.space6),
          const _FavoritesSection(),
          SizedBox(height: s.space6),
          const _HistorySection(),
          // 工具区（原型 §5.10「我的→工具」/ §5.11 文字转图自由模式：手动输入或粘贴文本）。
          SectionTitle(label: '工具'),
          Card(
            child: ListTile(
              leading: AppIcon(
                'share',
                size: 20,
                color: AppColors.of(context).textSecondary,
              ),
              title: Text('文字转图', style: t(context).bodyStrong),
              subtitle: Text(
                '把书名、推荐语或排雷文渲染成可分享的卡片图片',
                style: t(context).caption,
              ),
              trailing: RotatedBox(
                quarterTurns: 3,
                child: AppIcon('chev', size: 16),
              ),
              onTap: () => showShareSheet(
                context,
                const ShareCardSpec(),
                freeMode: true,
              ),
            ),
          ),
          SizedBox(height: s.space6),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: AppIcon(
                    'gear',
                    size: 20,
                    color: AppColors.of(context).textSecondary,
                  ),
                  title: Text('设置', style: t(context).bodyStrong),
                  trailing: RotatedBox(
                    quarterTurns: 3,
                    child: AppIcon('chev', size: 16),
                  ),
                  onTap: () => context.push('/settings'),
                ),
                const Divider(height: AppMetrics.hairline, indent: 56),
                ListTile(
                  leading: AppIcon(
                    'info',
                    size: 20,
                    color: AppColors.of(context).textSecondary,
                  ),
                  title: Text('关于', style: t(context).bodyStrong),
                  trailing: RotatedBox(
                    quarterTurns: 3,
                    child: AppIcon('chev', size: 16),
                  ),
                  onTap: () => _showAbout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static AppTypography t(BuildContext context) => AppTypography.of(context);
}

/// 段头（label + 计数 + 可选尾部动作），复用 SectionTitle 的发丝延伸线语汇。
class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.label, required this.count, this.trailing});

  final String label;
  final int count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SectionTitle(label: '$label $count', trailing: trailing);
  }
}

/// 书签夹（§5.10：点击 = 完整恢复六维快照；左滑 = 删除）。
class _BookmarksSection extends ConsumerWidget {
  const _BookmarksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final List<Bookmark> rows =
        ref.watch(bookmarksProvider).value ?? const <Bookmark>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHead(label: '书签夹', count: rows.length),
        if (rows.isEmpty)
          const AppEmptyState(
            title: '还没有书签',
            message: '在帖子详情底部点「书签」即可留存当前搜索条件快照',
            svgIcon: 'bookmark',
          ),
        for (final Bookmark b in rows)
          Dismissible(
            key: ValueKey<String>('bm-${b.id}'),
            direction: DismissDirection.endToStart,
            onDismissed: (_) {
              if (b.postRef != null) {
                ref
                    .read(queriesProvider)
                    .togglePostBookmark(postRef: b.postRef!, title: b.title);
              }
            },
            background: _dismissBg(context),
            child: InkWell(
              onTap: () => _restore(context, ref, b),
              borderRadius: AppRadius.mdBorder,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: s.space3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '「${b.title}」',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyStrong.copyWith(color: c.text),
                    ),
                    SizedBox(height: s.space1),
                    Text(
                      <String>[
                        if ((b.author ?? '').isNotEmpty) b.author!,
                        if ((b.channel ?? '').isNotEmpty) b.channel!,
                        '第 ${b.position + 1} 条',
                        // 任务 1：有楼层记忆的书签在副标题带出（schema v3 floor_seq）。
                        if (b.floorSeq != null) '${b.floorSeq}楼',
                      ].join(' · '),
                      style: t.caption.copyWith(color: c.textMuted),
                    ),
                    // 快照摘要：有则显示（§5.10 线框「快照: 无限流·2024·11月·上旬·扫书」）。
                    if (_snapshotOf(b).isNotEmpty) ...<Widget>[
                      SizedBox(height: s.space1),
                      Text(
                        '快照: ${_snapshotOf(b)}',
                        style: t.caption.copyWith(color: c.accentStrong),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _snapshotOf(Bookmark b) => SearchFilter(
    query: b.snapQuery ?? '',
    year: b.snapYear,
    month: b.snapMonth,
    tenDay: b.snapTenDay,
    channel: b.snapChannel,
    category: b.snapCategory,
  ).describe();

  void _restore(BuildContext context, WidgetRef ref, Bookmark b) {
    final SearchFilter f = SearchFilter(
      query: b.snapQuery ?? '',
      year: b.snapYear,
      month: b.snapMonth,
      tenDay: b.snapTenDay,
      channel: b.snapChannel,
      category: b.snapCategory,
      sort: SearchSort.fromWire(b.snapSort),
    );
    // 任务 1：指向帖子的书签恢复 = 打开帖子详情并定位到记录时的阅读楼层
    // （floor_seq，旧书签为 null → 从头阅读）；搜索条件快照随行（再收藏/高亮语义不变）。
    if (b.postRef != null) {
      openPostDetail(
        context,
        ref,
        PostSelection(
          postId: b.postRef!,
          position: b.position,
          snapshot: f,
          initialFloorSeq: b.floorSeq,
        ),
      );
      return;
    }
    context.go(
      Uri(
        path: '/search',
        queryParameters: <String, String>{...f.toUriParams(), 'browse': '1'},
      ).toString(),
    );
  }
}

/// 收藏夹（§5.10：书 / 帖子双粒度；点击 = 打开对应详情；左滑 = 取消收藏）。
class _FavoritesSection extends ConsumerWidget {
  const _FavoritesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final List<Favorite> rows =
        ref.watch(favoritesProvider).value ?? const <Favorite>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHead(
          label: '收藏夹',
          count: rows.length,
          trailing: rows.isEmpty ? null : _ExportFavoritesButton(rows: rows),
        ),
        if (rows.isEmpty)
          const AppEmptyState(
            title: '还没有收藏',
            message: '书聚合页右上角星标、帖子详情「收藏」、时间线长按菜单都能加',
            svgIcon: 'star',
          ),
        for (final Favorite f in rows)
          Dismissible(
            key: ValueKey<String>('fav-${f.id}'),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => ref
                .read(queriesProvider)
                .toggleFavorite(
                  targetType: f.targetType,
                  targetId: f.targetId,
                  title: f.title,
                ),
            background: _dismissBg(context),
            child: InkWell(
              onTap: () {
                if (f.targetType == FavoriteTarget.bookGroup) {
                  openBookDetail(context, f.targetId);
                } else if (f.targetType == FavoriteTarget.post) {
                  openPostDetail(
                    context,
                    ref,
                    PostSelection(postId: f.targetId),
                  );
                }
              },
              borderRadius: AppRadius.mdBorder,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: s.space3),
                child: Row(
                  children: <Widget>[
                    // 收藏行图标：书聚合 → i-book，帖子 → i-list（楼层流语义）。
                    // 尺寸取 .ic sm 16 档（图标档位 24/20/16/13；与下方历史行 clock 16 同档）。
                    AppIcon(
                      f.targetType == FavoriteTarget.bookGroup
                          ? 'book'
                          : 'list',
                      size: 16,
                      color: c.accent,
                    ),
                    SizedBox(width: s.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            f.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.body.copyWith(color: c.text),
                          ),
                          if ((f.subtitle ?? '').isNotEmpty)
                            Text(
                              f.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.caption.copyWith(color: c.textMuted),
                            ),
                        ],
                      ),
                    ),
                    MetaChip(
                      label: f.targetType == FavoriteTarget.bookGroup
                          ? '书'
                          : '帖子',
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 收藏夹导出入口（原型 §3.1 P2-4「导出书单 Markdown/TXT」）：
/// 汇总全部收藏（书粒度经 bookDetail/bookEntries 补全，帖粒度经 postDetail）→ 导出弹层。
class _ExportFavoritesButton extends ConsumerWidget {
  const _ExportFavoritesButton({required this.rows});

  final List<Favorite> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    return IconButton(
      tooltip: '导出书单',
      visualDensity: VisualDensity.compact,
      icon: AppIcon('external', size: 16, color: c.textSecondary),
      onPressed: () async {
        final BookRepository repo = ref.read(queriesProvider);
        final BooklistDoc doc = await buildFavoritesDoc(
          repo: repo,
          favorites: rows,
        );
        if (!context.mounted) {
          return;
        }
        showBooklistExportSheet(context, doc);
      },
    );
  }
}

/// 搜索历史（§5.3/§5.10：点击复现六维、左滑删除、清空全部）。
class _HistorySection extends ConsumerWidget {
  const _HistorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final List<SearchHistoryEntry> rows =
        ref.watch(searchHistoryProvider).value ?? const <SearchHistoryEntry>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHead(
          label: '搜索历史',
          count: rows.length,
          trailing: rows.isEmpty
              ? null
              : TextButton(
                  onPressed: () => ref.read(queriesProvider).clearHistory(),
                  child: Text(
                    '清空',
                    style: t.caption.copyWith(color: c.textMuted),
                  ),
                ),
        ),
        if (rows.isEmpty)
          const AppEmptyState(
            title: '暂无搜索历史',
            message: '在搜索台提交一次条件即会留存六维快照',
            svgIcon: 'clock',
          ),
        for (final SearchHistoryEntry h in rows)
          Dismissible(
            key: ValueKey<String>('his-${h.id}'),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => ref.read(queriesProvider).deleteHistory(h.id),
            background: _dismissBg(context),
            child: InkWell(
              onTap: () => context.go(
                Uri(
                  path: '/search',
                  queryParameters: <String, String>{
                    ...SearchFilter.fromHistory(h).toUriParams(),
                    'browse': '1',
                  },
                ).toString(),
              ),
              borderRadius: AppRadius.mdBorder,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: s.space3),
                child: Row(
                  children: <Widget>[
                    // 搜索历史行 = 设计稿 i-clock（index.html:1309/2649；与搜索台历史行同款）。
                    AppIcon('clock', size: 16, color: c.textMuted),
                    SizedBox(width: s.space3),
                    Expanded(
                      child: Text(
                        SearchFilter.fromHistory(h).describe(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.body.copyWith(color: c.text),
                      ),
                    ),
                    SizedBox(width: s.space2),
                    Text(
                      '${h.searchedAt.month.toString().padLeft(2, '0')}-${h.searchedAt.day.toString().padLeft(2, '0')}',
                      style: AppTypography.tabular(
                        t.caption.copyWith(color: c.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 左滑删除背景（danger-soft 底 + 删除图标，与搜索页历史行同族）。
Widget _dismissBg(BuildContext context) {
  final AppColors c = AppColors.of(context);
  return Container(
    alignment: Alignment.centerRight,
    padding: EdgeInsets.only(right: AppSpacing.of(context).space5),
    decoration: BoxDecoration(
      color: c.dangerSoft,
      borderRadius: AppRadius.mdBorder,
    ),
    // 无 trash 资产；破坏性动作 = close 染 danger（24 导航档，与搜索台历史行左滑同款）。
    child: AppIcon('close', size: 24, color: c.danger),
  );
}
