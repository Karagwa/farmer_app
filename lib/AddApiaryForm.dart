import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:HPGM/Services/auth_services.dart';
import 'package:HPGM/Services/connectivity_service.dart';

class AddApiaryForm extends StatefulWidget {
  final String token;
  final VoidCallback onApiaryAdded;

  const AddApiaryForm({
    super.key,
    required this.token,
    required this.onApiaryAdded,
  });

  @override
  State<AddApiaryForm> createState() => _AddApiaryFormState();
}

class _AddApiaryFormState extends State<AddApiaryForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _ownerIdController = TextEditingController(); 
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _latitudeController =TextEditingController();
  final TextEditingController _longitudeController =TextEditingController();
  final TextEditingController _descriptionController =TextEditingController();
  
  bool _isLoading = false;

  @override
  void dispose() {
    _ownerIdController.dispose();
    _nameController.dispose();
    _districtController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.brown[100],
      appBar: AppBar(
        title: const Text('Add New Apiary',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: "Sans",
                color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.orange[700],
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Basic Information'),
              
              _buildTextField('Name', _nameController, hint: 'Apiary name'),
              const SizedBox(height: 20),
              
              _buildSectionHeader('Location Details'),
              _buildTextField('District', _districtController, hint: 'District'),
              _buildTextField('Address', _addressController, hint: 'Detailed address'),
              _buildTextField('Latitude', _latitudeController, hint: 'Latitude coordinates', isNumeric: true),
              _buildTextField('Longitude', _longitudeController, hint: 'Longitude coordinates', isNumeric: true),
              const SizedBox(height: 20),
              
              _buildSectionHeader('Additional Information'),
              _buildTextField('Description', _descriptionController, hint: 'Description (optional)', isRequired: false),
              const SizedBox(height: 30),
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
                            'ADD APIARY',
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

  Widget _buildTextField(String label, TextEditingController controller,
      {String? hint, bool isNumeric = false, bool isRequired = true}) {
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
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return 'Please enter $label';
          }
          if (isNumeric && value != null && value.isNotEmpty) {
            if (double.tryParse(value) == null) {
              return 'Please enter a valid number';
            }
          }
          return null;
        },
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

  setState(() {
    _isLoading = true;
  });
  
  try {
      final currentUserId = AuthService.getUserId();
    
    if (currentUserId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Error: User not properly authenticated',
            style: TextStyle(fontFamily: "Sans"),
          ),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }
      final apiaryData = {
        'ownerId': currentUserId,
        'name': _nameController.text.trim(),
        'district': _districtController.text.trim(),
        'address': _addressController.text.trim(),
        'latitude': _latitudeController.text.trim(),
        'longitude':_longitudeController.text.trim(),
        'description':_descriptionController.text.trim(),
      };

      // Add debug prints
      print('Sending data: $apiaryData');
      
      //print('Endpoint: https://ce6faf404c9b.ngrok-free.app/api/v1/farms');

      final response = await http.post(
        Uri.parse('http://196.43.168.57/api/v1/farms'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
          'Accept': 'application/json', // Add this line
        },
        body: jsonEncode(apiaryData),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        // Success - show confirmation and navigate back
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Apiary added successfully!',
              style: TextStyle(fontFamily: "Sans"),
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        widget.onApiaryAdded();
        print('Apiary added successfully with owner id ' );
        Navigator.pop(context);

      } else {
        // Better error handling
        String errorMsg;
        try {
          final errorBody = jsonDecode(response.body);
          errorMsg = errorBody['message'] ?? 'Failed with status ${response.statusCode}';
        } catch (_) {
          errorMsg = 'Failed with status ${response.statusCode}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $errorMsg',
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
    } catch (e) {
      print('Error: $e');
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
