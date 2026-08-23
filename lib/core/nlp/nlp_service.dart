import '../models/task.dart';
import 'zh_parser.dart';
import 'llm_client.dart';

class NlpResult {
  final String? title;
  final String? listName;
  final DueDate? due;
  final String? rrule;
  final int? priority;
  final int? reminderMinutes; // 到期前 N 分钟提醒；null=未提及或明确关闭
  final bool reminderDisabled; // true=用户明确要求不要提醒
  final bool needsConfirm;
  final String source;
  final bool fallbackFromLlm;
  const NlpResult({
    this.title,
    this.listName,
    this.due,
    this.rrule,
    this.priority,
    this.reminderMinutes,
    this.reminderDisabled = false,
    this.needsConfirm = true,
    this.source = 'local',
    this.fallbackFromLlm = false,
  });
  bool get isEmpty =>
      title == null && due == null && rrule == null && priority == null;

  bool get reminderNeedsDue =>
      reminderMinutes != null && due == null && !reminderDisabled;
}

/// 三级解析：本地规则(zh) -> 可选 LLM -> 手动兜底。
class NlpService {
  final ZhParser _zh;
  final LlmClient? llm;
  NlpService({ZhParser? zh, this.llm}) : _zh = zh ?? ZhParser();

  NlpResult parseLocal(String text, {bool fallbackFromLlm = false}) {
    final d = _zh.parse(text);
    return NlpResult(
      title: ZhParser.isNonActionableInput(text) || d.title.isEmpty
          ? null
          : d.title,
      listName: d.listName,
      due: d.due != null ? DueDate(d.due!, dateOnly: d.dateOnly) : null,
      rrule: d.rrule,
      priority: d.priority,
      reminderMinutes: d.reminderMinutes,
      reminderDisabled: d.reminderDisabled,
      needsConfirm: true,
      source: 'local',
      fallbackFromLlm: fallbackFromLlm,
    );
  }

  Future<NlpResult> parse(String text, {LlmConfig? config}) async {
    // Conversational filler is not a task and should never leave the device
    // for an optional external parser.
    if (ZhParser.isNonActionableInput(text)) {
      return parseLocal(text);
    }
    if (llm != null && config != null) {
      try {
        final d = await llm!.enhance(text, config);
        // 空标题（空白/无意义输入）不算有效解析，回退本地用原文兜底，避免创建空标题任务
        if (d != null && d.title != null && d.title!.trim().isNotEmpty) {
          // 本地解析是明确中文提醒/重复语义的底线：LLM 漏字段时不能把用户
          // 已经说清楚的信息静默丢掉。复杂日期、标题和 LLM 扩展规则仍保留。
          final local = parseLocal(text);
          final llmDue = d.dueIso != null
              ? _dueFromLlm(d.dueIso!, d.dateOnly ?? false)
              : null;
          final llmRrule = _cleanRruleTime(
              _ensureRruleDay(
                  _ensureWeekend(
                      _ensureMonthEnd(_ensureRruleTime(d.rrule, text), text),
                      text),
                  text),
              text);
          final reminderDisabled =
              local.reminderDisabled || _hasReminderOptOut(text);
          final llmReminder =
              d.reminderMinutes != null && d.reminderMinutes! >= 0
                  ? d.reminderMinutes
                  : null;
          final wantsReminder = _wantsReminder(text);
          final reminder = reminderDisabled
              ? null
              : (local.reminderMinutes ??
                  (wantsReminder ? (llmReminder ?? 15) : null));
          final mergedDue = _promoteDueTime(local.due ?? llmDue, text) ??
              (llmRrule == null
                  ? null
                  : _promoteDueTime(_todayAnchor(), text) ?? _todayAnchor());
          return NlpResult(
            title: _mergeTitle(local, d.title!, text),
            listName: local.listName ?? d.listName,
            due: mergedDue,
            rrule: _mergeRrule(llmRrule, local.rrule, text),
            priority: local.priority ?? d.priority,
            reminderMinutes: reminder,
            reminderDisabled: reminderDisabled,
            needsConfirm: true,
            source: 'llm',
          );
        }
      } catch (_) {
        // fall through to local
      }
    }
    return parseLocal(text, fallbackFromLlm: llm != null && config != null);
  }

  /// 安全网：LLM 给了“仅日期”但原文有显式时刻或时间段词（规则2）→ 提升为具体时刻。
  static DueDate? _promoteDueTime(DueDate? due, String text) {
    if (due == null || !due.dateOnly) return due;
    final t = _explicitTime(text) ?? _periodDefault(text);
    if (t == null) return due;
    // 原文时刻是本地墙钟时间 → 转成 UTC 存储（与本地 zh_parser 语义一致）
    final local =
        DateTime(due.value.year, due.value.month, due.value.day, t.$1, t.$2);
    return DueDate(local.toUtc(), dateOnly: false);
  }

  static DueDate _todayAnchor() {
    final now = DateTime.now();
    return DueDate(DateTime.utc(now.year, now.month, now.day), dateOnly: true);
  }

  /// 安全网：LLM 漏写 BYHOUR（规则3：重复任务固定时刻不能丢）→ 从原文补回。
  /// 显式时刻优先；无数字时按时间段词默认（下午=15:00、上午=9:00 等，与本地解析一致）。
  static String? _ensureRruleTime(String? rrule, String text) {
    if (rrule == null) return rrule;
    final t = _explicitTime(text) ?? _periodDefault(text);
    if (t == null) return rrule;
    if (RegExp(r';BYHOUR=\d+;BYMINUTE=\d+;BYSECOND=\d+', caseSensitive: false)
        .hasMatch(rrule)) {
      return rrule;
    }
    final withoutTime = rrule.replaceAll(
        RegExp(r';BY(?:HOUR|MINUTE|SECOND)=[^;]+', caseSensitive: false), '');
    return '$withoutTime;BYHOUR=${t.$1};BYMINUTE=${t.$2};BYSECOND=0';
  }

  /// 无显式数字时的“时间段默认时刻”（与 zh_parser 一致）。
  static (int, int)? _periodDefault(String text) {
    if (text.contains('下班')) return (18, 0);
    if (text.contains('睡前')) return (23, 0);
    if (text.contains('下午')) return (15, 0);
    if (text.contains('中午')) return (12, 0);
    if (text.contains('傍晚')) return (18, 0);
    if (text.contains('晚上') || text.contains('夜晚')) {
      return (20, 0);
    }
    if (text.contains('上午') ||
        text.contains('早上') ||
        text.contains('早晨') ||
        text.contains('清晨')) {
      return (9, 0);
    }
    if (text.contains('凌晨')) return (0, 0);
    return null;
  }

  /// 从原文提取显式时刻（上午/下午/晚上/傍晚/凌晨 + N点/N点半/N:MM，支持中文数字），返回(时,分)。
  static (int, int)? _explicitTime(String text) {
    final m = RegExp(r'((?:\d{1,2})|(?:[零一二两三四五六七八九十]+))'
            r'(?:\s*[:：]\s*((?:\d{1,2})|(?:[零一二两三四五六七八九十]+))'
            r'|\s*点(半|一刻|三刻)?)')
        .firstMatch(text);
    if (m == null) return null;
    final h = _cnToInt(m.group(1)!);
    final mm = m.group(2) != null ? _cnToInt(m.group(2)!) : null;
    final minute = mm ??
        (m.group(3) == '半'
            ? 30
            : m.group(3) == '一刻'
                ? 15
                : m.group(3) == '三刻'
                    ? 45
                    : 0);
    final marker = RegExp(r'(上午|下午|晚上|傍晚|凌晨|中午|晚)').firstMatch(text)?.group(1);
    var resolved = h;
    if (marker == '下午' || marker == '晚上' || marker == '傍晚' || marker == '晚') {
      resolved = h < 12 ? h + 12 : h;
    } else if (marker == '凌晨' && h == 12) {
      resolved = 0;
    } else if (marker == '中午') {
      resolved = h < 12 ? h + 12 : h;
    }
    if (resolved < 0 || resolved > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return (resolved, minute);
  }

  /// 中文数字（含“两/十/二十/十一”等）与阿拉伯数字 → int。
  static int _cnToInt(String s) {
    final digit = int.tryParse(s);
    if (digit != null) return digit;
    const map = {
      '零': 0,
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
    if (s == '十') return 10;
    if (s.length == 1) return map[s] ?? 0;
    if (s.startsWith('十')) return 10 + (map[s[1]] ?? 0);
    if (s.endsWith('十')) return (map[s[0]] ?? 0) * 10;
    return (map[s[0]] ?? 0) * 10 + (map[s[1]] ?? 0);
  }

  /// 是否明确表示“不需要提醒”。否定必须先于正向关键词判断。
  static bool _hasReminderOptOut(String text) =>
      ZhParser.hasReminderOptOut(text);

  /// 是否包含“提醒意图”词（与 zh_parser 语义一致；LLM 漏了也能兜底15分钟）。
  static bool _wantsReminder(String text) => ZhParser.wantsReminder(text);

  /// Local extraction owns text that it has already reduced by removing an
  /// explicit date, time, recurrence, reminder, or priority token. This keeps
  /// a model hallucination from replacing a clear action title.
  static String _mergeTitle(NlpResult local, String llmTitle, String text) {
    final localTitle = local.title?.trim();
    if (localTitle != null &&
        localTitle.isNotEmpty &&
        localTitle != text.trim()) {
      return localTitle;
    }
    return llmTitle.trim();
  }

  /// 安全网：LLM 把“每月月底/月末”错写成 BYMONTHDAY=31（无31日的月份会丢）→ 改 -1。
  static String? _ensureMonthEnd(String? rrule, String text) {
    if (rrule == null || !rrule.contains('FREQ=MONTHLY')) {
      return rrule;
    }
    if (text.contains('月底') || text.contains('月末')) {
      if (rrule.contains('BYMONTHDAY=31')) {
        return rrule.replaceFirst('BYMONTHDAY=31', 'BYMONTHDAY=-1');
      }
      if (!rrule.contains('BYMONTHDAY=')) {
        return '$rrule;BYMONTHDAY=-1';
      }
    }
    return rrule;
  }

  /// 安全网：LLM 漏写 BYDAY（每周重复的星期几）→ 从原文“周X/星期X/礼拜X”补回。
  static String? _ensureRruleDay(String? rrule, String text) {
    if (rrule == null ||
        !rrule.contains('FREQ=WEEKLY') ||
        rrule.contains('BYDAY')) {
      return rrule;
    }
    const map = {
      '一': 'MO',
      '二': 'TU',
      '三': 'WE',
      '四': 'TH',
      '五': 'FR',
      '六': 'SA',
      '日': 'SU',
      '天': 'SU',
    };
    final days = <String>{};
    for (final m in RegExp(r'(?:周|星期|礼拜)([一二三四五六日天])').allMatches(text)) {
      final d = map[m.group(1)!];
      if (d != null) days.add(d);
    }
    if (days.isEmpty) return rrule;
    return '$rrule;BYDAY=${days.join(',')}';
  }

  /// 安全网：文本根本没提时刻，LLM 却写了 BYHOUR → 移除（避免重复任务凭空定在某个时刻）。
  static String? _cleanRruleTime(String? rrule, String text) {
    if (rrule == null || !rrule.contains('BYHOUR=')) return rrule;
    if (_explicitTime(text) != null || _periodDefault(text) != null) {
      return rrule;
    }
    return rrule.replaceAll(
        RegExp(r';BY(?:HOUR|MINUTE|SECOND)=[^;]+', caseSensitive: false), '');
  }

  /// 安全网：重复任务文本含“周末”但 LLM 的 BYDAY 不是 SA,SU → 统一为周末两天。
  static String? _ensureWeekend(String? rrule, String text) {
    if (rrule == null ||
        !rrule.contains('FREQ=WEEKLY') ||
        !RegExp(r'(?:每(?:个)?|每逢)\s*周末').hasMatch(text)) {
      return rrule;
    }
    final byday = RegExp(r'BYDAY=([^;]+)').firstMatch(rrule)?.group(1);
    final days = (byday ?? '').split(',').toSet();
    if (days.contains('SA') && days.contains('SU')) return rrule;
    final cleaned = rrule.replaceFirst(RegExp(r';BYDAY=[^;]+'), '');
    return '$cleaned;BYDAY=SA,SU';
  }

  /// 合并本地明确的周期间隔与 LLM 补充的星期/月底等字段。
  /// 本地规则只有通用频率时不覆盖 LLM 的更完整结果；周末和间隔是明确意图，
  /// 必须保留，避免模型把“每两周”或“每个周末”改成普通重复。
  static String? _mergeRrule(
      String? llmRrule, String? localRrule, String text) {
    if (llmRrule == null) return localRrule;
    if (localRrule == null) {
      // “周末”默认是一次性日期；不要接受模型凭空生成的周重复。
      if (RegExp(r'(?:下|本|这)?周末').hasMatch(text) &&
          !RegExp(r'(?:每(?:个)?|每逢)\s*周末').hasMatch(text)) {
        return null;
      }
      return _mentionsRecurrence(text) ? llmRrule : null;
    }
    if (text.contains('周末') && localRrule.contains('BYDAY=SA,SU')) {
      return localRrule;
    }
    // “月底”是明确的日历语义。若模型只返回普通月重复，保留本地
    // BYMONTHDAY=-1，避免任务在每月第一天/任意默认日期触发。
    if ((text.contains('月底') || text.contains('月末')) &&
        localRrule.contains('BYMONTHDAY=-1') &&
        !llmRrule.contains('BYMONTHDAY=')) {
      return localRrule;
    }

    final localFreq = RegExp(r'FREQ=([^;]+)').firstMatch(localRrule)?.group(1);
    final llmFreq = RegExp(r'FREQ=([^;]+)').firstMatch(llmRrule)?.group(1);
    if (localFreq != llmFreq) {
      // 本地中文规则已经确认了用户说出的基础周期时，频率冲突不能
      // 由模型的猜测覆盖；模型只负责补充同一频率下的字段。
      return localRrule;
    }

    var merged = llmRrule;
    for (final field in const [
      'INTERVAL',
      'BYDAY',
      'BYMONTH',
      'BYMONTHDAY',
      'BYHOUR',
      'BYMINUTE',
      'BYSECOND',
    ]) {
      final localClause = _rruleClause(localRrule, field);
      if (localClause != null) {
        merged = _replaceOrAppendRruleClause(merged, localClause);
      } else if (!_rruleFieldSupportedByText(field, text)) {
        merged = _removeRruleClause(merged, field);
      }
    }
    return merged;
  }

  static bool _mentionsRecurrence(String text) => RegExp(
        r'每隔|隔(?:天|周)|每(?:个)?季度|每年|每(?:个)?月|'
        r'每\s*[0-9零一二两三四五六七八九十]+\s*(?:天|周|星期|礼拜|个?月)|'
        r'每(?:个)?工作日|'
        r'每周末|每(?:个)?周末|每(?:周|星期|礼拜)[一二三四五六日天]+|'
        r'每(?:天|日|周|星期|礼拜)(?!都)',
      ).hasMatch(text);

  static bool _rruleFieldSupportedByText(String field, String text) {
    switch (field) {
      case 'INTERVAL':
        return RegExp(
          r'每隔|隔(?:天|周)|每\s*[二两三四五六七八九十0-9]+\s*(?:天|周|星期|礼拜|个?月)',
        ).hasMatch(text);
      case 'BYDAY':
        return RegExp(
          r'(?:周|星期|礼拜)[一二三四五六日天]+|工作日|周末',
        ).hasMatch(text);
      case 'BYMONTHDAY':
        return RegExp(r'(?:月底|月末|最后(?:一天|一日)|月\s*[0-9零一二两三四五六七八九十百]+\s*[号日])')
            .hasMatch(text);
      case 'BYMONTH':
        return RegExp(r'每年\s*[0-9零一二两三四五六七八九十百]+\s*月').hasMatch(text);
      case 'BYHOUR':
      case 'BYMINUTE':
      case 'BYSECOND':
        return _explicitTime(text) != null || _periodDefault(text) != null;
      default:
        return true;
    }
  }

  static String? _rruleClause(String rrule, String field) {
    return RegExp('(?:^|;)($field=[^;]+)').firstMatch(rrule)?.group(1);
  }

  static String _replaceOrAppendRruleClause(String rrule, String clause) {
    final field = clause.substring(0, clause.indexOf('='));
    final pattern = RegExp('(?:^|;)$field=[^;]+');
    final match = pattern.firstMatch(rrule);
    if (match == null) return '$rrule;$clause';
    final prefix = match.group(0)!.startsWith(';') ? ';' : '';
    return rrule.replaceFirst(pattern, '$prefix$clause');
  }

  static String _removeRruleClause(String rrule, String field) => rrule
      .replaceAll(RegExp('(?:^|;)$field=[^;]+', caseSensitive: false), '')
      .replaceFirst(RegExp(r'^;'), '');

  DueDate _dueFromLlm(String iso, bool dateOnly) {
    final parsed = DateTime.parse(iso);
    // 若 LLM 给的字符串本身不含时间部分，一律按"仅日期"处理，避免时区漂移。
    final noTimePart = !iso.contains('T');
    if (dateOnly || noTimePart) {
      return DueDate(
        DateTime.utc(parsed.year, parsed.month, parsed.day),
        dateOnly: true,
      );
    }
    return DueDate(parsed.toUtc());
  }
}
