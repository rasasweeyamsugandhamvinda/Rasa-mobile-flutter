import 'package:flutter_test/flutter_test.dart';
import 'package:rasa_mobile_flutter/main.dart';

void main() {
  testWidgets('App loads and displays header', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RasaApp());

    // Verify that our new text is on the screen.
    expect(find.text('Describe the moment.'), findsOneWidget);
  });
}
