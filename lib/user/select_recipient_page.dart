import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'direct_message_page.dart';

class SelectRecipientPage extends StatefulWidget {
  const SelectRecipientPage({super.key});

  @override
  State<SelectRecipientPage> createState() => _SelectRecipientPageState();
}

class _SelectRecipientPageState extends State<SelectRecipientPage> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _currentUser;
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // React to user input changes
  void _onSearchChanged() {
    final keyword = _searchController.text.trim();
    if (keyword.length >= 2) {
      _searchUsers(keyword);
    } else {
      setState(() {
        _searchResults = [];
        _error = '';
      });
    }
  }

  // Call Cloud Function to search users
  Future<void> _searchUsers(String keyword) async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('searchUsers')
          .call({'keyword': keyword});

      final List<dynamic> users = result.data;
      debugPrint('Cloud Function returned ${users.length} users');

      // Filter out current user
      setState(() {
        _searchResults = users.where((user) => user['uid'] != _currentUser?.uid).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error searching users: $e');
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  // Navigate to chat with selected user
  void _openChat(dynamic user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DirectMessagePage(
          recipientUid: user['uid'],
          recipientEmail: user['email'] ?? 'No Email',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textColor = Theme.of(context).colorScheme.onBackground;

    return Scaffold(
      appBar: AppBar(title: const Text('Start New Chat')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search by email, name, or username...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(_error, style: const TextStyle(color: Colors.red)),
            ),
          if (!_isLoading)
            Expanded(
              child: _searchController.text.trim().length < 2
                  ? const Center(child: Text('Type at least 2 characters to search.'))
                  : _searchResults.isEmpty
                  ? const Center(child: Text('No users found.'))
                  : ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final user = _searchResults[index];
                  final String displayName = user['displayName'] ?? 'No Name';
                  final String email = user['email'] ?? 'No Email';
                  final String? photoUrl = user['photoUrl'];

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl)
                          : null,
                      backgroundColor: photoUrl == null ? Colors.grey[400] : Colors.transparent,
                      child: photoUrl == null
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    title: Text(displayName, style: TextStyle(color: textColor)),
                    subtitle: Text(email, style: TextStyle(color: textColor.withOpacity(0.7))),
                    onTap: () => _openChat(user),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
