import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/settings/local_settings.dart';
import 'package:verb_app/core/settings/settings_controller.dart';
import 'package:verb_app/core/storage/inmemory_repository.dart';

void main() {
  test('配对令牌：ensureSyncToken 生成并保留(幂等) + 持久化', () async {
    final dir = await Directory.systemTemp.createTemp('verb_tok_');
    addTearDown(() async {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    });
    final settings = LocalSettings(File('${dir.path}/s.json'));
    final controller = SettingsController(settings, InMemoryRepository());
    final t1 = controller.ensureSyncToken();
    await controller.flush();
    expect(t1, isNotEmpty);
    expect(controller.ensureSyncToken(), t1);
    final reread = LocalSettings(File('${dir.path}/s.json'));
    expect(reread.syncToken, t1);
  });
}
