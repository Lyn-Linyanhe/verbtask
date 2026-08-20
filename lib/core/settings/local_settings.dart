import 'dart:convert';
import 'dart:io';

/// 本地设置：持久化为 JSON 文件。无账号、纯本地。
class LocalSettings {
  final File file;
  final Map<String, Object?> _m = {};
  LocalSettings(this.file) {
    if (file.existsSync()) {
      try {
        final root =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        _m.addAll(root);
      } catch (_) {}
    }
  }

  String get language => (_m['language'] as String?) ?? 'zh';
  set language(String v) => _m['language'] = v;

  String get llmBaseUrl => (_m['llmBaseUrl'] as String?) ?? '';
  set llmBaseUrl(String v) => _m['llmBaseUrl'] = v;

  String get llmKey => (_m['llmKey'] as String?) ?? '';
  set llmKey(String v) => _m['llmKey'] = v;

  int get llmEnabled => (_m['llmEnabled'] as num?)?.toInt() ?? 0;
  set llmEnabled(int v) => _m['llmEnabled'] = v;

  int get syncAutoIntervalMin =>
      (_m['syncAutoIntervalMin'] as num?)?.toInt() ?? 30;
  set syncAutoIntervalMin(int v) => _m['syncAutoIntervalMin'] = v;

  bool get notifyDefaultReminderEnabled =>
      (_m['notifyDefaultReminderEnabled'] as bool?) ?? true;
  set notifyDefaultReminderEnabled(bool v) =>
      _m['notifyDefaultReminderEnabled'] = v;

  int get notifyDefaultOffsetMin =>
      (_m['notifyDefaultOffsetMin'] as num?)?.toInt() ?? -30;
  set notifyDefaultOffsetMin(int v) => _m['notifyDefaultOffsetMin'] = v;

  String get themeMode => (_m['themeMode'] as String?) ?? 'system';
  set themeMode(String v) => _m['themeMode'] = v;

  bool get trayEnabled => (_m['trayEnabled'] as bool?) ?? true;
  set trayEnabled(bool v) => _m['trayEnabled'] = v;

  bool get autostartEnabled => (_m['autostartEnabled'] as bool?) ?? true;
  set autostartEnabled(bool v) => _m['autostartEnabled'] = v;

  String get syncToken => (_m['syncToken'] as String?) ?? '';
  set syncToken(String v) => _m['syncToken'] = v;

  Future<void> save() async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(_m));
  }
}
