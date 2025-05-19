import 'package:flutter_test/flutter_test.dart';

class StringUtils {
  /// Capitalizes the first letter of each word in a string
  static String capitalize(String text) {
    if (text.isEmpty) return '';

    return text.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
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
}

void main() {
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
  });
}
