import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/models/models.dart';
import 'package:verb_app/core/services/task_service.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';
import 'package:verb_app/core/storage/repository.dart';

class FailingSnapshotRepository extends InMemoryRepository {
  @override
  Future<void> replaceSnapshot({
    required List<Task> tasks,
    required List<TaskList> lists,
    Iterable<Change> changes = const [],
    Iterable<TaskTombstone> tombstones = const [],
  }) async {
    throw StateError('simulated snapshot failure');
  }
}

void main() {
  final first = DateTime.utc(2026, 1, 1, 9);
  final second = DateTime.utc(2026, 1, 2, 9);
  final third = DateTime.utc(2026, 1, 3, 9);

  test('单次编辑保存实例覆盖，不把修改伪装成跳过', () async {
    final repo = InMemoryRepository();
    final service = TaskService(repo);
    final task = await service.create(
      title: '每日锻炼',
      due: DueDate(first),
      rrule: 'FREQ=DAILY',
    );

    final result = await service.editRecurring(
      task,
      scope: RecurrenceEditScope.occurrence,
      occurrence: second,
      title: '每日瑜伽',
      notes: '改到家里做',
      due: DueDate(DateTime.utc(2026, 1, 2, 20)),
      status: TaskStatus.doing,
      priority: 3,
      reminders: const [Reminder(id: 'override', offsetMinutes: -15)],
      reminderPolicy: ReminderPolicy.enabled,
    );

    final override = result.series.occurrenceOverrides[occurrenceKey(second)];
    expect(override, isNotNull);
    expect(override!.title, '每日瑜伽');
    expect(override.notes, '改到家里做');
    expect(override.due?.value, DateTime.utc(2026, 1, 2, 20));
    expect(override.status, TaskStatus.doing);
    expect(override.priority, 3);
    expect(result.series.skippedOccurrences,
        isNot(contains(occurrenceKey(second))));
    expect(result.newSeries, isNull);

    final stored = (await repo.allTasks()).single;
    expect(stored.occurrenceOverrides, contains(occurrenceKey(second)),
        reason: 'override 应通过仓库保存');
  });

  test('实例覆盖可以 JSON 往返', () async {
    final repo = InMemoryRepository();
    final service = TaskService(repo);
    final task = await service.create(
      title: '每日阅读',
      due: DueDate(first),
      rrule: 'FREQ=DAILY',
    );
    final result = await service.editRecurring(
      task,
      scope: RecurrenceEditScope.occurrence,
      occurrence: second,
      title: '每日阅读（周末版）',
      due: null,
      reminders: const [],
      reminderPolicy: ReminderPolicy.disabled,
    );

    final restored = Task.fromJson(result.series.toJson());
    expect(restored.occurrenceOverrides[occurrenceKey(second)]?.title,
        '每日阅读（周末版）');
    expect(restored.occurrenceOverrides[occurrenceKey(second)]?.due, isNull);
    expect(restored.occurrenceOverrides[occurrenceKey(second)]?.reminderPolicy,
        ReminderPolicy.disabled);
  });

  test('实例覆盖显式清空后，后续部分编辑不会回退到系列值', () async {
    final repo = InMemoryRepository();
    final service = TaskService(repo);
    final task = await service.create(
      title: '每日整理',
      listId: 'work',
      due: DueDate(first),
      rrule: 'FREQ=DAILY',
      reminders: const [Reminder(id: 'base', offsetMinutes: -30)],
    );

    await service.editRecurring(
      task,
      scope: RecurrenceEditScope.occurrence,
      occurrence: second,
      due: null,
      listId: null,
      reminders: const [],
      reminderPolicy: ReminderPolicy.disabled,
    );
    final afterClear = (await repo.allTasks()).single;
    final editedAgain = await service.editRecurring(
      afterClear,
      scope: RecurrenceEditScope.occurrence,
      occurrence: second,
      title: '每日整理（更新标题）',
    );

    final override =
        editedAgain.series.occurrenceOverrides[occurrenceKey(second)];
    expect(override, isNotNull);
    expect(override!.due, isNull);
    expect(override.listId, isNull);
    expect(override.reminders, isEmpty);
    expect(override.reminderPolicy, ReminderPolicy.disabled);
  });

  test('实例编辑拒绝不属于当前 RRULE 的日期', () async {
    final repo = InMemoryRepository();
    final service = TaskService(repo);
    final task = await service.create(
      title: '每日任务',
      due: DueDate(first),
      rrule: 'FREQ=DAILY;COUNT=2',
    );

    await expectLater(
      service.editRecurring(
        task,
        scope: RecurrenceEditScope.occurrence,
        occurrence: DateTime.utc(2026, 1, 2, 10),
        title: '错误时间',
      ),
      throwsArgumentError,
    );
    await expectLater(
      service.editRecurring(
        task,
        scope: RecurrenceEditScope.thisAndFuture,
        occurrence: third,
        title: '超出 COUNT',
      ),
      throwsArgumentError,
    );
  });

  test('此次及以后拆分旧系列和新系列，并保留旧系列边界', () async {
    final repo = InMemoryRepository();
    final service = TaskService(repo);
    final task = await service.create(
      title: '每日站会',
      due: DueDate(first),
      rrule: 'FREQ=DAILY',
    );

    final result = await service.editRecurring(
      task,
      scope: RecurrenceEditScope.thisAndFuture,
      occurrence: third,
      title: '每日复盘',
      due: DueDate(DateTime.utc(2026, 1, 3, 18)),
      rrule: 'FREQ=DAILY',
    );

    expect(result.series.recurrenceUntil, second);
    expect(result.series.title, '每日站会');
    expect(result.newSeries, isNotNull);
    expect(result.newSeries!.title, '每日复盘');
    expect(result.newSeries!.due?.value, DateTime.utc(2026, 1, 3, 18));
    expect(result.newSeries!.seriesId, isNot(result.series.seriesId));
    expect((await repo.allTasks()).map((t) => t.id),
        containsAll([result.series.id, result.newSeries!.id]));
  });

  test('此次及以后拆分 COUNT 系列时只保留剩余次数', () async {
    final repo = InMemoryRepository();
    final service = TaskService(repo);
    final task = await service.create(
      title: '限次任务',
      due: DueDate(first),
      rrule: 'FREQ=DAILY;COUNT=5',
    );

    final result = await service.editRecurring(
      task,
      scope: RecurrenceEditScope.thisAndFuture,
      occurrence: third,
      title: '限次任务（新规则）',
      rrule: 'FREQ=DAILY;COUNT=5',
    );

    expect(result.newSeries!.rrule, contains('COUNT=3'));
  });

  test('拆分时按实例序号映射异常，而不是复制旧 occurrence key', () async {
    final repo = InMemoryRepository();
    final service = TaskService(repo);
    final task = await service.create(
      title: '每日打卡',
      due: DueDate(first),
      rrule: 'FREQ=DAILY',
    );
    final completed = await service.completeOccurrence(
      task,
      DateTime.utc(2026, 1, 4, 9),
      completed: true,
    );

    final result = await service.editRecurring(
      completed,
      scope: RecurrenceEditScope.thisAndFuture,
      occurrence: third,
      due: DueDate(DateTime.utc(2026, 1, 3, 18)),
      title: '每日打卡（晚间）',
    );

    expect(result.newSeries!.completedOccurrences,
        contains(occurrenceKey(DateTime.utc(2026, 1, 4, 18))));
    expect(result.newSeries!.completedOccurrences,
        isNot(contains(occurrenceKey(DateTime.utc(2026, 1, 4, 9)))));
  });

  test('拆分提交失败时旧系列不会先被截断', () async {
    final repo = FailingSnapshotRepository();
    final service = TaskService(repo);
    final task = await service.create(
      title: '原子拆分',
      due: DueDate(first),
      rrule: 'FREQ=DAILY',
    );

    await expectLater(
      service.editRecurring(
        task,
        scope: RecurrenceEditScope.thisAndFuture,
        occurrence: second,
        title: '不会提交',
      ),
      throwsStateError,
    );
    final stored = (await repo.allTasks()).single;
    expect(stored.id, task.id);
    expect(stored.recurrenceUntil, isNull);
    expect(stored.deleted, isFalse);
  });

  test('拆分后的旧段保留边界，whole-series 不会制造重叠', () async {
    final repo = InMemoryRepository();
    final service = TaskService(repo);
    final task = await service.create(
      title: '有边界的任务',
      due: DueDate(first),
      rrule: 'FREQ=DAILY',
    );
    final bounded = await service.edit(
      task,
      recurrenceUntil: third,
    );
    final split = await service.editRecurring(
      bounded,
      scope: RecurrenceEditScope.thisAndFuture,
      occurrence: second,
      title: '后半段',
    );

    expect(split.newSeries!.recurrenceUntil, third);
    final editedOld = await service.editRecurring(
      split.series,
      scope: RecurrenceEditScope.wholeSeries,
      title: '前半段已更新',
    );
    expect(editedOld.series.recurrenceUntil, first);
    expect((await repo.allTasks()).where((t) => !t.deleted), hasLength(2));
  });

  test('旧重复 JSON 缺少 seriesId 时使用稳定任务 id 迁移', () {
    final legacy = Task(
      id: 'legacy-series',
      title: '旧重复任务',
      due: DueDate(first),
      rrule: 'FREQ=DAILY',
      createdAt: first,
      updatedAt: first,
    ).toJson()
      ..remove('seriesId');

    expect(Task.fromJson(legacy).seriesId, 'legacy-series');
  });

  test('夏令时边界附近的仅日期截止时间保持 UTC 日历日', () {
    final due = DueDate(DateTime.utc(2026, 3, 29), dateOnly: true);
    final restored = DueDate.fromJson(due.toJson());
    expect(restored.dateOnly, isTrue);
    expect(restored.value, DateTime.utc(2026, 3, 29));
  });
}
