import 'dart:io';
import '../storage/repository.dart';
import 'http_transport.dart';
import 'lan_discovery.dart';

/// Windows 端=Server：启动 HTTP 同步服务 + 局域网发现应答。
class SyncHost {
  final SyncServer _server;
  final RawDatagramSocket _responder;
  final int httpPort;
  SyncHost._(this._server, this._responder) : httpPort = _server.port;

  static Future<SyncHost> start(TaskRepository repo,
      {String token = ''}) async {
    if (token.trim().isEmpty) {
      throw StateError('同步服务必须配置非空令牌');
    }
    final server = SyncServer(repo, token: token);
    await server.start(); // 绑定任意空闲端口
    final responder = await LanDiscovery.startResponder(httpPort: server.port);
    return SyncHost._(server, responder);
  }

  Future<void> stop() async {
    _responder.close();
    await _server.stop();
  }
}
