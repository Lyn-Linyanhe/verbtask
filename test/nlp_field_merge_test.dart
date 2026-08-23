import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:verb_app/core/nlp/llm_client.dart';
import 'package:verb_app/core/nlp/nlp_service.dart';
import 'package:verb_app/core/nlp/zh_parser.dart';

void main() {
  Future<NlpResult> parseWithLlm(String input,
      {String? rrule,
      int? reminderMinutes,
      String? title,
      String? due,
      bool dateOnly = true}) {
    final mock = MockClient((_) async => http.Response.bytes(
          utf8.encode(jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'title': title ?? (input.contains('浇花') ? '浇花' : '任务'),
                    'due': due,
                    'dateOnly': dateOnly,
                    'rrule': rrule,
                    'priority': 0,
                    'reminderMinutes': reminderMinutes,
                  }),
                },
              },
            ],
          })),
          200,
          headers: {'content-type': 'application/json'},
        ));
    return NlpService(llm: LlmClient(client: mock)).parse(
      input,
      config: const LlmConfig(baseUrl: 'https://example.com/v1', apiKey: 'k'),
    );
  }

  test('LLM 漏字段时保留本地明确的重复和提醒', () async {
    final result = await parseWithLlm('每隔2天提前30分钟浇花');

    expect(result.rrule, 'FREQ=DAILY;INTERVAL=2');
    expect(result.reminderMinutes, 30);
  });

  test('本地解析识别“每两周”与“每个周末”', () {
    final parser = ZhParser();

    expect(parser.parse('每两周做一次体检').rrule, 'FREQ=WEEKLY;INTERVAL=2');
    expect(parser.parse('两周一次做体检').rrule, 'FREQ=WEEKLY;INTERVAL=2');
    expect(parser.parse('每个周末大扫除').rrule, 'FREQ=WEEKLY;BYDAY=SA,SU');
  });

  test('本地解析识别三周和三个月的间隔', () {
    final parser = ZhParser();

    expect(parser.parse('每三周做一次体检').rrule, 'FREQ=WEEKLY;INTERVAL=3');
    expect(parser.parse('每三个月做一次体检').rrule, 'FREQ=MONTHLY;INTERVAL=3');
  });

  test('LLM 合法返回三周或三个月时不被本地语义门禁丢弃', () async {
    final weekly =
        await parseWithLlm('每三周做一次体检', rrule: 'FREQ=WEEKLY;INTERVAL=3');
    final monthly =
        await parseWithLlm('每三个月做一次体检', rrule: 'FREQ=MONTHLY;INTERVAL=3');

    expect(weekly.rrule, 'FREQ=WEEKLY;INTERVAL=3');
    expect(monthly.rrule, 'FREQ=MONTHLY;INTERVAL=3');
  });

  test('提醒同义词会触发提醒意图', () {
    final parser = ZhParser();

    expect(parser.parse('通知我明天开会').reminderMinutes, 15);
    expect(parser.parse('提示我明天开会').reminderMinutes, 15);
    expect(parser.parse('别忘了明天交报告').reminderMinutes, 15);
  });

  test('明确否定提醒不会被关键词误判', () {
    final parser = ZhParser();

    for (final text in [
      '不用提醒我明天交报告',
      '无需提醒明天交报告',
      '不要提醒我明天交报告',
      '不提醒我明天交报告',
      '不用提前10分钟提醒我明天交报告',
    ]) {
      final result = parser.parse(text);
      expect(result.reminderMinutes, isNull, reason: text);
      expect(result.reminderDisabled, isTrue, reason: text);
    }
  });

  test('LLM 路径保留本地明确的不提醒意图', () async {
    final result = await parseWithLlm('不用提醒我明天交报告', reminderMinutes: 15);

    expect(result.reminderMinutes, isNull);
    expect(result.reminderDisabled, isTrue);
  });

  test('本地明确重复规则优先于 LLM 错误规则', () async {
    final result = await parseWithLlm(
      '每个周末大扫除',
      rrule: 'FREQ=DAILY',
    );

    expect(result.rrule, 'FREQ=WEEKLY;BYDAY=SA,SU');
  });

  test('LLM 安全网不会把“发通知”误判成提醒', () async {
    final result = await parseWithLlm(
      '明天给客户发通知',
      title: '给客户发通知',
    );

    expect(result.reminderMinutes, isNull);
    expect(result.reminderDisabled, isFalse);
  });

  test('本地识别的每月月底优先于 LLM 的普通月重复', () async {
    final result = await parseWithLlm(
      '每月月底做账',
      rrule: 'FREQ=MONTHLY',
      title: '做账',
    );

    expect(result.rrule, 'FREQ=MONTHLY;BYMONTHDAY=-1');
  });

  test('本地每月具体日期不被 LLM 普通月重复覆盖', () async {
    final result = await parseWithLlm(
      '每月15号交房租',
      rrule: 'FREQ=MONTHLY',
      title: '交房租',
    );

    expect(result.rrule, 'FREQ=MONTHLY;BYMONTHDAY=15');
  });

  test('本地年度月份不被 LLM 错误的 BYMONTH 覆盖', () async {
    final result = await parseWithLlm(
      '每年6月体检',
      rrule: 'FREQ=YEARLY;BYMONTH=12',
      title: '体检',
    );

    expect(result.rrule, 'FREQ=YEARLY;BYMONTH=6');
  });

  test('本地工作日约束不被 LLM 普通周重复覆盖', () async {
    final result = await parseWithLlm(
      '每个工作日打卡',
      rrule: 'FREQ=WEEKLY',
      title: '打卡',
    );

    expect(result.rrule, 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR');
  });

  test('没有提醒意图时不接受 LLM 凭空添加的提醒', () async {
    final result = await parseWithLlm('买瓶酱油', reminderMinutes: 15);

    expect(result.reminderMinutes, isNull);
    expect(result.reminderDisabled, isFalse);
  });

  test('本地明确每天时不接受 LLM 凭空增加的星期约束', () async {
    final result = await parseWithLlm(
      '每天喝水',
      rrule: 'FREQ=DAILY;BYDAY=MO',
      title: '喝水',
    );

    expect(result.rrule, 'FREQ=DAILY');
  });

  test('非法 LLM 重复规则回退为无重复', () async {
    final result = await parseWithLlm(
      '买牛奶',
      rrule: 'FREQ=NOPE',
      title: '买牛奶',
    );

    expect(result.rrule, isNull);
  });

  test('本地已提取出的标题不会被 LLM 无关标题覆盖', () async {
    final result = await parseWithLlm(
      '明天交报告',
      title: '买牛奶',
    );

    expect(result.title, '交报告');
  });

  test('LLM 路径使用本地清洗后的动作标题并保留给我这一接收者', () async {
    final result = await parseWithLlm(
      '明天下午3点前把周报交给我',
      title: '交周报',
    );

    expect(result.title, '把周报交给我');
  });

  test('LLM 路径不会把“晚八点”解析成早上八点', () async {
    final result = await parseWithLlm(
      '下周五晚八点和同事聚餐',
      title: '晚 和同事聚餐',
    );

    expect(result.due, isNotNull);
    expect(result.due!.value.toLocal().hour, 20);
    expect(result.title, '和同事聚餐');
  });

  test('“晚点”不应被提升为晚上八点', () async {
    final result = await parseWithLlm(
      '明天晚点交报告',
      title: '交报告',
      due: '2026-08-22',
    );

    expect(result.due, isNotNull);
    expect(result.due!.dateOnly, isTrue);
  });

  test('非法时刻不应被 DateTime 进位成错误的具体提醒时刻', () async {
    final result = await parseWithLlm(
      '明天25点开会',
      title: '开会',
      due: '2026-08-22',
    );

    expect(result.due, isNotNull);
    expect(result.due!.dateOnly, isTrue);
  });

  test('裸“提前提醒我”不应残留在任务标题', () async {
    final result = await parseWithLlm(
      '明天交报告，提前提醒我',
      title: '交报告',
    );

    expect(result.title, '交报告');
    expect(result.reminderMinutes, 15);
  });
}
