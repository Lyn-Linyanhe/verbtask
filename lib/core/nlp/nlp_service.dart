import '../models/task.dart';
import 'zh_parser.dart';
import 'llm_client.dart';

class NlpResult {
  final String? title;
  final DueDate? due;
  final String? rrule;
  final int? priority;
  final int? reminderMinutes; // 到期前 N 分钟提醒；null=不提醒
  final bool needsConfirm;
  final String source;
  final bool fallbackFromLlm;
  const NlpResult({
    this.title,
    this.due,
    this.rrule,
    this.priority,
    this.reminderMinutes,
    this.needsConfirm = true,
    this.source = 'local',
    this.fallbackFromLlm = false,
  });
  bool get isEmpty =>
      title == null && due == null && rrule == null && priority == null;
}

/// 三级解析：本地规则(zh) -> 可选 LLM -> 手动兜底。
class NlpService {
  final ZhParser _zh;
  final LlmClient? llm;
  NlpService({ZhParser? zh, this.llm}) : _zh = zh ?? ZhParser();

  NlpResult parseLocal(String text, {bool fallbackFromLlm = false}) {
    final d = _zh.parse(text);
    return NlpResult(
      title: d.title.isEmpty ? null : d.title,
      due: d.due != null ? DueDate(d.due!, dateOnly: d.dateOnly) : null,
      rrule: d.rrule,
      priority: d.priority,
      reminderMinutes: d.reminderMinutes,
      needsConfirm: true,
      source: 'local',
      fallbackFromLlm: fallbackFromLlm,
    );
  }

  Future<NlpResult> parse(String text, {LlmConfig? config}) async {
    if (llm != null && config != null) {
      try {
        final d = await llm!.enhance(text, config);
        // 空标题（空白/无意义输入）不算有效解析，回退本地用原文兜底，避免创建空标题任务
        if (d != null && d.title != null && d.title!.trim().isNotEmpty) {
          final due = d.dueIso != null
              ? _dueFromLlm(d.dueIso!, d.dateOnly ?? false)
              : null;
          return NlpResult(
            title: d.title,
            due: _promoteDueTime(due, text),
            rrule: _cleanRruleTime(
                _ensureRruleDay(
                    _ensureWeekend(
                        _ensureMonthEnd(_ensureRruleTime(d.rrule, text), text),
                        text),
                    text),
                text),
            priority: d.priority,
            // 安全网：LLM 漏提“提醒”时按本地语义默认 15 分钟（与 zh_parser 一致）
            reminderMinutes: d.reminderMinutes ?? (_wantsReminder(text) ? 15 : null),
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
    final local = DateTime(
        due.value.year, due.value.month, due.value.day, t.$1, t.$2);
    return DueDate(local.toUtc(), dateOnly: false);
  }

  /// 安全网：LLM 漏写 BYHOUR（规则3：重复任务固定时刻不能丢）→ 从原文补回。
  /// 显式时刻优先；无数字时按时间段词默认（下午=15:00、上午=9:00 等，与本地解析一致）。
  static String? _ensureRruleTime(String? rrule, String text) {
    if (rrule == null || rrule.contains('BYHOUR')) return rrule;
    final t = _explicitTime(text) ?? _periodDefault(text);
    if (t == null) return rrule;
    return '$rrule;BYHOUR=${t.$1};BYMINUTE=${t.$2};BYSECOND=0';
  }

  /// 无显式数字时的“时间段默认时刻”（与 zh_parser 一致）。
  static (int, int)? _periodDefault(String text) {
    if (text.contains('下班')) return (18, 0);
    if (text.contains('睡前')) return (23, 0);
    if (text.contains('下午')) return (15, 0);
    if (text.contains('中午')) return (12, 0);
    if (text.contains('傍晚')) return (18, 0);
    if (text.contains('晚上') || text.contains('夜晚')) return (20, 0);
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
    final m = RegExp(
            r'((?:\d{1,2})|(?:[零一二两三四五六七八九十]+))'
            r'([:：]((?:\d{1,2})|(?:[零一二两三四五六七八九十]+)))?'
            r'\s*点(半|一刻|三刻)?')
        .firstMatch(text);
    if (m == null) return null;
    final h = _cnToInt(m.group(1)!);
    final mm = m.group(3) != null ? _cnToInt(m.group(3)!) : null;
    final minute = mm ??
        (m.group(4) == '半'
            ? 30
            : m.group(4) == '一刻'
                ? 15
                : m.group(4) == '三刻'
                    ? 45
                    : 0);
    final marker = RegExp(r'(上午|下午|晚上|傍晚|凌晨)').firstMatch(text)?.group(1);
    var resolved = h;
    if (marker == '下午' || marker == '晚上' || marker == '傍晚') {
      resolved = h < 12 ? h + 12 : h;
    } else if (marker == '凌晨' && h == 12) {
      resolved = 0;
    }
    return (resolved, minute);
  }

  /// 中文数字（含“两/十/二十/十一”等）与阿拉伯数字 → int。
  static int _cnToInt(String s) {
    final digit = int.tryParse(s);
    if (digit != null) return digit;
    const map = {
      '零': 0, '一': 1, '二': 2, '两': 2, '三': 3, '四': 4,
      '五': 5, '六': 6, '七': 7, '八': 8, '九': 9,
    };
    if (s == '十') return 10;
    if (s.length == 1) return map[s] ?? 0;
    if (s.startsWith('十')) return 10 + (map[s[1]] ?? 0);
    if (s.endsWith('十')) return (map[s[0]] ?? 0) * 10;
    return (map[s[0]] ?? 0) * 10 + (map[s[1]] ?? 0);
  }

  /// 是否包含“提醒意图”词（与 zh_parser 语义一致；LLM 漏了也能兜底 15 分钟）。
  static bool _wantsReminder(String text) =>
      RegExp(r'提醒|叫我|叫醒|闹钟|记得|记着|记住').hasMatch(text);
  /// 安全网：LLM 把“每月月底/月末”错写成 BYMONTHDAY=31（无31日的月份会丢）→ 改 -1。
  static String? _ensureMonthEnd(String? rrule, String text) {
    if (rrule == null || !rrule.contains('FREQ=MONTHLY') ||
        !rrule.contains('BYMONTHDAY=31')) {
      return rrule;
    }
    if (text.contains('月底') || text.contains('月末')) {
      return rrule.replaceFirst('BYMONTHDAY=31', 'BYMONTHDAY=-1');
    }
    return rrule;
  }

  /// 安全网：LLM 漏写 BYDAY（每周重复的星期几）→ 从原文“周X/星期X/礼拜X”补回。
  static String? _ensureRruleDay(String? rrule, String text) {
    if (rrule == null || !rrule.contains('FREQ=WEEKLY') ||
        rrule.contains('BYDAY')) {
      return rrule;
    }
    const map = {
      '一': 'MO', '二': 'TU', '三': 'WE', '四': 'TH',
      '五': 'FR', '六': 'SA', '日': 'SU', '天': 'SU',
    };
    final days = <String>{};
    for (final m
        in RegExp(r'(?:周|星期|礼拜)([一二三四五六日天])').allMatches(text)) {
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
    return rrule.replaceFirst(
        RegExp(r';BYHOUR=\d+;BYMINUTE=\d+;BYSECOND=\d+'), '');
  }

  /// 安全网：重复任务文本含“周末”但 LLM 的 BYDAY 不是 SA,SU → 统一为周末两天。
  static String? _ensureWeekend(String? rrule, String text) {
    if (rrule == null || !rrule.contains('FREQ=WEEKLY') ||
        !text.contains('周末')) {
      return rrule;
    }
    final byday =
        RegExp(r'BYDAY=([^;]+)').firstMatch(rrule)?.group(1);
    final days = (byday ?? '').split(',').toSet();
    if (days.contains('SA') && days.contains('SU')) return rrule;
    final cleaned = rrule.replaceFirst(RegExp(r';BYDAY=[^;]+'), '');
    return '$cleaned;BYDAY=SA,SU';
  }

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



