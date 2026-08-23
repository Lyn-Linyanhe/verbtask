import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:rrule/rrule.dart';
import '../net/system_proxy.dart';

/// 用户自填的 OpenAI 兼容接口配置（base_url + key，key 存本地）。
class LlmConfig {
  final String baseUrl;
  final String apiKey;
  final String model; // 模型名；为空时客户端回退默认
  const LlmConfig({
    required this.baseUrl,
    required this.apiKey,
    this.model = '',
  });
}

/// 未配置 / 调用失败。
class LlmUnavailable implements Exception {
  final String message;
  final int? statusCode; // HTTP 状态码；null 表示非 HTTP 失败（如超时/网络错误）
  LlmUnavailable(this.message, {this.statusCode});
  @override
  String toString() => 'LlmUnavailable: $message';
}

/// LLM 解析的原始结果（不依赖 UI/NlpResult，避免循环依赖）。
class LlmDraft {
  final String? title;
  final String? listName;
  final String? dueIso; // ISO 8601；null=不限
  final bool? dateOnly;
  final String? rrule;
  final int? priority;
  final int? reminderMinutes; // 到期前 N 分钟提醒；null=不提醒
  const LlmDraft({
    this.title,
    this.listName,
    this.dueIso,
    this.dateOnly,
    this.rrule,
    this.priority,
    this.reminderMinutes,
  });
}

/// 可选 LLM 增强解析客户端（OpenAI 兼容 chat/completions）。
class LlmClient {
  final http.Client _http;
  static const maxReminderMinutes = 365 * 24 * 60;

  /// 默认使用跟随系统代理的 HTTP 客户端；测试可注入 MockClient。
  LlmClient({http.Client? client}) : _http = client ?? _buildProxyClient();

  static http.Client _buildProxyClient() {
    final io = HttpClient()..findProxy = SystemProxy.findProxy;
    return IOClient(io);
  }

  /// 带重试的增强解析。偶发失败（超时/网络/5xx/429/网关返回 HTML 等）自动重试一次；
  /// 确定性失败（401/403/404 等配置性错误）立即抛出，避免无谓等待。
  Future<LlmDraft?> enhance(String text, LlmConfig cfg) async {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    Object? last;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _enhanceOnce(text, cfg, todayStr);
      } catch (e) {
        last = e;
        if (!_shouldRetry(e)) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    if (last is Exception) throw last;
    throw LlmUnavailable('解析失败');
  }

  /// 是否值得重试：任何非 LlmUnavailable 的异常（超时/网络/连接等）一律重试一次；
  /// LlmUnavailable 仅在 200(网关HTML)/429/5xx 或未知状态时重试；4xx 鉴权/路径类不重试。
  static bool _shouldRetry(Object e) {
    if (e is LlmUnavailable) {
      final s = e.statusCode;
      if (s == null) return true;
      return s == 200 || s >= 500 || s == 429;
    }
    return true;
  }

  Future<LlmDraft?> _enhanceOnce(
      String text, LlmConfig cfg, String todayStr) async {
    // 端点自动探测：先试常用 /chat/completions；若服务端返回非 JSON（网关 HTML 等），
    // 再试 /v1/chat/completions（很多中转站/代理的正确路径），避免静默回退本地解析。
    // 今天日期作为相对时间基准（关键：防止 LLM 把"明天/下周一/月底"解析成过去的任意日期）。
    Map<String, dynamic> data = const {};
    int lastStatus = 0;
    String lastBody = '';
    for (final endpoint in _endpointCandidates(cfg.baseUrl)) {
      final resp = await _http
          .post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json',
              if (cfg.apiKey.isNotEmpty)
                'Authorization': 'Bearer ${cfg.apiKey}',
            },
            body: jsonEncode({
              'model': cfg.model.isEmpty ? 'gpt-4o-mini' : cfg.model,
              'messages': [
                {
                  'role': 'system',
                  'content': _buildSystemPrompt(todayStr),
                },
                {'role': 'user', 'content': text},
              ],
            }),
          )
          .timeout(const Duration(seconds: 45));
      lastStatus = resp.statusCode;
      final ct = (resp.headers['content-type'] ?? '').toLowerCase();
      final body = utf8.decode(resp.bodyBytes);
      // 网关常对未知路径返回 HTML 页；此时跳过并尝试下一个候选端点。
      if (resp.statusCode != 200 || ct.contains('text/html')) {
        lastBody =
            body.isNotEmpty ? body.substring(0, body.length.clamp(0, 80)) : '';
        continue;
      }
      try {
        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('响应根节点不是 JSON 对象');
        }
        final choices = decoded['choices'];
        if (choices is! List || choices.isEmpty) {
          lastBody = 'choices 为空';
          data = const {};
          continue;
        }
        final first = choices.first;
        final content = first is Map && first['message'] is Map
            ? _messageContent((first['message'] as Map)['content'])
            : null;
        if (content == null || content.trim().isEmpty) {
          lastBody = 'choices.content 为空';
          data = const {};
          continue;
        }
        data = decoded;
        break;
      } catch (_) {
        lastBody =
            body.isNotEmpty ? body.substring(0, body.length.clamp(0, 80)) : '';
        data = const {};
        continue;
      }
    }
    if (!data.containsKey('choices')) {
      throw LlmUnavailable('响应非 JSON/失败 (HTTP $lastStatus; 响应="$lastBody")',
          statusCode: lastStatus);
    }
    final choices = (data['choices'] as List?) ?? const [];
    final message = (choices.first as Map)['message'];
    final content = message is Map ? _messageContent(message['content']) : null;
    if (content == null || content.trim().isEmpty) {
      throw LlmUnavailable('响应内容为空', statusCode: lastStatus);
    }
    final map = _extractFirstJson(content);
    if (map == null) return null;
    final rawReminder = (map['reminderMinutes'] as num?)?.toDouble();
    final reminderMinutes = rawReminder != null &&
            rawReminder.isFinite &&
            rawReminder >= 0 &&
            rawReminder <= maxReminderMinutes
        ? rawReminder.toInt()
        : null;
    return LlmDraft(
      title: map['title'] as String?,
      listName: map['listName'] as String?,
      dueIso: map['due'] as String?,
      dateOnly: map['dateOnly'] as bool?,
      rrule: _normalizeRrule(map['rrule'] as String?),
      priority: (map['priority'] as num?)?.toInt(),
      reminderMinutes: reminderMinutes,
    );
  }

  /// 构造解析系统提示词。注入今天日期作为相对时间基准，并约束标题/rrule/priority 语义。
  static String _buildSystemPrompt(String today) => '''
你是中文任务解析器。今天的日期是 $today。所有相对时间（今天/明天/后天/下周X/本周五/月底/N天后等）必须基于今天推算成绝对日期。

把用户的中文任务文本解析成 JSON，只输出 JSON，不要输出任何其他文字。JSON 格式：
{"title":"行动标题","listName":"清单名或 null","due":"本地时间ISO8601(不带时区) 或 null","dateOnly":true或false,"rrule":"重复规则 或 null","priority":0或1或2或3,"reminderMinutes":数字或null}

规则：
1. title=去掉时间/日期/频率/语气词后的行动短语："明天下午3点前把周报交给我，这个很重要啊"→"交周报"；剔除"提醒我/记得/别迟到/很重要/每天/每周/上午/下午/几点"等冗余词。
2. due 输出本地墙钟时间（不要带 Z 或时区偏移）。提到具体时刻（如"下午3点""早上十点"）→ dateOnly=false；只提到日期（如"下周一""月底前"）→ dateOnly=true。若文本隐含合理默认期限，也应给出 due 而非 null："这个月/本月做X"→当月最后一天(dateOnly=true)；"睡前/临睡前做X"→今晚23:00；"下班后做X"→当天18:00；"周末做X"→最近的周末日期。完全没有时间概念的事务（如"买瓶酱油"）才给 due=null。
3. 重复任务 rrule 用不带 RRULE: 前缀的 FREQ=...（如 FREQ=WEEKLY;BYDAY=MO、FREQ=MONTHLY;BYMONTHDAY=28、FREQ=DAILY;INTERVAL=14）。"每两周/两周一次/每隔两周"→FREQ=WEEKLY;INTERVAL=2（间隔写的是周数！绝不写 BIWEEKLY，也绝不把"两周"写成 INTERVAL=14——那表示 14 周）。"每季度"→FREQ=MONTHLY;INTERVAL=3；"每季度末/每季度最后一天"→FREQ=MONTHLY;INTERVAL=3;BYMONTHDAY=-1；"每年6月"→FREQ=YEARLY;BYMONTH=6，"每年六月十五日"还要加 BYMONTHDAY=15；"每年最后一天"→FREQ=YEARLY;BYMONTH=12;BYMONTHDAY=31。若重复的每次发生在固定时刻（如"每天下午六点""每周一上午九点"），必须把时刻写进 BYHOUR/BYMINUTE/BYSECOND（如 FREQ=DAILY;BYHOUR=18;BYMINUTE=0;BYSECOND=0），绝对不要丢失时刻，即使"提醒我/记得"在句首：""提醒我每周五下午提交周报""→FREQ=WEEKLY;BYDAY=FR;BYHOUR=15;BYMINUTE=0;BYSECOND=0、""每两周周五下午开周会""→FREQ=WEEKLY;INTERVAL=2;BYDAY=FR;BYHOUR=15;BYMINUTE=0;BYSECOND=0。""下班后/下班""按 18:00 处理：""每天下班后打卡""→FREQ=DAILY;BYHOUR=18;BYMINUTE=0;BYSECOND=0。""每月月底/月末做账""→FREQ=MONTHLY;BYMONTHDAY=-1（月底=当月最后一天，必须用 -1，绝不写 31！）。""每周末/每个周末做X""→FREQ=WEEKLY;BYDAY=SA,SU（周末=周六和周日两天，不是只周六）。若文本未给具体时刻（如""每周五交周报""），rrule 不要写 BYHOUR/BYMINUTE/BYSECOND。若只给时间段词没给数字：""下午""默认15:00、""上午/早上""默认9:00、""中午""默认12:00、""傍晚/下班后""默认18:00、""晚上""默认20:00、""睡前""默认23:00，如""每周五下午提交周报""→FREQ=WEEKLY;BYDAY=FR;BYHOUR=15;BYMINUTE=0;BYSECOND=0。若明确首次时间（如"下周二下午两点开始"）则 due 填该次绝对时间；否则 due=null。
4. listName：文本出现 #工作、#家庭 等标签时提取标签名（不含 #）；没有标签时为 null。不要凭空创建清单。
5. priority：0=未强调/默认，1=低，2=中（提到"重要"），3=高或紧急。只有出现"紧急/重要/高/低/P1-P3/!!"等明确词才设置；不要因为任务性质（如面试/开会/交报告/去医院）自动提高优先级，默认一律 0。
6. 提醒：reminderMinutes=到期前提醒的分钟数："提前10分钟提醒我"→10、"提前半小时"→30、"提前三天"→4320；当"提醒我/记得提醒/叫我/叫醒/闹钟/记得/记着/记住"是祈使（提醒我去做某事）时必须设置，无提前量→15，并把这类词从 title 剔除（title 只留动作），如"明天早上叫我起床"→title=起床、reminderMinutes=15；明确说"不要提醒我/不要提前提醒我"时 reminderMinutes=null；完全没提提醒→null。''';

  /// 统一 rrule 格式为不带 RRULE: 前缀（与本地 zh_parser 一致，兼容下游解析）。
  static String? _normalizeRrule(String? raw) {
    if (raw == null) return null;
    var t = raw.trim();
    if ((t.startsWith('"') || t.startsWith("'")) && t.length >= 2) {
      t = t.substring(1);
      if (t.endsWith('"') || t.endsWith("'")) {
        t = t.substring(0, t.length - 1);
      }
    }
    t = t.trim();
    if (t.startsWith('RRULE:')) t = t.substring('RRULE:'.length);
    // 非标准扩展频率别名 → 标准 RRULE（rrule 包只认 SECONDLY..YEARLY，避免展开静默失败）
    t = t.replaceFirst('FREQ=BIWEEKLY', 'FREQ=WEEKLY;INTERVAL=2');
    t = t.replaceFirst('FREQ=BIMONTHLY', 'FREQ=MONTHLY;INTERVAL=2');
    if (t.isEmpty) return null;
    try {
      RecurrenceRule.fromString('RRULE:$t');
      return t;
    } catch (_) {
      // An invalid model rule must never reach task storage and fail later
      // while reminders are being expanded.
      return null;
    }
  }

  /// 拉取 OpenAI 兼容接口的可用模型 id 列表（GET /models）。
  Future<List<String>> listModels(LlmConfig cfg) async {
    final resp = await _http.get(
      Uri.parse(_modelsEndpoint(cfg.baseUrl)),
      headers: {
        'Content-Type': 'application/json',
        if (cfg.apiKey.isNotEmpty) 'Authorization': 'Bearer ${cfg.apiKey}',
      },
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw LlmUnavailable('HTTP ${resp.statusCode}');
    }
    final data = jsonDecode(utf8.decode(resp.bodyBytes));
    final arr = (data['data'] as List?) ?? const [];
    final names = <String>[];
    for (final item in arr) {
      if (item is Map && item['id'] is String) {
        names.add(item['id'] as String);
      }
    }
    return names;
  }

  /// 从 base_url 推导 /models 端点（去掉可能存在的 /chat/completions 或 /responses 后缀）。
  String _modelsEndpoint(String baseUrl) {
    var b = baseUrl.trim();
    if (b.endsWith('/')) b = b.substring(0, b.length - 1);
    if (b.endsWith('/chat/completions')) {
      b = b.substring(0, b.length - '/chat/completions'.length);
    } else if (b.endsWith('/responses')) {
      b = b.substring(0, b.length - '/responses'.length);
    }
    return '$b/models';
  }

  /// 候选 chat 端点：优先 /chat/completions；其次 /v1/chat/completions
  /// （geiliapi 等中转站正确路径带 /v1）。用户已显式带后缀时直接用。
  List<String> _endpointCandidates(String baseUrl) {
    var b = baseUrl.trim();
    if (b.endsWith('/')) b = b.substring(0, b.length - 1);
    if (b.endsWith('/chat/completions') || b.endsWith('/responses')) {
      return [b];
    }
    final plain = '$b/chat/completions';
    final v1 = '$b/v1/chat/completions';
    // 若 base 已含 /v1 前缀，则不要重复拼 v1
    if (b.endsWith('/v1') || b.endsWith('/v1/')) {
      return ['$b/chat/completions'];
    }
    return [plain, v1];
  }

  Map<String, dynamic>? _extractFirstJson(String content) {
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      return jsonDecode(content.substring(start, end + 1))
          as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// OpenAI-compatible providers may return either a string or an array of
  /// typed text blocks in message.content.
  static String? _messageContent(Object? value) {
    if (value is String) return value;
    if (value is List) {
      final chunks = <String>[];
      for (final item in value) {
        if (item is Map && item['text'] is String) {
          chunks.add(item['text'] as String);
        }
      }
      return chunks.isEmpty ? null : chunks.join();
    }
    if (value is Map && value['text'] is String) {
      return value['text'] as String;
    }
    return null;
  }
}
