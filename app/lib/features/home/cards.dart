import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../data/repo/queries.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

// 共享展示组件（M1-④）：语义徽标/色条卡/书名 chip/计数对比/分段控件/空态/stagger。
// 规格出处：设计系统 v1.3 §4 组件规格；色值/圆角/间距/动效全走 token（§5.2/§6.2 治理）。

/// 语义色调（§5.2：推荐绿 / 排雷红 / 求书灰弱标记 / 中性不标）。
enum SemanticTone { recommend, avoid, ask, neutral }

/// 条目/帖 → 语义色调（flag 与 category 联合判定，§8.9）。
SemanticTone toneOf({required int flag, String? category}) {
  if (flag == 1) {
    return SemanticTone.recommend;
  }
  if (flag == -1) {
    return SemanticTone.avoid;
  }
  if (category == CategoryKind.ask) {
    return SemanticTone.ask;
  }
  return SemanticTone.neutral;
}

/// 语义色条颜色（卡片左 3px）。
Color barColorOf(BuildContext context, SemanticTone tone) {
  final AppColors c = AppColors.of(context);
  return switch (tone) {
    SemanticTone.recommend => c.recommend,
    SemanticTone.avoid => c.danger,
    SemanticTone.ask => c.borderStrong,
    SemanticTone.neutral => c.border,
  };
}

/// 推荐/排雷/求书徽标（badge h24 pill；MI-5 pop-in：instant+spring，比卡片晚一拍）。
class SemanticBadge extends StatelessWidget {
  const SemanticBadge({super.key, required this.tone, this.animate = true});

  final SemanticTone tone;
  final bool animate;

  static String labelOf(SemanticTone tone) => switch (tone) {
    SemanticTone.recommend => '推荐',
    SemanticTone.avoid => '排雷',
    SemanticTone.ask => '求书',
    SemanticTone.neutral => '',
  };

  @override
  Widget build(BuildContext context) {
    if (tone == SemanticTone.neutral) {
      return const SizedBox.shrink();
    }
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final (Color bg, Color fg, IconData? icon) = switch (tone) {
      SemanticTone.recommend => (c.recommendSoft, c.recommend, Icons.check_rounded),
      SemanticTone.avoid => (c.dangerSoft, c.danger, Icons.warning_amber_rounded),
      SemanticTone.ask => (c.surfaceSunken, c.textMuted, null),
      SemanticTone.neutral => (c.surfaceSunken, c.textMuted, null),
    };
    final Widget badge = Container(
      height: AppMetrics.badgeHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.pillBorder),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 13, color: fg),
            SizedBox(width: AppSpacing.of(context).space1 / 2),
          ],
          Text(labelOf(tone), style: t.label.copyWith(fontWeight: FontWeight.w600, color: fg, letterSpacing: 0)),
        ],
      ),
    );
    if (!animate) {
      return badge;
    }
    // MI-5：scale 0.8→1.0 + fade，延迟一拍（staggerDelay）弹出。
    // pop.curve 是 spring 近似（Cubic(0.34,1.4,0.64,1)，easeOutBack 变体），**值会过冲到 >1**：
    // scale 保留过冲（正是弹现手感），opacity 必须 clamp —— Opacity 断言 0≤opacity≤1。
    final AppMotionTheme motion = AppMotionTheme.of(context);
    final Duration delay = motion.staggerDelay;
    final Duration total = motion.pop.duration + delay;
    final double begin = total == Duration.zero ? 0 : delay.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: total,
      curve: Interval(begin, 1, curve: motion.pop.curve),
      builder: (BuildContext context, double v, Widget? child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.8 + 0.2 * v, child: child),
      ),
      child: badge,
    );
  }
}

/// origin 徽标（§5.2：内置灰 / 自采绿 / 导入蓝）。
///
/// 种子导入行 origin='seed'（[Origin.seed]）与 'builtin' 同归「内置」灰档 —— 走 `_` 缺省臂。
class OriginBadge extends StatelessWidget {
  const OriginBadge({super.key, required this.origin});

  final String origin;

  static String labelOf(String origin) => switch (origin) {
    Origin.collected => '自采',
    Origin.imported => '导入',
    _ => '内置',
  };

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final (Color bg, Color fg) = switch (origin) {
      Origin.collected => (c.recommendSoft, c.recommend),
      Origin.imported => (c.infoSoft, c.info),
      _ => (c.surfaceSunken, c.textMuted),
    };
    return Container(
      height: AppMetrics.badgeHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.pillBorder),
      child: Text(labelOf(origin), style: t.label.copyWith(fontWeight: FontWeight.w600, color: fg, letterSpacing: 0)),
    );
  }
}

/// 中性 meta-chip（渠道/日期/+n，h24 pill sunken）。
class MetaChip extends StatelessWidget {
  const MetaChip({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillBorder,
      child: Container(
        height: AppMetrics.badgeHeight,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: AppRadius.pillBorder),
        alignment: Alignment.center,
        child: Text(label, style: t.caption.copyWith(color: c.textSecondary)),
      ),
    );
  }
}

/// 书名 chip（h32 pill · 衬线 bookname · 8% 染底；点击=以书名发起搜索，长按=复制）。
class BookNameChip extends StatelessWidget {
  const BookNameChip({super.key, required this.name, this.onTap, this.onLongPress, this.big = false});

  /// 书名（不含《》；渲染时补全）。
  final String name;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool big;

  static String stripBrackets(String name) => name.replaceAll('《', '').replaceAll('》', '').trim();

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: AppRadius.pillBorder,
      child: Container(
        height: big ? AppMetrics.bookChipHeightBig : AppMetrics.bookChipHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: c.bookname.withValues(alpha: 0.08),
          borderRadius: AppRadius.pillBorder,
        ),
        alignment: Alignment.center,
        child: Text(
          '《${stripBrackets(name)}》',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.cardTitle.copyWith(color: c.bookname),
        ),
      ),
    );
  }
}

/// 左 3px 语义色条内容卡（r20 · 1px border · raised · padding 20，无阴影）。
class AccentCard extends StatelessWidget {
  const AccentCard({super.key, required this.tone, required this.child, this.onTap, this.onLongPress});

  final SemanticTone tone;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final AppSpacing s = AppSpacing.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(width: 3, color: barColorOf(context, tone)),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(s.space4, s.cardPadding, s.cardPadding, s.cardPadding),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 首页时间线卡片（§5.2：徽标+标题+摘要+书名 chips+来源 meta+origin+日期）。
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.data,
    required this.onTap,
    this.onLongPress,
    required this.onBookTap,
    this.onChannelTap,
  });

  final PostCardData data;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<String> onBookTap;
  final ValueChanged<String>? onChannelTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final post = data.post;
    final SemanticTone tone = toneOf(flag: post.recommendFlag, category: post.postKind);
    final String title = (post.title?.isNotEmpty ?? false)
        ? post.title!
        : (data.books.isNotEmpty ? '《${BookNameChip.stripBrackets(data.books.first.name)}》' : '无题');
    return AccentCard(
      tone: tone,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SemanticBadge(tone: tone),
              SizedBox(width: s.space2),
              Expanded(
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.cardTitle.copyWith(color: c.text)),
              ),
            ],
          ),
          if (data.summary != null) ...<Widget>[
            SizedBox(height: s.space2),
            Text(
              data.summary!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.secondary.copyWith(color: c.textSecondary),
            ),
          ],
          if (data.books.isNotEmpty) ...<Widget>[
            SizedBox(height: s.space3),
            Wrap(
              spacing: s.space2,
              runSpacing: s.space2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                for (final BookChip chip in data.books)
                  BookNameChip(name: chip.name, onTap: () => onBookTap(BookNameChip.stripBrackets(chip.name))),
                if (data.entryCount > data.books.length) MetaChip(label: '+${data.entryCount - data.books.length}'),
              ],
            ),
          ],
          SizedBox(height: s.space3),
          Row(
            children: <Widget>[
              if ((post.author ?? '').isNotEmpty) ...<Widget>[
                Flexible(
                  child: Text(post.author!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption.copyWith(color: c.textMuted)),
                ),
                SizedBox(width: s.space2),
              ],
              MetaChip(label: post.channel, onTap: onChannelTap == null ? null : () => onChannelTap!(post.channel)),
              SizedBox(width: s.space2),
              OriginBadge(origin: post.origin),
              const Spacer(),
              Text(
                post.date ?? '',
                style: AppTypography.tabular(t.caption.copyWith(color: c.textMuted)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 书级条目卡（分类预览/随机书荒/书聚合评价卡通用；§5.12 复用 §5.2 卡片规格）。
class BookEntryCard extends StatefulWidget {
  const BookEntryCard({
    super.key,
    required this.entry,
    this.onTap,
    this.onBookTap,
    this.onRecommenderTap,
    this.onSourceTap,
    this.showRecommender = false,
    this.expandableComment = false,
    this.commentMaxCollapsed = 200,
  });

  final EntryRow entry;
  final VoidCallback? onTap;

  /// 点《书名》→ 以书名搜索（§5 通用规范）。
  final ValueChanged<String>? onBookTap;

  /// 点推荐人 → 以推荐人搜索（§5.5）。
  final ValueChanged<String>? onRecommenderTap;

  /// 点「原帖↗」（§5.5：有帖溯源进详情，否则外链复制）。
  final VoidCallback? onSourceTap;
  final bool showRecommender;
  final bool expandableComment;
  final int commentMaxCollapsed;

  @override
  State<BookEntryCard> createState() => _BookEntryCardState();
}

class _BookEntryCardState extends State<BookEntryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final EntryRow e = widget.entry;
    final SemanticTone tone = toneOf(flag: e.recommendFlag, category: e.category);
    final String comment = e.comment ?? '';
    final bool collapsible = widget.expandableComment && comment.length > widget.commentMaxCollapsed;
    final String shown = (collapsible && !_expanded) ? comment : comment;

    Widget? commentBlock;
    if (shown.isNotEmpty) {
      commentBlock = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            shown,
            maxLines: (collapsible && !_expanded) ? 3 : null,
            overflow: (collapsible && !_expanded) ? TextOverflow.ellipsis : null,
            style: t.secondary.copyWith(
              color: tone == SemanticTone.avoid ? c.danger : c.textSecondary, // 排雷摘要砖红（设计系统 §3 #04）
            ),
          ),
          if (collapsible)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: EdgeInsets.only(top: s.space1),
                child: Text(
                  _expanded ? '收起' : '展开全文',
                  style: t.caption.copyWith(color: c.accentStrong, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      );
    }

    return AccentCard(
      tone: tone,
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SemanticBadge(tone: tone),
              SizedBox(width: s.space2),
              Expanded(
                child: GestureDetector(
                  onTap: widget.onBookTap == null ? null : () => widget.onBookTap!(BookNameChip.stripBrackets(e.name)),
                  child: Text(
                    '《${BookNameChip.stripBrackets(e.name)}》',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.cardTitle.copyWith(color: c.bookname),
                  ),
                ),
              ),
              if ((e.date ?? '').isNotEmpty)
                Text(e.date!, style: AppTypography.tabular(t.caption.copyWith(color: c.textMuted))),
            ],
          ),
          if ((e.author ?? '').isNotEmpty) ...<Widget>[
            SizedBox(height: s.space1),
            Text(e.author!, style: t.secondary.copyWith(color: c.textSecondary)),
          ],
          if (commentBlock != null) ...<Widget>[SizedBox(height: s.space2), commentBlock],
          SizedBox(height: s.space3),
          Row(
            children: <Widget>[
              if (widget.showRecommender && (e.recommender ?? '').isNotEmpty) ...<Widget>[
                GestureDetector(
                  onTap: widget.onRecommenderTap == null ? null : () => widget.onRecommenderTap!(e.recommender!),
                  child: Text(
                    e.recommender!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.caption.copyWith(color: c.accentStrong, fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(width: s.space2),
              ],
              MetaChip(label: e.channel),
              SizedBox(width: s.space2),
              OriginBadge(origin: e.origin),
              const Spacer(),
              if (widget.onSourceTap != null)
                GestureDetector(
                  onTap: widget.onSourceTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('原帖', style: t.caption.copyWith(color: c.info)),
                      Icon(Icons.north_east_rounded, size: 13, color: c.info),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 计数对比胶囊「推荐 n ｜ 排雷 m」（count-duo，点击=语义筛选，§5.5/设计系统 §3 #03）。
class CountDuo extends StatelessWidget {
  const CountDuo({super.key, required this.recommend, required this.avoid, this.onRecommendTap, this.onAvoidTap});

  final int recommend;
  final int avoid;
  final VoidCallback? onRecommendTap;
  final VoidCallback? onAvoidTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    Widget half(String label, int n, Color fg, VoidCallback? onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillBorder,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: s.space3, vertical: s.space1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.circle, size: 8, color: fg),
              SizedBox(width: s.space1),
              Text(label, style: t.caption.copyWith(color: fg)),
              SizedBox(width: s.space1),
              Text('$n', style: AppTypography.tabular(t.bodyStrong.copyWith(color: fg))),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: c.border, width: AppMetrics.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          half('推荐', recommend, c.recommend, onRecommendTap),
          Container(width: AppMetrics.hairline, height: 20, color: c.border),
          half('排雷', avoid, c.danger, onAvoidTap),
        ],
      ),
    );
  }
}

/// 分段控件（sunken 容器 pill + 选中 raised；热门榜 4 档时段 / 书聚合语义筛选，§4）。
class SegmentedPill<T> extends StatelessWidget {
  const SegmentedPill({super.key, required this.options, required this.selected, required this.onChanged});

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppMotionTheme motion = AppMotionTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surfaceSunken,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: c.border, width: AppMetrics.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final (T value, String label) in options)
            InkWell(
              onTap: () => onChanged(value),
              borderRadius: AppRadius.pillBorder,
              child: AnimatedContainer(
                duration: motion.switch_.duration,
                curve: motion.switch_.curve,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: value == selected ? c.surfaceRaised : c.surfaceSunken.withValues(alpha: 0),
                  borderRadius: AppRadius.pillBorder,
                ),
                child: Text(
                  label,
                  style: t.caption.copyWith(
                    color: value == selected ? c.text : c.textMuted,
                    fontWeight: value == selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 维度值 chip（compact h36 · pill · 值名 + 真实命中计数 `.ct` tabular；选中珊瑚高亮，§4）。
class CountChip extends StatelessWidget {
  const CountChip({
    super.key,
    required this.label,
    this.count,
    required this.selected,
    this.onTap,
    this.dangerTint = false,
    this.compact = true,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback? onTap;

  /// 「分类·排雷」红染（设计系统 §3 #02）。
  final bool dangerTint;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final Color bg = selected
        ? (dangerTint ? c.dangerSoft : c.accentSoft)
        : c.surfaceSunken;
    final Color fg = selected ? (dangerTint ? c.danger : c.accentStrong) : c.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillBorder,
      child: Container(
        height: compact ? AppMetrics.chipHeightCompact : AppMetrics.chipHeight,
        padding: EdgeInsets.symmetric(horizontal: s.space3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(
            color: selected ? (dangerTint ? c.danger : c.accent) : c.surfaceSunken.withValues(alpha: 0),
            width: AppMetrics.hairline,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.secondary.copyWith(color: fg, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
              ),
            ),
            if (count != null) ...<Widget>[
              SizedBox(width: s.space1),
              Text(
                '${count! >= 10000 ? '${(count! / 1000).round()}k' : count!}',
                style: AppTypography.tabular(
                  t.label.copyWith(color: selected ? fg : c.textMuted, letterSpacing: 0),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// `[高亮]` 标记摘要渲染（FTS snippet / LIKE 兜底同约定；琥珀荧光笔心智，§5.4）。
class HighlightText extends StatelessWidget {
  const HighlightText({super.key, required this.text, required this.style, this.maxLines});

  final String text;
  final TextStyle style;
  final int? maxLines;

  static final RegExp _marker = RegExp(r'\[([^\[\]]*)\]');

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final Paint bg = Paint()..color = c.highlight;
    final List<InlineSpan> spans = <InlineSpan>[];
    int cursor = 0;
    for (final RegExpMatch m in _marker.allMatches(text)) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start)));
      }
      spans.add(TextSpan(text: m.group(1), style: style.copyWith(background: bg)));
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}

/// 分区标题（label + 发丝延伸线 + 可选尾部动作）。
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    return Padding(
      padding: EdgeInsets.only(top: s.sectionGap, bottom: s.space3),
      child: Row(
        children: <Widget>[
          Text(label, style: t.label.copyWith(color: c.textMuted)),
          SizedBox(width: s.space3),
          Expanded(child: Container(height: AppMetrics.hairline, color: c.border)),
          if (trailing != null) ...<Widget>[SizedBox(width: s.space3), trailing!],
        ],
      ),
    );
  }
}

/// 主按钮（primary=ink 底 / accent=珊瑚底 / outline=1px border-strong，h48 r14，§4）。
enum AppButtonKind { primary, accent, outline }

class AppButton extends StatelessWidget {
  const AppButton({super.key, required this.label, this.onPressed, this.kind = AppButtonKind.primary, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final (Color bg, Color fg, BoxBorder? border) = switch (kind) {
      AppButtonKind.primary => (c.ink, c.onInk, null),
      AppButtonKind.accent => (c.accent, c.onAccent, null),
      AppButtonKind.outline => (c.surfaceRaised, c.text, Border.all(color: c.borderStrong, width: AppMetrics.hairline)),
    };
    final bool enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: bg,
        borderRadius: AppRadius.mdBorder,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.mdBorder,
          child: Container(
            height: AppMetrics.buttonHeight,
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.of(context).buttonPaddingH),
            decoration: BoxDecoration(borderRadius: AppRadius.mdBorder, border: border),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
                Text(label, style: t.bodyStrong.copyWith(color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 骨架块（sunken r10；扫光动画省略——静态块防测试 pumpAndSettle 悬挂，§6.4 降级实现）。
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({super.key, this.height = 16, this.width = double.infinity});

  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(color: AppColors.of(context).surfaceSunken, borderRadius: AppRadius.smBorder),
    );
  }
}

/// 空态（线稿 accent 64px + headline + caption + 可选动作，§4）。
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({super.key, required this.title, this.message, this.icon = Icons.auto_stories_outlined, this.action});

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: s.emptyStatePaddingV, horizontal: s.emptyStatePaddingH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: AppMetrics.emptyStateIconSize, color: c.accent),
          SizedBox(height: s.space4),
          Text(title, textAlign: TextAlign.center, style: t.headline.copyWith(color: c.text)),
          if (message != null) ...<Widget>[
            SizedBox(height: s.space2),
            Text(message!, textAlign: TextAlign.center, style: t.secondary.copyWith(color: c.textMuted)),
          ],
          if (action != null) ...<Widget>[SizedBox(height: s.space5), action!],
        ],
      ),
    );
  }
}

/// 首屏 cascade 面板（§6.4/§6.6：单控制器 + Interval 分段，fade + 8dp 上移，上限前 8 项）。
///
/// 内容替换（如热门榜切时段）以 [switchKey] 换键重放；reduceMotion 退化纯 opacity。
/// [wrap]=true 时以 Wrap 排布（手风琴值 chips，MI-8 组内 stagger）。
class StaggerPanel extends StatefulWidget {
  const StaggerPanel({super.key, required this.children, this.switchKey, this.spacing = 0, this.wrap = false, this.runSpacing = 0});

  final List<Widget> children;
  final Key? switchKey;
  final double spacing;
  final bool wrap;
  final double runSpacing;

  @override
  State<StaggerPanel> createState() => StaggerPanelState();
}

class StaggerPanelState extends State<StaggerPanel> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 总时长取自 AppMotionTheme（要 context），必须在 forward() 之前落定：
    // AnimationController.forward() 在 duration 为 null 时直接断言抛错。
    final AppMotionTheme motion = AppMotionTheme.of(context);
    _controller.duration = motion.enter.duration + motion.staggerAt(7);
    if (!_started) {
      _started = true;
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(StaggerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.switchKey != oldWidget.switchKey) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppMotionTheme motion = AppMotionTheme.of(context);
    final Duration total = motion.enter.duration + motion.staggerAt(7);
    if (_controller.duration != total) {
      _controller.duration = total;
    }
    final List<Widget> items = <Widget>[];
    // reduceMotion 退化：禁位移，仅保留 opacity 淡入（§6.1/§6.8）。
    final double amplitude = motion.reduceMotion ? 0 : 8;
    for (int i = 0; i < widget.children.length; i++) {
      if (i >= 8 || total == Duration.zero) {
        items.add(widget.children[i]);
        continue;
      }
      final double begin = motion.staggerAt(i).inMicroseconds / total.inMicroseconds;
      final Animation<double> anim = CurvedAnimation(
        parent: _controller,
        curve: Interval(begin, 1, curve: motion.enter.curve),
      );
      items.add(AnimatedBuilder(
        animation: anim,
        builder: (BuildContext context, Widget? child) {
          final double v = anim.value;
          return Opacity(
            opacity: v,
            child: Transform.translate(offset: Offset(0, amplitude * (1 - v)), child: child),
          );
        },
        child: widget.children[i],
      ));
    }
    if (widget.wrap) {
      return Wrap(
        key: widget.switchKey,
        spacing: widget.spacing,
        runSpacing: widget.runSpacing,
        children: items,
      );
    }
    return Column(
      key: widget.switchKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < items.length; i++) ...<Widget>[
          if (i > 0 && widget.spacing > 0) SizedBox(height: widget.spacing),
          items[i],
        ],
      ],
    );
  }
}

/// 列表项级 stagger（懒加载 ListView 用：前 8 项入场动画 + keep-alive 防滚动回看重放）。
class StaggerItem extends StatefulWidget {
  const StaggerItem({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<StaggerItem> createState() => _StaggerItemState();
}

class _StaggerItemState extends State<StaggerItem> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  bool _started = false;

  @override
  bool get wantKeepAlive => widget.index < 8;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 同 StaggerPanelState：duration 必须先于 forward() 落定，否则断言抛错。
    final AppMotionTheme motion = AppMotionTheme.of(context);
    _controller.duration = motion.enter.duration + motion.staggerAt(widget.index);
    if (!_started) {
      _started = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final AppMotionTheme motion = AppMotionTheme.of(context);
    if (widget.index >= 8) {
      // 8 项之后随列表立即呈现，避免长列表尾部闪烁（§6.4）。
      return widget.child;
    }
    final Duration delay = motion.staggerAt(widget.index);
    final Duration total = motion.enter.duration + delay;
    if (_controller.duration != total) {
      _controller.duration = total;
    }
    final double begin = total == Duration.zero ? 0 : delay.inMicroseconds / total.inMicroseconds;
    final Animation<double> anim = CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, 1, curve: motion.enter.curve),
    );
    // reduceMotion 退化：禁位移，仅保留 ≤100ms opacity 淡入（§6.1/§6.8）。
    final double amplitude = motion.reduceMotion ? 0 : 8;
    return AnimatedBuilder(
      animation: anim,
      builder: (BuildContext context, Widget? child) {
        final double v = anim.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, amplitude * (1 - v)), child: child),
        );
      },
      child: widget.child,
    );
  }
}
