import 'dart:io';
import '../services/task_service.dart';
import '../storage/repository.dart';
import 'notification_sink.dart';
import 'platform_notification_sink.dart';
import 'reminder_service.dart';

/// 全局通知入口：启动初始化 + 数据改动后重排提醒。测试环境 sink 为空则 no-op。
class AppNotifications {
  static NotificationSink? _sink;

  static Future<void> init(
    TaskRepository repo, {
    int? defaultOffsetMinutes,
  }) async {
    if (!Platform.isAndroid && !Platform.isWindows) return;
    try {
      _sink = await PlatformNotificationSink.create();
    } catch (_) {
      _sink = null;
    }
    await rescheduleAll(repo, defaultOffsetMinutes: defaultOffsetMinutes);
  }

  static Future<void> rescheduleAll(
    TaskRepository repo, {
    int? defaultOffsetMinutes,
  }) async {
    final s = _sink;
    if (s == null) return;
    try {
      await ReminderService(tasks: TaskService(repo), sink: s).syncReminders(
        defaultOffsetMinutes: defaultOffsetMinutes,
      );
    } catch (_) {}
  }
}
