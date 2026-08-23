import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/app.dart';
import 'package:verb_app/core/nlp/nlp_service.dart';
import 'package:verb_app/core/nlp/zh_parser.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';

void main() {
  final parser = ZhParser();

  test('recognizes 不要提醒我 as an explicit reminder opt-out', () {
    final draft = parser.parse('明天下午3点不要提醒我交报告');

    expect(draft.reminderDisabled, isTrue);
    expect(draft.reminderMinutes, isNull);
    expect(draft.title, '交报告');
  });

  test('recognizes bare 不要提前提醒我 as an explicit reminder opt-out', () {
    final draft = parser.parse('明天不要提前提醒我开会');

    expect(draft.reminderDisabled, isTrue);
    expect(draft.reminderMinutes, isNull);
    expect(draft.title, '开会');
  });

  test('parses 每月最后一天 as the last calendar day', () {
    final draft = parser.parse('每月最后一天做账');

    expect(draft.rrule, 'FREQ=MONTHLY;BYMONTHDAY=-1');
    expect(draft.title, '做账');
  });

  test('anchors 下周末 to the Saturday of the next calendar week', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expected = today.add(Duration(days: 13 - today.weekday));
    final draft = parser.parse('下周末整理房间');

    expect(draft.due, isNotNull);
    expect(draft.due!.toLocal(),
        DateTime.utc(expected.year, expected.month, expected.day).toLocal());
    expect(draft.title, '整理房间');
  });

  test('extracts a hashtag list hint from quick-entry text', () {
    final draft = parser.parse('明天交周报 #工作');

    expect(draft.listName, '工作');
    expect(draft.title, '交周报');
  });

  test('rejects conversational filler instead of turning it into a note title',
      () {
    final draft = parser.parse('哦对对对，我想起来了');
    final result = NlpService().parseLocal('哦对对对，我想起来了');

    expect(draft.title, isEmpty);
    expect(result.title, isNull);
  });

  test('keeps a natural note and exposes an unschedulable reminder explicitly',
      () {
    final result = NlpService().parseLocal('提醒我买瓶酱油');

    expect(result.title, '买瓶酱油');
    expect(result.due, isNull);
    expect(result.reminderMinutes, 15);
    expect(result.reminderNeedsDue, isTrue);
  });

  testWidgets('quick entry does not create a task from conversational filler',
      (tester) async {
    final repository = InMemoryRepository();
    await tester.pumpWidget(VerbApp(
      repository: repository,
      initialLocale: const Locale('zh'),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '哦对对对，我想起来了');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('没有识别到可记录的事项'), findsOneWidget);
    expect(await repository.allTasks(), isEmpty);
  });
}
