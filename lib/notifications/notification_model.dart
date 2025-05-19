import 'package:flutter/material.dart';

enum NotificationSeverity {
  low,
  medium,
  high,
}

enum NotificationType {
  temperature,
  humidity,
  weight,
  weather,
  carbonDioxide,
  connection,
  colonization,
}

class HiveNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  final NotificationSeverity severity;
  final bool isRead;
  final int hiveId;
  final Map<String, dynamic>? data;

  HiveNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    required this.severity,
    required this.hiveId,
    this.isRead = false,
    this.data,
  });

  HiveNotification copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? timestamp,
    NotificationType? type,
    NotificationSeverity? severity,
    bool? isRead,
    int? hiveId,
    Map<String, dynamic>? data,
  }) {
    return HiveNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      isRead: isRead ?? this.isRead,
      hiveId: hiveId ?? this.hiveId,
      data: data ?? this.data,
    );
  }

  // Helper method to get icon based on notification type
  IconData get icon {
    switch (type) {
      case NotificationType.temperature:
        return Icons.thermostat;
      case NotificationType.humidity:
        return Icons.water_drop;
      case NotificationType.weight:
        return Icons.scale;
      case NotificationType.weather:
        return Icons.cloud;
      case NotificationType.carbonDioxide:
        return Icons.co2;
      case NotificationType.connection:
        return Icons.wifi;
      case NotificationType.colonization:
        return Icons.home;
    }
  }

  // Helper method to get color based on severity
  Color get color {
    switch (severity) {
      case NotificationSeverity.low:
        return Colors.blue;
      case NotificationSeverity.medium:
        return Colors.orange;
      case NotificationSeverity.high:
        return Colors.red;
    }
  }

  // Helper method to get a human-readable time
  String get timeAgo {
    final difference = DateTime.now().difference(timestamp);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}