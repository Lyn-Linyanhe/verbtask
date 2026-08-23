import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:verb_app/app.dart';

void main() {
  test('runs one sync when the app returns after being backgrounded', () async {
    var calls = 0;
    final observer = AppLifecycleSyncObserver(
      onResumed: () async => calls++,
    );

    observer.didChangeAppLifecycleState(AppLifecycleState.paused);
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    expect(calls, 1);
  });

  test('does not start duplicate foreground syncs while one is running',
      () async {
    var release = false;
    var calls = 0;
    final observer = AppLifecycleSyncObserver(
      onResumed: () async {
        calls++;
        while (!release) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
      },
    );

    observer.didChangeAppLifecycleState(AppLifecycleState.paused);
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    observer.didChangeAppLifecycleState(AppLifecycleState.paused);
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    release = true;
    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(calls, 1);
  });
}
