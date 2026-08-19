import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'notification_sink.dart';

/// 真实平台通知（flutter_local_notifications）。Android/Windows 可用；其余平台 no-op。
class PlatformNotificationSink implements NotificationSink {
  final FlutterLocalNotificationsPlugin _plugin;
  PlatformNotificationSink._(this._plugin);

  static Future<PlatformNotificationSink> create() async {
    tzdata.initializeTimeZones();
    final plugin = FlutterLocalNotificationsPlugin();
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      windows: WindowsInitializationSettings(
        appName: 'Verb Task',
        appUserModelId: 'VerbApp.VerbApp',
        guid: 'a2c0d1e2-3f44-4b55-8c66-9d77e0f1a2b3',
      ),
    );
    await plugin.initialize(init);
    return PlatformNotificationSink._(plugin);
  }

  @override
  Future<void> schedule({
    required String id,
    required DateTime at,
    required String title,
    String? body,
  }) async {
    if (!Platform.isAndroid && !Platform.isWindows) return;
    final tzAt = tz.TZDateTime.from(at.toLocal(), tz.local);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'task_reminders',
        '任务提醒',
        channelDescription: '任务到期/提前提醒',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.zonedSchedule(
      id.hashCode,
      title,
      body,
      tzAt,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(String id) async => _plugin.cancel(id.hashCode);

  @override
  Future<void> cancelAll() async => _plugin.cancelAll();
}

