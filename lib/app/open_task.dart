import 'package:flutter/material.dart';
import '../core/models/models.dart';
import '../core/services/task_service.dart';
import '../core/storage/repository.dart';
import '../ui/pages/task_edit_page.dart';

/// 按任务 id 打开编辑页（通知点击/全局入口复用）。找不到返回 false。
Future<bool> openTaskById(
  TaskRepository repo,
  String taskId, {
  GlobalKey<NavigatorState>? navigatorKey,
}) async {
  final svc = TaskService(repo);
  final all = await svc.query(includeDeleted: false);
  Task? task;
  for (final t in all) {
    if (t.id == taskId) {
      task = t;
      break;
    }
  }
  if (task == null) return false;
  final lists = await svc.allLists();
  final nav = navigatorKey?.currentState;
  if (nav == null) return false;
  nav.push(MaterialPageRoute(
      builder: (_) => TaskEditPage(task: task!, service: svc, lists: lists)));
  return true;
}
