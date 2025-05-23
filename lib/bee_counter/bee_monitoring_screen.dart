// lib/bee_counter/bee_monitoring_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:HPGM/bee_counter/bee_counter_model.dart';
import 'package:HPGM/bee_counter/bee_count_database.dart';
import 'package:HPGM/bee_counter/bee_monitoring_background_service.dart';
import 'package:fl_chart/fl_chart.dart';

class BeeMonitoringScreen extends StatefulWidget {
  final String hiveId;

  const BeeMonitoringScreen({Key? key, required this.hiveId}) : super(key: key);

  @override
  _BeeMonitoringScreenState createState() => _BeeMonitoringScreenState();
}

class _BeeMonitoringScreenState extends State<BeeMonitoringScreen> {
  final AutomaticBeeMonitoringService _automaticService = AutomaticBeeMonitoringService();

  List<BeeCount> _beeCounts = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
    
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _loadBeeCounts();
    });
  }

  Future<void> _initializeScreen() async {
    // Ensure automatic service is running
    await _automaticService.initializeAndStart();
    await _loadBeeCounts();
  }

  Future<void> _loadBeeCounts() async {
    try {
      final counts = await BeeCountDatabase.instance.readBeeCountsByDate(_selectedDate);
      
      // Filter by hive ID
      final hiveCounts = counts.where((count) => count.hiveId == widget.hiveId).toList();
      
      // Sort by timestamp
      hiveCounts.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (mounted) {
        setState(() {
          _beeCounts = hiveCounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading bee counts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Map<String, BeeCount> _groupCountsByTimePeriod() {
    final Map<String, BeeCount> result = {
      'morning': BeeCount(
        hiveId: widget.hiveId,
        beesEntering: 0,
        beesExiting: 0,
        timestamp: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 7),
      ),
      'noon': BeeCount(
        hiveId: widget.hiveId,
        beesEntering: 0,
        beesExiting: 0,
        timestamp: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 12),
      ),
      'evening': BeeCount(
        hiveId: widget.hiveId,
        beesEntering: 0,
        beesExiting: 0,
        timestamp: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 18),
      ),
    };

    // Aggregate counts by time period
    for (final count in _beeCounts) {
      final hour = count.timestamp.hour;
      String period;
      
      if (hour >= 5 && hour < 10) {
        period = 'morning';
      } else if (hour >= 10 && hour < 15) {
        period = 'noon';
      } else if (hour >= 15 && hour < 20) {
        period = 'evening';
      } else {
        continue;
      }

      final existing = result[period]!;
      result[period] = BeeCount(
        hiveId: widget.hiveId,
        beesEntering: existing.beesEntering + count.beesEntering,
        beesExiting: existing.beesExiting + count.beesExiting,
        timestamp: count.timestamp,
        confidence: (existing.confidence + count.confidence) / 2,
      );
    }

    return result;
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _isLoading = true;
      });
      _loadBeeCounts();
    }
  }

  Widget _buildActivityChart(Map<String, BeeCount> timeBasedCounts) {
    final List<BarChartGroupData> barGroups = [];
    final periods = ['morning', 'noon', 'evening'];

    for (int i = 0; i < periods.length; i++) {
      final period = periods[i];
      final count = timeBasedCounts[period]!;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: count.beesEntering.toDouble(),
              color: Colors.green,
              width: 20,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            BarChartRodData(
              toY: count.beesExiting.toDouble(),
              color: Colors.orange,
              width: 20,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _calculateMaxY(timeBasedCounts),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final period = periods[group.x.toInt()];
              final count = timeBasedCounts[period]!;
              final label = rodIndex == 0 ? 'Entering' : 'Exiting';
              final value = rodIndex == 0 ? count.beesEntering : count.beesExiting;
              return BarTooltipItem(
                '$label: $value',
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final titles = ['Morning', 'Noon', 'Evening'];
                return Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    titles[value.toInt()],
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value == 0) return SizedBox.shrink();
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                );
              },
              reservedSize: 35,
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          horizontalInterval: 10,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1);
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }

  double _calculateMaxY(Map<String, BeeCount> timeBasedCounts) {
    double maxY = 10;
    for (final count in timeBasedCounts.values) {
      if (count.beesEntering > maxY) maxY = count.beesEntering.toDouble();
      if (count.beesExiting > maxY) maxY = count.beesExiting.toDouble();
    }
    return (maxY * 1.2).ceilToDouble();
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeBasedCounts = _groupCountsByTimePeriod();
    
    // Calculate daily totals
    int totalEntering = 0;
    int totalExiting = 0;
    for (final count in _beeCounts) {
      totalEntering += count.beesEntering;
      totalExiting += count.beesExiting;
    }
    final netChange = totalEntering - totalExiting;

    return Scaffold(
      appBar: AppBar(
        title: Text('Hive ${widget.hiveId} Activity'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: _selectDate,
            tooltip: 'Select date',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBeeCounts,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date header
                    Center(
                      child: Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    SizedBox(height: 8),
                    if (_beeCounts.isEmpty)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            children: [
                              Icon(Icons.hourglass_empty, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No data available yet',
                                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Videos are processed automatically at 7AM, 12PM, and 6PM',
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      // Summary cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'Bees In',
                              totalEntering.toString(),
                              Icons.arrow_downward,
                              Colors.green,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: _buildSummaryCard(
                              'Bees Out',
                              totalExiting.toString(),
                              Icons.arrow_upward,
                              Colors.orange,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: _buildSummaryCard(
                              'Net Change',
                              '${netChange >= 0 ? '+' : ''}$netChange',
                              netChange >= 0 ? Icons.trending_up : Icons.trending_down,
                              netChange >= 0 ? Colors.blue : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                      
                      // Activity chart
                      Container(
                        height: 250,
                        padding: EdgeInsets.only(top: 16),
                        child: _buildActivityChart(timeBasedCounts),
                      ),
                      SizedBox(height: 24),
                      
                      // Time period details
                      Text(
                        'Activity by Time Period',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 16),
                      
                      _buildPeriodCard('Morning', '5AM - 10AM', timeBasedCounts['morning']!, Icons.wb_sunny),
                      SizedBox(height: 8),
                      _buildPeriodCard('Noon', '10AM - 3PM', timeBasedCounts['noon']!, Icons.wb_sunny_outlined),
                      SizedBox(height: 8),
                      _buildPeriodCard('Evening', '3PM - 8PM', timeBasedCounts['evening']!, Icons.nights_stay),
                      
                      SizedBox(height: 16),
                      Center(
                        child: Text(
                          'Last updated: ${DateFormat('HH:mm').format(DateTime.now())}',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodCard(String period, String time, BeeCount count, IconData icon) {
    final hasData = count.beesEntering > 0 || count.beesExiting > 0;
    
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: hasData ? Colors.amber.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
          child: Icon(icon, color: hasData ? Colors.amber : Colors.grey),
        ),
        title: Text(period, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(time),
        trailing: hasData
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.arrow_downward, color: Colors.green, size: 16),
                          SizedBox(width: 4),
                          Text('${count.beesEntering}', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.arrow_upward, color: Colors.orange, size: 16),
                          SizedBox(width: 4),
                          Text('${count.beesExiting}', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  if (count.confidence > 0) ...[
                    SizedBox(width: 16),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${count.confidence.toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 12, color: Colors.purple),
                      ),
                    ),
                  ],
                ],
              )
            : Text('No data', style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}