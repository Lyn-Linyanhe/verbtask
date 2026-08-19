import 'package:flutter_test/flutter_test.dart';
import 'package:verb_app/main.dart';

void main() {
  testWidgets('renders home', (tester) async {
    await tester.pumpWidget(const VerbApp());
    expect(find.text('Verb Task'), findsWidgets);
  });
}
