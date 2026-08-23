import 'dart:async';
import '../storage/repository.dart';
import 'http_transport.dart';
import 'lan_discovery.dart';
import 'sync_engine.dart';

/// Android/任意端：快速同步 = 局域网发现 → 对每个 Server 执行一次双向同步。
class SyncController {
  static Object? lastError;

  static Future<int> quickSync(
    TaskRepository localRepo, {
    Future<List<LanPeer>> Function()? discover,
    Future<void> Function()? onSynced,
    FutureOr<void> Function(Object error)? onError,
    String token = '',
    String? cursor,
    Future<void> Function(String cursor)? onCursorCommitted,
  }) async {
    late final List<LanPeer> peers;
    try {
      peers = await (discover ?? LanDiscovery.discover)();
    } catch (error) {
      lastError = error;
      await onError?.call(error);
      rethrow;
    }
    if (peers.isEmpty) {
      final error = StateError('未发现可同步的 Windows 主机');
      lastError = error;
      await onError?.call(error);
      throw error;
    }
    var ran = 0;
    Object? firstError;
    for (final peer in peers) {
      try {
        final client = SyncClient(peer.uri, token: token);
        final engine = SyncEngine(localRepo);
        await runSync(
          client,
          engine,
          after: cursor,
          onCursorCommitted: onCursorCommitted,
        );
        ran++;
      } catch (error) {
        firstError ??= error;
        await onError?.call(error);
      }
    }
    if (ran > 0) {
      lastError = null;
      await onSynced?.call();
    } else if (firstError != null) {
      lastError = firstError;
      throw StateError('同步失败: $firstError');
    }
    return ran;
  }
}
