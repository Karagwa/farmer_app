import 'package:flutter_test/flutter_test.dart';

class FormatUtils {
  static String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  static String formatTemperature(double temp) {
    return '${temp.toStringAsFixed(1)}°C';
  }
}

void main() {
  group('FormatUtils', () {
    test('formatDate returns correct format', () {
      final date = DateTime(2025, 5, 19);
      expect(FormatUtils.formatDate(date), equals('19/5/2025'));
    });

    test('formatTemperature returns correct format', () {
      expect(FormatUtils.formatTemperature(25.0), equals('25.0°C'));
      expect(FormatUtils.formatTemperature(25.12), equals('25.1°C'));
    });
  });
}
