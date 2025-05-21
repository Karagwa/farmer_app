import 'dart:async';
import 'package:flutter/material.dart';
import 'package:HPGM/notifications/notification_model.dart';
import 'package:HPGM/hive_model.dart';
import 'package:HPGM/notifications/notification_service.dart';
import 'package:HPGM/notifications/hive_data_service.dart';
import 'package:HPGM/notifications/weather_data_service.dart';
import 'package:HPGM/notifications/weather_model.dart';
import 'package:HPGM/notifications/notification_card.dart';
import 'package:HPGM/notifications/hive_status_card.dart';
import 'package:HPGM/Services/weather_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  final NotificationService _notificationService = NotificationService();
  final HiveDataService _hiveDataService = HiveDataService();
  final WeatherService _weatherService = WeatherService();

  late TabController _tabController;
  List<HiveNotification> _notifications = [];
  Hive? _currentHive;
  WeatherData? _weatherData;

  StreamSubscription? _notificationSubscription;
  StreamSubscription? _hiveSubscription;

  bool _isLoading = true;
  String? _errorMessage;

  // Filter options
  NotificationType? _selectedType;
  NotificationSeverity? _selectedSeverity;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize notification service
      await _notificationService.initialize();

      // Subscribe to notifications
      _notificationSubscription = _notificationService.notificationsStream
          .listen((notifications) {
            setState(() {
              _notifications = notifications;
            });
          });

      // Subscribe to hive data
      _hiveSubscription = _hiveDataService.hiveStream.listen((hive) {
        setState(() {
          _currentHive = hive;
          _isLoading = false;
        });

        // Check hive data for notifications
        _notificationService.checkHiveData(hive);

        // Fetch weather data based on hive location
        _fetchWeatherData(hive);
      });

      // Start monitoring hive data
      _hiveDataService.startMonitoring(
        refreshInterval: const Duration(minutes: 1),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchWeatherData(Hive hive) async {
    try {
      // Parse latitude and longitude from hive data
      final latitude = double.tryParse(hive.latitude) ?? 0.0;
      final longitude = double.tryParse(hive.longitude) ?? 0.0;

      final weatherData = await _weatherService.getWeatherData(
        latitude,
        longitude,
      );
      setState(() {
        _weatherData = weatherData;
      });

      // Check weather data for notifications
      _notificationService.checkWeatherData(weatherData);
    } catch (e) {
      print('Error fetching weather data: $e');
    }
  }

  List<HiveNotification> get _filteredNotifications {
    return _notifications.where((notification) {
      bool typeMatch =
          _selectedType == null || notification.type == _selectedType;
      bool severityMatch =
          _selectedSeverity == null ||
          notification.severity == _selectedSeverity;
      return typeMatch && severityMatch;
    }).toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notificationSubscription?.cancel();
    _hiveSubscription?.cancel();
    _hiveDataService.dispose();
    _notificationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beehive Monitoring'),
        backgroundColor: Colors.amber[700],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Notifications'), Tab(text: 'Hive Status')],
          indicatorColor: Colors.white,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() {
                _isLoading = true;
              });
              await _hiveDataService.fetchHiveData(1);
              setState(() {
                _isLoading = false;
              });
            },
          ),
          PopupMenuButton<void>(
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    child: const Text('Mark all as read'),
                    onTap: () {
                      _notificationService.markAllAsRead();
                    },
                  ),
                  PopupMenuItem(
                    child: const Text('Clear all notifications'),
                    onTap: () {
                      _notificationService.clearNotifications();
                    },
                  ),
                ],
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              )
              : _errorMessage != null
              ? Center(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              )
              : TabBarView(
                controller: _tabController,
                children: [_buildNotificationsTab(), _buildHiveStatusTab()],
              ),
    );
  }

  Widget _buildNotificationsTab() {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child:
              _filteredNotifications.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                  : RefreshIndicator(
                    onRefresh: () async {
                      await _hiveDataService.fetchHiveData(1);
                    },
                    child: ListView.builder(
                      itemCount: _filteredNotifications.length,
                      itemBuilder: (context, index) {
                        final notification = _filteredNotifications[index];
                        return NotificationCard(
                          notification: notification,
                          onTap: () {
                            _notificationService.markAsRead(notification.id);
                          },
                        );
                      },
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          const Text('Filter: ', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTypeFilterChip(null, 'All Types'),
                  _buildTypeFilterChip(
                    NotificationType.temperature,
                    'Temperature',
                  ),
                  _buildTypeFilterChip(NotificationType.humidity, 'Humidity'),
                  _buildTypeFilterChip(NotificationType.weight, 'Weight'),
                  _buildTypeFilterChip(NotificationType.weather, 'Weather'),
                  _buildTypeFilterChip(NotificationType.carbonDioxide, 'CO₂'),
                  const SizedBox(width: 8),
                  _buildSeverityFilterChip(null, 'All Severities'),
                  _buildSeverityFilterChip(NotificationSeverity.high, 'High'),
                  _buildSeverityFilterChip(
                    NotificationSeverity.medium,
                    'Medium',
                  ),
                  _buildSeverityFilterChip(NotificationSeverity.low, 'Low'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilterChip(NotificationType? type, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: _selectedType == type,
        onSelected: (selected) {
          setState(() {
            _selectedType = selected ? type : null;
          });
        },
        backgroundColor: Colors.grey[200],
        selectedColor: Colors.amber[200],
      ),
    );
  }

  Widget _buildSeverityFilterChip(
    NotificationSeverity? severity,
    String label,
  ) {
    Color? chipColor;
    if (severity != null) {
      switch (severity) {
        case NotificationSeverity.high:
          chipColor = Colors.red[100];
          break;
        case NotificationSeverity.medium:
          chipColor = Colors.orange[100];
          break;
        case NotificationSeverity.low:
          chipColor = Colors.blue[100];
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: _selectedSeverity == severity,
        onSelected: (selected) {
          setState(() {
            _selectedSeverity = selected ? severity : null;
          });
        },
        backgroundColor: Colors.grey[200],
        selectedColor: chipColor ?? Colors.amber[200],
      ),
    );
  }

  Widget _buildHiveStatusTab() {
    if (_currentHive == null) {
      return const Center(child: Text('No hive data available'));
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HiveStatusCard(hive: _currentHive!, weatherData: _weatherData),
            const SizedBox(height: 16),
            _buildThresholdsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alert Thresholds',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildThresholdItem(
              'Temperature',
              '20°C - 35°C',
              '15°C - 40°C',
              Icons.thermostat,
              Colors.orange,
            ),
            const Divider(),
            _buildThresholdItem(
              'Humidity',
              '40% - 80%',
              '30% - 90%',
              Icons.water_drop,
              Colors.blue,
            ),
            const Divider(),
            _buildThresholdItem(
              'Weight',
              '10kg - 30kg',
              '5kg - 35kg',
              Icons.scale,
              Colors.green,
            ),
            const Divider(),
            _buildThresholdItem(
              'Carbon Dioxide',
              '400ppm - 5000ppm',
              '300ppm - 8000ppm',
              Icons.co2,
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdItem(
    String title,
    String warningRange,
    String criticalRange,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildThresholdLabel(
                      'Warning',
                      Colors.orange,
                      warningRange,
                    ),
                    const SizedBox(width: 16),
                    _buildThresholdLabel('Critical', Colors.red, criticalRange),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdLabel(String label, Color color, String value) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: $value',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }
}
