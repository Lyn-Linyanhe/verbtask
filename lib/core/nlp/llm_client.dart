import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../net/system_proxy.dart';

/// 用户自填的 OpenAI 兼容接口配置（base_url + key，key 存本地）。
class LlmConfig {
  final String baseUrl;
  final String apiKey;
  final String model; // 模型名；为空时客户端回退默认
  const LlmConfig({
    required this.baseUrl,
    required this.apiKey,
    this.model = '',
  });
}

/// 未配置 / 调用失败。
class LlmUnavailable implements Exception {
  final String message;
  LlmUnavailable(this.message);
  @override
  String toString() => 'LlmUnavailable: $message';
}

/// LLM 解析的原始结果（不依赖 UI/NlpResult，避免循环依赖）。
class LlmDraft {
  final String? title;
  final String? dueIso; // ISO 8601；null=不限
  final bool? dateOnly;
  final String? rrule;
  final int? priority;
  const LlmDraft({
    this.title,
    this.dueIso,
    this.dateOnly,
    this.rrule,
    this.priority,
  });
}

/// 可选 LLM 增强解析客户端（OpenAI 兼容 chat/completions）。
class LlmClient {
  final http.Client _http;
  /// 默认使用跟随系统代理的 HTTP 客户端；测试可注入 MockClient。
  LlmClient({http.Client? client})
      : _http = client ?? _buildProxyClient();

  static http.Client _buildProxyClient() {
    final io = HttpClient()..findProxy = SystemProxy.findProxy;
    return IOClient(io);
  }

  Future<LlmDraft?> enhance(String text, LlmConfig cfg) async {
    final resp = await _http
        .post(
          Uri.parse(_endpoint(cfg.baseUrl)),
          headers: {
            'Content-Type': 'application/json',
            if (cfg.apiKey.isNotEmpty) 'Authorization': 'Bearer ${cfg.apiKey}',
          },
          body: jsonEncode({
            'model': cfg.model.isEmpty ? 'gpt-4o-mini' : cfg.model,
            'messages': [
              {
                'role': 'system',
                'content': '你是任务解析助手。把用户的中文任务文本解析成 JSON，只输出 JSON：'
                    '{"title":"任务标题","due":"ISO8601 或 null","dateOnly":true|false,"rrule":"RRULE 或 null","priority":0|1|2|3}。'
                    '不输出任何其他文字。',
              },
              {'role': 'user', 'content': text},
            ],
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (resp.statusCode != 200) {
      throw LlmUnavailable('HTTP ${resp.statusCode}');
    }
    final data = jsonDecode(utf8.decode(resp.bodyBytes));
    final choices = (data['choices'] as List?) ?? const [];
    final content = choices.isEmpty
        ? null
        : (choices.first as Map<String, dynamic>)['message']?['content']
            as String?;
    if (content == null || content.trim().isEmpty) return null;
    final map = _extractFirstJson(content);
    if (map == null) return null;
    return LlmDraft(
      title: map['title'] as String?,
      dueIso: map['due'] as String?,
      dateOnly: map['dateOnly'] as bool?,
      rrule: map['rrule'] as String?,
      priority: (map['priority'] as num?)?.toInt(),
    );
  }

  /// 拉取 OpenAI 兼容接口的可用模型 id 列表（GET /models）。
  Future<List<String>> listModels(LlmConfig cfg) async {
    final resp = await _http
        .get(
          Uri.parse(_modelsEndpoint(cfg.baseUrl)),
          headers: {
            'Content-Type': 'application/json',
            if (cfg.apiKey.isNotEmpty) 'Authorization': 'Bearer ${cfg.apiKey}',
          },
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw LlmUnavailable('HTTP ${resp.statusCode}');
    }
    final data = jsonDecode(utf8.decode(resp.bodyBytes));
    final arr = (data['data'] as List?) ?? const [];
    final names = <String>[];
    for (final item in arr) {
      if (item is Map && item['id'] is String) {
        names.add(item['id'] as String);
      }
    }
    return names;
  }

  /// 从 base_url 推导 /models 端点（去掉可能存在的 /chat/completions 或 /responses 后缀）。
  String _modelsEndpoint(String baseUrl) {
    var b = baseUrl.trim();
    if (b.endsWith('/')) b = b.substring(0, b.length - 1);
    if (b.endsWith('/chat/completions')) {
      b = b.substring(0, b.length - '/chat/completions'.length);
    } else if (b.endsWith('/responses')) {
      b = b.substring(0, b.length - '/responses'.length);
    }
    return '$b/models';
  }

  String _endpoint(String baseUrl) {
    var b = baseUrl.trim();
    if (b.endsWith('/')) b = b.substring(0, b.length - 1);
    if (b.endsWith('/chat/completions') || b.endsWith('/responses')) return b;
    return '$b/chat/completions';
  }

  Map<String, dynamic>? _extractFirstJson(String content) {
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      return jsonDecode(content.substring(start, end + 1))
          as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}







