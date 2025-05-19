import 'package:flutter/foundation.dart';

class VideoFile {
  final String id;
  final String filePath;
  final int size;
  final Uint8List? thumbnail;
  final DateTime timestamp;
  final String analysisStatus;

  VideoFile({
    required this.id,
    required this.filePath,
    required this.size,
    this.thumbnail,
    required this.timestamp,
    required this.analysisStatus,
  });
}
