import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:verb_app/core/nlp/llm_client.dart';
import 'package:verb_app/core/nlp/nlp_service.dart';

// 回归保护：防止再次退化 —— ①相对日期基准（今天日期）必须要注入提示词；
// ②rrule 必须归一化为不带 RRULE: 前缀；③LLM 出错时应回退本地并标记。
void main() {
  final cfg = LlmConfig(
      baseUrl: 'https://sub.geiliapi.com/', apiKey: 'k', model: 'deepseek-v4-flash');

  http.Response jsonResp(Map<String, dynamic> draft) => http.Response.bytes(
        utf8.encode(jsonEncode({
          'choices': [
            {
              'message': {
                'content': jsonEncode(draft),
              }
            }
          ]
        })),
        200,
        headers: {'content-type': 'application/json'},
      );

  test('enhance: 请求体里必须注入今天日期作为相对时间基准', () async {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final bodies = <String>[];
    final mock = MockClient((req) async {
      bodies.add(utf8.decode(req.bodyBytes));
      return jsonResp({
        'title': '交周报',
        'due': '2026-08-22T07:00:00.000Z',
        'dateOnly': false,
        'rrule': null,
        'priority': 2,
      });
    });
    await LlmClient(client: mock).enhance('发消息', cfg);
    final sysMsg = (jsonDecode(bodies.single)
        as Map<String, dynamic>)['messages'][0]['content'] as String;
    expect(sysMsg, contains(todayStr),
        reason: '提示词须包含今天日期，否则 LLM 无法正确推算明天/下周一/月底');
  });

  test('enhance: rrule 归一化为不带 RRULE: 前缀', () async {
    final mock = MockClient((req) async => jsonResp({
          'title': '体检',
          'due': null,
          'dateOnly': true,
          'rrule': 'RRULE:FREQ=WEEKLY;INTERVAL=2',
          'priority': 1,
        }));
    final d = await LlmClient(client: mock).enhance('两周做一次体检', cfg);
    expect(d!.rrule, 'FREQ=WEEKLY;INTERVAL=2');
  });

  test('parse: LLM 给无时间部分 ISO 时按仅日期处理', () async {
    final fake = _FakeLlm(LlmDraft(
      title: '交房租',
      dueIso: '2026-08-31',
      dateOnly: null, // 未给 → 应由 enhance 后的推断兜底
      rrule: null,
      priority: 1,
    ));
    final svc = NlpService(llm: fake);
    final r = await svc.parse('月底前交房租', config: cfg);
    expect(r.source, 'llm');
    expect(r.due, isNotNull);
    expect(r.due!.dateOnly, isTrue, reason: '无时刻信息应视为仅日期');
    expect(
      r.due!.value.toIso8601String().startsWith('2026-08-31'),
      isTrue,
    );
  });

  test('parse: LLM 抛错时回退本地并标记 fallbackFromLlm', () async {
    final fake = _FakeLlmThrows();
    final svc = NlpService(llm: fake);
    final r = await svc.parse('明天交周报', config: cfg);
    expect(r.source, 'local');
    expect(r.fallbackFromLlm, isTrue);
  });
}

class _FakeLlm extends LlmClient {
  final LlmDraft draft;
  _FakeLlm(this.draft);
  @override
  Future<LlmDraft?> enhance(String text, LlmConfig config) async => draft;
}

class _FakeLlmThrows extends LlmClient {
  @override
  Future<LlmDraft?> enhance(String text, LlmConfig config) async =>
      throw LlmUnavailable('mock down');
}
