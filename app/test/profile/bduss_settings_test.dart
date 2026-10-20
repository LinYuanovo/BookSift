/// BDUSS 导入与存储（需求 8）+ 测试按钮 / 失效标记（需求 5）：
/// 解析口径、设置页导入/清除/测试交互、失效态文案。
///
/// 全部零真实 IO：机密存储走内存假实现（secretStoreProvider override），
/// initNickname 探测走脚本化 dio（probe override），更新检查走脚本化 dio
/// （updateTestOverrides），DB 走 harness 哨兵。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'
    show MacOsOptions;
import 'package:booksift/collector/collect_providers.dart';
import 'package:booksift/collector/tieba_account.dart';
import 'package:booksift/collector/tieba_search.dart' show computeFormSign;
import 'package:booksift/data/bduss.dart';
import 'package:booksift/features/profile/settings_page.dart';

import '../support/demo_data.dart';
import '../support/fake_book_repository.dart';
import '../support/harness.dart';
import '../update/support.dart';

/// 内存机密存储（settings 测试用；真实实现是 flutter_secure_storage）。
/// 键位感知：`bduss` 走 [value]，其余（如 `bduss_invalid`）走 [extra]。
class MemorySecrets implements SecretStore {
  MemorySecrets([this.value]);

  String? value;

  final Map<String, String> extra = <String, String>{};

  @override
  Future<String?> read(String key) async =>
      key == kSecretKeyBduss ? value : extra[key];

  @override
  Future<void> write(String key, String? v) async {
    if (key == kSecretKeyBduss) {
      value = v;
    } else if (v == null) {
      extra.remove(key);
    } else {
      extra[key] = v;
    }
  }
}

/// 门控适配器：fetch 挂起直到 [complete]（验证「进行中按钮禁用 + 转圈」）。
class _GatedAdapter implements HttpClientAdapter {
  final Completer<ResponseBody> _completer = Completer<ResponseBody>();

  void complete(String body) => _completer.complete(
    ResponseBody.fromString(
      body,
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json; charset=utf-8'],
      },
    ),
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (requestStream != null) {
      await requestStream.drain<void>();
    }
    return _completer.future;
  }

  @override
  void close({bool force = false}) {}
}

/// 合法形态的假 BDUSS（56 位；真实值约 192 位，长度只做粗校验）。
const String kFakeBduss =
    'aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789aBcDeFgHiJkLmNoPqRsTuV';

Future<void> pumpSettings(WidgetTester tester, MemorySecrets secrets) async {
  useTallSurface(tester);
  await tester.pumpWidget(
    testApp(
      FakeBookRepository(library: demoLibrary()),
      home: const SettingsPage(),
      extraOverrides: <Override>[
        secretStoreProvider.overrideWithValue(secrets),
        ...updateTestOverrides(
          adapter: ScriptedAdapter(<String, ScriptedResponse>{}),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('secure storage disables data protection keychain only on macOS', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      try {
        final options = SecureStorageSecrets().storage.mOptions;
        if (platform == TargetPlatform.macOS) {
          expect(options, isA<MacOsOptions>());
          expect((options as MacOsOptions).usesDataProtectionKeychain, isFalse);
        } else {
          expect(options.toMap()['usesDataProtectionKeychain'], 'true');
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }
  });

  group('parseBdussInput / maskBduss（纯函数）', () {
    test('裸值 / BDUSS= 前缀 / 整段 Cookie 片段都能提取', () {
      expect(parseBdussInput(kFakeBduss), kFakeBduss);
      expect(parseBdussInput('  BDUSS=$kFakeBduss  '), kFakeBduss);
      expect(parseBdussInput('BDUSS=$kFakeBduss; STOKEN=abc'), kFakeBduss);
      expect(parseBdussInput('bduss = "$kFakeBduss"'), kFakeBduss);
    });

    test('过短 / 空 / 含非法字符 / 明显不是凭证 → null', () {
      expect(parseBdussInput(''), isNull);
      expect(parseBdussInput('   '), isNull);
      expect(parseBdussInput('abc123'), isNull);
      expect(
        parseBdussInput('我的账号密码：password123456789012345678901234567890'),
        isNull,
      );
      expect(parseBdussInput('${'a' * 40}中文'), isNull);
    });

    test('掩码只露头 6 尾 4', () {
      expect(maskBduss(kFakeBduss), 'aBcDeF……sTuV');
      expect(maskBduss('short'), '……');
    });
  });

  group('设置页 BDUSS 行', () {
    testWidgets('匿名态：诚实标注当前配额，无清除钮', (WidgetTester tester) async {
      await pumpSettings(tester, MemorySecrets());
      expect(find.text('BDUSS 导入'), findsOneWidget);
      expect(
        find.text('匿名模式 · 每日配额 300 · 导入后 600 · 详见「关于与合规」'),
        findsOneWidget,
      );
      expect(find.text('清除'), findsNothing);
    });

    testWidgets('粘贴整段 Cookie → 存裸值 + 回显掩码；清除回匿名态', (WidgetTester tester) async {
      final MemorySecrets secrets = MemorySecrets();
      await pumpSettings(tester, secrets);

      await tester.tap(find.text('BDUSS 导入'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'BDUSS=$kFakeBduss; STOKEN=zzz',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(secrets.value, kFakeBduss, reason: '只存裸 BDUSS（不含前缀与 Cookie 其余键）');
      expect(find.text('BDUSS 已导入'), findsOneWidget);
      expect(find.textContaining('aBcDeF……sTuV'), findsOneWidget);
      await dismissSnackBars(tester);

      await tester.tap(find.text('清除'));
      await tester.pumpAndSettle();
      expect(secrets.value, isNull);
      expect(find.text('BDUSS 导入'), findsOneWidget);
      await dismissSnackBars(tester);
    });

    testWidgets('非法输入：拒绝保存并如实提示', (WidgetTester tester) async {
      final MemorySecrets secrets = MemorySecrets();
      await pumpSettings(tester, secrets);

      await tester.tap(find.text('BDUSS 导入'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '12345');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(secrets.value, isNull);
      expect(find.textContaining('看起来不是 BDUSS'), findsOneWidget);
      await dismissSnackBars(tester);
    });
  });

  group('并发分段按档位（需求 5）', () {
    testWidgets('匿名档上限 3（分段 2/3）；导入后上限 4（分段 2/3/4）', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester, MemorySecrets());
      expect(find.textContaining('上限 3（匿名档）'), findsOneWidget);
      expect(find.textContaining('上限 4（BDUSS 档）'), findsNothing);

      final MemorySecrets secrets = MemorySecrets(kFakeBduss);
      await pumpSettings(tester, secrets);
      expect(find.textContaining('上限 4（BDUSS 档）'), findsOneWidget);
      expect(find.textContaining('上限 3（匿名档）'), findsNothing);
      await dismissSnackBars(tester);
    });
  });

  group('设置页「测试」按钮（需求 5：initNickname 有效性探测）', () {
    Future<void> pumpWithProbe(
      WidgetTester tester,
      MemorySecrets secrets,
      Dio probeDio,
    ) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        testApp(
          FakeBookRepository(library: demoLibrary()),
          home: const SettingsPage(),
          extraOverrides: <Override>[
            secretStoreProvider.overrideWithValue(secrets),
            tiebaAccountProbeProvider.overrideWithValue(
              TiebaAccountProbe(dio: probeDio),
            ),
            ...updateTestOverrides(
              adapter: ScriptedAdapter(<String, ScriptedResponse>{}),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('有效：toast 显示昵称；请求体带 BDUSS 且 sign 与 App 同源', (
      WidgetTester tester,
    ) async {
      final ScriptedAdapter
      adapter = ScriptedAdapter(<String, ScriptedResponse>{
        kInitNicknameUrl: const ScriptedResponse(
          '{"error_code":0,"user_info":{"user_name":"u1","name_show":"测试昵称","tieba_uid":9}}',
        ),
      });
      final MemorySecrets secrets = MemorySecrets(kFakeBduss);
      await pumpWithProbe(tester, secrets, scriptedDio(adapter));

      await tester.tap(find.text('测试'));
      await tester.pumpAndSettle();

      expect(find.textContaining('BDUSS 有效 · 测试昵称'), findsOneWidget);
      final String body = adapter.requests.single.data as String;
      final Map<String, String> params = <String, String>{};
      for (final String pair in body.split('&')) {
        final int eq = pair.indexOf('=');
        params[Uri.decodeQueryComponent(pair.substring(0, eq))] =
            Uri.decodeQueryComponent(pair.substring(eq + 1));
      }
      expect(params['BDUSS'], kFakeBduss);
      final String sign = params.remove('sign')!;
      expect(sign, computeFormSign(params));
      await dismissSnackBars(tester);
    });

    testWidgets('失效：toast 无效 + 行内转「已失效 · 请重新导入」并落标记', (
      WidgetTester tester,
    ) async {
      final ScriptedAdapter adapter =
          ScriptedAdapter(<String, ScriptedResponse>{
            kInitNicknameUrl: const ScriptedResponse(
              '{"error_code":110001,"error_msg":"请先登录"}',
            ),
          });
      final MemorySecrets secrets = MemorySecrets(kFakeBduss);
      await pumpWithProbe(tester, secrets, scriptedDio(adapter));

      await tester.tap(find.text('测试'));
      await tester.pumpAndSettle();

      expect(find.textContaining('BDUSS 无效或已失效'), findsOneWidget);
      expect(
        secrets.extra[kSecretKeyBdussInvalid],
        '1',
        reason: '测试失效与采集侧自动降级同源标记',
      );
      expect(find.text('BDUSS 已失效'), findsOneWidget);
      expect(find.text('已失效 · 请重新导入（当前按匿名档运行）'), findsOneWidget);
      await dismissSnackBars(tester);

      // 重新导入：清除标记 → 回到「BDUSS 已导入」。
      await tester.tap(find.text('BDUSS 已失效'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), kFakeBduss);
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(secrets.extra[kSecretKeyBdussInvalid], isNull);
      expect(find.text('BDUSS 已导入'), findsOneWidget);
      await dismissSnackBars(tester);
    });

    testWidgets('进行中：按钮禁用 + 转圈；完成后恢复并出结果', (WidgetTester tester) async {
      final _GatedAdapter gate = _GatedAdapter();
      final Dio dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      )..httpClientAdapter = gate;
      await pumpWithProbe(tester, MemorySecrets(kFakeBduss), dio);

      await tester.tap(find.text('测试'));
      await tester.pump();
      expect(find.text('测试'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '清除'))
            .onPressed,
        isNull,
        reason: '测试进行中禁用清除',
      );

      gate.complete(
        '{"error_code":0,"user_info":{"user_name":"u2","name_show":"昵称C"}}',
      );
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('测试'), findsOneWidget);
      expect(find.textContaining('BDUSS 有效 · 昵称C'), findsOneWidget);
      await dismissSnackBars(tester);
    });
  });
}
