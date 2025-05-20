import 'package:HPGM/bee_advisory/plant_gallery_screen.dart';
import 'package:flutter/material.dart';
import 'package:HPGM/bee_advisory/bee_advisory_engine.dart';
import 'package:HPGM/bee_advisory/bee_advisory_database.dart';
import 'package:HPGM/bee_advisory/plant_detail_screen.dart';
import 'package:HPGM/bee_advisory/supplements_screen.dart';
import 'package:HPGM/bee_advisory/farmer_form_screen.dart';
import 'package:HPGM/bee_advisory/bee_advisory_visualizations.dart';
import 'package:HPGM/analytics/foraging_analysis/foraging_analysis_engine.dart';
// import 'package:HPGM/Services/bee_analysis_service.dart';

class BeeAdvisoryScreen extends StatefulWidget {
  final String? hiveId;

  const BeeAdvisoryScreen({Key? key, this.hiveId}) : super(key: key);

  @override
  State<BeeAdvisoryScreen> createState() => _BeeAdvisoryScreenState();
}

class _BeeAdvisoryScreenState extends State<BeeAdvisoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _recommendations = [];
  List<Map<String, dynamic>> _recommendedPlants = [];
  List<Map<String, dynamic>> _recommendedSupplements = [];

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get recommendations for this hive
      if (widget.hiveId != null) {
        // First try to load existing recommendations
        _recommendations = await BeeAdvisoryDatabase.instance
            .readRecommendationsByHive(widget.hiveId!);

        // If no recommendations exist or they're empty, generate new ones
        if (_recommendations.isEmpty) {
          print('No existing recommendations found, generating new ones...');
          _recommendations = await BeeAdvisoryEngine.instance
              .generateRecommendations(hiveId: widget.hiveId!);

          // If still no recommendations, try with a wider date range (last 30 days)
          if (_recommendations.isEmpty ||
              _recommendations.first.containsKey('error')) {
            print('Trying with extended date range...');
            final DateTime now = DateTime.now();
            final DateTime thirtyDaysAgo = now.subtract(Duration(days: 30));

            _recommendations = await BeeAdvisoryEngine.instance
                .generateRecommendations(
                  hiveId: widget.hiveId!,
                  startDate: thirtyDaysAgo,
                  endDate: now,
                );
          }
        }

        // Load recommended plants and supplements
        await _loadRecommendedItems();
      }
    } catch (e) {
      print('Error loading recommendations: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRecommendedItems() async {
    _recommendedPlants = [];
    _recommendedSupplements = [];

    // Process each recommendation
    for (var recommendation in _recommendations) {
      if (recommendation.containsKey('recommended_plants') &&
          recommendation['recommended_plants'] != null &&
          recommendation['recommended_plants'].toString().isNotEmpty) {
        List<String> plantIds = recommendation['recommended_plants']
            .toString()
            .split(',');

        for (var plantId in plantIds) {
          var plant = await BeeAdvisoryDatabase.instance.readPlant(plantId);
          if (plant != null &&
              !_recommendedPlants.any((p) => p['id'] == plant['id'])) {
            _recommendedPlants.add(plant);
          }
        }
      }

      if (recommendation.containsKey('recommended_supplements') &&
          recommendation['recommended_supplements'] != null &&
          recommendation['recommended_supplements'].toString().isNotEmpty) {
        List<String> suppIds = recommendation['recommended_supplements']
            .toString()
            .split(',');

        for (var suppId in suppIds) {
          var supplement = await BeeAdvisoryDatabase.instance.readSupplement(
            suppId,
          );
          if (supplement != null &&
              !_recommendedSupplements.any(
                (s) => s['id'] == supplement['id'],
              )) {
            _recommendedSupplements.add(supplement);
          }
        }
      }
    }
  }

  // Add this method to the BeeAdvisoryScreen class
  Future<void> _generatePredictiveRecommendations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get predictive recommendations for each hive
      List<Map<String, dynamic>> hives =
          await BeeAdvisoryDatabase.instance.readAllHives();
      List<Map<String, dynamic>> allPredictions = [];

      for (var hive in hives) {
        String hiveId = hive['id'];

        // Generate predictive recommendations
        final predictions = await BeeAdvisoryEngine.instance
            .generatePredictiveRecommendations( hiveId);

        allPredictions.addAll(predictions);
      }

      // Add predictions to recommendations
      setState(() {
        _recommendations.addAll(allPredictions);

        // Sort recommendations by priority
        _recommendations.sort(
          (a, b) => (a['priority'] as int).compareTo(b['priority'] as int),
        );

        _isLoading = false;
      });
    } catch (e) {
      print('Error generating predictive recommendations: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Add this method to the BeeAdvisoryScreen class
  Widget _buildRecommendationWithVisualization(
    BuildContext context,
    Map<String, dynamic> recommendation,
    Map<String, dynamic> foragingData,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Original recommendation card
        _buildRecommendationCard(context, recommendation),

        const SizedBox(height: 16),

        // Add visualization dashboard
        BeeAdvisoryVisualizations.generateRecommendationDashboard(
          context,
          recommendation,
          foragingData,
        ),
      ],
    );
  }

  Map<String, Map<String, dynamic>> _foragingDataMap = {};

  Future<void> _refreshRecommendations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get recommendations for each hive
      List<Map<String, dynamic>> hives =
          await BeeAdvisoryDatabase.instance.readAllHives();
      List<Map<String, dynamic>> allRecommendations = [];

      // Clear existing foraging data
      _foragingDataMap.clear();

      for (var hive in hives) {
        String hiveId = hive['id'];

        // Get foraging data for visualization
        final foragingData =
            await ForagingAnalysisEngine.analyzeForagingActivity(
              hiveId: hiveId,
              includeWeatherData: true,
            );

        if (foragingData.containsKey('hasData') && foragingData['hasData']) {
          _foragingDataMap[hiveId] = foragingData;
        }

        // Generate recommendations
        final recommendations = await BeeAdvisoryEngine.instance
            .generateRecommendations(hiveId: hiveId);

        // For each recommendation, add historical comparison
        for (var i = 0; i < recommendations.length; i++) {
          var rec = recommendations[i];

          // Add historical comparison data
          final historicalComparison = await BeeAdvisoryEngine.instance
              .compareWithHistoricalRecommendations(hiveId, rec);

          recommendations[i] = {
            ...rec,
            'historicalComparison': historicalComparison,
          };
        }

        // Generate seasonal recommendations
        final seasonalRecommendations = await BeeAdvisoryEngine.instance
            .generateSeasonalRecommendations(hiveId);

        allRecommendations.addAll([
          ...recommendations,
          ...seasonalRecommendations,
        ]);
      }

      // Sort recommendations by priority
      allRecommendations.sort(
        (a, b) => (a['priority'] as int).compareTo(b['priority'] as int),
      );

      setState(() {
        _recommendations = allRecommendations;
        _isLoading = false;
      });
    } catch (e) {
      print('Error refreshing recommendations: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bee Advisory'),
        backgroundColor: Color(0xFF4CAF50),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshRecommendations,
            tooltip: 'Refresh Recommendations',
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                ),
              )
              : SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRecommendationsSection(),
                    SizedBox(height: 24),
                    _buildRecommendedPlantsSection(),
                    SizedBox(height: 24),
                    _buildRecommendedSupplementsSection(),
                    SizedBox(height: 24),
                    _buildActionButtonsSection(),
                  ],
                ),
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => FarmerFormScreen()),
          );
        },
        child: Icon(Icons.add),
        tooltip: 'Add Manual Input',
      ),
    );
  }

  Widget _buildRecommendations(BuildContext context) {
    if (_recommendations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No recommendations available',
              style: TextStyle(fontSize: 18, color: Colors.grey[800]),
            ),
            SizedBox(height: 8),
            Text(
              'Tap the refresh button to generate new recommendations',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _recommendations.length,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final recommendation = _recommendations[index];
        
        // Determine card color based on severity
        Color cardColor;
        switch (recommendation['severity']) {
          case 'High':
            cardColor = Colors.red[50]!;
            break;
          case 'Medium':
            cardColor = Colors.amber[50]!;
            break;
          default:
            cardColor = Colors.green[50]!;
        }
        
        // Handle display of historical comparison if available
        Widget historyWidget = SizedBox.shrink();
        if (recommendation.containsKey('historicalComparison')) {
          Map<String, dynamic> history = recommendation['historicalComparison'];
          if (history.containsKey('isRecurring') && history['isRecurring']) {
            historyWidget = Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Recurring issue: ${history['occurrences']} times in the past',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[800],
                ),
              ),
            );
          }
        }
        
        return Card(
          color: cardColor,
          margin: EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recommendation['issue_identified'],
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Severity: ${recommendation['severity']}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: recommendation['severity'] == 'High' ? Colors.red : 
                           recommendation['severity'] == 'Medium' ? Colors.orange : Colors.green,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Management Actions:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(recommendation['management_actions']),
                historyWidget,
                SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // Implement detail view navigation
                    },
                    child: Text('View Details'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecommendationsSection() {
    if (_recommendations.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.lightbulb_outline, size: 48, color: Colors.amber),
              SizedBox(height: 16),
              Text(
                'No Recommendations Yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Tap the refresh button to generate recommendations based on your foraging analysis data.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommendations',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        ...List.generate(_recommendations.length, (index) {
          final recommendation = _recommendations[index];

          Color severityColor;
          switch (recommendation['severity']) {
            case 'High':
              severityColor = Colors.red;
              break;
            case 'Medium':
              severityColor = Colors.orange;
              break;
            default:
              severityColor = Colors.green;
          }

          bool isImplemented = recommendation['is_implemented'] == 1;

          return Card(
            elevation: 2,
            margin: EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: severityColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${recommendation['severity']} Priority',
                          style: TextStyle(
                            color: severityColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Spacer(),
                      if (isImplemented)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Implemented',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    recommendation['issue_identified'],
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    recommendation['management_actions'],
                    style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Expected Outcome:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    recommendation['expected_outcome'],
                    style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                  ),
                  if (recommendation.containsKey('notes') &&
                      recommendation['notes'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        recommendation['notes'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  SizedBox(height: 16),
                  if (!isImplemented)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () async {
                            await BeeAdvisoryDatabase.instance
                                .updateRecommendationImplementation(
                                  recommendation['id'],
                                  true,
                                );
                            await _loadRecommendations();
                            setState(() {});
                          },
                          child: Text('Mark as Implemented'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Color(0xFF4CAF50),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRecommendedPlantsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recommended Plants',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PlantGalleryScreen()),
                );
              },
              child: Text('View All'),
              style: TextButton.styleFrom(foregroundColor: Color(0xFF4CAF50)),
            ),
          ],
        ),
        SizedBox(height: 12),
        if (_recommendedPlants.isEmpty)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No plant recommendations available yet.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ),
            ),
          )
        else
          Container(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recommendedPlants.length,
              itemBuilder: (context, index) {
                final plant = _recommendedPlants[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                PlantDetailScreen(plantId: plant['id']),
                      ),
                    );
                  },
                  child: Container(
                    width: 160,
                    margin: EdgeInsets.only(right: 16),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: Image.asset(
                              plant['image_path'] ??
                                  'assets/plants/placeholder.jpg',
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 120,
                                  color: Colors.grey[300],
                                  child: Icon(
                                    Icons.image,
                                    size: 40,
                                    color: Colors.grey[500],
                                  ),
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  plant['name'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  plant['scientific_name'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey[700],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildValueIndicator(
                                      'N',
                                      plant['nectar_value'],
                                    ),
                                    SizedBox(width: 8),
                                    _buildValueIndicator(
                                      'P',
                                      plant['pollen_value'],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRecommendedSupplementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recommended Supplements',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SupplementsScreen()),
                );
              },
              child: Text('View All'),
              style: TextButton.styleFrom(foregroundColor: Color(0xFF4CAF50)),
            ),
          ],
        ),
        SizedBox(height: 12),
        if (_recommendedSupplements.isEmpty)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No supplement recommendations available yet.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ),
            ),
          )
        else
          Column(
            children: List.generate(_recommendedSupplements.length, (index) {
              final supplement = _recommendedSupplements[index];
              return Card(
                elevation: 2,
                margin: EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          supplement['image_path'] ??
                              'assets/supplements/placeholder.jpg',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey[300],
                              child: Icon(
                                Icons.image,
                                size: 40,
                                color: Colors.grey[500],
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              supplement['name'],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                supplement['type'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              supplement['description'],
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[800],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }

  Widget _buildActionButtonsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.assignment,
                label: 'Fill Farmer Form',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => FarmerFormScreen()),
                  ).then((_) => _loadRecommendations());
                },
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildActionButton(
                icon: Icons.eco,
                label: 'Plant Gallery',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlantGalleryScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.medical_services,
                label: 'Supplements',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SupplementsScreen(),
                    ),
                  );
                },
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildActionButton(
                icon: Icons.refresh,
                label: 'Refresh Analysis',
                onTap: _refreshRecommendations,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildValueIndicator(String label, int value) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: label == 'N' ? Colors.blue[100] : Colors.amber[100],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: label == 'N' ? Colors.blue[800] : Colors.amber[800],
              ),
            ),
          ),
        ),
        SizedBox(width: 4),
        Row(
          children: List.generate(5, (index) {
            return Icon(
              index < value ? Icons.star : Icons.star_border,
              size: 12,
              color:
                  index < value
                      ? (label == 'N' ? Colors.blue : Colors.amber)
                      : Colors.grey[400],
            );
          }),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Color(0xFF4CAF50).withOpacity(0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Color(0xFF4CAF50)),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(BuildContext context, Map<String, dynamic> recommendation) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and issue title
            Row(
              children: [
                Icon(
                  _getRecommendationIcon(recommendation['issue_identified']),
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    recommendation['issue_identified'],
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Priority indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(recommendation['priority']),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    recommendation['priority'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Description
            Text(
              recommendation['description'],
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            
            // Recommended action
            Text(
              'Recommended Action',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              recommendation['recommended_action'],
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    // Handle viewing details
                    _viewRecommendationDetails(recommendation);
                  },
                  child: const Text('View Details'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    // Handle implementing action
                    _implementRecommendation(recommendation);
                  },
                  child: const Text('Implement'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods for the recommendation card
  IconData _getRecommendationIcon(String issue) {
    if (issue.contains('Return Rate') || issue.contains('Foraging Performance')) {
      return Icons.loop;
    } else if (issue.contains('Duration') || issue.contains('Trip')) {
      return Icons.timer;
    } else if (issue.contains('Weather')) {
      return Icons.cloud;
    } else if (issue.contains('Activity')) {
      return Icons.schedule;
    } else if (issue.contains('Health')) {
      return Icons.favorite;
    } else {
      return Icons.analytics;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  void _viewRecommendationDetails(Map<String, dynamic> recommendation) {
    // Show a dialog with detailed information about the recommendation
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(recommendation['issue_identified']),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Display severity with appropriate styling
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(recommendation['severity'] ?? recommendation['priority']),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Severity: ${recommendation['severity'] ?? recommendation['priority']}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                
                // Description section
                Text(
                  'Issue Details:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(recommendation['description'] ?? recommendation['issue_identified']),
                SizedBox(height: 16),
                
                // Management actions section
                Text(
                  'Management Actions:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(recommendation['management_actions'] ?? recommendation['recommended_action']),
                SizedBox(height: 16),
                
                // Expected outcome section
                if (recommendation.containsKey('expected_outcome'))
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Expected Outcome:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(recommendation['expected_outcome']),
                      SizedBox(height: 16),
                    ],
                  ),
                
                // Historical data if available
                if (recommendation.containsKey('historicalComparison'))
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Historical Data:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        recommendation['historicalComparison']['isRecurring'] 
                            ? 'This issue has occurred ${recommendation['historicalComparison']['occurrences']} times in the past.'
                            : 'This is a new issue.',
                      ),
                      if (recommendation['historicalComparison']['isRecurring'])
                        Text(
                          'Last occurrence: ${recommendation['historicalComparison']['lastOccurrence'] ?? 'Unknown'}',
                        ),
                      SizedBox(height: 16),
                    ],
                  ),
                
                // Notes section if available
                if (recommendation.containsKey('notes') && recommendation['notes'] != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Additional Notes:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(recommendation['notes']),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                // Close dialog and implement recommendation
                Navigator.of(context).pop();
                _implementRecommendation(recommendation);
              },
              child: Text('Implement'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF4CAF50),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }
  
  void _implementRecommendation(Map<String, dynamic> recommendation) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                ),
                SizedBox(width: 16),
                Text("Updating recommendation status..."),
              ],
            ),
          );
        },
      );
  
      // Update the recommendation in the database
      await BeeAdvisoryDatabase.instance.updateRecommendationImplementation(
        recommendation['id'],
        true,
      );
      
      // Close loading dialog
      Navigator.of(context).pop();
  
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recommendation implemented successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
  
      // Refresh recommendations to update UI
      await _loadRecommendations();
      
    } catch (e) {
      // Close loading dialog if it's open
      Navigator.of(context).pop();
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error implementing recommendation: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      print('Error implementing recommendation: $e');
    }
  }
}