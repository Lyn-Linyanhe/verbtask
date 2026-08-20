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

  group('LLM 安全网：提醒意图', () {
    Future<NlpResult> parseWith(String input,
        {Map<String, dynamic>? draft}) async {
      final mock = MockClient((_) async => http.Response.bytes(
            utf8.encode(jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': jsonEncode(draft ??
                        {
                          'title': 'X',
                          'due': null,
                          'dateOnly': false,
                          'rrule': null,
                          'priority': 0
                        })
                  }
                }
              ]
            })),
            200,
            headers: {'content-type': 'application/json'},
          ));
      return NlpService(llm: LlmClient(client: mock)).parse(
        input,
        config: const LlmConfig(baseUrl: 'https://x/v1', apiKey: 'k'),
      );
    }

    test('LLM 漏提提醒，但含“叫我”→15', () async {
      final r = await parseWith('明天早上叫我起床');
      expect(r.reminderMinutes, 15);
    });
    test('LLM 漏提提醒，但含“闹钟”→15', () async {
      final r = await parseWith('帮我定个明早7点的闹钟起床',
          draft: const {
            'title': '定闹钟起床',
            'due': '2026-08-22T07:00:00.000Z',
            'dateOnly': false,
            'rrule': null,
            'priority': 0
          });
      expect(r.reminderMinutes, 15);
    });
    test('LLM 漏提提醒，但含“记得”→15', () async {
      final r = await parseWith('记得明天上午10点给客户回电话');
      expect(r.reminderMinutes, 15);
    });
    test('LLM 已给提前量时不被覆盖', () async {
      final r = await parseWith('明天早上叫我起床，提前1小时',
          draft: const {
            'title': '起床',
            'due': '2026-08-22T00:00:00.000Z',
            'dateOnly': true,
            'rrule': null,
            'priority': 0,
            'reminderMinutes': 60
          });
      expect(r.reminderMinutes, 60);
    });
  });

  group('LLM 安全网：重复任务时刻补回', () {
    Future<NlpResult> parseWith(String input,
        {String? rrule, String? due}) async {
      final mock = MockClient((_) async => http.Response.bytes(
            utf8.encode(jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': jsonEncode({
                      'title': 'X',
                      'due': due,
                      'dateOnly': true,
                      'rrule': rrule,
                      'priority': 0
                    })
                  }
                }
              ]
            })),
            200,
            headers: {'content-type': 'application/json'},
          ));
      return NlpService(llm: LlmClient(client: mock)).parse(
        input,
        config: const LlmConfig(baseUrl: 'https://x/v1', apiKey: 'k'),
      );
    }

    test('LLM 漏 BYHOUR，原文含“下午3点”→补 15:00', () async {
      final r = await parseWith('每两周周五下午3点开周会',
          rrule: 'FREQ=WEEKLY;INTERVAL=2;BYDAY=FR');
      expect(
          r.rrule, 'FREQ=WEEKLY;INTERVAL=2;BYDAY=FR;BYHOUR=15;BYMINUTE=0;BYSECOND=0');
    });
    test('LLM 漏 BYHOUR，原文“下班后”→补 18:00', () async {
      final r = await parseWith('每天下班后打卡', rrule: 'FREQ=DAILY');
      expect(r.rrule, 'FREQ=DAILY;BYHOUR=18;BYMINUTE=0;BYSECOND=0');
    });
    test('已有 BYHOUR 不重复追加', () async {
      final r = await parseWith('每周五下午3点开周会',
          rrule: 'FREQ=WEEKLY;BYDAY=FR;BYHOUR=15;BYMINUTE=0;BYSECOND=0');
      expect(r.rrule, 'FREQ=WEEKLY;BYDAY=FR;BYHOUR=15;BYMINUTE=0;BYSECOND=0');
    });
    test('LLM 把“每月月底”写成 BYMONTHDAY=31 → 改 -1', () async {
      final r = await parseWith('每月月底做账',
          rrule: 'FREQ=MONTHLY;BYMONTHDAY=31');
      expect(r.rrule, 'FREQ=MONTHLY;BYMONTHDAY=-1');
    });
    test('LLM 漏 BYDAY，原文“下周二”→补 BYDAY=TU', () async {
      final r = await parseWith('下周二下午两点开始每周开会',
          rrule: 'FREQ=WEEKLY;BYHOUR=14;BYMINUTE=0;BYSECOND=0');
      expect(r.rrule,
          'FREQ=WEEKLY;BYHOUR=14;BYMINUTE=0;BYSECOND=0;BYDAY=TU');
    });
    test('LLM 漏 BYDAY，原文“每周二和周四”→补 BYDAY=TU,TH', () async {
      final r = await parseWith('每周二和周四晚上8点学英语',
          rrule: 'FREQ=WEEKLY;BYHOUR=20;BYMINUTE=0;BYSECOND=0');
      expect(r.rrule,
          'FREQ=WEEKLY;BYHOUR=20;BYMINUTE=0;BYSECOND=0;BYDAY=TU,TH');
    });
    test('LLM 凭空写 BYHOUR=0 且原文无时刻 → 移除', () async {
      final r = await parseWith('每周五交周报 记得提前提醒',
          rrule: 'FREQ=WEEKLY;BYDAY=FR;BYHOUR=0;BYMINUTE=0;BYSECOND=0');
      expect(r.rrule, 'FREQ=WEEKLY;BYDAY=FR');
    });
    test('原文确实有“0点”→保留 BYHOUR=0', () async {
      final r = await parseWith('每周五0点打卡',
          rrule: 'FREQ=WEEKLY;BYDAY=FR;BYHOUR=0;BYMINUTE=0;BYSECOND=0');
      expect(r.rrule, 'FREQ=WEEKLY;BYDAY=FR;BYHOUR=0;BYMINUTE=0;BYSECOND=0');
    });
    test('LLM 把“每周末”写成仅 SA 且凭空 BYHOUR=10 → SA,SU 且无时刻', () async {
      final r = await parseWith('每周末大扫除',
          rrule: 'FREQ=WEEKLY;BYDAY=SA;BYHOUR=10;BYMINUTE=0;BYSECOND=0');
      expect(r.rrule, 'FREQ=WEEKLY;BYDAY=SA,SU');
    });
    test('LLM 已给 SA,SU 不重复改', () async {
      final r = await parseWith('每周末大扫除',
          rrule: 'FREQ=WEEKLY;BYDAY=SA,SU');
      expect(r.rrule, 'FREQ=WEEKLY;BYDAY=SA,SU');
    });
    test('LLM 漏 BYHOUR，原文中文数字“两点”→补 14:00', () async {
      final r = await parseWith('每两周周五下午两点开周会',
          rrule: 'FREQ=WEEKLY;INTERVAL=2;BYDAY=FR');
      expect(r.rrule,
          'FREQ=WEEKLY;INTERVAL=2;BYDAY=FR;BYHOUR=14;BYMINUTE=0;BYSECOND=0');
    });
    test('LLM 漏 BYHOUR，原文仅“下午”→补默认 15:00', () async {
      final r = await parseWith('每两周周五下午开周会',
          rrule: 'FREQ=WEEKLY;INTERVAL=2;BYDAY=FR');
      expect(r.rrule,
          'FREQ=WEEKLY;INTERVAL=2;BYDAY=FR;BYHOUR=15;BYMINUTE=0;BYSECOND=0');
    });
    test('LLM 凭“下午”给的 BYHOUR 不被清洗', () async {
      final r = await parseWith('每周五下午提交周报',
          rrule: 'FREQ=WEEKLY;BYDAY=FR;BYHOUR=15;BYMINUTE=0;BYSECOND=0');
      expect(r.rrule, 'FREQ=WEEKLY;BYDAY=FR;BYHOUR=15;BYMINUTE=0;BYSECOND=0');
    });
  });

  group('LLM 安全网：仅日期提升为具体时刻', () {
    test('due 仅日期 + 原文仅“下午”→ 默认 15:00', () async {
      final mock = MockClient((_) async => http.Response.bytes(
            utf8.encode(jsonEncode({
              'choices': [
                {
                  'message': {
                    'content':
                        '{"title":"交报告","due":"2026-08-22","dateOnly":true,"rrule":null,"priority":0}'
                  }
                }
              ]
            })),
            200,
            headers: {'content-type': 'application/json'},
          ));
      final svc = NlpService(llm: LlmClient(client: mock));
      final r = await svc.parse('明天下午交报告',
          config: const LlmConfig(baseUrl: 'https://x/v1', apiKey: 'k'));
      expect(r.due!.dateOnly, isFalse);
      expect(r.due!.value.toLocal().hour, 15);
    });

    test('due 仅日期 + 原文下午3点 → 15:00 具体时刻', () async {
      final mock = MockClient((_) async => http.Response.bytes(
            utf8.encode(jsonEncode({
              'choices': [
                {
                  'message': {
                    'content':
                        '{"title":"交报告","due":"2026-08-22","dateOnly":true,"rrule":null,"priority":0}'
                  }
                }
              ]
            })),
            200,
            headers: {'content-type': 'application/json'},
          ));
      final svc = NlpService(llm: LlmClient(client: mock));
      final r = await svc.parse('明天下午3点交报告',
          config: const LlmConfig(baseUrl: 'https://x/v1', apiKey: 'k'));
      expect(r.due!.dateOnly, isFalse);
      expect(r.due!.value.toLocal().hour, 15);
    });
  });

  group('本地 zh_parser：口语提醒/时刻', () {
    final p = ZhParser();
    test('叫我起床 → 15分钟', () {
      final d = p.parse('明天早上叫我起床');
      expect(d.reminderMinutes, 15);
      expect(d.title, '起床');
      expect(d.due, isNotNull);
    });
    test('闹钟 → 15分钟', () {
      final d = p.parse('明早7点闹钟叫我起床');
      expect(d.reminderMinutes, 15);
      expect(d.due!.toLocal().hour, 7);
      expect(d.title, '起床');
    });
    test('记得 → 15分钟', () {
      final d = p.parse('记得明天上午10点给客户回电话');
      expect(d.reminderMinutes, 15);
    });
    test('下班后 → 18:00', () {
      final d = p.parse('明天下班后去买菜');
      expect(d.due!.toLocal().hour, 18);
      expect(d.title, '去买菜');
    });
    test('每天下班后打卡 → RRULE 带 BYHOUR=18', () {
      final d = p.parse('每天下班后打卡');
      expect(d.rrule, 'FREQ=DAILY;BYHOUR=18;BYMINUTE=0;BYSECOND=0');
      expect(d.title, '打卡');
    });
    test('睡前 → 23:00', () {
      final d = p.parse('睡前刷牙');
      expect(d.due!.toLocal().hour, 23);
      expect(d.title, '刷牙');
    });
    test('帮我记着每天晚上10点吃药 → 重复+提醒', () {
      final d = p.parse('帮我记着每天晚上10点吃药');
      expect(d.rrule, 'FREQ=DAILY;BYHOUR=22;BYMINUTE=0;BYSECOND=0');
      expect(d.reminderMinutes, 15);
      expect(d.title, '吃药');
    });
    test('时间段词默认时刻：每周五下午提交周报 → 15:00', () {
      final d = p.parse('每周五下午提交周报');
      expect(d.rrule, 'FREQ=WEEKLY;BYDAY=FR;BYHOUR=15;BYMINUTE=0;BYSECOND=0');
      expect(d.title, '提交周报');
      expect(d.reminderMinutes, isNull);
    });
    test('时间段词默认时刻：明天下午交报告 → 明天15:00', () {
      final d = p.parse('明天下午交报告');
      expect(d.due!.toLocal().hour, 15);
      expect(d.title, '交报告');
      expect(d.reminderMinutes, isNull);
    });
    test('中文数字时刻：明早六点半叫我起来晨跑', () {
      final d = p.parse('明早六点半叫我起来晨跑');
      expect(d.reminderMinutes, 15);
      expect(d.due!.toLocal().hour, 6);
      expect(d.due!.toLocal().minute, 30);
    });
    test('中文数字时刻：每周六上午十点提醒我上瑜伽课', () {
      final d = p.parse('每周六上午十点提醒我上瑜伽课');
      expect(d.rrule, 'FREQ=WEEKLY;BYDAY=SA;BYHOUR=10;BYMINUTE=0;BYSECOND=0');
      expect(d.reminderMinutes, 15);
      expect(d.title, '上瑜伽课');
    });
    test('中文数字时刻：十点一刻开会', () {
      final d = p.parse('明天上午十点一刻开会');
      expect(d.due!.toLocal().hour, 10);
      expect(d.due!.toLocal().minute, 15);
    });
  });
}

