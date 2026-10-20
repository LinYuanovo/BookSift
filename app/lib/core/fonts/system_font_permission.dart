import 'package:flutter/services.dart';

/// Android 读取系统/用户字体目录遇 EACCES 时的权限请求端口。
///
/// 其他平台不使用；测试可注入 [NoopSystemFontPermissionRequester]。
abstract interface class SystemFontPermissionRequester {
  /// 返回 true = 权限已授予，可重试目录扫描；false = 用户拒绝或平台不支持。
  Future<bool> requestReadFontsPermission();
}

/// Android MethodChannel 实现（原生侧 MainActivity 负责 requestPermissions）。
final class MethodChannelSystemFontPermissionRequester
    implements SystemFontPermissionRequester {
  const MethodChannelSystemFontPermissionRequester();

  static const MethodChannel _channel = MethodChannel('booksift/system_fonts');

  @override
  Future<bool> requestReadFontsPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestReadPermission') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

/// 无权限需求的平台（非 Android / 测试）默认实现。
final class NoopSystemFontPermissionRequester implements SystemFontPermissionRequester {
  const NoopSystemFontPermissionRequester();

  @override
  Future<bool> requestReadFontsPermission() async => false;
}
