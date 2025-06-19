import 'package:flutter/material.dart';

class RecordsForm extends StatefulWidget {
  final String apiaryLocation;
  final String hiveId;
  final String farmName;

  const RecordsForm({
    super.key,
    required this.apiaryLocation,
    required this.hiveId,
    required this.farmName,
  });

  @override
  State<RecordsForm> createState() => _RecordsFormState();
}

class _RecordsFormState extends State<RecordsForm> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0; // Added to manage current step
  final DateTime _inspectionDate = DateTime.now();

  // Controllers (same as before)
  final TextEditingController _beekeeperNameController =
      TextEditingController();
  final TextEditingController _weatherConditionsController =
      TextEditingController();
  final TextEditingController _apiaryLocationController =
      TextEditingController();
  final TextEditingController _hiveIdController = TextEditingController();
  final TextEditingController _hiveTypeController = TextEditingController();
  final TextEditingController _hiveConditionController =
      TextEditingController();
  final TextEditingController _queenPresenceController =
      TextEditingController();
  final TextEditingController _queenCellsController = TextEditingController();
  final TextEditingController _broodPatternController = TextEditingController();
  final TextEditingController _eggsLarvaeController = TextEditingController();
  final TextEditingController _honeyStoresController = TextEditingController();
  final TextEditingController _pollenStoresController = TextEditingController();
  final TextEditingController _beePopulationController =
      TextEditingController();
  final TextEditingController _aggressivenessController =
      TextEditingController();
  final TextEditingController _diseasesObservedController =
      TextEditingController();
  final TextEditingController _diseasesSpecifyController =
      TextEditingController();
  final TextEditingController _pestsPresentController = TextEditingController();
  final TextEditingController _framesCheckedController =
      TextEditingController();
  final TextEditingController _framesReplacedController =
      TextEditingController();
  final TextEditingController _hiveCleanedController = TextEditingController();
  final TextEditingController _supersChangedController =
      TextEditingController();
  final TextEditingController _otherActionsController = TextEditingController();
  final TextEditingController _commentsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _apiaryLocationController.text = widget.apiaryLocation;
    _hiveIdController.text = widget.hiveId;
  }

  @override
  void dispose() {
    // Dispose all controllers (same as before)
    _beekeeperNameController.dispose();
    _weatherConditionsController.dispose();
    _apiaryLocationController.dispose();
    _hiveIdController.dispose();
    _hiveTypeController.dispose();
    _hiveConditionController.dispose();
    _queenPresenceController.dispose();
    _queenCellsController.dispose();
    _broodPatternController.dispose();
    _eggsLarvaeController.dispose();
    _honeyStoresController.dispose();
    _pollenStoresController.dispose();
    _beePopulationController.dispose();
    _aggressivenessController.dispose();
    _diseasesObservedController.dispose();
    _diseasesSpecifyController.dispose();
    _pestsPresentController.dispose();
    _framesCheckedController.dispose();
    _framesReplacedController.dispose();
    _hiveCleanedController.dispose();
    _supersChangedController.dispose();
    _otherActionsController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  // List of section headers for the stepper
  final List<String> _sectionTitles = [
    'General Information',
    'Hive Information',
    'Colony Health',
    'Maintenance Actions',
    'Comments & Recommendations',
  ];

  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        if (_currentStep < _sectionTitles.length - 1) {
          _currentStep++;
        } else {
          _submitForm(); // This is the last step, so submit
        }
      });
    }
  }

  void _previousStep() {
    setState(() {
      if (_currentStep > 0) {
        _currentStep--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.brown[50],
      appBar: AppBar(
        title: Text(
          'Hive Inspection - ${widget.hiveId}',
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.orange[100]!.withOpacity(0.2),
              Colors.brown[50]!,
            ],
          ),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
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

                // Stepper (visual indicator of progress)
                _buildStepper(),
                const SizedBox(height: 20),

                // Form Sections based on _currentStep
                _buildCurrentFormSection(),

                const SizedBox(height: 32),

                // Navigation Buttons
                _buildNavigationButtons(),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepper() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_sectionTitles.length, (index) {
            bool isActive = index == _currentStep;
            return Expanded(
              child: Column(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.orange[700] : Colors.brown[200],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive ? Colors.orange[900]! : Colors.brown[300]!,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.brown[800],
                          fontWeight: FontWeight.bold,
                          fontFamily: "Sans",
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _sectionTitles[index].split(' ').first, // Show only first word
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: isActive ? Colors.orange[700] : Colors.brown[600],
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      fontFamily: "Sans",
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: (_currentStep + 1) / _sectionTitles.length,
          backgroundColor: Colors.brown[100],
          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange[700]!),
        ),
      ],
    );
  }


  Widget _buildCurrentFormSection() {
    switch (_currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('1. General Information'),
            _buildReadOnlyField(
                'Inspection Date', _formatDate(_inspectionDate)),
            _buildTextField('Beekeeper Name', _beekeeperNameController),
            _buildTextField(
                'Weather Conditions', _weatherConditionsController),
            _buildReadOnlyField(
                'Apiary Location', _apiaryLocationController.text),
            _buildReadOnlyField('Hive ID', _hiveIdController.text),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('2. Hive Information'),
            _buildTextField('Type of Hive', _hiveTypeController,
                hint: 'e.g., Langstroth, Top Bar'),
            _buildDropdownField('Hive Condition', _hiveConditionController,
                ['Good', 'Fair', 'Poor']),
            _buildYesNoField(
                'Presence of Queen?', _queenPresenceController),
            _buildYesNoField('Queen Cells Present?', _queenCellsController),
            _buildDropdownField('Brood Pattern', _broodPatternController,
                ['Good', 'Irregular', 'Spotty', 'None']),
            _buildYesNoField(
                'Eggs & Larvae Present?', _eggsLarvaeController),
            _buildDropdownField('Honey Stores', _honeyStoresController,
                ['Low', 'Medium', 'Full']),
            _buildDropdownField('Pollen Stores', _pollenStoresController,
                ['Low', 'Medium', 'Full']),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('3. Colony Health'),
            _buildDropdownField('Bee Population', _beePopulationController,
                ['Strong', 'Moderate', 'Weak']),
            _buildDropdownField('Aggressiveness', _aggressivenessController,
                ['Calm', 'Moderate', 'Aggressive']),
            _buildYesNoField(
                'Diseases or Pests Observed?', _diseasesObservedController),
            if (_diseasesObservedController.text == 'Yes')
              _buildTextField(
                  'Specify Diseases/Pests', _diseasesSpecifyController),
            _buildTextField('Other Pests Present', _pestsPresentController,
                hint: 'e.g., Varroa mites, Small Hive Beetles'),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('4. Maintenance Actions'),
            _buildNumberField('Frames Checked', _framesCheckedController),
            _buildYesNoField('Frames Replaced?', _framesReplacedController),
            _buildYesNoField('Hive Cleaned?', _hiveCleanedController),
            _buildYesNoField(
                'Supers Added/Removed?', _supersChangedController),
            _buildTextField('Other Actions Taken', _otherActionsController),
          ],
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('5. Comments & Recommendations'),
            _buildLargeTextField('General Comments', _commentsController),
          ],
        );
      default:
        return Container(); // Should not happen
    }
  }

  Widget _buildNavigationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: Colors.orange[700]!),
              ),
              onPressed: _previousStep,
              child: Text(
                'PREVIOUS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                  fontFamily: "Sans",
                ),
              ),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            onPressed: _nextStep,
            child: Text(
              _currentStep < _sectionTitles.length - 1 ? 'NEXT' : 'SUBMIT INSPECTION',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: "Sans",
              ),
            ),
          ),
        ),
      ],
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

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        initialValue: value,
        readOnly: true,
        style: const TextStyle(fontFamily: "Sans"),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.brown[100],
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
      ),
    );
  }

  Widget _buildDropdownField(
      String label, TextEditingController controller, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<String>(
        value: controller.text.isNotEmpty ? controller.text : null, // Set initial value if present
        style: TextStyle(
          fontFamily: "Sans",
          color: Colors.brown[800], // Set dropdown item text color
        ),
        decoration: InputDecoration(
          labelText: label,
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
        dropdownColor: Colors.white,
        items: items.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value, style: const TextStyle(fontFamily: "Sans")),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            controller.text = value ?? '';
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select $label';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildYesNoField(String label, TextEditingController controller) {
    return _buildDropdownField(label, controller, ['Yes', 'No']);
  }

  Widget _buildNumberField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontFamily: "Sans"),
        decoration: InputDecoration(
          labelText: label,
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
          if (int.tryParse(value) == null) {
            return 'Please enter a valid number';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildLargeTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        maxLines: 4,
        style: const TextStyle(fontFamily: "Sans"),
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: true,
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
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _showSubmissionDialog();
    }
  }

  void _showSubmissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Submit Inspection?',
          style: TextStyle(fontFamily: "Sans", fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to submit this hive inspection record?',
          style: TextStyle(fontFamily: "Sans"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                color: Colors.brown,
                fontFamily: "Sans",
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context); // Close the dialog
              _saveInspectionData();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Inspection submitted successfully!',
                    style: TextStyle(fontFamily: "Sans"),
                  ),
                  backgroundColor: Colors.green[700],
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
              // You might want to navigate back or clear the form here
              // For now, let's just pop the current screen
              // Navigator.pop(context);
            },
            child: const Text(
              'SUBMIT',
              style: TextStyle(
                fontFamily: "Sans",
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _saveInspectionData() {
    final inspectionData = {
      'date': _formatDate(_inspectionDate),
      'beekeeper': _beekeeperNameController.text,
      'location': _apiaryLocationController.text,
      'hiveId': _hiveIdController.text,
      'weatherConditions': _weatherConditionsController.text,
      'hiveType': _hiveTypeController.text,
      'hiveCondition': _hiveConditionController.text,
      'queenPresence': _queenPresenceController.text,
      'queenCells': _queenCellsController.text,
      'broodPattern': _broodPatternController.text,
      'eggsLarvae': _eggsLarvaeController.text,
      'honeyStores': _honeyStoresController.text,
      'pollenStores': _pollenStoresController.text,
      'beePopulation': _beePopulationController.text,
      'aggressiveness': _aggressivenessController.text,
      'diseasesObserved': _diseasesObservedController.text,
      'diseasesSpecify': _diseasesSpecifyController.text,
      'pestsPresent': _pestsPresentController.text,
      'framesChecked': _framesCheckedController.text,
      'framesReplaced': _framesReplacedController.text,
      'hiveCleaned': _hiveCleanedController.text,
      'supersChanged': _supersChangedController.text,
      'otherActions': _otherActionsController.text,
      'comments': _commentsController.text,
    };
    print('Inspection Data: $inspectionData');
    // In a real application, you would send this data to a backend or save it locally.
  }
}