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
        if (d != null && d.title != null) {
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
    if (dateOnly) {
      return DueDate(
        DateTime.utc(parsed.year, parsed.month, parsed.day),
        dateOnly: true,
      );
    }
    return DueDate(parsed.toUtc());
  }
}
