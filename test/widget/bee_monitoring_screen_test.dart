import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:HPGM/bee_counter/bee_monitoring_screen.dart';
import 'package:mockito/mockito.dart';

void main() {
  testWidgets('BeeMonitoringScreen shows correct initial state', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(
      MaterialApp(
        home: BeeMonitoringScreen(
          hiveId: 'test_hive_1',
          // Remove hiveName parameter if it's not accepted by your BeeMonitoringScreen
        ),
      ),
    );

    // Verify that monitoring related widget is present
    expect(find.byType(BeeMonitoringScreen), findsOneWidget);

    // Add more specific expectations based on your actual UI
  });
}
