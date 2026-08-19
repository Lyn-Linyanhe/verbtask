import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 跨平台可写数据目录（Android/Windows 用系统应用数据目录，测试回退当前目录）。
class AppPaths {
  static Future<Directory> _base() async {
    try {
      final d = await getApplicationSupportDirectory();
      return Directory('${d.path}${Platform.pathSeparator}verb');
    } catch (_) {
      return Directory('${Directory.current.path}${Platform.pathSeparator}data');
    }
  }

  static Future<File> dataFile() async =>
      File('${(await _base()).path}${Platform.pathSeparator}verb_data.json');

  static Future<File> settingsFile() async =>
      File('${(await _base()).path}${Platform.pathSeparator}settings.json');
}
