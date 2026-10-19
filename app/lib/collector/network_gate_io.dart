import 'dart:io';

Future<bool> isLinuxWifiDefaultRoute({
  String routeFile = '/proc/net/route',
  String ipv6RouteFile = '/proc/net/ipv6_route',
  String sysClassNetwork = '/sys/class/net',
}) async {
  final (String?, int?) ipv4 = await _bestIpv4DefaultRoute(routeFile);
  final (String?, int?) best = ipv4.$1 == null
      ? await _bestIpv6DefaultRoute(ipv6RouteFile)
      : ipv4;
  final String? interface = best.$1;
  if (interface == null) return false;
  return Directory('$sysClassNetwork/$interface/wireless').exists();
}

Future<(String?, int?)> _bestIpv4DefaultRoute(String routeFile) async {
  try {
    final List<String> lines = await File(routeFile).readAsLines();
    String? interface;
    int? bestMetric;
    for (final String line in lines.skip(1)) {
      final List<String> fields = line.trim().split(RegExp(r'\s+'));
      if (fields.length < 7 || fields[1] != '00000000') continue;
      final int? flags = int.tryParse(fields[3], radix: 16);
      final int? metric = int.tryParse(fields[6]);
      if (flags == null || metric == null || flags & 1 == 0) continue;
      if (bestMetric == null || metric < bestMetric) {
        interface = fields[0];
        bestMetric = metric;
      }
    }
    return (interface, bestMetric);
  } on FileSystemException {
    return (null, null);
  }
}

Future<(String?, int?)> _bestIpv6DefaultRoute(String routeFile) async {
  try {
    final List<String> lines = await File(routeFile).readAsLines();
    String? interface;
    int? bestMetric;
    for (final String line in lines) {
      final List<String> fields = line.trim().split(RegExp(r'\s+'));
      if (fields.length < 10 || fields[0] != '00000000000000000000000000000000') {
        continue;
      }
      final int? metric = int.tryParse(fields[5], radix: 16);
      final int? flags = int.tryParse(fields[8], radix: 16);
      if (metric == null || flags == null || flags & 1 == 0) continue;
      if (bestMetric == null || metric < bestMetric) {
        interface = fields[9];
        bestMetric = metric;
      }
    }
    return (interface, bestMetric);
  } on FileSystemException {
    return (null, null);
  }
}
