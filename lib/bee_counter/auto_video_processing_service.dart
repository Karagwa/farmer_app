import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:HPGM/bee_counter/bee_counter_model.dart';
import 'package:HPGM/Services/bee_analysis_service.dart';
import 'package:HPGM/bee_counter/bee_count_database.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class AutoVideoProcessingService with ChangeNotifier {
  // API base URL
  final String baseUrl = 'http://196.43.168.57/api/v1';
  final BeeAnalysisService _beeAnalysisService = BeeAnalysisService();

  // HTTP client
  final http.Client _client = http.Client();

  // Cache for latest processed video ID to avoid reprocessing
  String? _lastProcessedVideoId;

  // Timer for polling the server
  Timer? _pollingTimer;

  // Status flags
  bool _isRunning = false;
  bool _isProcessing = false;

  // Event callbacks
  Function(BeeCount)? onNewAnalysisComplete;
  Function(String)? onStatusUpdate;
  Function(String)? onError;

  // Polling interval
  final Duration _pollingInterval = Duration(minutes: 5);

  // Retry configuration
  final int _maxRetries = 3;
  final Duration _retryDelay = Duration(seconds: 2);

  // Getters
  bool get isRunning => _isRunning;
  bool get isProcessing => _isProcessing;

  // Constructor - starts monitoring immediately if autoStart is true
  AutoVideoProcessingService({bool autoStart = false}) {
    if (autoStart) {
      startMonitoring();
    }
  }

  // Start the automatic monitoring service
  void startMonitoring({String? hiveId}) {
    if (_isRunning) return;

    _isRunning = true;
    _updateStatus('Starting automatic video monitoring service');

    // Run immediately once
    _checkForNewVideos(hiveId);

    // Then set up periodic polling
    _pollingTimer = Timer.periodic(_pollingInterval, (_) {
      _checkForNewVideos(hiveId);
    });

    notifyListeners();
  }

  // Stop the monitoring service
  void stopMonitoring() {
    if (!_isRunning) return;

    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isRunning = false;
    _updateStatus('Automatic video monitoring stopped');

    notifyListeners();
  }

  // Dispose method to cleanup resources when service is no longer needed
  void dispose() {
    stopMonitoring();
    _client.close();
    super.dispose();
  }

  // Check for new videos and process them
  Future<void> _checkForNewVideos(String? hiveId) async {
    if (_isProcessing) {
      _updateStatus('Already processing a video, skipping this check');
      return;
    }

    try {
      _isProcessing = true;
      _updateStatus('Checking for new videos...');

      // Fetch the latest video
      final latestVideo = await fetchLatestVideoFromServer(hiveId ?? 'default');

      if (latestVideo != null) {
        _updateStatus('Found video: ${latestVideo.id}');

        // Check if we've already processed this video
        if (latestVideo.id != _lastProcessedVideoId) {
          _updateStatus('New video detected. Starting analysis...');

          // Process the new video
          final result = await processServerVideo(
            latestVideo,
            onStatusUpdate: (status) {
              _updateStatus('Analysis: $status');
            },
          );

          if (result != null) {
            _lastProcessedVideoId = latestVideo.id;
            _updateStatus('Analysis complete and saved to database');

            // Notify listeners if callback is provided
            if (onNewAnalysisComplete != null) {
              onNewAnalysisComplete!(result);
            }
          } else {
            _updateStatus('Analysis failed');
          }
        } else {
          _updateStatus('Video already processed, skipping');
        }
      } else {
        _updateStatus('No new videos found');
      }
    } catch (e) {
      _handleError('Error checking for new videos: $e');
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  // Manual trigger option - force check for new videos
  Future<bool> manualCheckForVideos(String hiveId) async {
    if (_isProcessing) {
      _updateStatus('Already processing a video. Please wait.');
      return false;
    }

    await _checkForNewVideos(hiveId);
    return true;
  }

  // Update status and notify listeners via callback
  void _updateStatus(String status) {
    if (kDebugMode) {
      print('AutoVideoProcessingService: $status');
    }

    if (onStatusUpdate != null) {
      onStatusUpdate!(status);
    }
  }

  // Handle errors and notify via callback
  void _handleError(String errorMessage) {
    if (kDebugMode) {
      print('ERROR: $errorMessage');
    }

    if (onError != null) {
      onError!(errorMessage);
    }
  }

  // Make this method public so it can be called from background_video_processing_service
  Future<VideoData?> fetchLatestVideoFromServer(String hiveId) async {
    int retryCount = 0;

    while (retryCount < _maxRetries) {
      try {
        final response = await _client.get(
          Uri.parse('$baseUrl/videos/latest?hiveId=$hiveId'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data != null && data['success'] == true && data['data'] != null) {
            return VideoData.fromJson(data['data']);
          } else {
            _updateStatus('No videos available for processing');
            return null;
          }
        } else if (response.statusCode == 404) {
          _updateStatus('No videos found for hive: $hiveId');
          return null;
        } else {
          throw Exception('Server error: ${response.statusCode}');
        }
      } catch (e) {
        retryCount++;
        if (retryCount >= _maxRetries) {
          _handleError('Failed to fetch videos after $_maxRetries attempts: $e');
          return null;
        }

        _updateStatus('Retrying video fetch (${retryCount}/$_maxRetries)...');
        await Future.delayed(_retryDelay);
      }
    }

    return null;
  }

  // Make this method public and fix onProgress parameter usage
  Future<BeeCount?> processServerVideo(
    VideoData video, {
    Function(String)? onStatusUpdate,
  }) async {
    try {
      // Download the video if needed or get its URL
      final videoUrl = video.videoUrl;

      // Use the bee analysis service to process the video
      final analysisResult = await _beeAnalysisService.analyzeVideo(
        videoUrl,
        video.id,
        video.hiveId,
        // Make sure onProgress is defined in BeeAnalysisService.analyzeVideo method
        onProgress: (double progress) {
          if (onStatusUpdate != null) {
            onStatusUpdate('${(progress * 100).toInt()}% complete');
          }
        },
      );

      if (analysisResult != null) {
        // Save to database
        final beeCount = BeeCount(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          videoId: video.id,
          hiveId: video.hiveId,
          timestamp: DateTime.now(),
          // Make sure these property names match with what's used in background service
          beesEntering: analysisResult.beesEntering, // or inCount
          beesExiting: analysisResult.beesExiting,   // or outCount
          confidence: analysisResult.confidence,     // Make sure this property exists
        );

        await BeeCountDatabase.instance.updateBeeCount(beeCount);
        return beeCount;
      }

      return null;
    } catch (e) {
      _handleError('Error processing video: $e');
      return null;
    }
  }
}

// VideoData model to hold video information from the server
class VideoData {
  final String id;
  final String hiveId;
  final String videoUrl;
  final DateTime recordedAt;

  VideoData({
    required this.id,
    required this.hiveId,
    required this.videoUrl,
    required this.recordedAt,
  });

  factory VideoData.fromJson(Map<String, dynamic> json) {
    return VideoData(
      id: json['id'],
      hiveId: json['hiveId'],
      videoUrl: json['videoUrl'],
      recordedAt: DateTime.parse(json['recordedAt']),
    );
  }
}
