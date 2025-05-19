import 'package:flutter/material.dart';
import 'bee_advisory_database.dart';

class PlantDetailScreen extends StatefulWidget {
  final String plantId;

  const PlantDetailScreen({Key? key, required this.plantId}) : super(key: key);

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _plant;

  @override
  void initState() {
    super.initState();
    _loadPlantDetails();
  }

  Future<void> _loadPlantDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _plant = await BeeAdvisoryDatabase.instance.readPlant(widget.plantId);
    } catch (e) {
      print('Error loading plant details: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
              ),
            )
          : _plant == null
              ? Center(child: Text('Plant not found'))
              : CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 300,
                      pinned: true,
                      flexibleSpace: FlexibleSpaceBar(
                        title: Text(_plant!['name']),
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              _plant!['image_path'] ??
                                  'assets/plants/placeholder.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[300],
                                  child: Icon(
                                    Icons.image,
                                    size: 40,
                                    color: Colors.grey[500],
                                  ),
                                );
                              },
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.7),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _plant!['scientific_name'],
                              style: TextStyle(
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 13),
                            _buildInfoRow(
                              icon: Icons.eco,
                              title: 'Benefits to Bees',
                              content: _plant!['benefits_to_bees'],
                            ),
                            Divider(height: 32),
                            _buildInfoRow(
                              icon: Icons.description,
                              title: 'Description',
                              content: _plant!['description'],
                            ),
                            SizedBox(height: 13),
                            _buildInfoRow(
                              icon: Icons.thermostat,
                              title: 'Climate Preference',
                              content: _plant!['climate_preference'],
                            ),
                            SizedBox(height: 13),
                            _buildInfoRow(
                              icon: Icons.calendar_today,
                              title: 'Flowering Season',
                              content: _plant!['flowering_season'],
                            ),
                            Divider(height: 26),
                            Text(
                              'Planting Instructions',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              _plant!['planting_instructions'],
                              style: TextStyle(fontSize: 16),
                            ),
                            SizedBox(height: 20),
                            _buildRequirementsSection(),
                            SizedBox(height: 20),
                            _buildValueSection(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: Color(0xFF4CAF50)),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(content, style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequirementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Growing Requirements',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildRequirementItem(
                icon: Icons.wb_sunny,
                title: 'Sun',
                value: _plant!['sun_requirements'],
              ),
            ),
            Expanded(
              child: _buildRequirementItem(
                icon: Icons.water_drop,
                title: 'Water',
                value: _plant!['water_requirements'],
              ),
            ),
            Expanded(
              child: _buildRequirementItem(
                icon: Icons.build,
                title: 'Maintenance',
                value: _plant!['maintenance_level'],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRequirementItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    Color color;
    if (value.toLowerCase() == 'low') {
      color = Colors.green;
    } else if (value.toLowerCase() == 'moderate' ||
        value.toLowerCase() == 'medium') {
      color = Colors.amber;
    } else {
      color = Colors.orange;
    }

    return Column(
      children: [
        Icon(icon, size: 28, color: color),
        SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildValueSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Value to Bees',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 13),
        Row(
          children: [
            Expanded(
              child: _buildValueItem(
                label: 'Nectar',
                value: _plant!['nectar_value'],
                color: Colors.blue,
              ),
            ),
            Expanded(
              child: _buildValueItem(
                label: 'Pollen',
                value: _plant!['pollen_value'],
                color: Colors.amber,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildValueItem({
    required String label,
    required int value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return Icon(
              index < value ? Icons.star : Icons.star_border,
              size: 24,
              color: index < value ? color : Colors.grey[400],
            );
          }),
        ),
      ],
    );
  }
}
