/// BDUSS 凭证（贴吧登录态 Cookie 值）的本地存储与解析。
///
/// 合规口径（原型 §11.2 / about_page 声明）：**只**存设备本地系统加密存储
/// （flutter_secure_storage：Windows = Credential Manager，Android = Keystore 加密
/// SharedPreferences），不进 settings 表、不写日志、不上传；随时可清除。
///
/// 用途（§8.11）：请求带账号身份 → 每日配额 300 → 600、间隔放宽 1.0–2.0s、
/// 并发上限 3 → 4；匿名档行为一字不变。
/// 存储键固定为 [kSecretKeyBduss]（裸 BDUSS）+ [kSecretKeyBdussInvalid]（失效标记）。
///
/// 解析/掩码与存储键定义在纯 Dart 的 `bduss_format.dart`（headless CLI 复用同一口径），
/// 这里 re-export 保持既有 `import 'bduss.dart'` 调用点不变。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'bduss_format.dart';

export 'bduss_format.dart'
    show kSecretKeyBduss, kSecretKeyBdussInvalid, parseBdussInput, maskBduss;

/// 机密读写端口（唯一实现走 flutter_secure_storage；测试注入内存实现，
/// 避免 testWidgets 里碰平台通道）。
abstract interface class SecretStore {
  Future<String?> read(String key);

  /// [value] 为 null = 删除该键。
  Future<void> write(String key, String? value);
}

/// flutter_secure_storage 实现（设备本地系统加密存储）。
class SecureStorageSecrets implements SecretStore {
  const SecureStorageSecrets([this.storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage storage;

  @override
  Future<String?> read(String key) => storage.read(key: key);

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      await storage.delete(key: key);
      return;
    }
    await storage.write(key: key, value: value);
  }
}

/// 机密存储端口（测试可 override 为内存实现）。
final Provider<SecretStore> secretStoreProvider = Provider<SecretStore>(
  (Ref ref) => const SecureStorageSecrets(),
);

/// 当前 BDUSS：null = 匿名模式。读取失败（首启竞态 / 平台通道不可用）一律回落 null，
/// 与 collectSettingsProvider 同策略——不阻断 UI，也不改变匿名档行为。
final FutureProvider<String?> bdussProvider = FutureProvider<String?>((Ref ref) async {
  try {
    final String? raw = await ref.watch(secretStoreProvider).read(kSecretKeyBduss);
    return (raw ?? '').isEmpty ? null : raw;
  } catch (_) {
    return null;
  }
});

/// 凭证是否已标记失效（存储键 [kSecretKeyBdussInvalid]；读取失败一律回落 false）。
///
/// 失效 = 采集/在线搜索命中「登录态失效」特征后自动降级匿名档（需求 5，§8.10）；
/// 设置页据此显示「已失效 · 请重新导入」。[BdussController.save]/[clear] 会清标记。
final FutureProvider<bool> bdussInvalidProvider = FutureProvider<bool>((Ref ref) async {
  try {
    final String? raw = await ref.watch(secretStoreProvider).read(kSecretKeyBdussInvalid);
    return (raw ?? '').isNotEmpty;
  } catch (_) {
    return false;
  }
});

/// 生效凭证（全装配链路的唯一读取口径）：已标记失效 → null（按匿名档运行）。
/// 其余消费方（tiebaApiProvider / 采集控制器 / 账号徽标）都读这个而不是
/// [bdussProvider]，失效降级才不会漏过某一条链路。
final FutureProvider<String?> effectiveBdussProvider = FutureProvider<String?>((Ref ref) async {
  if (await ref.watch(bdussInvalidProvider.future)) {
    return null;
  }
  return ref.watch(bdussProvider.future);
});

/// BDUSS 写入（设置页「BDUSS 导入」消费；写后 invalidate 读取侧 → 采集装配随之换客户端）。
class BdussController {
  const BdussController(this._ref);

  final Ref _ref;

  /// 保存（入参应为 [parseBdussInput] 规范化后的值）。重新导入即清除失效标记。
  Future<void> save(String bduss) async {
    final SecretStore store = _ref.read(secretStoreProvider);
    await store.write(kSecretKeyBduss, bduss);
    await store.write(kSecretKeyBdussInvalid, null);
    _ref.invalidate(bdussProvider);
    _ref.invalidate(bdussInvalidProvider);
  }

  /// 清除（回匿名档），一并清失效标记。
  Future<void> clear() async {
    final SecretStore store = _ref.read(secretStoreProvider);
    await store.write(kSecretKeyBduss, null);
    await store.write(kSecretKeyBdussInvalid, null);
    _ref.invalidate(bdussProvider);
    _ref.invalidate(bdussInvalidProvider);
  }

  /// 标记凭证已失效（采集/在线搜索命中登录态失效时由装配侧调用；不删凭证本身）。
  /// 幂等：返回 true = 本次是**新**标记（UI 可据此只提示一次）。
  Future<bool> markInvalid() async {
    final SecretStore store = _ref.read(secretStoreProvider);
    final bool already = ((await store.read(kSecretKeyBdussInvalid)) ?? '').isNotEmpty;
    if (!already) {
      await store.write(kSecretKeyBdussInvalid, '1');
    }
    _ref.invalidate(bdussInvalidProvider);
    return !already;
  }
}

final Provider<BdussController> bdussControllerProvider =
    Provider<BdussController>(BdussController.new);
