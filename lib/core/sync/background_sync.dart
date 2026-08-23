import 'dart:io';
import 'package:workmanager/workmanager.dart';
import '../storage/app_paths.dart';
import '../storage/file_repository.dart';
import '../settings/local_settings.dart';
import '../notifications/app_notifications.dart';
import 'sync_controller.dart';

/// 后台回调调度器：workmanager 在独立 isolate 中调用。
@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      final repo = FileRepository(await AppPaths.dataFile());
      final settings = LocalSettings(await AppPaths.settingsFile());
      final syncToken = settings.syncToken;
      await SyncController.quickSync(
        token: syncToken,
        repo,
        cursor: settings.syncCursor,
        onCursorCommitted: (cursor) async {
          settings
            ..syncCursor = cursor
            ..syncLastStatus = 'success'
            ..syncLastError = ''
            ..syncLastAt = DateTime.now().toUtc().toIso8601String();
          await settings.save();
        },
        onError: (error) async {
          settings
            ..syncLastStatus = 'failed'
            ..syncLastError = error.toString()
            ..syncLastAt = DateTime.now().toUtc().toIso8601String();
          await settings.save();
        },
        onSynced: () => AppNotifications.rescheduleAll(
          repo,
          defaultOffsetMinutes: settings.notifyDefaultReminderEnabled
              ? settings.notifyDefaultOffsetMin
              : null,
          language: settings.language,
          initializeIfNeeded: true,
        ),
      );
    } catch (error) {
      try {
        final settings = LocalSettings(await AppPaths.settingsFile());
        settings
          ..syncLastStatus = 'failed'
          ..syncLastError = error.toString()
          ..syncLastAt = DateTime.now().toUtc().toIso8601String();
        await settings.save();
      } catch (_) {}
      // 返回 false 让 WorkManager 按平台策略重试，而不是错误地确认成功。
      return false;
    }
    return true;
  });
}

/// Android 端：注册周期后台同步（发现并同步局域网内的 Windows 宿主）。
class BackgroundSync {
  static const _unique = 'verb-periodic-sync';
  static const _task = 'periodicSyncTask';
  static bool _initialized = false;

  static int normalizeInterval(int minutes) => minutes.clamp(15, 24 * 60);

  static Future<void> init({int intervalMinutes = 30}) async {
    if (!Platform.isAndroid) return;
    if (!_initialized) {
      await Workmanager().initialize(backgroundCallbackDispatcher);
      _initialized = true;
    }
    await Workmanager().registerPeriodicTask(
      _unique,
      _task,
      frequency: Duration(minutes: normalizeInterval(intervalMinutes)),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  static Future<void> updateInterval(int intervalMinutes) async {
    if (!Platform.isAndroid) return;
    if (!_initialized) {
      await init(intervalMinutes: intervalMinutes);
      return;
    }
    await Workmanager().registerPeriodicTask(
      _unique,
      _task,
      frequency: Duration(minutes: normalizeInterval(intervalMinutes)),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}
