import 'dart:io';

/// Windows 开机自启：通过 HKCU Run 注册表键实现（无需管理员权限）。
/// 可开启/关闭/查询，异常兜底不崩溃。
class Autostart {
  static const _runKey =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _valueName = 'VerbTask';

  /// 设置/取消开机自启。enabled=true 写入当前可执行文件路径。
  static Future<void> setEnabled(bool enabled) async {
    if (!Platform.isWindows) return;
    try {
      final exe = Platform.resolvedExecutable;
      if (enabled) {
        await Process.run('reg', [
          'add', _runKey, '/v', _valueName, '/t', 'REG_SZ',
          '/d', '"$exe"', '/f',
        ]);
      } else {
        await Process.run('reg', ['delete', _runKey, '/v', _valueName, '/f']);
      }
    } catch (_) {}
  }

  /// 查询是否已启用。
  static Future<bool> isEnabled() async {
    if (!Platform.isWindows) return false;
    try {
      final r = await Process.run('reg', ['query', _runKey, '/v', _valueName]);
      return r.stdout.toString().contains(_valueName);
    } catch (_) {
      return false;
    }
  }
}
