// test\widget_test.dart, do not remove this line!
//
// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Change this import to match your actual Dart package name (from pubspec.yaml)
// If your pubspec.yaml says `name: flutter_tasktracker`, use that:
import 'package:flutter_tasktracker/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Make sure the main.dart defines a widget named `MyTaskTrackerApp`.
    await tester.pumpWidget(const MyTaskTrackerApp());

    // Verify that our counter starts at 0 (if you have a counter in your app).
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
