import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../collector/scheduler.dart';
import '../../core/icons.dart';
import '../../core/update/update_controller.dart';
import '../../core/update/update_service.dart';
import '../../core/widgets/app_toast.dart';
import '../../data/repo/queries_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 内置库数据截至日（口径与 headless `stats` 的 `dataCutoff` 同源：
/// `SELECT MAX(date) FROM book_entries`）。null = 空库或无日期列。
final FutureProvider<String?> aboutCutoffProvider = FutureProvider<String?>(
  (Ref ref) => ref.watch(queriesProvider).dataCutoff(),
);

/// 关于与合规页（路线图 Phase 5 合规文案；口径出处：原型 §11.2 BDUSS 政策 /
/// §11.3 版权与数据来源署名 / §11.4 贴吧 ToS 风险与免责文案）。
///
/// 三块固定内容 —— 数据来源署名 / 贴吧服务条款与使用提示 / BDUSS 与隐私声明；
/// 频控数字一律内插 `collector/scheduler.dart` 的常量，文案不与代码各写一套。
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  /// 全局间隔下限（秒，1 位小数）：`kMinIntervalMs` 1500 → 「1.5」。
  static String get _minIntervalSec =>
      (kMinIntervalMs / 1000).toStringAsFixed(1);

  /// 全局间隔上限（秒，1 位小数）：`kMaxIntervalMs` 3000 → 「3.0」。
  static String get _maxIntervalSec =>
      (kMaxIntervalMs / 1000).toStringAsFixed(1);

  /// BDUSS 档间隔下限（秒，1 位小数）：`kMinIntervalBdussMs` 1000 → 「1.0」。
  static String get _bdMinIntervalSec =>
      (kMinIntervalBdussMs / 1000).toStringAsFixed(1);

  /// BDUSS 档间隔上限（秒，1 位小数）：`kMaxIntervalBdussMs` 2000 → 「2.0」。
  static String get _bdMaxIntervalSec =>
      (kMaxIntervalBdussMs / 1000).toStringAsFixed(1);

  /// 单帖退避序列（`retryBackoff` 30s×2ⁿ，重试 ≤ `kMaxThreadRetries`）。
  static String get _backoffSeq => List<int>.generate(
    kMaxThreadRetries,
    (int i) => retryBackoff(i).inSeconds,
  ).join(' / ');

  /// 数据来源署名（原型 §11.3：署名区 + 可溯源 + 快照口径 + 删除通道）。
  List<String> _attribution(String? cutoff) => <String>[
    '书名、推荐语和排雷信息都来自百度贴吧各扫书相关吧的公开帖子，由吧友自己发布，'
        '版权归原作者与发帖人所有。',
    '扫书汇只做离线整理和检索：把公开帖子按书名归并、分类、建索引，供个人学习研究。'
        '应用不商用、不声称拥有任何内容版权，也不提供原帖全文的批量导出。',
    '带原帖链接（tid）的条目，可以在书聚合页复制链接跳回贴吧溯源；没有链接的条目'
        '会如实提示「原帖已不可溯源」。',
    cutoff == null
        ? '内置种子数据包是一次性快照，不会自动更新。快照之后的新帖，需要你自己增量采集。'
        : '内置种子数据包是一次性快照，不会自动更新，数据截至 $cutoff。'
              '之后的新帖需要你自己增量采集。',
    '权利人如果希望移除相关内容，可以通过项目发布渠道提出，我们会在后续数据包中处理。',
  ];

  /// 贴吧 ToS 与使用提示（原型 §11.4：非公开逆向接口 + 保守频控 + 风险自担）。
  List<String> get _tosParagraphs => <String>[
    '增量采集使用的是贴吧的非官方逆向接口，来自对官方 Android 客户端的逆向分析，'
        '不是百度对外开放的接口，有可能违反贴吧服务条款。接口随时可能变更或失效，不保证一直可用。',
    '为了尽量少打扰贴吧服务，采集做了以下限制：',
  ];

  List<String> get _tosBullets => <String>[
    '全局限速：相邻两次请求的启动间隔，匿名档为 $_minIntervalSec–$_maxIntervalSec 秒，'
        'BDUSS 档为 $_bdMinIntervalSec–$_bdMaxIntervalSec 秒，并在区间内随机抖动；',
    '每日预算：匿名档每日最多 $kDailyBudgetAnonymous 次请求，'
        '账号档提高到 $kDailyBudgetBduss 次。当天用完就停止，第二天 0 点重置；',
    '退避熔断：单帖失败后按 $_backoffSeq 秒退避，最多重试 $kMaxThreadRetries 次；'
        '同一吧连续失败 $kForumFailureCooldown 次进入 ${kForumCooldownDuration.inHours} 小时冷却；'
        '全局连续失败 $kGlobalFailurePause 次会暂停整轮采集。',
  ];

  List<String> get _tosTail => <String>[
    '跨吧并发数默认 $kDefaultConcurrency、上限 匿名 $kMaxConcurrencyAnonymous / '
        'BDUSS 档 $kMaxConcurrencyBduss，可以在设置页调整。其他频控参数固定，不开放调高。',
    '采集只面向个人自用的低频使用，不做高频压测，也不做批量商用抓取。',
    '把并发调高会让单位时间内的请求变多，使用 BDUSS 则会让请求带上账号身份。'
        '两者都会提高触发风控的概率，可能导致账号被限制。是否使用由你决定，风险自行承担。',
  ];

  /// BDUSS 与隐私声明（原型 §11.2 / §8.10）：导入入口已实装（设置页「BDUSS 导入」行）。
  List<String> get _privacyHead => <String>[
    'BDUSS 是可选的账号凭证。不导入时全程匿名，只读接口照常使用。导入入口在设置页的'
        '「BDUSS 导入」一行：从贴吧 App 或网页版的 Cookie 里复制粘贴即可，'
        '只填 BDUSS，不要填账号密码。',
    '导入后，它只会用于以下用途：',
  ];

  List<String> get _privacyBullets => <String>[
    '仅通过 flutter_secure_storage 存放在设备本地的系统加密存储中'
        '（Windows 凭据管理器 / Android Keystore / Apple 平台 Keychain），不落明文、不写日志、不进数据库；',
    '只在请求贴吧官方接口时携带账号身份，每日请求配额 $kDailyBudgetAnonymous → $kDailyBudgetBduss，'
        '没有其他用途；',
    '可随时在设置页一键清除，清除后回到匿名档。设置页的「测试」按钮可以校验当前凭证；',
    '如果凭证失效，采集和在线搜索会自动降级回匿名档并标记失效，但不会删除凭证。'
        '重新导入即可恢复；',
    '绝不上传到任何第三方服务器。本应用没有自建服务端。',
  ];

  List<String> get _privacyTail => <String>[
    '本地数据同样只留在设备上：数据库、书签、收藏、搜索历史和导入字体都存放在应用私有目录，'
        '不上传、不同步。应用不含任何统计或广告 SDK。',
  ];

  /// 反馈渠道：页面展示与实际打开地址共用同一组常量。
  static const String _creatorUrl = 'https://space.bilibili.com/345721873';
  static const String _projectUrl = 'https://github.com/LinYuanovo/BookSift';
  static const String _email = '1577242215@qq.com';

  static Future<void> _openFeedbackUrl(BuildContext context, String url) async {
    bool opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } on Object {
      opened = false;
    }
    if (!opened && context.mounted) {
      showAppToast(context, '没有可打开该链接的应用');
    }
  }

  static Future<void> _openFeedbackEmail(BuildContext context) async {
    bool opened = false;
    try {
      opened = await launchUrl(
        Uri(scheme: 'mailto', path: _email),
        mode: LaunchMode.externalApplication,
      );
    } on Object {
      opened = false;
    }
    if (!opened && context.mounted) {
      showAppToast(context, '没有可发送邮件的应用');
    }
  }

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
        padding: EdgeInsets.fromLTRB(
          space.pagePadding,
          space.space4,
          space.pagePadding,
          space.space8,
        ),
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
            SizedBox(height: space.space6),
            Card(
              child: Padding(
                padding: EdgeInsets.all(space.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        AppIcon('info', size: 20, color: colors.accent),
                        SizedBox(width: space.space3),
                        Expanded(
                          child: Text(
                            '反馈与联系',
                            style: t.cardTitle.copyWith(color: colors.text),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: space.space4),
                    Text(
                      '遇到问题、发现数据有误，或有功能建议，欢迎通过以下渠道反馈。'
                      '为了便于定位，请尽量附上应用版本、使用平台和复现步骤。',
                      style: t.body.copyWith(color: colors.textSecondary),
                    ),
                    SizedBox(height: space.space3),
                    _FeedbackLink(
                      icon: 'user',
                      title: 'B 站主页',
                      subtitle: _creatorUrl,
                      onTap: () => _openFeedbackUrl(context, _creatorUrl),
                    ),
                    const Divider(height: 1),
                    _FeedbackLink(
                      icon: 'book',
                      title: '项目主页',
                      subtitle: _projectUrl,
                      onTap: () => _openFeedbackUrl(context, _projectUrl),
                    ),
                    const Divider(height: 1),
                    _FeedbackLink(
                      icon: 'external',
                      title: '邮件联系',
                      subtitle: _email,
                      onTap: () => _openFeedbackEmail(context),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: space.space8),
            Text(
              '扫书汇 · $versionText',
              textAlign: TextAlign.center,
              style: AppTypography.tabular(
                t.caption.copyWith(color: colors.textSecondary),
              ),
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

/// 反馈渠道行：整行可点，附外部打开图标。
class _FeedbackLink extends StatelessWidget {
  const _FeedbackLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AppTypography t = AppTypography.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: AppIcon(icon, size: 20, color: colors.textMuted),
      title: Text(
        title,
        style: t.bodyStrong.copyWith(color: colors.text),
      ),
      subtitle: Text(
        subtitle,
        style: t.caption.copyWith(color: colors.textMuted),
      ),
      trailing: AppIcon('external', size: 16, color: colors.textMuted),
      onTap: onTap,
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
                Expanded(
                  child: Text(
                    title,
                    style: t.cardTitle.copyWith(color: colors.text),
                  ),
                ),
              ],
            ),
            SizedBox(height: space.space4),
            for (final String p in paragraphs)
              Padding(
                padding: EdgeInsets.only(bottom: space.space3),
                child: Text(
                  p,
                  style: t.body.copyWith(color: colors.textSecondary),
                ),
              ),
            for (final String b in bullets)
              Padding(
                padding: EdgeInsets.only(bottom: space.space3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('·', style: t.body.copyWith(color: colors.textMuted)),
                    SizedBox(width: space.space2),
                    Expanded(
                      child: Text(
                        b,
                        style: t.body.copyWith(color: colors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            for (final String p in tail)
              Padding(
                padding: EdgeInsets.only(bottom: space.space3),
                child: Text(
                  p,
                  style: t.body.copyWith(color: colors.textSecondary),
                ),
              ),
            SizedBox(height: space.space1),
          ],
        ),
      ),
    );
  }
}
