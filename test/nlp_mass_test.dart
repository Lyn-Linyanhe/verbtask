import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/nlp/zh_parser.dart';

/// 本地中文解析批量回归（对应 docs/测试清单 B 区）。
/// 日期期望全部基于测试运行当天动态推算，避免写死。
void main() {
  final p = ZhParser();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime add(int d) => today.add(Duration(days: d));
  // 本周/下周几点：以「今天」为参照推算 next weekday（1=周一…7=周日）
  DateTime nextWeekday(int wd, {int weeks = 0}) {
    var target = today.add(Duration(days: 1));
    while (target.weekday != wd) {
      target = target.add(const Duration(days: 1));
    }
    return target.add(Duration(days: weeks * 7));
  }

  String iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  group('本地解析 B 区', () {
    test('B.01 明天交报告', () {
      final d = p.parse('明天交报告');
      expect(d.title, '交报告');
      expect(iso(d.due!.toLocal()), iso(add(1)));
      expect(d.dateOnly, isTrue);
    });
    test('B.02 每天锻炼', () {
      final d = p.parse('每天锻炼');
      expect(d.rrule, 'FREQ=DAILY');
      expect(d.title, '锻炼');
    });
    test('B.03 每天晚上9点锻炼(时刻进 rrule)', () {
      final d = p.parse('每天晚上9点锻炼');
      expect(d.rrule, 'FREQ=DAILY;BYHOUR=21;BYMINUTE=0;BYSECOND=0');
      expect(d.title, '锻炼');
    });
    test('B.04 下周三下午3点交报告', () {
      final d = p.parse('下周三下午3点交报告');
      expect(d.title, '交报告');
      expect(d.dateOnly, isFalse);
      expect(d.due!.toLocal().hour, 15);
      expect(iso(d.due!.toLocal()), iso(nextWeekday(3)));
    });
    test('B.05 每隔2天买菜', () {
      expect(p.parse('每隔2天买菜').rrule, 'FREQ=DAILY;INTERVAL=2');
    });
    test('B.06 每隔3周体检', () {
      expect(p.parse('每隔3周体检').rrule, 'FREQ=WEEKLY;INTERVAL=3');
    });
    test('B.07 每月15号交房租', () {
      expect(p.parse('每月15号交房租').rrule, 'FREQ=MONTHLY;BYMONTHDAY=15');
    });
    test('B.08 每个工作日打卡', () {
      expect(p.parse('每个工作日打卡').rrule, 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR');
    });
    test('B.09 每周六日去爸妈家', () {
      expect(p.parse('每周六日去爸妈家').rrule, 'FREQ=WEEKLY;BYDAY=SA,SU');
    });
    test('B.10 后天交周报', () {
      final d = p.parse('后天交周报');
      expect(d.title, '交周报');
      expect(iso(d.due!.toLocal()), iso(add(2)));
    });
    test('B.11 月底前交房租', () {
      final d = p.parse('月底前交房租');
      expect(d.due, isNotNull);
      // 月末
      final last = DateTime(today.year, today.month + 1, 0);
      expect(iso(d.due!.toLocal()), iso(last));
    });
    test('B.12 下午5点半开会', () {
      final d = p.parse('下午5点半开会');
      expect(d.due!.toLocal().hour, 17);
      expect(d.due!.toLocal().minute, 30);
      expect(iso(d.due!.toLocal()), iso(today));
    });
    test('B.13 紧急：明早给客户回邮件', () {
      final d = p.parse('紧急：明早给客户回邮件');
      expect(d.priority, 3);
      expect(d.title, '给客户回邮件');
      expect(iso(d.due!.toLocal()), iso(add(1)));
    });
    test('B.14 重要：周五评审材料', () {
      final d = p.parse('重要：周五评审材料');
      expect(d.priority, 2);
    });
    test('B.15 低：下月逛书店', () {
      final d = p.parse('低：下月逛书店');
      expect(d.priority, 1);
    });
    test('B.16 优先级词剥离干净', () {
      final d = p.parse('紧急：明早给客户回邮件');
      expect(d.title, isNot(contains('紧急')));
      expect(d.title, isNot(contains('重要')));
    });
  });
}
