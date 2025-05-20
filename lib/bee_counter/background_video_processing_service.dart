import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:HPGM/bee_counter/auto_video_processing_service.dart';
import 'package:HPGM/bee_counter/bee_counter_model.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

// IMPORTANT: Add these dependencies to your pubspec.yaml:
// flutter_background_service: ^5.0.5
// flutter_background_service_android: ^6.2.2
// shared_preferences: ^2.2.0

// This class manages background processing for bee video analysis
class BackgroundVideoProcessingService {
  // Static port name for communication with background isolate
  static const String _portName = 'bee_monitoring_port';

  // Service singleton
  static final BackgroundVideoProcessingService _instance =
      BackgroundVideoProcessingService._internal();
  factory BackgroundVideoProcessingService() => _instance;
  BackgroundVideoProcessingService._internal();

  // Service status
  bool _isInitialized = false;
  bool _isBackgroundTaskEnabled = false;

  // Check if service is enabled
  Future<bool> isBackgroundTaskEnabled() async {
    if (!_isInitialized) return false;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('background_task_enabled') ?? false;
  }

  // Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'bee_monitoring_channel',
        initialNotificationTitle: 'Bee Monitoring Service',
        initialNotificationContent: 'Initializing',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    _isInitialized = true;

    // Check if background processing was previously enabled
    final enabled = await isBackgroundTaskEnabled();
    if (enabled) {
      await enableBackgroundProcessing();
    }
  }

  // Enable background processing
  Future<void> enableBackgroundProcessing() async {
    if (!_isInitialized) await initialize();

    final service = FlutterBackgroundService();
    await service.startService();

    // Save setting
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('background_task_enabled', true);
    _isBackgroundTaskEnabled = true;
  }

  // Disable background processing
  Future<void> disableBackgroundProcessing() async {
    if (!_isInitialized) return;

    final service = FlutterBackgroundService();
    service.invoke('stopService');

    // Save setting
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('background_task_enabled', false);
    _isBackgroundTaskEnabled = false;
  }

  // Run a one-time check
  Future<void> runOneTimeCheck() async {
    // Since we're not using Workmanager anymore, we'll directly process the video
    // This will run in the current process but could be moved to an isolate if needed
    try {
      final videoService = AutoVideoProcessingService();

      // Get default hiveId from SharedPreferences or use a default
      final prefs = await SharedPreferences.getInstance();
      final defaultHiveId = prefs.getString('default_hive_id') ?? '1';

      // Set up status callback
      videoService.onStatusUpdate = (status) {
        print('One-time task status: $status');
      };

      // Set up completion callback
      videoService.onNewAnalysisComplete = (BeeCount beeCount) {
        print('One-time analysis complete: ${beeCount.videoId}');
      };

      // Check for new videos
      await videoService
          .fetchLatestVideoFromServer(defaultHiveId)
          .then((video) async {
        if (video != null) {
          await videoService.processServerVideo(
            video,
            onStatusUpdate: (status) {
              print('One-time processing: $status');
            },
          );
        }
      });

      // Clean up
      videoService.dispose();
    } catch (e) {
      print('One-time task failed: $e');
    }
  }
}

// iOS background handler
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  return true;
}

// Background service entry point
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // For Android, set up the foreground notification
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: "Bee Monitoring Service",
      content: "Running in background",
    );
  }

  // Set up periodic task
  Timer.periodic(Duration(minutes: 15), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "Bee Monitoring Service",
          content: "Checking for new videos",
        );
      }
    }

    // Run the video processing task
    try {
      final videoService = AutoVideoProcessingService();

      // Get default hiveId from SharedPreferences or use a default
      final prefs = await SharedPreferences.getInstance();
      final defaultHiveId = prefs.getString('default_hive_id') ?? '1';

      // This port is used to communicate from the background service
      // to the main app if needed
      final SendPort? sendPort = IsolateNameServer.lookupPortByName(
          BackgroundVideoProcessingService._portName);

      // Set up status callback
      videoService.onStatusUpdate = (status) {
        print('Background task status: $status');
        // Send status updates to the main app
        service.invoke('status', {'message': status});
      };

      // Set up completion callback
      videoService.onNewAnalysisComplete = (BeeCount beeCount) {
        print('Background analysis complete: ${beeCount.videoId}');
        // Send results to the main app
        service.invoke('result', {
          'hiveId': beeCount.hiveId,
          'entering': beeCount.beesEntering,
          'exiting': beeCount.beesExiting,
          'timestamp': beeCount.timestamp.toIso8601String(),
        });
      };

      // Check for new videos
      await videoService
          .fetchLatestVideoFromServer(defaultHiveId)
          .then((video) async {
        if (video != null) {
          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: "Processing Bee Video",
              content: "Analyzing video data",
            );
          }

          await videoService.processServerVideo(
            video,
            onStatusUpdate: (status) {
              print('Background processing: $status');
            },
          );

          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: "Bee Monitoring Service",
              content: "Running in background",
            );
          }
        }
      });

      // Clean up
      videoService.dispose();
    } catch (e) {
      print('Background task failed: $e');

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Bee Monitoring Service",
          content: "Error occurred, will retry later",
        );
      }
    }
  });

  // Listen for events from the main app
  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}
