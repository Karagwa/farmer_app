import 'package:flutter/foundation.dart';
import 'dart:math' as math;

/// Represents efficiency metrics for bee foraging during a specific time period
class ForagingEfficiencyMetric {
  /// The date of the foraging activity
  final DateTime date;

  /// Total number of bees returning to the hive
  final int totalBeesIn;

  /// Total number of bees leaving the hive
  final int totalBeesOut;

  /// Net change in colony population (in - out)
  final int netChange;

  /// Total foraging activity (in + out)
  final int totalActivity;

  /// Average temperature during the period (°C)
  final double temperature;

  /// Average humidity during the period (%)
  final double humidity;

  /// Average wind speed during the period (m/s)
  final double windSpeed;

  /// Overall foraging efficiency score
  /// Higher values indicate better foraging conditions
  final double efficiencyScore;

  final  peakTimePeriod;

  final  returnRate;

  /// Creates a new foraging efficiency metric
  ForagingEfficiencyMetric({
    required this.date,
    required this.totalBeesIn,
    required this.totalBeesOut,
    required this.netChange,
    required this.totalActivity,
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.efficiencyScore,
    required this.peakTimePeriod,
    required this.returnRate,
  });

  /// Convert this metric to a JSON object for storage
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'totalBeesIn': totalBeesIn,
      'totalBeesOut': totalBeesOut,
      'netChange': netChange,
      'totalActivity': totalActivity,
      'temperature': temperature,
      'humidity': humidity,
      'windSpeed': windSpeed,
      'efficiencyScore': efficiencyScore,
    };
  }

  /// Create a metric from a JSON object
  factory ForagingEfficiencyMetric.fromJson(Map<String, dynamic> json) {
    return ForagingEfficiencyMetric(
      date: DateTime.parse(json['date']),
      totalBeesIn: json['totalBeesIn'],
      totalBeesOut: json['totalBeesOut'],
      netChange: json['netChange'],
      totalActivity: json['totalActivity'],
      temperature: json['temperature'],
      humidity: json['humidity'],
      windSpeed: json['windSpeed'],
      efficiencyScore: json['efficiencyScore'],
      peakTimePeriod:json['peakTimePeriod'],
      returnRate:json['returnRate']
    );
  }

  /// Create a copy of this metric with some values replaced
  ForagingEfficiencyMetric copyWith({
    DateTime? date,
    int? totalBeesIn,
    int? totalBeesOut,
    int? netChange,
    int? totalActivity,
    double? temperature,
    double? humidity,
    double? windSpeed,
    double? efficiencyScore,
  }) {
    return ForagingEfficiencyMetric(
      date: date ?? this.date,
      totalBeesIn: totalBeesIn ?? this.totalBeesIn,
      totalBeesOut: totalBeesOut ?? this.totalBeesOut,
      netChange: netChange ?? this.netChange,
      totalActivity: totalActivity ?? this.totalActivity,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      windSpeed: windSpeed ?? this.windSpeed,
      efficiencyScore: efficiencyScore ?? this.efficiencyScore,
      peakTimePeriod:peakTimePeriod ,
      returnRate:returnRate
    );
  }

  @override
  String toString() {
    return 'ForagingEfficiencyMetric('
        'date: $date, '
        'in: $totalBeesIn, '
        'out: $totalBeesOut, '
        'net: $netChange, '
        'activity: $totalActivity, '
        'temp: ${temperature.toStringAsFixed(1)}°C, '
        'efficiency: ${efficiencyScore.toStringAsFixed(1)})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ForagingEfficiencyMetric &&
        other.date.isAtSameMomentAs(date) &&
        other.totalBeesIn == totalBeesIn &&
        other.totalBeesOut == totalBeesOut &&
        other.temperature == temperature &&
        other.efficiencyScore == efficiencyScore;
  }

  @override
  int get hashCode =>
      date.hashCode ^ totalBeesIn.hashCode ^ totalBeesOut.hashCode;
}

/// Helper class for calculating foraging efficiency metrics
class ForagingEfficiencyCalculator {
  /// Calculate efficiency score based on various factors
  ///
  /// The formula considers:
  /// - Total activity (higher is better)
  /// - Net change (positive is better)
  /// - Temperature (closer to optimal temperature is better)
  /// - Wind speed (lower is better)
  /// - Time of day (factoring in optimal foraging times)
  static double calculateEfficiencyScore({
    required int totalBeesIn,
    required int totalBeesOut,
    required double temperature,
    required double windSpeed,
    required DateTime timestamp,
    double optimalTemperature = 25.0, // °C
    double maxWindThreshold = 6.0, // m/s
  }) {
    final totalActivity = totalBeesIn + totalBeesOut;
    final netChange = totalBeesIn - totalBeesOut;

    // Base score is total activity
    double score = totalActivity.toDouble();

    // Apply modifiers

    // 1. Net change modifier: boost score for positive net change
    final netChangeFactor =
        netChange >= 0
            ? 1.0 +
                (netChange / max(totalActivity.toDouble(), 1)) *
                    0.2 // Bonus up to 20%
            : 1.0 -
                min(
                  abs(netChange.toDouble()) / max(totalActivity.toDouble(), 1),
                  0.3,
                ); // Penalty up to 30%

    // 2. Temperature modifier: optimal is 100%, decreases as temp deviates
    final tempDelta = (temperature - optimalTemperature).abs();
    final tempFactor = 1.0 - min(tempDelta / 15.0, 0.5); // Penalty up to 50%

    // 3. Wind speed modifier: lower is better
    final windFactor = max(0.5, 1.0 - (windSpeed / maxWindThreshold));

    // 4. Time of day modifier: optimal times get bonuses
    final hour = timestamp.hour;
    double timeFactor = 1.0;

    // Early morning (5-10 AM) and late afternoon (3-6 PM) are typically optimal
    if ((hour >= 5 && hour <= 10) || (hour >= 15 && hour <= 18)) {
      timeFactor = 1.15; // 15% bonus
    } else if (hour < 5 || hour > 19) {
      timeFactor = 0.8; // 20% penalty for non-foraging hours
    }

    // Apply all factors
    score = score * netChangeFactor * tempFactor * windFactor * timeFactor;

    // Normalize to a common scale (0-100)
    score = min(max(score / 5.0, 0.0), 100.0);

    return score;
  }

  /// Utility function to get the absolute value
  static double abs(double value) => value < 0 ? -value : value;

  /// Utility function to get the maximum of two values
  static double max(double a, double b) => a > b ? a : b;

  /// Utility function to get the minimum of two values
  static double min(double a, double b) => a < b ? a : b;
}
