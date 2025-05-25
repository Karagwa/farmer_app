import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:HPGM/main.dart';

void main() {
  testWidgets('App can be created', (WidgetTester tester) async {
    // Just verify the app can be instantiated
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
