// lib/bee_counter/process_videos_widget.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:farmer_app/bee_counter/bee_counter_model.dart';
import 'package:farmer_app/bee_counter/bee_count_database.dart';
import 'package:farmer_app/bee_counter/server_video_service.dart';
import 'package:farmer_app/Services/bee_analysis_service.dart';

class ProcessVideosWidget extends StatefulWidget {
  final String hiveId;
  final DateTime date;
  final bool force;
  final VoidCallback? onProcessingComplete;
  
  const ProcessVideosWidget({
    Key? key,
    required this.hiveId,
    required this.date,
    this.force = false,
    this.onProcessingComplete,
  }) : super(key: key);
  
  @override
  _ProcessVideosWidgetState createState() => _ProcessVideosWidgetState();
}

class _ProcessVideosWidgetState extends State<ProcessVideosWidget> {
  bool _isProcessing = false;
  String _status = 'Ready to process videos';
  List<String> _logMessages = [];
  int _totalVideos = 0;
  int _processedVideos = 0;
  int _successCount = 0;
  int _failureCount = 0;
  int _skippedCount = 0;
  
  // Services
  final ServerVideoService _serverVideoService = ServerVideoService();
  final BeeAnalysisService _beeAnalysisService = BeeAnalysisService();
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Video Processing',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            
            // Status info
            Text('Date: ${DateFormat('yyyy-MM-dd').format(widget.date)}'),
            Text('Hive ID: ${widget.hiveId}'),
            Text('Force reprocessing: ${widget.force ? 'Yes' : 'No'}'),
            const SizedBox(height: 16),
            
            // Progress indicators
            if (_isProcessing) ...[
              LinearProgressIndicator(
                value: _totalVideos > 0 ? _processedVideos / _totalVideos : null,
              ),
              const SizedBox(height: 8),
              Text('Status: $_status'),
              Text('Processed: $_processedVideos / $_totalVideos'),
              if (_processedVideos > 0)
                Text('Results: $_successCount successful, $_failureCount failed, $_skippedCount skipped'),
            ],
            
            // Action buttons
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: _isProcessing ? null : _processVideos,
                  child: Text(_isProcessing ? 'Processing...' : 'Start Processing'),
                ),
              ],
            ),
            
            // Log viewer
            if (_logMessages.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Processing Log',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.all(8),
                child: ListView.builder(
                  itemCount: _logMessages.length,
                  itemBuilder: (context, index) {
                    final message = _logMessages[index];
                    return Text(
                      message,
                      style: TextStyle(
                        color: message.startsWith('ERROR') ? Colors.red : Colors.white,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Future<void> _processVideos() async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
      _status = 'Starting video processing...';
      _logMessages = [];
      _totalVideos = 0;
      _processedVideos = 0;
      _successCount = 0;
      _failureCount = 0;
      _skippedCount = 0;
    });
    
    try {
      // Start processing
      _addLog('Starting video processing for date: ${DateFormat('yyyy-MM-dd').format(widget.date)}');
      
      // Fetch videos
      setState(() {
        _status = 'Fetching videos from server...';
      });
      
      final videos = await _serverVideoService.fetchVideosFromServer(
        widget.hiveId, 
        fetchAllIntervals: true,
      );
      
      _addLog('Found ${videos.length} total videos on server');
      
      // Filter by date
      final dateVideos = videos.where((video) {
        if (video.timestamp == null) return false;
        
        return video.timestamp!.year == widget.date.year && 
               video.timestamp!.month == widget.date.month && 
               video.timestamp!.day == widget.date.day;
      }).toList();
      
      setState(() {
        _totalVideos = dateVideos.length;
        _status = 'Found $_totalVideos videos for selected date';
      });
      
      _addLog('Found $_totalVideos videos for date ${DateFormat('yyyy-MM-dd').format(widget.date)}');
      
      if (_totalVideos == 0) {
        setState(() {
          _isProcessing = false;
          _status = 'No videos found for the selected date';
        });
        return;
      }
      
      // Get all bee counts from database to check if videos already processed
      final existingCounts = await BeeCountDatabase.instance.getAllBeeCounts();
      _addLog('Found ${existingCounts.length} existing bee counts in database');
      
      // Process videos one by one
      for (int i = 0; i < dateVideos.length; i++) {
        final video = dateVideos[i];
        final videoId = video.id;
        
        setState(() {
          _status = 'Processing video ${i+1} of $_totalVideos: $videoId';
        });
        
        _addLog('\nProcessing video ${i+1}/$_totalVideos: $videoId');
        
        // Check if already processed
        final alreadyProcessed = existingCounts.any((count) => count.videoId == videoId);
        
        if (alreadyProcessed && !widget.force) {
          _addLog('Video already processed, skipping (enable Force mode to reprocess)');
          setState(() {
            _processedVideos++;
            _skippedCount++;
          });
          continue;
        }
        
        try {
          // Download the video
          _addLog('Downloading video from ${video.url}');
          final videoPath = await _beeAnalysisService.downloadVideo(
            video.url,
            onProgress: (progress) {
              setState(() {
                _status = 'Downloading video ${i+1}/$_totalVideos: ${(progress * 100).toStringAsFixed(1)}%';
              });
            },
          );
          
          if (videoPath == null) {
            throw Exception('Failed to download video');
          }
          
          _addLog('Video downloaded to: $videoPath');
          
          // Extract hive ID from video name if needed
          final extractedHiveId = video.id.split('_').first;
          final finalHiveId = widget.hiveId.isNotEmpty ? widget.hiveId : extractedHiveId;
          
          // Analyze the video
          setState(() {
            _status = 'Analyzing video ${i+1}/$_totalVideos with ML model...';
          });
          
          _addLog('Analyzing video with ML model');
          final result = await _beeAnalysisService.analyzeVideo(
            finalHiveId,
            videoId,
            videoPath,
          );
          
          if (result == null) {
            throw Exception('Video analysis returned null result');
          }
          
          // Create bee count with video timestamp
          final BeeCount finalResult = BeeCount(
            id: result.id,
            hiveId: result.hiveId,
            beesEntering: result.beesEntering,
            beesExiting: result.beesExiting,
            timestamp: video.timestamp ?? result.timestamp,
            videoId: videoId,
          );
          
          // Delete existing record if force mode
          if (widget.force && alreadyProcessed) {
            await BeeCountDatabase.instance.deleteBeeCountByVideoId(videoId);
            _addLog('Deleted existing record for video $videoId');
          }
          
          // Save to database
          final String countId = await BeeCountDatabase.instance.createBeeCount(finalResult);
          final BeeCount? savedCount = await BeeCountDatabase.instance.getBeeCount(countId);
          if (savedCount != null) {
            _addLog('Saved bee count to database: ${savedCount.beesEntering} bees in, ${savedCount.beesExiting} bees out');
          } else {
            _addLog('Saved bee count to database, but could not retrieve it');
          }
          // Clean up video file
          try {
            await File(videoPath).delete();
            _addLog('Cleaned up temporary video file');
          } catch (e) {
            _addLog('Warning: Failed to delete temporary video file: $e');
          }
          
          setState(() {
            _processedVideos++;
            _successCount++;
          });
          
        } catch (e) {
          _addLog('ERROR: $e');
          setState(() {
            _processedVideos++;
            _failureCount++;
          });
        }
      }
      
      setState(() {
        _isProcessing = false;
        _status = 'Processing complete: $_successCount successful, $_failureCount failed, $_skippedCount skipped';
      });
      
      _addLog('\nProcessing complete: $_successCount successful, $_failureCount failed, $_skippedCount skipped');
      
      // Notify parent that processing is complete
      if (widget.onProcessingComplete != null) {
        widget.onProcessingComplete!();
      }
      
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _status = 'Error: $e';
      });
      _addLog('ERROR: $e');
    }
  }
  
  void _addLog(String message) {
    setState(() {
      _logMessages.add(message);
    });
  }
}
