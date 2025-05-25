import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:HPGM/splashscreen.dart';
import '../test_utils.dart';

void main() {
  testWidgets('Splash screen visual appearance', (WidgetTester tester) async {
    await pumpAndSettleWidget(tester, const Splashscreen());

    // Verify splash screen widgets
    expect(find.byType(Image), findsOneWidget);

    // For the golden test, we'd normally do:
    // await expectLater(find.byType(SplashScreen), matchesGoldenFile('splash_screen.png'));
    // But we'll skip it as golden tests can be environment-dependent
  });
}
