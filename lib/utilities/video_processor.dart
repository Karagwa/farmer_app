// lib/utilities/video_processor.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:HPGM/bee_counter/server_video_service.dart';
import 'package:HPGM/bee_counter/bee_count_database.dart';
import 'package:HPGM/Services/bee_analysis_service.dart';
import 'package:HPGM/bee_counter/bee_counter_model.dart';

/// Utility class for processing bee videos - NO DUMMY DATA
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
      'error': null,
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
      
      // Fetch videos from server
      log('Fetching videos from server...');
      List<ServerVideo> videos = [];
      
      try {
        videos = await serverVideoService.fetchVideosFromServer(
          hiveId,
          fetchAllIntervals: true,
        );
        log('Server returned ${videos.length} videos');
      } catch (serverError) {
        log('Server fetch failed: $serverError');
        // NO DUMMY DATA - just return empty results
        log('No videos available - server unavailable');
        return results;
      }
      
      // If no videos from server, return empty results
      if (videos.isEmpty) {
        log('No videos found on server');
        return results;
      }
      
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
        log('No videos match the selected date');
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
          results['processed'] = (results['processed'] as int) + 1;
          continue;
        }
        
        try {
          results['processed'] = (results['processed'] as int) + 1;
          
          // Process real video only - NO DUMMY HANDLING
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
      
      log('\nProcessing complete: ${results['successful']} successful, ${results['failed']} failed, ${results['skipped']} skipped');
      return results;
      
    } catch (e) {
      log('Error during video processing: $e');
      results['error'] = e.toString();
      return results;
    }
  }
}