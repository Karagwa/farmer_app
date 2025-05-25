import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:HPGM/notifications/weather_model.dart';

class WeatherDataService {
  // Get mock weather data (for testing purposes)
  WeatherData getMockWeatherData() {
    return WeatherData(
      temperature: 25.5,
      humidity: 65.0,
      windSpeed: 12.0,
      condition: 'Partly cloudy',
      timestamp: DateTime.now(),
    );
  }

  // Get real weather data
  Future<WeatherData> getWeatherData(double latitude, double longitude) async {
    // In a real implementation, this would call a weather API
    // For now, just return mock data
    return getMockWeatherData();
  }
}
