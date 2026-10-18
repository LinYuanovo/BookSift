/// 备源 URL 持久化测试（plain test()；drift 内存库 = TESTING.md §3.2 允许的真实 IO 档，
/// NativeDatabase.memory() 在当前 isolate 同步执行，不落盘、不触 path_provider）。
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/update/update_controller.dart';
import 'package:booksift/data/db/app_database.dart';

import 'support.dart';

void main() {
  test('DriftUpdateSettingsStore：settings 键 update_fallback_url 往返', () async {
    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final DriftUpdateSettingsStore store = DriftUpdateSettingsStore(db);

    expect(await store.read(kUpdateFallbackUrlKey), isNull); // 出厂缺省 = 未配置
    await store.write(
      kUpdateFallbackUrlKey,
      'https://cdn.example.com/version.json',
    );
    expect(
      await store.read(kUpdateFallbackUrlKey),
      'https://cdn.example.com/version.json',
    );
    await store.write(kUpdateFallbackUrlKey, ''); // 覆盖写 = 恢复缺省
    expect(await store.read(kUpdateFallbackUrlKey), '');
  });

  test(
    'UpdateSettingsController.setFallbackUrl：trim 后写 store + invalidate 读取侧',
    () async {
      final InMemoryUpdateSettingsStore store = InMemoryUpdateSettingsStore();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          updateSettingsStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(updateFallbackUrlProvider.future), '');

      await container
          .read(updateSettingsControllerProvider)
          .setFallbackUrl('  https://a.example/version.json ');
      expect(
        store.values[kUpdateFallbackUrlKey],
        'https://a.example/version.json',
      );
      expect(
        await container.read(updateFallbackUrlProvider.future),
        'https://a.example/version.json',
      );

      await container.read(updateSettingsControllerProvider).setFallbackUrl('');
      expect(await container.read(updateFallbackUrlProvider.future), '');
    },
  );

  test('isValidFallbackUrl：空 = 合法（恢复缺省）；http(s) 绝对 = 合法；其余非法', () {
    expect(isValidFallbackUrl(''), isTrue);
    expect(isValidFallbackUrl('   '), isTrue);
    expect(isValidFallbackUrl('https://a.example/version.json'), isTrue);
    expect(isValidFallbackUrl('http://a.example/version.json'), isTrue);
    expect(isValidFallbackUrl('ftp://a.example/version.json'), isFalse);
    expect(isValidFallbackUrl('/relative/version.json'), isFalse);
    expect(isValidFallbackUrl('不是 URL'), isFalse);
  });
}
