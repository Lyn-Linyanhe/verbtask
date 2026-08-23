import 'dart:io';
import '../async/serial_future_queue.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../storage/repository.dart';
import 'notification_sink.dart';
import 'platform_notification_sink.dart';
import 'reminder_service.dart';

/// 全局通知入口：启动初始化 + 数据改动后重排提醒。测试环境 sink 为空则 no-op。
class AppNotifications {
  static NotificationSink? _sink;
  static final _rescheduleQueue = SerialFutureQueue();
  static Object? lastError;

  static Future<void> init(
    TaskRepository repo, {
    int? defaultOffsetMinutes,
    void Function(String? taskId)? onNotificationTap,
    String language = 'zh',
  }) async {
    if (!Platform.isAndroid && !Platform.isWindows) return;
    try {
      final existingTasks =
          await TaskService(repo).query(includeDeleted: false);
      _sink = await PlatformNotificationSink.create(
          requestPermission: true,
          requestExactAlarms: shouldRequestExactAlarms(
            existingTasks,
            defaultOffsetMinutes: defaultOffsetMinutes,
          ),
          onTaskTap: onNotificationTap,
          language: language);
    } catch (_) {
      _sink = null;
    }
    await rescheduleAll(repo,
        defaultOffsetMinutes: defaultOffsetMinutes, language: language);
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
    String language = 'zh',
    bool initializeIfNeeded = false,
  }) {
    return _rescheduleQueue.add<void>(() => _rescheduleNow(
          repo,
          defaultOffsetMinutes: defaultOffsetMinutes,
          language: language,
          initializeIfNeeded: initializeIfNeeded,
        ));
  }

  static Future<void> _rescheduleNow(
    TaskRepository repo, {
    int? defaultOffsetMinutes,
    required String language,
    required bool initializeIfNeeded,
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
    if (s is PlatformNotificationSink) s.language = language;
    if (s == null) return;
    try {
      await ReminderService(
        tasks: TaskService(repo),
        sink: s,
        language: language,
      ).syncReminders(
        defaultOffsetMinutes: defaultOffsetMinutes,
      );
      lastError = null;
    } catch (error) {
      lastError = error;
      rethrow;
    }
  }
}

/// Exact-alarm access is only worth asking for when a reminder can be queued.
/// Ordinary notifications can still be requested during startup.
bool shouldRequestExactAlarms(
  Iterable<Task> tasks, {
  required int? defaultOffsetMinutes,
}) {
  return tasks.any((task) {
    if (task.deleted || task.status == TaskStatus.done || task.due == null) {
      return false;
    }
    if (task.reminderPolicy == ReminderPolicy.disabled) return false;
    return task.reminders.isNotEmpty || defaultOffsetMinutes != null;
  });
}
