// 批量真实 LLM 探测工具（人类可读回归）。
// 用法：dart run tool/llm_mass_probe.dart --settings <settings.json路径> [--cases docs/nlp_llm_cases.json] [--tag A4]
// settings.json 也可用环境变量 VERBTASK_SETTINGS 指定；cases 默认 docs/nlp_llm_cases.json。
// 临时线上探测也可只用进程环境变量：VERBTASK_LLM_BASE_URL、VERBTASK_LLM_API_KEY、VERBTASK_LLM_MODEL。
// 本文件不硬编码任何机器路径。
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:verb_app/core/nlp/nlp_service.dart';
import 'package:verb_app/core/nlp/llm_client.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// 比较 cases 文件中可机器读取的声明字段。
/// 旧 cases 仍允许使用自然语言说明；无法可靠结构化的部分继续人工查看。
List<String> probeMismatches(
  NlpResult result,
  String expected, {
  NlpResult? localBaseline,
}) {
  final mismatches = <String>[];
  final title = RegExp(
    r'(?:^|[,，；;])\s*(?:title|标题)\s*=\s*([^,，；;]+)',
    caseSensitive: false,
  ).firstMatch(expected)?.group(1)?.trim();
  if (title != null &&
      title.isNotEmpty &&
      !(result.title ?? '').toLowerCase().contains(title.toLowerCase())) {
    mismatches.add('title expected "$title", got "${result.title ?? '-'}"');
  }

  final priorityText = RegExp(
    r'(?:pri|priority|优先级)\s*=\s*(高|中|低|无|\d+)',
    caseSensitive: false,
  ).firstMatch(expected)?.group(1);
  if (priorityText != null) {
    final expectedPriority = switch (priorityText) {
      '高' => 3,
      '中' => 2,
      '低' => 1,
      '无' => 0,
      _ => int.tryParse(priorityText),
    };
    if (expectedPriority != null && result.priority != expectedPriority) {
      mismatches.add(
          'priority expected $expectedPriority, got ${result.priority ?? '-'}');
    }
  }

  final reminderText = RegExp(
    r'(?:rem(?:inder)?|提醒)\s*=\s*(\d+|none|无|关闭|不提醒)',
    caseSensitive: false,
  ).firstMatch(expected)?.group(1);
  if (reminderText != null) {
    final expectedReminder = int.tryParse(reminderText);
    final matches = expectedReminder == null
        ? result.reminderDisabled || result.reminderMinutes == null
        : result.reminderMinutes == expectedReminder &&
            !result.reminderDisabled;
    if (!matches) {
      mismatches.add(
          'reminder expected "$reminderText", got ${result.reminderDisabled ? 'disabled' : result.reminderMinutes ?? '-'}');
    }
  }

  final date = RegExp(
    r'(?<![A-Za-z])(?:due|diua|截止)?\s*=?\s*(\d{2})-(\d{2})(?:\s+(\d{1,2}):(\d{2}))?',
    caseSensitive: false,
  ).firstMatch(expected);
  if (date != null) {
    final due = result.due;
    final month = int.parse(date.group(1)!);
    final day = int.parse(date.group(2)!);
    final hour = date.group(3) == null ? null : int.parse(date.group(3)!);
    final minute = date.group(4) == null ? null : int.parse(date.group(4)!);
    final baselineDue = localBaseline?.due;
    final value = due?.value.toLocal();
    final expectedValue = baselineDue?.value.toLocal() ?? value;
    final sameDate = value != null && value.month == month && value.day == day;
    final sameTime = hour == null ||
        (value != null && value.hour == hour && value.minute == minute);
    final matchesBaseline = baselineDue == null ||
        (value != null &&
            value.year == expectedValue!.year &&
            value.month == expectedValue.month &&
            value.day == expectedValue.day &&
            value.hour == expectedValue.hour &&
            value.minute == expectedValue.minute);
    if (!matchesBaseline || (baselineDue == null && (!sameDate || !sameTime))) {
      mismatches
          .add('due expected ${date.group(0)!.trim()}, got ${fmtDue(result)}');
    }
  }
  final expectedDateOnly =
      localBaseline?.due?.dateOnly ?? (expected.contains('仅日期') ? true : null);
  if (expectedDateOnly != null && result.due?.dateOnly != expectedDateOnly) {
    mismatches.add(
        'dateOnly expected $expectedDateOnly, got ${result.due?.dateOnly ?? false}');
  }

  final rrule = result.rrule?.toUpperCase() ?? '';
  final frequency =
      RegExp(r'FREQ=(DAILY|WEEKLY|MONTHLY|YEARLY)', caseSensitive: false)
          .firstMatch(expected)
          ?.group(1);
  if (frequency != null && !rrule.contains('FREQ=$frequency')) {
    mismatches
        .add('rrule expected FREQ=$frequency, got ${result.rrule ?? '-'}');
  }
  for (final token in RegExp(
    r'(?:INTERVAL=\d+|BYMONTHDAY=-?\d+|BYMONTH=\d+(?:,\d+)*|'
    r'BYDAY=[A-Z]+(?:,[A-Z]+)*|BYHOUR=\d+|BYMINUTE=\d+|BYSECOND=\d+)',
    caseSensitive: false,
  ).allMatches(expected).map((match) => match.group(0)!.toUpperCase())) {
    if (!rrule.contains(token)) {
      mismatches.add('rrule expected $token, got ${result.rrule ?? '-'}');
    }
  }
  if (expected.contains('WEEKLY') &&
      RegExp(r'\b(MO|TU|WE|TH|FR|SA|SU)\b').hasMatch(expected)) {
    final day =
        RegExp(r'\b(MO|TU|WE|TH|FR|SA|SU)\b').firstMatch(expected)!.group(1)!;
    if (!rrule.contains(day)) {
      mismatches.add('rrule expected weekday $day, got ${result.rrule ?? '-'}');
    }
  }
  if (expected.contains('不产生有效任务') && !result.isEmpty) {
    mismatches.add('expected an empty parse result');
  }
  return mismatches;
}

String fmtDue(NlpResult r) {
  if (r.due == null) return '-';
  final local = r.due!.value.toLocal();
  final date = '${local.year}-${_two(local.month)}-${_two(local.day)}';
  if (r.due!.dateOnly) return '[仅日期]$date';
  return '[时刻]$date ${_two(local.hour)}:${_two(local.minute)}';
}

void main(List<String> args) async {
  String? settingsPath;
  String casesPath = 'docs/nlp_llm_cases.json';
  String? tag;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--settings' && i + 1 < args.length) {
      settingsPath = args[i + 1];
    }
    if (args[i] == '--cases' && i + 1 < args.length) casesPath = args[i + 1];
    if (args[i] == '--tag' && i + 1 < args.length) tag = args[i + 1];
  }
  settingsPath ??= Platform.environment['VERBTASK_SETTINGS'];
  final env = Platform.environment;
  final envBaseUrl = env['VERBTASK_LLM_BASE_URL']?.trim() ?? '';
  final envApiKey = env['VERBTASK_LLM_API_KEY']?.trim() ?? '';
  final envModel = env['VERBTASK_LLM_MODEL']?.trim() ?? '';
  final hasEnvConfig = envBaseUrl.isNotEmpty && envApiKey.isNotEmpty;
  if (!hasEnvConfig &&
      (settingsPath == null || !File(settingsPath).existsSync())) {
    stdout.writeln(
        '!! 需要 settings.json 路径：--settings <path> 或环境变量 VERBTASK_SETTINGS；'
        '也可设置 VERBTASK_LLM_BASE_URL/VERBTASK_LLM_API_KEY');
    exit(2);
  }

  final sMap = !hasEnvConfig
      ? jsonDecode(File(settingsPath!).readAsStringSync())
          as Map<String, dynamic>
      : const <String, dynamic>{};
  final baseUrl =
      hasEnvConfig ? envBaseUrl : (sMap['llmBaseUrl'] as String? ?? '').trim();
  final apiKey =
      hasEnvConfig ? envApiKey : (sMap['llmKey'] as String? ?? '').trim();
  final model =
      hasEnvConfig ? envModel : (sMap['llmModel'] as String? ?? '').trim();
  final enabled = hasEnvConfig ? 1 : (sMap['llmEnabled'] as num?)?.toInt() ?? 0;
  if (enabled != 1 || baseUrl.isEmpty || apiKey.isEmpty) {
    stdout.writeln('!! LLM 未启用或配置不全');
    exit(2);
  }
  final all = (jsonDecode(File(casesPath).readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final selected = all
      .where((c) => tag == null || c['id'].toString().startsWith(tag))
      .toList();

  final config = LlmConfig(baseUrl: baseUrl, apiKey: apiKey, model: model);
  final svc = NlpService(llm: LlmClient());
  final now = DateTime.now();
  stdout.writeln('基准今天: ${now.year}-${_two(now.month)}-${_two(now.day)} '
      '(周${'一二三四五六日'[now.weekday - 1]})  model=$model');
  stdout.writeln('执行 ${selected.length} 条（tag=${tag ?? '全部'}）...');
  stdout.writeln(
      '====================================================================');
  var llmOk = 0, localFallback = 0, err = 0;
  for (final c in selected) {
    final input = c['input'] as String;
    final expected = c['expect'] as String?;
    try {
      final r = await svc.parse(input, config: config);
      final localBaseline = NlpService().parseLocal(input);
      final mismatches = expected == null
          ? const <String>[]
          : probeMismatches(r, expected, localBaseline: localBaseline);
      if (mismatches.isNotEmpty) {
        err++;
        stdout.writeln('${c['id']} | 期望不匹配: ${mismatches.join('; ')}');
      }
      if (r.source == 'llm') {
        llmOk++;
      } else if (r.fallbackFromLlm) {
        localFallback++;
      }
      final due = fmtDue(r);
      stdout.writeln(
          '${c['id']} | ${r.source}${r.fallbackFromLlm ? "(回退)" : ""} | title=${r.title} | due=$due | rrule=${r.rrule ?? "-"} | pri=${r.priority ?? "-"} | reminder=${r.reminderMinutes ?? "-"}');
      stdout.writeln('      input: $input');
    } catch (e) {
      err++;
      stdout.writeln('${c['id']} | 异常: $e');
      stdout.writeln('      input: $input');
    }
  }
  stdout.writeln(
      '====================================================================');
  stdout.writeln(
      '汇总: 共 ${selected.length} 条 | LLM生效=$llmOk | 回退本地=$localFallback | 异常=$err');
  if (err > 0) exitCode = 1;
}
