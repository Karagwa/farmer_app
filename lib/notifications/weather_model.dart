class WeatherData {
  final double temperature;
  final double humidity;
  final double windSpeed;
  final String condition;
  final DateTime timestamp;

  // Computed property
  bool get isRaining => condition.toLowerCase().contains('rain');

  WeatherData({
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.condition,
    required this.timestamp,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      temperature: json['temperature'].toDouble(),
      humidity: json['humidity'].toDouble(),
      windSpeed: json['windSpeed'].toDouble(),
      condition: json['condition'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'windSpeed': windSpeed,
      'condition': condition,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
