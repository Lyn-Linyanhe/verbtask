import 'package:flutter/material.dart';
import '../core/models/models.dart';
import '../core/services/task_service.dart';
import '../core/storage/repository.dart';
import '../ui/pages/task_edit_page.dart';

String? _pendingTaskOpen;

/// 按任务 id 打开编辑页（通知点击/全局入口复用）。找不到返回 false。
Future<bool> openTaskById(
  TaskRepository repo,
  String taskId, {
  GlobalKey<NavigatorState>? navigatorKey,
  Future<void> Function()? onChanged,
}) async {
  final svc = TaskService(repo, onChanged: onChanged);
  final all = await svc.query(includeDeleted: false);
  Task? task;
  final payloadParts = taskId.split('|');
  final rawTaskId = payloadParts.first;
  final occurrence = payloadParts.length > 1
      ? DateTime.tryParse(payloadParts[1])?.toUtc()
      : null;
  final baseTaskId = rawTaskId;
  for (final t in all) {
    // 新版通知 payload 只保存任务 ID；同时兼容旧版的
    // "taskId-timestamp" payload，避免升级后点击旧通知完全无响应。
    if (t.id == baseTaskId ||
        baseTaskId.startsWith('${t.id}-') ||
        taskId.startsWith('${t.id}|')) {
      task = t;
      break;
    }
  }
  if (task == null) return false;
  final lists = await svc.allLists();
  final nav = navigatorKey?.currentState;
  if (nav == null) {
    // Android 冷启动通知回调可能早于 MaterialApp/Navigator 建立；保留
    // 最新一次点击，首帧后由 flushPendingTaskOpen 再尝试打开。
    _pendingTaskOpen = taskId;
    return false;
  }
  nav.push(MaterialPageRoute(
      builder: (_) => TaskEditPage(
            task: task!,
            service: svc,
            lists: lists,
            occurrence: occurrence,
          )));
  return true;
}

/// 在应用首帧建立导航树后重试冷启动通知点击。
Future<bool> flushPendingTaskOpen(
  TaskRepository repo, {
  GlobalKey<NavigatorState>? navigatorKey,
  Future<void> Function()? onChanged,
}) async {
  final taskId = _pendingTaskOpen;
  if (taskId == null) return false;
  final opened = await openTaskById(
    repo,
    taskId,
    navigatorKey: navigatorKey,
    onChanged: onChanged,
  );
  if (opened && identical(_pendingTaskOpen, taskId)) {
    _pendingTaskOpen = null;
  }
  return opened;
}
