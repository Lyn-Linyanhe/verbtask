import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// Windows 窗口控制：置顶 + 悬浮速记模式的尺寸切换。
/// 仅在 Windows 上生效，其它平台静默降级，不抛错。
class WindowControl {
  static Size? _normalSize; // 正常模式窗口尺寸
  static const Size normalMinimumSize = Size(560, 400);
  static const Size miniSize = Size(420, 260);
  static const Size minMiniSize = Size(360, 220);

  static Future<void> ensure() async {
    if (!Platform.isWindows) return;
    try {
      await windowManager.ensureInitialized();
    } catch (_) {}
  }

  static Future<void> setAlwaysOnTop(bool on) async {
    if (!Platform.isWindows) return;
    try {
      await windowManager.setAlwaysOnTop(on);
    } catch (_) {}
  }

  static Future<void> setMinimumSize(Size size) async {
    if (!Platform.isWindows) return;
    try {
      await ensure();
      await windowManager.setMinimumSize(size);
    } catch (_) {}
  }

  /// 进入悬浮速记：记录正常尺寸，缩到小窗并置顶。
  static Future<void> enterMini() async {
    if (!Platform.isWindows) return;
    try {
      await ensure();
      _normalSize ??= await windowManager.getSize();
      await windowManager.setMinimumSize(minMiniSize);
      await windowManager.setSize(miniSize);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.focus();
    } catch (_) {}
  }

  /// 退出悬浮速记：恢复正常尺寸，按持久化设置恢复置顶状态。
  static Future<void> exitMini({required bool restoreAlwaysOnTop}) async {
    if (!Platform.isWindows) return;
    try {
      final size = _normalSize ?? const Size(900, 600);
      await windowManager.setMinimumSize(normalMinimumSize);
      await windowManager.setSize(size);
      await windowManager.setAlwaysOnTop(restoreAlwaysOnTop);
      await windowManager.center();
      _normalSize = null;
    } catch (_) {}
  }

  /// 纯函数形式暴露恢复策略，供回归测试锁定悬浮窗尺寸约束。
  static Size minimumSizeAfterMini(Size normalSize) => normalMinimumSize;

  /// 拖动窗口（供悬浮速记的把手使用）。
  static Future<void> startDragging() async {
    if (!Platform.isWindows) return;
    try {
      await windowManager.startDragging();
    } catch (_) {}
  }
}
