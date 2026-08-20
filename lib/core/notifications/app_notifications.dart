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
      _sink = await PlatformNotificationSink.create(requestPermission: false);
    } catch (_) {
      _sink = null;
    }
    await rescheduleAll(repo, defaultOffsetMinutes: defaultOffsetMinutes);
  }

  /// 用户主动开启提醒时请求通知权限（Android 13+）；其余平台 no-op。
  static Future<void> ensureNotificationPermission() async {
    if (!Platform.isAndroid) return;
    try {
      var s = _sink;
      if (s == null) {
        s = await PlatformNotificationSink.create(requestPermission: true);
        _sink = s;
      } else if (s is PlatformNotificationSink) {
        await s.requestPermission();
      }
    } catch (_) {}
  }

  static Future<void> rescheduleAll(
    TaskRepository repo, {
    int? defaultOffsetMinutes,
    bool initializeIfNeeded = false,
  }) async {
    var s = _sink;
    if (s == null &&
        initializeIfNeeded &&
        (Platform.isAndroid || Platform.isWindows)) {
      try {
        s = await PlatformNotificationSink.create(requestPermission: false);
        _sink = s;
      } catch (_) {
        s = null;
      }
    }
    if (s == null) return;
    try {
      await ReminderService(tasks: TaskService(repo), sink: s).syncReminders(
        defaultOffsetMinutes: defaultOffsetMinutes,
      );
    } catch (_) {}
  }
}
