import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/storage/app_paths.dart';

void main() {
  test(
      'migrates legacy data and fills missing settings without overwriting new values',
      () async {
    final root = await Directory.systemTemp.createTemp('verbtask-paths-');
    addTearDown(() => root.delete(recursive: true));

    final legacy = Directory(
        '${root.path}${Platform.pathSeparator}verb_app${Platform.pathSeparator}verb')
      ..createSync(recursive: true);
    final current = Directory(
        '${root.path}${Platform.pathSeparator}VerbTask${Platform.pathSeparator}verb')
      ..createSync(recursive: true);

    File('${legacy.path}${Platform.pathSeparator}verb_data.json')
        .writeAsStringSync(
      jsonEncode({
        'version': 1,
        'tasks': [
          {'id': 'legacy-task'}
        ]
      }),
    );
    File('${legacy.path}${Platform.pathSeparator}settings.json')
        .writeAsStringSync(
      jsonEncode({
        'syncToken': 'old-token',
        'llmBaseUrl': 'https://example.test/v1',
        'llmModel': 'old-model'
      }),
    );
    File('${current.path}${Platform.pathSeparator}settings.json')
        .writeAsStringSync(
      jsonEncode({'syncToken': 'new-token'}),
    );

    AppPaths.migrateLegacyFiles(current: current, legacy: legacy);

    final data = File('${current.path}${Platform.pathSeparator}verb_data.json');
    final settings = jsonDecode(
      File('${current.path}${Platform.pathSeparator}settings.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(data.existsSync(), isTrue);
    expect(jsonDecode(data.readAsStringSync())['tasks'], hasLength(1));
    expect(settings['syncToken'], 'new-token');
    expect(settings['llmBaseUrl'], 'https://example.test/v1');
    expect(settings['llmModel'], 'old-model');
  });

  test('does not overwrite an existing current data file during migration',
      () async {
    final root = await Directory.systemTemp.createTemp('verbtask-paths-');
    addTearDown(() => root.delete(recursive: true));

    final legacy = Directory('${root.path}${Platform.pathSeparator}legacy')
      ..createSync(recursive: true);
    final current = Directory('${root.path}${Platform.pathSeparator}current')
      ..createSync(recursive: true);
    File('${legacy.path}${Platform.pathSeparator}verb_data.json')
        .writeAsStringSync('legacy');
    File('${current.path}${Platform.pathSeparator}verb_data.json')
        .writeAsStringSync('current');

    AppPaths.migrateLegacyFiles(current: current, legacy: legacy);

    expect(
      File('${current.path}${Platform.pathSeparator}verb_data.json')
          .readAsStringSync(),
      'current',
    );
  });
}
