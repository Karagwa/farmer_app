import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum ApiaryActionType { add, edit }

class ApiaryQueueItem {
  final ApiaryActionType actionType;
  final Map<String, dynamic> data;
  final int? apiaryId; // Only for edit

  ApiaryQueueItem({
    required this.actionType,
    required this.data,
    this.apiaryId,
  });

  Map<String, dynamic> toJson() => {
    'actionType': actionType.toString(),
    'data': data,
    'apiaryId': apiaryId,
  };

  static ApiaryQueueItem fromJson(Map<String, dynamic> json) {
    return ApiaryQueueItem(
      actionType: json['actionType'] == 'ApiaryActionType.add'
          ? ApiaryActionType.add
          : ApiaryActionType.edit,
      data: Map<String, dynamic>.from(json['data']),
      apiaryId: json['apiaryId'],
    );
  }
}

class ApiaryQueueService {
  static const String _queueKey = 'apiary_queue';

  static Future<List<ApiaryQueueItem>> getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getStringList(_queueKey) ?? [];
    return queueJson.map((e) => ApiaryQueueItem.fromJson(jsonDecode(e))).toList();
  }

  static Future<void> addToQueue(ApiaryQueueItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? [];
    queue.add(jsonEncode(item.toJson()));
    await prefs.setStringList(_queueKey, queue);
  }

  static Future<void> removeFromQueue(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? [];
    if (index < queue.length) {
      queue.removeAt(index);
      await prefs.setStringList(_queueKey, queue);
    }
  }

  static Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
  }
}
