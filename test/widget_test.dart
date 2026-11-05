import 'package:events_app_trueattempt/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App starts correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(
          enableAlertNotifications: false,
          splashDuration: Duration.zero,
        ),
      ),
    );

    await tester.pump(); // Runs the zero-duration splash timer.
    await tester.pump(const Duration(seconds: 1)); // Completes splash timers.

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}