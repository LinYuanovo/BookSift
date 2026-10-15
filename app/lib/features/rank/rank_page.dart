import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons.dart';
import '../../core/widgets/scroll_chrome.dart';
import '../../core/window_size.dart';
import '../../data/repo/queries.dart';
import '../../data/repo/queries_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../content/detail_slot.dart';
import '../home/cards.dart';
import '../home/home_page.dart' show rankTodayProvider;

// 独立热门榜页（M2-②）。
//
// 设计稿 09 屏逐块复刻（work/ui_design/claude/index.html:1928–1980）：
// appbar（返回 + 「热门榜」+ badge kind i-flame 当前榜名，点击=切换榜种）→
// 居中 .seg 四时段 → .sec-title scope 文案 → .rank-list Top10
//（rank-no/rank-tx/rank-cnt，index.html:784–806）→ .rank-note（i-db + 数据截至）。
// 榜种切换唯一入口 = appbar badge（真机反馈问题B：底部 btn-outline 切换按钮已移除）。
// 行为规格 = 原型 §5.13：时段锚定 today、切时段/切榜 AnimatedSwitcher + stagger 重放、
// 空态「该时段暂无推荐」+[看看全时段]、行点击 → 书聚合页。
//
// rankTodayProvider 定义留在 features/home/home_page.dart（test/support/harness.dart
// 以该 import 路径注入固定锚点日期，harness 为禁改文件），本页跨文件引用同一 Provider 对象。

/// 榜单种类：推荐次数榜（默认主榜）/ 字数榜（库B子集，§5.13）。
enum RankKind { recommend, word }

/// 热门榜时段（§5.13 分段控件；/rank 页独立状态，首页入口只负责 push）。
final StateProvider<RankWindow> rankWindowProvider = StateProvider<RankWindow>((Ref ref) => RankWindow.allTime);

/// 当前榜单种类（AppBar badge 与 scope 文案随之切换）。
final StateProvider<RankKind> rankKindProvider = StateProvider<RankKind>((Ref ref) => RankKind.recommend);

/// 榜单查询键：时段 × 榜种（record 结构化相等 = family 键）。
typedef RankQuery = ({RankWindow window, RankKind kind});

final rankRowsProvider = FutureProvider.family<List<RankRow>, RankQuery>((Ref ref, RankQuery q) {
  final BookRepository repo = ref.watch(queriesProvider);
  final DateTime today = ref.watch(rankTodayProvider);
  return q.kind == RankKind.recommend
      ? repo.rankRows(q.window, today: today)
      : repo.wordRankRows(q.window, today: today);
});

final FutureProvider<String?> rankCutoffProvider =
    FutureProvider<String?>((Ref ref) => ref.watch(queriesProvider).dataCutoff());

/// 时段 scope 标签（设计稿 JS RANK_SCOPE，index.html:3814：本年/本月带锚点年月）。
String rankScopeLabel(RankWindow window, DateTime today) => switch (window) {
  RankWindow.allTime => '全时段',
  RankWindow.thisYear => '本年 · ${today.year}',
  RankWindow.thisMonth =>
    '本月 · ${today.year}-${today.month.toString().padLeft(2, '0')}',
  RankWindow.last30 => '近30天',
};

/// 字数徽标文案：≥1 万 → 「12 万字」/「1.6 万字」（1 位小数，去尾 .0），否则原值「9999 字」。
String rankWordLabel(int words) {
  if (words < 10000) {
    return '$words 字';
  }
  final String w = (words / 10000).toStringAsFixed(1);
  return '${w.endsWith('.0') ? w.substring(0, w.length - 2) : w} 万字';
}

/// 热门榜页（路由 /rank，vertical SharedAxis 进入，app_router.dart）。
class RankPage extends ConsumerStatefulWidget {
  const RankPage({super.key});

  static const Map<RankWindow, String> _windowLabels = <RankWindow, String>{
    RankWindow.allTime: '全时段',
    RankWindow.thisYear: '本年',
    RankWindow.thisMonth: '本月',
    RankWindow.last30: '近30天',
  };

  @override
  ConsumerState<RankPage> createState() => _RankPageState();
}

class _RankPageState extends ConsumerState<RankPage> {
  /// 主滚动区控制器（与 ScrollChrome 共享同一实例，配对 dispose）。
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 榜种切换（推荐次数榜 ↔ 字数榜；appbar badge 点击，问题B 唯一入口）。
  void _toggleKind() {
    final RankKind kind = ref.read(rankKindProvider);
    ref.read(rankKindProvider.notifier).state =
        kind == RankKind.recommend ? RankKind.word : RankKind.recommend;
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final AppMotionTheme motion = AppMotionTheme.of(context);
    final RankWindow window = ref.watch(rankWindowProvider);
    final RankKind kind = ref.watch(rankKindProvider);
    final DateTime today = ref.watch(rankTodayProvider);
    final RankQuery query = (window: window, kind: kind);
    final AsyncValue<List<RankRow>> async = ref.watch(rankRowsProvider(query));
    final List<RankRow> rows = async.value ?? const <RankRow>[];
    final String? cutoff = ref.watch(rankCutoffProvider).value;
    final String boardName = kind == RankKind.recommend ? '推荐次数榜' : '字数榜';

    return Scaffold(
      appBar: AppBar(
        // 设计稿 appbar：icon-btn i-back（index.html:1940），SVG 图标不走 Material 缺省箭头。
        leading: IconButton(
          tooltip: '返回',
          icon: AppIcon('back', size: 24, color: c.textSecondary),
          onPressed: () => context.pop(),
        ),
        title: const Text('热门榜'),
        actions: <Widget>[
          // badge kind：i-flame + 当前榜名（index.html:1942）；点击 = 切换榜种
          //（真机反馈问题B：唯一切换入口，文案恒显示当前榜名）。
          Padding(
            padding: EdgeInsets.only(right: s.space3),
            child: Center(
              child: _KindBadge(
                label: kind == RankKind.recommend ? '推荐次数' : '字数',
                onTap: _toggleKind,
              ),
            ),
          ),
        ],
      ),
      // 宽屏（medium/expanded）：阅读列 ≤720 居中，不强行多列（window_size.dart 惯例）。
      body: ConstrainedContent(
        child: ScrollChrome(
          controller: _scrollController,
          child: ListView(
            controller: _scrollController,
            // .pad：space-3 顶 / space-5 水平 / space-5 底（index.html:248）。
            padding: EdgeInsets.fromLTRB(s.pagePadding, s.space3, s.pagePadding, s.space5),
            children: <Widget>[
              // 分段控件居中（index.html:1946：flex center + 上 space-2 下 space-4）。
              Padding(
                padding: EdgeInsets.fromLTRB(0, s.space2, 0, s.space4),
                child: Center(
                  child: SegmentedPill<RankWindow>(
                    options: RankWindow.values
                        .map((RankWindow w) => (w, RankPage._windowLabels[w]!))
                        .toList(),
                    selected: window,
                    onChanged: (RankWindow w) =>
                        ref.read(rankWindowProvider.notifier).state = w,
                  ),
                ),
              ),
              // sec-title scope 文案（margin-top:0，index.html:1954）。
              _ScopeTitle(label: '$boardName · ${rankScopeLabel(window, today)} Top10'),
              // 字数榜口径诚实说明（真机反馈问题D）：自采条目 word_count=NULL
              //（无小说字数数据）天然不入榜；匹配到内置库同书后经 MAX(word_count) 继承入榜。
              if (kind == RankKind.word)
                Padding(
                  padding: EdgeInsets.fromLTRB(s.space1, 0, s.space1, s.space3),
                  child: Text(
                    '字数榜仅收录带字数数据的书目；自采书目匹配到内置库同书后自动入榜',
                    style: t.caption.copyWith(color: c.textMuted),
                  ),
                ),
              // 切时段/切榜 = 榜单重排（AnimatedSwitcher crossfade + stagger 重放，§6.4；
              // reduceMotion 由 StaggerPanel/motion token 内部退化）。
              AnimatedSwitcher(
                duration: motion.switch_.duration,
                switchInCurve: motion.switch_.curve,
                switchOutCurve: motion.exit.curve,
                child: _board(context, async, rows, query),
              ),
              if (cutoff != null) _RankNote(cutoff: cutoff),
              SizedBox(height: s.space4),
            ],
          ),
        ),
      ),
    );
  }

  /// 榜单主体三态（骨架 / 空态 / Top10 列表），键随查询切换触发 crossfade。
  Widget _board(
    BuildContext context,
    AsyncValue<List<RankRow>> async,
    List<RankRow> rows,
    RankQuery query,
  ) {
    final AppSpacing s = AppSpacing.of(context);
    if (rows.isEmpty && async.isLoading) {
      return Column(
        key: ValueKey<String>('rank-skeleton-$query'),
        children: <Widget>[
          for (int i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.only(bottom: s.space2),
              child: const SkeletonBlock(height: AppMetrics.rankRowMinHeight),
            ),
        ],
      );
    }
    if (rows.isEmpty) {
      // §5.13 空态：该时段无数据（如自采初期「本月」为空）。
      return AppEmptyState(
        key: ValueKey<String>('rank-empty-$query'),
        title: '该时段暂无推荐',
        message: '自采入库后会实时更新本月/近30天榜单',
        svgIcon: 'flame', // 热门榜空态用设计稿 SVG 线稿（页内零 Material Icon 红线，index.html:1942）
        action: AppButton(
          label: '看看全时段',
          kind: AppButtonKind.outline,
          onPressed: () =>
              ref.read(rankWindowProvider.notifier).state = RankWindow.allTime,
        ),
      );
    }
    return StaggerPanel(
      key: ValueKey<String>('rank-list-$query'),
      spacing: s.space2,
      children: <Widget>[
        for (int i = 0; i < rows.length; i++)
          _RankListRow(row: rows[i], rank: i, kind: query.kind),
      ],
    );
  }
}

/// AppBar 右侧 badge kind（h24 pill · accent-soft 底 · i-flame 12 + 榜名，index.html:284/1942）。
/// 点击 = 切换榜种（问题B：文案恒显示当前榜名，底部切换按钮已移除）。
class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillBorder,
      child: Container(
        height: AppMetrics.badgeHeight,
        padding: const EdgeInsets.symmetric(horizontal: 10), // index.html:277 padding 0 10px
        decoration: BoxDecoration(color: c.accentSoft, borderRadius: AppRadius.pillBorder),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppIcon('flame', size: 12, color: c.accentStrong), // .badge .ic 12px stroke2 → -s 档
            SizedBox(width: s.space1), // index.html:276 gap:4px
            Text(
              label,
              maxLines: 1,
              style: t.label.copyWith(fontWeight: FontWeight.w600, color: c.accentStrong, letterSpacing: 0),
            ),
          ],
        ),
      ),
    );
  }
}

/// sec-title（label 字阶 + 发丝延伸线；09 屏 margin-top:0，index.html:432–437/1954）。
class _ScopeTitle extends StatelessWidget {
  const _ScopeTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(s.space1, 0, s.space1, s.space3),
      child: Row(
        children: <Widget>[
          // Dynamic Type：scope 文案可收缩省略（1.0 缩放取固有宽，视觉不变）。
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.label.copyWith(color: c.textMuted)),
          ),
          SizedBox(width: s.space3),
          Expanded(child: Container(height: AppMetrics.hairline, color: c.border)),
        ],
      ),
    );
  }
}

/// 榜单行（rank-row：r20 · min-h64 · 前 3 名衬线 23 accent-strong 序号 ·
/// rank-cnt 徽标 tabular，index.html:785–805）。
class _RankListRow extends StatelessWidget {
  const _RankListRow({required this.row, required this.rank, required this.kind});

  final RankRow row;

  /// 0-based 名次。
  final int rank;
  final RankKind kind;

  /// rank-cnt 徽标高 30（index.html:802，组件级几何常量，AppMetrics 无对应档位）。
  static const double _cntHeight = 30;

  /// rank-no 序号列宽 30（index.html:794）。
  static const double _noWidth = 30;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final bool top3 = rank < 3;
    final String author = (row.author ?? '').isEmpty ? '作者佚' : row.author!;
    return InkWell(
      key: ValueKey<String>('rank-row-$rank'),
      onTap: () {
        final int? groupId = row.bookGroupId;
        if (groupId != null) {
          openBookDetail(context, groupId); // → push /book/{groupId}（书聚合页，§5.5）
        } else {
          context.push('/search?q=${Uri.encodeComponent(row.nameNorm)}');
        }
      },
      borderRadius: AppRadius.lgBorder,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppMetrics.rankRowMinHeight),
        padding: EdgeInsets.symmetric(horizontal: s.space4, vertical: s.space2),
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: AppRadius.lgBorder,
          border: Border.all(color: c.border, width: AppMetrics.hairline),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: _noWidth,
              child: Text(
                '${rank + 1}',
                key: ValueKey<String>('rank-no-$rank'),
                textAlign: TextAlign.center,
                // 前 3 名：衬线 700 23 accent-strong；其余：衬线 700 17 muted（index.html:793–797）。
                style: AppTypography.tabular(
                  top3
                      ? t.title.copyWith(fontSize: 23, fontWeight: FontWeight.w700, color: c.accentStrong)
                      : t.headline.copyWith(fontSize: 17, fontWeight: FontWeight.w700, color: c.textMuted),
                ),
              ),
            ),
            SizedBox(width: s.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('《${row.name}》', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.cardTitle.copyWith(color: c.text)),
                  Text(author, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption.copyWith(color: c.textMuted)),
                ],
              ),
            ),
            SizedBox(width: s.space3),
            // rank-cnt：h30 pill · accent-soft 底 · 600 13 accent-strong · tabular（index.html:801–805）。
            Container(
              height: _cntHeight,
              padding: EdgeInsets.symmetric(horizontal: s.space3),
              decoration: BoxDecoration(color: c.accentSoft, borderRadius: AppRadius.pillBorder),
              // 居中用 Center(factor 1) 而非 Container.alignment —— 后者在有界约束下膨胀到整宽。
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  kind == RankKind.recommend ? '${row.count} 推' : rankWordLabel(row.count),
                  style: AppTypography.tabular(
                    t.secondary.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: c.accentStrong),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// rank-note：i-db 13 + 「数据截至 {cutoff} · 内置库」（index.html:806/1967，原型 §5.13 口径）。
class _RankNote extends StatelessWidget {
  const _RankNote({required this.cutoff});

  final String cutoff;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    return Padding(
      padding: EdgeInsets.only(top: s.space4),
      child: Row(
        children: <Widget>[
          AppIcon('db', size: 13, color: c.textMuted),
          SizedBox(width: s.space2),
          Expanded(
            child: Text(
              '数据截至 $cutoff · 内置库',
              style: AppTypography.tabular(t.caption.copyWith(color: c.textMuted)),
            ),
          ),
        ],
      ),
    );
  }
}
