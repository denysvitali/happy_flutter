// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/main.dart';

void main() {
  testWidgets('Happy app renders without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const HappyApp());

    // Verify that the app renders (MaterialApp is present)
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
