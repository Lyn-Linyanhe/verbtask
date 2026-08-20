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

class _CloseToTray extends WindowListener {
  @override
  void onWindowClose() async {
    if (WindowsTray.enabled) {
      await windowManager.hide();
    }
  }
}

/// Windows 托盘常驻：读取 trayEnabled。启用→建托盘+关闭隐藏后台；
/// 关闭→销毁托盘+允许直接退出。异常兜底。
class WindowsTray {
  static bool _enabled = false;
  static bool _initialized = false;
  static WindowListener closeListener = _CloseToTray();

  static Future<void> init({required bool enabled}) async {
    if (!Platform.isWindows) return;
    try {
      await windowManager.ensureInitialized();
      final tray = TrayManager.instance;
      tray.addListener(_Tray());
      if (!_initialized) {
        windowManager.addListener(closeListener);
        _initialized = true;
      }
      await apply(enabled);
    } catch (_) {}
  }

  /// 切换托盘是否启用（创建/销毁托盘 + 是否拦截关闭）。
  static Future<void> apply(bool enabled) async {
    if (!Platform.isWindows) return;
    _enabled = enabled;
    try {
      await windowManager.setPreventClose(enabled);
      final tray = TrayManager.instance;
      await windowManager.setTitle('Verb Task');
      if (enabled) {
        await windowManager.show();
        await windowManager.focus();
        await tray.setContextMenu(Menu(items: [
          MenuItem(key: 'show', label: '显示'),
          MenuItem(key: 'quit', label: '退出'),
        ]));
      } else {
        await tray.destroy();
      }
    } catch (_) {}
  }

  static bool get enabled => _enabled;
}

