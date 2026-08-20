import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:verb_app/core/nlp/llm_client.dart';

void main() {
  final cfg = LlmConfig(baseUrl: 'https://example.com/v1', apiKey: 'k');

  test('解析 LLM 返回 JSON', () async {
    final mock = MockClient((req) async {
      expect(req.headers['Authorization'], 'Bearer k');
      return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content':
                      '{"title":"写周报","due":"2026-08-25T10:00:00Z","dateOnly":true,"rrule":null,"priority":2}'
                }
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'});
    });
    final client = LlmClient(client: mock);
    final d = await client.enhance('写周报', cfg);
    expect(d, isNotNull);
    expect(d!.title, '写周报');
    expect(d.dueIso, '2026-08-25T10:00:00Z');
    expect(d.dateOnly, isTrue);
    expect(d.priority, 2);
  });

  test('非 200 抛 LlmUnavailable', () async {
    final mock = MockClient((req) async => http.Response('err', 500));
    final client = LlmClient(client: mock);
    expect(() => client.enhance('x', cfg), throwsA(isA<LlmUnavailable>()));
  });
}
