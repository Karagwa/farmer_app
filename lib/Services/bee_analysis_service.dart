// lib/Services/bee_analysis_service.dart (updated to use your existing analyzer)

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:HPGM/bee_counter/bee_counter_model.dart';
import 'package:HPGM/bee_counter/bee_count_database.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:HPGM/bee_counter/bee_video_analyzer.dart'; // Your existing analyzer

class BeeAnalysisService {
  static final BeeAnalysisService _instance = BeeAnalysisService._internal();
  factory BeeAnalysisService() => _instance;
  BeeAnalysisService._internal();
  static BeeAnalysisService get instance => _instance;

  // ML analyzer instance - using your existing analyzer
  BeeVideoAnalyzer? _analyzer;
  bool _isInitialized = false;
  bool _isInitializing = false;

  /// Initialize the ML model
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    if (_isInitializing) {
      // Wait for initialization to complete
      int attempts = 0;
      while (_isInitializing && attempts < 10) {
        await Future.delayed(Duration(seconds: 1));
        attempts++;
      }
      return _isInitialized;
    }

    _isInitializing = true;

    try {
      print('Initializing BeeAnalysisService with your existing ML model...');

      // Use your existing BeeVideoAnalyzer
      _analyzer = BeeVideoAnalyzer(
        updateState: (fn) {
          // Empty function for background processing
          fn();
        },
      );

      final success = await _analyzer!.initialize();
      _isInitialized = success;

      print('ML model initialization: ${success ? "SUCCESS" : "FAILED"}');
      return success;
    } catch (e, stack) {
      print('Error initializing ML model: $e');
      print('Stack trace: $stack');
      _isInitialized = false;
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Analyze video using your REAL ML model
  Future<BeeCount?> analyzeVideoWithML(
    String hiveId,
    String videoId,
    String videoPath, {
    Function(double)? onProgress,
  }) async {
    try {
      print('=== STARTING ML VIDEO ANALYSIS ===');
      print('Video ID: $videoId');
      print('Hive ID: $hiveId');
      print('Video Path: $videoPath');

      // Initialize ML if not already done
      if (!_isInitialized) {
        print('ML model not initialized, initializing now...');
        final success = await initialize();
        if (!success) {
          print('ERROR: Failed to initialize ML model');
          return null;
        }
      }

      // Check if file exists
      final videoFile = File(videoPath);
      if (!await videoFile.exists()) {
        print('ERROR: Video file does not exist at path: $videoPath');
        return null;
      }

      final fileSize = await videoFile.length();
      print(
        'Video file exists. Size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB',
      );

      // Progress update
      onProgress?.call(0.1);

      // Process video with your existing ML model
      print('Processing video with your existing ML model...');
      final analysisResult = await _analyzer!.processVideoFile(
        videoFile,
        videoId,
        onStatusUpdate: (status) {
          print('ML Status: $status');
          // Convert status to progress if possible
          if (status.contains('%')) {
            try {
              final match = RegExp(r'(\d+(?:\.\d+)?)%').firstMatch(status);
              if (match != null) {
                final progress = double.parse(match.group(1)!) / 100;
                onProgress?.call(0.1 + progress * 0.8); // Scale to 10-90%
              }
            } catch (e) {
              // Ignore parsing errors
            }
          } else if (status.contains('frame') && status.contains('/')) {
            // Parse "Analyzing frame X/Y..." format
            try {
              final match = RegExp(r'frame (\d+)/(\d+)').firstMatch(status);
              if (match != null) {
                final current = double.parse(match.group(1)!);
                final total = double.parse(match.group(2)!);
                final progress = current / total;
                onProgress?.call(0.1 + progress * 0.8); // Scale to 10-90%
              }
            } catch (e) {
              // Ignore parsing errors
            }
          }
        },
      );

      if (analysisResult == null) {
        print('ERROR: ML analysis returned null');
        return null;
      }

      print('=== ML ANALYSIS COMPLETE ===');
      print(
        'Results: ${analysisResult.beesIn} bees in, ${analysisResult.beesOut} bees out',
      );
      print(
        'Confidence: ${analysisResult.detectionConfidence.toStringAsFixed(1)}%',
      );
      print(
        'Processing time: ${analysisResult.processingTime.toStringAsFixed(1)}s',
      );
      print('Frames analyzed: ${analysisResult.framesAnalyzed}');

      // Convert your BeeAnalysisResult to BeeCount and save to database
      // IMPORTANT: Use the video's original timestamp, not the processing timestamp
      final videoTimestamp = _extractTimestampFromVideoId(videoId) ?? analysisResult.timestamp;
      
      final beeCount = BeeCount(
        id: analysisResult.id,
        hiveId: hiveId,
        videoId: videoId,
        beesEntering: analysisResult.beesIn,
        beesExiting: analysisResult.beesOut,
        timestamp: videoTimestamp, // Use video timestamp instead of processing timestamp
        confidence: analysisResult.detectionConfidence,
        notes:
            'ML processed. Model: ${analysisResult.modelVersion}, Processing time: ${analysisResult.processingTime.toStringAsFixed(1)}s, Frames: ${analysisResult.framesAnalyzed}',
      );

      try {
        // Save to database
        await BeeCountDatabase.instance.createBeeCount(beeCount);
        print('Bee count saved to database successfully');
      } catch (e, stack) {
        print('ERROR saving to database: $e');
        print('Stack trace: $stack');
        // Continue anyway - we'll return the result even if DB save fails
      }

      // Final progress update
      onProgress?.call(1.0);

      return beeCount;
    } catch (e, stack) {
      print('ERROR in ML video analysis: $e');
      print('Stack trace: $stack');
      return null;
    }
  }

  /// Download video from URL with improved error handling
  Future<String?> downloadVideo(
    String url, {
    Function(double)? onProgress,
  }) async {
    final client = http.Client();
    try {
      print('=== DOWNLOADING VIDEO ===');
      print('URL: $url');

      if (!url.startsWith('http')) {
        throw Exception('Invalid URL: $url');
      }

      onProgress?.call(0.0);

      // Try different ways to download the video
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          print('Download attempt $attempt/3');

          // Make request with streaming
          final request = http.Request('GET', Uri.parse(url));
          final response = await client
              .send(request)
              .timeout(Duration(seconds: 30));

          if (response.statusCode != 200) {
            print(
              'Failed to download: HTTP ${response.statusCode}, trying again...',
            );
            continue;
          }

          // Get content length for progress tracking
          final contentLength = response.contentLength ?? 0;
          print(
            'Content length: ${(contentLength / 1024 / 1024).toStringAsFixed(2)} MB',
          );

          // Get temporary directory
          final directory = await getTemporaryDirectory();
          final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
          final filePath = '${directory.path}/$fileName';

          // Write file with progress tracking
          final file = File(filePath);
          final sink = file.openWrite();

          int downloadedBytes = 0;

          await for (final chunk in response.stream) {
            sink.add(chunk);
            downloadedBytes += chunk.length;

            if (contentLength > 0) {
              final progress = downloadedBytes / contentLength;
              onProgress?.call(progress * 0.9); // Reserve 10% for final write
            }
          }

          await sink.close();
          onProgress?.call(1.0);

          final fileSize = await file.length();
          print('Video downloaded successfully');
          print('File path: $filePath');
          print('File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

          return filePath;
        } catch (e, stack) {
          print('Error in download attempt $attempt: $e');
          print('Stack trace: $stack');

          if (attempt == 3) throw e; // Re-throw on last attempt
          await Future.delayed(Duration(seconds: 2)); // Wait before retrying
        }
      }

      return null; // Should never reach here, but needed for compilation
    } catch (e, stack) {
      print('ERROR downloading video: $e');
      print('Stack trace: $stack');
      return null;
    } finally {
      client.close();
    }
  }

  /// Clean up resources
  void dispose() {
    print('Disposing BeeAnalysisService resources');
    _analyzer?.dispose();
    _analyzer = null;
    _isInitialized = false;
  }

  /// Extract timestamp from video ID (e.g., "1_2025-05-24_073136.mp4")
  DateTime? _extractTimestampFromVideoId(String videoId) {
    try {
      // Parse video ID format: "1_2025-05-24_073136.mp4"
      final parts = videoId.split('_');
      if (parts.length >= 3) {
        final datePart = parts[1]; // "2025-05-24"
        final timePart = parts[2].split('.')[0]; // "073136"

        final year = int.parse(datePart.substring(0, 4));
        final month = int.parse(datePart.substring(5, 7));
        final day = int.parse(datePart.substring(8, 10));

        final hour = int.parse(timePart.substring(0, 2));
        final minute = int.parse(timePart.substring(2, 4));
        final second = int.parse(timePart.substring(4, 6));

        final timestamp = DateTime(year, month, day, hour, minute, second);
        print('Extracted timestamp from video ID $videoId: $timestamp');
        return timestamp;
      }
    } catch (e) {
      print('Error extracting timestamp from video ID $videoId: $e');
    }
    return null;
  }
}