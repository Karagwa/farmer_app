import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:farmer_app/bee_advisory/bee_advisory_database.dart';
import 'package:farmer_app/analytics/foraging_analysis/foraging_analysis_engine.dart';

class BeeAdvisoryVisualizations {
  // Generate a visualization dashboard for a recommendation
  static Widget generateRecommendationDashboard(
    BuildContext context,
    Map<String, dynamic> recommendation,
    Map<String, dynamic> foragingData,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Foraging Analysis Dashboard',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),

        // Relevant metrics based on recommendation type
        _buildRelevantMetricsCard(context, recommendation, foragingData),

        const SizedBox(height: 16),

        // Visualization based on recommendation type
        _buildRecommendationVisualization(
            context, recommendation, foragingData),

        const SizedBox(height: 16),

        // Historical trend if available
        if (recommendation.containsKey('historicalComparison') &&
            recommendation['historicalComparison'] != null)
          _buildHistoricalTrendCard(
              context, recommendation['historicalComparison']),
      ],
    );
  }

  // Build a card showing metrics relevant to the recommendation
  static Widget _buildRelevantMetricsCard(
    BuildContext context,
    Map<String, dynamic> recommendation,
    Map<String, dynamic> foragingData,
  ) {
    // Determine which metrics to show based on recommendation issue
    String issue = recommendation['issue_identified'];
    List<Widget> metricWidgets = [];

    if (issue.contains('Return Rate') ||
        issue.contains('Foraging Performance')) {
      // Show return rate metrics
      metricWidgets.add(
        _buildMetricItem(
          context,
          'Return Rate',
          '${foragingData['metrics']['returnRate'].toStringAsFixed(1)}%',
          icon: Icons.loop,
          color: _getMetricColor(foragingData['metrics']['returnRate'], 85, 95),
        ),
      );
    }

    if (issue.contains('Foraging Duration') || issue.contains('Trip')) {
      // Show duration metrics
      metricWidgets.add(
        _buildMetricItem(
          context,
          'Avg Trip Duration',
          '${foragingData['metrics']['estimatedForagingDuration'].toStringAsFixed(1)} min',
          icon: Icons.timer,
          color: _getMetricColor(
            foragingData['metrics']['estimatedForagingDuration'],
            45,
            90,
            lowerIsBetter: false,
            upperIsBetter: false,
          ),
        ),
      );
    }

    if (issue.contains('Efficiency') || issue.contains('Performance')) {
      // Show efficiency metrics
      metricWidgets.add(
        _buildMetricItem(
          context,
          'Efficiency Score',
          '${foragingData['efficiency']['efficiencyScore'].toStringAsFixed(1)}',
          icon: Icons.speed,
          color: _getMetricColor(
              foragingData['efficiency']['efficiencyScore'], 70, 85),
        ),
      );
    }

    if (issue.contains('Health') || issue.contains('Performance')) {
      // Show health metrics if available
      if (foragingData.containsKey('timeBasedAnalysis') &&
          foragingData['timeBasedAnalysis'].containsKey('overallHealthScore')) {
        metricWidgets.add(
          _buildMetricItem(
            context,
            'Health Score',
            '${foragingData['timeBasedAnalysis']['overallHealthScore'].toStringAsFixed(1)}',
            icon: Icons.favorite,
            color: _getMetricColor(
                foragingData['timeBasedAnalysis']['overallHealthScore'],
                70,
                85),
          ),
        );
      }
    }

    // Always show foraging performance score
    metricWidgets.add(
      _buildMetricItem(
        context,
        'Performance Score',
        '${foragingData['foragePerformanceScore'].toStringAsFixed(1)}',
        icon: Icons.analytics,
        color: _getMetricColor(foragingData['foragePerformanceScore'], 70, 85),
      ),
    );

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Key Metrics',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: metricWidgets,
            ),
          ],
        ),
      ),
    );
  }

  // Build a single metric display
  static Widget _buildMetricItem(
      BuildContext context, String label, String value,
      {IconData? icon, Color? color}) {
    return Container(
      width: 150,
      child: Row(
        children: [
          if (icon != null)
            Icon(icon,
                color: color ?? Theme.of(context).primaryColor, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Get color based on metric value
  static Color _getMetricColor(
      double value, double warningThreshold, double goodThreshold,
      {bool lowerIsBetter = false, bool upperIsBetter = true}) {
    if (lowerIsBetter) {
      if (value <= goodThreshold) return Colors.green;
      if (value <= warningThreshold) return Colors.orange;
      return Colors.red;
    } else if (!upperIsBetter) {
      // For metrics where middle range is best (like trip duration)
      if (value >= warningThreshold && value <= goodThreshold)
        return Colors.green;
      if ((value >= warningThreshold * 0.7 && value < warningThreshold) ||
          (value > goodThreshold && value <= goodThreshold * 1.3))
        return Colors.orange;
      return Colors.red;
    } else {
      // Default: higher is better
      if (value >= goodThreshold) return Colors.green;
      if (value >= warningThreshold) return Colors.orange;
      return Colors.red;
    }
  }

  // Build visualization based on recommendation type
  static Widget _buildRecommendationVisualization(
    BuildContext context,
    Map<String, dynamic> recommendation,
    Map<String, dynamic> foragingData,
  ) {
    String issue = recommendation['issue_identified'];

    if (issue.contains('Return Rate')) {
      return _buildReturnRateVisualization(context, foragingData);
    } else if (issue.contains('Foraging Duration') || issue.contains('Trip')) {
      return _buildTripDurationVisualization(context, foragingData);
    } else if (issue.contains('Weather Dependency')) {
      return _buildWeatherCorrelationVisualization(context, foragingData);
    } else if (issue.contains('Activity Imbalance')) {
      return _buildActivityDistributionVisualization(context, foragingData);
    } else if (issue.contains('Health')) {
      return _buildHealthScoreVisualization(context, foragingData);
    } else {
      // Default visualization
      return _buildForagingPerformanceVisualization(context, foragingData);
    }
  }

  // Build return rate visualization
  static Widget _buildReturnRateVisualization(
    BuildContext context,
    Map<String, dynamic> foragingData,
  ) {
    // Check if we have daily return rates
    if (!foragingData.containsKey('timeBasedAnalysis') ||
        !foragingData['timeBasedAnalysis'].containsKey('dailyReturnRates')) {
      return _buildNoDataCard(context, 'No daily return rate data available');
    }

    Map<String, Map<String, dynamic>> dailyRates =
        foragingData['timeBasedAnalysis']['dailyReturnRates'];

    // Prepare data for chart
    List<FlSpot> spots = [];
    List<String> days = [];
    int index = 0;

    dailyRates.forEach((day, data) {
      if (data.containsKey('overallReturnRate')) {
        spots.add(FlSpot(index.toDouble(), data['overallReturnRate']));
        days.add(day);
        index++;
      }
    });

    if (spots.isEmpty) {
      return _buildNoDataCard(context, 'No daily return rate data available');
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Return Rates',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}%',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index >= 0 && index < days.length) {
                            return Text(
                              days[index].substring(0, 3),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Theme.of(context).primaryColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).primaryColor.withOpacity(0.2),
                      ),
                    ),
                  ],
                  minX: 0,
                  maxX: (spots.length - 1).toDouble(),
                  minY: 0,
                  maxY: 100,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build trip duration visualization
  static Widget _buildTripDurationVisualization(
    BuildContext context,
    Map<String, dynamic> foragingData,
  ) {
    // Check if we have trip distribution data
    if (!foragingData.containsKey('timeBasedAnalysis') ||
        !foragingData['timeBasedAnalysis']
            .containsKey('tripDistributionPercentages')) {
      return _buildNoDataCard(
          context, 'No trip duration distribution data available');
    }

    Map<String, dynamic> distribution =
        foragingData['timeBasedAnalysis']['tripDistributionPercentages'];

    // Prepare data for pie chart
    List<PieChartSectionData> sections = [];

    if (distribution.containsKey('short')) {
      sections.add(
        PieChartSectionData(
          value: distribution['short'],
          title: 'Short\n${distribution['short'].toStringAsFixed(1)}%',
          color: Colors.red,
          radius: 100,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    if (distribution.containsKey('medium')) {
      sections.add(
        PieChartSectionData(
          value: distribution['medium'],
          title: 'Medium\n${distribution['medium'].toStringAsFixed(1)}%',
          color: Colors.green,
          radius: 100,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    if (distribution.containsKey('long')) {
      sections.add(
        PieChartSectionData(
          value: distribution['long'],
          title: 'Long\n${distribution['long'].toStringAsFixed(1)}%',
          color: Colors.blue,
          radius: 100,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    if (sections.isEmpty) {
      return _buildNoDataCard(
          context, 'No trip duration distribution data available');
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trip Duration Distribution',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 0,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(context, 'Short (<30 min)', Colors.red),
                const SizedBox(width: 16),
                _buildLegendItem(context, 'Medium (30-90 min)', Colors.green),
                const SizedBox(width: 16),
                _buildLegendItem(context, 'Long (>90 min)', Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Build weather correlation visualization
  static Widget _buildWeatherCorrelationVisualization(
    BuildContext context,
    Map<String, dynamic> foragingData,
  ) {
    // Check if we have environmental factors data
    if (!foragingData.containsKey('environmentalFactors') ||
        !foragingData['environmentalFactors'].containsKey('weatherData')) {
      return _buildNoDataCard(context, 'No weather correlation data available');
    }

    Map<String, dynamic> weatherData =
        foragingData['environmentalFactors']['weatherData'];

    // Prepare data for bar chart
    List<BarChartGroupData> barGroups = [];
    List<String> factors = [];
    int index = 0;

    weatherData.forEach((factor, data) {
      if (data.containsKey('correlations') &&
          data['correlations'].containsKey('totalActivity')) {
        double correlation =
            data['correlations']['totalActivity']['correlation'];

        // Only show if correlation is significant
        if (correlation.abs() >= 0.3) {
          barGroups.add(
            BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: correlation.abs() * 100, // Convert to percentage
                  color: correlation > 0 ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          );
          factors.add(factor);
          index++;
        }
      }
    });

    if (barGroups.isEmpty) {
      return _buildNoDataCard(
          context, 'No significant weather correlations found');
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weather Factor Correlations',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.center,
                  barGroups: barGroups,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}%',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (value, meta) {
                          int idx = value.toInt();
                          if (idx >= 0 && idx < factors.length) {
                            return Text(
                              _capitalizeFirst(factors[idx]),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  maxY: 100,
                  minY: 0,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(context, 'Positive Correlation', Colors.green),
                const SizedBox(width: 16),
                _buildLegendItem(context, 'Negative Correlation', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Build health score visualization
  static Widget _buildHealthScoreVisualization(
    BuildContext context,
    Map<String, dynamic> foragingData,
  ) {
    // Check if we have health score data
    if (!foragingData.containsKey('timeBasedAnalysis') ||
        !foragingData['timeBasedAnalysis'].containsKey('overallHealthScore')) {
      return _buildNoDataCard(context, 'No health score data available');
    }

    double healthScore =
        foragingData['timeBasedAnalysis']['overallHealthScore'];

    // Check if we have daily health scores
    List<FlSpot> spots = [];
    List<String> days = [];

    if (foragingData['timeBasedAnalysis'].containsKey('dailyReturnRates')) {
      Map<String, Map<String, dynamic>> dailyRates =
          foragingData['timeBasedAnalysis']['dailyReturnRates'];
      int index = 0;

      dailyRates.forEach((day, data) {
        if (data.containsKey('healthScore')) {
          spots.add(FlSpot(index.toDouble(), data['healthScore']));
          days.add(day);
          index++;
        }
      });
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Foraging Health Score',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: _buildGaugeChart(context, healthScore),
            ),
            const SizedBox(height: 16),
            if (spots.isNotEmpty) ...[
              Text(
                'Daily Health Scores',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 150,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          getTitlesWidget: (value, meta) {
                            int index = value.toInt();
                            if (index >= 0 && index < days.length) {
                              return Text(
                                days[index].substring(0, 3),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: Theme.of(context).primaryColor,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.2),
                        ),
                      ),
                    ],
                    minX: 0,
                    maxX: (spots.length - 1).toDouble(),
                    minY: 0,
                    maxY: 100,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Build foraging performance visualization
  static Widget _buildForagingPerformanceVisualization(
    BuildContext context,
    Map<String, dynamic> foragingData,
  ) {
    double performanceScore = foragingData['foragePerformanceScore'];

    // Get component scores
    Map<String, double> componentScores = {};

    if (foragingData.containsKey('metrics')) {
      componentScores['Return Rate'] = foragingData['metrics']['returnRate'];
    }

    if (foragingData.containsKey('efficiency')) {
      componentScores['Efficiency'] =
          foragingData['efficiency']['efficiencyScore'];
    }

    if (foragingData.containsKey('timeBasedAnalysis') &&
        foragingData['timeBasedAnalysis'].containsKey('overallHealthScore')) {
      componentScores['Health'] =
          foragingData['timeBasedAnalysis']['overallHealthScore'];
    }

    // Prepare data for radar chart
    List<RadarEntry> entries = [];

    componentScores.forEach((key, value) {
      entries.add(RadarEntry(value: value));
    });

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overall Foraging Performance',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: _buildGaugeChart(context, performanceScore),
            ),
            const SizedBox(height: 16),
            if (componentScores.isNotEmpty) ...[
              Text(
                'Performance Components',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: RadarChart(
                  RadarChartData(
                    radarShape: RadarShape.polygon,
                    dataSets: [
                      RadarDataSet(
                        dataEntries: entries,
                        // Use these properties instead of color/fillColor
                        entryRadius: 3,
                        borderColor: Theme.of(context).primaryColor,
                        fillColor:
                            Theme.of(context).primaryColor.withOpacity(0.2),
                        borderWidth: 2,
                      ),
                    ],
                    radarBorderData: const BorderSide(color: Colors.grey),
                    tickCount: 5,
                    ticksTextStyle: const TextStyle(color: Colors.transparent),
                    tickBorderData:
                        BorderSide(color: Colors.grey.withOpacity(0.3)),
                    gridBorderData:
                        BorderSide(color: Colors.grey.withOpacity(0.3)),
                    titlePositionPercentageOffset: 0.2,
                    // Replace getTitlesWidget with proper titles configuration
                    titleTextStyle: const TextStyle(fontSize: 12),
                    getTitle: (index, angle) {
                      final List<String> keys = componentScores.keys.toList();
                      if (index >= 0 && index < keys.length) {
                        return RadarChartTitle(
                          text: keys[index],
                          angle: angle,
                          positionPercentageOffset: 0.15,
                        );
                      }
                      return RadarChartTitle(text: '');
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Build historical trend card
  static Widget _buildHistoricalTrendCard(
    BuildContext context,
    Map<String, dynamic> historicalComparison,
  ) {
    if (historicalComparison['isNew']) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Historical Trend',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text('This is a new issue with no historical data.'),
            ],
          ),
        ),
      );
    }

    // Prepare historical data visualization
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Historical Trend',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  historicalComparison['severityWorsened']
                      ? Icons.trending_up
                      : Icons.trending_down,
                  color: historicalComparison['severityWorsened']
                      ? Colors.red
                      : Colors.green,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    historicalComparison['severityWorsened']
                        ? 'This issue has worsened since last detected.'
                        : 'This issue has improved since last detected.',
                    style: TextStyle(
                      color: historicalComparison['severityWorsened']
                          ? Colors.red
                          : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Last occurred ${historicalComparison['daysSinceLastOccurrence']} days ago.',
            ),
            const SizedBox(height: 8),
            Text(
              'This issue has occurred ${historicalComparison['occurrences']} times.',
            ),
            if (historicalComparison['implementationStatus']
                ['implemented']) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Previous recommendation was implemented.',
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Build gauge chart for scores
  static Widget _buildGaugeChart(BuildContext context, double score) {
    Color gaugeColor;
    if (score >= 80)
      gaugeColor = Colors.green;
    else if (score >= 60)
      gaugeColor = Colors.orange;
    else
      gaugeColor = Colors.red;

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sections: [
              PieChartSectionData(
                value: score,
                color: gaugeColor,
                radius: 60,
                showTitle: false,
              ),
              PieChartSectionData(
                value: 100 - score,
                color: Colors.grey.withOpacity(0.2),
                radius: 60,
                showTitle: false,
              ),
            ],
            centerSpaceRadius: 40,
            sectionsSpace: 0,
            startDegreeOffset: -90,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              score.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: gaugeColor,
              ),
            ),
            Text(
              'out of 100',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Build legend item
  static Widget _buildLegendItem(
      BuildContext context, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  // Build no data card
  static Widget _buildNoDataCard(BuildContext context, String message) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper to capitalize first letter
  static String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  // Build activity distribution visualization
  static Widget _buildActivityDistributionVisualization(
    BuildContext context,
    Map<String, dynamic> foragingData,
  ) {
    // Check if we have distribution data
    if (!foragingData.containsKey('distributions') ||
        !foragingData['distributions'].containsKey('timeBlockDistribution')) {
      return _buildNoDataCard(
          context, 'No activity distribution data available');
    }

    Map<String, dynamic> distribution =
        foragingData['distributions']['timeBlockDistribution'];

    // Prepare data for pie chart
    List<PieChartSectionData> sections = [];
    List<Widget> legendItems = [];

    List<Color> colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];

    int colorIndex = 0;

    distribution.forEach((timeBlock, percentage) {
      Color color = colors[colorIndex % colors.length];

      sections.add(
        PieChartSectionData(
          value: percentage,
          title: '${percentage.toStringAsFixed(1)}%',
          color: color,
          radius: 100,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );

      legendItems.add(_buildLegendItem(context, timeBlock, color));

      colorIndex++;
    });

    if (sections.isEmpty) {
      return _buildNoDataCard(
          context, 'No activity distribution data available');
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity Distribution by Time Block',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 30,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: legendItems,
            ),
          ],
        ),
      ),
    );
  }
}
