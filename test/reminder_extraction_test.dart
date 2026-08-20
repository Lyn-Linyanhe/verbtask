import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:verb_app/app.dart';
import 'package:verb_app/core/nlp/zh_parser.dart';
import 'package:verb_app/core/nlp/llm_client.dart';
import 'package:verb_app/core/nlp/nlp_service.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';
import 'package:verb_app/core/settings/local_settings.dart';
import 'package:verb_app/core/settings/settings_controller.dart';

/// 回归：快速录入 / LLM / 本地解析 的「提醒」提取与真实创建。
void main() {
  group('本地 zh_parser 提醒提取', () {
    final p = ZhParser();
    test('提前N分钟', () {
      final d = p.parse('提前30分钟提醒我交报告');
      expect(d.reminderMinutes, 30);
      expect(d.title, '交报告');
    });
    test('提前N小时换算为分钟', () {
      expect(p.parse('提前2小时准备').reminderMinutes, 120);
    });
    test('提前半小时', () {
      expect(p.parse('提前半小时提醒').reminderMinutes, 30);
    });
    test('只说“提醒”→默认15分钟', () {
      final d = p.parse('明天9点提醒我开会');
      expect(d.reminderMinutes, 15);
      expect(d.title, '开会');
      expect(d.due, isNotNull);
    });
    test('未提提醒→null', () {
      expect(p.parse('买菜').reminderMinutes, isNull);
    });
  });

  group('LLM 提醒透传', () {
    test('enhance 返回 reminderMinutes 并透传到 NlpResult', () async {
      final mock = MockClient((req) async {
        final body = utf8.decode(req.bodyBytes);
        expect(body, contains('reminderMinutes'), reason: '提示词应要求提取提醒');
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'choices': [
              {
                'message': {
                  'content':
                      '{"title":"交报告","due":"2026-08-22T07:00:00.000Z","dateOnly":false,"rrule":null,"priority":2,"reminderMinutes":45}'
                }
              }
            ]
          })),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final svc = NlpService(llm: LlmClient(client: mock));
      final r = await svc.parse('提前45分钟交报告',
          config: const LlmConfig(baseUrl: 'https://x/v1', apiKey: 'k'));
      expect(r.reminderMinutes, 45);
    });
    test('LLM 漏提“提醒”→安全网默认15分钟', () async {
      final mock = MockClient((_) async => http.Response.bytes(
            utf8.encode(jsonEncode({
              'choices': [
                {
                  'message': {
                    'content':
                        '{"title":"喝水","due":"2026-08-22T00:00:00.000Z","dateOnly":true,"rrule":null,"priority":0}'
                  }
                }
              ]
            })),
            200,
            headers: {'content-type': 'application/json'},
          ));
      final svc = NlpService(llm: LlmClient(client: mock));
      final r = await svc.parse('提醒我喝水',
          config: const LlmConfig(baseUrl: 'https://x/v1', apiKey: 'k'));
      expect(r.reminderMinutes, 15,
          reason: 'LLM 未给提醒但文本含“提醒”时安全网兜底15分钟');
    });
  });

  group('快速录入真实创建提醒', () {
    Future<(TaskService, InMemoryRepository, SettingsController)>
        setup({required bool defaultEnabled, int defaultOffset = -30}) async {
      final dir = Directory.systemTemp.createTempSync('verb_rm');
      final repo = InMemoryRepository();
      final svc = TaskService(repo);
      final settings = SettingsController(
          LocalSettings(File('${dir.path}/settings.json')), repo);
      settings.llmEnabled = 0;
      settings.notifyDefaultReminderEnabled = defaultEnabled;
      settings.notifyDefaultOffsetMin = defaultOffset;
      addTearDown(() => dir.deleteSync(recursive: true));
      return (svc, repo, settings);
    }

    Future<void> quickAdd(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField).first, text);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
    }

    testWidgets('全局默认提醒 → 快速录入创建带 -30min 提醒', (tester) async {
      final (_, repo, settings) = await setup(defaultEnabled: true);
      await tester.pumpWidget(VerbApp(
          repository: repo,
          initialLocale: const Locale('zh'),
          settings: settings));
      await tester.pumpAndSettle();

      await quickAdd(tester, '明天下午3点开会');
      final tasks = await repo.allTasks();
      expect(tasks.single.reminders, isNotEmpty);
      expect(tasks.single.reminders.first.offsetMinutes, -30);
    });

    testWidgets('显式“提前10分钟”优先于默认', (tester) async {
      final (_, repo, settings) = await setup(defaultEnabled: true);
      await tester.pumpWidget(VerbApp(
          repository: repo,
          initialLocale: const Locale('zh'),
          settings: settings));
      await tester.pumpAndSettle();

      await quickAdd(tester, '明天下午3点开会，提前10分钟提醒');
      final tasks = await repo.allTasks();
      expect(tasks.single.reminders.first.offsetMinutes, -10);
    });

    testWidgets('默认提醒关闭且未提提醒 → 不创建提醒', (tester) async {
      final (_, repo, settings) = await setup(defaultEnabled: false);
      await tester.pumpWidget(VerbApp(
          repository: repo,
          initialLocale: const Locale('zh'),
          settings: settings));
      await tester.pumpAndSettle();

      await quickAdd(tester, '买菜');
      final tasks = await repo.allTasks();
      expect(tasks.single.reminders, isEmpty);
    });
  });
}
