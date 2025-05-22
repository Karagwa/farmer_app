import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:farmer_app/bee_counter/bee_counter_model.dart';
import 'package:farmer_app/Services/bee_analysis_service.dart';
import 'package:farmer_app/bee_counter/bee_count_database.dart';
import 'package:farmer_app/bee_counter/bee_counter_integration.dart';
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

  // Fetch a video for a specific time interval with proper error handling
  Future<ServerVideo?> fetchVideoForInterval(
    String hiveId,
    int hourOfDay,
  ) async {
    try {
      // Build URL to fetch videos - using the same endpoint as latest
      String url = '$baseUrl/vids/latest';

      print('Fetching videos for interval $hourOfDay from: $url');

      final response = await _client.get(Uri.parse(url));

      if (response.statusCode == 200) {
        print('Response body for interval $hourOfDay: ${response.body}');

        final Map<String, dynamic> responseData = json.decode(response.body);

        // Handle different response structures
        List<dynamic> videos = [];

        if (responseData.containsKey('videos') &&
            responseData['videos'] != null) {
          // Multiple videos response
          videos = responseData['videos'] as List<dynamic>;
          print('Found ${videos.length} videos in response');
        } else if (responseData.containsKey('video') &&
            responseData['video'] != null) {
          // Single video response - convert to list
          videos = [responseData['video']];
          print('Found single video in response, converted to list');
        } else {
          print('No videos found in response for interval $hourOfDay');
          return null;
        }

        if (videos.isEmpty) {
          print('No videos available for interval $hourOfDay');
          return null;
        }

        // Find the most recent video that matches the time interval
        ServerVideo? matchingVideo;
        DateTime? mostRecentTime;

        for (final videoData in videos) {
          try {
            final video = ServerVideo.fromJson(
              videoData as Map<String, dynamic>,
            );

            // Skip videos with no timestamp
            if (video.timestamp == null) {
              print('Skipping video ${video.id} - no timestamp');
              continue;
            }

            // Check if this video is from the requested time interval (±1 hour)
            final videoHour = video.timestamp!.hour;
            if ((videoHour >= hourOfDay - 1) && (videoHour <= hourOfDay + 1)) {
              // Check if this is the most recent video for this interval
              if (mostRecentTime == null ||
                  video.timestamp!.isAfter(mostRecentTime)) {
                matchingVideo = video;
                mostRecentTime = video.timestamp;
                print(
                  'Found matching video for interval $hourOfDay: ${video.id} at ${video.timestamp}',
                );
              }
            }
          } catch (e) {
            print('Error parsing video data: $e');
            continue;
          }
        }

        if (matchingVideo != null) {
          print('Returning video ${matchingVideo.id} for interval $hourOfDay');
          return matchingVideo;
        } else {
          print('No matching video found for interval $hourOfDay');
        }
      } else {
        print(
          'Server returned status ${response.statusCode} for interval $hourOfDay',
        );
        print('Response: ${response.body}');
      }

      return null;
    } catch (e) {
      print('Error fetching video for interval $hourOfDay: $e');
      return null;
    }
  }

  // Improved error handling for latest video fetch
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

            try {
              final Map<String, dynamic> responseData = json.decode(
                response.body,
              );

              // Handle both single video and videos array responses
              ServerVideo? serverVideo;

              if (responseData.containsKey('video') &&
                  responseData['video'] != null) {
                // Single video response
                final videoData = responseData['video'] as Map<String, dynamic>;
                serverVideo = ServerVideo.fromJson(videoData);
                print(
                  'Successfully parsed single video: ${serverVideo.id} - ${serverVideo.url}',
                );
              } else if (responseData.containsKey('videos') &&
                  responseData['videos'] != null) {
                // Multiple videos response - get the latest one
                final videos = responseData['videos'] as List<dynamic>;
                if (videos.isNotEmpty) {
                  // Assume the first video is the latest
                  final videoData = videos.first as Map<String, dynamic>;
                  serverVideo = ServerVideo.fromJson(videoData);
                  print(
                    'Successfully parsed latest from videos array: ${serverVideo.id} - ${serverVideo.url}',
                  );
                }
              } else {
                print('Response does not contain video data: $responseData');
                continue; // Try next attempt
              }

              if (serverVideo != null) {
                // Update cache
                _cachedVideo = serverVideo;
                _lastCacheTime = DateTime.now();
                return serverVideo;
              }
            } catch (jsonError) {
              print('Error parsing JSON response: $jsonError');
              print('Raw response: ${response.body}');
            }
          } else {
            print('Server returned status code: ${response.statusCode}');
            print('Response body: ${response.body}');
          }

          // If response was not 200 or parsing failed, try again
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

      print('No videos available from server');
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
      final alreadyProcessed = beeCounts.any(
        (count) => count.videoId == video.id,
      );

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

        // If the existing count has actual bee counts, return it
        if (existingCount.beesEntering > 0 || existingCount.beesExiting > 0) {
          return existingCount;
        }
        // Otherwise, continue processing to get better counts
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
        onStatusUpdate(
          'Failed to download video: Could not save video to storage',
        );
        return null;
      }

      print('Video successfully available at: $videoPath');
      onStatusUpdate('Processing video with ML model...');

      // Extract hive ID from video name (assuming format like "1_date_time.mp4")
      final extractedHiveId = video.id.split('_').first;

      // Use provided hiveId unless it's empty, then fall back to extracted one
      final finalHiveId = hiveId.isNotEmpty ? hiveId : extractedHiveId;

      print(
          'Using hive ID: $finalHiveId for video ID: ${video.id}'); // Use our improved bee counter fix for more reliable results
      try {
        print('Starting enhanced video analysis for path: $videoPath');

        // Import the fix dynamically to avoid circular dependencies
        final beeCounterFix =
            await import('package:farmer_app/bee_counter/bee_counter_fix.dart');
        final countFix = beeCounterFix.BeeCounterFix.instance;

        final result = await countFix.processVideo(
            finalHiveId, video.id, videoPath, onStatusUpdate: (status) {
          onStatusUpdate('Analysis: $status');
        });

        print('Enhanced analysis completed successfully: ${result.toString()}');
        onStatusUpdate('Analysis complete');

        // Save the analysis timestamp in shared preferences
        await _saveVideoProcessTime(video.id);

        return result;
      } catch (analysisError) {
        print('ERROR in analyzeVideo: $analysisError');
        onStatusUpdate('Analysis failed: $analysisError');
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
      await prefs.setString(
        'video_${videoId}_processed_at',
        DateTime.now().toIso8601String(),
      );
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

  // Fetch videos for a specific interval
  Future<List<ServerVideo>> _fetchVideosForInterval(
    String hiveId,
    int interval,
  ) async {
    try {
      final url = '$baseUrl/videos/$hiveId/interval/$interval';
      print('Fetching videos from: $url');

      final response =
          await _client.get(Uri.parse(url)).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        // Check if response body is null or empty
        if (response.body == null || response.body.isEmpty) {
          print('Empty response for interval $interval');
          return [];
        }

        final jsonData = jsonDecode(response.body);

        // Handle case where API returns null instead of a list
        if (jsonData == null) {
          print('Null JSON response for interval $interval');
          return [];
        }

        // Handle case where API returns an object instead of a list
        if (jsonData is! List) {
          print('JSON response is not a list for interval $interval');
          return [];
        }

        return jsonData
            .map((videoJson) => ServerVideo.fromJson(videoJson))
            .toList();
      } else {
        print(
          'Error status code ${response.statusCode} for interval $interval',
        );
        return [];
      }
    } catch (e) {
      print('Error fetching video for interval $interval: $e');
      return []; // Return empty list instead of propagating error
    }
  }
}
