import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/sync/lan_discovery.dart';

void main() {
  test('UDP 广播发现能定位局域网内的 Server', () async {
    final server = await LanDiscovery.startResponder(httpPort: 8181);
    try {
      final peers = await LanDiscovery.discover(
        timeout: const Duration(seconds: 2),
        targets: [InternetAddress.loopbackIPv4],
      );
      expect(peers, isNotEmpty);
      final found = peers.any((p) => p.httpPort == 8181);
      expect(found, isTrue, reason: '应发现 httpPort=8181 的 Server');
    } finally {
      server.close();
    }
  });
}
