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

  factory BeeAnalysisResult.fromJson(Map<String, dynamic> json) {
    return BeeAnalysisResult(
      id: json['id'],
      videoId: json['video_id'],
      beesIn: json['bees_in'],
      beesOut: json['bees_out'],
      netChange: json['net_change'],
      totalActivity: json['total_activity'],
      detectionConfidence: json['detection_confidence'],
      processingTime: json['processing_time'],
      framesAnalyzed: json['frames_analyzed'],
      modelVersion: json['model_version'],
      timestamp: DateTime.parse(json['timestamp']),
      videoPath: json['video_path'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'video_id': videoId,
      'bees_in': beesIn,
      'bees_out': beesOut,
      'net_change': netChange,
      'total_activity': totalActivity,
      'detection_confidence': detectionConfidence,
      'processing_time': processingTime,
      'frames_analyzed': framesAnalyzed,
      'model_version': modelVersion,
      'timestamp': timestamp.toIso8601String(),
      'video_path': videoPath,
    };
  }

  @override
  String toString() {
    return 'BeeAnalysisResult(id: $id, videoId: $videoId, beesIn: $beesIn, beesOut: $beesOut, netChange: $netChange, confidence: $detectionConfidence%)';
  }
}