import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:HPGM/analytics/foraging_advisory_service.dart';

class RecommendationsScreen extends StatefulWidget {
  final DailyForagingAnalysis analysisData;

  const RecommendationsScreen({Key? key, required this.analysisData}) : super(key: key);

  @override
  _RecommendationsScreenState createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen>
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;
  String _selectedPriorityFilter = 'All';
  String _selectedCategoryFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<DailyRecommendation> get _filteredRecommendations {
    var recommendations = widget.analysisData.recommendations;
    
    // Filter by priority
    if (_selectedPriorityFilter != 'All') {
      recommendations = recommendations.where((r) => 
        r.priority.toLowerCase() == _selectedPriorityFilter.toLowerCase()).toList();
    }
    
    // Filter by category (simple text-based filtering)
    if (_selectedCategoryFilter != 'All') {
      recommendations = recommendations.where((r) => 
        r.title.toLowerCase().contains(_selectedCategoryFilter.toLowerCase()) ||
        r.description.toLowerCase().contains(_selectedCategoryFilter.toLowerCase())).toList();
    }
    
    // Sort by priority
    recommendations.sort((a, b) {
      const priorityOrder = {
        'Critical': 0,
        'High': 1,
        'Medium': 2,
        'Low': 3,
      };
      return (priorityOrder[a.priority] ?? 3).compareTo(priorityOrder[b.priority] ?? 3);
    });
    
    return recommendations;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Foraging Recommendations'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          tabs: [
            Tab(text: 'Actions', icon: Icon(Icons.checklist)),
            Tab(text: 'Plants', icon: Icon(Icons.local_florist)),
            Tab(text: 'Science', icon: Icon(Icons.science)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActionsTab(),
          _buildPlantsTab(),
          _buildScienceTab(),
        ],
      ),
    );
  }

  Widget _buildActionsTab() {
    return Column(
      children: [
        _buildFilters(),
        _buildRecommendationsSummary(),
        Expanded(
          child: _filteredRecommendations.isEmpty
              ? _buildNoRecommendations()
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _filteredRecommendations.length,
                  itemBuilder: (context, index) {
                    final recommendation = _filteredRecommendations[index];
                    return _buildRecommendationCard(recommendation);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRecommendationsSummary() {
    final recommendations = widget.analysisData.recommendations;
    final criticalCount = recommendations.where((r) => r.priority == 'Critical').length;
    final highCount = recommendations.where((r) => r.priority == 'High').length;
    final mediumCount = recommendations.where((r) => r.priority == 'Medium').length;
    
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'Daily Action Items',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'For ${DateFormat('MMMM dd, yyyy').format(widget.analysisData.date)}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              if (criticalCount > 0)
                _buildPriorityBadge('Critical', criticalCount, Colors.red.shade600),
              if (highCount > 0) ...[
                if (criticalCount > 0) SizedBox(width: 8),
                _buildPriorityBadge('High', highCount, Colors.orange.shade600),
              ],
              if (mediumCount > 0) ...[
                if (criticalCount > 0 || highCount > 0) SizedBox(width: 8),
                _buildPriorityBadge('Medium', mediumCount, Colors.green.shade600),
              ],
              if (recommendations.isEmpty)
                _buildPriorityBadge('All Good', 0, Colors.green.shade600),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(String priority, int count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count > 0) ...[
            Text(
              count.toString(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            SizedBox(width: 6),
          ],
          Text(
            priority,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedPriorityFilter,
              decoration: InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: ['All', 'Critical', 'High', 'Medium', 'Low'].map((priority) {
                return DropdownMenuItem(value: priority, child: Text(priority));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPriorityFilter = value!;
                });
              },
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedCategoryFilter,
              decoration: InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: ['All', 'Temperature', 'Activity', 'Weight', 'Seasonal', 'Environmental']
                  .map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategoryFilter = value!;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoRecommendations() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
          SizedBox(height: 16),
          Text(
            _selectedPriorityFilter == 'All' && _selectedCategoryFilter == 'All'
                ? 'No recommendations for today'
                : 'No recommendations match your filters',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            _selectedPriorityFilter == 'All' && _selectedCategoryFilter == 'All'
                ? 'Your hive is performing well!'
                : 'Try adjusting your filter settings',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          if (_selectedPriorityFilter == 'All' && _selectedCategoryFilter == 'All') ...[
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.eco, color: Colors.green.shade600, size: 32),
                  SizedBox(height: 8),
                  Text(
                    'Keep up the great work!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Continue monitoring and maintain current practices',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(DailyRecommendation recommendation) {
    final priorityColor = _getPriorityColor(recommendation.priority);
    final priorityIcon = _getPriorityIcon(recommendation.priority);
    
    return Card(
      elevation: 3,
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: priorityColor.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(priorityIcon, color: priorityColor, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        recommendation.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: priorityColor,
                        ),
                      ),
                    ),
                    _buildPriorityChip(recommendation.priority),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  recommendation.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Action Items:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                ...recommendation.actionItems.map((action) => _buildActionItem(action, priorityColor)).toList(),
                SizedBox(height: 16),
                
                // Recommendation details
                _buildDetailSection(recommendation, priorityColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(DailyRecommendation recommendation, Color color) {
    return Column(
      children: [
        _buildRecommendationDetail(
          Icons.schedule, 
          'Timeline', 
          recommendation.timeRelevance,
          Colors.blue.shade600
        ),
        SizedBox(height: 8),
        _buildRecommendationDetail(
          Icons.trending_up, 
          'Expected outcome', 
          recommendation.expectedOutcome,
          Colors.green.shade600
        ),
        SizedBox(height: 8),
        _buildRecommendationDetail(
          Icons.agriculture, 
          'Foraging impact', 
          recommendation.foragingImpact,
          Colors.orange.shade600
        ),
        SizedBox(height: 12),
        
        // Scientific basis
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.science, size: 20, color: Colors.purple.shade600),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scientific Basis',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      recommendation.scientificBasis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.purple.shade700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationDetail(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: color,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionItem(String action, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              action,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityChip(String priority) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getPriorityColor(priority),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
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

  Widget _buildPlantsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPlantTabHeader(),
          SizedBox(height: 24),
          _buildSeasonalPlantRecommendations(),
          SizedBox(height: 24),
          _buildPlantingCalendar(),
          SizedBox(height: 24),
          _buildQuickActionPlants(),
        ],
      ),
    );
  }

  Widget _buildPlantTabHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_florist, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Plant Recommendations',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Based on your hive activity patterns and current season',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonalPlantRecommendations() {
    final currentSeason = _getCurrentSeason();
    final seasonalPlants = EnhancedForagingAdvisoryService.seasonalPlants[currentSeason] ?? [];
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getSeasonDisplayName(currentSeason)} Plant Recommendations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            SizedBox(height: 16),
            if (seasonalPlants.isNotEmpty)
              ...seasonalPlants.map((plant) => _buildPlantCard(plant)).toList()
            else
              Text('No specific recommendations for this season'),
          ],
        ),
      ),
    );
  }

  String _getCurrentSeason() {
    final month = DateTime.now().month;
    if (month >= 3 && month <= 5) return 'spring';
    if (month >= 6 && month <= 8) return 'summer';
    if (month >= 9 && month <= 11) return 'fall';
    return 'winter';
  }

  String _getSeasonDisplayName(String season) {
    return season[0].toUpperCase() + season.substring(1);
  }

  Widget _buildPlantCard(PlantRecommendation plant) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plant.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              _buildPlantDetail('Planting', plant.plantingTime, Icons.schedule),
              SizedBox(width: 16),
              _buildPlantDetail('Bloom', plant.bloomPeriod, Icons.local_florist),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              _buildPlantDetail('Nectar', plant.nectarValue, Icons.opacity),
              SizedBox(width: 16),
              _buildPlantDetail('Pollen', plant.pollenValue, Icons.grain),
            ],
          ),
          SizedBox(height: 12),
          Text(
            plant.scientificBasis,
            style: TextStyle(
              fontSize: 12,
              color: Colors.green.shade700,
              fontStyle: FontStyle.italic,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Instructions: ${plant.plantingInstructions}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlantDetail(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.green.shade600),
        SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.green.shade700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: Colors.green.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildPlantingCalendar() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Year-Round Planting Calendar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            SizedBox(height: 16),
            _buildCalendarSeason('Spring (Mar-May)', [
              'Plant fruit trees for early nectar',
              'Sow wildflower mixes',
              'Establish willow for pollen',
              'Prepare soil for summer plants',
            ], Colors.green.shade100, Icons.eco),
            SizedBox(height: 12),
            _buildCalendarSeason('Summer (Jun-Aug)', [
              'Plant sunflowers and basswood',
              'Succession plant buckwheat',
              'Maintain water sources',
              'Monitor for summer dearth',
            ], Colors.yellow.shade100, Icons.wb_sunny),
            SizedBox(height: 12),
            _buildCalendarSeason('Fall (Sep-Nov)', [
              'Plant asters and goldenrod',
              'Prepare winter feed if needed',
              'Plant trees for next year',
              'Assess honey stores',
            ], Colors.orange.shade100, Icons.nature),
            SizedBox(height: 12),
            _buildCalendarSeason('Winter (Dec-Feb)', [
              'Plan next year\'s plantings',
              'Order seeds and saplings',
              'Prepare planting areas',
              'Monitor hive health',
            ], Colors.blue.shade100, Icons.ac_unit),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarSeason(String season, List<String> activities, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey.shade700),
              SizedBox(width: 8),
              Text(
                season,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          ...activities.map((activity) => Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    activity,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildQuickActionPlants() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emergency Forage Plants',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Fast-growing plants for poor foraging conditions',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 16),
            _buildEmergencyPlant(
              'Buckwheat',
              'Blooms in 6-8 weeks',
              'High nectar production',
              Icons.grass,
            ),
            _buildEmergencyPlant(
              'Phacelia',
              'Blooms in 6 weeks',
              'Excellent bee forage',
              Icons.local_florist,
            ),
            _buildEmergencyPlant(
              'Borage',
              'Blooms in 8 weeks',
              'Continuous nectar source',
              Icons.nature,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyPlant(String name, String timing, String benefit, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.red.shade600, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                ),
                Text(
                  '$timing • $benefit',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScienceTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildScienceHeader(),
          SizedBox(height: 24),
          _buildAnalysisBasedInsights(),
          SizedBox(height: 24),
          _buildResearchFoundations(),
          SizedBox(height: 24),
          _buildDataSources(),
        ],
      ),
    );
  }

  Widget _buildScienceHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade400, Colors.purple.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Scientific Foundation',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Understanding the research behind your hive\'s foraging optimization',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisBasedInsights() {
    final analysis = widget.analysisData;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Hive\'s Data Insights',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            SizedBox(height: 16),
            _buildInsightCard(
              'Temperature Correlation',
              'Your hive shows ${analysis.correlations.temperatureActivity >= 0 ? 'positive' : 'negative'} correlation (${analysis.correlations.temperatureActivity.toStringAsFixed(2)}) between temperature and activity.',
              _getCorrelationAdvice(analysis.correlations.temperatureActivity, 'temperature'),
              Icons.thermostat,
              Colors.red.shade600,
            ),
            SizedBox(height: 12),
            _buildInsightCard(
              'Foraging Patterns',
              'Analysis shows: ${analysis.foragingPatterns.overallForagingAssessment}',
              _getForagingAdvice(analysis.foragingPatterns.overallForagingAssessment),
              Icons.navigation,
              Colors.orange.shade600,
            ),
            SizedBox(height: 12),
            _buildInsightCard(
              'Activity Level',
              'Total daily activity: ${analysis.beeCountData.fold(0, (sum, hour) => sum + hour.totalActivity)} bee movements',
              _getActivityAdvice(analysis.beeCountData.fold(0, (sum, hour) => sum + hour.totalActivity)),
              Icons.trending_up,
              Colors.green.shade600,
            ),
          ],
        ),
      ),
    );
  }

  String _getCorrelationAdvice(double correlation, String parameter) {
    if (correlation.abs() > 0.6) {
      return 'Strong ${correlation > 0 ? 'positive' : 'negative'} correlation indicates $parameter significantly affects your bees. Use weather forecasts for optimal timing.';
    } else if (correlation.abs() > 0.3) {
      return 'Moderate correlation suggests $parameter has some influence. Monitor patterns for optimization opportunities.';
    } else {
      return 'Weak correlation indicates other factors may be more important than $parameter for your location.';
    }
  }

  String _getForagingAdvice(String assessment) {
    if (assessment.contains('Excellent')) {
      return 'Your bees have abundant local forage. Maintain current conditions and consider expanding colonies.';
    } else if (assessment.contains('Challenging')) {
      return 'Bees are working hard for forage. Consider planting closer nectar sources or supplemental feeding.';
    } else {
      return 'Monitor foraging patterns and consider gradual improvements to local forage availability.';
    }
  }

  String _getActivityAdvice(int totalActivity) {
    if (totalActivity > 800) {
      return 'Excellent activity levels indicate strong, healthy colony with good forage availability.';
    } else if (totalActivity > 400) {
      return 'Good activity levels. Monitor for opportunities to enhance foraging conditions.';
    } else if (totalActivity > 200) {
      return 'Moderate activity. Consider checking colony health and local forage availability.';
    } else {
      return 'Low activity may indicate issues with colony health, weather, or forage scarcity.';
    }
  }

  Widget _buildInsightCard(String title, String data, String advice, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            data,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            advice,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResearchFoundations() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Research Foundations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.purple.shade700,
              ),
            ),
            SizedBox(height: 16),
            _buildResearchSection(
              'Temperature and Foraging',
              'Optimal foraging occurs between 15-30°C with peak activity at 20-25°C. Activity drops 50% below 15°C and stops above 35°C.',
              [
                'Flight muscle efficiency peaks at 22-24°C',
                'Energy expenditure increases exponentially outside optimal range',
                'Heat stress above 32°C triggers cooling behaviors',
              ],
              Icons.thermostat,
              Colors.red.shade600,
            ),
            SizedBox(height: 16),
            _buildResearchSection(
              'Foraging Distance Economics',
              'Bees prefer forage within 2km. Energy cost doubles every 500m beyond optimal range, reducing net energy gain.',
              [
                'Optimal foraging radius: 1-3km from hive',
                'Quality trumps quantity for distant sources',
                'Diverse local forage reduces competition',
              ],
              Icons.navigation,
              Colors.orange.shade600,
            ),
            SizedBox(height: 16),
            _buildResearchSection(
              'Seasonal Nutritional Needs',
              'Colony requirements vary dramatically by season, requiring different foraging strategies.',
              [
                'Spring: 25% more protein for brood development',
                'Summer: Peak nectar collection for 60-80% of annual stores',
                'Fall: Critical protein for winter bee longevity',
              ],
              Icons.calendar_today,
              Colors.green.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResearchSection(String title, String summary, List<String> keyPoints, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          summary,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 8),
        ...keyPoints.map((point) => Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.only(top: 6),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  point,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildDataSources() {
    return Card(
      elevation: 3,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.source, color: Colors.blue.shade700, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Data Sources & Methodology',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _buildDataSource(
                'Real-time Hive Monitoring',
                'Temperature, humidity, and weight sensors provide continuous environmental data correlated with bee activity patterns.',
                Icons.sensors,
              ),
              _buildDataSource(
                'Computer Vision Analysis',
                'Machine learning models analyze video feeds to count bees entering and exiting, providing accurate activity measurements.',
                Icons.videocam,
              ),
              _buildDataSource(
                'Scientific Literature',
                'Recommendations based on peer-reviewed research from leading apiculture journals and university extension services.',
                Icons.book,
              ),
              _buildDataSource(
                'Statistical Correlation',
                'Advanced correlation analysis identifies relationships between environmental factors and foraging patterns for predictive insights.',
                Icons.analytics,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataSource(String title, String description, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue.shade600, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue.shade700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}