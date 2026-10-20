import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/headless/network_gate.dart';

void main() {
  test('host network probe result controls Wi-Fi availability', () async {
    expect(await HostNetworkGate(wifiProbe: () async => true).isWifi(), isTrue);
    expect(await HostNetworkGate(wifiProbe: () async => false).isWifi(), isFalse);
  });
}
