import 'notification_sink.dart';

class ScheduledNotification {
  final String id;
  final DateTime at;
  final String title;
  final String? body;
  final String? payload;
  ScheduledNotification(this.id, this.at, this.title, this.body, this.payload);
}

/// 记录型实现：用于测试与内存验证。
class LoggingNotificationSink implements NotificationSink {
  final List<ScheduledNotification> scheduled = [];
  final List<String> cancelled = [];

  @override
  Future<void> schedule({
    required String id,
    required DateTime at,
    required String title,
    String? body,
    String? payload,
  }) async {
    scheduled.add(ScheduledNotification(id, at, title, body, payload));
  }

  @override
  Future<void> cancel(String id) async => cancelled.add(id);

  @override
  Future<void> cancelAll() async => cancelled.add('*ALL*');
}
