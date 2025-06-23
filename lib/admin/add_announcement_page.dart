import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:cloud_functions/cloud_functions.dart'; // Import for Firebase Cloud Functions
import 'troupe_selection_page.dart'; // UPDATED: Corrected import path (now in the same 'admin' directory)

class AddAnnouncementPage extends StatefulWidget {
  const AddAnnouncementPage({super.key});

  @override
  State<AddAnnouncementPage> createState() => _AddAnnouncementPageState();
}

class _AddAnnouncementPageState extends State<AddAnnouncementPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _isLoading = false;

  String? _selectedParentTroupeId;
  String? _selectedParentTroupeName;
  String? _selectedSubTroupeId;
  String? _selectedSubTroupeName;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _selectTroupe() async {
    debugPrint('AddAnnouncementPage: Navigating to TroupeSelectionPage for selection.');
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TroupeSelectionPage(),
      ),
    );

    if (result != null && result is Map<String, String?>) {
      setState(() {
        _selectedParentTroupeId = result['parentTroupeId'];
        _selectedParentTroupeName = result['parentTroupeName'];
        _selectedSubTroupeId = result['subTroupeId'];
        _selectedSubTroupeName = result['subTroupeName'];
        debugPrint('AddAnnouncementPage: Selected Parent: $_selectedParentTroupeName (ID: $_selectedParentTroupeId)');
        debugPrint('AddAnnouncementPage: Selected Sub: $_selectedSubTroupeName (ID: $_selectedSubTroupeId)');
      });
    }
  }

  void _clearTroupeSelection() {
    setState(() {
      _selectedParentTroupeId = null;
      _selectedParentTroupeName = null;
      _selectedSubTroupeId = null;
      _selectedSubTroupeName = null;
      debugPrint('AddAnnouncementPage: Cleared all troupe selections.');
    });
    _showSnackBar('Troupe selection cleared. Announcement will be posted globally.');
  }

  Future<void> _submitAnnouncement() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showSnackBar('You must be logged in to add an announcement.');
        debugPrint('AddAnnouncementPage: No user logged in for announcement creation.');
        setState(() { _isLoading = false; });
        return;
      }

      try {
        debugPrint('AddAnnouncementPage: Attempting to add announcement via Cloud Function...');
        
        final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('addAnnouncement');
        
        // Prepare payload based on selections
        final Map<String, dynamic> payload = {
          'title': _titleController.text.trim(),
          'content': _contentController.text.trim(),
        };

        if (_selectedParentTroupeId != null) {
          payload['parentTroupeId'] = _selectedParentTroupeId;
          payload['parentTroupeName'] = _selectedParentTroupeName;
        }
        if (_selectedSubTroupeId != null) {
          payload['subTroupeId'] = _selectedSubTroupeId;
          payload['subTroupeName'] = _selectedSubTroupeName;
        }

        await callable.call(payload);

        _showSnackBar('Announcement added successfully!');
        debugPrint('AddAnnouncementPage: Announcement saved successfully via Cloud Function. Navigating back.');
        if (mounted) {
          Navigator.pop(context); // Go back to the previous screen (DevToolsScreen)
        }
      } on FirebaseFunctionsException catch (e) {
        _showSnackBar('Failed to add announcement: ${e.message}');
        debugPrint('AddAnnouncementPage FirebaseFunctions Error: ${e.code} - ${e.message}');
      } catch (e) {
        _showSnackBar('An unexpected error occurred: $e');
        debugPrint('AddAnnouncementPage General Error: Failed to add announcement: $e');
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Announcement'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create a new announcement. Select the target troupe(s) or leave blank to post to the main dashboard.',
                style: TextStyle(fontSize: 16, color: textOnBackground),
              ),
              const SizedBox(height: 20),
              // Troupe Selection Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Target Audience:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_selectedParentTroupeName == null && _selectedSubTroupeName == null)
                        Text(
                          'Currently: Global (Dashboard Announcements)',
                          style: TextStyle(fontSize: 14, color: textOnBackground.withOpacity(0.8)),
                        )
                      else if (_selectedSubTroupeName != null)
                        Text(
                          'Currently: ${_selectedParentTroupeName ?? "Selected Parent"} > $_selectedSubTroupeName',
                          style: TextStyle(fontSize: 14, color: textOnBackground.withOpacity(0.8)),
                        )
                      else if (_selectedParentTroupeName != null)
                        Text(
                          'Currently: $_selectedParentTroupeName (Parent Troupe Only)',
                          style: TextStyle(fontSize: 14, color: textOnBackground.withOpacity(0.8)),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _selectTroupe,
                              icon: const Icon(Icons.group_add),
                              label: const Text('Select Troupe(s)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                          if (_selectedParentTroupeId != null || _selectedSubTroupeId != null) ...[
                            const SizedBox(width: 10),
                            IconButton(
                              onPressed: _clearTroupeSelection,
                              icon: Icon(Icons.clear, color: primaryColor),
                              tooltip: 'Clear selection',
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Announcement Content Section
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Announcement Title',
                  hintText: 'e.g., Important Update',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Announcement Content',
                  hintText: 'Type your message here...',
                  alignLabelWithHint: true,
                ),
                maxLines: 8,
                minLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Announcement content cannot be empty.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? Center(child: CircularProgressIndicator(color: primaryColor))
                  : Center(
                      child: ElevatedButton(
                        onPressed: _submitAnnouncement,
                        child: const Text('Publish Announcement'),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
