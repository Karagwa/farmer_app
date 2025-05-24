import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:farmer_app/bee_counter/bee_counter_model.dart';
import 'package:farmer_app/bee_counter/bee_count_database.dart';
import 'package:farmer_app/bee_counter/bee_monitoring_background_service.dart';
import 'package:farmer_app/bee_counter/server_video_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:farmer_app/bee_counter/process_videos_widget.dart';
import 'package:farmer_app/bee_counter/bee_activity_correlation_screen.dart';
import 'package:farmer_app/bee_counter/integrated_hive_monitoring.dart';

class BeeMonitoringScreen extends StatefulWidget {
  final String hiveId;

  const BeeMonitoringScreen({
    Key? key,
    required this.hiveId,
  }) : super(key: key);

  @override
  _BeeMonitoringScreenState createState() => _BeeMonitoringScreenState();
}

class _BeeMonitoringScreenState extends State<BeeMonitoringScreen> {
  final BeeMonitoringService _monitoringService = BeeMonitoringService();
  final ServerVideoService _serverVideoService = ServerVideoService();

  List<BeeCount> _beeCounts = [];
  bool _isLoading = true;
  String _statusMessage = 'Initializing...';
  bool _isServiceRunning = false;
  StreamSubscription? _serviceStatusSubscription;

  // Selected date for filtering
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializeBackgroundService();
    _loadBeeCounts();
    _setupServiceStatusListener();
  }

  // Initialize the background service
  Future<void> _initializeBackgroundService() async {
    setState(() {
      _statusMessage = 'Initializing background service...';
    });

    await _monitoringService.initializeService();
    final isRunning = await _monitoringService.isServiceRunning();

    setState(() {
      _isServiceRunning = isRunning;
      _statusMessage = isRunning
          ? 'Bee monitoring service is running'
          : 'Bee monitoring service is not running';
    });
  }

  // Setup listener for service status updates
  void _setupServiceStatusListener() {
    // Use the service's built-in messaging system through your BeeMonitoringService instance
    _monitoringService.getService().on('update').listen((event) {
      if (event != null && event is Map<String, dynamic>) {
        setState(() {
          _statusMessage = event['status'] ?? 'Unknown status';

          // If it's a result update, refresh bee counts
          if (event.containsKey('result')) {
            _loadBeeCounts();
          }
        });
      }
    });
  }

  void _showVideoProcessingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // User must tap button to close dialog
      builder: (context) => AlertDialog(
        title: const Text('Process Bee Videos'),
        content: SizedBox(
          width: double.maxFinite,
          height: 500, // Adjust height as needed
          child: ProcessVideosWidget(
            hiveId: widget.hiveId,
            date: _selectedDate,
            force: false,
            onProcessingComplete: () {
              // Reload data after processing
              _loadBeeCounts();
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Load bee counts from database
  Future<void> _loadBeeCounts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load bee counts for the selected date
      final counts =
          await BeeCountDatabase.instance.readBeeCountsByDate(_selectedDate);

      setState(() {
        _beeCounts = counts;
        _isLoading = false;
        _statusMessage = counts.isEmpty
            ? 'No bee activity data found for ${DateFormat('MMMM d, yyyy').format(_selectedDate)}'
            : 'Loaded ${counts.length} bee activity records';
      });
    } catch (e) {
      print('Error loading bee counts: $e');
      setState(() {
        _statusMessage = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  // Group bee counts by time period (morning, noon, evening)
  Map<String, BeeCount> _groupCountsByTimePeriod() {
    final Map<String, BeeCount> result = {
      'morning': BeeCount(
        hiveId: widget.hiveId,
        beesEntering: 0,
        beesExiting: 0,
        timestamp: DateTime(
            _selectedDate.year, _selectedDate.month, _selectedDate.day, 7),
      ),
      'noon': BeeCount(
        hiveId: widget.hiveId,
        beesEntering: 0,
        beesExiting: 0,
        timestamp: DateTime(
            _selectedDate.year, _selectedDate.month, _selectedDate.day, 12),
      ),
      'evening': BeeCount(
        hiveId: widget.hiveId,
        beesEntering: 0,
        beesExiting: 0,
        timestamp: DateTime(
            _selectedDate.year, _selectedDate.month, _selectedDate.day, 18),
      ),
    };

    for (final count in _beeCounts) {
      final hour = count.timestamp.hour;

      // Assign to morning, noon, or evening based on time
      if (hour >= 5 && hour < 10) {
        result['morning'] = count;
      } else if (hour >= 10 && hour < 15) {
        result['noon'] = count;
      } else if (hour >= 15 && hour < 20) {
        result['evening'] = count;
      }
    }

    return result;
  }

  // Toggle the background service
  Future<void> _toggleService() async {
    if (_isServiceRunning) {
      await _monitoringService.stopService();
    } else {
      await _monitoringService.startService();
    }

    final isRunning = await _monitoringService.isServiceRunning();
    setState(() {
      _isServiceRunning = isRunning;
      _statusMessage = isRunning
          ? 'Bee monitoring service started'
          : 'Bee monitoring service stopped';
    });
  }

  // Manually check for videos now
  Future<void> _checkForVideosNow() async {
    setState(() {
      _statusMessage = 'Checking for new videos...';
      _isLoading = true;
    });

    try {
      // Fetch videos from server
      final videos = await _serverVideoService.fetchVideosFromServer(
        widget.hiveId,
        fetchAllIntervals: true,
      );

      if (videos.isEmpty) {
        setState(() {
          _statusMessage = 'No videos found on server';
          _isLoading = false;
        });
        return;
      }

      // Process each video
      int processedCount = 0;
      for (final video in videos) {
        setState(() {
          _statusMessage =
              'Processing video ${processedCount + 1}/${videos.length}: ${video.id}';
        });

        await _serverVideoService.processServerVideo(
          video,
          hiveId: widget.hiveId,
          onStatusUpdate: (status) {
            setState(() {
              _statusMessage = status;
            });
          },
        );

        processedCount++;
      }

      // Reload bee counts
      await _loadBeeCounts();

      setState(() {
        _statusMessage = 'Processed $processedCount videos';
      });
    } catch (e) {
      print('Error checking for videos: $e');
      setState(() {
        _statusMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  // Pick a date to view bee activity
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadBeeCounts();
    }
  }

  // Build a chart of bee activity
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
              width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            BarChartRodData(
              toY: count.beesExiting.toDouble(),
              color: Colors.orange,
              width: 16,
              borderRadius: const BorderRadius.only(
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
            tooltipBgColor: Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final period = periods[group.x.toInt()];
              final count = timeBasedCounts[period]!;
              final String label = rodIndex == 0 ? 'Entering' : 'Exiting';
              final int value =
                  rodIndex == 0 ? count.beesEntering : count.beesExiting;
              return BarTooltipItem(
                '$label: $value',
                const TextStyle(color: Colors.white),
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
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    titles[value.toInt()],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                );
              },
              reservedSize: 28,
            ),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          horizontalInterval: 10,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.3),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }

  // Calculate max Y value for chart
  double _calculateMaxY(Map<String, BeeCount> timeBasedCounts) {
    double maxY = 10; // Default minimum height

    for (final count in timeBasedCounts.values) {
      if (count.beesEntering > maxY) maxY = count.beesEntering.toDouble();
      if (count.beesExiting > maxY) maxY = count.beesExiting.toDouble();
    }

    // Add some room at the top
    return (maxY * 1.2).ceilToDouble();
  }

  // Build time period reports
  List<Widget> _buildTimePeriodReports(Map<String, BeeCount> timeBasedCounts) {
    final List<Widget> widgets = [];

    final periods = [
      {'key': 'morning', 'name': 'Morning (5AM-10AM)', 'icon': Icons.wb_sunny},
      {
        'key': 'noon',
        'name': 'Noon (10AM-3PM)',
        'icon': Icons.wb_sunny_outlined
      },
      {
        'key': 'evening',
        'name': 'Evening (3PM-8PM)',
        'icon': Icons.nights_stay
      },
    ];

    for (final period in periods) {
      final key = period['key'] as String;
      final name = period['name'] as String;
      final icon = period['icon'] as IconData;
      final count = timeBasedCounts[key]!;

      widgets.add(
        Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildMetricRow(
                  'Bees Entering:',
                  count.beesEntering.toString(),
                  Icons.arrow_downward,
                  Colors.green,
                ),
                const SizedBox(height: 8),
                _buildMetricRow(
                  'Bees Exiting:',
                  count.beesExiting.toString(),
                  Icons.arrow_upward,
                  Colors.orange,
                ),
                const SizedBox(height: 8),
                _buildMetricRow(
                  'Net Change:',
                  count.netChange.toString(),
                  count.netChange >= 0 ? Icons.add : Icons.remove,
                  count.netChange >= 0 ? Colors.green : Colors.red,
                ),
                const SizedBox(height: 8),
                _buildMetricRow(
                  'Total Activity:',
                  count.totalActivity.toString(),
                  Icons.sync,
                  Colors.blue,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  // Build a metric row
  Widget _buildMetricRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  // Build status bar
  Widget _buildStatusBar() {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Icon(
            _isServiceRunning ? Icons.circle : Icons.circle_outlined,
            color: _isServiceRunning ? Colors.green : Colors.red,
            size: 12,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage,
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _serviceStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bee Activity Monitor - Hive ${widget.hiveId}'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadBeeCounts,
            tooltip: 'Refresh data',
          ),
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: _selectDate,
            tooltip: 'Select date',
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildStatusBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleService,
        child: Icon(_isServiceRunning ? Icons.pause : Icons.play_arrow),
        tooltip: _isServiceRunning
            ? 'Stop bee monitoring service'
            : 'Start bee monitoring service',
      ),
      persistentFooterButtons: [
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BeeActivityCorrelationScreen(
                  hiveId: widget.hiveId,
                ),
              ),
            );
          },
          icon: const Icon(Icons.analytics_outlined),
          label: const Text('Activity Correlations'),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading bee activity data...')
          ],
        ),
      );
    }

    if (_beeCounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 64,
              color: Colors.amber,
            ),
            const SizedBox(height: 16),
            Text(
              'No bee activity data for ${DateFormat('MMMM d, yyyy').format(_selectedDate)}',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _checkForVideosNow,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check for videos now'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _showVideoProcessingDialog,
                  icon: const Icon(Icons.settings),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  label: const Text('Process Videos'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'There might be videos available on the server for this date. Click "Check for videos now" to verify.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    // Group bee counts by time period
    final Map<String, BeeCount> timeBasedCounts = _groupCountsByTimePeriod();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bee Activity for ${DateFormat('MMMM d, yyyy').format(_selectedDate)}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),

            // Show bee activity chart
            Container(
              height: 220,
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildActivityChart(timeBasedCounts),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            // Display time period reports
            ..._buildTimePeriodReports(timeBasedCounts),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Add button to navigate to correlation analysis
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BeeActivityCorrelationScreen(
                        hiveId: widget.hiveId,
                      ),
                    ),                  );
                },
                icon: const Icon(Icons.analytics),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[800],
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                label: const Text('View Activity Correlations'),
              ),
            ),

            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => IntegratedHiveMonitoring(
                        hiveId: widget.hiveId,
                        token: '',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.insights),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                label: const Text('Enhanced Analytics Dashboard'),
              ),
            ),

            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'See detailed correlations between bee activity and environmental factors like temperature, humidity, and hive weight.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
