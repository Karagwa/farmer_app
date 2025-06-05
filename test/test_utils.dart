import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps a widget with MaterialApp for testing
Widget testableWidget({required Widget child}) {
  return MaterialApp(home: Scaffold(body: child));
}

/// Utility function to pump a widget and wait for all animations to complete
Future<void> pumpAndSettleWidget(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(testableWidget(child: widget));
  await tester.pumpAndSettle();
}
