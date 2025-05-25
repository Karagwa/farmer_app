import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:HPGM/analytics/foraging_advisory_service.dart';

class EnhancedForagingDashboard extends StatefulWidget {
  final String hiveId;

  const EnhancedForagingDashboard({Key? key, required this.hiveId}) : super(key: key);

  @override
  _EnhancedForagingDashboardState createState() => _EnhancedForagingDashboardState();
}

class _EnhancedForagingDashboardState extends State<EnhancedForagingDashboard>
    with SingleTickerProviderStateMixin {
  
  final EnhancedForagingAdvisoryService _advisoryService = EnhancedForagingAdvisoryService();
  
  DailyForagingAnalysis? _analysisData;
  bool _isLoading = true;
  String _errorMessage = '';
  DateTime _selectedDate = DateTime.now();
  Timer? _refreshTimer;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDailyAnalysis();
    
    // Auto-refresh every 15 minutes for daily updates
    _refreshTimer = Timer.periodic(Duration(minutes: 15), (timer) {
      _loadDailyAnalysis();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDailyAnalysis() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final data = await _advisoryService.getDailyForagingAnalysis(
        widget.hiveId,
        _selectedDate,
      );

      if (mounted) {
        setState(() {
          _analysisData = data;
          _isLoading = false;
          if (data == null) {
            _errorMessage = 'No analysis data available for ${DateFormat('MMM dd, yyyy').format(_selectedDate)}';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading analysis: $e';
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(Duration(days: 30)),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadDailyAnalysis();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Daily Foraging Analysis - Hive ${widget.hiveId}'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: _selectDate,
            tooltip: 'Select date',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadDailyAnalysis,
            tooltip: 'Refresh analysis',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          tabs: [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard, size: 20)),
            Tab(text: 'Correlations', icon: Icon(Icons.trending_up, size: 20)),
            Tab(text: 'Patterns', icon: Icon(Icons.insights, size: 20)),
            Tab(text: 'Actions', icon: Icon(Icons.recommend, size: 20)),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green),
            SizedBox(height: 16),
            Text('Analyzing daily foraging patterns...'),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDailyAnalysis,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_analysisData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No analysis data available'),
            SizedBox(height: 8),
            Text('Try selecting a different date'),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildCorrelationsTab(),
        _buildPatternsTab(),
        _buildActionsTab(),
      ],
    );
  }

  Widget _buildOverviewTab() {
    final data = _analysisData!;
    
    return RefreshIndicator(
      onRefresh: _loadDailyAnalysis,
      color: Colors.green,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateHeader(),
            SizedBox(height: 16),
            _buildDailySummaryCard(),
            SizedBox(height: 16),
            _buildHourlyActivityChart(),
            SizedBox(height: 16),
            _buildParameterComparisonChart(),
            SizedBox(height: 16),
            _buildWeightAnalysisCard(),
            SizedBox(height: 16),
            _buildForagingDistanceChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader() {
    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            colors: [Colors.blue.shade400, Colors.blue.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMMM dd, yyyy').format(_selectedDate),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Last updated: ${DateFormat('HH:mm').format(_analysisData!.lastUpdated)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _selectDate,
                child: Text(
                  'Change Date',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailySummaryCard() {
    final data = _analysisData!;
    final totalActivity = data.beeCountData.fold(0, (sum, hour) => sum + hour.totalActivity);
    final totalEntering = data.beeCountData.fold(0, (sum, hour) => sum + hour.beesEntering);
    final totalExiting = data.beeCountData.fold(0, (sum, hour) => sum + hour.beesExiting);
    final peakHour = data.foragingPatterns.peakActivityHour;
    
    return Card(
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Summary',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryMetric(
                    'Total Activity',
                    '$totalActivity bees',
                    Icons.trending_up,
                    Colors.blue.shade600,
                  ),
                ),
                Expanded(
                  child: _buildSummaryMetric(
                    'Bees Entering',
                    '$totalEntering',
                    Icons.arrow_downward,
                    Colors.green.shade600,
                  ),
                ),
                Expanded(
                  child: _buildSummaryMetric(
                    'Bees Exiting',
                    '$totalExiting',
                    Icons.arrow_upward,
                    Colors.orange.shade600,
                  ),
                ),
                Expanded(
                  child: _buildSummaryMetric(
                    'Peak Hour',
                    '${peakHour}:00',
                    Icons.access_time,
                    Colors.purple.shade600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.insights, color: Colors.green.shade600),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data.foragingPatterns.overallForagingAssessment,
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildHourlyActivityChart() {
    final data = _analysisData!;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hourly Bee Activity Pattern',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Shows when bees are most active and the entering/exiting patterns',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 16),
            Container(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, horizontalInterval: 20),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(fontSize: 12),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final hour = value.toInt();
                          if (hour % 3 == 0) {
                            return Text(
                              '${hour}h',
                              style: TextStyle(fontSize: 10),
                            );
                          }
                          return Text('');
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    // Total activity line
                    LineChartBarData(
                      spots: data.beeCountData.map((activity) {
                        return FlSpot(
                          activity.hour.toDouble(),
                          activity.totalActivity.toDouble(),
                        );
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue.shade600,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.shade600.withOpacity(0.1),
                      ),
                    ),
                    // Bees entering line
                    LineChartBarData(
                      spots: data.beeCountData.map((activity) {
                        return FlSpot(
                          activity.hour.toDouble(),
                          activity.beesEntering.toDouble(),
                        );
                      }).toList(),
                      isCurved: true,
                      color: Colors.green.shade600,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                      dashArray: [5, 5],
                    ),
                    // Bees exiting line
                    LineChartBarData(
                      spots: data.beeCountData.map((activity) {
                        return FlSpot(
                          activity.hour.toDouble(),
                          activity.beesExiting.toDouble(),
                        );
                      }).toList(),
                      isCurved: true,
                      color: Colors.orange.shade600,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                      dashArray: [3, 3],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem('Total Activity', Colors.blue.shade600, true),
                _buildLegendItem('Entering', Colors.green.shade600, false),
                _buildLegendItem('Exiting', Colors.orange.shade600, false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isSolid) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            border: isSolid ? null : Border.all(color: color),
          ),
          child: isSolid ? null : CustomPaint(
            painter: DashedLinePainter(color: color),
          ),
        ),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildParameterComparisonChart() {
    final data = _analysisData!;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Environmental Parameters vs Bee Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.purple.shade700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Compares temperature, humidity with bee activity throughout the day',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 16),
            Container(
              height: 350,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, horizontalInterval: 10),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      axisNameWidget: Text(
                        'Bee Activity',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(fontSize: 10, color: Colors.blue),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      axisNameWidget: Text(
                        'Temperature (°C)',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(fontSize: 10, color: Colors.red),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget: Text('Hour of Day'),
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final hour = value.toInt();
                          if (hour % 4 == 0) {
                            return Text(
                              '${hour}h',
                              style: TextStyle(fontSize: 10),
                            );
                          }
                          return Text('');
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    // Bee activity line (left axis)
                    LineChartBarData(
                      spots: data.beeCountData.map((activity) {
                        return FlSpot(
                          activity.hour.toDouble(),
                          activity.totalActivity.toDouble(),
                        );
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue.shade600,
                      barWidth: 3,
                      dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: Colors.blue.shade600,
                          strokeWidth: 1,
                          strokeColor: Colors.white,
                        );
                      }),
                    ),
                    // Temperature line (right axis - scaled)
                    if (data.correlations.hourlyTemperature.isNotEmpty)
                      LineChartBarData(
                        spots: data.correlations.hourlyTemperature.entries.map((entry) {
                          // Scale temperature to fit on same chart (multiply by 3 for visibility)
                          return FlSpot(
                            entry.key.toDouble(),
                            entry.value * 3,
                          );
                        }).toList(),
                        isCurved: true,
                        color: Colors.red.shade600,
                        barWidth: 2,
                        dotData: FlDotData(show: false),
                        dashArray: [5, 3],
                      ),
                    // Humidity line (scaled)
                    if (data.correlations.hourlyHumidity.isNotEmpty)
                      LineChartBarData(
                        spots: data.correlations.hourlyHumidity.entries.map((entry) {
                          // Scale humidity to fit (divide by 2 for visibility)
                          return FlSpot(
                            entry.key.toDouble(),
                            entry.value / 2,
                          );
                        }).toList(),
                        isCurved: true,
                        color: Colors.cyan.shade600,
                        barWidth: 2,
                        dotData: FlDotData(show: false),
                        dashArray: [8, 4],
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildLegendItem('Bee Activity', Colors.blue.shade600, true),
                _buildLegendItem('Temperature (×3)', Colors.red.shade600, false),
                _buildLegendItem('Humidity (÷2)', Colors.cyan.shade600, false),
              ],
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Correlation Analysis: Temperature-Activity: ${data.correlations.temperatureActivity.toStringAsFixed(2)} | '
                'Humidity-Activity: ${data.correlations.humidityActivity.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.purple.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightAnalysisCard() {
    final data = _analysisData!;
    final weightAnalysis = data.weightAnalysis;
    
    Color changeColor = Colors.grey.shade600;
    IconData changeIcon = Icons.trending_flat;
    
    if (weightAnalysis.dailyChange > 0.1) {
      changeColor = Colors.green.shade600;
      changeIcon = Icons.trending_up;
    } else if (weightAnalysis.dailyChange < -0.1) {
      changeColor = Colors.red.shade600;
      changeIcon = Icons.trending_down;
    }
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.scale, color: Colors.amber.shade600, size: 24),
                SizedBox(width: 8),
                Text(
                  'Weight Analysis & Activity Correlation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(changeIcon, color: changeColor, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Daily Change: ${weightAnalysis.dailyChange >= 0 ? '+' : ''}${weightAnalysis.dailyChange.toStringAsFixed(2)} kg',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: changeColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        weightAnalysis.interpretation,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Activity Correlation:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.blue.shade800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              weightAnalysis.activityCorrelation,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildWeightActivityIndicator(data),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightActivityIndicator(DailyForagingAnalysis data) {
    final totalActivity = data.beeCountData.fold(0, (sum, hour) => sum + hour.totalActivity);
    final weightChange = data.weightAnalysis.dailyChange;
    
    // Create a simple correlation visualization
    String status;
    Color statusColor;
    IconData statusIcon;
    
    if (weightChange > 0.1 && totalActivity > 100) {
      status = 'Excellent\nNectar Flow';
      statusColor = Colors.green.shade600;
      statusIcon = Icons.check_circle;
    } else if (weightChange < -0.1 && totalActivity > 50) {
      status = 'High Activity\nNo Weight Gain';
      statusColor = Colors.orange.shade600;
      statusIcon = Icons.warning;
    } else if (weightChange < -0.1 && totalActivity < 50) {
      status = 'Poor Foraging\nConditions';
      statusColor = Colors.red.shade600;
      statusIcon = Icons.error;
    } else {
      status = 'Stable\nConditions';
      statusColor = Colors.blue.shade600;
      statusIcon = Icons.info;
    }
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(statusIcon, color: statusColor, size: 32),
          SizedBox(height: 8),
          Text(
            status,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Activity: $totalActivity',
            style: TextStyle(
              fontSize: 12,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForagingDistanceChart() {
    final data = _analysisData!;
    final indicators = data.foragingPatterns.foragingDistanceIndicators;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Foraging Distance Analysis by Hour',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Entering/Exiting ratios indicate whether bees are finding food nearby or traveling far',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 16),
            Container(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 3.0,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final hour = group.x.toInt();
                        final indicator = indicators[hour];
                        if (indicator != null) {
                          return BarTooltipItem(
                            '${hour}:00\n${indicator.distanceAssessment}\nRatio: ${rod.toY.toStringAsFixed(2)}',
                            TextStyle(color: Colors.white, fontSize: 12),
                          );
                        }
                        return null;
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      axisNameWidget: Text('Entering/Exiting Ratio'),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(1),
                            style: TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget: Text('Hour of Day'),
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}h',
                            style: TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  barGroups: indicators.entries.map((entry) {
                    final hour = entry.key;
                    final indicator = entry.value;
                    
                    Color barColor;
                    if (indicator.distanceAssessment.contains('Close')) {
                      barColor = Colors.green.shade600;
                    } else if (indicator.distanceAssessment.contains('Distant')) {
                      barColor = Colors.red.shade600;
                    } else if (indicator.distanceAssessment.contains('Scouting')) {
                      barColor = Colors.blue.shade600;
                    } else {
                      barColor = Colors.orange.shade600;
                    }
                    
                    return BarChartGroupData(
                      x: hour,
                      barRods: [
                        BarChartRodData(
                          toY: indicator.enteringRatio.clamp(0.0, 3.0),
                          color: barColor,
                          width: 16,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildForageDistanceLegend('Close Forage', Colors.green.shade600, '>1.5 ratio'),
                _buildForageDistanceLegend('Normal Foraging', Colors.orange.shade600, '0.8-1.5 ratio'),
                _buildForageDistanceLegend('Distant Foraging', Colors.red.shade600, '<0.8 ratio'),
                _buildForageDistanceLegend('Scouting Activity', Colors.blue.shade600, 'High exiting'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForageDistanceLegend(String label, Color color, String description) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
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
          SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 9,
                  color: color.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCorrelationsTab() {
    final data = _analysisData!;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCorrelationMatrix(),
          SizedBox(height: 16),
          _buildTemperatureCorrelationChart(),
          SizedBox(height: 16),
          _buildHumidityCorrelationChart(),
          SizedBox(height: 16),
          _buildCorrelationInsights(),
        ],
      ),
    );
  }

  Widget _buildCorrelationMatrix() {
    final correlations = _analysisData!.correlations;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Parameter Correlation Matrix',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.purple.shade700,
              ),
            ),
            SizedBox(height: 16),
            Table(
              border: TableBorder.all(color: Colors.grey.shade300),
              columnWidths: {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: [
                    _buildTableHeader('Parameter'),
                    _buildTableHeader('Total Activity'),
                    _buildTableHeader('Entering'),
                    _buildTableHeader('Exiting'),
                  ],
                ),
                _buildCorrelationRow(
                  'Temperature',
                  correlations.temperatureActivity,
                  correlations.temperatureEntering,
                  correlations.temperatureExiting,
                ),
                _buildCorrelationRow(
                  'Humidity',
                  correlations.humidityActivity,
                  correlations.humidityEntering,
                  correlations.humidityExiting,
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'Strong correlations (>0.5) indicate predictable relationships. '
              'Negative correlations mean inverse relationships.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Container(
      padding: EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  TableRow _buildCorrelationRow(String parameter, double activity, double entering, double exiting) {
    return TableRow(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          child: Text(
            parameter,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        _buildCorrelationCell(activity),
        _buildCorrelationCell(entering),
        _buildCorrelationCell(exiting),
      ],
    );
  }

  Widget _buildCorrelationCell(double correlation) {
    Color color;
    if (correlation.abs() > 0.7) {
      color = correlation > 0 ? Colors.green.shade700 : Colors.red.shade700;
    } else if (correlation.abs() > 0.5) {
      color = correlation > 0 ? Colors.green.shade500 : Colors.red.shade500;
    } else if (correlation.abs() > 0.3) {
      color = correlation > 0 ? Colors.orange.shade600 : Colors.orange.shade700;
    } else {
      color = Colors.grey.shade600;
    }
    
    return Container(
      padding: EdgeInsets.all(8),
      child: Text(
        '${correlation >= 0 ? '+' : ''}${correlation.toStringAsFixed(2)}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTemperatureCorrelationChart() {
    final data = _analysisData!;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Temperature vs Bee Activity Correlation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Shows how temperature changes throughout the day affect bee foraging patterns',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            SizedBox(height: 16),
            Container(
              height: 280,
              child: _buildLineCorrelationChart(
                data.correlations.hourlyTemperature,
                data.beeCountData,
                'Temperature (°C)',
                Colors.red.shade600,
              ),
            ),
            SizedBox(height: 12),
            // Enhanced legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCorrelationLegendItem(
                  'Bee Activity', 
                  Colors.blue.shade600, 
                  true, 
                  'Primary axis (left)'
                ),
                _buildCorrelationLegendItem(
                  'Temperature', 
                  Colors.red.shade600, 
                  false, 
                  'Secondary axis (right)'
                ),
              ],
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Correlation Strength: ${data.correlations.temperatureActivity >= 0 ? '+' : ''}${data.correlations.temperatureActivity.toStringAsFixed(3)} | ${_getCorrelationStrength(data.correlations.temperatureActivity)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHumidityCorrelationChart() {
    final data = _analysisData!;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Humidity vs Bee Activity Correlation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.cyan.shade700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Shows how humidity changes throughout the day affect bee foraging patterns',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            SizedBox(height: 16),
            Container(
              height: 280,
              child: _buildLineCorrelationChart(
                data.correlations.hourlyHumidity,
                data.beeCountData,
                'Humidity (%)',
                Colors.cyan.shade600,
              ),
            ),
            SizedBox(height: 12),
            // Enhanced legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCorrelationLegendItem(
                  'Bee Activity', 
                  Colors.blue.shade600, 
                  true, 
                  'Primary axis (left)'
                ),
                _buildCorrelationLegendItem(
                  'Humidity', 
                  Colors.cyan.shade600, 
                  false, 
                  'Secondary axis (right)'
                ),
              ],
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.cyan.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Correlation Strength: ${data.correlations.humidityActivity >= 0 ? '+' : ''}${data.correlations.humidityActivity.toStringAsFixed(3)} | ${_getCorrelationStrength(data.correlations.humidityActivity)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.cyan.shade700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Updated line correlation chart method
  Widget _buildLineCorrelationChart(
    Map<int, double> parameterData,
    List<HourlyBeeActivity> beeData,
    String xAxisLabel,
    Color color,
  ) {
    // Create sorted lists of data points for line chart
    final List<FlSpot> parameterSpots = [];
    final List<FlSpot> activitySpots = [];
    
    // Get all hours that have both parameter and activity data
    final commonHours = <int>[];
    for (final bee in beeData) {
      if (parameterData.containsKey(bee.hour) && bee.totalActivity > 0) {
        commonHours.add(bee.hour);
      }
    }
    commonHours.sort(); // Sort hours for proper line connection
    
    // Create spots for both parameter and activity data
    for (final hour in commonHours) {
      final paramValue = parameterData[hour]!;
      final activityValue = beeData.firstWhere((b) => b.hour == hour).totalActivity.toDouble();
      
      parameterSpots.add(FlSpot(hour.toDouble(), paramValue));
      activitySpots.add(FlSpot(hour.toDouble(), activityValue));
    }
    
    if (parameterSpots.isEmpty) {
      return Center(
        child: Text(
          'No correlation data available',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }
    
    // Calculate max values for scaling
    final maxParam = parameterSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final maxActivity = activitySpots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, horizontalInterval: maxActivity / 5),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            axisNameWidget: Text(
              'Bee Activity',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(fontSize: 10, color: Colors.blue.shade600),
                );
              },
            ),
          ),
          rightTitles: AxisTitles(
            axisNameWidget: Text(
              xAxisLabel,
              style: TextStyle(fontSize: 12, color: color),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                // Scale back the parameter value for display
                final actualValue = xAxisLabel.contains('Temperature') 
                    ? value / 3  // Temperature was scaled by 3x
                    : value * 2; // Humidity was scaled by 0.5x
                return Text(
                  actualValue.toInt().toString(),
                  style: TextStyle(fontSize: 10, color: color),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: Text('Hour of Day'),
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}h',
                  style: TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          // Bee activity line (primary axis)
          LineChartBarData(
            spots: activitySpots,
            isCurved: true,
            color: Colors.blue.shade600,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.blue.shade600,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.shade600.withOpacity(0.1),
            ),
          ),
          // Parameter line (secondary axis - scaled for visibility)
          LineChartBarData(
            spots: parameterSpots.map((spot) {
              // Scale parameter values to fit nicely with activity data
              double scaledValue;
              if (xAxisLabel.contains('Temperature')) {
                scaledValue = spot.y * 3; // Scale temperature up for visibility
              } else {
                scaledValue = spot.y / 2; // Scale humidity down for visibility
              }
              return FlSpot(spot.x, scaledValue);
            }).toList(),
            isCurved: true,
            color: color,
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: color,
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                );
              },
            ),
            dashArray: [5, 3], // Dashed line to distinguish from activity
          ),
        ],
        // Add touch interaction to show both values
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                final hour = touchedSpot.x.toInt();
                if (touchedSpot.barIndex == 0) {
                  // Activity line
                  return LineTooltipItem(
                    'Hour ${hour}h\nActivity: ${touchedSpot.y.toInt()} bees',
                    TextStyle(color: Colors.blue.shade600, fontWeight: FontWeight.bold),
                  );
                } else {
                  // Parameter line
                  final actualValue = xAxisLabel.contains('Temperature') 
                      ? touchedSpot.y / 3
                      : touchedSpot.y * 2;
                  final unit = xAxisLabel.contains('Temperature') ? '°C' : '%';
                  return LineTooltipItem(
                    '${xAxisLabel.split(' ')[0]}: ${actualValue.toStringAsFixed(1)}$unit',
                    TextStyle(color: color, fontWeight: FontWeight.bold),
                  );
                }
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  // Helper method for correlation legend
  Widget _buildCorrelationLegendItem(String label, Color color, bool isSolid, String description) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 20,
                  height: 3,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: isSolid ? null : CustomPaint(
                    painter: DashedLinePainter(color: color),
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 10,
                color: color.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to interpret correlation strength
  String _getCorrelationStrength(double correlation) {
    final abs = correlation.abs();
    if (abs >= 0.8) return 'Very Strong';
    if (abs >= 0.6) return 'Strong';
    if (abs >= 0.4) return 'Moderate';
    if (abs >= 0.2) return 'Weak';
    return 'Very Weak';
  }

  Widget _buildCorrelationInsights() {
    final correlations = _analysisData!.correlations;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Correlation Insights & Implications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            SizedBox(height: 16),
            _buildInsightCard(
              'Temperature Impact',
              _getTemperatureInsight(correlations.temperatureActivity),
              correlations.temperatureActivity.abs() > 0.5 ? Colors.green : Colors.orange,
              Icons.thermostat,
            ),
            SizedBox(height: 12),
            _buildInsightCard(
              'Humidity Impact',
              _getHumidityInsight(correlations.humidityActivity),
              correlations.humidityActivity.abs() > 0.5 ? Colors.green : Colors.orange,
              Icons.water_drop,
            ),
            SizedBox(height: 12),
            _buildInsightCard(
              'Foraging Optimization',
              _getOptimizationInsight(correlations),
              Colors.purple,
              Icons.insights,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(String title, String insight, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  insight,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.8),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTemperatureInsight(double correlation) {
    if (correlation > 0.7) {
      return 'Strong positive correlation! Bees are very responsive to temperature increases. Time hive management and expect peak activity during warm periods. Plant flowers that bloom optimally at current temperature ranges.';
    } else if (correlation > 0.5) {
      return 'Good positive correlation. Warmer temperatures generally increase bee activity. Use temperature forecasts to predict foraging windows.';
    } else if (correlation < -0.5) {
      return 'Negative correlation suggests bees avoid extreme temperatures. Provide shade during hot periods and ensure adequate ventilation.';
    } else {
      return 'Weak temperature correlation indicates other factors (humidity, forage availability) may be more important for your hive location.';
    }
  }

  String _getHumidityInsight(double correlation) {
    if (correlation > 0.5) {
      return 'Positive humidity correlation suggests bees prefer moderate moisture levels. Ensure good drainage around hives and avoid very dry conditions.';
    } else if (correlation < -0.5) {
      return 'Negative humidity correlation indicates bees reduce activity in high moisture. Improve ventilation and avoid placing hives in damp areas.';
    } else {
      return 'Humidity shows minimal impact on activity. Focus optimization efforts on temperature and forage availability instead.';
    }
  }

  String _getOptimizationInsight(TimeSyncedCorrelations correlations) {
    final strongCorrelations = [
      if (correlations.temperatureActivity.abs() > 0.5) 'temperature',
      if (correlations.humidityActivity.abs() > 0.5) 'humidity',
    ];
    
    if (strongCorrelations.isEmpty) {
      return 'No strong environmental correlations detected. Focus on improving local forage availability and hive health rather than environmental modifications.';
    } else {
      return 'Strong correlations with ${strongCorrelations.join(' and ')} provide opportunities for predictive management. Use weather forecasts to optimize timing of inspections and interventions.';
    }
  }

  Widget _buildPatternsTab() {
    final data = _analysisData!;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNectarFlowAnalysis(),
          SizedBox(height: 16),
          _buildForagingPatternsDetail(),
          SizedBox(height: 16),
          _buildHourlyPatternBreakdown(),
          SizedBox(height: 16),
          _buildForagingEfficiencyMetrics(),
        ],
      ),
    );
  }

  Widget _buildNectarFlowAnalysis() {
    final nectarFlow = _analysisData!.foragingPatterns.nectarFlowAnalysis;
    
    Color statusColor;
    IconData statusIcon;
    
    switch (nectarFlow.intensity) {
      case 'High':
        statusColor = Colors.green.shade600;
        statusIcon = Icons.trending_up;
        break;
      case 'Medium':
        statusColor = Colors.blue.shade600;
        statusIcon = Icons.trending_flat;
        break;
      case 'Low':
        statusColor = Colors.orange.shade600;
        statusIcon = Icons.trending_down;
        break;
      default:
        statusColor = Colors.red.shade600;
        statusIcon = Icons.warning;
    }
    
    return Card(
      elevation: 3,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            colors: [statusColor.withOpacity(0.1), statusColor.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nectar Flow Analysis',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        Text(
                          nectarFlow.status,
                          style: TextStyle(
                            fontSize: 16,
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${nectarFlow.intensity} Intensity',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                nectarFlow.reasoning,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              if (nectarFlow.peakHours.isNotEmpty) ...[
                SizedBox(height: 12),
                Text(
                  'Peak Flow Hours: ${nectarFlow.peakHours.map((h) => '${h}:00').join(', ')}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: statusColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForagingPatternsDetail() {
    final patterns = _analysisData!.foragingPatterns;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hourly Foraging Distance Patterns',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade700,
              ),
            ),
            SizedBox(height: 16),
            ...patterns.foragingDistanceIndicators.entries.map((entry) {
              final hour = entry.key;
              final indicator = entry.value;
              return _buildPatternRow(hour, indicator);
            }).toList(),
            if (patterns.foragingDistanceIndicators.isEmpty)
              Container(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No activity patterns detected for this date',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternRow(int hour, ForageDistanceIndicator indicator) {
    Color assessmentColor;
    IconData assessmentIcon;
    
    if (indicator.distanceAssessment.contains('Close')) {
      assessmentColor = Colors.green.shade600;
      assessmentIcon = Icons.near_me;
    } else if (indicator.distanceAssessment.contains('Distant')) {
      assessmentColor = Colors.red.shade600;
      assessmentIcon = Icons.explore;
    } else if (indicator.distanceAssessment.contains('Scouting')) {
      assessmentColor = Colors.blue.shade600;
      assessmentIcon = Icons.search;
    } else {
      assessmentColor = Colors.orange.shade600;
      assessmentIcon = Icons.navigation;
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: assessmentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: assessmentColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 30,
            decoration: BoxDecoration(
              color: assessmentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '${hour}h',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: assessmentColor,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Icon(assessmentIcon, color: assessmentColor, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  indicator.distanceAssessment,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: assessmentColor,
                    fontSize: 14,
                  ),
                ),
                Text(
                  indicator.reasoning,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Ratio: ${indicator.enteringRatio.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: assessmentColor,
                ),
              ),
              Text(
                '${(indicator.confidence * 100).toStringAsFixed(0)}% confidence',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyPatternBreakdown() {
    final data = _analysisData!;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detailed Hourly Activity Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
                columns: [
                  DataColumn(label: Text('Hour', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Entering', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Exiting', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Net', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Pattern', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: data.beeCountData.where((activity) => activity.totalActivity > 0).map((activity) {
                  final pattern = data.foragingPatterns.foragingDistanceIndicators[activity.hour];
                  final netChange = activity.netChange;
                  
                  return DataRow(
                    cells: [
                      DataCell(Text('${activity.hour}:00')),
                      DataCell(Text('${activity.beesEntering}', style: TextStyle(color: Colors.green))),
                      DataCell(Text('${activity.beesExiting}', style: TextStyle(color: Colors.orange))),
                      DataCell(Text(
                        '${netChange >= 0 ? '+' : ''}$netChange',
                        style: TextStyle(
                          color: netChange >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      )),
                      DataCell(Text('${activity.totalActivity}')),
                      DataCell(
                        pattern != null
                            ? Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getPatternColor(pattern.distanceAssessment).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _getPatternShortName(pattern.distanceAssessment),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _getPatternColor(pattern.distanceAssessment),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            : Text('-', style: TextStyle(color: Colors.grey)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPatternColor(String pattern) {
    if (pattern.contains('Close')) return Colors.green.shade600;
    if (pattern.contains('Distant')) return Colors.red.shade600;
    if (pattern.contains('Scouting')) return Colors.blue.shade600;
    return Colors.orange.shade600;
  }

  String _getPatternShortName(String pattern) {
    if (pattern.contains('Close')) return 'Close';
    if (pattern.contains('Distant')) return 'Distant';
    if (pattern.contains('Scouting')) return 'Scout';
    return 'Normal';
  }

  Widget _buildForagingEfficiencyMetrics() {
    final data = _analysisData!;
    final totalEntering = data.beeCountData.fold(0, (sum, hour) => sum + hour.beesEntering);
    final totalExiting = data.beeCountData.fold(0, (sum, hour) => sum + hour.beesExiting);
    final totalActivity = totalEntering + totalExiting;
    
    final efficiency = totalActivity > 0 ? (totalEntering / totalActivity) * 100 : 0.0;
    final netGain = totalEntering - totalExiting;
    final weightChange = data.weightAnalysis.dailyChange;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Foraging Efficiency Metrics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.purple.shade700,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildEfficiencyCard(
                    'Foraging Ratio',
                    '${efficiency.toStringAsFixed(1)}%',
                    'Percentage of activity that is foraging (entering)',
                    efficiency >= 60 ? Colors.green : efficiency >= 40 ? Colors.orange : Colors.red,
                    Icons.percent,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildEfficiencyCard(
                    'Net Bee Flow',
                    '${netGain >= 0 ? '+' : ''}$netGain',
                    'Difference between entering and exiting bees',
                    netGain >= 0 ? Colors.green : Colors.orange,
                    netGain >= 0 ? Icons.trending_up : Icons.trending_down,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildEfficiencyCard(
                    'Activity-Weight Correlation',
                    weightChange >= 0 ? 'Positive' : 'Negative',
                    'High activity ${weightChange >= 0 ? 'with' : 'without'} weight gain',
                    (totalActivity > 50 && weightChange > 0) ? Colors.green : Colors.orange,
                    (totalActivity > 50 && weightChange > 0) ? Icons.check_circle : Icons.warning,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildEfficiencyCard(
                    'Peak Utilization',
                    '${((data.beeCountData.where((h) => h.totalActivity > 0).length / 24) * 100).toStringAsFixed(0)}%',
                    'Percentage of hours with bee activity',
                    data.beeCountData.where((h) => h.totalActivity > 0).length >= 8 ? Colors.green : Colors.orange,
                    Icons.schedule,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEfficiencyCard(String title, String value, String description, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsTab() {
    final data = _analysisData!;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRecommendationsSummary(),
          SizedBox(height: 16),
          ...data.recommendations.map((recommendation) => 
            _buildRecommendationCard(recommendation)
          ).toList(),
          if (data.recommendations.isEmpty)
            _buildNoRecommendationsCard(),
        ],
      ),
    );
  }

  Widget _buildRecommendationsSummary() {
    final recommendations = _analysisData!.recommendations;
    final criticalCount = recommendations.where((r) => r.priority == 'Critical').length;
    final highCount = recommendations.where((r) => r.priority == 'High').length;
    final mediumCount = recommendations.where((r) => r.priority == 'Medium').length;
    
    return Card(
      elevation: 3,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            colors: [Colors.orange.shade400, Colors.orange.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily Action Items',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Updated ${DateFormat('MMM dd, yyyy HH:mm').format(_analysisData!.lastUpdated)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  if (criticalCount > 0)
                    _buildPriorityBadge('Critical', criticalCount, Colors.red.shade700),
                  if (highCount > 0) ...[
                    if (criticalCount > 0) SizedBox(width: 8),
                    _buildPriorityBadge('High', highCount, Colors.orange.shade700),
                  ],
                  if (mediumCount > 0) ...[
                    if (criticalCount > 0 || highCount > 0) SizedBox(width: 8),
                    _buildPriorityBadge('Medium', mediumCount, Colors.blue.shade700),
                  ],
                  if (recommendations.isEmpty)
                    _buildPriorityBadge('All Good', 0, Colors.green.shade700),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority, int count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count > 0) ...[
            Text(
              count.toString(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            SizedBox(width: 6),
          ],
          Text(
            priority,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(DailyRecommendation recommendation) {
    Color priorityColor;
    IconData priorityIcon;
    
    switch (recommendation.priority) {
      case 'Critical':
        priorityColor = Colors.red.shade600;
        priorityIcon = Icons.error;
        break;
      case 'High':
        priorityColor = Colors.orange.shade600;
        priorityIcon = Icons.warning;
        break;
      case 'Medium':
        priorityColor = Colors.blue.shade600;
        priorityIcon = Icons.info;
        break;
      default:
        priorityColor = Colors.grey.shade600;
        priorityIcon = Icons.info_outline;
    }
    
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: priorityColor.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(priorityIcon, color: priorityColor, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        recommendation.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: priorityColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: priorityColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        recommendation.priority,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  recommendation.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Immediate Actions:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 8),
                ...recommendation.actionItems.map((action) => Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: EdgeInsets.only(top: 6),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: priorityColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          action,
                          style: TextStyle(fontSize: 14, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
                SizedBox(height: 16),
                _buildRecommendationMetrics(recommendation, priorityColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationMetrics(DailyRecommendation recommendation, Color color) {
    return Column(
      children: [
        _buildMetricRow(
          Icons.schedule,
          'Timeline',
          recommendation.timeRelevance,
          color,
        ),
        SizedBox(height: 8),
        _buildMetricRow(
          Icons.agriculture,
          'Foraging Impact',
          recommendation.foragingImpact,
          color,
        ),
        SizedBox(height: 8),
        _buildMetricRow(
          Icons.trending_up,
          'Expected Outcome',
          recommendation.expectedOutcome,
          color,
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.science, size: 16, color: Colors.blue.shade600),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  recommendation.scientificBasis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: color,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoRecommendationsCard() {
    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            colors: [Colors.green.shade400, Colors.green.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 48),
              SizedBox(height: 16),
              Text(
                'All Systems Optimal!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Your hive is performing well with no immediate action items. Continue monitoring daily patterns and maintain current management practices.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom painter for dashed lines in legend
class DashedLinePainter extends CustomPainter {
  final Color color;
  
  DashedLinePainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    
    const dashWidth = 3.0;
    const dashSpace = 3.0;
    double startX = 0;
    
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}