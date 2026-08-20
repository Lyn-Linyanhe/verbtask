import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 局域网同步发现：Windows(Server) 应答探针；Android(Client) 广播发现。
class LanPeer {
  final String host;
  final int httpPort;
  LanPeer(this.host, this.httpPort);
  Uri get uri => Uri.parse('http://$host:$httpPort/');
  @override
  String toString() => '$host:$httpPort';
}

class LanDiscovery {
  static const String _probe = 'VERB_DISCOVER';
  static const int controlPort = 45999;

  /// Windows 端：在 [controlPort] 上应答“谁在”探针，返回自身 HTTP 端口。
  /// 返回 socket，调用方负责 close。
  static Future<RawDatagramSocket> startResponder(
      {required int httpPort}) async {
    final socket =
        await RawDatagramSocket.bind(InternetAddress.anyIPv4, controlPort);
    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = socket.receive();
      if (dg == null) return;
      if (utf8.decode(dg.data, allowMalformed: true).trim() == _probe) {
        socket.send(utf8.encode('VERB:$httpPort'), dg.address, dg.port);
      }
    });
    return socket;
  }

  /// Android 端：广播探针，收集局域网内应答者的主机与 HTTP 端口。
  /// [targets] 额外定向地址（测试/单网卡场景用）。
  static Future<List<LanPeer>> discover({
    Duration timeout = const Duration(seconds: 2),
    List<InternetAddress>? targets,
  }) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    final peers = <LanPeer>[];
    final done = Completer<void>();
    final probe = utf8.encode(_probe);
    final timer = Timer(timeout, () {
      if (!done.isCompleted) done.complete();
    });

    socket.listen((event) {
      if (!done.isCompleted && event == RawSocketEvent.read) {
        final dg = socket.receive();
        if (dg != null) {
          final msg = utf8.decode(dg.data, allowMalformed: true);
          if (msg.startsWith('VERB:')) {
            final port = int.tryParse(msg.substring('VERB:'.length).trim());
            if (port != null &&
                !peers.any((p) =>
                    p.httpPort == port && p.host == dg.address.address)) {
              peers.add(LanPeer(dg.address.address, port));
            }
          }
        }
      } else if (!done.isCompleted && event == RawSocketEvent.closed) {
        done.complete();
      }
    });

    try {
      socket.send(probe, InternetAddress('255.255.255.255'), controlPort);
    } catch (_) {}
    if (targets != null) {
      for (final t in targets) {
        try {
          socket.send(probe, t, controlPort);
        } catch (_) {}
      }
    }

    await done.future;
    timer.cancel();
    socket.close();
    return peers;
  }
}
