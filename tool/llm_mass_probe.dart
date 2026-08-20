// 批量真实 LLM 探测工具（人类可读回归）。
// 用法：dart run tool/llm_mass_probe.dart --settings <settings.json路径> [--cases docs/nlp_llm_cases.json] [--tag A4]
// settings.json 也可用环境变量 VERBTASK_SETTINGS 指定；cases 默认 docs/nlp_llm_cases.json。
// 本文件不硬编码任何机器路径。
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:verb_app/core/nlp/nlp_service.dart';
import 'package:verb_app/core/nlp/llm_client.dart';

String _two(int n) => n.toString().padLeft(2, '0');
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
    if (args[i] == '--settings' && i + 1 < args.length) settingsPath = args[i + 1];
    if (args[i] == '--cases' && i + 1 < args.length) casesPath = args[i + 1];
    if (args[i] == '--tag' && i + 1 < args.length) tag = args[i + 1];
  }
  settingsPath ??= Platform.environment['VERBTASK_SETTINGS'];
  if (settingsPath == null || !File(settingsPath).existsSync()) {
    stdout.writeln('!! 需要 settings.json 路径：--settings <path> 或环境变量 VERBTASK_SETTINGS');
    exit(2);
  }

  final sMap = jsonDecode(File(settingsPath).readAsStringSync()) as Map<String, dynamic>;
  final baseUrl = (sMap['llmBaseUrl'] as String? ?? '').trim();
  final apiKey = (sMap['llmKey'] as String? ?? '').trim();
  final model = (sMap['llmModel'] as String? ?? '').trim();
  final enabled = (sMap['llmEnabled'] as num?)?.toInt() ?? 0;
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
  stdout.writeln('====================================================================');
  var llmOk = 0, localFallback = 0, err = 0;
  for (final c in selected) {
    final input = c['input'] as String;
    try {
      final r = await svc.parse(input, config: config);
      if (r.source == 'llm') {
        llmOk++;
      } else if (r.fallbackFromLlm) {
        localFallback++;
      }
      final due = fmtDue(r);
      stdout.writeln(
          '${c['id']} | ${r.source}${r.fallbackFromLlm ? "(回退)" : ""} | title=${r.title} | due=$due | rrule=${r.rrule ?? "-"} | pri=${r.priority ?? "-"}');
      stdout.writeln('      input: $input');
    } catch (e) {
      err++;
      stdout.writeln('${c['id']} | 异常: $e');
      stdout.writeln('      input: $input');
    }
  }
  stdout.writeln('====================================================================');
  stdout.writeln('汇总: 共 ${selected.length} 条 | LLM生效=$llmOk | 回退本地=$localFallback | 异常=$err');
}
