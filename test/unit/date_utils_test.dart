import 'package:flutter_test/flutter_test.dart';

class DateTimeUtils {
  /// Check if a date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Get the start of the day
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Check if a date is in the past
  static bool isPast(DateTime date) {
    final now = DateTime.now();
    return date.isBefore(now);
  }

  /// Format as a readable date string
  static String formatReadable(DateTime date) {
    List<String> months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Calculate difference in days between two dates
  static int daysBetween(DateTime from, DateTime to) {
    from = DateTime(from.year, from.month, from.day);
    to = DateTime(to.year, to.month, to.day);
    return (to.difference(from).inHours / 24).round();
  }
}

void main() {
  group('DateTimeUtils', () {
    test('startOfDay returns date with time set to midnight', () {
      final date = DateTime(2025, 5, 19, 14, 30, 45);
      final start = DateTimeUtils.startOfDay(date);

      expect(start.year, equals(2025));
      expect(start.month, equals(5));
      expect(start.day, equals(19));
      expect(start.hour, equals(0));
      expect(start.minute, equals(0));
      expect(start.second, equals(0));
      expect(start.millisecond, equals(0));
    });

    test('formatReadable returns correct format', () {
      final date = DateTime(2025, 5, 19);
      expect(DateTimeUtils.formatReadable(date), equals('May 19, 2025'));

      final anotherDate = DateTime(2023, 1, 1);
      expect(
        DateTimeUtils.formatReadable(anotherDate),
        equals('January 1, 2023'),
      );
    });

    test('daysBetween calculates correct number of days', () {
      final from = DateTime(2025, 5, 19);
      final to = DateTime(2025, 5, 25);

      expect(DateTimeUtils.daysBetween(from, to), equals(6));

      // Test reversed order (should be negative or zero depending on implementation)
      expect(DateTimeUtils.daysBetween(to, from), equals(-6));

      // Test same day
      expect(DateTimeUtils.daysBetween(from, from), equals(0));
    });
  });
}
