import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:verb_app/core/nlp/llm_client.dart';

// 真实场景：geiliapi 中转站根路径 /chat/completions 返回 HTML，
// 正确端点是 /v1/chat/completions。enhance 应自动探测并重试。
void main() {
  final cfg = LlmConfig(baseUrl: 'https://sub.geiliapi.com/', apiKey: 'k', model: 'deepseek-v4-flash');

  test('enhance: 首端点返回 HTML 时自动 fallback 到 /v1/chat/completions', () async {
    final urls = <String>[];
    final mock = MockClient((req) async {
      urls.add(req.url.toString());
      if (req.url.path == '/chat/completions') {
        // 网关对未知路径返回 HTML 页面
        return http.Response('<!doctype html><html><body>Gateway</body></html>', 200,
            headers: {'content-type': 'text/html'});
      }
      return http.Response.bytes(
        utf8.encode(jsonEncode({
          'choices': [
            {
              'message': {
                'content': '{"title":"交周报","due":"2026-08-22T07:00:00.000Z","dateOnly":false,"rrule":null,"priority":2}'
              }
            }
          ]
        })),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = LlmClient(client: mock);
    final d = await client.enhance('明天下午3点 交周报 高', cfg);
    expect(d, isNotNull);
    expect(d!.title, '交周报');
    expect(urls.any((u) => u.contains('/v1/chat/completions')), isTrue,
        reason: '应重试 /v1/chat/completions');
  });

  test('enhance: 两个端点都非 JSON 时抛 LlmUnavailable', () async {
    final mock = MockClient((req) async =>
        http.Response('<!doctype html>...', 200, headers: {'content-type': 'text/html'}));
    final client = LlmClient(client: mock);
    await expectLater(
      client.enhance('x', cfg),
      throwsA(isA<LlmUnavailable>()),
    );
  });
}
