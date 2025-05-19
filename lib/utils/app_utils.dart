import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Date and time utility functions
class DateTimeUtils {
  /// Check if a date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Get the start of the day (midnight)
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
    return to.difference(from).inDays;
  }

  /// Format date in standard API format (yyyy-MM-dd)
  static String formatAPIDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Format date and time for display
  static String formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// String manipulation utility functions
class StringUtils {
  /// Capitalizes the first letter of each word in a string
  static String capitalize(String text) {
    if (text.isEmpty) return '';

    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  /// Truncates a string to a maximum length and adds an ellipsis if needed
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Removes all special characters from a string
  static String removeSpecialChars(String text) {
    return text.replaceAll(RegExp(r'[^\w\s]+'), '');
  }

  /// Shortens an ID for display
  static String shortenId(String id, [int length = 8]) {
    if (id.length <= length) return id;
    return '${id.substring(0, length)}...';
  }
}

/// Mathematical utility functions
class MathUtils {
  /// Calculates the average of a list of numbers
  static double average(List<num> numbers) {
    if (numbers.isEmpty) return 0;
    return numbers.reduce((a, b) => a + b) / numbers.length;
  }

  /// Rounds a double to a specified number of decimal places
  static double roundToDecimalPlaces(double value, int places) {
    double mod = pow(10.0, places).toDouble();
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

  /// Returns the minimum value in a list
  static num min(List<num> numbers) {
    if (numbers.isEmpty) return 0;
    return numbers.reduce((a, b) => a < b ? a : b);
  }

  /// Clamps a value between min and max
  static num clamp(num value, num min, num max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}

/// Color manipulation utility functions
class ColorUtils {
  /// Lighten a color by a percentage (0-100)
  static Color lighten(Color color, int percentage) {
    assert(percentage >= 0 && percentage <= 100);

    int red = color.red;
    int green = color.green;
    int blue = color.blue;

    red = (red + ((255 - red) * percentage / 100)).round();
    green = (green + ((255 - green) * percentage / 100)).round();
    blue = (blue + ((255 - blue) * percentage / 100)).round();

    return Color.fromARGB(color.alpha, red, green, blue);
  }

  /// Darken a color by a percentage (0-100)
  static Color darken(Color color, int percentage) {
    assert(percentage >= 0 && percentage <= 100);

    int red = color.red;
    int green = color.green;
    int blue = color.blue;

    red = (red - (red * percentage / 100)).round();
    green = (green - (green * percentage / 100)).round();
    blue = (blue - (blue * percentage / 100)).round();

    return Color.fromARGB(color.alpha, red, green, blue);
  }

  /// Check if a color is dark or light
  static bool isDarkColor(Color color) {
    // Calculate perceived brightness using formula
    // (r * 299 + g * 587 + b * 114) / 1000
    int brightness =
        ((color.red * 299 + color.green * 587 + color.blue * 114) / 1000)
            .round();
    return brightness < 128;
  }

  /// Get a contrasting text color (black or white) based on background
  static Color contrastingTextColor(Color backgroundColor) {
    return isDarkColor(backgroundColor) ? Colors.white : Colors.black;
  }
}

/// Format utility functions
class FormatUtils {
  /// Format a date into a standard format
  static String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Format a temperature value with the correct unit
  static String formatTemperature(double temp) {
    return '${temp.toStringAsFixed(1)}°C';
  }

  /// Format a percentage value
  static String formatPercentage(double value) {
    return '${value.toStringAsFixed(1)}%';
  }

  /// Format a weight value with the correct unit
  static String formatWeight(double weight, {String unit = 'kg'}) {
    return '${weight.toStringAsFixed(1)} $unit';
  }

  /// Format a time duration in a human-readable way
  static String formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}
