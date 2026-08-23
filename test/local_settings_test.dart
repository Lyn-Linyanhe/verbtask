import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/settings/local_settings.dart';

void main() {
  test('内存设置不会尝试写入磁盘', () async {
    final settings = LocalSettings.inMemory();
    settings.language = 'en';

    await settings.save();

    expect(settings.language, 'en');
  });

  test('默认值 + 读写持久化', () async {
    final dir = Directory.systemTemp.createTempSync('verb_set_');
    try {
      final f = File('${dir.path}/settings.json');
      final s = LocalSettings(f);
      expect(s.language, 'zh');
      expect(s.notifyDefaultReminderEnabled, isTrue);
      expect(s.notifyDefaultOffsetMin, -30);
      expect(s.themeMode, 'system');
      s.language = 'en';
      s.llmBaseUrl = 'https://example.com/v1';
      s.llmKey = 'k123';
      s.llmEnabled = 1;
      s.notifyDefaultReminderEnabled = false;
      s.notifyDefaultOffsetMin = -60;
      s.themeMode = 'dark';
      await s.save();

      final s2 = LocalSettings(f); // 重读
      expect(s2.language, 'en');
      expect(s2.llmBaseUrl, 'https://example.com/v1');
      expect(s2.llmKey, 'k123');
      expect(s2.llmEnabled, 1);
      expect(s2.notifyDefaultReminderEnabled, isFalse);
      expect(s2.notifyDefaultOffsetMin, -60);
      expect(s2.themeMode, 'dark');
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  test('默认提醒提前量始终按到期前语义归一为非正数', () {
    final dir = Directory.systemTemp.createTempSync('verb_settings_offset_');
    try {
      final settings = LocalSettings(File('${dir.path}/settings.json'));

      settings.notifyDefaultOffsetMin = 30;

      expect(settings.notifyDefaultOffsetMin, -30);
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
