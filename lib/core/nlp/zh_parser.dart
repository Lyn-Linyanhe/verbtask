/// 轻量中文自然语言任务解析（规则库）。覆盖：
/// 周期（每天/每周X/每月X号/每个工作日/每隔N天|周）、
/// 日期（今天/明天/后天/下周X/周X/本周X/X号/年月日/Y月X号）、
/// 时间（上午/下午/晚上 N点 / N:N）、优先级（高/中/低/紧急/重要/!/P1-P3）。
/// 返回的 draft 一律应再经用户确认后写入。
class ZhDraft {
  final String title;
  final DateTime? due; // UTC
  final bool dateOnly;
  final String? rrule; // RRULE
  final int? priority; // 1=低 2=中 3=高
  const ZhDraft({
    required this.title,
    this.due,
    this.dateOnly = true,
    this.rrule,
    this.priority,
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
        .replaceAll('大后天', '大后天'); // 占位，真实处理在日期分支
    String? rrule;
    String? rruleToken;

    // ---- 周期 ----
    final workday = RegExp(r'每个工作日|每天工作日|每工作日');
    if (workday.hasMatch(text)) { rrule = 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR'; }
    else if (text.contains('每天') || text.contains('每日')) { rrule = 'FREQ=DAILY'; }
    else {
      final everyNday = RegExp(r'每隔\s*(\d+)\s*天');
      final everyNweek = RegExp(r'每隔\s*(\d+)\s*周');
      if (everyNday.hasMatch(text)) {
        rrule = 'FREQ=DAILY;INTERVAL=${everyNday.firstMatch(text)!.group(1)}';
      } else if (everyNweek.hasMatch(text)) {
        rrule = 'FREQ=WEEKLY;INTERVAL=${everyNweek.firstMatch(text)!.group(1)}';
      } else {
        final weekly = RegExp(r'每(?:周|星期|礼拜)([一二三四五六日天]+)');
        final m = weekly.firstMatch(text);
        if (m != null) {
          final days = m.group(1)!;
          final seen = <String>{};
          final list = <String>[];
          for (final ch in days.split('')) {
            if (seen.add(ch)) list.add(wdToDay(ch));
          }
          rrule = list.isEmpty ? 'FREQ=WEEKLY' : 'FREQ=WEEKLY;BYDAY=${list.join(',')}';
        } else if (text.contains('每周') || text.contains('每星期')) {
          rrule = 'FREQ=WEEKLY';
        } else {
          final monthlyByDay = RegExp(r'每月\s*(\d+)\s*号');
          final mb = monthlyByDay.firstMatch(text);
          if (mb != null) {
            rrule = 'FREQ=MONTHLY;BYMONTHDAY=${mb.group(1)}';
          } else if (text.contains('每月') || text.contains('每个月')) {
            rrule = 'FREQ=MONTHLY';
          }
        }
      }
    }

    // 记录要移除的周期 token 片段
    if (rrule != null) {
      final seg = _matchingSegment(text, [
        RegExp(r'每隔\s*\d+\s*天'), RegExp(r'每隔\s*\d+\s*周'),
        RegExp(r'每(?:周|星期|礼拜)[一二三四五六日天]+'),
        RegExp(r'每月\s*\d+\s*号'), RegExp(r'每个月?'), RegExp(r'每天工作日'),
        RegExp(r'每个工作日'), RegExp(r'每工作日'), RegExp(r'每日'), RegExp(r'每天'),
      ]);
      if (seg != null) { rruleToken = seg; }
    }
    if (rruleToken != null) text = text.replaceFirst(rruleToken, ' ');

    // ---- 日期 ----
    DateTime? due;
    bool dateOnly = true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (text.contains('大后天')) {
      due = today.add(const Duration(days: 3)); dateOnly = true;
    } else if (text.contains('后天')) {
      due = today.add(const Duration(days: 2)); dateOnly = true;
    } else if (text.contains('明天') || text.contains('明日')) {
      due = today.add(const Duration(days: 1)); dateOnly = true;
    } else if (text.contains('今天') || text.contains('今日') || text.contains('现在')) {
      due = today; dateOnly = true;
    } else if (text.contains('下周') || text.contains('下星期')) {
      final wd = RegExp(r'下(?:周|星期)([一二三四五六日天])').firstMatch(text)?.group(1);
      due = _nextWeekday(today, wdToNum(wd ?? '一'), 1); dateOnly = true;
    } else if (text.contains('本周') || text.contains('这周') || text.contains('这星期')) {
      final wd = RegExp(r'(?:本|这)(?:周|星期)([一二三四五六日天])').firstMatch(text)?.group(1);
      due = _nextWeekday(today, wdToNum(wd ?? '一'), 0); dateOnly = true;
    } else if (RegExp(r'(?:周|星期|礼拜)([一二三四五六日天])').hasMatch(text) && !RegExp(r'每').hasMatch(text)) {
      final wd = RegExp(r'(?:周|星期|礼拜)([一二三四五六日天])').firstMatch(text)!.group(1)!;
      due = _nextWeekday(today, wdToNum(wd), 0); dateOnly = true;
    } else if (RegExp(r'(\d{1,2})月(\d{1,2})[号日]').hasMatch(text)) {
      final m = RegExp(r'(\d{1,2})月(\d{1,2})[号日]').firstMatch(text)!;
      due = _thisMonthDay(today, int.parse(m.group(1)!), int.parse(m.group(2)!)); dateOnly = true;
    } else if (RegExp(r'(\d+)号').hasMatch(text) && !RegExp(r'每月').hasMatch(text)) {
      final m = RegExp(r'(\d+)号').firstMatch(text)!;
      due = _thisMonthDay(today, today.month, int.parse(m.group(1)!)); dateOnly = true;
    } else if (RegExp(r'\d{4}[-/年]\d{1,2}[-/月]\d{1,2}[日]?').hasMatch(text)) {
      final m = RegExp(r'(\d{4})[-/年](\d{1,2})[-/月](\d{1,2})[日]?').firstMatch(text)!;
      due = DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!)); dateOnly = true;
    } else if (text.contains('月底') || text.contains('月末')) {
      due = DateTime(today.year, today.month + 1, 0); dateOnly = true;
    }

    // 移除日期 token（仅当不在"每"周期里）
    final dateTokens = ['大后天','后天','明天','明日','今天','今日','现在'];
    for (final t in dateTokens) { if (text.contains(t)) text = text.replaceAll(t, ' '); }
    text = text.replaceAll(RegExp(r'(?:下|本|这|那)(?:周|星期|礼拜)[一二三四五六日天]?|(?:周|星期|礼拜)[一二三四五六日天](?!报)'), ' ');
    text = text.replaceAll(RegExp(r'\d{1,2}月\d{1,2}[号日]'), ' ');
    text = text.replaceAll(RegExp(r'\d+号'), ' ');
    text = text.replaceAll(RegExp(r'\d{4}[-/年]\d{1,2}[-/月]\d{1,2}[日]?'), ' ');
    text = text.replaceAll(RegExp(r'月底前|月末前|月底|月末'), ' ');

    // ---- 时间 ----
    int? hour; int minute = 0;
    final amPm = RegExp(r'(上午|下午|晚上|傍晚|凌晨)');
    final timeToken = RegExp(r'(\d{1,2})([:：](\d{1,2}))?\s*点(半)?');
    final tm = timeToken.firstMatch(text);
    if (tm != null) {
      final h = int.parse(tm.group(1)!);
      minute = tm.group(3) != null ? int.parse(tm.group(3)!) : (tm.group(4) == '半' ? 30 : 0);
      var resolved = h;
      final marker = amPm.firstMatch(text)?.group(1);
      if (marker == '下午' || marker == '晚上' || marker == '傍晚') {
        resolved = h < 12 ? h + 12 : h;
      } else if (marker == '凌晨' && h == 12) {
        resolved = 0;
      }
      hour = resolved;
      dateOnly = false;
      text = text.replaceAll(tm.group(0)!, ' ');
      if (marker != null) text = text.replaceAll(marker, ' ');
    }

    // 普通任务：仅时刻默认今天；重复任务：时刻写进 rrule（与 LLM 路径语义一致）
    if (hour != null) {
      if (rrule != null) {
        rrule = '$rrule;BYHOUR=$hour;BYMINUTE=$minute;BYSECOND=0';
        dateOnly = false;
      } else {
        final base = due ?? today;
        due = DateTime(base.year, base.month, base.day, hour, minute).toUtc();
        dateOnly = false;
      }
    } else if (due != null) {
      due = DateTime.utc(due.year, due.month, due.day);
    }
    // 无具体时刻的纯时间段词（上午/晚上/凌晨等）也要从标题剥离
    text = text.replaceAll(RegExp(r'上午|下午|晚上|傍晚|凌晨|中午|白天|夜晚'), ' ');

    // ---- 优先级 ----
    int? priority;
    if (RegExp(r'紧急|p1|!{2,}').hasMatch(text.toLowerCase())) { priority = 3; }
    else if (RegExp(r'重要|高|p2|!').hasMatch(text.toLowerCase())) { priority = 2; }
    else if (RegExp(r'低|p3').hasMatch(text.toLowerCase())) { priority = 1; }
    text = text.replaceAll(RegExp(r'紧急|重要|高|中|低|P[1-3]|!'), ' ');

    var title = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    title = title.replaceFirst(RegExp(r'^[\s：:，,。.、]+'), '');
    title = title.replaceFirst(RegExp(r'[\s：:，,。.、]+$'), '');
    return ZhDraft(
      title: title.isEmpty ? input.trim() : title,
      due: due,
      dateOnly: dateOnly,
      rrule: rrule,
      priority: priority,
    );
  }

  String? _matchingSegment(String text, List<RegExp> patterns) {
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) return m.group(0)!;
    }
    return null;
  }

  static String wdToDay(String w) {
    const map = {'一':'MO','二':'TU','三':'WE','四':'TH','五':'FR','六':'SA','日':'SU','天':'SU'};
    return map[w] ?? 'MO';
  }

  static int wdToNum(String w) {
    const map = {'一':1,'二':2,'三':3,'四':4,'五':5,'六':6,'日':7,'天':7};
    return map[w] ?? 1;
  }

  DateTime _nextWeekday(DateTime from, int targetWeekday, int weekOffset) {
    // targetWeekday 1=周一..7=周日；weekOffset 0=本周,1=下周
    final current = from.weekday; // 1=Mon..7=Sun
    var diff = targetWeekday - current;
    if (weekOffset == 0 ? diff < 0 : diff <= 0) {
      diff += 7;
    }
    if (weekOffset == 1 && diff <= 0) diff += 7;
    if (weekOffset == 1) diff += 7;
    return from.add(Duration(days: diff));
  }

  DateTime _thisMonthDay(DateTime today, int month, int day) {
    var base = DateTime(today.year, month, day);
    if (base.isBefore(today)) base = DateTime(today.year, month + 1, day);
    return base;
  }
}




