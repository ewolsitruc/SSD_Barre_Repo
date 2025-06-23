import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class AddTroupePage extends StatefulWidget {
  final String? parentTroupeId;
  final String? parentTroupeName;

  const AddTroupePage({
    super.key,
    this.parentTroupeId,
    this.parentTroupeName,
  });

  @override
  State<AddTroupePage> createState() => _AddTroupePageState();
}

class _AddTroupePageState extends State<AddTroupePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _orderController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  Future<void> _submitTroupe() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showSnackBar('You must be logged in to add a troupe.');
        debugPrint('AddTroupe: No user logged in.');
        setState(() { _isLoading = false; });
        return;
      }

      try {
        debugPrint('AddTroupe: Attempting to save troupe to Firestore.');
        await FirebaseFirestore.instance.collection('troupes').add({
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'order': int.tryParse(_orderController.text.trim()) ?? 0, // Default to 0 if invalid
          'isParentTroupe': widget.parentTroupeId == null, // True if no parent ID is provided
          'parentTroupeId': widget.parentTroupeId, // Null if it's a parent troupe
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': currentUser.uid,
        });

        _showSnackBar('Troupe added successfully!');
        debugPrint('AddTroupe: Troupe saved successfully. Navigating back.');
        if (mounted) {
          Navigator.pop(context); // Go back to the previous screen
        }
      } catch (e) {
        _showSnackBar('Failed to add troupe: $e');
        debugPrint('AddTroupe Error: Failed to add troupe: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textOnBackground = Theme.of(context).colorScheme.onBackground;

    final String pageTitle = widget.parentTroupeId == null
        ? 'Add New Troupe'
        : 'Add Sub-Troupe to ${widget.parentTroupeName}';

    final String descriptionText = widget.parentTroupeId == null
        ? 'Enter details for a new top-level troupe.'
        : 'Enter details for a new sub-troupe under "${widget.parentTroupeName}".';

    return Scaffold(
      appBar: AppBar(
        title: Text(pageTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                descriptionText,
                style: TextStyle(fontSize: 16, color: textOnBackground),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: widget.parentTroupeId == null ? 'Troupe Name' : 'Sub-Troupe Name',
                  hintText: widget.parentTroupeId == null ? 'e.g., Competition Team' : 'e.g., Tiny Team',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Brief description of the troupe...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _orderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Order (for display)',
                  hintText: 'e.g., 1, 2, 3 (lower numbers appear first)',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an order number.';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? Center(child: CircularProgressIndicator(color: primaryColor))
                  : Center(
                      child: ElevatedButton(
                        onPressed: _submitTroupe,
                        child: Text(widget.parentTroupeId == null ? 'Add Troupe' : 'Add Sub-Troupe'),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
