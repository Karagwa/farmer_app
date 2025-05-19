import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherData {
  final double temperature;
  final double humidity;
  final double windSpeed;
  final String condition;
  final bool isRaining;
  final DateTime timestamp;

  WeatherData({
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.condition,
    required this.isRaining,
    required this.timestamp,
  });
}

class WeatherDataService {
  // Get mock weather data (for testing purposes)
  WeatherData getMockWeatherData() {
    return WeatherData(
      temperature: 25.5,
      humidity: 65.0,
      windSpeed: 12.0,
      condition: 'Partly cloudy',
      isRaining: false,
      timestamp: DateTime.now(),
    );
  }

  // Get real weather data (in a real implementation, this would call an API)
  Future<WeatherData> getWeatherData(double latitude, double longitude) async {
    // In a real implementation, this would call a weather API
    // For now, just return mock data
    return getMockWeatherData();
  }
}
