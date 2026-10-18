/// 更新控制器测试（plain test()；ProviderContainer + 脚本化 dio，零 widget 零网络）。
///
/// 覆盖：启动静默检查调度（幂等 / 零延迟注入 / 不阻塞）、双源失败静默落 failed、
/// updateAvailableProvider 暴露口径、manualCheck 返回结果。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/update/update_controller.dart';
import 'package:booksift/core/update/update_service.dart';

import 'support.dart';

/// 轮询等待控制器落入指定状态（plain test 真实时钟；脚本化请求都是立即完成的微任务，
/// 正常几毫秒内收敛；落入其它终态立刻 fail 并带失败归类，便于定位脚本错误）。
Future<UpdateCheckState> waitStatus(
  ProviderContainer container,
  UpdateStatus expected, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final UpdateCheckState state = container.read(updateControllerProvider);
    if (state.status == expected) return state;
    if (state.status != UpdateStatus.idle &&
        state.status != UpdateStatus.checking) {
      fail(
        '状态落入 ${state.status}（期望 $expected）：'
        'primary=${state.result?.primaryFailure} fallback=${state.result?.fallbackFailure}',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  fail(
    '等待状态 $expected 超时；当前 ${container.read(updateControllerProvider).status}',
  );
}

void main() {
  test('初始化 = idle，build() 无副作用（不自行发请求/起检查）', () {
    final ScriptedAdapter adapter = ScriptedAdapter(
      <String, ScriptedResponse>{},
    );
    final ProviderContainer container = ProviderContainer(
      overrides: updateTestOverrides(adapter: adapter),
    );
    addTearDown(container.dispose);
    expect(container.read(updateControllerProvider).status, UpdateStatus.idle);
    expect(container.read(updateAvailableProvider), isNull);
    expect(adapter.requests, isEmpty);
  });

  test('启动静默检查：ensureStartupCheckScheduled 幂等，零延迟后落 updateAvailable', () async {
    final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
      kControllerGithubUrl: ScriptedResponse(
        githubReleaseJson(withSha256Asset: false),
      ),
    });
    final ProviderContainer container = ProviderContainer(
      overrides: updateTestOverrides(adapter: adapter),
    );
    addTearDown(container.dispose);

    final UpdateController controller = container.read(
      updateControllerProvider.notifier,
    );
    controller.ensureStartupCheckScheduled();
    controller.ensureStartupCheckScheduled(); // 幂等：第二次 no-op（不会双份请求）

    final UpdateCheckState state = await waitStatus(
      container,
      UpdateStatus.updateAvailable,
    );
    expect(state.info?.version, '1.1.0');
    expect(state.info?.source, UpdateSourceKind.github);
    expect(container.read(updateAvailableProvider)?.version, '1.1.0');
    expect(adapter.requestedUrls, <String>[kControllerGithubUrl]);
  });

  test('双源失败 → failed 静默：updateAvailableProvider null，不抛异常', () async {
    final InMemoryUpdateSettingsStore store = InMemoryUpdateSettingsStore()
      ..values[kUpdateFallbackUrlKey] = kTestFallbackUrl;
    final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
      kControllerGithubUrl: ScriptedResponse.networkError(),
      kTestFallbackUrl: const ScriptedResponse(
        '{"message":"gone"}',
        status: 404,
      ),
    });
    final ProviderContainer container = ProviderContainer(
      overrides: updateTestOverrides(adapter: adapter, store: store),
    );
    addTearDown(container.dispose);

    container
        .read(updateControllerProvider.notifier)
        .ensureStartupCheckScheduled();
    final UpdateCheckState state = await waitStatus(
      container,
      UpdateStatus.failed,
    );
    expect(state.result?.primaryFailure?.kind, UpdateFetchFailureKind.network);
    expect(
      state.result?.fallbackFailure?.kind,
      UpdateFetchFailureKind.notFound,
    );
    expect(container.read(updateAvailableProvider), isNull);
    expect(adapter.requestedUrls, <String>[
      kControllerGithubUrl,
      kTestFallbackUrl,
    ]);
  });

  test('主源 403 + 已配置备源 200 → 静默检查自动切源成功', () async {
    final InMemoryUpdateSettingsStore store = InMemoryUpdateSettingsStore()
      ..values[kUpdateFallbackUrlKey] = kTestFallbackUrl;
    final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
      kControllerGithubUrl: const ScriptedResponse(
        '{"message":"rate limit"}',
        status: 403,
      ),
      kTestFallbackUrl: ScriptedResponse(versionJson()),
    });
    final ProviderContainer container = ProviderContainer(
      overrides: updateTestOverrides(adapter: adapter, store: store),
    );
    addTearDown(container.dispose);

    container
        .read(updateControllerProvider.notifier)
        .ensureStartupCheckScheduled();
    final UpdateCheckState state = await waitStatus(
      container,
      UpdateStatus.updateAvailable,
    );
    expect(state.info?.source, UpdateSourceKind.staticJson);
    expect(state.info?.versionCode, 120);
  });

  test('备源未配置（出厂缺省）→ 仅主源单请求', () async {
    final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
      kControllerGithubUrl: ScriptedResponse.networkError(),
    });
    final ProviderContainer container = ProviderContainer(
      overrides: updateTestOverrides(adapter: adapter),
    );
    addTearDown(container.dispose);

    final UpdateCheckResult result = await container
        .read(updateControllerProvider.notifier)
        .manualCheck();
    expect(result.outcome, UpdateOutcome.failed);
    expect(result.fallbackFailure, isNull);
    expect(adapter.requestedUrls, <String>[kControllerGithubUrl]);
    expect(
      container.read(updateControllerProvider).status,
      UpdateStatus.failed,
    );
  });

  test('manualCheck 返回结果（upToDate 口径：tag == 本地版本）', () async {
    final ScriptedAdapter adapter = ScriptedAdapter(<String, ScriptedResponse>{
      kControllerGithubUrl: ScriptedResponse(
        githubReleaseJson(tag: 'v1.0.0', withSha256Asset: false),
      ),
    });
    final ProviderContainer container = ProviderContainer(
      overrides: updateTestOverrides(adapter: adapter),
    );
    addTearDown(container.dispose);

    final UpdateCheckResult result = await container
        .read(updateControllerProvider.notifier)
        .manualCheck();
    expect(result.outcome, UpdateOutcome.upToDate);
    expect(result.info?.version, '1.0.0');
    expect(container.read(updateAvailableProvider), isNull);
  });
}
