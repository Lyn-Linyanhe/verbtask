import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/app/autostart.dart';

void main() {
  test('开机自启注册表命令会引用含空格的可执行文件路径', () {
    expect(
      Autostart.commandForExecutable(
          r'C:\Program Files\VerbTask\verb_task.exe'),
      r'"C:\Program Files\VerbTask\verb_task.exe"',
    );
  });

  test('only a zero reg exit code counts as a successful change', () {
    expect(Autostart.commandSucceeded(ProcessResult(1, 0, '', '')), isTrue);
    expect(
        Autostart.commandSucceeded(ProcessResult(1, 2, '', 'error')), isFalse);
    expect(Autostart.commandSucceeded(ProcessResult(1, 0, 'ok', '')), isTrue);
  });
}
