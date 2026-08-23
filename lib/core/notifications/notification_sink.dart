/// 提醒投递抽象：不同平台（flutter_local_notifications / 测试日志 / Windows 通知）实现之。
abstract class NotificationSink {
  Future<void> schedule({
    required String id,
    required DateTime at,
    required String title,
    String? body,
    String? payload,
  });
  Future<void> cancel(String id);
  Future<void> cancelAll();
}
