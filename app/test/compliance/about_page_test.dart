/// 关于与合规页测试（Phase 5 合规文案；TESTING.md §3.1：全内存 fake，零真实 IO / 零网络）。
///
/// 覆盖：页面可渲染、三块内容关键句、数据截至日与版本号（含降级）、
/// 频控数字与 `collector/scheduler.dart` 常量同源、设置页入口可达。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/collector/scheduler.dart';
import 'package:booksift/core/update/update_service.dart';
import 'package:booksift/features/profile/about_page.dart';

import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import '../support/harness.dart';
import '../update/support.dart';

const LocalVersion kKnownVersion = LocalVersion(
  version: '1.0.0',
  buildNumber: 100,
);

/// demoLibrary() 的 book_entries 最大日期（= dataCutoff 口径）。
const String kDemoCutoff = '2025-04-28';

Future<void> pumpAbout(
  WidgetTester tester, {
  LocalVersion local = kKnownVersion,
}) async {
  useTallSurface(tester);
  await tester.pumpWidget(
    testApp(
      FakeBookRepository(library: demoLibrary()),
      home: const AboutPage(),
      extraOverrides: updateTestOverrides(
        adapter: ScriptedAdapter(<String, ScriptedResponse>{}),
        local: local,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('关于与合规页渲染', () {
    testWidgets('三块标题 + 版本行 + 上游致谢', (WidgetTester tester) async {
      await pumpAbout(tester);

      expect(find.text('关于与合规'), findsOneWidget); // AppBar
      expect(find.text('数据来源署名'), findsOneWidget);
      expect(find.text('贴吧服务条款与使用提示'), findsOneWidget);
      expect(find.text('BDUSS 与隐私声明'), findsOneWidget);
      expect(find.text('扫书汇 · v1.0.0 (100)'), findsOneWidget);
      expect(find.textContaining('protobuf 定义取自开源项目 aiotieba'), findsOneWidget);
      expect(find.textContaining('不隶属于百度'), findsOneWidget);
    });

    testWidgets('版本号降级：package_info 不可用 → 「版本未知」', (WidgetTester tester) async {
      await pumpAbout(tester, local: LocalVersion.unknown);
      expect(find.text('扫书汇 · 版本未知'), findsOneWidget);
    });

    testWidgets('版本号降级：无 buildNumber → 只显示 v 号', (WidgetTester tester) async {
      await pumpAbout(tester, local: const LocalVersion(version: '1.2.3'));
      expect(find.text('扫书汇 · v1.2.3'), findsOneWidget);
    });
  });

  group('块一 · 数据来源署名（原型 §11.3）', () {
    testWidgets('版权归属 / 离线整理不商用 / 溯源口径 / 快照与数据截至日 / 删除通道', (
      WidgetTester tester,
    ) async {
      await pumpAbout(tester);

      expect(find.textContaining('百度贴吧各扫书相关吧'), findsOneWidget);
      expect(find.textContaining('版权归原作者与发帖人所有'), findsOneWidget);
      expect(find.textContaining('供个人学习研究'), findsOneWidget);
      expect(find.textContaining('不商用、不声称拥有任何内容版权'), findsOneWidget);
      expect(find.textContaining('不提供原帖全文的批量导出'), findsOneWidget);
      expect(find.textContaining('复制链接跳回贴吧溯源'), findsOneWidget);
      expect(find.textContaining('原帖已不可溯源'), findsOneWidget);
      expect(find.textContaining('一次性快照'), findsOneWidget);
      expect(find.textContaining('数据截至 $kDemoCutoff'), findsOneWidget);
      expect(find.textContaining('我们会在后续数据包中处理'), findsOneWidget);
    });
  });

  group('块二 · 贴吧服务条款与使用提示（原型 §11.4）', () {
    testWidgets('非官方逆向接口 / 不保证可用 / 三重频控 / 不压测不商用 / 风险自担', (
      WidgetTester tester,
    ) async {
      await pumpAbout(tester);

      expect(find.textContaining('非官方逆向接口'), findsOneWidget);
      expect(find.textContaining('有可能违反贴吧服务条款'), findsOneWidget);
      expect(find.textContaining('接口随时可能变更或失效'), findsOneWidget);
      expect(find.textContaining('全局限速'), findsOneWidget);
      expect(find.textContaining('每日预算'), findsOneWidget);
      expect(find.textContaining('退避熔断'), findsOneWidget);
      expect(find.textContaining('不做高频压测，也不做批量商用抓取'), findsOneWidget);
      expect(find.textContaining('风险自行承担'), findsOneWidget);
    });

    testWidgets('频控数字由 scheduler 常量内插（改常量即改文案）', (WidgetTester tester) async {
      await pumpAbout(tester);

      expect(
        find.textContaining('匿名档为 1.5–3.0 秒，BDUSS 档为 1.0–2.0 秒，并在区间内随机抖动'),
        findsOneWidget,
      );
      expect(find.textContaining('每日最多 300 次请求'), findsOneWidget);
      expect(find.textContaining('账号档提高到 600 次'), findsOneWidget);
      expect(
        find.textContaining('按 30 / 60 / 120 秒退避，最多重试 3 次'),
        findsOneWidget,
      );
      expect(find.textContaining('连续失败 3 次进入 48 小时冷却'), findsOneWidget);
      expect(find.textContaining('全局连续失败 3 次会暂停整轮采集'), findsOneWidget);
      expect(find.textContaining('默认 2、上限 匿名 3 / BDUSS 档 4'), findsOneWidget);
    });
  });

  group('块三 · BDUSS 与隐私声明（原型 §11.2 / §8.10）', () {
    testWidgets('凭证可选导入 / 仅本地加密 / 只管身份与配额 / 可清除 / 本地数据不出设备', (
      WidgetTester tester,
    ) async {
      await pumpAbout(tester);

      expect(find.textContaining('BDUSS 是可选的账号凭证'), findsOneWidget);
      expect(find.textContaining('不导入时全程匿名'), findsOneWidget);
      expect(find.textContaining('只填 BDUSS，不要填账号密码'), findsOneWidget);
      expect(find.textContaining('flutter_secure_storage'), findsOneWidget);
      expect(
        find.textContaining(
          'Windows 凭据管理器 / Android Keystore / Apple 平台 Keychain',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('不落明文、不写日志、不进数据库'), findsOneWidget);
      expect(find.textContaining('每日请求配额 300 → 600'), findsOneWidget);
      expect(find.textContaining('可随时在设置页一键清除'), findsOneWidget);
      expect(find.textContaining('绝不上传到任何第三方服务器'), findsOneWidget);
      expect(find.textContaining('不上传、不同步'), findsOneWidget);
      expect(find.textContaining('不含任何统计或广告 SDK'), findsOneWidget);
    });
  });

  group('频控常量口径（改动须同步关于页文案）', () {
    test('scheduler.dart 的匿名/BDUSS 两档频控参数', () {
      expect(kMinIntervalMs, 1500);
      expect(kMaxIntervalMs, 3000);
      expect(kMinIntervalBdussMs, 1000);
      expect(kMaxIntervalBdussMs, 2000);
      expect(kDailyBudgetAnonymous, 300);
      expect(kDailyBudgetBduss, 600);
      expect(kDefaultConcurrency, 2);
      expect(kMaxConcurrencyAnonymous, 3);
      expect(kMaxConcurrencyBduss, 4);
      expect(kMaxThreadRetries, 3);
      expect(kForumFailureCooldown, 3);
      expect(kForumCooldownDuration, const Duration(hours: 48));
      expect(kGlobalFailurePause, 3);
      expect(retryBackoff(0), const Duration(seconds: 30));
      expect(retryBackoff(1), const Duration(seconds: 60));
      expect(retryBackoff(2), const Duration(seconds: 120));
    });
  });

  group('设置页入口', () {
    Future<void> pumpSettingsWithRouter(WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        testApp(
          FakeBookRepository(library: demoLibrary()),
          initial: '/settings',
          extraOverrides: updateTestOverrides(
            adapter: ScriptedAdapter(<String, ScriptedResponse>{}),
            local: kKnownVersion,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('「关于」小节新增行 → 点击进入 /about', (WidgetTester tester) async {
      await pumpSettingsWithRouter(tester);

      expect(find.text('关于与合规'), findsOneWidget);
      expect(find.text('数据来源署名 · 贴吧使用提示 · BDUSS 与隐私'), findsOneWidget);

      await tester.tap(find.text('关于与合规'));
      await tester.pumpAndSettle();

      expect(find.byType(AboutPage), findsOneWidget);
      expect(find.text('数据来源署名'), findsOneWidget);
      expect(find.text('贴吧服务条款与使用提示'), findsOneWidget);
      expect(find.text('BDUSS 与隐私声明'), findsOneWidget);
    });

    testWidgets('设置页 BDUSS 行给出匿名档与配额口径', (WidgetTester tester) async {
      await pumpSettingsWithRouter(tester);

      expect(find.text('BDUSS 导入'), findsOneWidget);
      expect(
        find.text('匿名模式 · 每日配额 300 · 导入后 600 · 详见「关于与合规」'),
        findsOneWidget,
      );
    });
  });
}
