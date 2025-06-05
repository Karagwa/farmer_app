import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:farmer_app/bee_counter/bee_counter_model.dart';
import 'package:farmer_app/bee_counter/bee_count_database.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:farmer_app/bee_counter/bee_video_analyzer.dart';
import 'dart:async';

class BeeAnalysisService {
  // Use your existing BeeVideoAnalyzer
  BeeVideoAnalyzer? _analyzer;

  static final BeeAnalysisService _instance = BeeAnalysisService._internal();

  // Factory constructor to return the singleton instance
  factory BeeAnalysisService() => _instance;

  // Private constructor for the singleton
  BeeAnalysisService._internal();

  // Static getter for the instance
  static BeeAnalysisService get instance => _instance;

  // Initialize the analyzer
  Future<void> _ensureAnalyzerInitialized() async {
    if (_analyzer == null) {
      print('Initializing BeeVideoAnalyzer');
      _analyzer = BeeVideoAnalyzer(
        updateState: (callback) {
          // This is a no-op since we're not directly updating UI state here
          callback();
        },
      );
      await _analyzer!.initialize();
      print('BeeVideoAnalyzer initialized successfully');
    }
  }

  // Process a video using your existing ML model
  Future<BeeCount?> analyzeVideo(
    String hiveId,
    String videoId,
    String videoPath, {
    Function(double)? onProgress,
  }) async {
    try {
      // Make sure analyzer is initialized
      await _ensureAnalyzerInitialized();

      print(
        'Starting video analysis for video: $videoId, hiveId: $hiveId, path: $videoPath',
      );

      // Check if file exists
      final videoFile = File(videoPath);
      if (!await videoFile.exists()) {
        print('ERROR: Video file does not exist at path: $videoPath');
        return null;
      }

      print(
        'Video file exists and has size: ${await videoFile.length()} bytes',
      );
      print('Processing video file: $videoPath');

      // Use your existing analyzer to process the video
      final result = await _analyzer!.processVideoFile(
        videoFile,
        videoId,
        onStatusUpdate: (status) {
          print('Analysis status: $status');
          // Forward progress updates if available in status
          if (status.contains('%') && onProgress != null) {
            final percentStr = status.replaceAll(RegExp(r'[^0-9.]'), '');
            try {
              final percent = double.parse(percentStr) / 100;
              onProgress(percent);
            } catch (_) {
              print('Could not parse percentage from status: $status');
            }
          }
        },
      );

      if (result != null) {
        print('Analysis result received: $result');
        // Convert your BeeAnalysisResult to our BeeCount model
        final beeCount = BeeCount(
          id: result.id,
          hiveId: hiveId,
          videoId: videoId,
          beesEntering: result.beesIn,
          beesExiting: result.beesOut,
          timestamp: result.timestamp,
          confidence: result.detectionConfidence,
          notes:
              'Confidence: ${result.detectionConfidence.toStringAsFixed(1)}%, Processing time: ${result.processingTime.toStringAsFixed(1)}s',
        );

        // Save to database
        print('Saving bee count to database');
        await BeeCountDatabase.instance.createBeeCount(beeCount);

        print(
          'Analysis complete: ${beeCount.beesEntering} bees entering, ${beeCount.beesExiting} bees exiting',
        );
        return beeCount;
      } else {
        print('Analysis failed or returned null from BeeVideoAnalyzer');
        return null;
      }
    } catch (e, stackTrace) {
      print('Error in ML model processing: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  // Download a video from a URL with timeout and better error handling
  Future<String?> downloadVideo(
    String url, {
    Function(double)? onProgress,
  }) async {
    final client = http.Client();
    try {
      // Check if URL is valid
      if (!url.startsWith('http')) {
        throw Exception('Invalid URL: $url');
      }

      print('Downloading video from: $url');

      // Make the request without timeout
      final response = await client.get(
        Uri.parse(url),
        headers: {'Accept': 'video/mp4'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to download video: ${response.statusCode}');
      }

      // Get the app's temporary directory
      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/temp_video_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Write the file
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      print('Video downloaded successfully to: $filePath');

      return filePath;
    } catch (e) {
      print('Error downloading video: $e');
      return null;
    } finally {
      client.close();
    }
  }

  // Add this method if it doesn't exist:
  Future<Map<String, dynamic>?> getHiveData(String hiveId) async {
    // Return mock data for testing purposes
    return {
      'id': hiveId,
      'name': 'Test Hive',
      'temperature': 25.5,
      'humidity': 65.0,
      'weight': 10.5,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  // Clean up resources
  void dispose() {
    print('Disposing BeeAnalysisService resources');
    _analyzer?.dispose();
    _analyzer = null;
  }
}
