import 'dart:io';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class _Tray extends TrayListener {
  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'quit') {
      exit(0);
    } else if (menuItem.key == 'show') {
      windowManager.show();
      windowManager.focus();
    }
  }
}

/// Windows 托盘常驻：点关闭→后台，托盘菜单 显示/退出。仅 Windows，异常兜底不崩溃。
class WindowsTray {
  static bool _done = false;

  static Future<void> init() async {
    if (_done || !Platform.isWindows) return;
    _done = true;
    try {
      await windowManager.ensureInitialized();
      await windowManager.setPreventClose(true);
      windowManager.addListener(_CloseToTray());
      // 启动时把窗口显示并拉回前台，避免“双击后看起来没反应”。
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setTitle('Verb Task');
      final tray = TrayManager.instance;
      tray.addListener(_Tray());
      await tray.setContextMenu(Menu(items: [
        MenuItem(key: 'show', label: '显示'),
        MenuItem(key: 'quit', label: '退出'),
      ]));
    } catch (_) {
      // 平台能力不可用时静默降级
    }
  }
}

/// 关闭窗口时隐藏到托盘（真正退出走托盘菜单）。
class _CloseToTray extends WindowListener {
  @override
  void onWindowClose() async {
    await windowManager.hide();
  }
}
