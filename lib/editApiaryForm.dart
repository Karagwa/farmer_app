import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'farm_model.dart';

class EditApiaryForm extends StatefulWidget {
  final String token;
  final Farm farm; // Use the Farm model
  final VoidCallback onApiaryUpdated;

  const EditApiaryForm({
    super.key,
    required this.token,
    required this.farm,
    required this.onApiaryUpdated,
  });

  @override
  State<EditApiaryForm> createState() => _EditApiaryFormState();
}

class _EditApiaryFormState extends State<EditApiaryForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _districtController;
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.farm.name);
    _districtController = TextEditingController(text: widget.farm.district);
    _addressController = TextEditingController(text: widget.farm.address);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _districtController.dispose();
    _addressController.dispose();
    super.dispose();
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
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Apiary Information'),
              _buildTextField('Name', _nameController, hint: 'Apiary name'),
              _buildTextField('District', _districtController, hint: 'District'),
              _buildTextField('Address', _addressController, hint: 'Detailed address'),
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
                    onPressed: _submitForm,
                    child: const Text(
                      'UPDATE APIARY',
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
      {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
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
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        final apiaryData = {
          'name': _nameController.text,
          'district': _districtController.text,
          'address': _addressController.text,
        };

        print('Farm ID: ${widget.farm.id}'); // Corrected to use widget.farm.id
        print('Payload: ${jsonEncode(apiaryData)}'); // Debugging: Log the payload

        final response = await http.put(
          Uri.parse('http://196.43.168.57/api/v1/farms/${widget.farm.id}'), // Corrected to use widget.farm.id
          headers: {
            'Authorization': 'Bearer ${widget.token}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(apiaryData),
        );

        print('Response: ${response.body}'); // Debugging: Log the response body

        if (response.statusCode == 200) {
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
          widget.onApiaryUpdated();
          Navigator.pop(context);
        } else if (response.statusCode == 404) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Farm not found. Please check the ID.',
                style: TextStyle(fontFamily: "Sans"),
              ),
              backgroundColor: Colors.red[700],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to update farm: ${response.statusCode}',
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