import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/repo/queries.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../category/category_page.dart' show dimensionCountsProvider;
import '../home/cards.dart';

// 采集 Tab（原型 §5.9）。
//
// 当前实装的是**本地库概览**半边：库容量、数据截至、类别构成、origin 三档溯源语义 ——
// 全部来自已就绪的 BookRepository，不新增查询面。
// §5.9 的另一半（关注吧水位 / 立即采集 / 分步进度页 / 采集日志）依赖 App 内增量采集模块，
// 属路线图 M2-①（lib/ 下尚无 collector 实现），此处**不做假 UI**，只以说明卡显式标注。

/// 数据截至日（§5.13 榜单页脚同源）。
final FutureProvider<String?> collectCutoffProvider =
    FutureProvider<String?>((Ref ref) => ref.watch(queriesProvider).dataCutoff());

class CollectPage extends ConsumerWidget {
  const CollectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    final AsyncValue<CategoryCounts> counts = ref.watch(dimensionCountsProvider);
    final String? cutoff = ref.watch(collectCutoffProvider).value;
    final CategoryCounts? data = counts.value;

    return Scaffold(
      appBar: AppBar(title: const Text('采集')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(s.pagePadding, s.space4, s.pagePadding, s.space8),
        children: <Widget>[
          SectionTitle(label: '本地库概览'),
          _StatCard(
            rows: <(String, String)>[
              ('库容量', data == null ? '—' : '${data.total} 条'),
              ('数据截至', cutoff ?? '—'),
              ('年份跨度', data == null || data.years.isEmpty
                  ? '—'
                  : '${data.years.last.label} – ${data.years.first.label}'),
            ],
          ),
          SizedBox(height: s.space6),
          SectionTitle(label: '类别构成'),
          if (data == null)
            const SkeletonBlock(height: 96)
          else
            _StatCard(
              rows: <(String, String)>[
                for (final DimCount d in data.categories) (d.label, '${d.count} 条'),
              ],
            ),
          SizedBox(height: s.space6),
          SectionTitle(label: '溯源徽标'),
          _LegendCard(
            items: <(String, String)>[
              (Origin.builtin, '种子数据包导入的行（origin=builtin / seed），随包发行'),
              (Origin.collected, 'App 内增量采集入库的行（origin=collected），升级不覆盖'),
              (Origin.imported, '外部数据包手动导入的行（origin=imported）'),
            ],
          ),
          SizedBox(height: s.space6),
          SectionTitle(label: '增量采集'),
          Container(
            padding: EdgeInsets.all(s.cardPadding),
            decoration: BoxDecoration(
              color: c.surfaceRaised,
              borderRadius: AppRadius.lgBorder,
              border: Border.all(color: c.border, width: AppMetrics.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.cloud_download_outlined, size: 20, color: c.textMuted),
                    SizedBox(width: s.space2),
                    Text('尚未实装（M2-①）', style: t.bodyStrong.copyWith(color: c.textSecondary)),
                  ],
                ),
                SizedBox(height: s.space2),
                Text(
                  '关注吧水位续采、立即采集、分步进度与采集日志属 App 内增量采集模块，'
                  '按路线图排在 M2-①。当前版本只读内置/已导入的本地库，不发起任何网络请求。',
                  style: t.secondary.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 键值统计卡（dtable 语汇的轻量版：左标签右 tabular 数值）。
class _StatCard extends StatelessWidget {
  const _StatCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing s = AppSpacing.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: s.cardPadding, vertical: s.space2),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: c.border, width: AppMetrics.hairline),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < rows.length; i++) ...<Widget>[
            if (i > 0) Divider(height: AppMetrics.hairline, thickness: AppMetrics.hairline, color: c.border),
            SizedBox(
              height: AppMetrics.listRowHeight,
              child: Row(
                children: <Widget>[
                  Expanded(child: Text(rows[i].$1, style: t.secondary.copyWith(color: c.textSecondary))),
                  Text(rows[i].$2, style: AppTypography.tabular(t.bodyStrong.copyWith(color: c.text))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 图例卡（徽标 + 说明）。
class _LegendCard extends StatelessWidget {
  const _LegendCard({required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    final AppTypography t = AppTypography.of(context);
    final AppColors c = AppColors.of(context);
    final AppSpacing s = AppSpacing.of(context);
    return Container(
      padding: EdgeInsets.all(s.cardPadding),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: c.border, width: AppMetrics.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final (String origin, String desc) in items)
            Padding(
              padding: EdgeInsets.only(bottom: s.space2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  OriginBadge(origin: origin),
                  SizedBox(width: s.space3),
                  Expanded(child: Text(desc, style: t.caption.copyWith(color: c.textMuted))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
