import 'package:flutter_test/flutter_test.dart';
import 'package:esp01_controller/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const Esp01App());

    // Verify that our scan screen is showing
    expect(find.text('Searching for ESP'), findsOneWidget);
  });
}
