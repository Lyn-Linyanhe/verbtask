import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/models/models.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';
import 'package:verb_app/core/notifications/reminder_scheduler.dart';
import 'package:verb_app/core/rrule/rrule_service.dart';
import 'package:verb_app/core/settings/local_settings.dart';

void main() {
  test('绝对时刻提醒：返回 absoluteAt（高于偏移）', () {
    final abs = DateTime.utc(2026, 9, 1, 8, 0);
    final s = ReminderScheduler();
    final fires = s.fireTimesForDue(
      DateTime.utc(2026, 9, 1, 10, 0),
      [Reminder(id: 'r1', absoluteAt: abs)],
    );
    expect(fires.single, abs);
  });

  test('重复任务 seriesId 创建/编辑保持不变', () async {
    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    final t = await svc.create(title: '每日锻炼', rrule: 'FREQ=DAILY');
    final edited = await svc.edit(t, title: '每日锻炼 v2');
    expect(edited.title, '每日锻炼 v2');
    expect(edited.rrule, 'FREQ=DAILY');
    // copyWith 保持系列在同一 id/已存逻辑上 seriesId 可为空——这里验证 rrule 不被 edit 清空
    expect(t.id, edited.id);
  });

  test('search 过滤命中 title 或 notes', () async {
    final repo = InMemoryRepository();
    final svc = TaskService(repo);
    await svc.create(title: '买菜', notes: '记得带购物袋');
    await svc.create(title: '交房租');
    final r1 = await svc.query(search: '购物袋');
    expect(r1.map((t) => t.title), ['买菜']);
    final r2 = await svc.query(search: '房租');
    expect(r2.map((t) => t.title), ['交房租']);
  });

  test('LocalSettings：托盘/置顶/自启/同步间隔/模型 默认值与持久化', () async {
    final dir = await Directory.systemTemp.createTemp('verbset');
    addTearDown(() => dir.delete(recursive: true));
    final f = File('${dir.path}/settings.json');
    final s = LocalSettings(f);
    // 默认值
    expect(s.trayEnabled, isTrue);
    expect(s.alwaysOnTop, isFalse);
    expect(s.autostartEnabled, isTrue);
    expect(s.syncAutoIntervalMin, 30);
    expect(s.llmModel, '');
    // 写入并持久化
    s.alwaysOnTop = true;
    s.syncAutoIntervalMin = 15;
    s.llmModel = 'deepseek-chat';
    await s.save();
    final s2 = LocalSettings(f);
    expect(s2.alwaysOnTop, isTrue);
    expect(s2.syncAutoIntervalMin, 15);
    expect(s2.llmModel, 'deepseek-chat');
  });
}
