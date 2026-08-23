import 'dart:convert';
import 'dart:io';

/// 本地设置：持久化为 JSON 文件。无账号、纯本地。
class LocalSettings {
  final File? file;
  final bool _persistent;
  final Map<String, Object?> _m = {};
  LocalSettings(this.file) : _persistent = true {
    final target = file;
    if (target != null && target.existsSync()) {
      try {
        final root =
            jsonDecode(target.readAsStringSync()) as Map<String, dynamic>;
        _m.addAll(root);
      } catch (_) {}
    }
  }

  /// 用于嵌入式 UI 测试或临时预览；不会把设置写入当前目录或系统根目录。
  LocalSettings.inMemory()
      : file = null,
        _persistent = false;

  String get language => (_m['language'] as String?) ?? 'zh';
  set language(String v) => _m['language'] = v;

  String get llmBaseUrl => (_m['llmBaseUrl'] as String?) ?? '';
  set llmBaseUrl(String v) => _m['llmBaseUrl'] = v;

  String get llmKey => (_m['llmKey'] as String?) ?? '';
  set llmKey(String v) => _m['llmKey'] = v;

  int get llmEnabled => (_m['llmEnabled'] as num?)?.toInt() ?? 0;
  set llmEnabled(int v) => _m['llmEnabled'] = v;
  String get llmModel => (_m['llmModel'] as String?) ?? '';
  set llmModel(String v) => _m['llmModel'] = v;

  int get syncAutoIntervalMin =>
      (_m['syncAutoIntervalMin'] as num?)?.toInt() ?? 30;
  set syncAutoIntervalMin(int v) => _m['syncAutoIntervalMin'] = v;

  bool get notifyDefaultReminderEnabled =>
      (_m['notifyDefaultReminderEnabled'] as bool?) ?? true;
  set notifyDefaultReminderEnabled(bool v) =>
      _m['notifyDefaultReminderEnabled'] = v;

  int get notifyDefaultOffsetMin {
    final value = (_m['notifyDefaultOffsetMin'] as num?)?.toInt() ?? -30;
    return value == 0 ? 0 : -value.abs();
  }

  set notifyDefaultOffsetMin(int v) =>
      _m['notifyDefaultOffsetMin'] = v == 0 ? 0 : -v.abs();

  String get themeMode => (_m['themeMode'] as String?) ?? 'system';
  set themeMode(String v) => _m['themeMode'] = v;

  bool get trayEnabled => (_m['trayEnabled'] as bool?) ?? true;
  set trayEnabled(bool v) => _m['trayEnabled'] = v;

  bool get autostartEnabled => (_m['autostartEnabled'] as bool?) ?? true;
  set autostartEnabled(bool v) => _m['autostartEnabled'] = v;
  bool get alwaysOnTop => (_m['alwaysOnTop'] as bool?) ?? false;
  set alwaysOnTop(bool v) => _m['alwaysOnTop'] = v;

  String get syncToken => (_m['syncToken'] as String?) ?? '';
  set syncToken(String v) => _m['syncToken'] = v;

  String get syncCursor => (_m['syncCursor'] as String?) ?? '';
  set syncCursor(String v) => _m['syncCursor'] = v;

  String get syncLastStatus => (_m['syncLastStatus'] as String?) ?? 'idle';
  set syncLastStatus(String v) => _m['syncLastStatus'] = v;

  String get syncLastError => (_m['syncLastError'] as String?) ?? '';
  set syncLastError(String v) => _m['syncLastError'] = v;

  String get syncLastAt => (_m['syncLastAt'] as String?) ?? '';
  set syncLastAt(String v) => _m['syncLastAt'] = v;

  Future<void> save() async {
    if (!_persistent || file == null) return;
    await file!.parent.create(recursive: true);
    await file!.writeAsString(jsonEncode(_m));
  }
}
