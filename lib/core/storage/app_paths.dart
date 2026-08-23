import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 跨平台可写数据目录（Android/Windows 用系统应用数据目录，测试回退当前目录）。
class AppPaths {
  static Future<Directory> _base() async {
    late final Directory base;
    try {
      final d = await getApplicationSupportDirectory();
      base = Directory('${d.path}${Platform.pathSeparator}verb');
    } catch (_) {
      base =
          Directory('${Directory.current.path}${Platform.pathSeparator}data');
    }
    if (Platform.isWindows) {
      _migrateWindowsLegacyFiles(base);
    }
    return base;
  }

  static Future<File> dataFile() async =>
      File('${(await _base()).path}${Platform.pathSeparator}verb_data.json');

  static Future<File> settingsFile() async =>
      File('${(await _base()).path}${Platform.pathSeparator}settings.json');

  /// Migrates files from the pre-release Windows application-data folders.
  ///
  /// The current file always wins. A settings merge only fills keys missing
  /// from the current file, which preserves a newly generated sync token while
  /// keeping user-configured options from an older build.
  static void migrateLegacyFiles({
    required Directory current,
    required Directory legacy,
  }) {
    try {
      if (!legacy.existsSync()) return;
      current.createSync(recursive: true);
      _copyIfMissing(
        File('${current.path}${Platform.pathSeparator}verb_data.json'),
        File('${legacy.path}${Platform.pathSeparator}verb_data.json'),
      );
      _mergeMissingSettings(
        File('${current.path}${Platform.pathSeparator}settings.json'),
        File('${legacy.path}${Platform.pathSeparator}settings.json'),
      );
    } catch (_) {
      // A failed compatibility migration must never prevent startup.
    }
  }

  static void _migrateWindowsLegacyFiles(Directory current) {
    final appDataRoot = current.parent.parent;
    for (final legacy in [
      Directory('${appDataRoot.path}${Platform.pathSeparator}verb_app'
          '${Platform.pathSeparator}verb'),
      Directory('${appDataRoot.path}${Platform.pathSeparator}verb'),
    ]) {
      migrateLegacyFiles(current: current, legacy: legacy);
    }
  }

  static void _copyIfMissing(File target, File source) {
    if (!target.existsSync() && source.existsSync()) {
      source.copySync(target.path);
    }
  }

  static void _mergeMissingSettings(File target, File source) {
    if (!source.existsSync()) return;
    if (!target.existsSync()) {
      source.copySync(target.path);
      return;
    }
    final oldValue = jsonDecode(source.readAsStringSync());
    final currentValue = jsonDecode(target.readAsStringSync());
    if (oldValue is! Map || currentValue is! Map) return;
    final merged = Map<String, dynamic>.from(currentValue);
    var changed = false;
    for (final entry in Map<String, dynamic>.from(oldValue).entries) {
      if (!merged.containsKey(entry.key)) {
        merged[entry.key] = entry.value;
        changed = true;
      }
    }
    if (changed) target.writeAsStringSync(jsonEncode(merged));
  }
}
