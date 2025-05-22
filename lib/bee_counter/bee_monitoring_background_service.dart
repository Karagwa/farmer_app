import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:HPGM/Services/bee_analysis_service.dart';
import 'package:HPGM/bee_counter/server_video_service.dart';
import 'package:HPGM/utilities/video_processor.dart';

// The port name used for communication with the background service
const String PORT_NAME = 'bee_monitoring_port';

class BeeMonitoringService {
  // Singleton pattern
  static final BeeMonitoringService _instance =
      BeeMonitoringService._internal();
  factory BeeMonitoringService() => _instance;
  BeeMonitoringService._internal();

  // Services
  final ServerVideoService _serverVideoService = ServerVideoService();
  final BeeAnalysisService _beeAnalysisService = BeeAnalysisService.instance;

  // Background service instance
  final FlutterBackgroundService _service = FlutterBackgroundService();

  // Notification setup
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Track last check time
  DateTime _lastCheckTime = DateTime.now();

  // Initialize the service
  Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    // Import the necessary packages to access the foreground service type
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'bee_monitoring_channel',
      'Bee Monitoring Service',
      description: 'Notifications for bee activity monitoring',
      importance: Importance.high,
    );

    // Create the channel before using it
    await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // Remove the foregroundServiceType parameter if it's not supported
        // If it is supported in your newer version, use it like this:
        // foregroundServiceType: AndroidServiceForegroundType.dataSync,
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'bee_monitoring_channel',
        initialNotificationTitle: 'Bee Monitoring Service',
        initialNotificationContent: 'Initializing...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  // Setup notification channels
  Future<void> _setupNotifications() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'bee_monitoring_channel',
      'Bee Monitoring Service',
      description: 'Notifications for bee activity monitoring',
      importance: Importance.high,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  FlutterBackgroundService getService() {
    return _service;
  }

  // Configure the background service
  Future<void> _configureBackgroundService() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'bee_monitoring_channel',
        initialNotificationTitle: 'Bee Monitoring Service',
        initialNotificationContent: 'Monitoring bee activity',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  // iOS background handler
  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  // Main background service entry point
  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    // Setup communication port
    final ReceivePort port = ReceivePort();
    IsolateNameServer.registerPortWithName(port.sendPort, PORT_NAME);

    // Configure Android-specific features
    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    // Listen for stop command
    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Using periodic timer that runs every 30 minutes
    Timer.periodic(
      const Duration(minutes: 30),
      (timer) => _checkForNewVideos(service),
    );

    // For testing, also run immediately
    _checkForNewVideos(service);
  }

  // Check for new videos logic
  // In your _checkForNewVideos method in BeeMonitoringService.dart
  static Future<void> _checkForNewVideos(ServiceInstance service) async {
    try {
      // Update service notification to show it's active
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Bee Monitoring Active',
          content: 'Checking for new videos...',
        );
      }

      final prefs = await SharedPreferences.getInstance();
      final lastCheckTime = DateTime.fromMillisecondsSinceEpoch(
        prefs.getInt('last_check_time') ?? 0,
      );

      service.invoke('update', {
        'status': 'Checking for new videos',
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Create a new instance of VideoProcessor to avoid static method issues
      final result = await VideoProcessor.processVideos(
        hiveId: '1', // Default hive ID
        date: DateTime.now(), // Process today's videos
        force: false,
        verbose: true,
        onStatusUpdate: (status) {
          // Report status updates to the service
          service.invoke('update', {
            'status': status,
            'timestamp': DateTime.now().toIso8601String(),
          });
        },
      );

      // Update service with results
      int processedCount = result['processed'] as int;
      int successfulCount = result['successful'] as int;

      service.invoke('update', {
        'status':
            processedCount > 0
                ? 'Processing complete: $successfulCount videos processed successfully'
                : 'No new videos to process',
        'timestamp': DateTime.now().toIso8601String(),
        'result': {
          'totalVideos': result['totalVideos'],
          'processed': result['processed'],
          'successful': result['successful'],
          'failed': result['failed'],
          'skipped': result['skipped'],
        },
      });

      // Only show notification if we actually processed videos
      if (processedCount > 0) {
        final FlutterLocalNotificationsPlugin notificationsPlugin =
            FlutterLocalNotificationsPlugin();

        notificationsPlugin.show(
          DateTime.now().millisecond,
          'Bee Activity Update',
          'Processed $processedCount videos: $successfulCount successful',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'bee_monitoring_channel',
              'Bee Monitoring Service',
              channelDescription: 'Notifications for bee monitoring',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@drawable/app_icon',
            ),
          ),
        );
      }

      // Update last check time
      await prefs.setInt(
        'last_check_time',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      print('Error in checking for new videos: $e');
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Bee Monitoring Error',
          content: 'Error: $e',
        );
      }
    }
  }

  // Start the service manually
  Future<bool> startService() async {
    return await _service.startService();
  }

  // Stop the service manually
  Future<bool> stopService() async {
    // Send the stop command
    _service.invoke('stopService');

    // Wait a brief moment for the service to process the stop command
    await Future.delayed(const Duration(milliseconds: 500));

    // Return the new service state (should be stopped)
    return !(await isServiceRunning());
  }

  // Check if service is running
  Future<bool> isServiceRunning() async {
    return await _service.isRunning();
  }

  // Method to manually trigger an immediate check
  Future<void> checkNow() async {
    if (await isServiceRunning()) {
      _service.invoke('checkNow');
    } else {
      await startService();
    }
  }
}
