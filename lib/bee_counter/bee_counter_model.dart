// import 'package:flutter/foundation.dart';

// Update the ServerVideo class to match the API response format
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
    // Print the JSON to debug
    print('Parsing video JSON: $json');

    // Extract the name as ID
    final id = json['name'] ?? '';

    // Extract the URL directly
    final url = json['url'] ?? '';

    // Parse timestamp from last_modified
    DateTime? timestamp;
    if (json['last_modified'] != null) {
      try {
        // Convert Unix timestamp to DateTime
        timestamp = DateTime.fromMillisecondsSinceEpoch(
          json['last_modified'] * 1000,
        );
      } catch (e) {
        print('Error parsing last_modified timestamp: $e');
      }
    }

    // If no timestamp from last_modified, try to extract from name
    if (timestamp == null && id.isNotEmpty) {
      try {
        // Assuming name format is like "1_2000-01-01_030020.mp4"
        final parts = id.split('_');
        if (parts.length >= 3) {
          final datePart = parts[1]; // "2000-01-01"
          final timePart = parts[2].split('.')[0]; // "030020"

          final year = int.parse(datePart.substring(0, 4));
          final month = int.parse(datePart.substring(5, 7));
          final day = int.parse(datePart.substring(8, 10));

          final hour = int.parse(timePart.substring(0, 2));
          final minute = int.parse(timePart.substring(2, 4));
          final second = int.parse(timePart.substring(4, 6));

          timestamp = DateTime(year, month, day, hour, minute, second);
        }
      } catch (e) {
        print('Error extracting timestamp from name: $e');
      }
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
  }) {
    return BeeCount(
      id: id ?? this.id,
      hiveId: hiveId ?? this.hiveId,
      videoId: videoId ?? this.videoId,
      beesEntering: beesEntering ?? this.beesEntering,
      beesExiting: beesExiting ?? this.beesExiting,
      timestamp: timestamp ?? this.timestamp,
      notes: notes ?? this.notes,
    );
  }
}
