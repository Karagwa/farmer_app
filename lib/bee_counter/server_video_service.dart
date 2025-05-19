import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:HPGM/bee_counter/bee_counter_model.dart';
import 'package:HPGM/Services/bee_analysis_service.dart';
import 'package:HPGM/bee_counter/bee_count_database.dart';
import 'dart:async';

class ServerVideoService {
  // API base URL
  final String baseUrl = 'http://196.43.168.57/api/v1';
  final BeeAnalysisService _beeAnalysisService = BeeAnalysisService();

  // HTTP client
  final http.Client _client = http.Client();

  // Cache for latest video to use as fallback
  ServerVideo? _cachedVideo;
  DateTime _lastCacheTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Retry configuration
  final int _maxRetries = 3;
  final Duration _retryDelay = Duration(seconds: 2);

  // Fetch only the latest video from server
  Future<List<ServerVideo>> fetchVideosFromServer(String hiveId) async {
    try {
      // Get only the latest video
      final latestVideo = await fetchLatestVideoFromServer(hiveId);
      
      // Return as a list containing only the latest video
      if (latestVideo != null) {
        return [latestVideo];
      } else {
        print('No latest video available from server');
        return [];
      }
    } catch (e) {
      print('Error fetching videos: $e');
      return [];
    }
  }

  Future<ServerVideo?> fetchLatestVideoFromServer(String hiveId) async {
    try {
      // Build the URL for latest video only
      String url = '$baseUrl/vids/latest';
      
      print('Fetching latest video from: $url');

      // Try with retries
      for (int attempt = 0; attempt < _maxRetries; attempt++) {
        try {
          final response = await _client.get(Uri.parse(url));

          if (response.statusCode == 200) {
            print('Response body: ${response.body}');
            final Map<String, dynamic> responseData = json.decode(response.body);
            
            // Handle the actual response structure
            if (responseData.containsKey('video')) {
              final videoData = responseData['video'];
              
              // Use ServerVideo.fromJson constructor to create object
              final serverVideo = ServerVideo.fromJson(videoData);
              
              print('Successfully parsed video: ${serverVideo.id} - ${serverVideo.url}');
              
              // Update cache
              _cachedVideo = serverVideo;
              _lastCacheTime = DateTime.now();
              
              // Check if this is a new video
              _checkAndAnalyzeNewVideo(hiveId, serverVideo);
              
              return serverVideo;
            } else {
              print('Response does not contain video data: $responseData');
            }
          } else {
            print('Server returned status code: ${response.statusCode}');
            print('Response body: ${response.body}');
          }
          
          // If response was not 200 or no videos, try again
          if (attempt < _maxRetries - 1) {
            print('Retrying in ${_retryDelay.inSeconds} seconds...');
            await Future.delayed(_retryDelay);
          }
          
        } catch (e) {
          print('Attempt ${attempt + 1} failed: $e');
          if (attempt < _maxRetries - 1) {
            await Future.delayed(_retryDelay);
          }
        }
      }
      
      // If all attempts fail, check if we have a cached video
      if (_cachedVideo != null && 
          DateTime.now().difference(_lastCacheTime).inMinutes < 30) {
        print('Using cached latest video');
        return _cachedVideo;
      }
      
      // If online fetch fails and no valid cache, return null
      print('Could not retrieve video from server and no valid cache available');
      return null;
      
    } catch (e) {
      print('Error fetching latest video: $e');
      return null;
    }
  }

  // Process a server video and analyze it
  Future<BeeCount?> processServerVideo(
    ServerVideo video, {
    required Function(String) onStatusUpdate,
  }) async {
    try {
      onStatusUpdate('Downloading video...');

      // Download the video
      final videoPath = await _beeAnalysisService.downloadVideo(
        video.url,
        onProgress: (progress) {
          onStatusUpdate(
            'Downloading video: ${(progress * 100).toStringAsFixed(1)}%',
          );
        },
      );

      if (videoPath == null) {
        onStatusUpdate('Failed to download video: Could not save video to storage');
        return null;
      }

      print('Video successfully downloaded to: $videoPath');
      onStatusUpdate('Processing video with ML model...');

      // Extract hive ID from video name (assuming format like "1_date_time.mp4")
      final hiveId = video.id.split('_').first;
      print('Extracted hive ID: $hiveId from video ID: ${video.id}');

      // Analyze the video using the ML model - NOTE: Parameter order fixed here!
      try {
        print('Starting video analysis for path: $videoPath');
        final result = await _beeAnalysisService.analyzeVideo(
          hiveId,      // First parameter should be hiveId
          video.id,    // Second parameter should be videoId
          videoPath,   // Third parameter should be videoPath
        );

        if (result != null) {
          print('Analysis completed successfully: ${result.toString()}');
          onStatusUpdate('Analysis complete');
          return result;
        } else {
          print('ERROR: BeeAnalysisService.analyzeVideo returned null');
          onStatusUpdate('Analysis failed: ML model could not process the video. Please check format and quality.');
          return null;
        }
      } catch (analysisError) {
        print('ERROR in analyzeVideo: $analysisError');
        onStatusUpdate('Analysis failed: ${analysisError.toString()}');
        return null;
      }
    } catch (e) {
      print('Error processing video: $e');
      onStatusUpdate('Error: $e');
      return null;
    }
  }

  // Check if a video is new and analyze it automatically
  Future<void> _checkAndAnalyzeNewVideo(
    String hiveId,
    ServerVideo video,
  ) async {
    try {
      // Check if we've already analyzed this video
      final beeCounts = await BeeCountDatabase.instance.readAllBeeCounts();
      final alreadyAnalyzed = beeCounts.any(
        (count) => count.videoId == video.id,
      );

      if (!alreadyAnalyzed) {
        print('New video detected: ${video.id}. Starting automatic analysis...');

        // Process the video automatically
        await processServerVideo(
          video,
          onStatusUpdate: (status) {
            print('Auto-analysis status: $status');
          },
        );
      }
    } catch (e) {
      print('Error in automatic video analysis: $e');
    }
  }

  // Get bee counts for a specific date
  Future<List<BeeCount>> getBeeCountsForDate(
    String hiveId,
    DateTime date,
  ) async {
    return await BeeCountDatabase.instance.readBeeCountsByDate(date);
  }

  // Get all bee counts for a hive
  Future<List<BeeCount>> getAllBeeCountsForHive(String hiveId) async {
    return await BeeCountDatabase.instance.readBeeCountsByHiveId(hiveId);
  }

  // Clean up resources
  void dispose() {
    _beeAnalysisService.dispose();
    _client.close();
  }
}