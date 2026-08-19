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
  const NlpResult({
    this.title, this.due, this.rrule, this.priority,
    this.needsConfirm = true, this.source = 'local',
  });
  bool get isEmpty => title == null && due == null && rrule == null && priority == null;
}

/// 三级解析：本地规则(zh) -> 可选 LLM -> 手动兜底。
class NlpService {
  final ZhParser _zh;
  final LlmClient? llm;
  NlpService({ZhParser? zh, this.llm}) : _zh = zh ?? ZhParser();

  NlpResult parseLocal(String text) {
    final d = _zh.parse(text);
    return NlpResult(
      title: d.title.isEmpty ? null : d.title,
      due: d.due != null ? DueDate(d.due!, dateOnly: d.dateOnly) : null,
      rrule: d.rrule,
      priority: d.priority,
      needsConfirm: true,
      source: 'local',
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
                ? DueDate(DateTime.parse(d.dueIso!).toUtc(), dateOnly: false)
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
    return parseLocal(text);
  }
}

