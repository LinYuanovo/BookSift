import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// 「原帖 ↗」外部跳转单一出口：Android 依次定向贴吧 App（官方 com.baidu.tieba →
/// 贴吧 Lite com.huanchengfly.tieba.post 的 http(s) intent-filter，MainActivity
/// MethodChannel 实现；都未安装由原生侧回落浏览器），其余平台直接系统浏览器。
const MethodChannel _externalLaunchChannel = MethodChannel('booksift/external_launch');

/// 打开原帖外链；返回是否成功交给某个外部应用。失败不抛（调用方按 false 提示）。
Future<bool> openThreadExternally(String url) async {
  final Uri? uri = Uri.tryParse(url);
  if (url.isEmpty || uri == null || !uri.hasAbsolutePath && !uri.hasAuthority) {
    return false;
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      final bool? viaApp = await _externalLaunchChannel
          .invokeMethod<bool>('openTiebaOrBrowser', <String, Object>{'url': url});
      if (viaApp == true) {
        return true;
      }
    } on MissingPluginException {
      // widget 测试 / 无原生宿主：落浏览器兜底路径。
    } on PlatformException {
      // 原生侧 startActivity 二次失败：落浏览器兜底路径。
    }
  }
  try {
    if (!await canLaunchUrl(uri)) {
      return false;
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object {
    return false;
  }
}

/// 带失败提示的调用封装（无可用应用时如实告知，不静默）。
Future<void> openThreadExternallyWithFeedback(BuildContext context, String url) async {
  final bool ok = await openThreadExternally(url);
  if (ok || !context.mounted) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('没有可打开原帖的应用')));
}
