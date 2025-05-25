import 'package:flutter_test/flutter_test.dart';
import 'package:HPGM/notifications/weather_model.dart';

void main() {
  group('WeatherData', () {
    test('should correctly initialize with all properties', () {
      final testDate = DateTime(2025, 5, 19);
      final weatherData = WeatherData(
        temperature: 25.0,
        humidity: 60.0,
        windSpeed: 10.0,
        condition: 'Sunny',
        timestamp: testDate,
      );

      expect(weatherData.temperature, equals(25.0));
      expect(weatherData.humidity, equals(60.0));
      expect(weatherData.windSpeed, equals(10.0));
      expect(weatherData.condition, equals('Sunny'));
      expect(weatherData.timestamp, equals(testDate));
    });

    test('should correctly convert to and from JSON', () {
      final testDate = DateTime(2025, 5, 19);
      final weatherData = WeatherData(
        temperature: 25.0,
        humidity: 60.0,
        windSpeed: 10.0,
        condition: 'Sunny',
        timestamp: testDate,
      );

      final json = weatherData.toJson();
      final fromJson = WeatherData.fromJson(json);

      expect(fromJson.temperature, equals(weatherData.temperature));
      expect(fromJson.humidity, equals(weatherData.humidity));
      expect(fromJson.windSpeed, equals(weatherData.windSpeed));
      expect(fromJson.condition, equals(weatherData.condition));
      expect(
        fromJson.timestamp.toIso8601String(),
        equals(weatherData.timestamp.toIso8601String()),
      );
    });
  });
}
