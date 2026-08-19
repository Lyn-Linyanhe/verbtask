import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'app/windows_tray.dart';
import 'core/sync/background_sync.dart';
import 'core/sync/sync_controller.dart';
import 'core/sync/sync_host.dart';
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
  runApp(VerbApp(
    repository: repo,
    settings: settings,
    onQuickSync: () => SyncController.quickSync(
      repo,
      onSynced: () => AppNotifications.rescheduleAll(
        repo,
        defaultOffsetMinutes: settings.defaultReminderOffsetMinutes,
        initializeIfNeeded: true,
      ),
    ),
  ));
  unawaited(AppNotifications.init(
    repo,
    defaultOffsetMinutes: settings.defaultReminderOffsetMinutes,
  ));
  unawaited(BackgroundSync.init().catchError((_) {}));
  if (Platform.isWindows) {
    WindowsTray.init();
    SyncHost.start(repo).then((_) {}, onError: (_) {});
  }
}
