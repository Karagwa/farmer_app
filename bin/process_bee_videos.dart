// bin/process_bee_videos.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:args/args.dart';
import 'package:farmer_app/utilities/video_processor.dart';

void main(List<String> args) async {
  // Initialize Flutter
  WidgetsFlutterBinding.ensureInitialized();
  
  print('Bee Video Processing Script');
  print('=========================');
  print('Date: ${DateTime.now()}');
  
  // Parse command line arguments
  final parser = ArgParser()
    ..addOption('hive-id', abbr: 'h', help: 'Hive ID to process videos for', defaultsTo: '1')
    ..addOption('date', abbr: 'd', help: 'Date to process (YYYY-MM-DD format)', defaultsTo: DateTime.now().toString().split(' ')[0])
    ..addFlag('force', abbr: 'f', help: 'Force reprocessing of videos already processed', defaultsTo: false)
    ..addFlag('verbose', abbr: 'v', help: 'Enable verbose logging', defaultsTo: false)
    ..addFlag('help', help: 'Show help', negatable: false, defaultsTo: false);
  
  try {
    final results = parser.parse(args);
    
    if (results['help'] as bool) {
      print('Usage: flutter run bin/process_bee_videos.dart [options]');
      print(parser.usage);
      exit(0);
    }
    
    final hiveId = results['hive-id'] as String;
    final dateStr = results['date'] as String;
    final force = results['force'] as bool;
    final verbose = results['verbose'] as bool;
    
    print('Configuration:');
    print('  Hive ID: $hiveId');
    print('  Date: $dateStr');
    print('  Force reprocessing: $force');
    print('  Verbose logging: $verbose');
    
    // Parse date
    DateTime date;
    try {
      date = DateTime.parse(dateStr);
    } catch (e) {
      print('Error: Invalid date format. Please use YYYY-MM-DD');
      exit(1);
    }
    
    // Process videos using the utility class
    final processResults = await VideoProcessor.processVideos(
      hiveId: hiveId,
      date: date,
      force: force,
      verbose: verbose,
      onStatusUpdate: (message) => print(message),
    );
    
    // Print summary
    print('\nProcessing summary:');
    print('  Total videos found: ${processResults['totalVideos']}');
    print('  Videos processed: ${processResults['processed']}');
    print('  Successfully processed: ${processResults['successful']}');
    print('  Failed: ${processResults['failed']}');
    print('  Skipped (already processed): ${processResults['skipped']}');
    
    if (processResults.containsKey('error')) {
      print('\nError occurred: ${processResults['error']}');
      exit(1);
    }
    
    print('\nBee video processing completed successfully.');
    exit(0);
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}