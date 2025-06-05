import 'package:flutter_test/flutter_test.dart';

class MathUtils {
  /// Calculates the average of a list of numbers
  static double average(List<num> numbers) {
    if (numbers.isEmpty) return 0;
    return numbers.reduce((a, b) => a + b) / numbers.length;
  }

  /// Rounds a double to a specified number of decimal places
  static double roundToDecimalPlaces(double value, int places) {
    double mod = pow(10.0, places).toDouble(); // Convert num to double
    return ((value * mod).round().toDouble() / mod);
  }

  /// Returns the maximum value in a list
  static num max(List<num> numbers) {
    if (numbers.isEmpty) return 0;
    return numbers.reduce((a, b) => a > b ? a : b);
  }

  /// Calculates power without using dart:math
  static num pow(num x, int exponent) {
    num result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= x;
    }
    return result;
  }
}

void main() {
  group('MathUtils', () {
    test('average calculates correctly', () {
      expect(MathUtils.average([1, 2, 3, 4, 5]), equals(3.0));
      expect(MathUtils.average([10]), equals(10.0));
      expect(MathUtils.average([]), equals(0.0));
    });

    test('roundToDecimalPlaces rounds correctly', () {
      expect(MathUtils.roundToDecimalPlaces(3.14159, 2), equals(3.14));
      expect(MathUtils.roundToDecimalPlaces(3.14559, 2), equals(3.15));
      expect(MathUtils.roundToDecimalPlaces(3.0, 2), equals(3.0));
    });

    test('max finds maximum value', () {
      expect(MathUtils.max([1, 2, 3, 4, 5]), equals(5));
      expect(MathUtils.max([5, 4, 3, 2, 1]), equals(5));
      expect(MathUtils.max([-5, -10, -15]), equals(-5));
      expect(MathUtils.max([]), equals(0));
    });

    test('pow calculates power correctly', () {
      expect(MathUtils.pow(2, 3), equals(8));
      expect(MathUtils.pow(10, 2), equals(100));
      expect(MathUtils.pow(5, 0), equals(1));
    });
  });
}
