import 'dart:async';
import 'dart:async' show StreamController;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:HPGM/analytics/foraging_advisory_service.dart';
import 'package:HPGM/analytics/navigation_helper.dart';

class NotificationsScreen extends StatefulWidget {
  final String? hiveId;

  const NotificationsScreen({Key? key, this.hiveId}) : super(key: key);

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  String _errorMessage = '';
  late TabController _tabController;
  Timer? _refreshTimer;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadNotifications();
    
    // Auto-refresh every 5 minutes
    _refreshTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      _loadNotifications();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final notifications = await _generateNotificationsFromAdvisorySystem();
      
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading notifications: $e';
        });
      }
    }
  }

  Future<List<NotificationItem>> _generateNotificationsFromAdvisorySystem() async {
    final List<NotificationItem> notifications = [];
    final advisoryService = EnhancedForagingAdvisoryService();
    
    try {
      // Get foraging analysis for the current date
      final analysisData = await advisoryService.getDailyForagingAnalysis(
        widget.hiveId ?? '1',
        DateTime.now(),
      );

      if (analysisData != null) {
        // Convert recommendations to notifications
        for (final recommendation in analysisData.recommendations) {
          notifications.add(NotificationItem(
            id: recommendation.id,
            title: recommendation.title,
            message: recommendation.description,
            type: _getNotificationTypeFromPriority(recommendation.priority),
            severity: _getSeverityFromPriority(recommendation.priority),
            timestamp: DateTime.now(),
            source: 'Advisory System',
            hiveId: analysisData.hiveId,
            isRead: false,
            actionRequired: recommendation.priority == 'Critical' || recommendation.priority == 'High',
            category: 'Foraging',
            additionalData: {
              'timeRelevance': recommendation.timeRelevance,
              'foragingImpact': recommendation.foragingImpact,
              'actionItems': recommendation.actionItems,
              'scientificBasis': recommendation.scientificBasis,
            },
          ));
        }

        // Generate parameter-based alerts
        notifications.addAll(await _generateParameterAlerts(analysisData));
        
        // Generate pattern-based alerts
        notifications.addAll(_generatePatternAlerts(analysisData));
      }

      // Add some sample system notifications
      notifications.addAll(_generateSystemNotifications());

    } catch (e) {
      print('Error generating notifications: $e');
    }

    // Sort by timestamp (newest first) and severity
    notifications.sort((a, b) {
      final severityOrder = {'Critical': 0, 'High': 1, 'Medium': 2, 'Low': 3, 'Info': 4};
      final aSeverity = severityOrder[a.severity] ?? 4;
      final bSeverity = severityOrder[b.severity] ?? 4;
      
      if (aSeverity != bSeverity) {
        return aSeverity.compareTo(bSeverity);
      }
      return b.timestamp.compareTo(a.timestamp);
    });

    return notifications;
  }

  Future<List<NotificationItem>> _generateParameterAlerts(DailyForagingAnalysis analysisData) async {
    final List<NotificationItem> alerts = [];
    final now = DateTime.now();

    // Temperature alerts
    if (analysisData.temperatureData.isNotEmpty) {
      final currentTemp = analysisData.temperatureData.first.value;
      
      if (currentTemp > 35.0) {
        alerts.add(NotificationItem(
          id: 'temp_critical_${now.millisecondsSinceEpoch}',
          title: 'Critical Temperature Alert',
          message: 'Temperature is ${currentTemp.toStringAsFixed(1)}°C - immediate action required to prevent heat stress',
          type: NotificationType.alert,
          severity: 'Critical',
          timestamp: now,
          source: 'Temperature Sensor',
          hiveId: analysisData.hiveId,
          isRead: false,
          actionRequired: true,
          category: 'Environmental',
          additionalData: {'currentValue': currentTemp, 'threshold': 35.0, 'unit': '°C'},
        ));
      } else if (currentTemp > 32.0) {
        alerts.add(NotificationItem(
          id: 'temp_warning_${now.millisecondsSinceEpoch}',
          title: 'High Temperature Warning',
          message: 'Temperature is ${currentTemp.toStringAsFixed(1)}°C - approaching heat stress levels',
          type: NotificationType.warning,
          severity: 'High',
          timestamp: now,
          source: 'Temperature Sensor',
          hiveId: analysisData.hiveId,
          isRead: false,
          actionRequired: true,
          category: 'Environmental',
          additionalData: {'currentValue': currentTemp, 'threshold': 32.0, 'unit': '°C'},
        ));
      } else if (currentTemp < 10.0) {
        alerts.add(NotificationItem(
          id: 'temp_cold_${now.millisecondsSinceEpoch}',
          title: 'Low Temperature Alert',
          message: 'Temperature is ${currentTemp.toStringAsFixed(1)}°C - foraging activity severely limited',
          type: NotificationType.warning,
          severity: 'High',
          timestamp: now,
          source: 'Temperature Sensor',
          hiveId: analysisData.hiveId,
          isRead: false,
          actionRequired: true,
          category: 'Environmental',
          additionalData: {'currentValue': currentTemp, 'threshold': 10.0, 'unit': '°C'},
        ));
      }
    }

    // Weight alerts
    if (analysisData.weightAnalysis.dailyChange <= -0.1) {
      alerts.add(NotificationItem(
        id: 'weight_loss_${now.millisecondsSinceEpoch}',
        title: 'Colony Weight Loss Alert',
        message: 'Daily weight loss of ${analysisData.weightAnalysis.dailyChange.toStringAsFixed(2)}kg detected',
        type: NotificationType.alert,
        severity: 'Critical',
        timestamp: now,
        source: 'Weight Sensor',
        hiveId: analysisData.hiveId,
        isRead: false,
        actionRequired: true,
        category: 'Colony Health',
        additionalData: {
          'dailyChange': analysisData.weightAnalysis.dailyChange,
          'interpretation': analysisData.weightAnalysis.interpretation,
        },
      ));
    }

    // Activity alerts
    final totalActivity = analysisData.beeCountData.fold(0, (sum, hour) => sum + hour.totalActivity);
    if (totalActivity < 100) {
      alerts.add(NotificationItem(
        id: 'low_activity_${now.millisecondsSinceEpoch}',
        title: 'Low Foraging Activity',
        message: 'Daily activity only ${totalActivity} bee movements - below normal levels',
        type: NotificationType.warning,
        severity: 'High',
        timestamp: now,
        source: 'Activity Monitor',
        hiveId: analysisData.hiveId,
        isRead: false,
        actionRequired: true,
        category: 'Colony Activity',
        additionalData: {'totalActivity': totalActivity, 'threshold': 100},
      ));
    }

    return alerts;
  }

  List<NotificationItem> _generatePatternAlerts(DailyForagingAnalysis analysisData) {
    final List<NotificationItem> alerts = [];
    final now = DateTime.now();

    // Nectar flow alerts
    final nectarFlow = analysisData.foragingPatterns.nectarFlowAnalysis;
    if (nectarFlow.intensity == 'Very Low' || nectarFlow.intensity == 'None') {
      alerts.add(NotificationItem(
        id: 'nectar_flow_${now.millisecondsSinceEpoch}',
        title: 'Poor Nectar Flow Detected',
        message: nectarFlow.reasoning,
        type: NotificationType.warning,
        severity: 'Medium',
        timestamp: now,
        source: 'Pattern Analysis',
        hiveId: analysisData.hiveId,
        isRead: false,
        actionRequired: true,
        category: 'Foraging Patterns',
        additionalData: {'intensity': nectarFlow.intensity, 'status': nectarFlow.status},
      ));
    }

    // Foraging distance alerts
    final distantForaging = analysisData.foragingPatterns.foragingDistanceIndicators.values
        .where((indicator) => indicator.distanceAssessment.contains('Distant')).length;
    
    if (distantForaging > 3) {
      alerts.add(NotificationItem(
        id: 'distant_foraging_${now.millisecondsSinceEpoch}',
        title: 'Distant Foraging Pattern',
        message: 'Bees are traveling long distances for forage during $distantForaging hours',
        type: NotificationType.info,
        severity: 'Medium',
        timestamp: now,
        source: 'Pattern Analysis',
        hiveId: analysisData.hiveId,
        isRead: false,
        actionRequired: false,
        category: 'Foraging Patterns',
        additionalData: {'distantHours': distantForaging},
      ));
    }

    return alerts;
  }

  List<NotificationItem> _generateSystemNotifications() {
    final now = DateTime.now();
    return [
      NotificationItem(
        id: 'system_update_${now.millisecondsSinceEpoch}',
        title: 'System Update Available',
        message: 'New features available for enhanced hive monitoring',
        type: NotificationType.info,
        severity: 'Info',
        timestamp: now.subtract(Duration(hours: 2)),
        source: 'System',
        hiveId: 'system',
        isRead: false,
        actionRequired: false,
        category: 'System',
        additionalData: {},
      ),
      NotificationItem(
        id: 'data_sync_${now.millisecondsSinceEpoch}',
        title: 'Data Synchronization Complete',
        message: 'All hive data has been successfully synchronized',
        type: NotificationType.success,
        severity: 'Info',
        timestamp: now.subtract(Duration(minutes: 30)),
        source: 'System',
        hiveId: 'system',
        isRead: true,
        actionRequired: false,
        category: 'System',
        additionalData: {},
      ),
    ];
  }

  NotificationType _getNotificationTypeFromPriority(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return NotificationType.alert;
      case 'high':
        return NotificationType.warning;
      case 'medium':
        return NotificationType.info;
      default:
        return NotificationType.info;
    }
  }

  String _getSeverityFromPriority(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return 'Critical';
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return 'Info';
    }
  }

  List<NotificationItem> get _filteredNotifications {
    if (_selectedFilter == 'All') {
      return _notifications;
    } else if (_selectedFilter == 'Unread') {
      return _notifications.where((n) => !n.isRead).toList();
    } else if (_selectedFilter == 'Action Required') {
      return _notifications.where((n) => n.actionRequired).toList();
    } else {
      return _notifications.where((n) => n.severity == _selectedFilter).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadNotifications,
            tooltip: 'Refresh notifications',
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list),
            onSelected: (filter) {
              setState(() {
                _selectedFilter = filter;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'All', child: Text('All Notifications')),
              PopupMenuItem(value: 'Unread', child: Text('Unread Only')),
              PopupMenuItem(value: 'Action Required', child: Text('Action Required')),
              PopupMenuItem(value: 'Critical', child: Text('Critical Only')),
              PopupMenuItem(value: 'High', child: Text('High Priority')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          tabs: [
            Tab(text: 'All', icon: Icon(Icons.notifications)),
            Tab(text: 'Alerts', icon: Icon(Icons.warning)),
            Tab(text: 'System', icon: Icon(Icons.settings)),
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
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 16),
            Text('Loading notifications...'),
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
              onPressed: _loadNotifications,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildAllNotificationsTab(),
        _buildAlertsTab(),
        _buildSystemTab(),
      ],
    );
  }

  Widget _buildAllNotificationsTab() {
    return Column(
      children: [
        _buildNotificationsSummary(),
        Expanded(
          child: _filteredNotifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _filteredNotifications.length,
                    itemBuilder: (context, index) {
                      final notification = _filteredNotifications[index];
                      return _buildNotificationCard(notification);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildAlertsTab() {
    final alerts = _notifications.where((n) => 
      n.type == NotificationType.alert || n.type == NotificationType.warning
    ).toList();

    return alerts.isEmpty
        ? _buildEmptyAlertsState()
        : RefreshIndicator(
            onRefresh: _loadNotifications,
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                final notification = alerts[index];
                return _buildNotificationCard(notification);
              },
            ),
          );
  }

  Widget _buildSystemTab() {
    final systemNotifications = _notifications.where((n) => 
      n.source == 'System'
    ).toList();

    return systemNotifications.isEmpty
        ? _buildEmptySystemState()
        : RefreshIndicator(
            onRefresh: _loadNotifications,
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: systemNotifications.length,
              itemBuilder: (context, index) {
                final notification = systemNotifications[index];
                return _buildNotificationCard(notification);
              },
            ),
          );
  }

  Widget _buildNotificationsSummary() {
    final unreadCount = _notifications.where((n) => !n.isRead).length;
    final criticalCount = _notifications.where((n) => n.severity == 'Critical').length;
    final actionRequiredCount = _notifications.where((n) => n.actionRequired && !n.isRead).length;

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: criticalCount > 0 
              ? [Colors.red.shade400, Colors.red.shade600]
              : actionRequiredCount > 0
                  ? [Colors.orange.shade400, Colors.orange.shade600]
                  : [Colors.blue.shade400, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notification Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Filter: $_selectedFilter',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              _buildSummaryBadge('Unread', unreadCount, Colors.white),
              SizedBox(width: 8),
              _buildSummaryBadge('Critical', criticalCount, Colors.red.shade700),
              SizedBox(width: 8),
              _buildSummaryBadge('Action Required', actionRequiredCount, Colors.orange.shade700),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBadge(String label, int count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
          color: color == Colors.white ? Colors.grey.shade800 : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
    final color = _getNotificationColor(notification);
    final icon = _getNotificationIcon(notification);

    return Card(
      elevation: notification.isRead ? 1 : 3,
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _onNotificationTap(notification),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: notification.isRead 
                ? null 
                : Border.all(color: color.withOpacity(0.3), width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
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
                        Icon(icon, color: color, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                        if (notification.actionRequired)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'ACTION',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        SizedBox(width: 8),
                        _buildSeverityChip(notification.severity),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      notification.message,
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
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                        SizedBox(width: 4),
                        Text(
                          DateFormat('MMM dd, yyyy HH:mm').format(notification.timestamp),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        SizedBox(width: 16),
                        Icon(Icons.source, size: 14, color: Colors.grey.shade600),
                        SizedBox(width: 4),
                        Text(
                          notification.source,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        if (notification.hiveId != 'system') ...[
                          SizedBox(width: 16),
                          Icon(Icons.hive, size: 14, color: Colors.grey.shade600),
                          SizedBox(width: 4),
                          Text(
                            'Hive ${notification.hiveId}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ],
                    ),
                    if (notification.actionRequired && !notification.isRead) ...[
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _handleNotificationAction(notification),
                              icon: Icon(Icons.arrow_forward, size: 16),
                              label: Text('Take Action'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: color,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          TextButton(
                            onPressed: () => _markAsRead(notification),
                            child: Text('Mark as Read'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeverityChip(String severity) {
    final color = _getSeverityColor(severity);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        severity.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade400),
          SizedBox(height: 16),
          Text(
            _selectedFilter == 'All' 
                ? 'No notifications'
                : 'No notifications match your filter',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          SizedBox(height: 8),
          Text(
            _selectedFilter == 'All'
                ? 'Your hives are running smoothly!'
                : 'Try changing the filter settings',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAlertsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
          SizedBox(height: 16),
          Text(
            'No active alerts',
            style: TextStyle(fontSize: 18, color: Colors.green.shade700),
          ),
          SizedBox(height: 8),
          Text(
            'All systems are operating normally',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySystemState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings_outlined, size: 64, color: Colors.grey.shade400),
          SizedBox(height: 16),
          Text(
            'No system notifications',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Color _getNotificationColor(NotificationItem notification) {
    switch (notification.type) {
      case NotificationType.alert:
        return Colors.red.shade600;
      case NotificationType.warning:
        return Colors.orange.shade600;
      case NotificationType.success:
        return Colors.green.shade600;
      case NotificationType.info:
        return Colors.blue.shade600;
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red.shade600;
      case 'high':
        return Colors.orange.shade600;
      case 'medium':
        return Colors.blue.shade600;
      case 'low':
        return Colors.grey.shade600;
      default:
        return Colors.green.shade600;
    }
  }

  IconData _getNotificationIcon(NotificationItem notification) {
    switch (notification.type) {
      case NotificationType.alert:
        return Icons.error;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.info:
        return Icons.info;
    }
  }

  void _onNotificationTap(NotificationItem notification) {
    if (!notification.isRead) {
      _markAsRead(notification);
    }
    
    // Show detailed notification dialog
    showDialog(
      context: context,
      builder: (context) => _buildNotificationDetailDialog(notification),
    );
  }

  Widget _buildNotificationDetailDialog(NotificationItem notification) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(_getNotificationIcon(notification), 
               color: _getNotificationColor(notification)),
          SizedBox(width: 8),
          Expanded(child: Text(notification.title)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(notification.message),
            SizedBox(height: 16),
            if (notification.additionalData.isNotEmpty) ...[
              Text(
                'Additional Information:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              ...notification.additionalData.entries.map((entry) => 
                Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text('${entry.key}: ${entry.value}'),
                )
              ).toList(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'),
        ),
        if (notification.actionRequired)
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleNotificationAction(notification);
            },
            child: Text('Take Action'),
          ),
      ],
    );
  }

  void _markAsRead(NotificationItem notification) {
    setState(() {
      notification.isRead = true;
    });
  }

  void _handleNotificationAction(NotificationItem notification) {
    if (notification.category == 'Foraging' || 
        notification.category == 'Environmental' ||
        notification.category == 'Colony Health') {
      // Navigate to recommendations screen for detailed actions
      NavigationHelper.navigateToRecommendations(
        context,
        hiveId: notification.hiveId,
      );
    } else if (notification.category == 'Foraging Patterns') {
      // Navigate to foraging dashboard
      NavigationHelper.navigateToForagingDashboard(
        context,
        hiveId: notification.hiveId,
      );
    } else {
      // Show action options dialog
      _showActionOptionsDialog(notification);
    }
  }

  void _showActionOptionsDialog(NotificationItem notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Action Options'),
        content: Text('What would you like to do about this notification?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _markAsRead(notification);
            },
            child: Text('Mark as Read'),
          ),
          if (notification.hiveId != 'system')
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                NavigationHelper.navigateToRecommendations(
                  context,
                  hiveId: notification.hiveId,
                );
              },
              child: Text('View Recommendations'),
            ),
        ],
      ),
    );
  }
}

// Notification data models
class NotificationItem {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final String severity;
  final DateTime timestamp;
  final String source;
  final String hiveId;
  bool isRead;
  final bool actionRequired;
  final String category;
  final Map<String, dynamic> additionalData;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.severity,
    required this.timestamp,
    required this.source,
    required this.hiveId,
    required this.isRead,
    required this.actionRequired,
    required this.category,
    required this.additionalData,
  });
}

enum NotificationType {
  alert,
  warning,
  info,
  success,
}

// Notification service for managing notifications across the app
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final List<NotificationItem> _notifications = [];
  final StreamController<List<NotificationItem>> _notificationController = 
      StreamController<List<NotificationItem>>.broadcast();

  Stream<List<NotificationItem>> get notificationStream => _notificationController.stream;
  List<NotificationItem> get notifications => List.unmodifiable(_notifications);
  
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  int get criticalCount => _notifications.where((n) => n.severity == 'Critical').length;

  void addNotification(NotificationItem notification) {
    _notifications.insert(0, notification); // Add to front (newest first)
    
    // Keep only last 100 notifications
    if (_notifications.length > 100) {
      _notifications.removeRange(100, _notifications.length);
    }
    
    _notificationController.add(_notifications);
  }

  void markAsRead(String notificationId) {
    final notification = _notifications.firstWhere(
      (n) => n.id == notificationId,
      orElse: () => throw Exception('Notification not found'),
    );
    notification.isRead = true;
    _notificationController.add(_notifications);
  }

  void markAllAsRead() {
    for (final notification in _notifications) {
      notification.isRead = true;
    }
    _notificationController.add(_notifications);
  }

  void removeNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    _notificationController.add(_notifications);
  }

  void clearAllNotifications() {
    _notifications.clear();
    _notificationController.add(_notifications);
  }

  // Generate notification from advisory recommendation
  void addAdvisoryRecommendation(DailyRecommendation recommendation, String hiveId) {
    final notification = NotificationItem(
      id: recommendation.id,
      title: recommendation.title,
      message: recommendation.description,
      type: _getNotificationTypeFromPriority(recommendation.priority),
      severity: recommendation.priority,
      timestamp: DateTime.now(),
      source: 'Advisory System',
      hiveId: hiveId,
      isRead: false,
      actionRequired: recommendation.priority == 'Critical' || recommendation.priority == 'High',
      category: 'Foraging',
      additionalData: {
        'timeRelevance': recommendation.timeRelevance,
        'foragingImpact': recommendation.foragingImpact,
        'actionItems': recommendation.actionItems,
        'scientificBasis': recommendation.scientificBasis,
      },
    );
    
    addNotification(notification);
  }

  // Generate parameter alert
  void addParameterAlert({
    required String title,
    required String message,
    required String severity,
    required String source,
    required String hiveId,
    required String category,
    Map<String, dynamic>? additionalData,
  }) {
    final notification = NotificationItem(
      id: 'param_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: message,
      type: _getNotificationTypeFromSeverity(severity),
      severity: severity,
      timestamp: DateTime.now(),
      source: source,
      hiveId: hiveId,
      isRead: false,
      actionRequired: severity == 'Critical' || severity == 'High',
      category: category,
      additionalData: additionalData ?? {},
    );
    
    addNotification(notification);
  }

  NotificationType _getNotificationTypeFromPriority(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return NotificationType.alert;
      case 'high':
        return NotificationType.warning;
      case 'medium':
        return NotificationType.info;
      default:
        return NotificationType.info;
    }
  }

  NotificationType _getNotificationTypeFromSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return NotificationType.alert;
      case 'high':
        return NotificationType.warning;
      case 'success':
        return NotificationType.success;
      default:
        return NotificationType.info;
    }
  }

  void dispose() {
    _notificationController.close();
  }
}

// Widget for displaying notification badge with count
class NotificationBadge extends StatelessWidget {
  final Widget child;
  final int count;
  final Color? badgeColor;

  const NotificationBadge({
    Key? key,
    required this.child,
    required this.count,
    this.badgeColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (count > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: badgeColor ?? Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// Usage example for adding notifications from other parts of the app:
/*
// Add a critical temperature alert
NotificationService().addParameterAlert(
  title: 'Critical Temperature Alert',
  message: 'Temperature is 37.5°C - immediate action required',
  severity: 'Critical',
  source: 'Temperature Sensor',
  hiveId: '1',
  category: 'Environmental',
  additionalData: {
    'currentValue': 37.5,
    'threshold': 35.0,
    'unit': '°C',
  },
);

// Add a foraging recommendation
final advisoryService = EnhancedForagingAdvisoryService();
final analysis = await advisoryService.getDailyForagingAnalysis('1', DateTime.now());
if (analysis != null) {
  for (final recommendation in analysis.recommendations) {
    NotificationService().addAdvisoryRecommendation(recommendation, analysis.hiveId);
  }
}
*/