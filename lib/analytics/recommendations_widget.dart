import 'package:flutter/material.dart';
import 'package:HPGM/analytics/foraging_advisory_service.dart';
import 'package:HPGM/analytics/navigation_helper.dart';

class RecommendationsWidget extends StatefulWidget {
  final String? hiveId;
  final bool showCriticalOnly;
  final bool autoRefresh;

  const RecommendationsWidget({
    Key? key,
    this.hiveId,
    this.showCriticalOnly = false,
    this.autoRefresh = true,
  }) : super(key: key);

  @override
  _RecommendationsWidgetState createState() => _RecommendationsWidgetState();
}

class _RecommendationsWidgetState extends State<RecommendationsWidget> {
  List<DailyRecommendation>? _recommendations;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
    
    // Auto-refresh every 30 minutes if enabled
    if (widget.autoRefresh) {
      Stream.periodic(Duration(minutes: 30), (_) => null)
          .listen((_) => _loadRecommendations());
    }
  }

  Future<void> _loadRecommendations() async {
    if (!mounted) return;
    
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final advisoryService = EnhancedForagingAdvisoryService();
      final analysisData = await advisoryService.getDailyForagingAnalysis(
        widget.hiveId ?? '1',
        DateTime.now(),
      );

      if (mounted) {
        setState(() {
          if (analysisData != null) {
            _recommendations = widget.showCriticalOnly
                ? analysisData.recommendations
                    .where((r) => r.priority == 'Critical' || r.priority == 'High')
                    .toList()
                : analysisData.recommendations;
          } else {
            _error = 'No data available';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (_isLoading)
            _buildLoadingState()
          else if (_error != null)
            _buildErrorState()
          else if (_recommendations == null || _recommendations!.isEmpty)
            _buildEmptyState()
          else
            _buildRecommendationsList(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final criticalCount = _recommendations?.where((r) => r.priority == 'Critical').length ?? 0;
    final highCount = _recommendations?.where((r) => r.priority == 'High').length ?? 0;
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: criticalCount > 0 ? Colors.red.shade50 : 
               highCount > 0 ? Colors.orange.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          Icon(
            criticalCount > 0 ? Icons.error : 
            highCount > 0 ? Icons.warning : Icons.check_circle,
            color: criticalCount > 0 ? Colors.red.shade600 : 
                   highCount > 0 ? Colors.orange.shade600 : Colors.green.shade600,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.showCriticalOnly ? 'Critical Alerts' : 'Daily Recommendations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: criticalCount > 0 ? Colors.red.shade700 : 
                           highCount > 0 ? Colors.orange.shade700 : Colors.green.shade700,
                  ),
                ),
                if (_recommendations != null)
                  Text(
                    '${_recommendations!.length} item${_recommendations!.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          if (!_isLoading) ...[
            IconButton(
              icon: Icon(Icons.refresh, size: 20),
              onPressed: _loadRecommendations,
              tooltip: 'Refresh',
            ),
            IconButton(
              icon: Icon(Icons.open_in_new, size: 20),
              onPressed: () => NavigationHelper.navigateToRecommendations(
                context,
                hiveId: widget.hiveId,
              ),
              tooltip: 'View all',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading recommendations...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red),
          SizedBox(height: 8),
          Text(
            'Failed to load recommendations',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            _error!,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadRecommendations,
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: Colors.green.shade600,
            ),
            SizedBox(height: 12),
            Text(
              widget.showCriticalOnly ? 'No Critical Alerts' : 'No Recommendations',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              widget.showCriticalOnly 
                  ? 'Your hive is operating normally'
                  : 'Your hive is performing well!',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsList() {
    // Show max 3 recommendations in compact view
    final displayRecommendations = _recommendations!.take(3).toList();
    
    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          itemCount: displayRecommendations.length,
          separatorBuilder: (context, index) => SizedBox(height: 12),
          itemBuilder: (context, index) {
            final recommendation = displayRecommendations[index];
            return _buildRecommendationItem(recommendation);
          },
        ),
        if (_recommendations!.length > 3)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_recommendations!.length - 3} more recommendation${_recommendations!.length - 3 != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                TextButton(
                  onPressed: () => NavigationHelper.navigateToRecommendations(
                    context,
                    hiveId: widget.hiveId,
                  ),
                  child: Text('View All'),
                ),
              ],
            ),
          ),
        if (_recommendations!.length <= 3)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => NavigationHelper.navigateToRecommendations(
                    context,
                    hiveId: widget.hiveId,
                  ),
                  child: Text('View Details'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRecommendationItem(DailyRecommendation recommendation) {
    final priorityColor = _getPriorityColor(recommendation.priority);
    final priorityIcon = _getPriorityIcon(recommendation.priority);
    
    return GestureDetector(
      onTap: () => NavigationHelper.navigateToRecommendations(
        context,
        hiveId: widget.hiveId,
      ),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: priorityColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: priorityColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(priorityIcon, color: priorityColor, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recommendation.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: priorityColor,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    recommendation.priority.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Text(
              recommendation.description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (recommendation.timeRelevance.toLowerCase().contains('immediate') ||
                recommendation.timeRelevance.toLowerCase().contains('today')) ...[
              SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.schedule, size: 12, color: priorityColor),
                  SizedBox(width: 4),
                  Text(
                    recommendation.timeRelevance,
                    style: TextStyle(
                      fontSize: 10,
                      color: priorityColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return Colors.red.shade600;
      case 'high':
        return Colors.orange.shade600;
      case 'medium':
        return Colors.blue.shade600;
      case 'low':
        return Colors.grey.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _getPriorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return Icons.error;
      case 'high':
        return Icons.warning;
      case 'medium':
        return Icons.info;
      case 'low':
        return Icons.info_outline;
      default:
        return Icons.info_outline;
    }
  }
}