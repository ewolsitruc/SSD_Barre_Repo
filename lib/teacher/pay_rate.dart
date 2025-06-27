import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class PayRatePage extends StatefulWidget {
  final String teacherUid;

  const PayRatePage({super.key, required this.teacherUid});

  @override
  State<PayRatePage> createState() => _PayRatePageState();
}

class _PayRatePageState extends State<PayRatePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _classRateController = TextEditingController();
  final TextEditingController _adminRateController = TextEditingController();
  final TextEditingController _flatRateController = TextEditingController();
  final TextEditingController _gasReimbursementController = TextEditingController();

  bool _isLoading = true;

  DocumentReference get _rateRef =>
      _firestore.collection('payRates').doc(widget.teacherUid);

  @override
  void initState() {
    super.initState();
    _loadPayRates();
  }

  Future<void> _loadPayRates() async {
    try {
      final doc = await _rateRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _classRateController.text = data['classRatePerHour']?.toString() ?? '';
        _adminRateController.text = data['adminRatePerHour']?.toString() ?? '';
        _flatRateController.text = data['flatRatePerClass']?.toString() ?? '';
        _gasReimbursementController.text = data['gasReimbursement']?.toString() ?? '';
      }
    } catch (e) {
      debugPrint('PayRatePage: Error loading rates: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveRates() async {
    try {
      final double? classRate = double.tryParse(_classRateController.text);
      final double? adminRate = double.tryParse(_adminRateController.text);
      final double? flatRate = double.tryParse(_flatRateController.text);
      final double? gasRate = double.tryParse(_gasReimbursementController.text);

      if (classRate == null ||
          adminRate == null ||
          flatRate == null ||
          gasRate == null) {
        _showSnackBar('Please enter valid numbers for all fields.');
        return;
      }

      await _rateRef.set({
        'classRatePerHour': classRate,
        'adminRatePerHour': adminRate,
        'flatRatePerClass': flatRate,
        'gasReimbursement': gasRate,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _showSnackBar('Rates updated successfully!');
    } catch (e) {
      debugPrint('PayRatePage: Error saving rates: $e');
      _showSnackBar('Failed to save rates.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay Rates'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildField('Class Rate (per hour)', _classRateController),
            _buildField('Admin Rate (per hour)', _adminRateController),
            _buildField('Flat Rate (per class)', _flatRateController),
            _buildField('Gas Reimbursement', _gasReimbursementController),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _saveRates,
              icon: const Icon(Icons.save),
              label: const Text('Save Rates'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _classRateController.dispose();
    _adminRateController.dispose();
    _flatRateController.dispose();
    _gasReimbursementController.dispose();
    super.dispose();
  }
}
