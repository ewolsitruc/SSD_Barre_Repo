import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AddPostPage extends StatefulWidget {
  final List<String>? allowedTroupeIds; // Optional for non-admins
  final String? initialTroupeId;
  final String? initialTroupeName;

  const AddPostPage({
    super.key,
    this.allowedTroupeIds,
    this.initialTroupeId,
    this.initialTroupeName,
  });

  @override
  State<AddPostPage> createState() => _AddPostPageState();
}

class _AddPostPageState extends State<AddPostPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _contentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _currentUser;
  bool _isLoading = false;
  bool _isLoadingTroupes = true;

  String? _selectedTroupeId;
  String? _selectedTroupeName;

  List<Map<String, dynamic>> _availableTroupes = [];

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _loadTroupes();
  }

  Future<void> _loadTroupes() async {
    setState(() => _isLoadingTroupes = true);
    try {
      QuerySnapshot troupeSnapshot;
      if (widget.allowedTroupeIds != null) {
        // Filter troupes based on allowed IDs
        if (widget.allowedTroupeIds!.isEmpty) {
          _showSnackBar("You are not assigned to any troupes.");
          setState(() => _isLoadingTroupes = false);
          return;
        }
        troupeSnapshot = await _firestore
            .collection('troupes')
            .where(FieldPath.documentId, whereIn: widget.allowedTroupeIds)
            .get();
      } else {
        // Admin access to all troupes
        troupeSnapshot = await _firestore.collection('troupes').get();
      }

      _availableTroupes = troupeSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unnamed',
          'isParent': data['isParentTroupe'] ?? false,
          'parentTroupeId': data['parentTroupeId'],
        };
      }).toList();

      // If initial troupe is provided
      if (widget.initialTroupeId != null && widget.initialTroupeName != null) {
        _selectedTroupeId = widget.initialTroupeId;
        _selectedTroupeName = widget.initialTroupeName;
      }

    } catch (e) {
      _showSnackBar('Error loading troupe data: $e');
      debugPrint('AddPostPage Error: $e');
    } finally {
      setState(() => _isLoadingTroupes = false);
    }
  }

  void _showTroupeSelectionDialog() {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textOnBackground = Theme.of(context).colorScheme.onBackground;

    _availableTroupes.sort((a, b) {
      if (a['isParent'] && !b['isParent']) return -1;
      if (!a['isParent'] && b['isParent']) return 1;
      return a['name'].compareTo(b['name']);
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Troupe', style: TextStyle(color: primaryColor)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _availableTroupes.length,
            itemBuilder: (context, index) {
              final troupe = _availableTroupes[index];
              String label = troupe['name'];
              if (!troupe['isParent']) {
                label += ' (Sub-Troupe)';
              }
              return ListTile(
                title: Text(label, style: TextStyle(color: textOnBackground)),
                trailing: _selectedTroupeId == troupe['id']
                    ? Icon(Icons.check, color: primaryColor)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedTroupeId = troupe['id'];
                    _selectedTroupeName = troupe['name'];
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: primaryColor)),
          )
        ],
      ),
    );
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTroupeId == null) {
      _showSnackBar("Please select a troupe to post to.");
      return;
    }

    if (_currentUser == null) {
      _showSnackBar("You must be logged in.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _firestore.collection('posts').add({
        'troupeId': _selectedTroupeId,
        'content': _contentController.text.trim(),
        'createdBy': _currentUser!.uid,
        'createdByEmail': _currentUser!.email,
        'createdAt': FieldValue.serverTimestamp(),
        'commentCount': 0,
        'viewCount': 0,
        'reactions': {'thumbsUp': 0, 'heart': 0},
        'reactedBy': [],
      });

      _showSnackBar("Post added successfully!");
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnackBar("Failed to add post: $e");
      debugPrint('AddPostPage Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearTroupeSelection() {
    setState(() {
      _selectedTroupeId = null;
      _selectedTroupeName = null;
    });
    _showSnackBar('Troupe selection cleared.');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textOnBackground = Theme.of(context).colorScheme.onBackground;

    return Scaffold(
      appBar: AppBar(title: const Text('Add New Post')),
      body: _isLoadingTroupes
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create a new post for your troupe.',
                style: TextStyle(fontSize: 16, color: textOnBackground),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Post to Troupe:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                      const SizedBox(height: 10),
                      Text(
                        _selectedTroupeName ?? 'No troupe selected.',
                        style: TextStyle(fontSize: 14, color: textOnBackground.withOpacity(0.8)),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.group_add),
                              label: const Text('Select Troupe'),
                              onPressed: _showTroupeSelectionDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                          if (_selectedTroupeId != null) ...[
                            const SizedBox(width: 10),
                            IconButton(
                              onPressed: _clearTroupeSelection,
                              icon: Icon(Icons.clear, color: primaryColor),
                              tooltip: 'Clear selection',
                            )
                          ]
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _contentController,
                maxLines: 8,
                minLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Post Content',
                  hintText: 'Type your announcement...',
                  alignLabelWithHint: true,
                ),
                validator: (value) =>
                value == null || value.isEmpty ? 'Post content cannot be empty.' : null,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? Center(child: CircularProgressIndicator(color: primaryColor))
                  : Center(
                child: ElevatedButton(
                  onPressed: _submitPost,
                  child: const Text('Publish Post'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
