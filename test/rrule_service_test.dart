import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/rrule/rrule_service.dart';

void main() {
  final svc = RruleService();
  final start = DateTime.utc(2026, 1, 1); // 周四

  test('每日到第二天', () {
    final next =
        svc.nextAfter('FREQ=DAILY', DateTime.utc(2026, 1, 1, 12), start: start);
    expect(next, DateTime.utc(2026, 1, 2));
  });

  test('带固定时刻的重复规则保持本地墙钟时间', () {
    final start = DateTime(2026, 1, 1, 21).toUtc();
    final after = DateTime(2026, 1, 1, 22).toUtc();
    final next = svc.nextAfter(
      'FREQ=DAILY;BYHOUR=21;BYMINUTE=0;BYSECOND=0',
      after,
      start: start,
      localWallClock: true,
    );

    expect(next, DateTime(2026, 1, 2, 21).toUtc());
  });

  test('每周一从周后出发取周一', () {
    final next = svc.nextAfter(
        'FREQ=WEEKLY;BYDAY=MO', DateTime.utc(2026, 1, 1, 12),
        start: start);
    expect(next, DateTime.utc(2026, 1, 5));
  });

  test('每月15日', () {
    final next = svc.nextAfter(
        'FREQ=MONTHLY;BYMONTHDAY=15', DateTime.utc(2026, 1, 1, 12),
        start: start);
    expect(next, DateTime.utc(2026, 1, 15));
  });

  test('每工作日周六出发取周一', () {
    final sat = DateTime.utc(2026, 1, 3); // 周六
    final next =
        svc.nextAfter('FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR', sat, start: start);
    expect(next, DateTime.utc(2026, 1, 5));
  });

  test('间隔2天', () {
    final next = svc.nextAfter(
        'FREQ=DAILY;INTERVAL=2', DateTime.utc(2026, 1, 1, 12),
        start: start);
    expect(next, DateTime.utc(2026, 1, 3));
  });

  test('实例窗口展开', () {
    final xs = svc.instancesBetween(
        'FREQ=DAILY', DateTime.utc(2026, 1, 1), DateTime.utc(2026, 1, 4),
        start: start);
    expect(xs.length, 3);
  });

  test('月末规则覆盖二月、30日和31日月份', () {
    final xs = svc.instancesBetween(
      'FREQ=MONTHLY;BYMONTHDAY=-1',
      DateTime.utc(2026, 1, 1),
      DateTime.utc(2026, 5, 1),
      start: DateTime.utc(2026, 1, 31),
    );
    expect(xs, [
      DateTime.utc(2026, 1, 31),
      DateTime.utc(2026, 2, 28),
      DateTime.utc(2026, 3, 31),
      DateTime.utc(2026, 4, 30),
    ]);
  });

  test('重复规则可以限制到旧系列的最后一个实例', () {
    final xs = svc.instancesBetween(
      'FREQ=DAILY',
      DateTime.utc(2026, 1, 1),
      DateTime.utc(2026, 1, 10),
      start: DateTime.utc(2026, 1, 1),
      recurrenceUntil: DateTime.utc(2026, 1, 2),
    );
    expect(xs, [DateTime.utc(2026, 1, 1), DateTime.utc(2026, 1, 2)]);
  });
}
