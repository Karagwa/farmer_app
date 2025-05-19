// This file is needed to bridge between your existing code and the new structure
import 'package:flutter/foundation.dart';

class BeeAnalysisResult {
  final String id;
  final String videoId;
  final int beesIn;
  final int beesOut;
  final int netChange;
  final int totalActivity;
  final double detectionConfidence;
  final double processingTime;
  final int framesAnalyzed;
  final String modelVersion;
  final DateTime timestamp;
  final String? videoPath;

  BeeAnalysisResult({
    required this.id,
    required this.videoId,
    required this.beesIn,
    required this.beesOut,
    required this.netChange,
    required this.totalActivity,
    required this.detectionConfidence,
    required this.processingTime,
    required this.framesAnalyzed,
    required this.modelVersion,
    required this.timestamp,
    this.videoPath,
  });
}
