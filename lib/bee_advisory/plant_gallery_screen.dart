import 'package:flutter/material.dart';
import 'package:HPGM/bee_advisory/bee_advisory_database.dart';
import 'package:HPGM/bee_advisory/plant_detail_screen.dart';

class PlantGalleryScreen extends StatefulWidget {
  const PlantGalleryScreen({Key? key}) : super(key: key);

  @override
  State<PlantGalleryScreen> createState() => _PlantGalleryScreenState();
}

class _PlantGalleryScreenState extends State<PlantGalleryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _plants = [];
  String _searchQuery = '';
  String _selectedClimate = 'All';

  final List<String> _climateOptions = [
    'All',
    'Temperate',
    'Mediterranean',
    'Tropical',
    'Subtropical',
    'Cool temperate',
  ];

  @override
  void initState() {
    super.initState();
    _loadPlants();
  }

  Future<void> _loadPlants() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _plants = await BeeAdvisoryDatabase.instance.readAllPlants();
      _filterPlants();
    } catch (e) {
      print('Error loading plants: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterPlants() {
    List<Map<String, dynamic>> filteredPlants = List.from(_plants);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filteredPlants = filteredPlants.where((plant) {
        return plant['name'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
            plant['scientific_name'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );
      }).toList();
    }

    // Apply climate filter
    if (_selectedClimate != 'All') {
      filteredPlants = filteredPlants.where((plant) {
        return plant['climate_preference']
            .toString()
            .toLowerCase()
            .contains(_selectedClimate.toLowerCase());
      }).toList();
    }

    setState(() {
      _plants = filteredPlants;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plant Gallery'),
        backgroundColor: Color(0xFF4CAF50),
      ),
      body: Column(
        children: [
          _buildSearchAndFilterBar(),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF4CAF50),
                      ),
                    ),
                  )
                : _plants.isEmpty
                    ? Center(child: Text('No plants found'))
                    : GridView.builder(
                        padding: EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _plants.length,
                        itemBuilder: (context, index) {
                          final plant = _plants[index];
                          return _buildPlantCard(plant);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search plants...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF4CAF50)),
              ),
              contentPadding: EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
              _filterPlants();
            },
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Climate:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _climateOptions.map((climate) {
                      bool isSelected = _selectedClimate == climate;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedClimate = climate;
                          });
                          _filterPlants();
                        },
                        child: Container(
                          margin: EdgeInsets.only(right: 8),
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Color(0xFF4CAF50)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              climate,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlantCard(Map<String, dynamic> plant) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlantDetailScreen(plantId: plant['id']),
          ),
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.asset(
                plant['image_path'] ?? 'assets/plants/placeholder.jpg',
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 140,
                    color: Colors.grey[300],
                    child: Icon(Icons.image, size: 28, color: Colors.grey[500]),
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                      _buildValueIndicator('N', plant['nectar_value']),
                      SizedBox(width: 8),
                      _buildValueIndicator('P', plant['pollen_value']),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    plant['climate_preference'],
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                fontSize: 8,
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
              size: 8,
              color: index < value
                  ? (label == 'N' ? Colors.blue : Colors.amber)
                  : Colors.grey[400],
            );
          }),
        ),
      ],
    );
  }
}
