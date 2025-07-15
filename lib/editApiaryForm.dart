import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';


class EditApiaryForm extends StatefulWidget {
  final String token;
  final int farmId;
  final Map<String, dynamic> initialData;

  const EditApiaryForm({
    Key? key,
    required this.token,
    required this.farmId,
    required this.initialData,
  }) : super(key: key);

  @override
  State<EditApiaryForm> createState() => _EditApiaryFormState();
}

class _EditApiaryFormState extends State<EditApiaryForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ownerIdController;
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _districtController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _descriptionController;
  
  bool _isLoading = false;
  String? _errorMessage;

  LatLng _mapCenter = LatLng(0, 0);

  @override
  void initState() {
    super.initState();
    _ownerIdController = TextEditingController(text: widget.initialData['OwnerId']?.toString() ?? '');
    _nameController = TextEditingController(text: widget.initialData['name'] ?? '');
    _addressController = TextEditingController(text: widget.initialData['address'] ?? '');
    _districtController = TextEditingController(text: widget.initialData['district'] ?? '');
    _latitudeController = TextEditingController(text: widget.initialData['latitude']?.toString() ?? '');
    _longitudeController = TextEditingController(text: widget.initialData['longitude']?.toString() ?? '');
    _descriptionController = TextEditingController(text: widget.initialData['description'] ?? '');
    _addressController.addListener(_autoGeocode);
_districtController.addListener(_autoGeocode);

  }

 void _autoGeocode() async {
    String query =
        _addressController.text.isNotEmpty
            ? _addressController.text
            : _districtController.text;
    if (query.isNotEmpty) {
      try {
        List<Location> locations = await locationFromAddress(query);
        if (locations.isNotEmpty) {
          setState(() {
            _latitudeController.text = locations.first.latitude.toString();
            _longitudeController.text = locations.first.longitude.toString();
          });
        } else {
          // Show a snackbar or error message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location not found. Please refine your address or district.',
              ),
            ),
          );
        }
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error finding location.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _ownerIdController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _districtController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

Future<void> _openMapPicker() async {
  if (_latitudeController.text.isEmpty || _longitudeController.text.isEmpty) {
    String query = _addressController.text.isNotEmpty
        ? _addressController.text
        : _districtController.text;
    if (query.isNotEmpty) {
      try {
        List<Location> locations = await locationFromAddress(query);
        if (locations.isNotEmpty) {
          _mapCenter = LatLng(
            locations.first.latitude,
            locations.first.longitude,
          );
        }
      } catch (_) {}
    }
  } else {
    _mapCenter = LatLng(
      double.tryParse(_latitudeController.text) ?? 0,
      double.tryParse(_longitudeController.text) ?? 0,
    );
  }

  LatLng? picked = await showDialog<LatLng>(
    context: context,
    builder: (context) {
      LatLng selected = _mapCenter;
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Pick Location'),
            content: SizedBox(
              width: 300,
              height: 300,
              child: FlutterMap(
               options: MapOptions(
                  center: selected,
                  zoom: 13.0,
                  minZoom: 5,
                  maxZoom: 18,
                  interactiveFlags: InteractiveFlag.all,
                  onTap: (tapPosition, point) {
                    setState(() {
                      selected = point;
                    });
                  },
                ),
                children: [
                 TileLayer(
                  urlTemplate: "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png",
                  subdomains: ['a', 'b', 'c'],
                  tileProvider: NetworkTileProvider(
                    headers: {
                      'User-Agent': 'farmerApp/1.0 (ayanhilwa@gmail.com)',
                    },
                  ),
                ),

                  MarkerLayer(
                    markers: [
                      Marker(
                        point: selected,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, selected),
                child: const Text('Select'),
              ),
            ],
          );
        },
      );
    },
  );

  if (picked != null) {
    setState(() {
      _latitudeController.text = picked.latitude.toString();
      _longitudeController.text = picked.longitude.toString();
    });
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.brown[100],
      appBar: AppBar(
        title: const Text(
          'Edit Apiary',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: "Sans",
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.orange[700],
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Apiary Info Card
              Card(
                color: Colors.brown[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(Icons.hexagon, color: Colors.orange[700], size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nameController.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: "Sans",
                              ),
                            ),
                            Text(
                              'ID: ${widget.farmId}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontFamily: "Sans",
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Basic Information Section
              _buildSectionHeader('Basic Information'),
              
              _buildTextField(
                'Apiary Name',
                _nameController,
                hint: 'Enter apiary name',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter apiary name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Location Section
              _buildSectionHeader('Location Details'),
              _buildTextField(
                'Address',
                _addressController,
                hint: 'Enter complete address',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter address';
                  }
                  return null;
                },
              ),
              _buildTextField(
                'District',
                _districtController,
                hint: 'Enter district name',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter district';
                  }
                  return null;
                },
              ),
              _buildTextField(
                'Latitude',
                _latitudeController,
                hint: 'Enter latitude coordinates',
                isNumeric: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter latitude';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              _buildTextField(
                'Longitude',
                _longitudeController,
                hint: 'Enter longitude coordinates',
                isNumeric: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter longitude';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              

              SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.map),
                label: const Text('Pick on Map'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _openMapPicker,
              ),
            ),
            const SizedBox(height: 20),


              // Description Section
              _buildSectionHeader('Additional Information'),
              _buildTextField(
                'Description',
                _descriptionController,
                hint: 'Enter apiary description (optional)',
              ),
              const SizedBox(height: 32),

              // Submit Button
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[700],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'SAVE CHANGES',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: "Sans",
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.orange[700]?.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[700]!.withOpacity(0.3)),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.brown[800],
          fontFamily: "Sans",
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? hint,
    String? Function(String?)? validator,
    bool isNumeric = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontFamily: "Sans"),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.brown[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.brown[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.orange[700]!, width: 2),
          ),
          labelStyle: TextStyle(
            color: Colors.brown[600],
            fontFamily: "Sans",
          ),
        ),
        validator: validator,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });
    //Uri.parse('http://196.43.168.57/api/v1/farms/${widget.farmId}'),

    try {
      final response = await http.put(
      Uri.parse('http://196.43.168.57/api/v1/farms/{id}'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          
          'name': _nameController.text,
          'address': _addressController.text,
          'district': _districtController.text,
          'latitude': _latitudeController.text,
          'longitude': _longitudeController.text,
          'description': _descriptionController.text,
        }),
      );
  

    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');

      if (response.statusCode == 200) {
        // Success - show confirmation and return
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Apiary updated successfully!',
              style: TextStyle(fontFamily: "Sans"),
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context, true);
      } else if (response.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Apiary not found (ID: ${widget.farmId})',
              style: const TextStyle(fontFamily: "Sans"),
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update: ${response.statusCode}',
              style: const TextStyle(fontFamily: "Sans"),
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $error',
            style: const TextStyle(fontFamily: "Sans"),
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
    
  }
}

