// lib/bee_counter/main_app_service_bridge.dart
import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:HPGM/bee_counter/bee_monitoring_background_service.dart';
import 'package:HPGM/analytics/foraging_advisory_service.dart';

class MainAppServiceBridge {
  static final MainAppServiceBridge _instance = MainAppServiceBridge._internal();
  factory MainAppServiceBridge() => _instance;
  MainAppServiceBridge._internal();
  
  bool _isInitialized = false;
  AutomaticBeeMonitoringService? _monitoringService;
  
  /// Initialize the bridge when the main app starts
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print(' INITIALIZING MAIN APP SERVICE BRIDGE ');
      
      // Initialize the monitoring service
      _monitoringService = AutomaticBeeMonitoringService();
      await _monitoringService!.initializeAndStart();
      
      _isInitialized = true;
      print(' Main app service bridge initialized successfully');
      
    } catch (e, stack) {
      print('ERROR initializing main app service bridge: $e');
      print('Stack trace: $stack');
    }
  }
  
  /// Call this when the main app comes to foreground
  Future<void> onAppResumed() async {
    if (!_isInitialized) {
      await initialize();
      return;
    }
    
    try {
      print('Main app resumed - ensuring service communication');
      
      // Re-establish communication if needed
      await _monitoringService?.initializeAndStart();
      
    } catch (e) {
      print('Error on app resumed: $e');
    }
  }
  
  /// Call this when the main app goes to background
  Future<void> onAppPaused() async {
    print('Main app paused - service communication may be limited');
    // Service will continue running but with limited processing capability
  }
  
  /// Check if the monitoring service is active
  Future<bool> isServiceActive() async {
    if (_monitoringService == null) return false;
    return await _monitoringService!.isServiceRunning();
  }
  
  /// Check if there are new critical or high priority recommendations
  Future<bool> hasNewRecommendations() async {
    try {
      final advisoryService = EnhancedForagingAdvisoryService();
      
      // Get analysis for today
      final data = await advisoryService.getDailyForagingAnalysis(
        '1',
        DateTime.now(),
      );
      
      if (data != null && data.recommendations.isNotEmpty) {
        // Check for critical or high priority recommendations
        final criticalRecommendations = data.recommendations
            .where((r) => r.priority == 'Critical' || r.priority == 'High')
            .length;
        
        print('Found $criticalRecommendations critical/high priority recommendations');
        return criticalRecommendations > 0;
      }
      
      return false;
    } catch (e) {
      print('Error checking recommendations: $e');
      return false;
    }
  }
  
  /// Get the current recommendations for display
  Future<List<DailyRecommendation>?> getCurrentRecommendations({String? hiveId}) async {
    try {
      final advisoryService = EnhancedForagingAdvisoryService();
      
      final data = await advisoryService.getDailyForagingAnalysis(
        hiveId ?? '1',
        DateTime.now(),
      );
      
      return data?.recommendations;
    } catch (e) {
      print('Error getting current recommendations: $e');
      return null;
    }
  }
  
  /// Get full foraging analysis for a specific date and hive
  Future<DailyForagingAnalysis?> getForagingAnalysis({
    required String hiveId,
    DateTime? date,
  }) async {
    try {
      final advisoryService = EnhancedForagingAdvisoryService();
      
      return await advisoryService.getDailyForagingAnalysis(
        hiveId,
        date ?? DateTime.now(),
      );
    } catch (e) {
      print('Error getting foraging analysis: $e');
      return null;
    }
  }
  
  /// Manually trigger a video check (useful for testing)
  Future<void> triggerManualCheck() async {
    if (!_isInitialized) {
      print('Bridge not initialized');
      return;
    }
    
    try {
      print('Triggering manual video check...');
      
      
      // we can trigger a service restart which will process any pending videos
      if (_monitoringService != null) {
        await _monitoringService!.initializeAndStart();
        print('Service restarted - pending videos will be processed automatically');
      }
      
    } catch (e) {
      print('Error triggering manual check: $e');
    }
  }
  
  /// Check if there are any critical alerts that need immediate attention
  Future<bool> hasCriticalAlerts() async {
    try {
      final recommendations = await getCurrentRecommendations();
      
      if (recommendations != null) {
        return recommendations.any((r) => r.priority == 'Critical');
      }
      
      return false;
    } catch (e) {
      print('Error checking critical alerts: $e');
      return false;
    }
  }
  
  /// Get a summary of today's hive activity
  Future<Map<String, dynamic>?> getTodaysSummary({String? hiveId}) async {
    try {
      final data = await getForagingAnalysis(hiveId: hiveId ?? '1');
      
      if (data != null) {
        final totalActivity = data.beeCountData.fold(0, (sum, hour) => sum + hour.totalActivity);
        final totalEntering = data.beeCountData.fold(0, (sum, hour) => sum + hour.beesEntering);
        final totalExiting = data.beeCountData.fold(0, (sum, hour) => sum + hour.beesExiting);
        final criticalRecommendations = data.recommendations.where((r) => r.priority == 'Critical').length;
        final highRecommendations = data.recommendations.where((r) => r.priority == 'High').length;
        
        return {
          'date': data.date.toIso8601String(),
          'totalActivity': totalActivity,
          'totalEntering': totalEntering,
          'totalExiting': totalExiting,
          'netChange': totalEntering - totalExiting,
          'peakActivityHour': data.foragingPatterns.peakActivityHour,
          'weightChange': data.weightAnalysis.dailyChange,
          'criticalRecommendations': criticalRecommendations,
          'highRecommendations': highRecommendations,
          'totalRecommendations': data.recommendations.length,
          'foragingAssessment': data.foragingPatterns.overallForagingAssessment,
          'nectarFlowStatus': data.foragingPatterns.nectarFlowAnalysis.status,
          'lastUpdated': data.lastUpdated.toIso8601String(),
        };
      }
      
      return null;
    } catch (e) {
      print('Error getting today\'s summary: $e');
      return null;
    }
  }
  
  /// Stream of recommendation updates (for real-time notifications)
  Stream<List<DailyRecommendation>> get recommendationStream {
    return Stream.periodic(Duration(minutes: 15), (_) async {
      return await getCurrentRecommendations();
    }).asyncMap((future) => future).where((recommendations) => recommendations != null).cast<List<DailyRecommendation>>();
  }
  
  void dispose() {
    print('Disposing main app service bridge');
    _isInitialized = false;
    _monitoringService = null;
  }
}