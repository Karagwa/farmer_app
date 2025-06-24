import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _ownerIdController = TextEditingController(text: widget.initialData['OwnerId']);
    _nameController = TextEditingController(text: widget.initialData['name']);
    _addressController = TextEditingController(text: widget.initialData['address']);
    _districtController = TextEditingController(text: widget.initialData['district']);
   
  }

  Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    final response = await http.put(
      Uri.parse('http://196.43.168.57/api/v1/farms/'),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'OwnerId': _ownerIdController.text,
        'name': _nameController.text,
        'address': _addressController.text,
        'district': _districtController.text,
      }),
    );

    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');

    if (response.statusCode == 200) {
      Navigator.pop(context, true); // Success
    } else if (response.statusCode == 404) {
      setState(() {
        _errorMessage = 'Apiary not found (ID: ${widget.farmId})';
      });
    } else {
      setState(() {
        _errorMessage =
            'Failed to update. Server responded with status: ${response.statusCode}';
      });
    }
  } catch (e) {
    setState(() {
      _errorMessage = 'Failed to update: ${e.toString()}';
    });
  } finally {
    setState(() => _isLoading = false);
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Apiary'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      body: _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 18, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _ownerIdController,
                      decoration: const InputDecoration(labelText: 'OwnerId*'),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Required field' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Name*'),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Required field' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: 'Address*'),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Required field' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _districtController,
                      decoration: const InputDecoration(labelText: 'District*'),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Required field' : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Save Changes'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}