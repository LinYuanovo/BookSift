import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../collector/scheduler.dart';
import '../../core/icons.dart';
import '../../core/update/update_controller.dart';
import '../../core/update/update_service.dart';
import '../../data/repo/queries_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 内置库数据截至日（口径与 headless `stats` 的 `dataCutoff` 同源：
/// `SELECT MAX(date) FROM book_entries`）。null = 空库或无日期列。
final FutureProvider<String?> aboutCutoffProvider =
    FutureProvider<String?>((Ref ref) => ref.watch(queriesProvider).dataCutoff());

/// 关于与合规页（路线图 Phase 5 合规文案；口径出处：原型 §11.2 BDUSS 政策 /
/// §11.3 版权与数据来源署名 / §11.4 贴吧 ToS 风险与免责文案）。
///
/// 三块固定内容 —— 数据来源署名 / 贴吧服务条款与使用提示 / BDUSS 与隐私声明；
/// 频控数字一律内插 `collector/scheduler.dart` 的常量，文案不与代码各写一套。
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  /// 全局间隔下限（秒，1 位小数）：`kMinIntervalMs` 1500 → 「1.5」。
  static String get _minIntervalSec => (kMinIntervalMs / 1000).toStringAsFixed(1);

  /// 全局间隔上限（秒，1 位小数）：`kMaxIntervalMs` 3000 → 「3.0」。
  static String get _maxIntervalSec => (kMaxIntervalMs / 1000).toStringAsFixed(1);

  /// BDUSS 档间隔下限（秒，1 位小数）：`kMinIntervalBdussMs` 1000 → 「1.0」。
  static String get _bdMinIntervalSec => (kMinIntervalBdussMs / 1000).toStringAsFixed(1);

  /// BDUSS 档间隔上限（秒，1 位小数）：`kMaxIntervalBdussMs` 2000 → 「2.0」。
  static String get _bdMaxIntervalSec => (kMaxIntervalBdussMs / 1000).toStringAsFixed(1);

  /// 单帖退避序列（`retryBackoff` 30s×2ⁿ，重试 ≤ `kMaxThreadRetries`）。
  static String get _backoffSeq => List<int>.generate(
        kMaxThreadRetries,
        (int i) => retryBackoff(i).inSeconds,
      ).join(' / ');

  /// 数据来源署名（原型 §11.3：署名区 + 可溯源 + 快照口径 + 删除通道）。
  List<String> _attribution(String? cutoff) => <String>[
        '书目、推荐语与排雷信息全部来自百度贴吧各扫书相关吧（如 yy小说吧、哀伤雪刃吧）的公开帖子，'
            '由社区用户自发发布，版权归原作者与发帖人所有。',
        '扫书汇只做离线整理与检索：把公开帖文按书名归并、分类、建索引，供个人学习研究使用。'
            '本应用不商用、不声称拥有任何内容版权，也不提供原帖全文的批量导出。',
        '带原帖链接（tid）的条目可在书聚合页复制跳回贴吧溯源；无链接的条目会如实提示'
            '「原帖已不可溯源」，不假装可跳。',
        cutoff == null
            ? '内置种子数据包是一次性快照，不随时间自动更新；快照之后的新帖需自行发起增量采集。'
            : '内置种子数据包是一次性快照，不随时间自动更新，数据截至 $cutoff；'
                '快照之后的新帖需自行发起增量采集。',
        '如权利人希望移除相关内容，可通过项目发布渠道提出，我们会在后续数据包中处理。',
      ];

  /// 贴吧 ToS 与使用提示（原型 §11.4：非公开逆向接口 + 保守频控 + 风险自担）。
  List<String> get _tosParagraphs => <String>[
        '增量采集使用的是贴吧的非官方逆向接口（逆向自官方 Android 客户端），并非百度对外开放的 API，'
            '违反贴吧服务条款的可能性存在。接口随时可能变更或失效，我们不对其可用性做任何保证。',
        '为把对贴吧服务的影响压到最低，采集侧内置了三重约束：',
      ];

  List<String> get _tosBullets => <String>[
        '全局限速：所有并发分支共享同一令牌桶，相邻请求启动间隔匿名档 $_minIntervalSec–$_maxIntervalSec 秒、'
            'BDUSS 档 $_bdMinIntervalSec–$_bdMaxIntervalSec 秒随机抖动；',
        '每日预算：匿名档每日最多 $kDailyBudgetAnonymous 次请求，导入 BDUSS 的账号档提高到 '
            '$kDailyBudgetBduss 次；触顶当日停止、次日 0 点重置；',
        '退避熔断：单帖失败按 $_backoffSeq 秒退避、最多重试 $kMaxThreadRetries 次；'
            '同一吧连续失败 $kForumFailureCooldown 次进入 ${kForumCooldownDuration.inHours} 小时冷却；'
            '全局连续失败 $kGlobalFailurePause 次整轮暂停。',
      ];

  List<String> get _tosTail => <String>[
        '除跨吧并发数（默认 $kDefaultConcurrency、上限 匿名 $kMaxConcurrencyAnonymous / BDUSS 档 $kMaxConcurrencyBduss，设置页可调）外，'
            '以上频控参数不对用户开放调高。',
        '我们把采集定位为「用户在自己设备上的低频订阅行为」：不做高频压测，也不做批量商用抓取。',
        '把并发调到上限会提高单位时间请求数，使用 BDUSS 则让请求带上账号身份 —— '
            '两者都会提高触发风控（429 / 110xxx / 冷却）的概率，可能导致账号被限制；'
            '是否使用由你决定，风险自行承担。',
      ];

  /// BDUSS 与隐私声明（原型 §11.2 / §8.10）：导入入口已实装（设置页「BDUSS 导入」行）。
  List<String> get _privacyHead => <String>[
        '账号凭证（BDUSS）为可选：不导入时全程匿名，只读接口照常可用。导入入口在设置页'
            '「BDUSS 导入」一行 —— 从贴吧 App / 网页版的 Cookie 里复制粘贴即可'
            '（只填 BDUSS，不要填账号密码）。',
        '导入后，它将：',
      ];

  List<String> get _privacyBullets => <String>[
        '仅通过 flutter_secure_storage 存放在设备本地的系统加密存储中'
            '（Windows 凭据管理器 / Android Keystore / iOS Keychain），不落明文、不写日志、不进数据库；',
        '只用于对贴吧官方接口发起请求时携带账号身份 —— 每日请求配额 $kDailyBudgetAnonymous → '
            '$kDailyBudgetBduss，仅此而已；',
        '可随时在设置页一键清除，清除即回匿名档；设置页「测试」按钮可用一次 initNickname 请求校验当前凭证；',
        '失效自动降级（§8.10）：采集 / 在线搜索命中「登录态失效」特征时自动回退匿名档并标记失效'
            '（不删凭证），重新导入即恢复；',
        '绝不上传到任何第三方服务器 —— 本应用没有自建服务端。',
      ];

  List<String> get _privacyTail => <String>[
        '本地数据同样只留在设备上：数据库、书签、收藏、搜索历史与导入字体全部存于应用私有目录，'
            '不上传、不同步。应用不含任何统计或广告 SDK。',
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing space = AppSpacing.of(context);
    final LocalVersion? local = ref.watch(localVersionProvider).value;
    final String? cutoff = ref.watch(aboutCutoffProvider).value;
    final String versionText = local == null || !local.isKnown
        ? '版本未知'
        : local.buildNumber == null
            ? 'v${local.version}'
            : 'v${local.version} (${local.buildNumber})';

    return Scaffold(
      appBar: AppBar(title: const Text('关于与合规')),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(space.pagePadding, space.space4, space.pagePadding, space.space8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Block(
              icon: 'book',
              title: '数据来源署名',
              paragraphs: _attribution(cutoff),
            ),
            SizedBox(height: space.space6),
            _Block(
              icon: 'alert',
              title: '贴吧服务条款与使用提示',
              paragraphs: _tosParagraphs,
              bullets: _tosBullets,
              tail: _tosTail,
            ),
            SizedBox(height: space.space6),
            _Block(
              icon: 'key',
              title: 'BDUSS 与隐私声明',
              paragraphs: _privacyHead,
              bullets: _privacyBullets,
              tail: _privacyTail,
            ),
            SizedBox(height: space.space8),
            Text(
              '扫书汇 · $versionText',
              textAlign: TextAlign.center,
              style: AppTypography.tabular(t.caption.copyWith(color: colors.textSecondary)),
            ),
            SizedBox(height: space.space2),
            Text(
              '贴吧接口的 protobuf 定义取自开源项目 aiotieba，协议实现参考了公开的逆向研究成果；'
              '本应用不隶属于百度，与其无任何关联。',
              textAlign: TextAlign.center,
              style: t.caption.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单块合规卡：图标 + 标题 + 段落（[paragraphs] → [bullets] → [tail]）。
class _Block extends StatelessWidget {
  const _Block({
    required this.icon,
    required this.title,
    required this.paragraphs,
    this.bullets = const <String>[],
    this.tail = const <String>[],
  });

  final String icon;
  final String title;
  final List<String> paragraphs;
  final List<String> bullets;
  final List<String> tail;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    final AppSpacing space = AppSpacing.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(space.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                AppIcon(icon, size: 20, color: colors.accent),
                SizedBox(width: space.space3),
                Expanded(child: Text(title, style: t.cardTitle.copyWith(color: colors.text))),
              ],
            ),
            SizedBox(height: space.space4),
            for (final String p in paragraphs)
              Padding(
                padding: EdgeInsets.only(bottom: space.space3),
                child: Text(p, style: t.body.copyWith(color: colors.textSecondary)),
              ),
            for (final String b in bullets)
              Padding(
                padding: EdgeInsets.only(bottom: space.space3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('·', style: t.body.copyWith(color: colors.textMuted)),
                    SizedBox(width: space.space2),
                    Expanded(child: Text(b, style: t.body.copyWith(color: colors.textSecondary))),
                  ],
                ),
              ),
            for (final String p in tail)
              Padding(
                padding: EdgeInsets.only(bottom: space.space3),
                child: Text(p, style: t.body.copyWith(color: colors.textSecondary)),
              ),
            SizedBox(height: space.space1),
          ],
        ),
      ),
    );
  }
}
