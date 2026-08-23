import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/nlp/zh_parser.dart';

void main() {
  final parser = ZhParser();

  void expectDraft(
    String input, {
    String? title,
    String? rrule,
    int? reminderMinutes,
    bool reminderDisabled = false,
  }) {
    final draft = parser.parse(input);
    expect(draft.title, title, reason: 'title: $input');
    expect(draft.rrule, rrule, reason: 'rrule: $input');
    expect(draft.reminderMinutes, reminderMinutes,
        reason: 'reminderMinutes: $input');
    expect(draft.reminderDisabled, reminderDisabled,
        reason: 'reminderDisabled: $input');
  }

  test('does not treat notification as a reminder when it is an action noun',
      () {
    expectDraft(
      '明天给客户发通知',
      title: '给客户发通知',
    );
  });

  test('recognizes conversational opt-out wording for reminders', () {
    for (final input in [
      '不用再提醒我明天交报告',
      '我不想被提醒明天交报告',
      '请不要在截止前提醒我明天交报告',
      '不要再给我设闹钟明早七点起床',
      '无需在截止前提醒我明天交报告',
      '别在截止前提醒我明天交报告',
      '不用到点提醒我明天交报告',
    ]) {
      final draft = parser.parse(input);
      expect(draft.reminderMinutes, isNull, reason: input);
      expect(draft.reminderDisabled, isTrue, reason: input);
    }
  });

  test('supports early synonyms and half-day reminder offsets', () {
    expectDraft(
      '提早十分钟提醒我明天开会',
      title: '开会',
      reminderMinutes: 10,
    );
    expectDraft(
      '提前半天提醒我明天开会',
      title: '开会',
      reminderMinutes: 720,
    );
  });

  test('parses compound Chinese numbers in reminder lead time', () {
    final draft = parser.parse('提前二十五分钟提醒我明天交报告');

    expect(draft.reminderMinutes, 25);
    expect(draft.title, '交报告');
  });

  test('recognizes opt-out wording with an action verb between 给我 and 提醒', () {
    final draft = parser.parse('不要给我发提醒，明天交报告');

    expect(draft.reminderMinutes, isNull);
    expect(draft.reminderDisabled, isTrue);
    expect(draft.title, '交报告');
  });

  test('recognizes daily recurrence and evening time synonyms', () {
    expectDraft(
      '天天提醒我吃药',
      title: '吃药',
      rrule: 'FREQ=DAILY',
      reminderMinutes: 15,
    );
    expectDraft(
      '每晚九点提醒我吃药',
      title: '吃药',
      rrule: 'FREQ=DAILY;BYHOUR=21;BYMINUTE=0;BYSECOND=0',
      reminderMinutes: 15,
    );
  });

  test('removes 工作日 schedule wording from the action title', () {
    final draft = parser.parse('每个工作日早上打卡');

    expect(draft.title, '打卡');
    expect(draft.rrule,
        'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR;BYHOUR=9;BYMINUTE=0;BYSECOND=0');
  });

  test('removes trailing scheduling filler from a recurring action title', () {
    final draft = parser.parse('两周做一次体检，下周二下午两点开始');

    expect(draft.title, '体检');
    expect(draft.rrule,
        'FREQ=WEEKLY;INTERVAL=2;BYDAY=TU;BYHOUR=14;BYMINUTE=0;BYSECOND=0');
  });

  test('parses bare 晚 before a numeric clock as afternoon', () {
    final draft = parser.parse('下周五晚八点和同事聚餐');

    expect(draft.due, isNotNull);
    expect(draft.due!.toLocal().hour, 20);
    expect(draft.title, '和同事聚餐');
  });

  test('removes date relation words left after extracting a deadline', () {
    expect(parser.parse('今晚十一点前提醒我睡觉').title, '睡觉');
    expect(parser.parse('下周一之前把年终总结写完发给老板').title, '把年终总结写完发给老板');
    expect(parser.parse('2026年10月1日前订好机票').title, '订好机票');
  });

  test('keeps 给我 when it is the recipient of the action', () {
    final draft = parser.parse('明天下午3点前把周报交给我');

    expect(draft.title, '把周报交给我');
  });

  test('removes month qualifiers while keeping the actual action', () {
    final current = parser.parse('本月25号晚上十点交水电费');
    final next = parser.parse('下个月逛逛书店');

    expect(current.title, '交水电费');
    expect(next.title, '逛逛书店');
    expect(next.due, isNotNull);
    expect(next.dateOnly, isTrue);
  });

  test('treats 最重要 as highest priority and strips its discourse filler', () {
    final draft = parser.parse('最重要的事：周五前敲定合同');

    expect(draft.priority, 3);
    expect(draft.title, '敲定合同');
  });

  test('removes the suffix 号 from an already extracted full date', () {
    expect(parser.parse('别忘了把发票2026/08/10号给报销了').title, '把发票给报销了');
  });

  test('keeps 要是 at the start of a conditional action', () {
    expect(parser.parse('下午要是没事就把发票贴了').title, '要是没事就把发票贴了');
  });

  test('removes chained trailing modal particles', () {
    expect(parser.parse('今天去楼下拿个快递吧，就').title, '去楼下拿个快递');
  });

  test('recognizes interval recurrence in days and months', () {
    expectDraft(
      '每三天一次浇花',
      title: '浇花',
      rrule: 'FREQ=DAILY;INTERVAL=3',
    );
    expectDraft(
      '每隔三个月体检',
      title: '体检',
      rrule: 'FREQ=MONTHLY;INTERVAL=3',
    );
  });

  test('recognizes recurring weekdays, lists, and weekday ranges', () {
    expectDraft(
      '每逢周一开会',
      title: '开会',
      rrule: 'FREQ=WEEKLY;BYDAY=MO',
    );
    expectDraft(
      '每周一和周三开会',
      title: '开会',
      rrule: 'FREQ=WEEKLY;BYDAY=MO,WE',
    );
    expectDraft(
      '每周一到周五打卡',
      title: '打卡',
      rrule: 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR',
    );
    expectDraft(
      '每隔两周周五下午开周会',
      title: '开周会',
      rrule: 'FREQ=WEEKLY;INTERVAL=2;BYDAY=FR;BYHOUR=15;BYMINUTE=0;BYSECOND=0',
    );
  });

  test('recognizes monthly end and does not mistake title text for recurrence',
      () {
    expectDraft(
      '每月月底做账',
      title: '做账',
      rrule: 'FREQ=MONTHLY;BYMONTHDAY=-1',
    );
    expectDraft(
      '每个月十五号交房租',
      title: '交房租',
      rrule: 'FREQ=MONTHLY;BYMONTHDAY=15',
    );
    expectDraft(
      '明天买每天都要吃的药',
      title: '买每天都要吃的药',
    );
  });

  test('treats on-time reminder wording as zero advance minutes', () {
    expectDraft(
      '到点提醒我明天交报告',
      title: '交报告',
      reminderMinutes: 0,
    );
  });

  test('supports a bare clock time with a colon', () {
    final draft = parser.parse('明天15:30交报告');

    expect(draft.title, '交报告');
    expect(draft.due, isNotNull);
    expect(draft.dateOnly, isFalse);
    expect(draft.due!.toLocal().hour, 15);
    expect(draft.due!.toLocal().minute, 30);
  });

  test('parses a four-digit year before the shorter month-day pattern', () {
    final draft = parser.parse('2027年1月1日交房租');
    final due = draft.due!.toLocal();

    expect(DateTime(due.year, due.month, due.day), DateTime(2027, 1, 1));
    expect(draft.title, '交房租');
  });

  test('rolls a month-day note into the next year when that date has passed',
      () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expectedYear =
        DateTime(now.year, 1, 1).isBefore(today) ? now.year + 1 : now.year;
    final draft = parser.parse('1月1日交房租');
    final due = draft.due!.toLocal();

    expect(
        DateTime(due.year, due.month, due.day), DateTime(expectedYear, 1, 1));
  });

  test('maps high priority wording to the highest priority', () {
    for (final input in [
      '明天下午3点交周报 高',
      '明天下午3点交周报 高优先级',
      '明天下午3点交周报 优先级高',
    ]) {
      expect(parser.parse(input).priority, 3, reason: input);
    }
  });

  test('does not turn a one-time weekend note into a recurring task', () {
    final draft = parser.parse('周末下午3点浇花');

    expect(draft.rrule, isNull);
    expect(draft.due, isNotNull);
    expect(draft.dateOnly, isFalse);
    expect(draft.title, '浇花');
  });

  test('creates an initial due time for recurring reminders', () {
    final timed = parser.parse('每天晚上10点吃药');
    expect(timed.due, isNotNull);
    expect(timed.due!.toLocal().hour, 22);
    expect(timed.due!.toLocal().minute, 0);

    final monthly = parser.parse('每月15号交房租');
    expect(monthly.due, isNotNull);
  });

  test('anchors recurring weekday and monthly dates to their stated date', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final weekly = parser.parse('每两周周五下午3点开周会');
    final weeklyDue = weekly.due!.toLocal();
    expect(weeklyDue.weekday, DateTime.friday);

    DateTime expectedMonthly(int day) {
      var candidate = DateTime(today.year, today.month, day);
      if (candidate.isBefore(today)) {
        candidate = DateTime(today.year, today.month + 1, day);
      }
      return candidate;
    }

    final dayTask = parser.parse('每月15号交房租');
    final dayDue = dayTask.due!.toLocal();
    final expectedDay = expectedMonthly(15);
    expect(DateTime(dayDue.year, dayDue.month, dayDue.day), expectedDay);

    final monthEnd = parser.parse('每月月底做账');
    final endDue = monthEnd.due!.toLocal();
    var expectedEnd = DateTime(today.year, today.month + 1, 0);
    if (expectedEnd.isBefore(today)) {
      expectedEnd = DateTime(today.year, today.month + 2, 0);
    }
    expect(DateTime(endDue.year, endDue.month, endDue.day), expectedEnd);
  });

  test('recognizes two-week spoken variants', () {
    for (final input in [
      '每两星期一次体检',
      '两星期一次体检',
      '每两礼拜一次体检',
    ]) {
      expect(parser.parse(input).rrule, 'FREQ=WEEKLY;INTERVAL=2',
          reason: input);
    }
  });

  test('recognizes direct opt-out and on-time reminder wording', () {
    for (final input in [
      '不再提醒我明天交报告',
      '我不希望在截止前收到提醒明天交报告',
    ]) {
      final draft = parser.parse(input);
      expect(draft.reminderDisabled, isTrue, reason: input);
      expect(draft.reminderMinutes, isNull, reason: input);
    }
    for (final input in [
      '提醒我在截止时间交报告',
      '提醒我到点交报告',
    ]) {
      expect(parser.parse(input).reminderMinutes, 0, reason: input);
    }
  });

  test('recognizes quarterly and annual recurring expressions offline', () {
    final quarter = parser.parse('每季度做一次体检');
    expect(quarter.rrule, 'FREQ=MONTHLY;INTERVAL=3');
    expect(quarter.due, isNotNull);

    final annual = parser.parse('每年六月十五日体检');
    expect(annual.rrule, 'FREQ=YEARLY;BYMONTH=6;BYMONTHDAY=15');
    expect(annual.due, isNotNull);
    expect(annual.due!.toLocal().month, 6);
    expect(annual.due!.toLocal().day, 15);
  });

  test('recognizes a trailing reminder word without confusing 发通知', () {
    final draft = parser.parse('每天下午六点下班打卡提醒');

    expect(draft.rrule, 'FREQ=DAILY;BYHOUR=18;BYMINUTE=0;BYSECOND=0');
    expect(draft.reminderMinutes, 15);
    expect(draft.title, '打卡');
    expect(parser.parse('明天给客户发通知').reminderMinutes, isNull);
  });

  test('parses 中午 one o’clock as 13:00', () {
    final draft = parser.parse('明天中午1点吃饭');

    expect(draft.due, isNotNull);
    expect(draft.due!.toLocal().hour, 13);
    expect(draft.title, '吃饭');
  });

  test('does not normalize impossible dates or times into another reminder',
      () {
    final invalidDate = parser.parse('2月31日交报告');
    final invalidTime = parser.parse('明天25点开会');

    expect(invalidDate.due, isNull);
    expect(invalidDate.title, contains('2月31日'));
    expect(invalidTime.due, isNull);
    expect(invalidTime.title, contains('25点'));
  });

  test('does not guess Monday for an unspecified 下周 date', () {
    final draft = parser.parse('下周交报告');

    expect(draft.due, isNull);
    expect(draft.title, '交报告');
  });

  test('anchors quarterly month-end tasks at the next calendar quarter end',
      () {
    final draft = parser.parse('每季度末写季度总结');
    expect(draft.rrule, 'FREQ=MONTHLY;INTERVAL=3;BYMONTHDAY=-1');
    expect(draft.due, isNotNull);

    final due = draft.due!.toLocal();
    expect([3, 6, 9, 12], contains(due.month));
    expect(due.day, DateTime(due.year, due.month + 1, 0).day);
  });
}
