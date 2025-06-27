import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddTeacherPage extends StatefulWidget {
  const AddTeacherPage({super.key});

  @override
  State<AddTeacherPage> createState() => _AddTeacherPageState();
}

class _AddTeacherPageState extends State<AddTeacherPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  List<DocumentSnapshot> _results = [];
  bool _isLoading = false;

  void _onSearchChanged() {
    setState(() {
      _searchText = _searchController.text.toLowerCase().trim();
    });
    _performSearch();
  }

  Future<void> _performSearch() async {
    if (_searchText.isEmpty) {
      setState(() {
        _results = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final usersRef = FirebaseFirestore.instance.collection('users');

      final queries = await Future.wait([
        usersRef
            .where('displayNameLowercase', isGreaterThanOrEqualTo: _searchText)
            .orderBy('displayNameLowercase')
            .limit(5)
            .get(),
        usersRef
            .where('firstNameLowercase', isGreaterThanOrEqualTo: _searchText)
            .orderBy('firstNameLowercase')
            .limit(5)
            .get(),
        usersRef
            .where('lastNameLowercase', isGreaterThanOrEqualTo: _searchText)
            .orderBy('lastNameLowercase')
            .limit(5)
            .get(),
      ]);

      // Merge & deduplicate results
      final uniqueResults = <String, DocumentSnapshot>{};
      for (var query in queries) {
        for (var doc in query.docs) {
          uniqueResults[doc.id] = doc;
        }
      }

      setState(() {
        _results = uniqueResults.values.toList();
      });
    } catch (e) {
      debugPrint('Search failed: $e');
      setState(() => _results = []);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsTeacher(DocumentSnapshot userDoc) async {
    try {
      await userDoc.reference.update({'isTeacher': true});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${userDoc['displayName'] ?? 'User'} is now a teacher.')),
      );
      _performSearch(); // Refresh list
    } catch (e) {
      debugPrint('Error updating user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textColor = Theme.of(context).colorScheme.onBackground;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Teacher')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search Users',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading) const CircularProgressIndicator(),
            if (!_isLoading && _results.isEmpty && _searchText.isNotEmpty)
              const Text('No matching users found.'),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final user = _results[index].data() as Map<String, dynamic>;
                  final isAlreadyTeacher = user['isTeacher'] == true;
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user['profileImageUrl'] != null && user['profileImageUrl'].toString().isNotEmpty
                            ? NetworkImage(user['profileImageUrl'])
                            : null,
                        child: user['profileImageUrl'] == null || user['profileImageUrl'].toString().isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(user['displayName'] ?? 'No Name'),
                      subtitle: Text(user['email'] ?? ''),
                      trailing: isAlreadyTeacher
                          ? const Icon(Icons.check, color: Colors.green)
                          : TextButton(
                        onPressed: () => _markAsTeacher(_results[index]),
                        child: const Text('Make Teacher'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
