import 'dart:io';

import '../collector/network_gate_io.dart';
import '../collector/worker.dart';

final class HostNetworkGate implements NetworkGate {
  const HostNetworkGate({this.wifiProbe});

  final Future<bool> Function()? wifiProbe;

  @override
  Future<bool> isWifi() async {
    final Future<bool> Function()? probe = wifiProbe;
    if (probe != null) return probe();
    if (Platform.isLinux) return isLinuxWifiDefaultRoute();
    if (!Platform.isWindows) return false;

    Process? process;
    try {
      final Process started = await Process.start(
        'powershell.exe',
        const <String>[
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          r'''
$routes = @(Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue)
if ($routes.Count -eq 0) {
  $routes = @(Get-NetRoute -AddressFamily IPv6 -DestinationPrefix '::/0' -ErrorAction SilentlyContinue)
}
$best = $routes | Sort-Object {
  $family = $_.AddressFamily
  $_.RouteMetric + (Get-NetIPInterface -AddressFamily $family -InterfaceIndex $_.InterfaceIndex).InterfaceMetric
} | Select-Object -First 1
$adapter = if ($null -ne $best) { Get-NetAdapter -InterfaceIndex $best.InterfaceIndex -ErrorAction SilentlyContinue }
if ($null -ne $adapter -and $adapter.Status -eq 'Up' -and ($adapter.IfType -eq 71 -or $adapter.NdisPhysicalMedium -eq 9)) { 'true' } else { 'false' }
''',
        ],
        runInShell: false,
      );
      process = started;
      final Future<List<int>> stdout =
          started.stdout.expand((List<int> chunk) => chunk).toList();
      final Future<void> stderr = started.stderr.drain<void>();
      final int code = await started.exitCode.timeout(const Duration(seconds: 5));
      await stderr;
      return code == 0 && String.fromCharCodes(await stdout).trim() == 'true';
    } on Object {
      process?.kill();
      return false;
    }
  }
}
