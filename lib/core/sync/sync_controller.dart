import '../storage/repository.dart';
import 'http_transport.dart';
import 'lan_discovery.dart';
import 'sync_engine.dart';

/// Android/任意端：快速同步 = 局域网发现 → 对每个 Server 执行一次双向同步。
class SyncController {
  static Future<int> quickSync(
    TaskRepository localRepo, {
    Future<List<LanPeer>> Function()? discover,
    Future<void> Function()? onSynced,
  }) async {
    final peers = await (discover ?? LanDiscovery.discover)();
    var ran = 0;
    for (final peer in peers) {
      try {
        final client = SyncClient(peer.uri);
        final engine = SyncEngine(localRepo);
        await runSync(client, engine);
        ran++;
      } catch (_) {
        // 单个节点失败不阻断其它节点
      }
    }
    if (ran > 0) await onSynced?.call();
    return ran;
  }
}
