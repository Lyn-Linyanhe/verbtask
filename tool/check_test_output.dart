import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.contains('--release-consistency')) {
    _checkReleaseConsistency();
  }

  final inputIndex = args.indexOf('--input');
  if (inputIndex >= 0 && inputIndex + 1 < args.length) {
    final output = File(args[inputIndex + 1]).readAsStringSync();
    _checkTestOutput(output);
  }
}

void _checkTestOutput(String output) {
  final lower = output.toLowerCase();
  final forbidden = <String>[
    'renderflex overflowed',
    'exception caught by flutter test framework',
    'unhandled exception',
    'failed to load',
    'hit-test warning',
    'warningifmissed',
  ];
  final failures = forbidden.where(lower.contains).toList();
  if (failures.isNotEmpty) {
    stderr.writeln(
        'Test output contains forbidden diagnostics: ${failures.join(', ')}');
    exitCode = 1;
  }
}

void _checkReleaseConsistency() {
  final root = Directory.current;
  String read(String path) =>
      File('${root.path}${Platform.pathSeparator}$path').readAsStringSync();

  final pubspec = read('pubspec.yaml');
  final packageVersion =
      RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)', multiLine: true)
          .firstMatch(pubspec)
          ?.group(1);
  final installerVersion = RegExp(r'#define MyAppVersion "([^"]+)"')
      .firstMatch(read('installer/verb_task.iss'))
      ?.group(1);
  final errors = <String>[];
  if (packageVersion == null || installerVersion != packageVersion) {
    errors.add(
        'pubspec version ($packageVersion) != installer version ($installerVersion)');
  }

  final cmake = read('windows/CMakeLists.txt');
  final installer = read('installer/verb_task.iss');
  final runner = read('windows/runner/Runner.rc');
  final manifest = read('android/app/src/main/AndroidManifest.xml');
  if (!cmake.contains('set(BINARY_NAME "verb_task")') ||
      !installer.contains('#define MyAppExeName "verb_task.exe"') ||
      !runner.contains('OriginalFilename", "verb_task.exe"') ||
      !manifest.contains('android:label="VerbTask"')) {
    errors.add('brand or executable metadata is inconsistent');
  }
  if (!File('${root.path}${Platform.pathSeparator}CHANGELOG.md')
      .readAsStringSync()
      .contains(packageVersion ?? '')) {
    errors.add('CHANGELOG.md does not mention the package version');
  }
  if (errors.isNotEmpty) {
    stderr
        .writeAll(errors.map((error) => 'Release consistency error: $error\n'));
    exitCode = 1;
  }
}
