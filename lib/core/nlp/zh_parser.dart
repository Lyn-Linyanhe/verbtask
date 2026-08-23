/// 轻量中文自然语言任务解析（规则库）。覆盖：
/// 周期（每天/每周X/每月X号/每个工作日/每隔N天|周）、
/// 日期（今天/明天/后天/下周X/周X/本周X/X号/年月日/Y月X号）、
/// 时间（上午/下午/晚上 N点 / N:N）、优先级（高/中/低/紧急/重要/!/P1-P3）。
/// 返回的 draft 一律应再经用户确认后写入。
class ZhDraft {
  final String title;
  final String? listName; // #清单提示；由 UI 与现有清单名称匹配
  final DateTime? due; // UTC
  final bool dateOnly;
  final String? rrule; // RRULE
  final int? priority; // 1=低 2=中 3=高
  final int? reminderMinutes; // 到期前 N 分钟提醒；null=不提醒
  final bool reminderDisabled; // true=用户明确要求不要提醒
  const ZhDraft({
    required this.title,
    this.listName,
    this.due,
    this.dateOnly = true,
    this.rrule,
    this.priority,
    this.reminderMinutes,
    this.reminderDisabled = false,
  });
}

class ZhParser {
  ZhDraft parse(String input) {
    var text = input.trim();
    // 复合时间词归一化为基础词：明早/明晚/今早/今晚 -> 明天/今天 + 时间段
    text = text
        .replaceAll('明早', '明天上午')
        .replaceAll('明晚', '明天晚上')
        .replaceAll('今早', '今天上午')
        .replaceAll('今晚', '今天晚上')
        .replaceAll('每晚', '每天晚上')
        .replaceAll('每夜', '每天晚上')
        .replaceAll('大后天', '大后天'); // 占位，真实处理在日期分支
    String? listName;
    final listTag =
        RegExp(r'#([\u4e00-\u9fffA-Za-z0-9][\u4e00-\u9fffA-Za-z0-9_-]*)')
            .firstMatch(text);
    if (listTag != null) {
      listName = listTag.group(1);
      text = text.replaceFirst(listTag.group(0)!, ' ');
    }
    String? rrule;
    String? rruleToken;
    final quarterEnd = RegExp(
      r'每(?:个)?季度(?:末|末尾|最后(?:一天|一日))',
    ).hasMatch(text);
    final annualMonth = RegExp(
      r'每年\s*([0-9零一二两三四五六七八九十百]+)\s*月'
      r'(?:\s*([0-9零一二两三四五六七八九十百]+)\s*[号日])?',
    ).firstMatch(text);

    // ---- 周期 ----
    final workday = RegExp(r'每个工作日|每天工作日|每工作日');
    if (workday.hasMatch(text)) {
      rrule = 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR';
    } else if (quarterEnd || RegExp(r'每(?:个)?季度').hasMatch(text)) {
      rrule = 'FREQ=MONTHLY;INTERVAL=3';
      if (quarterEnd) rrule += ';BYMONTHDAY=-1';
    } else if (annualMonth != null) {
      rrule = 'FREQ=YEARLY;BYMONTH=${_cnToInt(annualMonth.group(1)!)}';
      final day = annualMonth.group(2);
      if (day != null) rrule += ';BYMONTHDAY=${_cnToInt(day)}';
    } else if (RegExp(r'每年(?:年末|年底|最后(?:一天|一日))').hasMatch(text)) {
      rrule = 'FREQ=YEARLY;BYMONTH=12;BYMONTHDAY=31';
    } else if (RegExp(r'每年').hasMatch(text)) {
      rrule = 'FREQ=YEARLY';
    } else if (_hasScheduleWord(text, '每天') ||
        _hasScheduleWord(text, '每日') ||
        _hasScheduleWord(text, '天天')) {
      rrule = 'FREQ=DAILY';
    } else {
      final everyNday =
          RegExp(r'(?:每隔\s*|每\s*)([0-9零一二两三四五六七八九十]+)\s*天(?:一次|做一次)?');
      final everyNweek =
          RegExp(r'(?:每隔|每)\s*([0-9零一二两三四五六七八九十]+)\s*(?:周|星期|礼拜)(?:一次|做一次)?');
      final everyNmonth =
          RegExp(r'(?:每隔|每)\s*([0-9零一二两三四五六七八九十]+)\s*个?月(?:一次|做一次)?');
      if (everyNday.hasMatch(text)) {
        final value = _cnToInt(everyNday.firstMatch(text)!.group(1)!);
        rrule = 'FREQ=DAILY;INTERVAL=$value';
      } else if (everyNweek.hasMatch(text)) {
        final value = _cnToInt(everyNweek.firstMatch(text)!.group(1)!);
        rrule = 'FREQ=WEEKLY;INTERVAL=$value';
        final days = _recurringWeekdays(text);
        if (days.isNotEmpty) rrule = '$rrule;BYDAY=${days.join(',')}';
      } else if (everyNmonth.hasMatch(text)) {
        final value = _cnToInt(everyNmonth.firstMatch(text)!.group(1)!);
        rrule = 'FREQ=MONTHLY;INTERVAL=$value';
      } else if (RegExp(r'(?:每\s*)?两天(?:一次|做一次)?|隔天').hasMatch(text)) {
        rrule = 'FREQ=DAILY;INTERVAL=2';
      } else if (RegExp(r'(?:每\s*)?两(?:周|星期|礼拜)(?:一次|做一次)?|隔周')
          .hasMatch(text)) {
        rrule = 'FREQ=WEEKLY;INTERVAL=2';
        final days = _recurringWeekdays(text);
        if (days.isNotEmpty) rrule = '$rrule;BYDAY=${days.join(',')}';
      } else if (RegExp(r'(?:每(?:个)?|每逢)\s*周末').hasMatch(text)) {
        rrule = 'FREQ=WEEKLY;BYDAY=SA,SU';
      } else {
        final days = _recurringWeekdays(text);
        if (days.isNotEmpty &&
            RegExp(r'(?:每逢|每隔|每)(?:周|星期|礼拜)').hasMatch(text)) {
          rrule = 'FREQ=WEEKLY;BYDAY=${days.join(',')}';
        } else if (text.contains('每周') ||
            text.contains('每星期') ||
            text.contains('每礼拜')) {
          rrule = 'FREQ=WEEKLY';
        } else {
          final monthlyByDay = RegExp(r'每个?月\s*([0-9零一二两三四五六七八九十百]+)\s*[号日]');
          final mb = monthlyByDay.firstMatch(text);
          if (mb != null) {
            rrule = 'FREQ=MONTHLY;BYMONTHDAY=${_cnToInt(mb.group(1)!)}';
          } else if (text.contains('每月') || text.contains('每个月')) {
            rrule = RegExp(r'每个?月\s*(?:月底|月末|最后(?:一天|一日))').hasMatch(text)
                ? 'FREQ=MONTHLY;BYMONTHDAY=-1'
                : 'FREQ=MONTHLY';
          }
        }
      }
    }

    // 记录要移除的周期 token 片段
    if (rrule != null) {
      final seg = _matchingSegment(text, [
        RegExp(r'每(?:个)?季度(?:末|末尾|最后(?:一天|一日))?'),
        RegExp(
            r'每年\s*[0-9零一二两三四五六七八九十百]+\s*月(?:\s*[0-9零一二两三四五六七八九十百]+\s*[号日])?'),
        RegExp(r'每年(?:年末|年底|最后(?:一天|一日))?'),
        RegExp(r'每隔\s*[0-9零一二两三四五六七八九十]+\s*天'),
        RegExp(r'(?:每隔|每)\s*[0-9零一二两三四五六七八九十]+\s*(?:周|星期|礼拜)(?:一次|做一次)?'),
        RegExp(r'(?:每隔|每)\s*[0-9零一二两三四五六七八九十]+\s*个?月(?:一次|做一次)?'),
        RegExp(r'每\s*[0-9零一二两三四五六七八九十]+\s*天(?:一次|做一次)?'),
        RegExp(r'(?:每\s*)?两天(?:一次|做一次)?'),
        RegExp(r'(?:每\s*)?两(?:周|星期|礼拜)(?:一次|做一次)?'),
        RegExp(r'隔天'),
        RegExp(r'隔周'),
        RegExp(r'(?:每(?:个)?|每逢)\s*周末'),
        RegExp(
            r'每(?:周|星期|礼拜)[一二三四五六日天]+(?:\s*(?:和|、|及|到|至|-|~|～)\s*(?:周|星期|礼拜)?[一二三四五六日天]+)*'),
        RegExp(r'每个?月\s*[0-9零一二两三四五六七八九十百]+\s*[号日]'),
        RegExp(r'每个?月\s*(?:月底|月末|最后(?:一天|一日))'),
        RegExp(r'每个月?'),
        RegExp(r'每天工作日'),
        RegExp(r'每个工作日'),
        RegExp(r'每工作日'),
        RegExp(r'天天'),
        RegExp(r'每日'),
        RegExp(r'每天'),
      ]);
      if (seg != null) {
        rruleToken = seg;
      }
    }
    if (rruleToken != null) text = text.replaceFirst(rruleToken, ' ');
    if (rrule != null) text = _stripRecurringSyntax(text);
    // 工作日有时会被前面的周期匹配拆成“每个 + 工作日”；周期已确认后，
    // 不应让残留的“工作日”进入行动标题。
    if (workday.hasMatch(input)) {
      text = text.replaceFirst(RegExp(r'工作日'), ' ');
    }

    // ---- 日期 ----
    DateTime? due;
    bool dateOnly = true;
    var invalidDate = false;
    var invalidTime = false;
    var ambiguousWeek = false;
    var oneTimeWeekday = false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (RegExp(r'(?:下|本|这)?周末').hasMatch(text)) {
      due = _nextWeekendDate(today, text);
      dateOnly = true;
    } else if (text.contains('大后天')) {
      due = today.add(const Duration(days: 3));
      dateOnly = true;
    } else if (text.contains('后天')) {
      due = today.add(const Duration(days: 2));
      dateOnly = true;
    } else if (text.contains('明天') || text.contains('明日')) {
      due = today.add(const Duration(days: 1));
      dateOnly = true;
    } else if (text.contains('今天') ||
        text.contains('今日') ||
        text.contains('现在')) {
      due = today;
      dateOnly = true;
    } else if (RegExp(r'下(?:周|星期)[一二三四五六日天]').hasMatch(text)) {
      final wd = RegExp(r'下(?:周|星期)([一二三四五六日天])').firstMatch(text)?.group(1);
      due = _nextWeekday(today, wdToNum(wd!), 1);
      dateOnly = true;
    } else if (text.contains('下周') || text.contains('下星期')) {
      ambiguousWeek = true;
      dateOnly = true;
    } else if (RegExp(r'(?:本|这)(?:周|星期)[一二三四五六日天]').hasMatch(text)) {
      final wd =
          RegExp(r'(?:本|这)(?:周|星期)([一二三四五六日天])').firstMatch(text)?.group(1);
      due = _nextWeekday(today, wdToNum(wd!), 0);
      dateOnly = true;
    } else if (text.contains('本周') ||
        text.contains('这周') ||
        text.contains('这星期')) {
      ambiguousWeek = true;
      dateOnly = true;
    } else if (RegExp(r'(?:周|星期|礼拜)([一二三四五六日天])').hasMatch(text) &&
        !RegExp(r'每').hasMatch(text)) {
      final wd = RegExp(r'(?:周|星期|礼拜)([一二三四五六日天])').firstMatch(text)!.group(1)!;
      due = _nextWeekday(today, wdToNum(wd), 0);
      dateOnly = true;
      oneTimeWeekday = true;
    } else if (RegExp(r'\d{4}[-/年]\d{1,2}[-/月]\d{1,2}[日]?').hasMatch(text)) {
      final m =
          RegExp(r'(\d{4})[-/年](\d{1,2})[-/月](\d{1,2})[日]?').firstMatch(text)!;
      final year = int.parse(m.group(1)!);
      final month = int.parse(m.group(2)!);
      final day = int.parse(m.group(3)!);
      if (_isValidDate(year, month, day)) {
        due = DateTime(year, month, day);
        dateOnly = true;
      } else {
        invalidDate = true;
      }
    } else if (RegExp(r'(\d{1,2})月(\d{1,2})[号日]').hasMatch(text)) {
      final m = RegExp(r'(\d{1,2})月(\d{1,2})[号日]').firstMatch(text)!;
      due =
          _thisMonthDay(today, int.parse(m.group(1)!), int.parse(m.group(2)!));
      dateOnly = true;
      invalidDate = due == null;
    } else if (RegExp(r'(\d+)号').hasMatch(text) &&
        !RegExp(r'每月').hasMatch(text)) {
      final m = RegExp(r'(\d+)号').firstMatch(text)!;
      due = _thisMonthDay(today, today.month, int.parse(m.group(1)!));
      dateOnly = true;
      invalidDate = due == null;
    } else if (RegExp(r'本月|这个月').hasMatch(text)) {
      due = DateTime(today.year, today.month + 1, 0);
      dateOnly = true;
    } else if (RegExp(r'下个月|下月').hasMatch(text)) {
      due = DateTime(today.year, today.month + 2, 0);
      dateOnly = true;
    } else if (text.contains('月底') || text.contains('月末')) {
      due = DateTime(today.year, today.month + 1, 0);
      dateOnly = true;
    }

    if (quarterEnd) {
      due = _nextQuarterEnd(today);
      dateOnly = true;
    }

    // 移除日期 token（仅当不在"每"周期里）
    final dateTokens = [
      '大后天',
      '后天',
      '明天',
      '明日',
      '今天',
      '今日',
      '现在',
      '本月',
      '这个月',
      '下个月',
      '下月',
    ];
    for (final t in dateTokens) {
      if (text.contains(t)) text = text.replaceAll(t, ' ');
    }
    text = text.replaceAll(RegExp(r'(?:下|本|这)?周末'), ' ');
    text = text.replaceAll(
        RegExp(r'(?:下|本|这|那)(?:周|星期|礼拜)[一二三四五六日天]?|(?:周|星期|礼拜)[一二三四五六日天](?!报)'),
        ' ');
    if (!invalidDate) {
      text =
          text.replaceAll(RegExp(r'\d{4}[-/年]\d{1,2}[-/月]\d{1,2}[日号]?'), ' ');
      text = text.replaceAll(RegExp(r'\d{1,2}月\d{1,2}[号日]'), ' ');
      text = text.replaceAll(RegExp(r'\d+号'), ' ');
    }
    text = text.replaceAll(RegExp(r'月底前|月末前|月底|月末|最后(?:一天|一日)'), ' ');

    // ---- 时间 ----
    int? hour;
    int minute = 0;
    final amPm = RegExp(r'(上午|下午|晚上|傍晚|凌晨|早上|早晨|清晨|夜晚|中午|晚)');
    final timeToken = RegExp(r'((?:\d{1,2})|(?:[零一二两三四五六七八九十]+))'
        r'(?:\s*[:：]\s*((?:\d{1,2})|(?:[零一二两三四五六七八九十]+))'
        r'|\s*点(半|一刻|三刻)?)');
    final tm = timeToken.firstMatch(text);
    if (tm != null) {
      final h = _cnToInt(tm.group(1)!);
      final mm = tm.group(2) != null ? _cnToInt(tm.group(2)!) : null;
      minute = mm ??
          (tm.group(3) == '半'
              ? 30
              : tm.group(3) == '一刻'
                  ? 15
                  : tm.group(3) == '三刻'
                      ? 45
                      : 0);
      var resolved = h;
      final marker = amPm.firstMatch(text)?.group(1);
      if (marker == '下午' ||
          marker == '晚上' ||
          marker == '傍晚' ||
          marker == '夜晚' ||
          marker == '晚') {
        resolved = h < 12 ? h + 12 : h;
      } else if (marker == '凌晨' && h == 12) {
        resolved = 0;
      } else if (marker == '中午') {
        resolved = h < 12 ? h + 12 : h;
      }
      if (h <= 23 && minute <= 59 && resolved <= 23) {
        hour = resolved;
        dateOnly = false;
        text = text.replaceAll(tm.group(0)!, ' ');
        if (marker != null) text = text.replaceAll(marker, ' ');
      } else {
        invalidTime = true;
      }
    }

    // 无显式数字时刻时的“时间段默认时刻”（与 LLM 提示词规则一致）
    if (hour == null && tm == null) {
      int? dh;
      if (text.contains('下班') || text.contains('傍晚')) {
        dh = 18;
      } else if (text.contains('睡前')) {
        dh = 23;
      } else if (text.contains('下午')) {
        dh = 15;
      } else if (text.contains('中午')) {
        dh = 12;
      } else if (text.contains('晚上') || text.contains('夜晚')) {
        dh = 20;
      } else if (text.contains('上午') ||
          text.contains('早上') ||
          text.contains('早晨') ||
          text.contains('清晨')) {
        dh = 9;
      } else if (text.contains('凌晨')) {
        dh = 0;
      }
      if (dh != null) {
        hour = dh;
        dateOnly = false;
      }
    }

    // 重复任务也必须有一个系列起点，否则提醒预排无法展开。若用户说了
    // 星期几或每月几号，首个实例必须落在该规则对应的日期，而不是今天。
    if (rrule != null && due == null) {
      due = _recurringAnchor(
        rrule,
        today: today,
        now: now,
        hour: hour,
        minute: minute,
      );
    }
    if (rrule != null && due == null) due = today;

    // 普通任务：仅时刻默认今天；重复任务：时刻写进 rrule，同时保留首个实例的截止时刻。
    if (hour != null) {
      if (rrule != null) {
        final base = due ?? today;
        due = DateTime(base.year, base.month, base.day, hour, minute).toUtc();
        rrule = '$rrule;BYHOUR=$hour;BYMINUTE=$minute;BYSECOND=0';
        dateOnly = false;
      } else if (invalidDate || ambiguousWeek) {
        due = null;
      } else {
        final base = due ?? today;
        var timed = DateTime(base.year, base.month, base.day, hour, minute);
        if (oneTimeWeekday && timed.isBefore(now)) {
          timed = timed.add(const Duration(days: 7));
        }
        due = timed.toUtc();
        dateOnly = false;
      }
    } else if (due != null) {
      due = DateTime.utc(due.year, due.month, due.day);
    }
    if (invalidTime) due = null;
    // 无具体时刻的纯时间段词（上午/晚上/凌晨等）也要从标题剥离
    text = text.replaceAll(
        RegExp(r'上午|早上|早晨|清晨|下午|晚上|傍晚|凌晨|中午|白天|夜晚|下班后|下班|睡前|临睡前|帮我|麻烦你|请你'),
        ' ');
    // “给我”既可能是句首祈使（给我记下……），也可能是动作的
    // 接收者（把周报交给我）；只清理句首用法，避免损坏标题语义。
    text = text.replaceFirst(RegExp(r'^\s*给我\s*'), ' ');

    // ---- 提醒 ----
    final reminderOptOut = hasReminderOptOut(text);
    int? reminderMinutes;
    String reminderToken = '';
    if (!reminderOptOut) {
      for (final (pat, mul) in <(RegExp, int)>[
        (RegExp(r'(?:提前|提早)\s*半\s*天'), 720),
        (RegExp(r'(?:提前|提早)\s*半\s*个?\s*小时'), 30),
        (RegExp(r'(?:提前|提早)\s*([0-9零一二两三四五六七八九十]+)\s*分钟'), 1),
        (RegExp(r'(?:提前|提早)\s*([0-9零一二两三四五六七八九十]+)\s*个?\s*小时'), 60),
        (RegExp(r'(?:提前|提早)\s*([0-9零一二两三四五六七八九十]+)\s*天'), 1440),
      ]) {
        final m = pat.firstMatch(text);
        if (m != null) {
          reminderMinutes = m.groupCount == 0
              ? mul
              : (m.group(1) == null ? mul : _cnToInt(m.group(1)!) * mul);
          reminderToken = m.group(0)!;
          break;
        }
      }
    }
    if (reminderToken.isNotEmpty) text = text.replaceFirst(reminderToken, ' ');
    if (reminderMinutes == null && !reminderOptOut && wantsReminder(text)) {
      reminderMinutes =
          _isOnTimeReminder(text) ? 0 : 15; // 到点/准时=0；其余提醒意图未给提前量→默认提前15分钟
    }
    text = _stripReminderSyntax(text);

    // ---- 优先级 ----
    int? priority;
    String? priorityToken;
    for (final (pattern, value) in <(RegExp, int)>[
      (
        RegExp(
          r'紧急|p1\b|!{2,}|高\s*优先级|'
          r'(?:最\s*重要(?:的事)?|(?:非常\s*)+重要(?:的事)?)|'
          r'优先级\s*(?:为|是|[：:])?\s*(?:最高|高)|'
          r'(?<![\u4e00-\u9fff])高(?![\u4e00-\u9fff])',
          caseSensitive: false,
        ),
        3,
      ),
      (
        RegExp(
          r'(?:这个\s*)?(?:很\s*)?重要(?:的事)?|p2\b|中\s*优先级|'
          r'优先级\s*(?:为|是|[：:])?\s*中|'
          r'(?<![\u4e00-\u9fff])中(?![\u4e00-\u9fff])|!',
          caseSensitive: false,
        ),
        2,
      ),
      (
        RegExp(
          r'p3\b|低\s*优先级|'
          r'优先级\s*(?:为|是|[：:])?\s*低|'
          r'(?<![\u4e00-\u9fff])低(?![\u4e00-\u9fff])',
          caseSensitive: false,
        ),
        1,
      ),
    ]) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        priority = value;
        priorityToken = match.group(0);
        break;
      }
    }
    if (priorityToken != null) text = text.replaceFirst(priorityToken, ' ');

    var title = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    title = title.replaceFirst(RegExp(r'^[\s：:，,。.、]+'), '');
    title = title.replaceFirst(RegExp(r'^(?:截止|到期)?\s*(?:前|之前|以前)\s*'), '');
    title = title.replaceFirst(RegExp(r'^前\s*'), '');
    title = title.replaceFirst(RegExp(r'^(?:老板|领导)\s*说\s*'), '');
    title =
        title.replaceFirst(RegExp(r'^要(?=把|去|做|交|发|买|写|给|联系|准备|提交|开始)\s*'), '');
    title = title.replaceFirst(RegExp(r'^普通\s*[:：，,]?\s*'), '');
    // “下周二开始”是对安排的补充，不是行动本身；日期/时刻剥离后清掉
    // 这类句尾调度填充词，避免确认框显示“体检，开始”。
    title = title.replaceFirst(RegExp(r'[，,、；;]?\s*(?:开始|起|执行|进行)\s*$'), '');
    title =
        title.replaceFirst(RegExp(r'[，,、；;]?\s*(?:吧|啊|呀|啦|呢|哦|喽|就)\s*$'), '');
    title =
        title.replaceFirst(RegExp(r'[，,、；;]?\s*(?:吧|啊|呀|啦|呢|哦|喽|就)\s*$'), '');
    title = title.replaceFirst(RegExp(r'^[\s：:，,。.、]+'), '');
    title = title.replaceFirst(RegExp(r'[\s：:，,。.、]+$'), '');
    title = title.replaceAll(
        RegExp(r'(?<=[\u4e00-\u9fff])\s+(?=[\u4e00-\u9fff])'), '');
    return ZhDraft(
      title: isNonActionableInput(input)
          ? ''
          : (title.isEmpty ? input.trim() : title),
      listName: listName,
      due: due,
      dateOnly: dateOnly,
      rrule: rrule,
      priority: priority,
      reminderMinutes: reminderMinutes,
      reminderDisabled: reminderOptOut,
    );
  }

  String? _matchingSegment(String text, List<RegExp> patterns) {
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) return m.group(0)!;
    }
    return null;
  }

  /// 判断一个频率词是否像调度语句，而不是标题中的修饰语。
  /// 例如“明天买每天都要吃的药”里的“每天”属于定语，不应创建每日重复任务。
  static bool _hasScheduleWord(String text, String word) {
    for (final match in RegExp(RegExp.escape(word)).allMatches(text)) {
      final rest = text.substring(match.end);
      if (rest.startsWith('都')) continue;
      return true;
    }
    return false;
  }

  /// 从“每周一和周三”“每周一到周五”“每周六日”等口语中提取星期。
  List<String> _recurringWeekdays(String text) {
    final found = <int>{};
    final range = RegExp(
      r'(?:周|星期|礼拜)([一二三四五六日天])\s*'
      r'(?:到|至|-|~|～)\s*(?:周|星期|礼拜)?([一二三四五六日天])',
    ).firstMatch(text);
    if (range != null) {
      final start = wdToNum(range.group(1)!);
      final end = wdToNum(range.group(2)!);
      if (start <= end) {
        for (var day = start; day <= end; day++) {
          found.add(day);
        }
      } else {
        found
          ..add(start)
          ..add(end);
      }
    }
    for (final match in RegExp(
      r'(?:周|星期|礼拜)([一二三四五六日天]+)',
    ).allMatches(text)) {
      // “两周一次” contains the character sequence “周一”，but it is
      // an interval expression rather than Monday.
      if (match.end < text.length && text[match.end] == '次') continue;
      for (final ch in match.group(1)!.split('')) {
        found.add(wdToNum(ch));
      }
    }
    final ordered = found.toList()..sort();
    return ordered.map((day) => _dayCode(day)).toList();
  }

  static String _dayCode(int day) => const [
        '',
        'MO',
        'TU',
        'WE',
        'TH',
        'FR',
        'SA',
        'SU',
      ][day.clamp(1, 7)];

  /// 清理已经确定为周期语法的残余文本，避免“每逢”“和”“周五”等漏进标题。
  static String _stripRecurringSyntax(String text) {
    var result = text;
    for (final pattern in [
      RegExp(r'每隔\s*[0-9零一二两三四五六七八九十]+\s*(?:天|周|星期|礼拜|个?月)'),
      RegExp(r'每\s*[0-9零一二两三四五六七八九十]+\s*(?:周|星期|礼拜|个?月)(?:一次|做一次)?'),
      RegExp(r'每\s*[0-9零一二两三四五六七八九十]+\s*天(?:一次|做一次)?'),
      RegExp(r'(?:每\s*)?两(?:天|周)(?:一次|做一次)?'),
      RegExp(r'隔(?:天|周)'),
      RegExp(r'(?:每个|每逢|每周)?周末'),
      RegExp(r'每逢(?:周|星期|礼拜)[一二三四五六日天]+'),
      RegExp(
          r'每(?:周|星期|礼拜)[一二三四五六日天]+(?:\s*(?:和|、|及|到|至|-|~|～)\s*(?:周|星期|礼拜)?[一二三四五六日天]+)*'),
      // “下周二/本周五”是一次性日期锚点，不能在周期清理时删掉。
      RegExp(r'(?<!下)(?<!本)(?<!这)(?<!那)(?:周|星期|礼拜)[一二三四五六日天]+'),
      RegExp(r'每(?:周|星期|礼拜)'),
      RegExp(r'每(?:个)?工作日'),
      RegExp(r'天天|每日|每天'),
      RegExp(r'每个?月(?:月底|月末|\s*[0-9零一二两三四五六七八九十百]+\s*[号日])?'),
    ]) {
      result = result.replaceFirst(pattern, ' ');
    }
    return result;
  }

  /// 计算重复系列的第一个可用日期。RRULE 只描述后续节奏，首个 due
  /// 仍需要尊重用户说出的星期几、每月几号和固定时刻。
  static DateTime? _recurringAnchor(
    String rrule, {
    required DateTime today,
    required DateTime now,
    required int? hour,
    required int minute,
  }) {
    DateTime at(DateTime date) => hour == null
        ? DateTime(date.year, date.month, date.day)
        : DateTime(date.year, date.month, date.day, hour, minute);
    bool available(DateTime date, DateTime candidate) =>
        hour == null ? !date.isBefore(today) : !candidate.isBefore(now);

    final monthly = RegExp(r'FREQ=MONTHLY').hasMatch(rrule);
    if (monthly) {
      final raw = RegExp(r'BYMONTHDAY=(-?\d+)').firstMatch(rrule)?.group(1);
      if (raw == null) return today;
      final day = int.parse(raw);
      for (var monthOffset = 0; monthOffset < 24; monthOffset++) {
        final monthStart = DateTime(today.year, today.month + monthOffset, 1);
        final date = day == -1
            ? DateTime(monthStart.year, monthStart.month + 1, 0)
            : DateTime(monthStart.year, monthStart.month, day);
        // Skip invalid dates such as BYMONTHDAY=31 in a 30-day month.
        if (day > 0 && date.month != monthStart.month) continue;
        final candidate = at(date);
        if (available(date, candidate)) return date;
      }
      return today;
    }

    final yearly = RegExp(r'FREQ=YEARLY').hasMatch(rrule);
    if (yearly) {
      final month = int.tryParse(
          RegExp(r'BYMONTH=(\d+)').firstMatch(rrule)?.group(1) ?? '');
      final rawDay = RegExp(r'BYMONTHDAY=(-?\d+)').firstMatch(rrule)?.group(1);
      if (month == null) return today;
      final day = rawDay == null ? 1 : int.parse(rawDay);
      for (var yearOffset = 0; yearOffset < 12; yearOffset++) {
        final year = today.year + yearOffset;
        final date = day == -1
            ? DateTime(year, month + 1, 0)
            : DateTime(year, month, day);
        if (day > 0 && date.month != month) continue;
        final candidate = at(date);
        if (available(date, candidate)) return date;
      }
      return today;
    }

    final byday = RegExp(r'BYDAY=([^;]+)').firstMatch(rrule);
    if (byday != null) {
      final raw = byday.group(1) ?? '';
      final days =
          raw.split(',').map(_weekdayFromCode).whereType<int>().toSet();
      for (var offset = 0; offset < 14; offset++) {
        final date = today.add(Duration(days: offset));
        if (!days.contains(date.weekday)) continue;
        final candidate = at(date);
        if (available(date, candidate)) return date;
      }
    }

    if (hour != null) {
      final candidate = at(today);
      if (candidate.isBefore(now)) return today.add(const Duration(days: 1));
    }
    return today;
  }

  static int? _weekdayFromCode(String code) => const {
        'MO': DateTime.monday,
        'TU': DateTime.tuesday,
        'WE': DateTime.wednesday,
        'TH': DateTime.thursday,
        'FR': DateTime.friday,
        'SA': DateTime.saturday,
        'SU': DateTime.sunday,
      }[code.trim().toUpperCase()];

  static DateTime _nextQuarterEnd(DateTime today) {
    var month = ((today.month - 1) ~/ 3 + 1) * 3;
    var end = DateTime(today.year, month + 1, 0);
    if (end.isBefore(today)) {
      month += 3;
      end = DateTime(today.year, month + 1, 0);
    }
    return end;
  }

  /// Reject conversational filler that does not contain an actionable note.
  /// This is intentionally conservative: only whole-input acknowledgements
  /// match, so a real note with a polite prefix is preserved.
  static bool isNonActionableInput(String input) {
    final normalized = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s，,。.!！？?、；;:：]+'), '');
    if (normalized.isEmpty) return true;
    return RegExp(
      r'^(?:哦+|嗯+|啊+|呃+|诶+|对+|好+|哈哈+|'
      r'ok(?:ay)?|收到|知道了|明白了|谢谢|没事|算了|我想起来了|'
      r'(?:哦|嗯|啊|对|好)+我想起来了)$',
    ).hasMatch(normalized);
  }

  /// 判断用户是否明确关闭提醒。允许自然语言中出现“再、收到、截止前”等插入语。
  static bool hasReminderOptOut(String text) {
    const word = r'(?:(?:发|发送|推送|弹出)\s*)?(?:提醒|提示|通知|叫醒|叫我|设闹钟|定闹钟|闹钟)';
    return RegExp(
      r'(?:不用|无需|不需要|不必|不要|勿|别)\s*(?:再|继续)?\s*'
      r'(?:提前\s*)?(?:给我|帮我)?\s*(?:提醒|提示|通知)\s*我?|'
      r'(?:不用|无需|不需要|不必|不要|勿|别)\s*(?:再|继续)?\s*'
      r'(?:给我|帮我)?\s*'
      r'(?:(?:在[^，,。；;]{0,20})|到点|准时|截止前|截止时)?\s*'
      r'(?:提前\s*(?:半\s*天|半\s*个?\s*小时|'
      r'[0-9零一二两三四五六七八九十]+\s*(?:分钟|个?\s*小时|天))\s*)?'
      '$word|'
      r'(?:我\s*)?(?:不想|不希望|不愿意)\s*(?:再\s*)?'
      r'(?:在[^，,。；;]{0,20}\s*)?(?:被|收到|接受)?\s*'
      '$word|'
      r'请\s*(?:不要|别|勿)\s*(?:在[^，,。；;]{0,20})?\s*'
      '$word|'
      r'(?:不用|无需|不需要|不必)\s*(?:再\s*)?(?:收到|接受)\s*'
      '$word|'
      r'不\s*(?:再|继续)?\s*'
      '$word',
    ).hasMatch(text);
  }

  /// 判断用户是否发出了提醒祈使。单独的“通知”名词（如“发通知”）不算提醒。
  static bool wantsReminder(String text) {
    if (hasReminderOptOut(text)) return false;
    return RegExp(
      r'(?:提醒|提示|通知)\s*我|(?:叫醒|叫我|设闹钟|定闹钟)|闹钟|'
      r'记得(?:提醒)?|记着|记住|别忘了?|不要忘记|记一下|喊我|'
      r'到点\s*(?:提醒|提示|通知|叫我)|准时\s*(?:提醒|提示|通知|叫我)|'
      r'(?<!发)(?<!送)(?:提醒|提示)\s*[。！？!?]?$',
    ).hasMatch(text);
  }

  static bool _isOnTimeReminder(String text) => RegExp(
        r'(?:到点|准时|截止时|截止时间)\s*(?:提醒|提示|通知|叫我)|'
        r'(?:提醒|提示|通知)\s*我\s*(?:在\s*)?'
        r'(?:到点|准时|截止时|截止时间)',
      ).hasMatch(text);

  static String _stripReminderSyntax(String text) {
    var result = text;
    const word = r'(?:(?:发|发送|推送|弹出)\s*)?(?:提醒|提示|通知|叫醒|叫我|设闹钟|定闹钟|闹钟)';
    // “提前提醒我”没有具体提前量；“提前”本身不是行动标题的一部分。
    result = result.replaceAll(RegExp(r'提前\s*(?=' '$word)'), ' ');
    for (final pattern in [
      RegExp(r'(?:不用|无需|不需要|不必|不要|勿|别)\s*(?:再|继续)?\s*'
          r'(?:提前\s*)?(?:给我|帮我)?\s*(?:提醒|提示|通知)\s*我?'),
      RegExp(r'(?:不用|无需|不需要|不必|不要|勿|别)\s*(?:再|继续)?\s*'
          r'(?:给我|帮我)?\s*'
          r'(?:(?:在[^，,。；;]{0,20})|到点|准时|截止前|截止时)?\s*'
          r'(?:提前\s*(?:半\s*天|半\s*个?\s*小时|'
          r'[0-9零一二两三四五六七八九十]+\s*(?:分钟|个?\s*小时|天))\s*)?'
          '$word'),
      RegExp(r'(?:我\s*)?(?:不想|不希望|不愿意)\s*(?:再\s*)?'
          r'(?:在[^，,。；;]{0,20}\s*)?(?:被|收到|接受)?\s*'
          '$word'),
      RegExp(r'请\s*(?:不要|别|勿)\s*(?:在[^，,。；;]{0,20})?\s*' '$word'),
      RegExp(r'(?:不用|无需|不需要|不必)\s*(?:再\s*)?(?:收到|接受)\s*' '$word'),
      RegExp(r'不\s*(?:再|继续)?\s*' '$word'),
      RegExp(r'到点\s*|准时\s*'),
      RegExp(r'(?:提醒|提示|通知)\s*我\s*(?:在\s*)?(?:到点|准时|截止时|截止时间)'),
      RegExp(r'(?:提醒|提示|通知)\s*我'),
      RegExp(r'(?:叫醒|叫我|设闹钟|定闹钟|闹钟)'),
      RegExp(r'记得(?:提醒)?|记着|记住|别忘了?|不要忘记|记一下|喊我'),
      RegExp(r'(?<!发)(?<!送)(?:提醒|提示)\s*[。！？!?]?$'),
    ]) {
      result = result.replaceAll(pattern, ' ');
    }
    return result;
  }

  /// 中文数字（含“两/十/二十/十一”等）与阿拉伯数字 → int。
  static int _cnToInt(String s) {
    s = s.trim();
    final digit = int.tryParse(s);
    if (digit != null) return digit;
    const map = {
      '零': 0,
      '〇': 0,
      '一': 1,
      '二': 2,
      '两': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
    };
    const units = {'十': 10, '百': 100, '千': 1000, '万': 10000};
    var total = 0;
    var section = 0;
    var number = 0;
    for (final char in s.split('')) {
      final value = map[char];
      if (value != null) {
        number = value;
        continue;
      }
      final unit = units[char];
      if (unit == null) continue;
      if (unit == 10000) {
        section += number;
        total += (section == 0 ? 1 : section) * unit;
        section = 0;
      } else {
        section += (number == 0 ? 1 : number) * unit;
      }
      number = 0;
    }
    return total + section + number;
  }

  static String wdToDay(String w) {
    const map = {
      '一': 'MO',
      '二': 'TU',
      '三': 'WE',
      '四': 'TH',
      '五': 'FR',
      '六': 'SA',
      '日': 'SU',
      '天': 'SU'
    };
    return map[w] ?? 'MO';
  }

  static int wdToNum(String w) {
    const map = {
      '一': 1,
      '二': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '日': 7,
      '天': 7
    };
    return map[w] ?? 1;
  }

  DateTime _nextWeekday(DateTime from, int targetWeekday, int weekOffset) {
    // targetWeekday 1=周一..7=周日；weekOffset 0=本周,1=下周
    final current = from.weekday; // 1=Mon..7=Sun
    if (weekOffset == 1) {
      // “下周二”指下一个自然周的周二，而不是从今天起第一个周二。
      final daysUntilNextMonday = 7 - current;
      return from.add(Duration(days: daysUntilNextMonday + targetWeekday));
    }
    var diff = targetWeekday - current;
    if (diff < 0) diff += 7;
    return from.add(Duration(days: diff));
  }

  DateTime? _thisMonthDay(DateTime today, int month, int day) {
    final year =
        month < today.month || (month == today.month && day < today.day)
            ? today.year + 1
            : today.year;
    if (!_isValidDate(year, month, day)) return null;
    return DateTime(year, month, day);
  }

  static bool _isValidDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1) return false;
    final value = DateTime(year, month, day);
    return value.year == year && value.month == month && value.day == day;
  }

  DateTime _nextWeekendDate(DateTime today, String text) {
    if (text.contains('下周末')) {
      // 下周末指下一个自然周的周六，而不是从周日倒推到本周五。
      final daysUntilNextMonday = 8 - today.weekday;
      return today.add(Duration(days: daysUntilNextMonday + 5));
    }

    if (today.weekday == DateTime.sunday) return today;
    final daysUntilSaturday = DateTime.saturday - today.weekday;
    return today.add(Duration(days: daysUntilSaturday));
  }
}
