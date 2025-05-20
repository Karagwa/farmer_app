import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:HPGM/bee_counter/bee_counter_model.dart';
import 'package:HPGM/Services/bee_analysis_service.dart';
import 'package:HPGM/bee_counter/bee_count_database.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Predefined video intervals (in hours)
  final List<int> _videoIntervals = [7, 12, 18]; // Morning, Noon, Evening

  // Fetch videos from server with time interval filtering
  Future<List<ServerVideo>> fetchVideosFromServer(
    String hiveId, {
    bool fetchAllIntervals = false,
  }) async {
    try {
      List<ServerVideo> videos = [];

      if (fetchAllIntervals) {
        // Fetch videos for all intervals
        for (final interval in _videoIntervals) {
          final video = await fetchVideoForInterval(hiveId, interval);
          if (video != null) {
            videos.add(video);
          }
        }
      } else {
        // Get only the latest video
        final latestVideo = await fetchLatestVideoFromServer(hiveId);
        if (latestVideo != null) {
          videos.add(latestVideo);
        }
      }

      return videos;
    } catch (e) {
      print('Error fetching videos: $e');
      return [];
    }
  }

  // Fetch a video for a specific time interval (morning, noon, evening)
  Future<ServerVideo?> fetchVideoForInterval(
    String hiveId, 
    int hourOfDay,
  ) async {
    try {
      // Build URL to fetch videos
      String url = '$baseUrl/vids/latest';
      
      final response = await _client.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final List<dynamic> videos = json.decode(response.body)['videos'];
        
        // Find the most recent video that matches the time interval
        ServerVideo? matchingVideo;
        DateTime? mostRecentTime;
        
        for (final videoData in videos) {
          final video = ServerVideo.fromJson(videoData);
          
          // Skip videos with no timestamp
          if (video.timestamp == null) continue;
          
          // Check if this video is from the requested time interval (±1 hour)
          final videoHour = video.timestamp!.hour;
          if ((videoHour >= hourOfDay - 1) && (videoHour <= hourOfDay + 1)) {
            // Check if this is the most recent video for this interval
            if (mostRecentTime == null || video.timestamp!.isAfter(mostRecentTime)) {
              matchingVideo = video;
              mostRecentTime = video.timestamp;
            }
          }
        }
        
        if (matchingVideo != null) {
          return matchingVideo;
        }
      }
      
      return null;
    } catch (e) {
      print('Error fetching video for interval $hourOfDay: $e');
      return null;
    }
  }

  // Fetch only the latest video from server
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
    required String hiveId,
    required Function(String) onStatusUpdate,
  }) async {
    try {
      onStatusUpdate('Downloading video...');

      // Check if we've already processed this video
      final beeCounts = await BeeCountDatabase.instance.getAllBeeCounts();
      final alreadyProcessed = beeCounts.any((count) => count.videoId == video.id);
      
      if (alreadyProcessed) {
        onStatusUpdate('Video already processed: ${video.id}');
        // Return the existing count
        final existingCount = beeCounts.firstWhere(
          (count) => count.videoId == video.id,
          orElse: () => BeeCount(
            hiveId: hiveId,
            beesEntering: 0,
            beesExiting: 0,
            timestamp: DateTime.now(),
          ),
        );
        return existingCount;
      }

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
      final extractedHiveId = video.id.split('_').first;
      
      // Use provided hiveId unless it's empty, then fall back to extracted one
      final finalHiveId = hiveId.isNotEmpty ? hiveId : extractedHiveId;
      
      print('Using hive ID: $finalHiveId for video ID: ${video.id}');

      // Analyze the video using the ML model
      try {
        print('Starting video analysis for path: $videoPath');
        final result = await _beeAnalysisService.analyzeVideo(
          finalHiveId,
          video.id,
          videoPath,
        );

        if (result != null) {
          print('Analysis completed successfully: ${result.toString()}');
          onStatusUpdate('Analysis complete');
          
          // Save the analysis timestamp in shared preferences
          await _saveVideoProcessTime(video.id);
          
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

  // Save last processed time for a video
  Future<void> _saveVideoProcessTime(String videoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('video_${videoId}_processed_at', 
        DateTime.now().toIso8601String());
    } catch (e) {
      print('Error saving video process time: $e');
    }
  }

  // Check if a video has been processed within the last day
  Future<bool> hasVideoBeenProcessedRecently(String videoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final processedTimeStr = prefs.getString('video_${videoId}_processed_at');
      
      if (processedTimeStr == null) return false;
      
      final processedTime = DateTime.parse(processedTimeStr);
      final now = DateTime.now();
      
      // Check if processed within the last 24 hours
      return now.difference(processedTime).inHours < 24;
    } catch (e) {
      print('Error checking video process time: $e');
      return false;
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
    return await BeeCountDatabase.instance.getBeeCountsForHive(hiveId);
  }

  // Clean up resources
  void dispose() {
    _beeAnalysisService.dispose();
    _client.close();
  }
}