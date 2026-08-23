import 'dart:io';

/// Windows 开机自启：通过 HKCU Run 注册表键实现（无需管理员权限）。
/// 可开启/关闭/查询，异常兜底不崩溃。
class Autostart {
  static const _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _valueName = 'VerbTask';

  /// `Run` 注册表值由命令行解析，路径含空格时必须整体加引号。
  static String commandForExecutable(String executable) =>
      '"${executable.replaceAll('"', r'\"')}"';

  /// 设置/取消开机自启。enabled=true 写入当前可执行文件路径。
  static Future<bool> setEnabled(bool enabled) async {
    if (!Platform.isWindows) return true;
    try {
      final exe = Platform.resolvedExecutable;
      late final ProcessResult result;
      if (enabled) {
        result = await Process.run('reg', [
          'add',
          _runKey,
          '/v',
          _valueName,
          '/t',
          'REG_SZ',
          '/d',
          commandForExecutable(exe),
          '/f',
        ]);
      } else {
        result = await Process.run(
            'reg', ['delete', _runKey, '/v', _valueName, '/f']);
      }
      // `reg delete` also returns non-zero when the value was already absent;
      // disabling an already-disabled option is still a successful state.
      if (!enabled && result.exitCode != 0) {
        final stderr = result.stderr.toString().toLowerCase();
        if (stderr.contains('unable to find') ||
            stderr.contains('cannot find')) {
          return true;
        }
      }
      return commandSucceeded(result);
    } catch (_) {}
    return false;
  }

  static bool commandSucceeded(ProcessResult result) => result.exitCode == 0;

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
