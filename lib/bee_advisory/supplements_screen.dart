import 'package:flutter/material.dart';
import 'package:HPGM/bee_advisory/bee_advisory_database.dart';

class SupplementsScreen extends StatefulWidget {
  const SupplementsScreen({Key? key}) : super(key: key);

  @override
  State<SupplementsScreen> createState() => _SupplementsScreenState();
}

class _SupplementsScreenState extends State<SupplementsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _supplements = [];
  String _searchQuery = '';
  String _selectedType = 'All';

  final List<String> _typeOptions = [
    'All',
    'Feed',
    'Health',
    'Stimulant',
    'Medication',
  ];

  @override
  void initState() {
    super.initState();
    _loadSupplements();
  }

  Future<void> _loadSupplements() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _supplements = await BeeAdvisoryDatabase.instance.readAllSupplements();
      _filterSupplements();
    } catch (e) {
      print('Error loading supplements: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterSupplements() {
    List<Map<String, dynamic>> filteredSupplements = List.from(_supplements);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filteredSupplements = filteredSupplements.where((supplement) {
        return supplement['name'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
            supplement['description'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );
      }).toList();
    }

    // Apply type filter
    if (_selectedType != 'All') {
      filteredSupplements = filteredSupplements.where((supplement) {
        return supplement['type'] == _selectedType;
      }).toList();
    }

    setState(() {
      _supplements = filteredSupplements;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bee Supplements'),
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
                : _supplements.isEmpty
                    ? Center(child: Text('No supplements found'))
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _supplements.length,
                        itemBuilder: (context, index) {
                          final supplement = _supplements[index];
                          return _buildSupplementCard(supplement);
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
              hintText: 'Search supplements...',
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
              _filterSupplements();
            },
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Type:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _typeOptions.map((type) {
                      bool isSelected = _selectedType == type;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedType = type;
                          });
                          _filterSupplements();
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
                              type,
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

  Widget _buildSupplementCard(Map<String, dynamic> supplement) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(
          supplement['name'],
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            Container(
              margin: EdgeInsets.only(top: 4),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                supplement['type'],
                style: TextStyle(fontSize: 12, color: Colors.blue[700]),
              ),
            ),
            SizedBox(width: 8),
            Container(
              margin: EdgeInsets.only(top: 4),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                supplement['price_range'],
                style: TextStyle(fontSize: 12, color: Colors.orange[700]),
              ),
            ),
          ],
        ),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            supplement['image_path'] ?? 'assets/supplements/placeholder.jpg',
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 60,
                height: 60,
                color: Colors.grey[300],
                child: Icon(Icons.image, size: 30, color: Colors.grey[500]),
              );
            },
          ),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Description',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(supplement['description'], style: TextStyle(fontSize: 14)),
                SizedBox(height: 16),
                Text(
                  'Usage Instructions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  supplement['usage_instructions'],
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dosage',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            supplement['dosage'],
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'When to Use',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            supplement['when_to_use'],
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  'Benefits',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(supplement['benefits'], style: TextStyle(fontSize: 14)),
                if (supplement.containsKey('cautions') &&
                    supplement['cautions'] != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 16),
                      Text(
                        'Cautions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        supplement['cautions'],
                        style: TextStyle(fontSize: 14, color: Colors.red[700]),
                      ),
                    ],
                  ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Price Range',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            supplement['price_range'],
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Availability',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            supplement['availability'],
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
