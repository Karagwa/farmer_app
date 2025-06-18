import 'package:flutter/material.dart';

class EditForm extends StatefulWidget {
  final Map<String, String> apiary;
  final int index;
  final Function(int, Map<String, String>) onSave;

  const EditForm({
    super.key,
    required this.apiary,
    required this.index,
    required this.onSave,
  });

  @override
  State<EditForm> createState() => _EditFormState();
}

class _EditFormState extends State<EditForm> {
  late TextEditingController _nameController;
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.apiary['name']);
    _addressController = TextEditingController(text: widget.apiary['address']);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _submit() {
    final updatedApiary = {
      ...widget.apiary,
      'name': _nameController.text,
      'address': _addressController.text,
    };
    widget.onSave(widget.index, updatedApiary);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Apiary'),
        backgroundColor: Colors.orange[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
              ),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
