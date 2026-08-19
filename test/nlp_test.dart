import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/nlp/zh_parser.dart';

void main() {
  final p = ZhParser();
  test('明天 -> 日期', () {
    final d = p.parse('明天交报告');
    expect(d.due, isNotNull);
    expect(d.dateOnly, isTrue);
    expect(d.title, '交报告');
    expect(d.rrule, isNull);
  });
  test('每天 -> RRULE', () {
    final d = p.parse('每天晚上9点锻炼');
    expect(d.rrule, 'FREQ=DAILY');
    expect(d.title, '锻炼');
  });
  test('下周三下午3点 -> 时间+日期', () {
    final d = p.parse('下周三下午3点交报告');
    expect(d.rrule, isNull);
    expect(d.dateOnly, isFalse);
    expect(d.due!.toLocal().hour, 15); // 本地时区的下午3点
    expect(d.title, '交报告');
  });
  test('每隔2天', () {
    final d = p.parse('每隔2天买菜');
    expect(d.rrule, 'FREQ=DAILY;INTERVAL=2');
    expect(d.title, '买菜');
  });
  test('每月15号', () {
    final d = p.parse('每月15号交房租');
    expect(d.rrule, 'FREQ=MONTHLY;BYMONTHDAY=15');
    expect(d.title, '交房租');
  });
  test('每工作日', () {
    final d = p.parse('每个工作日打卡');
    expect(d.rrule, 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR');
  });
}

