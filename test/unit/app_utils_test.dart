import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:HPGM/utils/app_utils.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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
      expect(DateTimeUtils.daysBetween(to, from), equals(-6));
      expect(DateTimeUtils.daysBetween(from, from), equals(0));
    });

    test('formatAPIDate formats date correctly', () {
      final date = DateTime(2025, 5, 19);
      expect(DateTimeUtils.formatAPIDate(date), equals('2025-05-19'));
    });

    test('isPast correctly identifies past dates', () {
      final past = DateTime.now().subtract(Duration(days: 1));
      final future = DateTime.now().add(Duration(days: 1));

      expect(DateTimeUtils.isPast(past), isTrue);
      expect(DateTimeUtils.isPast(future), isFalse);
    });
  });

  group('StringUtils', () {
    test('capitalize returns correctly capitalized string', () {
      expect(StringUtils.capitalize('hello world'), equals('Hello World'));
      expect(StringUtils.capitalize('HELLO WORLD'), equals('Hello World'));
      expect(StringUtils.capitalize('hello WORLD'), equals('Hello World'));
      expect(StringUtils.capitalize(''), equals(''));
    });

    test('truncate correctly shortens strings', () {
      expect(
        StringUtils.truncate('This is a long text', 10),
        equals('This is a...'),
      );
      expect(StringUtils.truncate('Short', 10), equals('Short'));
      expect(StringUtils.truncate('', 10), equals(''));
    });

    test('removeSpecialChars removes special characters', () {
      expect(
        StringUtils.removeSpecialChars('Hello, World!'),
        equals('Hello World'),
      );
      expect(StringUtils.removeSpecialChars('abc123!@#'), equals('abc123'));
      expect(StringUtils.removeSpecialChars(''), equals(''));
    });

    test('shortenId correctly shortens IDs', () {
      expect(StringUtils.shortenId('1234567890', 5), equals('12345...'));
      expect(StringUtils.shortenId('12345', 8), equals('12345'));
    });
  });

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

    test('min finds minimum value', () {
      expect(MathUtils.min([1, 2, 3, 4, 5]), equals(1));
      expect(MathUtils.min([5, 4, 3, 2, 1]), equals(1));
      expect(MathUtils.min([-5, -10, -15]), equals(-15));
      expect(MathUtils.min([]), equals(0));
    });

    test('clamp restricts values to range', () {
      expect(MathUtils.clamp(5, 0, 10), equals(5));
      expect(MathUtils.clamp(-5, 0, 10), equals(0));
      expect(MathUtils.clamp(15, 0, 10), equals(10));
    });
  });

  group('ColorUtils', () {
    test('lighten creates correct color', () {
      Color black = Colors.black;
      Color lightenedBlack = ColorUtils.lighten(black, 50);
      expect(lightenedBlack.red, equals(128));
      expect(lightenedBlack.green, equals(128));
      expect(lightenedBlack.blue, equals(128));
    });

    test('darken creates correct color', () {
      Color white = Colors.white;
      Color darkenedWhite = ColorUtils.darken(white, 50);
      expect(darkenedWhite.red, equals(127));
      expect(darkenedWhite.green, equals(127));
      expect(darkenedWhite.blue, equals(127));
    });

    test('isDarkColor correctly identifies dark and light colors', () {
      expect(ColorUtils.isDarkColor(Colors.black), equals(true));
      expect(ColorUtils.isDarkColor(Colors.blue[900]!), equals(true));
      expect(ColorUtils.isDarkColor(Colors.white), equals(false));
      expect(ColorUtils.isDarkColor(Colors.yellow), equals(false));
    });

    test('contrastingTextColor returns appropriate color', () {
      expect(
        ColorUtils.contrastingTextColor(Colors.black),
        equals(Colors.white),
      );
      expect(
        ColorUtils.contrastingTextColor(Colors.white),
        equals(Colors.black),
      );
    });
  });

  group('FormatUtils', () {
    test('formatDate returns correct format', () {
      final date = DateTime(2025, 5, 19);
      expect(FormatUtils.formatDate(date), equals('19/5/2025'));
    });

    test('formatTemperature returns correct format', () {
      expect(FormatUtils.formatTemperature(25.0), equals('25.0°C'));
      expect(FormatUtils.formatTemperature(25.12), equals('25.1°C'));
    });

    test('formatPercentage returns correct format', () {
      expect(FormatUtils.formatPercentage(50.0), equals('50.0%'));
      expect(FormatUtils.formatPercentage(75.56), equals('75.6%'));
    });

    test('formatWeight returns correct format', () {
      expect(FormatUtils.formatWeight(10.5), equals('10.5 kg'));
      expect(FormatUtils.formatWeight(5.25, unit: 'lb'), equals('5.3 lb'));
    });

    test('formatDuration returns human-readable duration', () {
      expect(
        FormatUtils.formatDuration(Duration(days: 2, hours: 3)),
        equals('2d 3h'),
      );
      expect(
        FormatUtils.formatDuration(Duration(hours: 5, minutes: 30)),
        equals('5h 30m'),
      );
      expect(
        FormatUtils.formatDuration(Duration(minutes: 45, seconds: 20)),
        equals('45m 20s'),
      );
      expect(FormatUtils.formatDuration(Duration(seconds: 30)), equals('30s'));
    });
  });
}
