import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'notification_sink.dart';

/// Chinese remains the default for callers that do not provide a locale.
const NotificationDetails taskReminderNotificationDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    'task_reminders_zh',
    'VerbTask 提醒',
    channelDescription: 'VerbTask 任务到期/提前提醒',
    importance: Importance.high,
    priority: Priority.high,
  ),
  windows: WindowsNotificationDetails(
    duration: WindowsNotificationDuration.long,
  ),
);

NotificationDetails taskReminderNotificationDetailsFor(String language) {
  final english = language.toLowerCase().startsWith('en');
  return NotificationDetails(
    android: AndroidNotificationDetails(
      english ? 'task_reminders_en' : 'task_reminders_zh',
      english ? 'VerbTask reminders' : 'VerbTask 提醒',
      channelDescription:
          english ? 'Task due and advance reminders' : 'VerbTask 任务到期/提前提醒',
      importance: Importance.high,
      priority: Priority.high,
    ),
    windows: const WindowsNotificationDetails(
      duration: WindowsNotificationDuration.long,
    ),
  );
}

/// 真实平台通知（flutter_local_notifications）。Android/Windows 可用；其余平台 no-op。
class PlatformNotificationSink implements NotificationSink {
  final FlutterLocalNotificationsPlugin _plugin;
  bool _exactAlarmsAvailable;
  String language;
  PlatformNotificationSink._(this._plugin,
      {required bool exactAlarmsAvailable, this.language = 'zh'})
      : _exactAlarmsAvailable = exactAlarmsAvailable;

  static Future<PlatformNotificationSink> create({
    bool requestPermission = true,
    bool requestExactAlarms = true,
    void Function(String? taskId)? onTaskTap,
    String language = 'zh',
  }) async {
    tzdata.initializeTimeZones();
    final plugin = FlutterLocalNotificationsPlugin();
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      windows: WindowsInitializationSettings(
        appName: 'VerbTask',
        appUserModelId: 'LynVerbTask.VerbTask',
        guid: 'a2c0d1e2-3f44-4b55-8c66-9d77e0f1a2b3',
      ),
    );
    await plugin.initialize(init, onDidReceiveNotificationResponse: (resp) {
      onTaskTap?.call(resp.payload);
    });
    if (Platform.isAndroid) {
      try {
        final launch = await plugin.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp ?? false) {
          final p = launch?.notificationResponse?.payload;
          if (p != null) onTaskTap?.call(p);
        }
      } catch (_) {}
    }
    var exactAlarmsAvailable = false;
    if (Platform.isAndroid) {
      final android = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (requestPermission) {
        await android?.requestNotificationsPermission();
        if (requestExactAlarms) {
          try {
            await android?.requestExactAlarmsPermission();
          } catch (_) {
            // A denied special-access request must not disable ordinary reminders.
          }
        }
      }
      try {
        exactAlarmsAvailable =
            await android?.canScheduleExactNotifications() ?? false;
      } catch (_) {
        exactAlarmsAvailable = false;
      }
    }
    return PlatformNotificationSink._(plugin,
        exactAlarmsAvailable: exactAlarmsAvailable, language: language);
  }

  /// Android 上请求通知运行时权限（Android 13+）；其余平台 no-op。
  Future<void> requestPermission() async {
    if (!Platform.isAndroid) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    try {
      await android?.requestExactAlarmsPermission();
    } catch (_) {}
    try {
      _exactAlarmsAvailable =
          await android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      _exactAlarmsAvailable = false;
    }
  }

  @override
  Future<void> schedule({
    required String id,
    required DateTime at,
    required String title,
    String? body,
    String? payload,
  }) async {
    if (!Platform.isAndroid && !Platform.isWindows) return;
    final tzAt = tz.TZDateTime.from(at.toLocal(), tz.local);
    await _plugin.zonedSchedule(
      _stableNotificationId(id),
      title,
      body,
      tzAt,
      taskReminderNotificationDetailsFor(language),
      androidScheduleMode: androidReminderScheduleMode(
          exactAlarmsAvailable: _exactAlarmsAvailable),
      payload: payload ?? id,
    );
  }

  @override
  Future<void> cancel(String id) async =>
      _plugin.cancel(_stableNotificationId(id));

  @override
  Future<void> cancelAll() async => _plugin.cancelAll();
}

AndroidScheduleMode androidReminderScheduleMode(
        {required bool exactAlarmsAvailable}) =>
    exactAlarmsAvailable
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

int _stableNotificationId(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}
