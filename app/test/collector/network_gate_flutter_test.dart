import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/collector/network_gate_flutter.dart';
import 'package:booksift/collector/network_gate_io.dart';

void main() {
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(PlatformNetworkGate.channel, null);
  });

  for (final TargetPlatform platform in <TargetPlatform>[
    TargetPlatform.android,
    TargetPlatform.windows,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ]) {
    test('$platform queries the native active-network type', () async {
      debugDefaultTargetPlatformOverride = platform;
      String? method;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        PlatformNetworkGate.channel,
        (MethodCall call) async {
          method = call.method;
          return true;
        },
      );

      expect(await const PlatformNetworkGate().isWifi(), isTrue);
      expect(method, 'isWifi');
    });

    test('$platform fails closed when native network detection is unavailable', () async {
      debugDefaultTargetPlatformOverride = platform;
      expect(await const PlatformNetworkGate().isWifi(), isFalse);
    });
  }

  test('other platforms fail closed when network type is unavailable', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    expect(await const PlatformNetworkGate().isWifi(), isFalse);
  });

  test('Linux route probe accepts only an up default route with a wireless interface', () async {
    final Directory root = await Directory.systemTemp.createTemp('booksift_network_gate');
    addTearDown(() => root.delete(recursive: true));
    final Directory wireless = Directory('${root.path}/wlan0/wireless');
    await wireless.create(recursive: true);
    final File routes = File('${root.path}/route');
    await routes.writeAsString(
      'Iface Destination Gateway Flags RefCnt Use Metric Mask\n'
      'eth0 00000000 0101A8C0 0003 0 0 10 00000000\n'
      'wlan0 00000000 0101A8C0 0001 0 0 20 00000000\n',
    );

    expect(
      await isLinuxWifiDefaultRoute(
        routeFile: routes.path,
        sysClassNetwork: root.path,
      ),
      isFalse,
      reason: '选择最低 metric 的有线默认路由，不应误判成 Wi-Fi',
    );
    await routes.writeAsString(
      'Iface Destination Gateway Flags RefCnt Use Metric Mask\n'
      'eth0 00000000 0101A8C0 0003 0 0 30 00000000\n'
      'wlan0 00000000 0101A8C0 0001 0 0 20 00000000\n',
    );
    expect(
      await isLinuxWifiDefaultRoute(
        routeFile: routes.path,
        sysClassNetwork: root.path,
      ),
      isTrue,
    );

    final File ipv6Routes = File('${root.path}/ipv6_route');
    await routes.writeAsString(
      'Iface Destination Gateway Flags RefCnt Use Metric Mask\n',
    );
    await ipv6Routes.writeAsString(
      '00000000000000000000000000000000 00 00000000000000000000000000000000 00 '
      '00000000000000000000000000000000 00000014 00000000 00000000 00000001 wlan0\n',
    );
    expect(
      await isLinuxWifiDefaultRoute(
        routeFile: routes.path,
        ipv6RouteFile: ipv6Routes.path,
        sysClassNetwork: root.path,
      ),
      isTrue,
      reason: 'IPv4 无默认路由时应回退 IPv6 默认路由',
    );
    await ipv6Routes.writeAsString(
      '00000000000000000000000000000000 00 00000000000000000000000000000000 00 '
      '00000000000000000000000000000000 00000014 00000000 00000000 00000001 eth0\n',
    );
    expect(
      await isLinuxWifiDefaultRoute(
        routeFile: routes.path,
        ipv6RouteFile: ipv6Routes.path,
        sysClassNetwork: root.path,
      ),
      isFalse,
      reason: 'IPv6 默认路由不可用时应判定为非 Wi-Fi',
    );
  });
}
