

class WeatherData {
  final DateTime timestamp;
  final double temperature;
  final double humidity;
  final double windSpeed;
  final double rainfall;
  final double solarRadiation;
  
  WeatherData({
    required this.timestamp,
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    this.rainfall = 0.0,
    this.solarRadiation = 0.0,
  });
  
  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      timestamp: DateTime.parse(json['timestamp']),
      temperature: json['temperature'].toDouble(),
      humidity: json['humidity'].toDouble(),
      windSpeed: json['wind_speed'].toDouble(),
      rainfall: json['rainfall']?.toDouble() ?? 0.0,
      solarRadiation: json['solar_radiation']?.toDouble() ?? 0.0,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'temperature': temperature,
      'humidity': humidity,
      'wind_speed': windSpeed,
      'rainfall': rainfall,
      'solar_radiation': solarRadiation,
    };
  }
}

