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
        onSynced: () => AppNotifications.rescheduleAll(
          repo,
          defaultOffsetMinutes: settings.notifyDefaultReminderEnabled
              ? settings.notifyDefaultOffsetMin
              : null,
          initializeIfNeeded: true,
        ),
      );
    } catch (_) {
      // 后台失败静默：下次周期再试
    }
    return true;
  });
}

/// Android 端：注册周期后台同步（发现并同步局域网内的 Windows 宿主）。
class BackgroundSync {
  static const _unique = 'verb-periodic-sync';
  static const _task = 'periodicSyncTask';

  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    await Workmanager().initialize(backgroundCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      _unique,
      _task,
      frequency: const Duration(minutes: 30),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}
