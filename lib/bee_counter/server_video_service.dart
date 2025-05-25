

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:HPGM/bee_counter/bee_counter_model.dart';
import 'package:HPGM/Services/bee_analysis_service.dart';
import 'package:HPGM/bee_counter/bee_count_database.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ServerVideoService {
  // API configuration
  final String baseUrl = 'http://196.43.168.57/api/v1';
  final BeeAnalysisService _beeAnalysisService = BeeAnalysisService();
  final http.Client _client = http.Client();

  // Retry configuration
  final int _maxRetries = 5; 
  final Duration _retryDelay = Duration(seconds: 3); 

  /// Fetch videos from server - 
  Future<List<ServerVideo>> fetchVideosFromServer(
    String hiveId, {
    DateTime? specificDate,
  }) async {
    
    print('Hive ID: $hiveId');
    print('Date: ${specificDate?.toString() ?? "today"}');

    try {
      List<ServerVideo> allVideos = await _fetchAllVideosFromServer(hiveId);

      if (allVideos.isEmpty) {
        print('No videos available from server');
        return [];
      }

      // Filter videos for the specific date if provided
      if (specificDate != null) {
        allVideos = _filterVideosByDate(allVideos, specificDate);
      }

      print('Returning ${allVideos.length} videos');
      return allVideos;
    } catch (e, stack) {
      print('ERROR fetching videos from server: $e');
      print('Stack trace: $stack');
      return [];
    }
  }

  /// Filter videos by date
  List<ServerVideo> _filterVideosByDate(
    List<ServerVideo> videos,
    DateTime targetDate,
  ) {
    final dateVideos =
        videos.where((video) {
          if (video.timestamp == null) return false;

          return video.timestamp!.year == targetDate.year &&
              video.timestamp!.month == targetDate.month &&
              video.timestamp!.day == targetDate.day;
        }).toList();

    print(
      'Filtered ${videos.length} videos to ${dateVideos.length} for date ${targetDate.toString().split(' ')[0]}',
    );
    return dateVideos;
  }

  // Fetch all available videos from server
  
  Future<List<ServerVideo>> _fetchAllVideosFromServer(String hiveId) async {
    List<ServerVideo> allVideos = [];

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        print('Fetch attempt ${attempt + 1}/$_maxRetries');

        // Try different API endpoints
        final endpoints = [
          '$baseUrl/vids/latest', 
          '$baseUrl/vids',
          
        ];

        for (final endpoint in endpoints) {
          try {
            print('Trying endpoint: $endpoint');

            final response = await _client
                .get(
                  Uri.parse(endpoint),
                  headers: {'Accept': 'application/json'},
                )
                .timeout(Duration(seconds: 15));

            print('Response status: ${response.statusCode}');

            if (response.statusCode == 200) {
              print('Success! Response length: ${response.body.length} bytes');
              print(
                'Response preview: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}...',
              );

              // Parse response
              final responseData = json.decode(response.body);

              // Handle the specific format you showed
              if (responseData is Map && responseData.containsKey('video')) {
                print('Found "video" object in response');
                try {
                  final videoData = responseData['video'];
                  final video = ServerVideo.fromJson(
                    Map<String, dynamic>.from(videoData),
                  );
                  print('Successfully parsed video: ${video.id}');
                  allVideos.add(video);
                } catch (e) {
                  print('Error parsing "video" object: $e');
                }
              }
              // Handle other possible formats as fallbacks
              else if (responseData is List) {
                print('Response is a list of videos');
                // Process list of videos...
              }
              
              if (allVideos.isNotEmpty) {
                print(
                  'Successfully fetched ${allVideos.length} videos from $endpoint',
                );
                return allVideos;
              }
            }
          } catch (e) {
            print('Error with endpoint $endpoint: $e');
          }
        }

        // If no videos found, wait before retry
        if (attempt < _maxRetries - 1) {
          print(
            'No videos found, retrying in ${_retryDelay.inSeconds} seconds...',
          );
          await Future.delayed(_retryDelay);
        }
      } catch (e) {
        print('Attempt ${attempt + 1} failed: $e');
      }
    }

    print('Total videos fetched: ${allVideos.length}');
    return allVideos;
  }
  
// Fetch the latest video from the server
  Future<ServerVideo?> fetchLatestVideoFromServer(String hiveId) async {
    print('Hive ID: $hiveId');
    try {
      // Use the vids/latest endpoints
      final String endpoint = '$baseUrl/vids/latest';
      print('Trying endpoint: $endpoint');
      
      final response = await _client
          .get(
            Uri.parse(endpoint),
            headers: {'Accept': 'application/json'},
          )
          .timeout(Duration(seconds: 15));
      
      
      if (response.statusCode == 200) {
        print('Success! Response length: ${response.body.length} bytes');
        
        try {
          // Parse response -
          final responseData = json.decode(response.body);
          
          // Check if there's a video object in the response
          if (responseData is Map && responseData.containsKey('video')) {
            print('Found "video" object in response');
            final videoData = responseData['video'];
            final video = ServerVideo.fromJson(
              Map<String, dynamic>.from(videoData),
            );
            print('Successfully parsed latest video: ${video.id}');
            return video;
          } else {
            print('Response preview: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}');
          }
        } catch (e, stack) {
        
          print('Stack trace: $stack');
        }
      } else {
        print('Endpoint returned status: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
      
       // fall back to fetching all videos and sorting
      print('Falling back to fetching all videos and finding the latest');
      final allVideos = await fetchVideosFromServer(hiveId);
      if (allVideos.isNotEmpty) {
        // Sort by timestamp descending to get the most recent first
        allVideos.sort((a, b) => 
          (b.timestamp ?? DateTime(1970)).compareTo(a.timestamp ?? DateTime(1970))
        );
        print('Found latest video from all videos: ${allVideos.first.id}');
        return allVideos.first;
      }
      
      return null;
    } catch (e, stack) {
      print('ERROR fetching latest video from server: $e');
      print('Stack trace: $stack');
      return null;
    }
  }

  /// Process server video with ML model
  Future<BeeCount?> processServerVideo(
    ServerVideo video, {
    required String hiveId,
    required Function(String) onStatusUpdate,
  }) async {
    try {
    
      print('Video ID: ${video.id}');
      print('Video URL: ${video.url}');
      print('Video Timestamp: ${video.timestamp}');
      print('Hive ID: $hiveId');

      onStatusUpdate('Checking video status...');

      // Check if already processed
      final isProcessed = await BeeCountDatabase.instance.isVideoProcessed(
        video.id,
      );
      if (isProcessed) {
        print('Video already processed: ${video.id}');
        onStatusUpdate('Video already processed');

        // Return existing count
        final counts = await BeeCountDatabase.instance.getAllBeeCounts();
        final existingCount = counts.firstWhere(
          (count) => count.videoId == video.id,
          orElse:
              () => BeeCount(
                hiveId: hiveId,
                videoId: video.id,
                beesEntering: 0,
                beesExiting: 0,
                timestamp: video.timestamp ?? DateTime.now(),
              ),
        );
        return existingCount;
      }

      onStatusUpdate('Downloading video from server...');

      // Download video
      final videoPath = await _beeAnalysisService.downloadVideo(
        video.url,
        onProgress: (progress) {
          onStatusUpdate(
            'Downloading: ${(progress * 100).toStringAsFixed(1)}%',
          );
        },
      );

      if (videoPath == null) {
        onStatusUpdate('Failed to download video');
        return null;
      }

      print('Video downloaded successfully: $videoPath');
      onStatusUpdate('Starting ML video analysis...');

      // Extract hive ID from video name if needed
      final extractedHiveId = video.id.split('_').first;
      final finalHiveId = hiveId.isNotEmpty ? hiveId : extractedHiveId;

      print('Using hive ID: $finalHiveId for video: ${video.id}');

      // Optimize video handling to reduce memory pressure
      if (videoPath != null) {
        // Create a temporary directory for extracted frames
        final tempDir = await getTemporaryDirectory();
        final processingDir = Directory('${tempDir.path}/video_processing');

        try {
          // Clean up old files if any exist
          if (await processingDir.exists()) {
            await processingDir.delete(recursive: true);
          }
          await processingDir.create();

          // Analyze video with ML model
          final result = await _beeAnalysisService.analyzeVideoWithML(
            finalHiveId,
            video.id,
            videoPath,
            onProgress: (progress) {
              onStatusUpdate(
                'Analyzing: ${(progress * 100).toStringAsFixed(1)}%',
              );
            },
          );

          if (result != null) {
            print('ML analysis completed successfully');
            print(
              'Results: ${result.beesEntering} in, ${result.beesExiting} out',
            );
            print('Confidence: ${result.confidence.toStringAsFixed(1)}%');

            onStatusUpdate(
              'Analysis complete - ${result.beesEntering} bees in, ${result.beesExiting} bees out',
            );

            // Ensure the timestamp from the video is used
            final beeCountWithCorrectTime = result.copyWith(
              timestamp: video.timestamp ?? result.timestamp,
            );

            return beeCountWithCorrectTime;
          } else {
            print('ERROR: ML video analysis failed');
            onStatusUpdate('ML video analysis failed');
            return null;
          }
        } finally {
          // Always clean up the processing directory when done
          try {
            if (await processingDir.exists()) {
              await processingDir.delete(recursive: true);
            }
          } catch (e) {
            print('Cleanup error: $e');
          }
        }
      }
    } catch (e, stack) {
      print('ERROR processing video: $e');
      print('Stack trace: $stack');
      onStatusUpdate('Error: $e');
      return null;
    }
  }

  /// Get bee counts for specific date
  Future<List<BeeCount>> getBeeCountsForDate(
    String hiveId,
    DateTime date,
  ) async {
    final counts = await BeeCountDatabase.instance.readBeeCountsByDate(date);
    return counts.where((count) => count.hiveId == hiveId).toList();
  }

  /// Clean up resources
  void dispose() {
    print('Disposing ServerVideoService resources');
    _beeAnalysisService.dispose();
    _client.close();
  }
}

