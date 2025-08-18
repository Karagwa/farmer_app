import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:HPGM/services/token_storage.dart';
import 'package:HPGM/farm_model.dart';
import 'package:HPGM/hive_model.dart';

/// Centralized API service for all HTTP requests
class ApiService {
  static const String baseUrl = 'http://196.43.168.57/api/v1';
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Get headers with authorization token
  Future<Map<String, String>> _getHeaders() async {
    final token = await TokenStorage.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Generic GET request
  Future<Map<String, dynamic>> _get(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Generic POST request
  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // =============================================================================
  // FARM/APIARY ENDPOINTS
  // =============================================================================

  /// Fetch all farms/apiaries
  Future<List<Farm>> fetchFarms() async {
    final result = await _get('/farms');
    if (result['success']) {
      final List<dynamic> data = result['data'];
      return data.map((farm) => Farm.fromJson(farm)).toList();
    } else {
      throw Exception('Failed to fetch farms: ${result['error']}');
    }
  }

  /// Fetch specific farm by ID
  Future<Farm?> fetchFarm(int farmId) async {
    final result = await _get('/farms/$farmId');
    if (result['success']) {
      return Farm.fromJson(result['data']);
    } else {
      print('Failed to fetch farm $farmId: ${result['error']}');
      return null;
    }
  }

  // =============================================================================
  // HIVE ENDPOINTS
  // =============================================================================

  /// Fetch all hives for a specific farm
  Future<List<Hive>> fetchHives(int farmId) async {
    final result = await _get('/farms/$farmId/hives');
    if (result['success']) {
      final List<dynamic> data = result['data'];
      return data.map((hive) => Hive.fromJson(hive)).toList();
    } else {
      throw Exception('Failed to fetch hives: ${result['error']}');
    }
  }

  /// Fetch specific hive by ID
  Future<Hive?> fetchHive(int hiveId) async {
    final result = await _get('/hives/$hiveId');
    if (result['success']) {
      return Hive.fromJson(result['data']);
    } else {
      print('Failed to fetch hive $hiveId: ${result['error']}');
      return null;
    }
  }

  // =============================================================================
  // ENVIRONMENTAL DATA ENDPOINTS
  // =============================================================================

  /// Fetch temperature data for a hive within date range
  Future<List<Map<String, dynamic>>> fetchTemperatureData(
    int hiveId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    String endpoint = '/hives/$hiveId/temperature';

    if (startDate != null && endDate != null) {
      final startStr = startDate.toIso8601String().split('T')[0];
      final endStr = endDate.toIso8601String().split('T')[0];
      endpoint += '?start_date=$startStr&end_date=$endStr';
    }

    final result = await _get(endpoint);
    if (result['success']) {
      return List<Map<String, dynamic>>.from(result['data']);
    } else {
      throw Exception('Failed to fetch temperature data: ${result['error']}');
    }
  }

  /// Fetch humidity data for a hive within date range
  Future<List<Map<String, dynamic>>> fetchHumidityData(
    int hiveId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    String endpoint = '/hives/$hiveId/humidity';

    if (startDate != null && endDate != null) {
      final startStr = startDate.toIso8601String().split('T')[0];
      final endStr = endDate.toIso8601String().split('T')[0];
      endpoint += '?start_date=$startStr&end_date=$endStr';
    }

    final result = await _get(endpoint);
    if (result['success']) {
      return List<Map<String, dynamic>>.from(result['data']);
    } else {
      throw Exception('Failed to fetch humidity data: ${result['error']}');
    }
  }

  /// Fetch weight data for a hive within date range
  Future<List<Map<String, dynamic>>> fetchWeightData(
    int hiveId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    String endpoint = '/hives/$hiveId/weight';

    if (startDate != null && endDate != null) {
      final startStr = startDate.toIso8601String().split('T')[0];
      final endStr = endDate.toIso8601String().split('T')[0];
      endpoint += '?start_date=$startStr&end_date=$endStr';
    }

    final result = await _get(endpoint);
    if (result['success']) {
      return List<Map<String, dynamic>>.from(result['data']);
    } else {
      throw Exception('Failed to fetch weight data: ${result['error']}');
    }
  }

  // =============================================================================
  // DASHBOARD/ANALYTICS ENDPOINTS
  // =============================================================================

  /// Fetch dashboard data (counts, productive farms, etc.)
  Future<Map<String, dynamic>> fetchDashboardData() async {
    final result = await _get('/dashboard');
    if (result['success']) {
      return result['data'];
    } else {
      throw Exception('Failed to fetch dashboard data: ${result['error']}');
    }
  }

  /// Fetch home page statistics
  Future<Map<String, dynamic>> fetchHomeStatistics() async {
    final countResult = await _get('/dashboard/counts');
    final productiveResult = await _get('/dashboard/productive');
    final seasonResult = await _get('/dashboard/season');
    final supplementResult = await _get('/dashboard/supplement');

    if (countResult['success'] &&
        productiveResult['success'] &&
        seasonResult['success'] &&
        supplementResult['success']) {
      return {
        'counts': countResult['data'],
        'productive': productiveResult['data'],
        'season': seasonResult['data'],
        'supplement': supplementResult['data'],
      };
    } else {
      throw Exception('Failed to fetch home statistics');
    }
  }

  // =============================================================================
  // MEDIA ENDPOINTS
  // =============================================================================

  /// Fetch images for a hive within date range
  Future<List<String>> fetchHiveImages(
    int hiveId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    String endpoint = '/hives/$hiveId/images';

    if (startDate != null && endDate != null) {
      final startStr = startDate.toIso8601String().split('T')[0];
      final endStr = endDate.toIso8601String().split('T')[0];
      endpoint += '/$startStr/$endStr';
    }

    final result = await _get(endpoint);
    if (result['success']) {
      final List<dynamic> imagePaths = result['data']['data'];
      return imagePaths.map<String>((item) => item.toString()).toList();
    } else {
      throw Exception('Failed to fetch hive images: ${result['error']}');
    }
  }

  // =============================================================================
  // INSPECTION/RECORDS ENDPOINTS
  // =============================================================================

  /// Submit inspection record
  Future<bool> submitInspectionRecord(Map<String, dynamic> recordData) async {
    final result = await _post('/inspections', recordData);
    return result['success'];
  }

  /// Fetch inspection records for a hive
  Future<List<Map<String, dynamic>>> fetchInspectionRecords(
    int hiveId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    String endpoint = '/hives/$hiveId/inspections';

    if (startDate != null && endDate != null) {
      final startStr = startDate.toIso8601String().split('T')[0];
      final endStr = endDate.toIso8601String().split('T')[0];
      endpoint += '?start_date=$startStr&end_date=$endStr';
    }

    final result = await _get(endpoint);
    if (result['success']) {
      return List<Map<String, dynamic>>.from(result['data']);
    } else {
      throw Exception('Failed to fetch inspection records: ${result['error']}');
    }
  }

  // =============================================================================
  // UTILITY METHODS
  // =============================================================================

  /// Check if the API is reachable
  Future<bool> isApiReachable() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/health'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get current API server status
  Future<Map<String, dynamic>> getServerStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/status'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'status': 'error', 'message': 'Server unavailable'};
      }
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }
}
