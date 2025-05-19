import 'package:flutter/material.dart';
import 'package:HPGM/bee_advisory/bee_advisory_engine.dart';
import 'package:HPGM/bee_advisory/bee_advisory_database.dart';
import 'package:HPGM/bee_advisory/plant_detail_screen.dart';

class FarmerFormScreen extends StatefulWidget {
  const FarmerFormScreen({Key? key}) : super(key: key);

  @override
  State<FarmerFormScreen> createState() => _FarmerFormScreenState();
}

class _FarmerFormScreenState extends State<FarmerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _showResults = false;

  // Form data
  String _farmerName = '';
  String _farmLocation = '';
  int _hiveCount = 1;
  double _availableArea = 0;
  String _climateZone = 'Temperate';
  String _currentPlants = '';
  String _currentIssues = '';
  String _budgetConstraint = 'Medium';
  String _goals = '';

  // Results
  List<Map<String, dynamic>> _recommendedPlants = [];
  List<Map<String, dynamic>> _recommendedSupplements = [];
  List<String> _managementActions = [];

  // Options for dropdowns
  final List<String> _climateOptions = [
    'Temperate',
    'Mediterranean',
    'Tropical',
    'Subtropical',
    'Cool temperate',
  ];

  final List<String> _budgetOptions = ['Low', 'Medium', 'High'];

  @override
  void initState() {
    super.initState();
    _loadPreviousInput();
  }

  Future<void> _loadPreviousInput() async {
    try {
      final previousInput =
          await BeeAdvisoryDatabase.instance.readLatestFarmerInput();

      if (previousInput != null) {
        setState(() {
          _farmerName = previousInput['farmer_name'] ?? '';
          _farmLocation = previousInput['farm_location'] ?? '';
          _hiveCount = previousInput['hive_count'] ?? 1;
          _availableArea = previousInput['available_area'] ?? 0;
          _climateZone = previousInput['climate_zone'] ?? 'Temperate';
          _currentPlants = previousInput['current_plants'] ?? '';
          _currentIssues = previousInput['current_issues'] ?? '';
          _budgetConstraint = previousInput['budget_constraint'] ?? 'Medium';
          _goals = previousInput['goals'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading previous input: $e');
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      setState(() {
        _isLoading = true;
      });

      try {
        // Prepare form data
        final formData = {
          'farmer_name': _farmerName,
          'farm_location': _farmLocation,
          'hive_count': _hiveCount,
          'available_area': _availableArea,
          'climate_zone': _climateZone,
          'current_plants': _currentPlants,
          'current_issues': _currentIssues,
          'budget_constraint': _budgetConstraint,
          'goals': _goals,
        };

        // Process form and get recommendations
        final result = await BeeAdvisoryEngine.instance.processFarmerForm(
          formData,
        );

        if (result['success']) {
          setState(() {
            _recommendedPlants = result['recommended_plants'];
            _recommendedSupplements = result['recommended_supplements'];
            _managementActions = result['management_actions'];
            _showResults = true;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        print('Error submitting form: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmer Form'),
        backgroundColor: Color(0xFF4CAF50),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
              ),
            )
          : _showResults
              ? _buildResultsView()
              : _buildFormView(),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Beekeeper Information',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            TextFormField(
              initialValue: _farmerName,
              decoration: InputDecoration(
                labelText: 'Your Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
              onSaved: (value) {
                _farmerName = value ?? '';
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              initialValue: _farmLocation,
              decoration: InputDecoration(
                labelText: 'Farm/Apiary Location',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.location_on),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your location';
                }
                return null;
              },
              onSaved: (value) {
                _farmLocation = value ?? '';
              },
            ),
            SizedBox(height: 24),
            Text(
              'Apiary Details',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _hiveCount.toString(),
                    decoration: InputDecoration(
                      labelText: 'Number of Hives',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.hive),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Enter a number';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _hiveCount = int.tryParse(value ?? '1') ?? 1;
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _availableArea.toString(),
                    decoration: InputDecoration(
                      labelText: 'Available Area (sq m)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.landscape),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Enter a number';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _availableArea = double.tryParse(value ?? '0') ?? 0;
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _climateZone,
              decoration: InputDecoration(
                labelText: 'Climate Zone',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.thermostat),
              ),
              items: _climateOptions.map((climate) {
                return DropdownMenuItem(
                  value: climate,
                  child: Text(climate),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _climateZone = value ?? 'Temperate';
                });
              },
              onSaved: (value) {
                _climateZone = value ?? 'Temperate';
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              initialValue: _currentPlants,
              decoration: InputDecoration(
                labelText: 'Current Plants in Area',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.eco),
                hintText: 'List major plants or crops near your hives',
              ),
              maxLines: 2,
              onSaved: (value) {
                _currentPlants = value ?? '';
              },
            ),
            SizedBox(height: 24),
            Text(
              'Challenges & Goals',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            TextFormField(
              initialValue: _currentIssues,
              decoration: InputDecoration(
                labelText: 'Current Issues',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.warning),
                hintText: 'E.g., low honey production, weak colonies, pests',
              ),
              maxLines: 2,
              onSaved: (value) {
                _currentIssues = value ?? '';
              },
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _budgetConstraint,
              decoration: InputDecoration(
                labelText: 'Budget Constraint',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.attach_money),
              ),
              items: _budgetOptions.map((budget) {
                return DropdownMenuItem(value: budget, child: Text(budget));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _budgetConstraint = value ?? 'Medium';
                });
              },
              onSaved: (value) {
                _budgetConstraint = value ?? 'Medium';
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              initialValue: _goals,
              decoration: InputDecoration(
                labelText: 'Your Goals',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.flag),
                hintText: 'What do you want to achieve with your bees?',
              ),
              maxLines: 3,
              onSaved: (value) {
                _goals = value ?? '';
              },
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitForm,
                child: Text(
                  'Get Recommendations',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4CAF50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
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
                      Icon(
                        Icons.check_circle,
                        color: Color(0xFF4CAF50),
                        size: 32,
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recommendations Generated',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Based on your input, we\'ve created personalized recommendations for your apiary.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Recommended Plants',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          _recommendedPlants.isEmpty
              ? Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'No specific plant recommendations based on your input.',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ),
                  ),
                )
              : Container(
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
                              builder: (context) =>
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
          SizedBox(height: 24),
          Text(
            'Recommended Supplements',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          _recommendedSupplements.isEmpty
              ? Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'No specific supplement recommendations based on your input.',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ),
                  ),
                )
              : Column(
                  children: List.generate(_recommendedSupplements.length, (
                    index,
                  ) {
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
          SizedBox(height: 24),
          Text(
            'Management Actions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          _managementActions.isEmpty
              ? Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'No specific management actions recommended.',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ),
                  ),
                )
              : Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:
                          List.generate(_managementActions.length, (index) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Color(0xFF4CAF50),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    (index + 1).toString(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  _managementActions[index],
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _showResults = false;
                    });
                  },
                  child: Text('Edit Form'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFF4CAF50),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Done'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF4CAF50),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
