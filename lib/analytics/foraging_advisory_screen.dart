import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:HPGM/analytics/foraging_advisory_service.dart';
import 'package:flutter_echarts/flutter_echarts.dart';
import 'package:HPGM/bee_counter/bee_count_database.dart';
import 'package:HPGM/bee_counter/bee_counter_model.dart';
import 'package:HPGM/temperature.dart';
import 'package:shared_preferences/shared_preferences.dart';


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
  List<TimeSeriesData>? _weeklyData;
  bool _isLoading = true;
  String _errorMessage = '';
  DateTime _selectedDate = DateTime.now();
  Timer? _refreshTimer;
  late TabController _tabController;
  String _selectedTimeRange = '7days'; // 7days, 14days, 30days

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this); // Added one more tab
    _loadData();
    
    // Auto-refresh every 15 minutes for daily updates
    _refreshTimer = Timer.periodic(Duration(minutes: 15), (timer) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }
  
  Future<String?> _getToken() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Load daily analysis
      final dailyData = await _advisoryService.getDailyForagingAnalysis(
        widget.hiveId,
        _selectedDate,
      );

      // Load weekly time series data
      final weeklyData = await _loadTimeSeriesData();

      if (mounted) {
        setState(() {
          _analysisData = dailyData;
          _weeklyData = weeklyData;
          _isLoading = false;
          if (dailyData == null && weeklyData.isEmpty) {
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

  Future<List<TimeSeriesData>> _loadTimeSeriesData() async {
    try {
      int daysBack = 7;
      switch (_selectedTimeRange) {
        case '14days':
          daysBack = 14;
          break;
        case '30days':
          daysBack = 30;
          break;
        default:
          daysBack = 7;
      }

      final endDate = _selectedDate;
      final startDate = _selectedDate.subtract(Duration(days: daysBack));
      
      // Get bee counts from database
      final beeCounts = await BeeCountDatabase.instance.getBeeCountsForDateRange(
        widget.hiveId,
        startDate,
        endDate,
      );

      // Get temperature and humidity data for the same period
      final token = await _advisoryService.getToken();
      if (token == null) return [];

      final temperatureData = await _advisoryService.fetchLatestTemperatureData(
        widget.hiveId, token, startDate, endDate
      );
      final humidityData = await _advisoryService.fetchLatestHumidityData(
        widget.hiveId, token, startDate, endDate
      );

      // Group bee counts by day and hour
      final Map<DateTime, Map<int, List<BeeCount>>> groupedByCounts = {};
      for (final count in beeCounts) {
        final day = DateTime(count.timestamp.year, count.timestamp.month, count.timestamp.day);
        final hour = count.timestamp.hour;
        
        if (!groupedByCounts.containsKey(day)) {
          groupedByCounts[day] = {};
        }
        if (!groupedByCounts[day]!.containsKey(hour)) {
          groupedByCounts[day]![hour] = [];
        }
        groupedByCounts[day]![hour]!.add(count);
      }

      // Create time series data points
      final List<TimeSeriesData> timeSeriesData = [];
      for (int i = 0; i < daysBack; i++) {
        final currentDay = startDate.add(Duration(days: i));
        final dayKey = DateTime(currentDay.year, currentDay.month, currentDay.day);
        
        int totalEntering = 0;
        int totalExiting = 0;
        int totalActivity = 0;
        
        if (groupedByCounts.containsKey(dayKey)) {
          for (final hourData in groupedByCounts[dayKey]!.values) {
            for (final count in hourData) {
              totalEntering += count.beesEntering;
              totalExiting += count.beesExiting;
            }
          }
          totalActivity = totalEntering + totalExiting;
        }

        // Find corresponding temperature and humidity for this day
        double? avgTemp;
        double? avgHumidity;
        
        final dayTempData = temperatureData.where((t) => 
          t.timestamp.year == currentDay.year &&
          t.timestamp.month == currentDay.month &&
          t.timestamp.day == currentDay.day
        ).toList();
        
        if (dayTempData.isNotEmpty) {
          avgTemp = dayTempData.map((t) => t.value).reduce((a, b) => a + b) / dayTempData.length;
        }

        final dayHumidityData = humidityData.where((h) => 
          h.timestamp.year == currentDay.year &&
          h.timestamp.month == currentDay.month &&
          h.timestamp.day == currentDay.day
        ).toList();
        
        if (dayHumidityData.isNotEmpty) {
          avgHumidity = dayHumidityData.map((h) => h.value).reduce((a, b) => a + b) / dayHumidityData.length;
        }

        timeSeriesData.add(TimeSeriesData(
          date: currentDay,
          beesEntering: totalEntering,
          beesExiting: totalExiting,
          totalActivity: totalActivity,
          temperature: avgTemp,
          humidity: avgHumidity,
        ));
      }

      return timeSeriesData;
    } catch (e) {
      print('Error loading time series data: $e');
      return [];
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(Duration(days: 90)),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadData();
    }
  }
  
  Future<List<TimestampedParameter>> _fetchTemperatureData(
    String hiveId, String token, DateTime startDate, DateTime endDate,
  ) async {
    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);
      
      print('Fetching temperature data from $startDateStr to $endDateStr');
      
      final response = await http.get(
        Uri.parse('${_advisoryService.baseUrl}/hives/$hiveId/temperature/$startDateStr/$endDateStr'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 30));

      print('Temperature API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List<TimestampedParameter> parameters = [];

        if (jsonData['data'] != null) {
          for (final dataPoint in jsonData['data']) {
            try {
              final timestamp = DateTime.parse(dataPoint['date'] ?? dataPoint['timestamp']);
              final temperature = dataPoint['exteriorTemperature'] != null
                  ? double.tryParse(dataPoint['exteriorTemperature'].toString())
                  : dataPoint['temperature'] != null
                      ? double.tryParse(dataPoint['temperature'].toString())
                      : null;

              if (temperature != null && temperature > -50 && temperature < 100) {
                parameters.add(TimestampedParameter(
                  timestamp: timestamp,
                  value: temperature,
                  type: 'temperature',
                ));
              }
            } catch (e) {
              print('Error parsing temperature data point: $e');
            }
          }
        }

        // Sort by timestamp descending (latest first)
        parameters.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        print('Fetched ${parameters.length} temperature readings');
        return parameters;
      }
    } catch (e) {
      print('Error fetching temperature data: $e');
    }
    return [];
  }

  Future<List<TimestampedParameter>> _fetchHumidityData(
    String hiveId, String token, DateTime startDate, DateTime endDate,
  ) async {
    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);
      
      print('Fetching humidity data from $startDateStr to $endDateStr');
      
      final response = await http.get(
        Uri.parse('${_advisoryService.baseUrl}/hives/$hiveId/humidity/$startDateStr/$endDateStr'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 30));

      print('Humidity API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List<TimestampedParameter> parameters = [];

        if (jsonData['data'] != null) {
          for (final dataPoint in jsonData['data']) {
            try {
              final timestamp = DateTime.parse(dataPoint['date'] ?? dataPoint['timestamp']);
              final humidity = dataPoint['exteriorHumidity'] != null
                  ? double.tryParse(dataPoint['exteriorHumidity'].toString())
                  : dataPoint['humidity'] != null
                      ? double.tryParse(dataPoint['humidity'].toString())
                      : null;

              if (humidity != null && humidity >= 0 && humidity <= 100) {
                parameters.add(TimestampedParameter(
                  timestamp: timestamp,
                  value: humidity,
                  type: 'humidity',
                ));
              }
            } catch (e) {
              print('Error parsing humidity data point: $e');
            }
          }
        }

        // Sort by timestamp descending (latest first)
        parameters.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        print('Fetched ${parameters.length} humidity readings');
        return parameters;
      }
    } catch (e) {
      print('Error fetching humidity data: $e');
    }
    return [];
  }

  


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Enhanced Foraging Analysis - Hive ${widget.hiveId}'),
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
            onPressed: _loadData,
            tooltip: 'Refresh analysis',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          isScrollable: true,
          tabs: [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard, size: 20)),
            Tab(text: 'Time Series', icon: Icon(Icons.timeline, size: 20)),
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
            Text('Analyzing foraging patterns and time series data...'),
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
              onPressed: _loadData,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildTimeSeriesTab(),
        _buildCorrelationsTab(),
        _buildPatternsTab(),
        _buildActionsTab(),
      ],
    );
  }

  Widget _buildOverviewTab() {
    if (_analysisData == null) {
      return Center(child: Text('No data available'));
    }
    
    final data = _analysisData!;
    
    return RefreshIndicator(
      onRefresh: _loadData,
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

  Widget _buildTimeSeriesTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: Colors.green,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimeRangeSelector(),
            SizedBox(height: 16),
            _buildWeeklyActivityChart(),
            SizedBox(height: 16),
            _buildBeeActivityTrendChart(),
            SizedBox(height: 16),
            _buildEnvironmentalCorrelationChart(),
            SizedBox(height: 16),
            _buildDailyPatternsHeatmap(),
            SizedBox(height: 16),
            _buildTimeSeriesInsights(),
          ],
        ),
      ),
    );
  }

  Widget _buildCorrelationsTab() {
    if (_analysisData == null) {
      return Center(child: Text('No data available'));
    }
    
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

  Widget _buildPatternsTab() {
    if (_analysisData == null) {
      return Center(child: Text('No data available'));
    }
    
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

  Widget _buildActionsTab() {
    if (_analysisData == null) {
      return Center(child: Text('No data available'));
    }
    
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

  Widget _buildTimeRangeSelector() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Time Range Analysis',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: '7days', label: Text('7 Days')),
                      ButtonSegment(value: '14days', label: Text('14 Days')),
                      ButtonSegment(value: '30days', label: Text('30 Days')),
                    ],
                    selected: {_selectedTimeRange},
                    onSelectionChanged: (Set<String> selection) {
                      setState(() {
                        _selectedTimeRange = selection.first;
                      });
                      _loadData();
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Showing data from ${DateFormat('MMM dd').format(_selectedDate.subtract(Duration(days: _getSelectedDays())))} to ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getSelectedDays() {
    switch (_selectedTimeRange) {
      case '14days': return 14;
      case '30days': return 30;
      default: return 7;
    }
  }

  Widget _buildWeeklyActivityChart() {
    if (_weeklyData == null || _weeklyData!.isEmpty) {
      return Card(
        elevation: 2,
        child: Container(
          height: 300,
          child: Center(
            child: Text('No time series data available'),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bee Activity Over Time',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Daily totals showing entering, exiting, and net change trends',
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
                  gridData: FlGridData(show: true, horizontalInterval: 50),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < _weeklyData!.length) {
                            return Transform.rotate(
                              angle: -0.5,
                              child: Text(
                                DateFormat('MM/dd').format(_weeklyData![index].date),
                                style: TextStyle(fontSize: 10),
                              ),
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
                      spots: _weeklyData!.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          entry.value.totalActivity.toDouble(),
                        );
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue.shade600,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.shade600.withOpacity(0.2),
                      ),
                    ),
                    // Bees entering line
                    LineChartBarData(
                      spots: _weeklyData!.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          entry.value.beesEntering.toDouble(),
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
                      spots: _weeklyData!.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          entry.value.beesExiting.toDouble(),
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
            color: isSolid ? color : Colors.transparent,
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

  Widget _buildBeeActivityTrendChart() {
    if (_weeklyData == null || _weeklyData!.isEmpty) return SizedBox();

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity Trends with Moving Average',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.purple.shade700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Shows daily activity with 3-day moving average trend',
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
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < _weeklyData!.length && index % 2 == 0) {
                            return Text(
                              DateFormat('MM/dd').format(_weeklyData![index].date),
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
                    // Daily activity
                    LineChartBarData(
                      spots: _weeklyData!.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          entry.value.totalActivity.toDouble(),
                        );
                      }).toList(),
                      isCurved: false,
                      color: Colors.blue.shade300,
                      barWidth: 2,
                      dotData: FlDotData(show: true),
                    ),
                    // 3-day moving average
                    LineChartBarData(
                      spots: _calculateMovingAverage(_weeklyData!, 3),
                      isCurved: true,
                      color: Colors.red.shade600,
                      barWidth: 3,
                      dotData: FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem('Daily Activity', Colors.blue.shade300, true),
                _buildLegendItem('3-Day Trend', Colors.red.shade600, true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _calculateMovingAverage(List<TimeSeriesData> data, int windowSize) {
    final List<FlSpot> movingAverage = [];
    
    for (int i = windowSize - 1; i < data.length; i++) {
      double sum = 0;
      for (int j = i - windowSize + 1; j <= i; j++) {
        sum += data[j].totalActivity;
      }
      movingAverage.add(FlSpot(i.toDouble(), sum / windowSize));
    }
    
    return movingAverage;
  }

  Widget _buildEnvironmentalCorrelationChart() {
    if (_weeklyData == null || _weeklyData!.isEmpty) return SizedBox();

    // Filter data points that have both temperature and activity data
    final validDataPoints = _weeklyData!.where((point) => 
      point.temperature != null && point.totalActivity > 0
    ).toList();

    if (validDataPoints.isEmpty) {
      return Card(
        elevation: 2,
        child: Container(
          height: 200,
          child: Center(
            child: Text('No environmental correlation data available'),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Temperature vs Activity Correlation Over Time',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Shows relationship between temperature and bee activity',
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
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      axisNameWidget: Text('Temperature (°C)', style: TextStyle(color: Colors.red)),
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
                    rightTitles: AxisTitles(
                      axisNameWidget: Text('Activity', style: TextStyle(color: Colors.blue)),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            (value * 10).toInt().toString(), // Scale back for display
                            style: TextStyle(fontSize: 10, color: Colors.blue),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < validDataPoints.length && index % 2 == 0) {
                            return Text(
                              DateFormat('MM/dd').format(validDataPoints[index].date),
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
                    // Temperature line
                    LineChartBarData(
                      spots: validDataPoints.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          entry.value.temperature!,
                        );
                      }).toList(),
                      isCurved: true,
                      color: Colors.red.shade600,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.red.shade600.withOpacity(0.1),
                      ),
                    ),
                    // Activity line (scaled for dual axis)
                    LineChartBarData(
                      spots: validDataPoints.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          entry.value.totalActivity / 10.0, // Scale down for display
                        );
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue.shade600,
                      barWidth: 2,
                      dotData: FlDotData(show: true),
                      dashArray: [5, 5],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, size: 16, color: Colors.blue.shade600),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Correlation coefficient: ${_calculateCorrelation(validDataPoints).toStringAsFixed(3)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
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

  double _calculateCorrelation(List<TimeSeriesData> data) {
    if (data.length < 2) return 0.0;

    final tempValues = data.map((d) => d.temperature!).toList();
    final activityValues = data.map((d) => d.totalActivity.toDouble()).toList();

    final tempMean = tempValues.reduce((a, b) => a + b) / tempValues.length;
    final activityMean = activityValues.reduce((a, b) => a + b) / activityValues.length;

    double numerator = 0.0;
    double tempSumSquares = 0.0;
    double activitySumSquares = 0.0;

    for (int i = 0; i < data.length; i++) {
      final tempDiff = tempValues[i] - tempMean;
      final activityDiff = activityValues[i] - activityMean;

      numerator += tempDiff * activityDiff;
      tempSumSquares += tempDiff * tempDiff;
      activitySumSquares += activityDiff * activityDiff;
    }

    final denominator = sqrt(tempSumSquares * activitySumSquares);
    return denominator > 0 ? numerator / denominator : 0.0;
  }

  Widget _buildDailyPatternsHeatmap() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Activity Heatmap',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Activity intensity by day of the week',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 16),
            _buildWeeklyHeatmapGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyHeatmapGrid() {
    if (_weeklyData == null || _weeklyData!.isEmpty) {
      return Container(
        height: 100,
        child: Center(child: Text('No data for heatmap')),
      );
    }

    // Group data by day of week
    final Map<int, List<int>> dayOfWeekActivity = {};
    for (final data in _weeklyData!) {
      final dayOfWeek = data.date.weekday; // 1=Monday, 7=Sunday
      if (!dayOfWeekActivity.containsKey(dayOfWeek)) {
        dayOfWeekActivity[dayOfWeek] = [];
      }
      dayOfWeekActivity[dayOfWeek]!.add(data.totalActivity);
    }

    // Calculate averages
    final Map<int, double> avgActivity = {};
    double maxActivity = 0;
    
    for (final entry in dayOfWeekActivity.entries) {
      final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
      avgActivity[entry.key] = avg;
      if (avg > maxActivity) maxActivity = avg;
    }

    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    return Container(
      height: 120,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (index) {
          final dayOfWeek = index + 1;
          final activity = avgActivity[dayOfWeek] ?? 0;
          final intensity = maxActivity > 0 ? activity / maxActivity : 0;
          
          return Expanded(
            child: Column(
              children: [
                Text(
                  dayNames[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Expanded(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(intensity.toDouble()),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Center(
                      child: Text(
                        activity.toInt().toString(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: intensity > 0.5 ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTimeSeriesInsights() {
    if (_weeklyData == null || _weeklyData!.isEmpty) return SizedBox();

    // Calculate insights
    final totalActivity = _weeklyData!.map((d) => d.totalActivity).reduce((a, b) => a + b);
    final avgDailyActivity = totalActivity / _weeklyData!.length;
    final maxDay = _weeklyData!.reduce((a, b) => a.totalActivity > b.totalActivity ? a : b);
    final minDay = _weeklyData!.reduce((a, b) => a.totalActivity < b.totalActivity ? a : b);
    
    // Calculate trend
    final firstHalf = _weeklyData!.take(_weeklyData!.length ~/ 2).map((d) => d.totalActivity).reduce((a, b) => a + b) / (_weeklyData!.length ~/ 2);
    final secondHalf = _weeklyData!.skip(_weeklyData!.length ~/ 2).map((d) => d.totalActivity).reduce((a, b) => a + b) / (_weeklyData!.length - _weeklyData!.length ~/ 2);
    final trend = secondHalf - firstHalf;

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Time Series Insights',
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
                  child: _buildInsightMetric(
                    'Average Daily',
                    '${avgDailyActivity.toInt()} bees',
                    Icons.trending_flat,
                    Colors.blue.shade600,
                  ),
                ),
                Expanded(
                  child: _buildInsightMetric(
                    'Peak Day',
                    '${maxDay.totalActivity} bees\n${DateFormat('MM/dd').format(maxDay.date)}',
                    Icons.trending_up,
                    Colors.green.shade600,
                  ),
                ),
                Expanded(
                  child: _buildInsightMetric(
                    'Trend',
                    '${trend >= 0 ? '+' : ''}${trend.toInt()} bees',
                    trend >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                    trend >= 0 ? Colors.green.shade600 : Colors.red.shade600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Key Observations:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _generateTimeSeriesInsights(avgDailyActivity, trend, maxDay, minDay),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade700,
                      height: 1.3,
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

  String _generateTimeSeriesInsights(double avgActivity, double trend, TimeSeriesData maxDay, TimeSeriesData minDay) {
    List<String> insights = [];
    
    // Activity level assessment
    if (avgActivity > 100) {
      insights.add('Excellent activity levels indicate a healthy, productive colony.');
    } else if (avgActivity > 50) {
      insights.add('Good activity levels with room for optimization.');
    } else {
      insights.add('Low activity levels may indicate environmental stress or colony issues.');
    }

    // Trend analysis
    if (trend > 20) {
      insights.add('Strong upward trend suggests improving conditions or increasing colony strength.');
    } else if (trend < -20) {
      insights.add('Declining trend may indicate seasonal changes, resource depletion, or colony stress.');
    } else {
      insights.add('Stable activity pattern indicates consistent foraging conditions.');
    }

    // Day comparison
    final dayDiff = maxDay.totalActivity - minDay.totalActivity;
    if (dayDiff > 100) {
      insights.add('High day-to-day variation suggests weather or resource availability impacts.');
    }

    return insights.join(' ');
  }

  Widget _buildInsightMetric(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
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
                      'Last updated: ${_analysisData != null ? DateFormat('HH:mm').format(_analysisData!.lastUpdated) : 'N/A'}',
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

  
  Widget _buildParameterComparisonChart() {
      final data = _analysisData!;
      final correlations = data.correlations;
      final theme = Theme.of(context);
      final isDarkMode = theme.brightness == Brightness.dark;
      final chartTextColor = isDarkMode ? 'white' : '#333';
    
      // Prepare data for the chart
      List<String> hourLabels = [];
      List<double?> temperatureValues = [];
      List<double?> humidityValues = [];
      List<double?> activityValues = [];
    
      // Get hours with data
      final hoursWithData = <int>[];
      for (final activity in data.beeCountData) {
        if (activity.totalActivity > 0) {
          hoursWithData.add(activity.hour);
        }
      }
      hoursWithData.sort();
    
      // Build chart data
      for (final hour in hoursWithData) {
        hourLabels.add('${hour}h');
        temperatureValues.add(correlations.hourlyTemperature[hour]);
        humidityValues.add(correlations.hourlyHumidity[hour]);
        
        final activity = data.beeCountData.firstWhere((a) => a.hour == hour);
        activityValues.add(activity.totalActivity.toDouble());
      }
    
      if (hourLabels.isEmpty) {
        return Card(
          elevation: 2,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Environmental Parameters vs Bee Activity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
                SizedBox(height: 20),
                Center(
                  child: Text(
                    'No environmental data available',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    
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
                child: Echarts(
                  option: '''
                  {
                    backgroundColor: 'transparent',
                    tooltip: {
                      trigger: 'axis',
                      axisPointer: {
                        type: 'cross',
                        label: {
                          backgroundColor: '#6a7985'
                        }
                      },
                      formatter: function(params) {
                        if (!params || params.length === 0) return '';
                        let result = '<div style="font-weight:bold;margin-bottom:5px;">' +
                          params[0].axisValueLabel + '</div>';
                        for (let i = 0; i < params.length; i++) {
                          let item = params[i];
                          if (item.value !== null && item.value !== undefined) {
                            let unit = '';
                            if (item.seriesName === 'Temperature') unit = '°C';
                            else if (item.seriesName === 'Humidity') unit = '%';
                            else unit = ' bees';
                            
                            result += '<div>' + item.marker + ' ' + item.seriesName +
                              ': <span style="font-weight:bold;color:' + item.color + '">' +
                              item.value + unit + '</span></div>';
                          }
                        }
                        return result;
                      }
                    },
                    legend: {
                      data: ['Temperature', 'Humidity', 'Bee Activity'],
                      textStyle: {
                        color: '$chartTextColor',
                        fontSize: 14
                      },
                      itemGap: 20,
                      right: 10,
                      top: 10
                    },
                    grid: {
                      left: '3%',
                      right: '4%',
                      bottom: '3%',
                      containLabel: true
                    },
                    xAxis: {
                      type: 'category',
                      boundaryGap: false,
                      data: ${jsonEncode(hourLabels)},
                      axisLine: {
                        lineStyle: {
                          color: '${isDarkMode ? 'rgba(255,255,255,0.3)' : 'rgba(0,0,0,0.3)'}'
                        }
                      },
                      axisLabel: {
                        color: '$chartTextColor',
                        fontSize: 12
                      }
                    },
                    yAxis: [
                      {
                        type: 'value',
                        name: 'Temperature (°C)',
                        position: 'left',
                        axisLine: {
                          lineStyle: {
                            color: '#EA4335'
                          }
                        },
                        axisLabel: {
                          formatter: '{value}°C',
                          color: '#EA4335',
                          fontSize: 12
                        },
                        splitLine: {
                          lineStyle: {
                            color: '${isDarkMode ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.1)'}'
                          }
                        }
                      },
                      {
                        type: 'value',
                        name: 'Humidity (%) / Bee Activity',
                        position: 'right',
                        axisLine: {
                          lineStyle: {
                            color: '#4285F4'
                          }
                        },
                        axisLabel: {
                          color: '#4285F4',
                          fontSize: 12
                        },
                        splitLine: { show: false }
                      }
                    ],
                    series: [
                      {
                        name: 'Temperature',
                        type: 'line',
                        smooth: true,
                        symbol: 'circle',
                        symbolSize: 6,
                        yAxisIndex: 0,
                        data: ${jsonEncode(temperatureValues)},
                        connectNulls: true,
                        itemStyle: {
                          color: '#EA4335',
                          borderColor: '#fff',
                          borderWidth: 2
                        },
                        lineStyle: {
                          width: 3,
                          color: '#EA4335'
                        }
                      },
                      {
                        name: 'Humidity',
                        type: 'line',
                        smooth: true,
                        symbol: 'diamond',
                        symbolSize: 6,
                        yAxisIndex: 1,
                        data: ${jsonEncode(humidityValues)},
                        connectNulls: true,
                        itemStyle: {
                          color: '#00BCD4',
                          borderColor: '#fff',
                          borderWidth: 2
                        },
                        lineStyle: {
                          width: 2,
                          type: 'dashed',
                          color: '#00BCD4'
                        }
                      },
                      {
                        name: 'Bee Activity',
                        type: 'line',
                        smooth: true,
                        symbol: 'circle',
                        symbolSize: 8,
                        yAxisIndex: 1,
                        data: ${jsonEncode(activityValues)},
                        connectNulls: true,
                        itemStyle: {
                          color: '#4285F4',
                          borderColor: '#fff',
                          borderWidth: 2
                        },
                        lineStyle: {
                          width: 4,
                          color: '#4285F4'
                        },
                        areaStyle: {
                          color: {
                            type: 'linear',
                            x: 0,
                            y: 0,
                            x2: 0,
                            y2: 1,
                            colorStops: [
                              { offset: 0, color: 'rgba(66, 133, 244, 0.3)' },
                              { offset: 1, color: 'rgba(66, 133, 244, 0.1)' }
                            ]
                          }
                        }
                      }
                    ]
                  }
                  ''',
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Correlation Analysis: Temperature-Activity: ${correlations.temperatureActivity.toStringAsFixed(2)} | '
                  'Humidity-Activity: ${correlations.humidityActivity.toStringAsFixed(2)}',
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
      
        // Determine current weight status color
        Color weightColor;
        if (weightAnalysis.currentWeight >= 25) {
          weightColor = Colors.green.shade600;
        } else if (weightAnalysis.currentWeight >= 20) {
          weightColor = Colors.blue.shade600;
        } else if (weightAnalysis.currentWeight >= 15) {
          weightColor = Colors.orange.shade600;
        } else {
          weightColor = Colors.red.shade600;
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
                    Icon(Icons.scale, color: Colors.amber.shade600, size: 22),
                    SizedBox(width: 6),
                    Text(
                      'Weight Analysis & Activity Correlation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14),
                
                // Current Weight Display 
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: weightColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: weightColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.monitor_weight, color: weightColor, size: 32),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Weight',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${weightAnalysis.currentWeight.toStringAsFixed(2)} kg',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: weightColor,
                            ),
                          ),
                        ],
                      ),
                      Spacer(),
                      if (data.weightData.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Last Updated',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              DateFormat('MMM dd, HH:mm').format(data.weightData.first.timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                
                SizedBox(height: 13),
                
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Only show daily change if we have multiple readings
                          if (data.weightData.length > 1)
                            Row(
                              children: [
                                Icon(changeIcon, color: changeColor, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Daily Change: ${weightAnalysis.dailyChange >= 0 ? '+' : ''}${weightAnalysis.dailyChange.toStringAsFixed(2)} kg',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: changeColor,
                                  ),
                                ),
                              ],
                            )
                          else
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info, color: Colors.amber.shade700, size: 16),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Daily change calculation requires multiple weight readings',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.amber.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          SizedBox(height: 6),
                          Text(
                            weightAnalysis.interpretation,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          SizedBox(height: 10),
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
                    SizedBox(width: 14),
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

  
            Widget _buildTemperatureCorrelationChart() {
                final data = _analysisData!;
                final correlations = data.correlations;
                final theme = Theme.of(context);
                final isDarkMode = theme.brightness == Brightness.dark;
                final chartTextColor = isDarkMode ? 'white' : '#333';
              
                // Prepare data for the chart
                List<String> hourLabels = [];
                List<double?> temperatureValues = [];
                List<double?> activityValues = [];
              
                // Get hours with data
                final hoursWithData = <int>[];
                for (final activity in data.beeCountData) {
                  if (activity.totalActivity > 0 && correlations.hourlyTemperature.containsKey(activity.hour)) {
                    hoursWithData.add(activity.hour);
                  }
                }
                hoursWithData.sort();
              
                // Build chart data
                for (final hour in hoursWithData) {
                  hourLabels.add('${hour}h');
                  temperatureValues.add(correlations.hourlyTemperature[hour]);
                  
                  final activity = data.beeCountData.firstWhere((a) => a.hour == hour);
                  activityValues.add(activity.totalActivity.toDouble());
                }
              
                if (hourLabels.isEmpty) {
                  return Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'Temperature vs Bee Activity Correlation',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                          SizedBox(height: 20),
                          Center(
                            child: Text(
                              'No correlation data available',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              
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
                          height: 300,
                          child: Echarts(
                            option: '''
                            {
                              backgroundColor: 'transparent',
                              tooltip: {
                                trigger: 'axis',
                                axisPointer: {
                                  type: 'cross',
                                  label: {
                                    backgroundColor: '#6a7985'
                                  }
                                },
                                formatter: function(params) {
                                  if (!params || params.length === 0) return '';
                                  let result = '<div style="font-weight:bold;margin-bottom:5px;">' +
                                    params[0].axisValueLabel + '</div>';
                                  for (let i = 0; i < params.length; i++) {
                                    let item = params[i];
                                    if (item.value !== null && item.value !== undefined) {
                                      let unit = item.seriesName === 'Temperature' ? '°C' : ' bees';
                                      result += '<div>' + item.marker + ' ' + item.seriesName +
                                        ': <span style="font-weight:bold;color:' + item.color + '">' +
                                        item.value + unit + '</span></div>';
                                    }
                                  }
                                  return result;
                                }
                              },
                              legend: {
                                data: ['Temperature', 'Bee Activity'],
                                textStyle: {
                                  color: '$chartTextColor',
                                  fontSize: 14
                                },
                                itemGap: 20,
                                right: 10,
                                top: 10
                              },
                              grid: {
                                left: '3%',
                                right: '4%',
                                bottom: '3%',
                                containLabel: true
                              },
                              xAxis: {
                                type: 'category',
                                boundaryGap: false,
                                data: ${jsonEncode(hourLabels)},
                                axisLine: {
                                  lineStyle: {
                                    color: '${isDarkMode ? 'rgba(255,255,255,0.3)' : 'rgba(0,0,0,0.3)'}'
                                  }
                                },
                                axisLabel: {
                                  color: '$chartTextColor',
                                  fontSize: 12
                                }
                              },
                              yAxis: [
                                {
                                  type: 'value',
                                  name: 'Temperature (°C)',
                                  position: 'left',
                                  axisLine: {
                                    lineStyle: {
                                      color: '#EA4335'
                                    }
                                  },
                                  axisLabel: {
                                    formatter: '{value}°C',
                                    color: '#EA4335',
                                    fontSize: 12
                                  },
                                  splitLine: {
                                    lineStyle: {
                                      color: '${isDarkMode ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.1)'}'
                                    }
                                  }
                                },
                                {
                                  type: 'value',
                                  name: 'Bee Activity',
                                  position: 'right',
                                  axisLine: {
                                    lineStyle: {
                                      color: '#4285F4'
                                    }
                                  },
                                  axisLabel: {
                                    formatter: '{value}',
                                    color: '#4285F4',
                                    fontSize: 12
                                  },
                                  splitLine: { show: false }
                                }
                              ],
                              series: [
                                {
                                  name: 'Temperature',
                                  type: 'line',
                                  smooth: true,
                                  symbol: 'circle',
                                  symbolSize: 6,
                                  yAxisIndex: 0,
                                  data: ${jsonEncode(temperatureValues)},
                                  connectNulls: true,
                                  itemStyle: {
                                    color: '#EA4335',
                                    borderColor: '#fff',
                                    borderWidth: 2
                                  },
                                  lineStyle: {
                                    width: 3,
                                    color: '#EA4335'
                                  },
                                  areaStyle: {
                                    color: {
                                      type: 'linear',
                                      x: 0,
                                      y: 0,
                                      x2: 0,
                                      y2: 1,
                                      colorStops: [
                                        { offset: 0, color: 'rgba(234, 67, 53, 0.3)' },
                                        { offset: 1, color: 'rgba(234, 67, 53, 0.1)' }
                                      ]
                                    }
                                  }
                                },
                                {
                                  name: 'Bee Activity',
                                  type: 'line',
                                  smooth: true,
                                  symbol: 'circle',
                                  symbolSize: 6,
                                  yAxisIndex: 1,
                                  data: ${jsonEncode(activityValues)},
                                  connectNulls: true,
                                  itemStyle: {
                                    color: '#4285F4',
                                    borderColor: '#fff',
                                    borderWidth: 2
                                  },
                                  lineStyle: {
                                    width: 3,
                                    color: '#4285F4'
                                  },
                                  areaStyle: {
                                    color: {
                                      type: 'linear',
                                      x: 0,
                                      y: 0,
                                      x2: 0,
                                      y2: 1,
                                      colorStops: [
                                        { offset: 0, color: 'rgba(66, 133, 244, 0.3)' },
                                        { offset: 1, color: 'rgba(66, 133, 244, 0.1)' }
                                      ]
                                    }
                                  }
                                }
                              ]
                            }
                            ''',
                          ),
                        ),
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Correlation Strength: ${correlations.temperatureActivity >= 0 ? '+' : ''}${correlations.temperatureActivity.toStringAsFixed(3)} | ${_getCorrelationStrength(correlations.temperatureActivity)}',
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
                  final correlations = data.correlations;
                  final theme = Theme.of(context);
                  final isDarkMode = theme.brightness == Brightness.dark;
                  final chartTextColor = isDarkMode ? 'white' : '#333';
                
                  // Prepare data for the chart
                  List<String> hourLabels = [];
                  List<double?> humidityValues = [];
                  List<double?> activityValues = [];
                
                  // Get hours with data
                  final hoursWithData = <int>[];
                  for (final activity in data.beeCountData) {
                    if (activity.totalActivity > 0 && correlations.hourlyHumidity.containsKey(activity.hour)) {
                      hoursWithData.add(activity.hour);
                    }
                  }
                  hoursWithData.sort();
                
                  // Build chart data
                  for (final hour in hoursWithData) {
                    hourLabels.add('${hour}h');
                    humidityValues.add(correlations.hourlyHumidity[hour]);
                    
                    final activity = data.beeCountData.firstWhere((a) => a.hour == hour);
                    activityValues.add(activity.totalActivity.toDouble());
                  }
                
                  if (hourLabels.isEmpty) {
                    return Card(
                      elevation: 2,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              'Humidity vs Bee Activity Correlation',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.cyan.shade700,
                              ),
                            ),
                            SizedBox(height: 20),
                            Center(
                              child: Text(
                                'No correlation data available',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                
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
                            height: 300,
                            child: Echarts(
                              option: '''
                              {
                                backgroundColor: 'transparent',
                                tooltip: {
                                  trigger: 'axis',
                                  axisPointer: {
                                    type: 'cross',
                                    label: {
                                      backgroundColor: '#6a7985'
                                    }
                                  },
                                  formatter: function(params) {
                                    if (!params || params.length === 0) return '';
                                    let result = '<div style="font-weight:bold;margin-bottom:5px;">' +
                                      params[0].axisValueLabel + '</div>';
                                    for (let i = 0; i < params.length; i++) {
                                      let item = params[i];
                                      if (item.value !== null && item.value !== undefined) {
                                        let unit = item.seriesName === 'Humidity' ? '%' : ' bees';
                                        result += '<div>' + item.marker + ' ' + item.seriesName +
                                          ': <span style="font-weight:bold;color:' + item.color + '">' +
                                          item.value + unit + '</span></div>';
                                      }
                                    }
                                    return result;
                                  }
                                },
                                legend: {
                                  data: ['Humidity', 'Bee Activity'],
                                  textStyle: {
                                    color: '$chartTextColor',
                                    fontSize: 14
                                  },
                                  itemGap: 20,
                                  right: 10,
                                  top: 10
                                },
                                grid: {
                                  left: '3%',
                                  right: '4%',
                                  bottom: '3%',
                                  containLabel: true
                                },
                                xAxis: {
                                  type: 'category',
                                  boundaryGap: false,
                                  data: ${jsonEncode(hourLabels)},
                                  axisLine: {
                                    lineStyle: {
                                      color: '${isDarkMode ? 'rgba(255,255,255,0.3)' : 'rgba(0,0,0,0.3)'}'
                                    }
                                  },
                                  axisLabel: {
                                    color: '$chartTextColor',
                                    fontSize: 12
                                  }
                                },
                                yAxis: [
                                  {
                                    type: 'value',
                                    name: 'Humidity (%)',
                                    position: 'left',
                                    min: 0,
                                    max: 100,
                                    axisLine: {
                                      lineStyle: {
                                        color: '#00BCD4'
                                      }
                                    },
                                    axisLabel: {
                                      formatter: '{value}%',
                                      color: '#00BCD4',
                                      fontSize: 12
                                    },
                                    splitLine: {
                                      lineStyle: {
                                        color: '${isDarkMode ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.1)'}'
                                      }
                                    }
                                  },
                                  {
                                    type: 'value',
                                    name: 'Bee Activity',
                                    position: 'right',
                                    axisLine: {
                                      lineStyle: {
                                        color: '#4285F4'
                                      }
                                    },
                                    axisLabel: {
                                      formatter: '{value}',
                                      color: '#4285F4',
                                      fontSize: 12
                                    },
                                    splitLine: { show: false }
                                  }
                                ],
                                series: [
                                  {
                                    name: 'Humidity',
                                    type: 'line',
                                    smooth: true,
                                    symbol: 'circle',
                                    symbolSize: 6,
                                    yAxisIndex: 0,
                                    data: ${jsonEncode(humidityValues)},
                                    connectNulls: true,
                                    itemStyle: {
                                      color: '#00BCD4',
                                      borderColor: '#fff',
                                      borderWidth: 2
                                    },
                                    lineStyle: {
                                      width: 3,
                                      color: '#00BCD4'
                                    },
                                    areaStyle: {
                                      color: {
                                        type: 'linear',
                                        x: 0,
                                        y: 0,
                                        x2: 0,
                                        y2: 1,
                                        colorStops: [
                                          { offset: 0, color: 'rgba(0, 188, 212, 0.3)' },
                                          { offset: 1, color: 'rgba(0, 188, 212, 0.1)' }
                                        ]
                                      }
                                    }
                                  },
                                  {
                                    name: 'Bee Activity',
                                    type: 'line',
                                    smooth: true,
                                    symbol: 'circle',
                                    symbolSize: 6,
                                    yAxisIndex: 1,
                                    data: ${jsonEncode(activityValues)},
                                    connectNulls: true,
                                    itemStyle: {
                                      color: '#4285F4',
                                      borderColor: '#fff',
                                      borderWidth: 2
                                    },
                                    lineStyle: {
                                      width: 3,
                                      color: '#4285F4'
                                    },
                                    areaStyle: {
                                      color: {
                                        type: 'linear',
                                        x: 0,
                                        y: 0,
                                        x2: 0,
                                        y2: 1,
                                        colorStops: [
                                          { offset: 0, color: 'rgba(66, 133, 244, 0.3)' },
                                          { offset: 1, color: 'rgba(66, 133, 244, 0.1)' }
                                        ]
                                      }
                                    }
                                  }
                                ]
                              }
                              ''',
                            ),
                          ),
                          SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.cyan.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Correlation Strength: ${correlations.humidityActivity >= 0 ? '+' : ''}${correlations.humidityActivity.toStringAsFixed(3)} | ${_getCorrelationStrength(correlations.humidityActivity)}',
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
  
  String _getCorrelationStrength(double correlation) {
      final abs = correlation.abs();
      if (abs >= 0.8) return 'Very Strong';
      if (abs >= 0.6) return 'Strong';
      if (abs >= 0.4) return 'Moderate';
      if (abs >= 0.2) return 'Weak';
      return 'Very Weak';
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

class TimeSeriesData {
  final DateTime date;
  final int beesEntering;
  final int beesExiting;
  final int totalActivity;
  final double? temperature;
  final double? humidity;

  TimeSeriesData({
    required this.date,
    required this.beesEntering,
    required this.beesExiting,
    required this.totalActivity,
    this.temperature,
    this.humidity,
  });
}

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