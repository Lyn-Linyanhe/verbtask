import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:verb_app/app/window_control.dart';

void main() {
  test('leaving mini mode restores the normal minimum, not the current size',
      () {
    expect(
      WindowControl.minimumSizeAfterMini(const Size(900, 600)),
      const Size(560, 400),
    );
  });
}
