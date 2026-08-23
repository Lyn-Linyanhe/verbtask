import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/core/async/serial_future_queue.dart';

void main() {
  test('串行队列会等待前一个异步操作完成后再开始下一个', () async {
    final queue = SerialFutureQueue();
    final firstRelease = Completer<void>();
    final events = <String>[];

    final Future<void> first = queue.add<void>(() async {
      events.add('first-start');
      await firstRelease.future;
      events.add('first-end');
    });
    final Future<void> second = queue.add<void>(() async {
      events.add('second');
    });

    await Future<void>.delayed(Duration.zero);
    expect(events, ['first-start']);

    firstRelease.complete();
    await Future.wait([first, second]);

    expect(events, ['first-start', 'first-end', 'second']);
  });
}
