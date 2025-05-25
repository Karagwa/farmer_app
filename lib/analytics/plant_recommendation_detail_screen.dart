
import 'package:flutter/material.dart';
import 'package:HPGM/analytics/foraging_advisory_service.dart';

class PlantRecommendationDetailScreen extends StatelessWidget {
  final PlantRecommendation plant;

  const PlantRecommendationDetailScreen({Key? key, required this.plant}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(plant.name),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            SizedBox(height: 16),
            _buildValueMetrics(),
            SizedBox(height: 16),
            _buildPlantingGuide(),
            SizedBox(height: 16),
            _buildScientificInfo(),
            SizedBox(height: 16),
            _buildCareTips(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            colors: [Colors.green.shade400, Colors.green.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_florist, color: Colors.white, size: 32),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      plant.name,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Blooms: ${plant.bloomPeriod}',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Plant: ${plant.plantingTime}',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValueMetrics() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bee Value Metrics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildValueCard(
                    'Nectar Value',
                    plant.nectarValue,
                    Icons.water_drop,
                    _getValueColor(plant.nectarValue),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildValueCard(
                    'Pollen Value',
                    plant.pollenValue,
                    Icons.grain,
                    _getValueColor(plant.pollenValue),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getValueColor(String value) {
    if (value.toLowerCase().contains('excellent') || value.toLowerCase().contains('outstanding')) {
      return Colors.green.shade600;
    } else if (value.toLowerCase().contains('good') || value.toLowerCase().contains('high')) {
      return Colors.orange.shade600;
    }
    return Colors.grey.shade600;
  }

  Widget _buildPlantingGuide() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Planting Instructions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                plant.plantingInstructions,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.blue.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScientificInfo() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science, color: Colors.purple.shade600, size: 24),
                SizedBox(width: 8),
                Text(
                  'Scientific Basis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              plant.scientificBasis,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCareTips() {
    final careTips = _getCareTips(plant.name);
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tips_and_updates, color: Colors.orange.shade600, size: 24),
                SizedBox(width: 8),
                Text(
                  'Care & Maintenance Tips',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...careTips.map((tip) => _buildCareTip(tip)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCareTip(String tip) {
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
              color: Colors.orange.shade600,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                fontSize: 14,
                height: 1.3,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getCareTips(String plantName) {
    // Generic care tips based on plant type
    if (plantName.toLowerCase().contains('tree')) {
      return [
        'Water deeply once weekly during first year',
        'Mulch around base to retain moisture',
        'Prune during dormant season',
        'Protect from deer and rodents when young',
        'Allow 3-5 years for full nectar production',
      ];
    } else if (plantName.toLowerCase().contains('clover')) {
      return [
        'Broadcast seed in spring or fall',
        'No need for fertilization - fixes own nitrogen',
        'Mow high (3+ inches) to encourage blooming',
        'Reseed thin areas annually',
        'Tolerates foot traffic well',
      ];
    } else if (plantName.toLowerCase().contains('lavender')) {
      return [
        'Plant in well-draining soil',
        'Requires full sun exposure',
        'Drought tolerant once established',
        'Prune after flowering to maintain shape',
        'Divide every 3-4 years',
      ];
    } else {
      return [
        'Follow seed packet instructions for depth',
        'Water regularly until established',
        'Deadhead spent flowers to encourage blooming',
        'Monitor for pests and diseases',
        'Collect seeds for next year if desired',
      ];
    }
  }
}



