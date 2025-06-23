import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class AddPostPage extends StatefulWidget {
  final String troupeId;
  final String troupeName;

  const AddPostPage({
    super.key,
    required this.troupeId,
    required this.troupeName,
  });

  @override
  State<AddPostPage> createState() => _AddPostPageState();
}

class _AddPostPageState extends State<AddPostPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _contentController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showSnackBar('You must be logged in to create a post.');
        debugPrint('AddPostPage: No user logged in for post creation.');
        setState(() { _isLoading = false; });
        return;
      }

      try {
        debugPrint('AddPostPage: Attempting to save post to Firestore for troupe: ${widget.troupeName}');
        await FirebaseFirestore.instance.collection('posts').add({
          'troupeId': widget.troupeId,
          'content': _contentController.text.trim(),
          'createdBy': currentUser.uid,
          'createdByEmail': currentUser.email, // Store email for display
          'createdAt': FieldValue.serverTimestamp(),
          'commentCount': 0, // Initialize comment count
          'viewCount': 0,    // Initialize view count
          'reactions': {     // Initialize reaction counts
            'thumbsUp': 0,
            'heart': 0,
          },
          // You might add an array for users who have reacted to prevent multiple reactions
          // 'reactedBy': [],
        });

        _showSnackBar('Post added successfully!');
        debugPrint('AddPostPage: Post saved successfully. Navigating back.');
        if (mounted) {
          Navigator.pop(context); // Go back to the previous screen (TroupeContentPage)
        }
      } catch (e) {
        _showSnackBar('Failed to add post: $e');
        debugPrint('AddPostPage Error: Failed to add post: $e');
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
        title: Text('Add Post to ${widget.troupeName}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create a new post for your troupe. This post will be visible to all members of ${widget.troupeName}.',
                style: TextStyle(fontSize: 16, color: textOnBackground),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Post Content',
                  hintText: 'Share an update, announcement, or message...',
                  alignLabelWithHint: true, // Align label to top for multiline input
                ),
                maxLines: 8, // Allow for longer content
                minLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Post content cannot be empty.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? Center(child: CircularProgressIndicator(color: primaryColor))
                  : Center(
                      child: ElevatedButton(
                        onPressed: _submitPost,
                        child: const Text('Publish Post'),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
