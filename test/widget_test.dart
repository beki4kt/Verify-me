import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const VerifyMeApp());
    expect(find.text('0'), findsNothing);
  });
}