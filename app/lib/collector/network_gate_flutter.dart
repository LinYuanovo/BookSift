import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart';

import 'network_gate_io.dart';
import 'worker.dart';

final class PlatformNetworkGate implements NetworkGate {
  const PlatformNetworkGate();

  static const MethodChannel channel = MethodChannel('booksift/network');

  @override
  Future<bool> isWifi() async {
    if (defaultTargetPlatform == TargetPlatform.linux && Platform.isLinux) {
      return isLinuxWifiDefaultRoute();
    }
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.windows &&
        defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return false;
    }
    try {
      return await channel
              .invokeMethod<bool>('isWifi')
              .timeout(const Duration(seconds: 5)) ??
          false;
    } on TimeoutException {
      return false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
