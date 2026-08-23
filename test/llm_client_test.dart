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

  test('首个端点返回空 choices 时继续探测备用端点', () async {
    final urls = <String>[];
    final mock = MockClient((req) async {
      urls.add(req.url.path);
      if (req.url.path == '/chat/completions') {
        return http.Response(
          jsonEncode({'choices': <Object>[]}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content':
                    '{"title":"写周报","due":null,"dateOnly":true,"rrule":null,"priority":0}'
              }
            }
          ]
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final d = await LlmClient(client: mock).enhance(
      '写周报',
      const LlmConfig(baseUrl: 'https://example.com', apiKey: 'k'),
    );

    expect(d?.title, '写周报');
    expect(urls, contains('/v1/chat/completions'));
  });

  test('accepts OpenAI-compatible content blocks in message.content', () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': [
                    {'type': 'text', 'text': '{"title":"交报告"}'},
                  ],
                },
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        ));

    final draft = await LlmClient(client: client).enhance(
      '交报告',
      const LlmConfig(baseUrl: 'https://example.com/v1', apiKey: 'k'),
    );

    expect(draft?.title, '交报告');
  });

  test('超出一年范围的提醒分钟数不会进入 LLM 草稿', () async {
    final mock = MockClient((_) async => http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content':
                      '{"title":"交报告","due":null,"dateOnly":true,"rrule":null,"priority":0,"reminderMinutes":999999}'
                }
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        ));

    final d = await LlmClient(client: mock).enhance('交报告', cfg);

    expect(d?.reminderMinutes, isNull);
  });
}
