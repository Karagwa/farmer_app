// File: lib/bee_counter/bee_activity_visualization.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:farmer_app/bee_counter/bee_counter_model.dart';
import 'package:farmer_app/bee_counter/weatherdata.dart';
import 'package:farmer_app/hive_model.dart';

/// A class to generate visualizations of bee activity correlated with environmental factors
class BeeActivityVisualization {
  /// Generate a chart showing bee activity over time
  static Widget buildActivityTimelineChart(
    List<BeeCount> beeCounts, {
    required BuildContext context,
    bool showLegend = true,
    bool showEnteringBees = true,
    bool showExitingBees = true,
  }) {
    if (beeCounts.isEmpty) {
      return _buildNoDataWidget('No bee activity data available');
    }

    // Sort counts by timestamp
    final sortedCounts = List<BeeCount>.from(beeCounts)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Group by hour to avoid overcrowding
    final Map<DateTime, BeeCount> hourlyData = {};

    for (final count in sortedCounts) {
      final hour = DateTime(
        count.timestamp.year,
        count.timestamp.month,
        count.timestamp.day,
        count.timestamp.hour,
      );

      if (!hourlyData.containsKey(hour)) {
        hourlyData[hour] = BeeCount(
          hiveId: count.hiveId,
          beesEntering: 0,
          beesExiting: 0,
          timestamp: hour,
        );
      }

      final existing = hourlyData[hour]!;
      hourlyData[hour] = BeeCount(
        hiveId: existing.hiveId,
        videoId: existing.videoId,
        beesEntering: existing.beesEntering + count.beesEntering,
        beesExiting: existing.beesExiting + count.beesExiting,
        timestamp: existing.timestamp,
      );
    }

    // Convert to sorted list
    final List<MapEntry<DateTime, BeeCount>> sortedHourlyData =
        hourlyData.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    // Prepare data for the chart
    final enteringSpots = <FlSpot>[];
    final exitingSpots = <FlSpot>[];

    for (int i = 0; i < sortedHourlyData.length; i++) {
      final count = sortedHourlyData[i].value;
      enteringSpots.add(FlSpot(i.toDouble(), count.beesEntering.toDouble()));
      exitingSpots.add(FlSpot(i.toDouble(), count.beesExiting.toDouble()));
    }

    // Find max Y value for the chart
    double maxY = 0;
    for (final count in hourlyData.values) {
      if (count.beesEntering > maxY) maxY = count.beesEntering.toDouble();
      if (count.beesExiting > maxY) maxY = count.beesExiting.toDouble();
    }
    maxY = (maxY * 1.2).ceilToDouble();
    if (maxY < 10) maxY = 10;

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.2),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 &&
                      value.toInt() < sortedHourlyData.length &&
                      value.toInt() % (sortedHourlyData.length ~/ 5 + 1) == 0) {
                    final timestamp = sortedHourlyData[value.toInt()].key;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('HH:mm').format(timestamp),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          minX: 0,
          maxX: sortedHourlyData.length - 1,
          minY: 0,
          maxY: maxY,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  if (index >= 0 && index < sortedHourlyData.length) {
                    final timestamp = sortedHourlyData[index].key;
                    final activity = spot.y.toInt();
                    final isEntering = spot.barIndex == 0;

                    return LineTooltipItem(
                      '${DateFormat('yyyy-MM-dd HH:mm').format(timestamp)}\n'
                      '${isEntering ? 'Entering' : 'Exiting'}: $activity bees',
                      TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }
                  return null;
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            if (showEnteringBees)
              LineChartBarData(
                spots: enteringSpots,
                isCurved: true,
                color: Colors.green,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.green.withOpacity(0.2),
                ),
              ),
            if (showExitingBees)
              LineChartBarData(
                spots: exitingSpots,
                isCurved: true,
                color: Colors.orange,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.orange.withOpacity(0.2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Generate a chart showing bee activity correlated with temperature
  static Widget buildTemperatureCorrelationChart(
    List<BeeCount> beeCounts,
    Map<DateTime, WeatherData> weatherData, {
    required BuildContext context,
    bool showTrendline = true,
  }) {
    if (beeCounts.isEmpty || weatherData.isEmpty) {
      return _buildNoDataWidget('No weather correlation data available');
    }

    // Prepare data by matching bee counts with nearest weather data point
    final List<ScatterSpot> spots = [];
    final Map<double, List<int>> tempBasedActivity = {};

    for (final count in beeCounts) {
      // Find the closest weather data point
      WeatherData? nearestWeather;
      Duration smallestDiff = const Duration(days: 1);

      for (final entry in weatherData.entries) {
        final diff = (entry.key.difference(count.timestamp)).abs();
        if (diff < smallestDiff) {
          smallestDiff = diff;
          nearestWeather = entry.value;
        }
      }

      // Only use if we found a weather point within a reasonable timeframe (4 hours)
      if (nearestWeather != null && smallestDiff.inHours < 4) {
        // Round temperature to nearest 0.5°C for grouping
        final temp = (nearestWeather.temperature * 2).round() / 2;

        // Add to spots for scatter chart
        spots.add(
          ScatterSpot(
            temp,
            (count.beesEntering + count.beesExiting).toDouble(),
            dotPainter: FlDotCirclePainter(
              color: Colors.blue,
              strokeWidth: 1,
              strokeColor: Colors.blue.shade800,
            ),
          ),
        );

        // Group by temperature for trend line
        if (!tempBasedActivity.containsKey(temp)) {
          tempBasedActivity[temp] = [];
        }
        tempBasedActivity[temp]!.add(count.beesEntering + count.beesExiting);
      }
    }

    if (spots.isEmpty) {
      return _buildNoDataWidget(
          'No matching weather and bee activity data found');
    }

    // Calculate min/max values for chart
    double minTemp = double.infinity;
    double maxTemp = -double.infinity;
    double maxActivity = 0;

    for (final spot in spots) {
      if (spot.x < minTemp) minTemp = spot.x;
      if (spot.x > maxTemp) maxTemp = spot.x;
      if (spot.y > maxActivity) maxActivity = spot.y;
    }

    // Add some padding
    minTemp = (minTemp - 2).floorToDouble();
    maxTemp = (maxTemp + 2).ceilToDouble();
    maxActivity = (maxActivity * 1.1).ceilToDouble();

    // Calculate trend line points if enabled
    List<FlSpot> trendPoints = [];
    if (showTrendline) {
      // Sort temperature points
      final sortedTemps = tempBasedActivity.keys.toList()..sort();

      for (final temp in sortedTemps) {
        final activities = tempBasedActivity[temp]!;
        if (activities.isNotEmpty) {
          final avgActivity =
              activities.reduce((a, b) => a + b) / activities.length;
          trendPoints.add(FlSpot(temp, avgActivity));
        }
      }

      // Sort trend points by temperature
      trendPoints.sort((a, b) => a.x.compareTo(b.x));
    }

    return SizedBox(
      height: 300,
      child: ScatterChart(
        ScatterChartData(
          scatterSpots: spots,
          minX: minTemp,
          maxX: maxTemp,
          minY: 0,
          maxY: maxActivity,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              axisNameWidget: const Text(
                'Temperature (°C)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              axisNameSize: 25,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(1),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: const Text(
                'Bee Activity',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              axisNameSize: 25,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            checkToShowHorizontalLine: (value) => true,
            checkToShowVerticalLine: (value) => true,
            drawVerticalLine: true,
            drawHorizontalLine: true,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
            getDrawingVerticalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
          ),
          scatterTouchData: ScatterTouchData(
            touchTooltipData: ScatterTouchTooltipData(
              tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
              getTooltipItems: (touchedSpot) {
                return ScatterTooltipItem(
                  'Temperature: ${touchedSpot.x.toStringAsFixed(1)}°C\n'
                  'Bee Activity: ${touchedSpot.y.toInt()}',
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
        ),
        swapAnimationDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  /// Generate a chart showing bee activity by time of day
  static Widget buildTimeOfDayActivityChart(
    List<BeeCount> beeCounts, {
    required BuildContext context,
  }) {
    if (beeCounts.isEmpty) {
      return _buildNoDataWidget('No bee activity data available');
    }

    // Group activity by hour of day
    final Map<int, List<int>> hourlyActivities = {};
    for (int i = 0; i < 24; i++) {
      hourlyActivities[i] = [];
    }

    for (final count in beeCounts) {
      final hour = count.timestamp.hour;
      hourlyActivities[hour]!.add(count.beesEntering + count.beesExiting);
    }

    // Calculate average activity by hour
    final List<BarChartGroupData> barGroups = [];

    for (int hour = 0; hour < 24; hour++) {
      final activities = hourlyActivities[hour]!;
      final double avgActivity = activities.isNotEmpty
          ? activities.reduce((a, b) => a + b) / activities.length
          : 0.0;

      final timeString = '$hour:00';

      // Determine color based on time of day
      Color barColor;
      if (hour >= 6 && hour < 12) {
        barColor = Colors.amber; // Morning
      } else if (hour >= 12 && hour < 18) {
        barColor = Colors.orange; // Afternoon
      } else {
        barColor = Colors.indigo; // Evening/Night
      }

      barGroups.add(
        BarChartGroupData(
          x: hour,
          barRods: [
            BarChartRodData(
              toY: avgActivity,
              color: barColor,
              width: 12,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    // Find max Y for scaling
    double maxY = 0;
    for (final group in barGroups) {
      if (group.barRods.first.toY > maxY) {
        maxY = group.barRods.first.toY;
      }
    }
    maxY = (maxY * 1.2).ceilToDouble();
    if (maxY < 10) maxY = 10;

    return SizedBox(
      height: 300,
      child: Padding(
        padding: const EdgeInsets.only(top: 20, right: 20),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                tooltipBgColor: Colors.blueGrey,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final time = '${group.x}:00';
                  return BarTooltipItem(
                    'Time: $time\n${rod.toY.toStringAsFixed(1)} bees on average',
                    const TextStyle(color: Colors.white),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                axisNameWidget: const Text(
                  'Time of Day',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                axisNameSize: 25,
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    if (value.toInt() % 4 == 0) {
                      return Text(
                        '${value.toInt()}:00',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              leftTitles: AxisTitles(
                axisNameWidget: const Text(
                  'Average Bee Activity',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                axisNameSize: 25,
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              horizontalInterval: maxY / 5,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey.withOpacity(0.2),
                  strokeWidth: 1,
                );
              },
              drawVerticalLine: false,
            ),
            borderData: FlBorderData(show: false),
            barGroups: barGroups,
          ),
        ),
      ),
    );
  }

  /// Generate a chart showing bee activity correlated with humidity
  static Widget buildHumidityCorrelationChart(
    List<BeeCount> beeCounts,
    Map<DateTime, WeatherData> weatherData, {
    required BuildContext context,
    bool showTrendline = true,
  }) {
    if (beeCounts.isEmpty || weatherData.isEmpty) {
      return _buildNoDataWidget('No humidity correlation data available');
    }

    // Prepare data by matching bee counts with nearest weather data point
    final List<ScatterSpot> spots = [];
    final Map<int, List<int>> humidityBasedActivity = {};

    for (final count in beeCounts) {
      // Find the closest weather data point
      WeatherData? nearestWeather;
      Duration smallestDiff = const Duration(days: 1);

      for (final entry in weatherData.entries) {
        final diff = (entry.key.difference(count.timestamp)).abs();
        if (diff < smallestDiff) {
          smallestDiff = diff;
          nearestWeather = entry.value;
        }
      }

      // Only use if we found a weather point within a reasonable timeframe (4 hours)
      if (nearestWeather != null && smallestDiff.inHours < 4) {
        // Round humidity to nearest 5% for grouping
        final humidity = (nearestWeather.humidity / 5).round() * 5;

        // Add to spots for scatter chart
        spots.add(
          ScatterSpot(
            humidity.toDouble(),
            (count.beesEntering + count.beesExiting).toDouble(),
            dotPainter: FlDotCirclePainter(
              color: Colors.teal,
              strokeWidth: 1,
              strokeColor: Colors.teal.shade800,
            ),
          ),
        );

        // Group by humidity for trend line
        if (!humidityBasedActivity.containsKey(humidity)) {
          humidityBasedActivity[humidity] = [];
        }
        humidityBasedActivity[humidity]!
            .add(count.beesEntering + count.beesExiting);
      }
    }

    if (spots.isEmpty) {
      return _buildNoDataWidget(
          'No matching humidity and bee activity data found');
    }

    // Calculate min/max values for chart
    double minHumidity = double.infinity;
    double maxHumidity = -double.infinity;
    double maxActivity = 0;

    for (final spot in spots) {
      if (spot.x < minHumidity) minHumidity = spot.x;
      if (spot.x > maxHumidity) maxHumidity = spot.x;
      if (spot.y > maxActivity) maxActivity = spot.y;
    }

    // Add some padding
    minHumidity = (minHumidity - 5).floorToDouble();
    maxHumidity = (maxHumidity + 5).ceilToDouble();
    maxActivity = (maxActivity * 1.1).ceilToDouble();

    // Calculate trend line points if enabled
    List<FlSpot> trendPoints = [];
    if (showTrendline) {
      // Sort humidity points
      final sortedHumidities = humidityBasedActivity.keys.toList()..sort();

      for (final humidity in sortedHumidities) {
        final activities = humidityBasedActivity[humidity]!;
        if (activities.isNotEmpty) {
          final avgActivity =
              activities.reduce((a, b) => a + b) / activities.length;
          trendPoints.add(FlSpot(humidity.toDouble(), avgActivity));
        }
      }

      // Sort trend points by humidity
      trendPoints.sort((a, b) => a.x.compareTo(b.x));
    }

    return SizedBox(
      height: 300,
      child: ScatterChart(
        ScatterChartData(
          scatterSpots: spots,
          minX: minHumidity,
          maxX: maxHumidity,
          minY: 0,
          maxY: maxActivity,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              axisNameWidget: const Text(
                'Humidity (%)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              axisNameSize: 25,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value % 10 == 0) {
                    return Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: const Text(
                'Bee Activity',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              axisNameSize: 25,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            checkToShowHorizontalLine: (value) => true,
            checkToShowVerticalLine: (value) => true,
            drawVerticalLine: true,
            drawHorizontalLine: true,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
            getDrawingVerticalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
          ),
          scatterTouchData: ScatterTouchData(
            touchTooltipData: ScatterTouchTooltipData(
              tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
              getTooltipItems: (touchedSpot) {
                return ScatterTooltipItem(
                  'Humidity: ${touchedSpot.x.toInt()}%\n'
                  'Bee Activity: ${touchedSpot.y.toInt()}',
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
        ),
        swapAnimationDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  /// Generate a chart showing bee activity correlated with hive weight/honey levels
  static Widget buildWeightCorrelationChart(
    List<BeeCount> beeCounts,
    List<HiveData> hiveData, {
    required BuildContext context,
  }) {
    if (beeCounts.isEmpty || hiveData.isEmpty) {
      return _buildNoDataWidget('No hive weight correlation data available');
    }

    // Process weight data to make it time series
    final Map<DateTime, double> weightByDay = {};

    for (final data in hiveData) {
      try {
        if (data.weight != null) {
          final timestamp = data.lastChecked != null
              ? DateTime.parse(data.lastChecked!)
              : DateTime.now();

          final day = DateTime(timestamp.year, timestamp.month, timestamp.day);
          weightByDay[day] = data.weight!;
        }
      } catch (e) {
        print('Error parsing date: $e');
      }
    }

    // Group bee counts by day
    final Map<DateTime, int> activityByDay = {};

    for (final count in beeCounts) {
      final day = DateTime(
        count.timestamp.year,
        count.timestamp.month,
        count.timestamp.day,
      );

      if (!activityByDay.containsKey(day)) {
        activityByDay[day] = 0;
      }

      activityByDay[day] =
          activityByDay[day]! + count.beesEntering + count.beesExiting;
    }

    // Align days that have both weight and activity data
    final List<DateTime> alignedDays = [];
    final List<double> weights = [];
    final List<double> activities = [];

    for (final day in activityByDay.keys) {
      if (weightByDay.containsKey(day)) {
        alignedDays.add(day);
        weights.add(weightByDay[day]!);
        activities.add(activityByDay[day]!.toDouble());
      }
    }

    if (alignedDays.isEmpty) {
      return _buildNoDataWidget(
          'No matching weight and bee activity data found');
    }

    // Sort by date
    final List<int> indices = List.generate(alignedDays.length, (i) => i);
    indices.sort((a, b) => alignedDays[a].compareTo(alignedDays[b]));

    final List<DateTime> sortedDays =
        indices.map((i) => alignedDays[i]).toList();
    final List<double> sortedWeights = indices.map((i) => weights[i]).toList();
    final List<double> sortedActivities =
        indices.map((i) => activities[i]).toList();

    // Find min/max for scaling
    final double maxWeight = sortedWeights.reduce((a, b) => a > b ? a : b);
    final double maxActivity = sortedActivities.reduce((a, b) => a > b ? a : b);

    // Create spots for the chart
    final List<FlSpot> weightSpots = [];
    final List<FlSpot> activitySpots = [];

    for (int i = 0; i < sortedDays.length; i++) {
      weightSpots.add(FlSpot(i.toDouble(), sortedWeights[i]));
      activitySpots.add(FlSpot(
          i.toDouble(), sortedActivities[i] * (maxWeight / maxActivity)));
    }

    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  if (index >= 0 && index < sortedDays.length) {
                    final date = sortedDays[index];
                    final isWeight = spot.barIndex == 0;

                    if (isWeight) {
                      return LineTooltipItem(
                        '${DateFormat('yyyy-MM-dd').format(date)}\n'
                        'Weight: ${sortedWeights[index].toStringAsFixed(1)} kg',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    } else {
                      return LineTooltipItem(
                        '${DateFormat('yyyy-MM-dd').format(date)}\n'
                        'Activity: ${sortedActivities[index].toInt()} bees',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }
                  }
                  return null;
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxWeight / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.2),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 &&
                      index < sortedDays.length &&
                      index % ((sortedDays.length ~/ 5) + 1) == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('MM/dd').format(sortedDays[index]),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: const Text(
                'Weight (kg)',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.indigo),
              ),
              axisNameSize: 25,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(0),
                    style: const TextStyle(
                      color: Colors.indigo,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(
              axisNameWidget: const Text(
                'Bee Activity',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.orange),
              ),
              axisNameSize: 25,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    (value * (maxActivity / maxWeight)).toStringAsFixed(0),
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: weightSpots,
              isCurved: true,
              barWidth: 3,
              color: Colors.indigo,
              isStrokeCapRound: true,
              dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: Colors.indigo,
                      strokeWidth: 2,
                      strokeColor: Colors.indigo.shade200,
                    );
                  }),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.indigo.withOpacity(0.2),
              ),
            ),
            LineChartBarData(
              spots: activitySpots,
              isCurved: true,
              barWidth: 3,
              color: Colors.orange,
              isStrokeCapRound: true,
              dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: Colors.orange,
                      strokeWidth: 2,
                      strokeColor: Colors.orange.shade200,
                    );
                  }),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.orange.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget for showing no data message
  static Widget _buildNoDataWidget(String message) {
    return SizedBox(
      height: 250,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_off,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Helper function to build a legend item
  static Widget buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[800],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// Build a widget showing insights about the correlations
  static Widget buildCorrelationInsights(
    Map<String, double> correlations,
    BuildContext context,
  ) {
    final insights = <Widget>[];

    // Helper function to describe correlation strength
    String describeCorrelation(double value) {
      final absValue = value.abs();
      if (absValue < 0.2) return 'very weak';
      if (absValue < 0.4) return 'weak';
      if (absValue < 0.6) return 'moderate';
      if (absValue < 0.8) return 'strong';
      return 'very strong';
    }

    // Helper function to describe correlation direction
    String correlationDirection(double value) {
      return value > 0 ? 'positive' : 'negative';
    }

    // Add insights for each correlation
    correlations.forEach((factor, value) {
      if (value.abs() >= 0.2) {
        // Only show meaningful correlations
        insights.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  value > 0 ? Icons.trending_up : Icons.trending_down,
                  color: value > 0 ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$factor shows a ${describeCorrelation(value)} ${correlationDirection(value)} correlation with bee activity${_getCorrelationExplanation(factor, value)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    });

    if (insights.isEmpty) {
      insights.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            'No significant correlations found. This might be due to limited data or complex interactions between factors.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data Insights',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...insights,
            const SizedBox(height: 8),
            Text(
              'Note: Correlation does not necessarily imply causation. Other factors may also be involved.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to get specific explanations for different factors
  static String _getCorrelationExplanation(String factor, double value) {
    final absValue = value.abs();
    if (absValue < 0.2) return '.';

    switch (factor.toLowerCase()) {
      case 'temperature':
        if (value > 0) {
          return ', suggesting bees are more active as temperature increases.';
        } else {
          return ', suggesting bees reduce activity when temperatures are too high.';
        }
      case 'humidity':
        if (value > 0) {
          return ', suggesting some humidity may be beneficial for foraging.';
        } else {
          return ', suggesting high humidity may hinder bee activity.';
        }
      case 'weight':
      case 'hive weight':
        if (value > 0) {
          return ', indicating increased activity may be contributing to honey production.';
        } else {
          return ', which could indicate that bees are consuming stored honey during this period.';
        }
      case 'wind':
      case 'wind speed':
        if (value < 0) {
          return ', confirming that bees prefer calmer conditions for foraging.';
        } else {
          return ', which is unusual as bees typically prefer less windy conditions.';
        }
      case 'time of day':
        return ', showing that bees have specific preferred foraging times.';
      default:
        return '.';
    }
  }
}

/// Helper class for hive data to use in visualizations
class HiveData {
  final String id;
  final String name;
  final String status;
  final String healthStatus;
  final String lastChecked;
  final bool autoProcessingEnabled;
  final double? weight;
  final double? temperature;
  final double? honeyLevel;
  final bool isConnected;
  final bool isColonized;
  final double? exteriorTemperature;
  final double? interiorHumidity;
  final double? exteriorHumidity;
  final int? carbonDioxide;

  HiveData({
    required this.id,
    required this.name,
    required this.status,
    required this.healthStatus,
    required this.lastChecked,
    required this.autoProcessingEnabled,
    this.weight,
    this.temperature,
    this.honeyLevel,
    required this.isConnected,
    required this.isColonized,
    this.exteriorTemperature,
    this.interiorHumidity,
    this.exteriorHumidity,
    this.carbonDioxide,
  });
}
