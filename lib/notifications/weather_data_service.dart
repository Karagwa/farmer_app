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

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'wind_speed': windSpeed,
      'condition': condition,
      'is_raining': isRaining,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      temperature: json['temperature'],
      humidity: json['humidity'],
      windSpeed: json['wind_speed'],
      condition: json['condition'],
      isRaining: json['is_raining'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  // Replace with your actual weather API key and endpoint
  final String _apiKey = 'YOUR_WEATHER_API_KEY';
  final String _baseUrl = 'https://api.weatherapi.com/v1/current.json';

  Future<WeatherData> getWeatherData(double latitude, double longitude) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?key=$_apiKey&q=$latitude,$longitude&aqi=no'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current'];
        
        return WeatherData(
          temperature: current['temp_c'].toDouble(),
          humidity: current['humidity'].toDouble(),
          windSpeed: current['wind_kph'].toDouble(),
          condition: current['condition']['text'],
          isRaining: current['condition']['text'].toString().toLowerCase().contains('rain'),
          timestamp: DateTime.now(),
        );
      } else {
        throw Exception('Failed to load weather data');
      }
    } catch (e) {
      // For demo purposes, return mock data if API call fails
      return _getMockWeatherData();
    }
  }

  // Mock data for testing or when API is unavailable
  WeatherData _getMockWeatherData() {
    return WeatherData(
      temperature: 25.5,
      humidity: 65.0,
      windSpeed: 12.0,
      condition: 'Partly cloudy',
      isRaining: false,
      timestamp: DateTime.now(),
    );
  }
}