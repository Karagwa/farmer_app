
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
import 'package:HPGM/bee_counter/bee_counter_model.dart';
const String PORT_NAME = 'bee_monitoring_port';

@pragma('vm:entry-point')
class AutomaticBeeMonitoringService {
  static final AutomaticBeeMonitoringService _instance =
      AutomaticBeeMonitoringService._internal();
  factory AutomaticBeeMonitoringService() => _instance;
  AutomaticBeeMonitoringService._internal();

  final FlutterBackgroundService _service = FlutterBackgroundService();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const Duration _checkInterval = Duration(minutes: 3);

  // Communication port for main isolate processing
  static SendPort? _mainIsolateSendPort;
  static ReceivePort? _backgroundReceivePort;

  /// Initialize and AUTO-START the service
  Future<void> initializeAndStart() async {
  

    try {
      await _setupNotifications();
      print('✓ Notifications configured');

      // Setup communication between isolates
      await _setupIsolateCommunication();
      print('✓ Isolate communication setup');

      await _configureBackgroundService();
      print(' Background service configured');

      final isRunning = await _service.isRunning();
      if (!isRunning) {
        print('Starting background service...');
        final started = await _service.startService();
        print(' Service auto-started: $started');
      } else {
        print('Service already running');
      }

      print(' Bee monitoring service started automatically');
    } catch (e) {
      print('ERROR initializing service: $e');
    }
  }

  // Setup communication between main and background isolates
  Future<void> _setupIsolateCommunication() async {
    // Create receive port for background isolate to send tasks to main isolate
    _backgroundReceivePort = ReceivePort();
    
    // Listen for video processing requests from background isolate
    _backgroundReceivePort!.listen((message) async {
      if (message is Map && message['type'] == 'process_video') {
        try {
          print('Main isolate received video processing request');
          
          final videoUrl = message['videoUrl'] as String;
          final videoId = message['videoId'] as String;
          final hiveId = message['hiveId'] as String;
          final timestamp = message['timestamp'] != null 
              ? DateTime.parse(message['timestamp']) 
              : DateTime.now();

          // Process video in main isolate where FFmpeg works
          final result = await _processVideoInMainIsolate(videoUrl, videoId, hiveId, timestamp);
          
          // Send result back to background isolate
          final backgroundPort = message['responsePort'] as SendPort;
          backgroundPort.send({
            'type': 'processing_result',
            'success': result != null,
            'data': result?.toJson(),
            'beeCount': result != null ? {
              'beesEntering': result.beesEntering,
              'beesExiting': result.beesExiting,
              'confidence': result.confidence,
            } : null,
          });
        } catch (e) {
          print('Error processing video in main isolate: $e');
          // Send error response
          final backgroundPort = message['responsePort'] as SendPort;
          backgroundPort.send({
            'type': 'processing_result',
            'success': false,
            'error': e.toString(),
          });
        }
      }
    });

    // Register the port for background isolate to find
    IsolateNameServer.removePortNameMapping('main_isolate_port');
    IsolateNameServer.registerPortWithName(
      _backgroundReceivePort!.sendPort, 
      'main_isolate_port'
    );
  }

  /// Process video in main isolate where plugins work
  Future<BeeCount?> _processVideoInMainIsolate(
    String videoUrl, 
    String videoId, 
    String hiveId,
    DateTime timestamp,
  ) async {
    try {
      print('Processing video in main isolate: $videoId');
      
      // Check if already processed to avoid duplicate work
      final isProcessed = await BeeCountDatabase.instance.isVideoProcessed(videoId);
      if (isProcessed) {
        print('Video already processed: $videoId');
        // Return existing count
        final counts = await BeeCountDatabase.instance.getAllBeeCounts();
        final existingCount = counts.firstWhere(
          (count) => count.videoId == videoId,
          orElse: () => BeeCount(
            hiveId: hiveId,
            videoId: videoId,
            beesEntering: 0,
            beesExiting: 0,
            timestamp: timestamp,
          ),
        );
        return existingCount;
      }
      
      final beeAnalysisService = BeeAnalysisService.instance;
      
      // Initialize ML model if needed
      await beeAnalysisService.initialize();
      
      // Download video
      print('Downloading video from: $videoUrl');
      final videoPath = await beeAnalysisService.downloadVideo(
        videoUrl,
        onProgress: (progress) {
          print('Download progress: ${(progress * 100).toStringAsFixed(1)}%');
        },
      );

      if (videoPath == null) {
        print('Failed to download video');
        return null;
      }

      print('Video downloaded successfully: $videoPath');

      // Analyze with ML (this will use FFmpeg in main isolate where it works)
      final result = await beeAnalysisService.analyzeVideoWithML(
        hiveId,
        videoId,
        videoPath,
        onProgress: (progress) {
          print('Analysis progress: ${(progress * 100).toStringAsFixed(1)}%');
        },
      );

      if (result != null) {
        // Ensure correct timestamp is used
        final correctedResult = result.copyWith(timestamp: timestamp);
        print(' Video processed successfully: ${correctedResult.beesEntering} in, ${correctedResult.beesExiting} out');
        return correctedResult;
      } else {
        print(' Video processing failed');
        return null;
      }

    } catch (e, stack) {
      print('Error in main isolate video processing: $e');
      print('Stack trace: $stack');
      return null;
    }
  }

  /// Setup notification system
  Future<void> _setupNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'bee_monitoring_channel',
      'Bee Monitoring Service',
      description: 'Automatic bee activity monitoring',
      importance: Importance.high,
      showBadge: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  // Configure background service
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

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Bee Monitor Active',
        content: 'Monitoring hive activity',
      );
      service.setAsForegroundService();
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    await _startAutomaticProcessing(service);
    return true;
  }

  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    await _startAutomaticProcessing(service);
    return true;
  }

  // Start the main processing loop - simplified to avoid plugin issues
  static Future<void> _startAutomaticProcessing(ServiceInstance service) async {
    print('Starting automatic bee video processing loop');
    final Map<String, DateTime> lastCheckTime = {};

    // Get reference to main isolate port
    SendPort? mainIsolatePort;
    
    Timer.periodic(Duration(seconds: 5), (timer) {
      // Try to get main isolate port if we don't have it
      if (mainIsolatePort == null) {
        mainIsolatePort = IsolateNameServer.lookupPortByName('main_isolate_port');
        if (mainIsolatePort != null) {
          print('Connected to main isolate for video processing');
        }
      }
    });

    Timer.periodic(_checkInterval, (timer) async {
      print('\n PERIODIC CHECK: ${DateTime.now()} ');
      await _performAutomaticVideoCheck(service, lastCheckTime, mainIsolatePort);
    });
  }

  /// Simplified video check - delegate processing to main isolate
  static Future<void> _performAutomaticVideoCheck(
    ServiceInstance service,
    Map<String, DateTime> lastCheckTime,
    SendPort? mainIsolatePort,
  ) async {
    try {
      print('Checking for new videos...');
      
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Bee Monitor',
          content: 'Checking for new videos...',
        );
      }

      // Simple check without processing - just fetch latest video info
      final serverVideoService = ServerVideoService();
      final latestVideo = await serverVideoService.fetchLatestVideoFromServer('1');

      if (latestVideo == null) {
        print('No videos found on server');
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'Bee Monitor Active',
            content: 'No new videos found',
          );
        }
        return;
      }

      print('Found latest video: ${latestVideo.id}');
      print('Video timestamp: ${latestVideo.timestamp}');

      // Check if already processed
      final isProcessed = await BeeCountDatabase.instance.isVideoProcessed(latestVideo.id);
      
      final lastCheck = lastCheckTime['1'] ?? DateTime.now().subtract(Duration(days: 1));
      final isNewerThanLastCheck = latestVideo.timestamp != null && 
          latestVideo.timestamp!.isAfter(lastCheck);
      
      if (isProcessed && !isNewerThanLastCheck) {
        print('Video already processed and not newer than last check, skipping');
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'Bee Monitor Active',
            content: 'Monitoring hive activity (${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')})',
          );
        }
        return;
      }

      // If main isolate communication is available, delegate processing
      if (mainIsolatePort != null) {
        print('Delegating video processing to main isolate');
        
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'Processing Video',
            content: 'Analyzing ${latestVideo.id}...',
          );
        }
        
        final responsePort = ReceivePort();
        mainIsolatePort.send({
          'type': 'process_video',
          'videoUrl': latestVideo.url,
          'videoId': latestVideo.id,
          'hiveId': '1',
          'timestamp': latestVideo.timestamp?.toIso8601String(),
          'responsePort': responsePort.sendPort,
        });

        // Wait for response with timeout
        try {
          final response = await responsePort.first.timeout(
            Duration(minutes: 10), // Increased timeout for video processing
            onTimeout: () => {'type': 'timeout'},
          );

          if (response['type'] == 'processing_result' && response['success'] == true) {
            final beeCount = response['beeCount'];
            print('✓ Video processed successfully in main isolate');
            
            if (beeCount != null) {
              print('Results: ${beeCount['beesEntering']} in, ${beeCount['beesExiting']} out');
              print('Confidence: ${beeCount['confidence'].toStringAsFixed(1)}%');
            }
            
            // Update last check time
            lastCheckTime['1'] = DateTime.now();
            
            if (service is AndroidServiceInstance) {
              final message = beeCount != null 
                  ? 'Processed: ${beeCount['beesEntering']} in, ${beeCount['beesExiting']} out'
                  : 'Latest video processed successfully';
              
              service.setForegroundNotificationInfo(
                title: 'Bee Monitor Active',
                content: message,
              );
            }
            
            // Show success notification
            await _showProcessingNotification(1, 1, beeCount);
            
          } else if (response['type'] == 'timeout') {
            print(' Video processing timed out');
            if (service is AndroidServiceInstance) {
              service.setForegroundNotificationInfo(
                title: 'Bee Monitor Active',
                content: 'Processing timed out - will retry next cycle',
              );
            }
          } else {
            print(' Video processing failed: ${response['error'] ?? 'Unknown error'}');
            if (service is AndroidServiceInstance) {
              service.setForegroundNotificationInfo(
                title: 'Bee Monitor Active',
                content: 'Processing failed - will retry next cycle',
              );
            }
          }
        } catch (e) {
          print('Error waiting for processing response: $e');
        } finally {
          responsePort.close();
        }
        
      } else {
        print('Main isolate communication not available');
        
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'Bee Monitor Limited',
            content: 'Main app needed for video processing',
          );
        }
        
        // Create a placeholder entry to avoid reprocessing
        final placeholderCount = BeeCount(
          hiveId: '1',
          videoId: latestVideo.id,
          beesEntering: 0,
          beesExiting: 0,
          timestamp: latestVideo.timestamp ?? DateTime.now(),
          notes: 'Processed in background - main app needed for full analysis',
          confidence: 0.0,
        );
        
        try {
          await BeeCountDatabase.instance.createBeeCount(placeholderCount);
          print('Created placeholder entry for video: ${latestVideo.id}');
        } catch (e) {
          print('Error creating placeholder entry: $e');
        }
      }

    } catch (e, stack) {
      print('ERROR in automatic processing: $e');
      print('Stack trace: $stack');
      
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Bee Monitor Error',
          content: 'Error checking videos - will retry',
        );
      }
    }
  }

  /// Show processing notification with results
  static Future<void> _showProcessingNotification(
    int successful,
    int processed,
    Map<String, dynamic>? beeCount,
  ) async {
    final notificationsPlugin = FlutterLocalNotificationsPlugin();

    String title = 'New Bee Video Processed';
    String body = 'Successfully analyzed $successful out of $processed videos';
    
    if (beeCount != null) {
      final beesIn = beeCount['beesEntering'] ?? 0;
      final beesOut = beeCount['beesExiting'] ?? 0;
      final confidence = beeCount['confidence'] ?? 0.0;
      
      body = 'Detected: $beesIn bees in, $beesOut bees out (${confidence.toStringAsFixed(0)}% confidence)';
    }

    await notificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'bee_monitoring_channel',
          'Bee Monitoring Service',
          channelDescription: 'Bee monitoring notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  Future<bool> isServiceRunning() async {
    return await _service.isRunning();
  }

  FlutterBackgroundService getService() {
    return _service;
  }
}