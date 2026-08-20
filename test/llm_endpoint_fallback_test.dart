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

  retryTests();
}



void retryTests() {
  // 单端点配置：baseUrl 已含 /v1 → 只有一个候选，便于精确计数重试次数
  final cfg = LlmConfig(baseUrl: 'https://sub.geiliapi.com/v1', apiKey: 'k', model: 'deepseek-v4-flash');
  http.Response jsonResp() => http.Response.bytes(
        utf8.encode(jsonEncode({
          'choices': [
            {'message': {'content': '{"title":"交周报","due":"2026-08-22T07:00:00.000Z","dateOnly":false,"rrule":null,"priority":2}'}}
          ]
        })),
        200,
        headers: {'content-type': 'application/json'},
      );

  test('enhance: 首次 5xx 偶发失败自动重试一次后成功', () async {
    var calls = 0;
    final mock = MockClient((req) async {
      calls++;
      if (calls == 1) return http.Response('bad gateway', 502, headers: {'content-type': 'text/html'});
      return jsonResp();
    });
    final d = await LlmClient(client: mock).enhance('明天下午3点 交周报 高', cfg);
    expect(calls, 2, reason: '首次失败应重试一次');
    expect(d!.title, '交周报');
  });

  test('enhance: 网络异常(类超时)自动重试一次后成功', () async {
    var calls = 0;
    final mock = MockClient((req) async {
      calls++;
      if (calls == 1) throw http.ClientException('timeout', Uri.parse(req.url.toString()));
      return jsonResp();
    });
    final d = await LlmClient(client: mock).enhance('明天下午3点 交周报 高', cfg);
    expect(calls, 2);
    expect(d!.title, '交周报');
  });

  test('enhance: 401 鉴权类错误不重试，立即抛 LlmUnavailable', () async {
    var calls = 0;
    final mock = MockClient((req) async {
      calls++;
      return http.Response('{"error":"invalid key"}', 401, headers: {'content-type': 'application/json'});
    });
    await expectLater(
      LlmClient(client: mock).enhance('x', cfg),
      throwsA(isA<LlmUnavailable>()),
    );
    expect(calls, 1, reason: '鉴权错误重试无意义，应答立即失败');
  });
}
