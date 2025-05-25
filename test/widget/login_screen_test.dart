import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:HPGM/login.dart';
import '../test_utils.dart';

void main() {
  testWidgets('Login screen has expected UI elements', (
    WidgetTester tester,
  ) async {
    await pumpAndSettleWidget(tester, const LoginScreen());

    // Find text fields
    expect(find.byType(TextFormField), findsAtLeast(1));

    // Find login button
    expect(find.widgetWithText(ElevatedButton, 'LOGIN'), findsOneWidget);

    // Find forgot password button
    expect(find.text('Forgot Password?'), findsOneWidget);
  });
}
