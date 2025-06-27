import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class AddTroupePage extends StatefulWidget {
  final String? parentTroupeId;
  final String? parentTroupeName;
  final String? troupeToEditId; // NEW: ID of the troupe being edited
  final String? initialName; // NEW: Initial name for editing
  final String? initialDescription; // NEW: Initial description for editing
  final int? initialOrder; // NEW: Initial order for editing

  const AddTroupePage({
    super.key,
    this.parentTroupeId,
    this.parentTroupeName,
    this.troupeToEditId, // Initialize new parameters
    this.initialName,
    this.initialDescription,
    this.initialOrder,
  });

  @override
  State<AddTroupePage> createState() => _AddTroupePageState();
}

class _AddTroupePageState extends State<AddTroupePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _orderController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with initial values if provided (for editing)
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _descriptionController = TextEditingController(text: widget.initialDescription ?? '');
    _orderController = TextEditingController(text: widget.initialOrder?.toString() ?? '');

    // If troupeToEditId is provided, and initial data is not, fetch it.
    // This handles cases where initial data might not be fully passed from the calling screen.
    // However, for consistency, it's better to pass all initial data from `TroupesPage`.
    if (widget.troupeToEditId != null && widget.initialName == null) {
      _loadTroupeDataForEdit();
    }
  }

  // NEW: Function to load existing troupe data for editing if not passed in
  Future<void> _loadTroupeDataForEdit() async {
    if (widget.troupeToEditId == null) return;

    setState(() { _isLoading = true; });

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('troupes').doc(widget.troupeToEditId).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          _nameController.text = data['name'] ?? '';
          _descriptionController.text = data['description'] ?? '';
          _orderController.text = (data['order'] ?? 0).toString();
        });
        debugPrint('AddTroupePage: Loaded data for editing troupe ID: ${widget.troupeToEditId}');
      } else {
        _showSnackBar('Troupe not found for editing.');
        debugPrint('AddTroupePage Error: Troupe ${widget.troupeToEditId} not found for editing.');
      }
    } catch (e) {
      _showSnackBar('Failed to load troupe data for editing: $e');
      debugPrint('AddTroupePage Error: Failed to load troupe data for editing: $e');
    } finally {
      setState(() { _isLoading = false; });
    }
  }

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
        _showSnackBar('You must be logged in to add/edit a troupe.');
        debugPrint('AddTroupe: No user logged in.');
        setState(() { _isLoading = false; });
        return;
      }

      try {
        final Map<String, dynamic> troupeData = {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'order': int.tryParse(_orderController.text.trim()) ?? 0, // Default to 0 if invalid
        };

        if (widget.troupeToEditId == null) {
          // This is an ADD operation
          debugPrint('AddTroupe: Attempting to add new troupe to Firestore.');
          troupeData['isParentTroupe'] = widget.parentTroupeId == null; // True if no parent ID is provided
          troupeData['parentTroupeId'] = widget.parentTroupeId; // Null if it's a parent troupe
          troupeData['createdAt'] = FieldValue.serverTimestamp();
          troupeData['createdBy'] = currentUser.uid;

          await FirebaseFirestore.instance.collection('troupes').add(troupeData);
          _showSnackBar('Troupe added successfully!');
          debugPrint('AddTroupe: Troupe saved successfully. Navigating back.');
        } else {
          // This is an EDIT (UPDATE) operation
          debugPrint('AddTroupe: Attempting to update troupe ID: ${widget.troupeToEditId}');
          troupeData['updatedAt'] = FieldValue.serverTimestamp(); // Add an updatedAt field
          troupeData['updatedBy'] = currentUser.uid; // Track who updated it

          await FirebaseFirestore.instance.collection('troupes').doc(widget.troupeToEditId).update(troupeData);
          _showSnackBar('Troupe updated successfully!');
          debugPrint('AddTroupe: Troupe updated successfully. Navigating back.');
        }

        if (mounted) {
          Navigator.pop(context); // Go back to the previous screen
        }
      } catch (e) {
        _showSnackBar('Failed to save troupe: $e');
        debugPrint('AddTroupe Error: Failed to save troupe: $e');
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

    final String pageTitle;
    final String descriptionText;
    final String buttonText;
    final String nameLabel;
    final String nameHint;

    if (widget.troupeToEditId != null) {
      pageTitle = 'Edit Troupe';
      descriptionText = 'Modify the details of this troupe.';
      buttonText = 'Save Changes';
      nameLabel = 'Troupe Name';
      nameHint = 'e.g., Competition Team';
    } else if (widget.parentTroupeId == null) {
      pageTitle = 'Add New Troupe';
      descriptionText = 'Enter details for a new top-level troupe.';
      buttonText = 'Add Troupe';
      nameLabel = 'Troupe Name';
      nameHint = 'e.g., Competition Team';
    } else {
      pageTitle = 'Add Sub-Troupe to ${widget.parentTroupeName}';
      descriptionText = 'Enter details for a new sub-troupe under "${widget.parentTroupeName}".';
      buttonText = 'Add Sub-Troupe';
      nameLabel = 'Sub-Troupe Name';
      nameHint = 'e.g., Tiny Team';
    }

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
                  labelText: nameLabel,
                  hintText: nameHint,
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
                  child: Text(buttonText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
