import 'package:flutter/material.dart';

import '../../classify/src/engine.dart' show kRecommendKind;
import '../../core/constants.dart';
import '../../core/icons.dart';
import '../../data/repo/queries.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

// 共享展示组件（M1-④）：语义徽标/色条卡/书名 chip/计数对比/分段控件/空态/stagger。
// 规格出处：设计系统 v1.3 §4 组件规格；色值/圆角/间距/动效全走 token（§5.2/§6.2 治理）。

/// 按**字符**（rune）截断到最多 [max] 个，超出补「…」。
///
/// 用于推荐人（扫书作者名）显示上限 6 字：按 runes 切才不会把代理对（emoji/生僻字）
/// 劈成半个；行内另有 ellipsis 兜底（字阶放大/窄屏时按可用宽再收）。
String _capRunes(String text, int max) {
  final List<int> runes = text.runes.toList();
  return runes.length > max ? '${String.fromCharCodes(runes.take(max))}…' : text;
}

/// 语义色调（§5.2：推荐绿 / 排雷红 / 求书灰弱标记 / 扫书中性灰 / 中性不标）。
enum SemanticTone { recommend, avoid, ask, scan, neutral }

/// 条目/帖 → 语义色调（flag 与 category 联合判定，§8.9）。
///
/// flag==0 时再按类别分档：扫书条目只是「被扫到」、没有原帖背书颜色（entryFlagOf 口径），
/// 给一枚中性灰「扫书」徽标把话说清楚，好过什么都不标（读者会以为漏标）。
SemanticTone toneOf({required int flag, String? category}) {
  if (flag == 1) {
    return SemanticTone.recommend;
  }
  if (flag == -1) {
    return SemanticTone.avoid;
  }
  if (category == CategoryKind.scan) {
    return SemanticTone.scan;
  }
  if (category == CategoryKind.ask) {
    return SemanticTone.ask;
  }
  return SemanticTone.neutral;
}

/// 条目三分类型 → 语义色调（推书档走推荐绿「推荐」徽标；与计数同源，见 EntryRow.kindLabel）。
SemanticTone toneOfEntry(EntryRow e) => switch (e.kindLabel) {
  kRecommendKind => SemanticTone.recommend,
  CategoryKind.avoid => SemanticTone.avoid,
  CategoryKind.ask => SemanticTone.ask,
  _ => SemanticTone.scan,
};

/// 帖子级语义色调（post_kind 单判，不看 posts.recommend_flag）。
///
/// 帖子没有条目那样的「原帖背书颜色」——recommend_flag 只是 post_kind 的派生存列
/// （classifier.dart：扫书+1 / 排雷−1 / 求书 0），拿它判推荐会让全部扫书帖挂绿标，
/// 与条目级新口径（只认颜色标记）自相矛盾。故帖子级一律按类别定档：扫书灰「扫书」、
/// 排雷红、求书灰「求书」、其余不标。
SemanticTone postToneOf({required String? postKind}) {
  switch (postKind) {
    case CategoryKind.avoid:
      return SemanticTone.avoid;
    case CategoryKind.scan:
      return SemanticTone.scan;
    case CategoryKind.ask:
      return SemanticTone.ask;
    default:
      return SemanticTone.neutral;
  }
}

/// 语义色条颜色（卡片左 3px）。
Color barColorOf(BuildContext context, SemanticTone tone) {
  final AppColors c = AppColors.of(context);
  return switch (tone) {
    SemanticTone.recommend => c.recommend,
    SemanticTone.avoid => c.danger,
    SemanticTone.ask => c.borderStrong,
    // 扫书档比 neutral 的 border 略深：有色条才看得出「这是一张有语义的卡」，又不抢推荐/排雷。
    SemanticTone.scan => c.borderStrong,
    SemanticTone.neutral => c.border,
  };
}

/// 推荐/排雷/求书/扫书徽标（badge h24 pill；MI-5 pop-in：instant+spring，比卡片晚一拍）。
class SemanticBadge extends StatelessWidget {
  const SemanticBadge({super.key, required this.tone, this.animate = true});

  final SemanticTone tone;
  final bool animate;

  static String labelOf(SemanticTone tone) => switch (tone) {
    SemanticTone.recommend => '推荐',
    SemanticTone.avoid => '排雷',
    SemanticTone.ask => '求书',
    SemanticTone.scan => '扫书',
    SemanticTone.neutral => '',
  };

  @override
  Widget build(BuildContext context) {
    if (tone == SemanticTone.neutral) {
      return const SizedBox.shrink();
    }
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    // 徽标内图标走设计稿 SVG（index.html:1465/1479：`.ic.xs` #i-check / #i-alert，13px → -s 档），
    // 不用 Material check_rounded/warning_amber（用户红线：不得随意采用默认 Material 图标）。
    final (Color bg, Color fg, String? icon) = switch (tone) {
      SemanticTone.recommend => (c.recommendSoft, c.recommend, 'check'),
      SemanticTone.avoid => (c.dangerSoft, c.danger, 'alert'),
      SemanticTone.ask => (c.surfaceSunken, c.textMuted, null),
      // 扫书档 = 与求书同规格的灰徽标（无图标），字色比 ask 深一档以保可读（sunken 底上 textMuted 偏淡）。
      SemanticTone.scan => (c.surfaceSunken, c.textSecondary, null),
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
            AppIcon(icon, size: 13, color: fg),
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
      // 垂直居中走 Center（widthFactor/heightFactor=1 收缩裹内容）；
      // 不得用 Container.alignment —— 其在有界约束下会把徽标膨胀到整宽（Wrap/松散槽内实测复现）。
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          labelOf(origin),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.label.copyWith(fontWeight: FontWeight.w600, color: fg, letterSpacing: 0),
        ),
      ),
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
        // Dynamic Type：外层为 Flexible 时可收缩省略（1.0 缩放下取固有宽，视觉不变）。
        // 居中用 Center(factor 1) 而非 Container.alignment —— 后者在有界约束下膨胀到整宽。
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption.copyWith(color: c.textSecondary)),
        ),
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
        // 居中用 Center(factor 1) 而非 Container.alignment —— 后者在有界约束下膨胀到整宽。
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Text(
            '《${stripBrackets(name)}》',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.cardTitle.copyWith(color: c.bookname),
          ),
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
    final SemanticTone tone = postToneOf(postKind: post.postKind);
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
              // 作者名槽用 Expanded（紧约束）而非 Flexible：loose 槽比文本宽时富余空白会堆到行尾，
              // 把日期从右边缘顶回来（实测短作者名下日期左移 58dp）。紧约束下文本在槽内左对齐、
              // 槽宽恒定 → 日期恒贴右边缘，作者名过长时才 ellipsis。
              if ((post.author ?? '').isNotEmpty) ...<Widget>[
                Expanded(
                  flex: 2,
                  child: Text(post.author!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption.copyWith(color: c.textMuted)),
                ),
                SizedBox(width: s.space2),
              ],
              // chips 取固有宽（不套 Flexible，否则弹性槽均分余量会把标签撑宽/挤爆推荐人）。
              MetaChip(label: post.channel, onTap: onChannelTap == null ? null : () => onChannelTap!(post.channel)),
              SizedBox(width: s.space2),
              OriginBadge(origin: post.origin),
              // 日期槽 = Expanded(flex 5) 紧约束 + textAlign.end：一是贴死行右缘（原 loose 槽比文本宽时
              // 日期悬在行中，看着像掉了右对齐），二是让日期在弹性余量里拿大头（作者名 flex 2）→
              // 常规字阶下作者名与日期同时完整（真机反馈「日期显示不全」的修法：旧口径作者/Spacer/日期
              // 三等分，日期只剩 ~64dp 被砍成「2025-0…」）。字阶继续放大时先削作者名，日期最后才省略；
              // 实测 textScaler 2.0 下光日期就占行宽 78%（240/311dp），「日期永不截断」与「零 overflow」
              // 不可兼得 → 取后者（质量预算 Dynamic Type 门禁，test/quality/dynamic_type_test.dart）。
              Expanded(
                flex: 5,
                child: Text(
                  post.date ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: AppTypography.tabular(t.caption.copyWith(color: c.textMuted)),
                ),
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
    this.commentMaxCollapsed = 100,
    this.hideBookName = false,
  });

  final EntryRow entry;
  final VoidCallback? onTap;

  /// 点《书名》→ 以书名搜索（§5 通用规范）。
  final ValueChanged<String>? onBookTap;

  /// 点推荐人 → 以推荐人搜索（§5.5）。
  final ValueChanged<String>? onRecommenderTap;

  /// 点「原帖↗」（§5.5：有帖溯源进详情，否则交系统外链打开）。
  final VoidCallback? onSourceTap;
  final bool showRecommender;

  /// 折叠态是否可「展开全文」（仅 comment 超过 [commentMaxCollapsed] 字符时生效）。
  final bool expandableComment;

  /// 折叠态摘录长度（**字符数**，非行数）：超出即截断补 '…'，展开显示全文。
  final int commentMaxCollapsed;

  /// 首行不渲染书名（书聚合页整页同书，书名已在页头大标题，卡内再写一遍是冗余）。
  final bool hideBookName;

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
    final SemanticTone tone = toneOfEntry(e);
    // 预览原文 = 条目评语，空则回退楼层正文（种子库 4169 条 comment 为空但楼层正文在场；
    // 不回退会让书聚合/分类预览卡片正文整块空白）。截断在 UI 侧按字符做（可展开全文）。
    final String comment = e.previewSource ?? '';
    // 折叠态摘录按**字符**截（不是按行数）：行数截断的实际长度随字阶/屏宽漂移，
    // 而这里要的是稳定的「开头 N 字」；按 runes 切才不会把代理对（emoji）劈成半个。
    final List<int> runes = comment.runes.toList();
    final bool collapsible = widget.expandableComment && runes.length > widget.commentMaxCollapsed;
    final bool clip = !widget.expandableComment && runes.length > widget.commentMaxCollapsed;
    final String shown = (collapsible && !_expanded) || clip
        ? '${String.fromCharCodes(runes.take(widget.commentMaxCollapsed))}…'
        : comment;

    Widget? commentBlock;
    if (shown.isNotEmpty) {
      commentBlock = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            shown,
            maxLines: null,
            style: t.secondary.copyWith(
              color: tone == SemanticTone.avoid ? c.danger : c.textSecondary,
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
          // 首行三段同一中线：徽标是 h24 pill、书名是 cardTitle、日期是 caption，
          // 原来用 CrossAxisAlignment.start 会把日期顶到行首基线之上（真机反馈「日期飘高」）。
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SemanticBadge(tone: tone),
              SizedBox(width: s.space2),
              // 书名槽恒占 Expanded（tight）：既吃掉全部余量把日期顶到行尾右贴边，
              // hideBookName 时留空槽也保持同一几何（日期位置不随书名有无跳动）。
              Expanded(
                child: widget.hideBookName
                    ? const SizedBox.shrink()
                    : GestureDetector(
                        onTap: widget.onBookTap == null ? null : () => widget.onBookTap!(BookNameChip.stripBrackets(e.name)),
                        child: Text(
                          '《${BookNameChip.stripBrackets(e.name)}》',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.cardTitle.copyWith(color: c.bookname),
                        ),
                      ),
              ),
              // 日期取固有宽（不套 Flexible）：弹性槽余量不足时会截成「2025-0…」，
              // 而日期是这张卡的时间锚点，宁可书名单行省略也要让它完整。
              if ((e.date ?? '').isNotEmpty)
                Text(
                  e.date!,
                  maxLines: 1,
                  textAlign: TextAlign.end,
                  style: AppTypography.tabular(t.caption.copyWith(color: c.textMuted)),
                ),
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
              // chips 取固有宽（不套 Flexible，避免弹性槽均分余量撑宽标签/挤爆推荐人）；
              // Dynamic Type 收缩由推荐人/原帖文本槽承担（可省略）。
              if (widget.showRecommender && (e.recommender ?? '').isNotEmpty) ...<Widget>[
                // 推荐人（扫书作者名）是这行的主角：弹性份额 20 压过右侧 Spacer 的 8
                // → 保证 6 个中文字符完整显示（用户口径「最多六个中文字符」），
                // 超出 6 字才截断（见 _capRunes），不再动辄截成「扫书人…」。
                Flexible(
                  flex: 20,
                  child: GestureDetector(
                    onTap: widget.onRecommenderTap == null ? null : () => widget.onRecommenderTap!(e.recommender!),
                    child: Text(
                      _capRunes(e.recommender!, 6),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.caption.copyWith(color: c.accentStrong, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                SizedBox(width: s.space2),
              ],
              MetaChip(label: e.channel),
              SizedBox(width: s.space2),
              OriginBadge(origin: e.origin),
              const Spacer(flex: 8),
              if (widget.onSourceTap != null)
                // 「查看」= 进原帖详情（楼层流，非外链跳转）；取固有宽贴右（不套 Flexible：
                // 弹性槽与 Spacer 均分余量时槽宽可能小于文案宽而截断，推荐人槽承担收缩）。
                GestureDetector(
                  onTap: widget.onSourceTap,
                  child: Text('查看', maxLines: 1, style: t.caption.copyWith(color: c.info)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 计数对比胶囊「扫书 n ｜ 推荐 n ｜ 排雷 m」（书聚合页头；三档皆可点 = 语义筛选）。
class CountTrio extends StatelessWidget {
  const CountTrio({
    super.key,
    required this.scan,
    required this.recommend,
    required this.avoid,
    this.onScanTap,
    this.onRecommendTap,
    this.onAvoidTap,
  });

  final int scan;
  final int recommend;
  final int avoid;
  final VoidCallback? onScanTap;
  final VoidCallback? onRecommendTap;
  final VoidCallback? onAvoidTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    Widget half(String label, int n, Color fg, VoidCallback? onTap) {
      return Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          // 墨渍贴合 pill 圆角：无 borderRadius 时按压高亮/涟漪是直角矩形，会外溢到
          // chip 圆角之外（CountDuo 的同类修法是容器 Clip.antiAlias，此处就近加在墨渍层）。
          borderRadius: AppRadius.pillBorder,
          hoverColor: c.surfaceSunken,
          highlightColor: c.surfaceSunken,
          splashColor: c.surfaceSunken,
          child: Container(
            constraints: const BoxConstraints(minHeight: AppMetrics.minTouchTarget),
            padding: EdgeInsets.symmetric(horizontal: s.space4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '$n',
                  style: AppTypography.tabular(
                    t.headline.copyWith(fontSize: 17, fontWeight: FontWeight.w700, height: 1, color: fg),
                  ),
                ),
                SizedBox(width: s.space1),
                Text(label, style: t.bodyStrong.copyWith(color: c.text)),
              ],
            ),
          ),
        ),
      );
    }

    Widget chip(String label, int n, Color fg, VoidCallback? onTap) => Container(
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: AppRadius.pillBorder,
            border: Border.all(color: c.borderStrong, width: AppMetrics.hairline),
          ),
          child: half(label, n, fg, onTap),
        );
    // 窄屏放不下三档时换行，宽屏同一行；不把三档硬塞进一条胶囊（1440 宽下会溢出）。
    return Wrap(
      spacing: s.space2,
      runSpacing: s.space2,
      children: <Widget>[
        chip('扫书', scan, c.textSecondary, onScanTap),
        chip('推荐', recommend, c.recommend, onRecommendTap),
        chip('排雷', avoid, c.danger, onAvoidTap),
      ],
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
    // 设计 04 行 1449–1452 + CSS 542–555：`[衬线700 17 tabular 彩色数字][标签]`，数字在前、标签在后；
    // 推荐=recommend 绿 / 排雷=danger 红（仅数字着色，标签走 --text-body-strong 继承文字色）；
    // button min-h44 / padding 0 space5 / hover·pressed sunken；无 Material 图标（原 circle 圆点已删）。
    Widget half(String label, int n, Color fg, VoidCallback? onTap) {
      return Material(
        // 透明 Material 作墨渍画布：hover/highlight 的 sunken 底才盖得到 surfaceRaised 之上。
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          hoverColor: c.surfaceSunken,
          highlightColor: c.surfaceSunken,
          splashColor: c.surfaceSunken,
          child: Container(
            constraints: const BoxConstraints(minHeight: AppMetrics.minTouchTarget), // CSS 548：min-height 44
            padding: EdgeInsets.symmetric(horizontal: s.space5), // CSS 548：padding 0 var(--space-5)
            // 垂直居中由 Row 在 minHeight 约束内默认 crossAxisAlignment.center 承担；
            // 不得用 Container.alignment —— 其会把半边膨胀到整行宽（实测把胶囊撑满屏宽）。
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // `.n`（CSS 553）：衬线 700 17px/1 tabular；headline 槽 = --font-serif，对齐 rank-no 17px 序号。
                Text(
                  '$n',
                  style: AppTypography.tabular(
                    t.headline.copyWith(fontSize: 17, fontWeight: FontWeight.w700, height: 1, color: fg),
                  ),
                ),
                const SizedBox(width: 6), // CSS 548：gap 6px（组件级几何，无对应 spacing token）
                Text(label, style: t.bodyStrong.copyWith(color: c.text)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias, // CSS 544：overflow hidden，hover 墨渍裁进 pill
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: c.borderStrong, width: AppMetrics.hairline), // CSS 545：border-strong
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          half('推荐', recommend, c.recommend, onRecommendTap),
          Container(width: AppMetrics.hairline, height: 26, color: c.borderStrong), // CSS 552：sep 1×26 border-strong
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
          // Dynamic Type：各段 loose-Flexible，放大时收缩省略；1.0 缩放取固有宽（min Row），视觉不变。
          for (final (T value, String label) in options)
            Flexible(
              child: InkWell(
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.caption.copyWith(
                      color: value == selected ? c.text : c.textMuted,
                      fontWeight: value == selected ? FontWeight.w600 : FontWeight.w400,
                    ),
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
    this.showChev = false,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback? onTap;

  /// 「分类·排雷」红染（设计系统 §3 #02）。
  final bool dangerTint;
  final bool compact;

  /// 尾部 chev（13px）：仅「点开值域浮层」的下拉触发器传 true（搜索六维 chips）；
  /// 值选择 chip（分类页/浮层内）与动作 chip（排序切换/清空）不显示（设计系统 §4 值 chip = 值名+计数，无 chev）。
  final bool showChev;

  /// 千分位分组计数（设计稿 .ct：74,498 / 10,705 精确值，不做 k 缩写）。
  static String formatCount(int n) {
    final String digits = '$n';
    final StringBuffer buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      buf.write(digits[i]);
      if ((digits.length - i - 1) % 3 == 0 && i < digits.length - 1) {
        buf.write(',');
      }
    }
    return buf.toString();
  }

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
        // 垂直居中由 Row 在固定高度内默认 crossAxisAlignment.center 承担；
        // 不得用 Container.alignment —— 其会把 chip 膨胀到整宽（Wrap 内实测复现）。
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
                formatCount(count!),
                style: AppTypography.tabular(
                  t.label.copyWith(color: selected ? fg : c.textMuted, letterSpacing: 0),
                ),
              ),
            ],
            // 设计 :1297–1304 六维下拉触发 chip 尾部 i-chev（xs 13px→stroke2 自动 -s 资产），色随 chip 前景。
            if (showChev) ...<Widget>[
              SizedBox(width: s.space1),
              AppIcon('chev', size: 13, color: fg),
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
  const AppButton({super.key, required this.label, this.onPressed, this.kind = AppButtonKind.primary, this.svgIcon});

  final String label;
  final VoidCallback? onPressed;
  final AppButtonKind kind;

  /// 可选前缀图标（设计稿 SVG symbol 名；.btn .ic sm 16px，index.html:324/333）。
  final String? svgIcon;

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
            // 垂直居中由 Row 在固定高度内默认 crossAxisAlignment.center 承担；
            // 不得用 Container.alignment —— 其会把按钮膨胀到整宽（设计按钮裹内容）。
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (svgIcon != null) ...<Widget>[AppIcon(svgIcon!, size: 16, color: fg), const SizedBox(width: 6)],
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
///
/// 图标槽单一口径：[svgIcon]（AppIcon symbol 名）渲染设计稿 SVG 线稿 accent 64px；
/// 不接受 Material IconData（全仓图标红线，test/icon_guard_test.dart 守卫）。
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    required this.svgIcon,
    this.message,
    this.action,
  });

  final String title;
  final String? message;

  /// 设计稿 SVG symbol 名（assets/icons/*.svg）。
  final String svgIcon;
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
          AppIcon(svgIcon, size: AppMetrics.emptyStateIconSize, color: c.accent),
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

