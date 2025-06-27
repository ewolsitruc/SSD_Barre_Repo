import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class EditPostPage extends StatefulWidget {
  final String postId;
  final String initialContent;

  const EditPostPage({
    super.key,
    required this.postId,
    required this.initialContent,
  });

  @override
  State<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _contentController; // Use late for initialization in initState
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _updatePost() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showSnackBar('You must be logged in to edit a post.');
        debugPrint('EditPostPage: No user logged in for post editing.');
        setState(() { _isLoading = false; });
        return;
      }

      try {
        debugPrint('EditPostPage: Attempting to update post ID: ${widget.postId}');
        await FirebaseFirestore.instance.collection('posts').doc(widget.postId).update({
          'content': _contentController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(), // Add an updatedAt field
          'updatedBy': currentUser.uid,
        });

        _showSnackBar('Post updated successfully!');
        debugPrint('EditPostPage: Post updated successfully. Navigating back.');
        if (mounted) {
          Navigator.pop(context); // Go back to the previous screen (TroupeContentPage)
        }
      } catch (e) {
        _showSnackBar('Failed to update post: $e');
        debugPrint('EditPostPage Error: Failed to update post: $e');
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
        title: const Text('Edit Post'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit the content of your post. Your changes will be visible to all members of this troupe.',
                style: TextStyle(fontSize: 16, color: textOnBackground),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Post Content',
                  hintText: 'Modify your message...',
                  alignLabelWithHint: true,
                ),
                maxLines: 8,
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
                        onPressed: _updatePost,
                        child: const Text('Save Changes'),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
