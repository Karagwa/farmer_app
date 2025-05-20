// lib/utilities/video_processor.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:HPGM/bee_counter/server_video_service.dart';
import 'package:HPGM/bee_counter/bee_count_database.dart';
import 'package:HPGM/Services/bee_analysis_service.dart';
import 'package:HPGM/bee_counter/bee_counter_model.dart';

/// Utility class for processing bee videos
class VideoProcessor {
  /// Process videos for a specific date and hive
  static Future<Map<String, dynamic>> processVideos({
    required String hiveId,
    required DateTime date,
    bool force = false,
    bool verbose = false,
    Function(String)? onStatusUpdate,
  }) async {
    // Define results map with correct types
    final Map<String, dynamic> results = {
      'totalVideos': 0,
      'processed': 0,
      'successful': 0,
      'failed': 0,
      'skipped': 0,
      'error': null, // Start with null, will be a String if error occurs
    };
    
    void log(String message) {
      if (onStatusUpdate != null) {
        onStatusUpdate(message);
      }
      if (verbose) {
        print(message);
      }
    }
    
    log('Processing videos for hive: $hiveId, date: ${date.toString().split(' ')[0]}');
    
    try {
      // Create services
      final serverVideoService = ServerVideoService();
      
      // Fetch videos
      log('Fetching videos from server...');
      final videos = await serverVideoService.fetchVideosFromServer(
        hiveId,
        fetchAllIntervals: true,
      );
      
      // Filter videos by date
      final dateVideos = videos.where((video) {
        if (video.timestamp == null) return false;
        
        return video.timestamp!.year == date.year && 
              video.timestamp!.month == date.month && 
              video.timestamp!.day == date.day;
      }).toList();
      
      results['totalVideos'] = dateVideos.length;
      log('Found ${dateVideos.length} videos for date ${date.toString().split(' ')[0]}');
      
      if (dateVideos.isEmpty) {
        log('No videos to process.');
        return results;
      }
      
      // Get all bee counts from database
      final existingCounts = await BeeCountDatabase.instance.getAllBeeCounts();
      log('Found ${existingCounts.length} existing bee counts in database');
      
      // Process each video
      for (final video in dateVideos) {
        final videoId = video.id;
        log('\nProcessing video: $videoId');
        
        // Check if already processed
        final alreadyProcessed = existingCounts.any((count) => count.videoId == videoId);
        
        if (alreadyProcessed && !force) {
          log('  Video already processed, skipping');
          results['skipped'] = (results['skipped'] as int) + 1;
          continue;
        }
        
        try {
          results['processed'] = (results['processed'] as int) + 1;
          
          // Process the video
          final beeCount = await serverVideoService.processServerVideo(
            video,
            hiveId: hiveId,
            onStatusUpdate: (status) {
              log('  Status: $status');
            },
          );
          
          if (beeCount != null) {
            log('  Successfully processed video: ${beeCount.beesEntering} bees in, ${beeCount.beesExiting} bees out');
            results['successful'] = (results['successful'] as int) + 1;
          } else {
            log('  Failed to process video: No results returned');
            results['failed'] = (results['failed'] as int) + 1;
          }
        } catch (e) {
          log('  Error processing video: $e');
          results['failed'] = (results['failed'] as int) + 1;
        }
      }
      
      // Return results
      return results;
    } catch (e) {
      log('Error during video processing: $e');
      // This is the key fix - specify the type explicitly for the map to avoid confusion
      results['error'] = e.toString(); // This assigns a String to a dynamic value
      return results;
    }
  }
}