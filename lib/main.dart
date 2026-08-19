import 'dart:io';
import 'package:flutter/material.dart';
import 'app/windows_tray.dart';
import 'core/notifications/app_notifications.dart';
import 'core/settings/local_settings.dart';
import 'core/settings/settings_controller.dart';
import 'core/storage/app_paths.dart';
import 'core/storage/file_repository.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = FileRepository(await AppPaths.dataFile());
  final settings = SettingsController(
    LocalSettings(await AppPaths.settingsFile()),
    repo,
  );
  await AppNotifications.init(repo);
  runApp(VerbApp(repository: repo, settings: settings));
  if (Platform.isWindows) {
    // 托盘在首帧后初始化（需要 plugin channel 就绪）
    WindowsTray.init();
  }
}
