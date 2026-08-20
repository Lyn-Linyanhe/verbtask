import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/nlp/llm_client.dart';
import 'package:verb_app/core/nlp/nlp_service.dart';

/// 真实网络测试（不走 MockClient）：用无效 key 打真实 OpenAI 兼容端点，
/// 应得到 LlmUnavailable（连接成功、鉴权失败），验证 NlpService 真实回退本地。
void main() {
  test('真实网络：LLM 调用失败(无效key)时 NlpService 回退本地并标记', () async {
    final client = LlmClient(); // 真实 HttpClient + 系统代理
    final svc = NlpService(llm: client);
    final result = await svc.parse(
      '明天交报告',
      config: const LlmConfig(
          baseUrl: 'https://api.deepseek.com', apiKey: 'sk-invalid'),
    );
    expect(result.source, 'local');
    expect(result.fallbackFromLlm, isTrue);
    expect(result.title, '交报告');
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('真实网络：listModels 无效 key 抛 LlmUnavailable（连通性已建立）', () async {
    final client = LlmClient();
    await expectLater(
      client.listModels(const LlmConfig(
          baseUrl: 'https://api.deepseek.com', apiKey: 'sk-invalid')),
      throwsA(isA<LlmUnavailable>()),
    );
  }, timeout: const Timeout(Duration(seconds: 30)));
}
