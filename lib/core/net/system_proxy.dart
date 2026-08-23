import 'dart:io';

/// 读取系统代理，供 HTTP 客户端使用。
/// Flutter/Dart 的 HttpClient 默认「不」读取 Windows 系统代理，
/// 导致需要代理的服务(如 OpenAI)直连超时。这里统一解析：
/// 1) 环境变量 HTTPS_PROXY/HTTP_PROXY；2) Windows 注册表里的系统代理。
class SystemProxy {
  static String? _cached;
  static bool _resolved = false;

  /// 返回形如 "host:port" 的代理地址；无代理返回 null。
  static String? get current {
    if (_resolved) return _cached;
    _cached = _resolve();
    _resolved = true;
    return _cached;
  }

  /// 拿到代理地址字符串 → 可直接用于 findProxy 回调。
  static String findProxy(Uri url) {
    final p = current;
    return p == null ? 'DIRECT' : 'PROXY $p';
  }

  static String? _resolve() {
    if (!Platform.isWindows) return _envProxy();
    // Windows：先看环境变量，再看注册表系统代理。
    final env = _envProxy();
    if (env != null) return env;
    return _registryProxy();
  }

  static String? _envProxy() {
    final e = Platform.environment;
    for (final k in [
      'HTTPS_PROXY',
      'https_proxy',
      'HTTP_PROXY',
      'http_proxy'
    ]) {
      final v = e[k];
      if (v != null && v.trim().isNotEmpty) return _normalize(v.trim());
    }
    return null;
  }

  static String? _registryProxy() {
    try {
      final key =
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';
      // ProxyEnable=1 才启用
      final en = Process.runSync('reg', ['query', key, '/v', 'ProxyEnable']);
      if (!en.stdout.toString().contains('0x1')) return null;
      final sv = Process.runSync('reg', ['query', key, '/v', 'ProxyServer']);
      final m = RegExp(r'ProxyServer\s+REG_SZ\s+(\S+)')
          .firstMatch(sv.stdout.toString());
      return m == null ? null : _normalize(m.group(1)!);
    } catch (_) {
      return null;
    }
  }

  /// 处理可能带协议前缀(如 "http://")或多种代理的字符串。
  static String? _normalize(String raw) {
    // 某些系统代理是 "http=host:port;https=host:port" 形式
    if (raw.contains('=')) {
      for (final part in raw.split(';')) {
        final kv = part.split('=');
        if (kv.length == 2) {
          final k = kv[0].toLowerCase().trim();
          if (k == 'http' || k == 'https') return kv[1].trim();
        }
      }
      return null;
    }
    var s = raw.trim();
    if (s.toLowerCase().startsWith('http://')) {
      s = s.substring(7);
    } else if (s.toLowerCase().startsWith('https://')) {
      s = s.substring(8);
    }
    return s.isEmpty ? null : s;
  }
}
