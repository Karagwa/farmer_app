import 'package:flutter/material.dart';
import 'package:HPGM/analytics/foraging_advisory_service.dart';
import 'package:HPGM/analytics/recommendations_screen.dart';
import 'package:HPGM/analytics/foraging_advisory_screen.dart';

class NavigationHelper {
  /// Navigate to recommendations screen with proper data
  static Future<void> navigateToRecommendations(
    BuildContext context, {
    String? hiveId,
    DateTime? date,
  }) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading recommendations...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Get foraging analysis
      final advisoryService = EnhancedForagingAdvisoryService();
      final analysisData = await advisoryService.getDailyForagingAnalysis(
        hiveId ?? '1',
        date ?? DateTime.now(),
      );

      // Close loading dialog
      Navigator.of(context).pop();

      if (analysisData != null) {
        // Navigate to recommendations screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => RecommendationsScreen(
              analysisData: analysisData,
            ),
          ),
        );
      } else {
        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('No Data Available'),
            content: Text('Unable to load recommendations. Please try again later.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Error'),
          content: Text('Failed to load recommendations: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  /// Navigate to enhanced foraging dashboard
  static Future<void> navigateToForagingDashboard(
    BuildContext context, {
    required String hiveId,
  }) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EnhancedForagingDashboard(
          hiveId: hiveId,
        ),
      ),
    );
  }

  /// Show quick recommendations dialog
  static Future<void> showQuickRecommendations(
    BuildContext context, {
    String? hiveId,
  }) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get recommendations
      final advisoryService = EnhancedForagingAdvisoryService();
      final analysisData = await advisoryService.getDailyForagingAnalysis(
        hiveId ?? '1',
        DateTime.now(),
      );

      // Close loading
      Navigator.of(context).pop();

      if (analysisData != null && analysisData.recommendations.isNotEmpty) {
        // Show quick view dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Today\'s Recommendations'),
            content: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(maxHeight: 400),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: analysisData.recommendations.length,
                itemBuilder: (context, index) {
                  final rec = analysisData.recommendations[index];
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        rec.priority == 'Critical' ? Icons.error :
                        rec.priority == 'High' ? Icons.warning :
                        Icons.info,
                        color: rec.priority == 'Critical' ? Colors.red :
                               rec.priority == 'High' ? Colors.orange :
                               Colors.blue,
                      ),
                      title: Text(
                        rec.title,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        rec.description,
                        style: TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      dense: true,
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  navigateToRecommendations(context, hiveId: hiveId);
                },
                child: Text('View All'),
              ),
            ],
          ),
        );
      } else {
        // No recommendations available
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('No Recommendations'),
            content: Text('No recommendations available for today. Your hive appears to be performing well!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close loading if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading recommendations: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Check and show notification if critical recommendations exist
  static Future<bool> checkAndShowCriticalAlerts(
    BuildContext context, {
    String? hiveId,
  }) async {
    try {
      final advisoryService = EnhancedForagingAdvisoryService();
      final analysisData = await advisoryService.getDailyForagingAnalysis(
        hiveId ?? '1',
        DateTime.now(),
      );

      if (analysisData != null) {
        final criticalRecs = analysisData.recommendations
            .where((r) => r.priority == 'Critical')
            .toList();

        if (criticalRecs.isNotEmpty) {
          // Show critical alert dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.error, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Critical Alert'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your hive has ${criticalRecs.length} critical recommendation${criticalRecs.length > 1 ? 's' : ''} that need immediate attention:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  ...criticalRecs.take(3).map((rec) => Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('• ${rec.title}', style: TextStyle(fontSize: 14)),
                  )).toList(),
                  if (criticalRecs.length > 3)
                    Text('...and ${criticalRecs.length - 3} more'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Later'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    navigateToRecommendations(context, hiveId: hiveId);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Text('View Now', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error checking critical alerts: $e');
      return false;
    }
  }
}