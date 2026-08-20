import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'app/windows_tray.dart';
import 'app/window_control.dart';
import 'app/navigation.dart';
import 'app/open_task.dart';
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
  final syncToken = settings.ensureSyncToken();
  runApp(VerbApp(
    repository: repo,
    settings: settings,
    onQuickSync: () => SyncController.quickSync(
      repo,
      token: syncToken,
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
    onNotificationTap: (taskId) {
      if (taskId == null) return;
      if (Platform.isWindows) {
        windowManager.show().then((_) => windowManager.focus());
      }
      openTaskById(repo, taskId, navigatorKey: appNavigatorKey);
    },
  ));
  unawaited(BackgroundSync.init().catchError((_) {}));
  if (Platform.isWindows) {
    WindowsTray.init(enabled: settings.trayEnabled);
    WindowControl.setAlwaysOnTop(settings.alwaysOnTop);
    SyncHost.start(repo, token: settings.syncToken)
        .then((_) {}, onError: (_) {});
  }
}


