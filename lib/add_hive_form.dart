import 'dart:convert';

import 'package:flutter/material.dart';
import 'hives.dart';
import 'package:http/http.dart' as http;

class AddHiveForm extends StatefulWidget {
  final int farmId;
  final String token;
  final String apiaryLocation;
  final String farmName;
  final VoidCallback onHiveAdded;

  const AddHiveForm({
    super.key,
    required this.farmId,
    required this.token,
    required this.apiaryLocation,
    required this.farmName,
    required this.onHiveAdded,
  });

  @override
  // ignore: library_private_types_in_public_api
  _AddHiveFormState createState() => _AddHiveFormState();
}

class _AddHiveFormState extends State<AddHiveForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  bool _isConnected = true;
  bool _isColonized = true;

  @override
  void dispose() {
    _longitudeController.dispose();
    _latitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.brown[100],
      appBar: AppBar(
        title: const Text(
          'Add New Hive',
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
              // Farm Info Card
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
                      Icon(Icons.hive, color: Colors.orange[700], size: 24),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.farmName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily: "Sans",
                            ),
                          ),
                          Text(
                            widget.apiaryLocation,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontFamily: "Sans",
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Location Section
              _buildSectionHeader('Hive Location'),
              _buildTextField(
                'Longitude',
                _longitudeController,
                hint: 'Enter longitude coordinates',
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
              _buildTextField(
                'Latitude',
                _latitudeController,
                hint: 'Enter latitude coordinates',
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
              const SizedBox(height: 20),

              // Status Section
              _buildSectionHeader('Initial Status'),
              _buildSwitchField(
                'Connected to Network',
                _isConnected,
                (value) => setState(() => _isConnected = value),
              ),
              _buildSwitchField(
                'Colonized',
                _isColonized,
                (value) => setState(() => _isColonized = value),
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
                    onPressed: _submitForm,
                    child: const Text(
                      'ADD HIVE',
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
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
          labelStyle: TextStyle(
            color: Colors.brown[600],
            fontFamily: "Sans",
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildSwitchField(
    String label,
    bool value,
    Function(bool) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.brown,
              fontWeight: FontWeight.w500,
              fontFamily: "Sans",
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.orange[700],
            activeTrackColor: Colors.orange[200],
          ),
        ],
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Prepare the hive data
        final hiveData = {
          'longitude': _longitudeController.text,
          'latitude': _latitudeController.text,
          'farm_id': widget.farmId,
          'state': {
            'connection_status': {'Connected': _isConnected},
            'colonization_status': {'Colonized': _isColonized},
            'weight': {
              'record': 0.0,
              'honey_percentage': 0.0,
            },
            'temperature': {
              'interior_temperature': 0.0,
            },
          },
        };

        // Send the request to your API
        String sendToken = "Bearer ${widget.token}";
        
        var headers = {
          'Authorization': sendToken,
          'Content-Type': 'application/json',
        };

        var url = 'http://196.43.168.57/api/v1/farms/${widget.farmId}/hives';
        var response = await http.post(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(hiveData),
        );

        if (response.statusCode == 201) {
          // Success - show confirmation and return
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Hive added successfully!',
                style: TextStyle(fontFamily: "Sans"),
              ),
              backgroundColor: Colors.green[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          widget.onHiveAdded();
          Navigator.pop(context);
        } else {
          // Handle API error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to add hive: ${response.statusCode}',
                style: const TextStyle(fontFamily: "Sans"),
              ),
              backgroundColor: Colors.red[700],
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
          ),
        );
      }
    }
  }
}