// lib/bee_counter/automatic_bee_monitoring_service.dart (updated)

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
import 'package:HPGM/bee_counter/bee_count_database.dart';

const String PORT_NAME = 'bee_monitoring_port';

class AutomaticBeeMonitoringService {
  static final AutomaticBeeMonitoringService _instance =
      AutomaticBeeMonitoringService._internal();
  factory AutomaticBeeMonitoringService() => _instance;
  AutomaticBeeMonitoringService._internal();

  final FlutterBackgroundService _service = FlutterBackgroundService();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Service configuration - Check every 5 minutes for new videos (reduced from 10)
  static const Duration _checkInterval = Duration(minutes: 5);

  // Expected video arrival times (with buffer)
  static final List<TimeWindow> _videoWindows = [
    TimeWindow(hour: 7, minuteStart: 0, minuteEnd: 59), // 7:00-7:59 AM
    TimeWindow(hour: 12, minuteStart: 0, minuteEnd: 59), // 12:00-12:59 PM
    TimeWindow(hour: 18, minuteStart: 0, minuteEnd: 59), // 6:00-6:59 PM
  ];

  /// Initialize and AUTO-START the service
  Future<void> initializeAndStart() async {
    print('=== INITIALIZING AUTOMATIC BEE MONITORING SERVICE ===');

    try {
      await _setupNotifications();
      print('✓ Notifications configured');

      await _configureBackgroundService();
      print('✓ Background service configured');

      // Always start the service automatically
      final isRunning = await _service.isRunning();
      if (!isRunning) {
        print('Starting background service...');
        final started = await _service.startService();
        print('✓ Service auto-started: $started');
      } else {
        print('✓ Service already running');

        // Force restart the service to ensure it's running with the latest configuration
        _service.invoke('stopService');
        await Future.delayed(Duration(seconds: 1));
        final restarted = await _service.startService();
        print('✓ Service restarted: $restarted');
      }

      // Initialize ML model in background
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ml_needs_init', true);
    } catch (e) {
      print('ERROR initializing service: $e');
      // Continue anyway - service is critical
    }
  }

  /// Setup notification system
  Future<void> _setupNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);

    // Create notification channel with HIGHER importance
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'bee_monitoring_channel',
      'Bee Monitoring Service',
      description: 'Automatic bee activity monitoring',
      importance: Importance.high, // Changed from low to high
      showBadge: true, // Changed from false to true
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// Configure background service
  Future<void> _configureBackgroundService() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'bee_monitoring_channel',
        initialNotificationTitle: 'Bee Monitor Active',
        initialNotificationContent: 'Monitoring hive activity',
        foregroundServiceNotificationId: 888,
        // Remove enableWakeLock
        autoStartOnBoot: true,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> _onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    print('=== BACKGROUND SERVICE STARTED ===');
    print('Current time: ${DateTime.now()}');

    // Ensure the service runs in foreground mode with a persistent notification
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Bee Monitor Active',
        content: 'Monitoring hive activity',
      );

      // Immediately set as foreground
      service.setAsForegroundService();
    }

    // Add handler for stopping service
    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Setup communication
    final ReceivePort port = ReceivePort();
    IsolateNameServer.registerPortWithName(port.sendPort, PORT_NAME);

    // Start automatic processing
    await _startAutomaticProcessing(service);

    return true;
  }

  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    print('=== BACKGROUND SERVICE STARTED (iOS) ===');

    // Setup communication
    final ReceivePort port = ReceivePort();
    IsolateNameServer.registerPortWithName(port.sendPort, PORT_NAME);

    // Start automatic processing
    await _startAutomaticProcessing(service);

    return true;
  }

  /// Start the main processing loop
  static Future<void> _startAutomaticProcessing(ServiceInstance service) async {
    print('Starting automatic bee video processing loop');
    final Map<String, DateTime> lastCheckTime = {};

    // Run immediate check
    print('Running initial video check...');
    await _performAutomaticVideoProcessing(service, lastCheckTime);

    // Create timer for periodic processing
    Timer.periodic(_checkInterval, (timer) async {
      print('\n=== PERIODIC CHECK: ${DateTime.now()} ===');
      await _performAutomaticVideoProcessing(service, lastCheckTime);
    });
  }

  /// Main processing logic - Process ANY new videos found
  static Future<void> _performAutomaticVideoProcessing(
    ServiceInstance service,
    Map<String, DateTime> lastCheckTime,
  ) async {
    final checkTime = DateTime.now();

    try {
      print('\n=== CHECKING FOR NEW VIDEOS ===');
      print('Time: ${checkTime.toString()}');

      // Update notification to show we're checking
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Bee Monitor',
          content: 'Checking for new videos...',
        );
      }

      // Check if current time is within any of the scheduled windows
      final isScheduledTime = _isScheduledProcessingTime(checkTime);
      print('Is scheduled processing time: $isScheduledTime');

      // Get all hives (for now just process hive "1")
      final hiveIds = ['1']; // TODO: Get from database or config

      int totalProcessed = 0;
      int totalSuccessful = 0;
      int totalNew = 0;

      // Always process videos, but log differently based on schedule
      for (final hiveId in hiveIds) {
        // Check when we last processed this hive
        final lastCheck =
            lastCheckTime[hiveId] ?? DateTime.now().subtract(Duration(days: 1));

        print('Checking hive $hiveId (last check: $lastCheck)');

        // Get ALL videos from server for today and yesterday
        final dates = [checkTime, checkTime.subtract(Duration(days: 1))];

        for (final date in dates) {
          final result = await _processVideosForHive(
            hiveId,
            date,
            service,
            onlyNew: true, // Process only unprocessed videos
          );

          totalNew += (result['totalVideos'] as int? ?? 0);
          totalProcessed += (result['processed'] as int? ?? 0);
          totalSuccessful += (result['successful'] as int? ?? 0);
        }

        // Update last check time
        lastCheckTime[hiveId] = checkTime;
      }

      // Update notification
      if (service is AndroidServiceInstance) {
        final message =
            totalNew > 0
                ? 'Found $totalNew videos, processed $totalSuccessful'
                : 'Monitoring hive activity (${checkTime.hour}:${checkTime.minute.toString().padLeft(2, '0')})';

        service.setForegroundNotificationInfo(
          title: 'Bee Monitor Active',
          content: message,
        );
      }

      // Show summary notification if videos were processed
      if (totalSuccessful > 0) {
        await _showProcessingNotification(totalSuccessful, totalProcessed);
      }

      print(
        'Check complete: $totalNew videos found, $totalSuccessful processed successfully\n',
      );
    } catch (e, stack) {
      print('ERROR in automatic processing: $e');
      print('Stack trace: $stack');

      // Update notification with error
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Bee Monitor Error',
          content:
              'Error checking videos. Will retry in ${_checkInterval.inMinutes} minutes.',
        );
      }
    }
  }

  /// Check if current time is within scheduled processing windows
  static bool _isScheduledProcessingTime(DateTime now) {
    for (final window in _videoWindows) {
      if (window.isInWindow(now)) {
        return true;
      }
    }
    return false;
  }

  /// Process videos for a specific hive and date
  static Future<Map<String, dynamic>> _processVideosForHive(
    String hiveId,
    DateTime date,
    ServiceInstance service, {
    bool onlyNew = true,
  }) async {
    final Map<String, dynamic> results = {
      'totalVideos': 0,
      'processed': 0,
      'successful': 0,
      'failed': 0,
      'skipped': 0,
    };

    try {
      print(
        '\nProcessing videos for hive: $hiveId, date: ${date.toString().split(' ')[0]}',
      );

      final serverVideoService = ServerVideoService();

      // Fetch all videos for the specified date
      final videos = await serverVideoService.fetchVideosFromServer(
        hiveId,
        specificDate: date,
      );

      print(
        'Found ${videos.length} videos from server for ${date.toString().split(' ')[0]}',
      );

      if (videos.isEmpty) {
        return results;
      }

      results['totalVideos'] = videos.length;

      // Process each video
      for (int i = 0; i < videos.length; i++) {
        final video = videos[i];
        final videoId = video.id;

        print('Checking video ${i + 1}/${videos.length}: $videoId');

        // Show video timestamp
        if (video.timestamp != null) {
          print('  Video timestamp: ${video.timestamp}');
        }

        try {
          // Check if already processed
          final isProcessed = await BeeCountDatabase.instance.isVideoProcessed(
            videoId,
          );

          if (isProcessed && onlyNew) {
            print('  Already processed, skipping');
            results['skipped'] = (results['skipped'] as int) + 1;
            continue;
          }

          print('  Processing new video...');
          results['processed'] = (results['processed'] as int) + 1;

          // Update UI notification
          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: 'Processing Video',
              content: 'Analyzing ${video.id}...',
            );
          }

          // Process the video with ML
          final beeCount = await serverVideoService.processServerVideo(
            video,
            hiveId: hiveId,
            onStatusUpdate: (status) {
              print('    → $status');
            },
          );

          if (beeCount != null) {
            print(
              '  ✓ SUCCESS: ${beeCount.beesEntering} in, ${beeCount.beesExiting} out',
            );
            print('  ✓ Confidence: ${beeCount.confidence.toStringAsFixed(1)}%');
            results['successful'] = (results['successful'] as int) + 1;
          } else {
            print('  ✗ FAILED: Could not process video');
            results['failed'] = (results['failed'] as int) + 1;
          }
        } catch (e, stack) {
          print('  ✗ ERROR: $e');
          print('  Stack trace: $stack');
          results['failed'] = (results['failed'] as int) + 1;
        }

        // Small delay between videos to prevent overload
        await Future.delayed(Duration(seconds: 1));
      }

      print(
        'Hive $hiveId date ${date.toString().split(' ')[0]} complete: ${results['successful']}/${results['processed']} processed successfully',
      );
      return results;
    } catch (e, stack) {
      print('ERROR processing hive $hiveId: $e');
      print('Stack trace: $stack');
      results['error'] = e.toString();
      return results;
    }
  }

  /// Show processing notification
  static Future<void> _showProcessingNotification(
    int successful,
    int processed,
  ) async {
    final notificationsPlugin = FlutterLocalNotificationsPlugin();

    await notificationsPlugin.show(
      DateTime.now().millisecond,
      'New Bee Videos Processed',
      'Successfully analyzed $successful out of $processed videos',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'bee_monitoring_channel',
          'Bee Monitoring Service',
          channelDescription: 'Bee monitoring notifications',
          importance: Importance.high,
          priority: Priority.high,
          // Use the default launcher icon instead of a custom one
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  // Status check method (for UI)
  Future<bool> isServiceRunning() async {
    return await _service.isRunning();
  }

  FlutterBackgroundService getService() {
    return _service;
  }
}

class TimeWindow {
  final int hour;
  final int minuteStart;
  final int minuteEnd;

  TimeWindow({
    required this.hour,
    required this.minuteStart,
    required this.minuteEnd,
  });

  bool isInWindow(DateTime dateTime) {
    return dateTime.hour == hour &&
        dateTime.minute >= minuteStart &&
        dateTime.minute <= minuteEnd;
  }
}
