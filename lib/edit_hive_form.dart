import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'Services/connectivity_service.dart';
import 'services/token_storage.dart';

class EditHiveForm extends StatefulWidget {
  final int hiveId;
  final int farmId;
  final String apiaryLocation;
  final String farmName;
  final String initialLatitude;
  final String initialLongitude;
  final bool initialConnected;
  final bool initialColonized;
  final VoidCallback onHiveUpdated;

  const EditHiveForm({
    super.key,
    required this.hiveId,
    required this.farmId,
    required this.apiaryLocation,
    required this.farmName,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.initialConnected,
    required this.initialColonized,
    required this.onHiveUpdated,
  });

  @override
  _EditHiveFormState createState() => _EditHiveFormState();
}

class _EditHiveFormState extends State<EditHiveForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _longitudeController;
  late final TextEditingController _latitudeController;
  late bool _isConnected;
  late bool _isColonized;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _longitudeController = TextEditingController(text: widget.initialLongitude);
    _latitudeController = TextEditingController(text: widget.initialLatitude);
    _isConnected = widget.initialConnected;
    _isColonized = widget.initialColonized;
  }

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
        title: Text(
          'Edit Hive ${widget.hiveId}',
          style: const TextStyle(
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Editing Hive ${widget.hiveId}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: "Sans",
                              ),
                            ),
                            Text(
                              '${widget.farmName} - ${widget.apiaryLocation}',
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
              const SizedBox(height: 32),

              // Hive Status Section
              _buildSectionHeader('Hive Status'),

              _buildSwitchField(
                'Connected to Network',
                _isConnected,
                (val) => setState(() => _isConnected = val),
              ),
              _buildSwitchField(
                'Colonized',
                _isColonized,
                (val) => setState(() => _isColonized = val),
              ),
              const SizedBox(height: 20),

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
                    onPressed: _isLoading ? null : _submitForm,
                    child:
                        _isLoading
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text(
                              'UPDATE HIVE',
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
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.orange[700]!, width: 2),
          ),
          labelStyle: TextStyle(color: Colors.brown[600], fontFamily: "Sans"),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildSwitchField(String label, bool value, Function(bool) onChanged) {
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
    if (!_formKey.currentState!.validate()) return;

    // Check connectivity before submitting
    final isConnected = await ConnectivityService().hasInternetConnection();
    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No internet connection. Please check your network and try again.',
            style: TextStyle(fontFamily: "Sans"),
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updateData = {
        'longitude': _longitudeController.text,
        'latitude': _latitudeController.text,
        'connected': _isConnected,
        'colonized': _isColonized,
      };

      final token = await TokenStorage.getToken();

      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication error. Please log in again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final url = 'http://196.43.168.57/api/v1/hives/${widget.hiveId}';
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Hive updated successfully!',
              style: TextStyle(fontFamily: "Sans"),
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        widget.onHiveUpdated();
        Navigator.pop(context);
      } else {
        throw Exception('Status code: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
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
