import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/rrule/rrule_service.dart';

void main() {
  final svc = RruleService();
  final start = DateTime.utc(2026, 1, 1); // 周四

  test('每日到第二天', () {
    final next = svc.nextAfter('FREQ=DAILY', DateTime.utc(2026, 1, 1, 12), start: start);
    expect(next, DateTime.utc(2026, 1, 2));
  });

  test('每周一从周后出发取周一', () {
    final next = svc.nextAfter('FREQ=WEEKLY;BYDAY=MO', DateTime.utc(2026, 1, 1, 12), start: start);
    expect(next, DateTime.utc(2026, 1, 5));
  });

  test('每月15日', () {
    final next = svc.nextAfter('FREQ=MONTHLY;BYMONTHDAY=15', DateTime.utc(2026, 1, 1, 12), start: start);
    expect(next, DateTime.utc(2026, 1, 15));
  });

  test('每工作日周六出发取周一', () {
    final sat = DateTime.utc(2026, 1, 3); // 周六
    final next = svc.nextAfter('FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR', sat, start: start);
    expect(next, DateTime.utc(2026, 1, 5));
  });

  test('间隔2天', () {
    final next = svc.nextAfter('FREQ=DAILY;INTERVAL=2', DateTime.utc(2026, 1, 1, 12), start: start);
    expect(next, DateTime.utc(2026, 1, 3));
  });

  test('实例窗口展开', () {
    final xs = svc.instancesBetween('FREQ=DAILY', DateTime.utc(2026,1,1), DateTime.utc(2026,1,4), start: start);
    expect(xs.length, 3);
  });
}
