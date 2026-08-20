import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../settings/local_settings.dart';
import '../storage/repository.dart';
import '../storage/backup_service.dart';

/// 供设置页使用：读写设置 + 备份导出/导入 + LLM 配置。
class SettingsController extends ChangeNotifier {
  final LocalSettings settings;
  final BackupService backup;
  Future<void> _pendingSave = Future<void>.value();
  SettingsController(this.settings, TaskRepository repo)
      : backup = BackupService(repo);

  String get language => settings.language;
  set language(String v) {
    settings.language = v;
    _save();
  }

  String get llmBaseUrl => settings.llmBaseUrl;
  set llmBaseUrl(String v) {
    settings.llmBaseUrl = v;
    _save();
  }

  String get llmKey => settings.llmKey;
  set llmKey(String v) {
    settings.llmKey = v;
    _save();
  }

  int get llmEnabled => settings.llmEnabled;
  set llmEnabled(int v) {
    settings.llmEnabled = v;
    _save();
  }

  int get syncAutoIntervalMin => settings.syncAutoIntervalMin;
  set syncAutoIntervalMin(int v) {
    settings.syncAutoIntervalMin = v;
    _save();
  }

  bool get notifyDefaultReminderEnabled =>
      settings.notifyDefaultReminderEnabled;
  set notifyDefaultReminderEnabled(bool v) {
    settings.notifyDefaultReminderEnabled = v;
    _save();
  }

  int get notifyDefaultOffsetMin => settings.notifyDefaultOffsetMin;
  set notifyDefaultOffsetMin(int v) {
    settings.notifyDefaultOffsetMin = v;
    _save();
  }

  int? get defaultReminderOffsetMinutes =>
      notifyDefaultReminderEnabled ? notifyDefaultOffsetMin : null;

  ThemeMode get themeMode => switch (settings.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
  set themeMode(ThemeMode value) {
    settings.themeMode = value.name;
    _save();
  }

  bool get trayEnabled => settings.trayEnabled;
  set trayEnabled(bool v) {
    settings.trayEnabled = v;
    _save();
  }

  bool get autostartEnabled => settings.autostartEnabled;
  set autostartEnabled(bool v) {
    settings.autostartEnabled = v;
    _save();
  }

  Future<String> exportTo(File f) async {
    final json = await backup.exportJson();
    await f.parent.create(recursive: true);
    await f.writeAsString(json);
    return json;
  }

  Future<int> importFrom(File f) async {
    final json = await f.readAsString();
    return backup.importJson(json);
  }

  Future<void> exportCsvTo(File f) async {
    final csv = await backup.exportCsv();
    await f.parent.create(recursive: true);
    await f.writeAsString(csv);
  }

  Future<int> importCsvFrom(File f) async {
    final csv = await f.readAsString();
    return backup.importCsv(csv);
  }

  /// 等待此前由 setter 触发的设置写入完成。
  String get syncToken => settings.syncToken;
  set syncToken(String v) {
    settings.syncToken = v;
    _save();
  }

  /// 返回持久化的同步令牌；为空则生成一个并保存。
  String ensureSyncToken() {
    var t = settings.syncToken;
    if (t.isEmpty) {
      t = _randomToken();
      settings.syncToken = t;
      _save();
    }
    return t;
  }

  String _randomToken() {
    final rnd = Random.secure();
    return List.generate(
        32, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> flush() => _pendingSave;

  void _save() {
    _pendingSave = _pendingSave.then((_) => settings.save());
    notifyListeners();
  }
}
