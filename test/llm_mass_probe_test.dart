import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/models/task.dart';
import 'package:verb_app/core/nlp/nlp_service.dart';
import '../tool/llm_mass_probe.dart' as probe;

void main() {
  test('批量探测器能报告声明字段的匹配和不匹配', () {
    final result = NlpResult(
      title: '交周报',
      due: DueDate(DateTime(2026, 8, 22, 15)),
      rrule: 'FREQ=WEEKLY;BYDAY=MO',
      priority: 2,
      reminderMinutes: 30,
    );

    expect(
      probe.probeMismatches(
        result,
        'due=08-22 15:00, pri=2, title=交周报, reminder=30, WEEKLY MO',
      ),
      isEmpty,
    );
    expect(
      probe.probeMismatches(result, 'title=错误标题, pri=3'),
      containsAll([
        contains('title'),
        contains('priority'),
      ]),
    );
  });

  test('探测器不会把 BYDAY 后的中文标点算进规则', () {
    final result = NlpResult(
      title: '交周报',
      rrule: 'FREQ=WEEKLY;BYDAY=FR',
      reminderMinutes: 15,
    );

    expect(
      probe.probeMismatches(result, 'rrule=WEEKLY;BYDAY=FR, rem=15'),
      isEmpty,
    );
  });

  test('探测器会检查重复任务的具体时刻', () {
    final result = NlpResult(
      title: '喝水',
      rrule: 'FREQ=DAILY',
    );

    expect(
      probe.probeMismatches(result, 'FREQ=DAILY BYHOUR=8 BYMINUTE=0'),
      contains(contains('BYHOUR=8')),
    );
  });

  test('探测器支持 rem 简写并能发现提醒丢失', () {
    final result = NlpResult(title: '交报告');

    expect(
      probe.probeMismatches(result, 'rem=15'),
      contains(contains('reminder')),
    );
  });

  test('相对日期批量探测优先使用当前本地基线而不是历史日期', () {
    final result = NlpResult(
      title: '交报告',
      due: DueDate(DateTime(2026, 8, 24, 15)),
    );
    final localBaseline = NlpResult(
      title: '交报告',
      due: DueDate(DateTime(2026, 8, 24, 15)),
    );

    expect(
      probe.probeMismatches(
        result,
        'due=08-22 15:00',
        localBaseline: localBaseline,
      ),
      isEmpty,
    );
  });
}
