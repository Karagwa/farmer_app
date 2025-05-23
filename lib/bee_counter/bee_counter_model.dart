// lib/bee_counter/bee_counter_model.dart
class ServerVideo {
  final String id;
  final String url;
  final DateTime? timestamp;
  final int size;
  final String mimeType;

  ServerVideo({
    required this.id,
    required this.url,
    this.timestamp,
    this.size = 0,
    this.mimeType = 'video/mp4',
  });

  factory ServerVideo.fromJson(Map<String, dynamic> json) {
    print('Parsing video JSON: $json');

    final id = json['name'] ?? '';
    final url = json['url'] ?? '';

    DateTime? timestamp;

    // First try to extract from filename (1_2025-05-23_073137.mp4)
    if (id.isNotEmpty) {
      try {
        final parts = id.split('_');
        if (parts.length >= 3) {
          final datePart = parts[1]; // "2025-05-23"
          final timePart = parts[2].split('.')[0]; // "073137"

          final year = int.parse(datePart.substring(0, 4));
          final month = int.parse(datePart.substring(5, 7));
          final day = int.parse(datePart.substring(8, 10));

          final hour = int.parse(timePart.substring(0, 2));
          final minute = int.parse(timePart.substring(2, 4));
          final second = int.parse(timePart.substring(4, 6));

          timestamp = DateTime(year, month, day, hour, minute, second);
          print('Extracted timestamp from filename: $timestamp');
        }
      } catch (e) {
        print('Error extracting timestamp from name: $e');
      }
    }

    // If no timestamp from filename, try date field
    if (timestamp == null && json['date'] != null) {
      try {
        // If there's a date field but no time info
        final datePart = json['date'].toString();
        timestamp = DateTime.parse('$datePart 00:00:00');
        print('Using date field timestamp: $timestamp');
      } catch (e) {
        print('Error parsing date field: $e');
      }
    }

    // If still no timestamp, try last_modified
    if (timestamp == null && json['last_modified'] != null) {
      try {
        timestamp = DateTime.fromMillisecondsSinceEpoch(
          (json['last_modified'] as num).toInt() * 1000,
        );
        print('Using last_modified timestamp: $timestamp');
      } catch (e) {
        print('Error parsing last_modified timestamp: $e');
      }
    }

    // If still no timestamp, use current time
    if (timestamp == null) {
      timestamp = DateTime.now();
      print('No timestamp found, using current time: $timestamp');
    }

    return ServerVideo(
      id: id,
      url: url,
      timestamp: timestamp,
      size: json['size'] ?? 0,
      mimeType: json['mime_type'] ?? 'video/mp4',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'timestamp': timestamp?.toIso8601String(),
      'size': size,
      'mime_type': mimeType,
    };
  }

  // Helper method to check if video matches a time interval
  bool matchesTimeInterval(int targetHour) {
    if (timestamp == null) return false;

    final videoHour = timestamp!.hour;
    // Allow 2 hour window around target time
    return (videoHour >= targetHour - 2) && (videoHour <= targetHour + 2);
  }
}

class BeeCount {
  final String? id;
  final String hiveId;
  final String? videoId;
  final int beesEntering;
  final int beesExiting;
  final DateTime timestamp;
  final String? notes;
  final double confidence;

  BeeCount({
    this.id,
    required this.hiveId,
    this.videoId,
    required this.beesEntering,
    required this.beesExiting,
    required this.timestamp,
    this.notes,
    this.confidence = 0.0,
  });

  int get netChange => beesEntering - beesExiting;
  int get totalActivity => beesEntering + beesExiting;

  factory BeeCount.fromJson(Map<String, dynamic> json) {
    return BeeCount(
      id: json['id'],
      hiveId: json['hive_id'],
      videoId: json['video_id'],
      beesEntering: json['bees_entering'],
      beesExiting: json['bees_exiting'],
      timestamp: DateTime.parse(json['timestamp']),
      notes: json['notes'],
      confidence: (json['confidence'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hive_id': hiveId,
      'video_id': videoId,
      'bees_entering': beesEntering,
      'bees_exiting': beesExiting,
      'timestamp': timestamp.toIso8601String(),
      'notes': notes,
      'confidence': confidence,
    };
  }

  BeeCount copyWith({
    String? id,
    String? hiveId,
    String? videoId,
    int? beesEntering,
    int? beesExiting,
    DateTime? timestamp,
    String? notes,
    double? confidence,
  }) {
    return BeeCount(
      id: id ?? this.id,
      hiveId: hiveId ?? this.hiveId,
      videoId: videoId ?? this.videoId,
      beesEntering: beesEntering ?? this.beesEntering,
      beesExiting: beesExiting ?? this.beesExiting,
      timestamp: timestamp ?? this.timestamp,
      notes: notes ?? this.notes,
      confidence: confidence ?? this.confidence,
    );
  }
}

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
