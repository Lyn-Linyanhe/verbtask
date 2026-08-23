import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'app/windows_tray.dart';
import 'app/window_control.dart';
import 'app/navigation.dart';
import 'app/open_task.dart';
import 'app/autostart.dart';
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
  await settings.flush();
  Future<void> openNotificationTask(String taskId) async {
    if (Platform.isWindows) {
      await windowManager.show();
      await windowManager.focus();
    }
    await openTaskById(
      repo,
      taskId,
      navigatorKey: appNavigatorKey,
      onChanged: () => AppNotifications.rescheduleAll(
        repo,
        defaultOffsetMinutes: settings.defaultReminderOffsetMinutes,
        initializeIfNeeded: true,
      ),
    );
  }

  runApp(VerbApp(
    repository: repo,
    settings: settings,
    onQuickSync: () async {
      await settings.markSyncStarted();
      try {
        await SyncController.quickSync(
          repo,
          // Read the current value at click time so pairing changes take
          // effect without restarting the app.
          token: settings.syncToken,
          cursor: settings.syncCursor,
          onCursorCommitted: settings.markSyncSuccess,
          onSynced: () => AppNotifications.rescheduleAll(
            repo,
            defaultOffsetMinutes: settings.defaultReminderOffsetMinutes,
            language: settings.language,
            initializeIfNeeded: true,
          ),
        );
      } catch (error) {
        await settings.markSyncFailure(error);
        rethrow;
      }
    },
  ));
  unawaited(AppNotifications.init(
    repo,
    defaultOffsetMinutes: settings.defaultReminderOffsetMinutes,
    language: settings.language,
    onNotificationTap: (taskId) {
      if (taskId == null) return;
      unawaited(openNotificationTask(taskId));
    },
  ));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(flushPendingTaskOpen(
      repo,
      navigatorKey: appNavigatorKey,
      onChanged: () => AppNotifications.rescheduleAll(
        repo,
        defaultOffsetMinutes: settings.defaultReminderOffsetMinutes,
        language: settings.language,
        initializeIfNeeded: true,
      ),
    ));
  });
  unawaited(BackgroundSync.init(
    intervalMinutes: settings.syncAutoIntervalMin,
  ).catchError((_) {}));
  if (Platform.isWindows) {
    WindowsTray.init(enabled: settings.trayEnabled);
    unawaited(Autostart.setEnabled(settings.autostartEnabled));
    unawaited(WindowControl.setMinimumSize(WindowControl.normalMinimumSize));
    WindowControl.setAlwaysOnTop(settings.alwaysOnTop);
    SyncHost.start(repo, token: syncToken).then((_) {}, onError: (_) {});
  }
}
