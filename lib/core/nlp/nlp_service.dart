import '../models/task.dart';
import 'zh_parser.dart';
import 'llm_client.dart';

class NlpResult {
  final String? title;
  final DueDate? due;
  final String? rrule;
  final int? priority;
  final bool needsConfirm;
  final String source;
  final bool fallbackFromLlm;
  const NlpResult({
    this.title,
    this.due,
    this.rrule,
    this.priority,
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
          return NlpResult(
            title: d.title,
            due: d.dueIso != null
                ? _dueFromLlm(d.dueIso!, d.dateOnly ?? false)
                : null,
            rrule: d.rrule,
            priority: d.priority,
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
