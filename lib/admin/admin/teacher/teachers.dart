import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ssd_barre_new/admin/teacher/teachers_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeachersListPage extends StatefulWidget {
  const TeachersListPage({super.key});

  @override
  State<TeachersListPage> createState() => _TeachersListPageState();
}

class _TeachersListPageState extends State<TeachersListPage> {
  String _searchQuery = '';
  String? _currentUid;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() {
        _currentUid = user.uid;
        _isAdmin = doc.exists && doc['isAdmin'] == true;
      });
    }
  }

  Future<void> _toggleTeacherActive(String uid, bool newValue) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(newValue ? 'Activate Account' : 'Suspend Account'),
        content: Text(
          'Are you sure you want to ${newValue ? 'activate' : 'suspend'} this teacher account?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newValue ? Colors.red : Colors.grey,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'isActive': newValue});
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onBackground;

    return Scaffold(
      appBar: AppBar(title: const Text('All Teachers')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search teachers by name...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase().trim());
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('isTeacher', isEqualTo: true)
                  .orderBy('firstNameLowercase')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No teachers found.'));
                }

                final teachers = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final fullName = (data['firstName'] ?? '') + (data['lastName'] ?? '');
                  return fullName.toLowerCase().contains(_searchQuery);
                }).toList();

                return ListView.separated(
                  itemCount: teachers.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, index) {
                    final doc = teachers[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final uid = doc.id;
                    final photoUrl = data['profileImageUrl'] ?? '';
                    final firstName = data['firstName'] ?? '';
                    final lastName = data['lastName'] ?? '';
                    final displayName = '$firstName $lastName';
                    final lastLogin = (data['lastLogin'] as Timestamp?)?.toDate();
                    final isActive = data['isActive'] != false; // default to true if null

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                          child: photoUrl.isEmpty ? const Icon(Icons.person) : null,
                          radius: 28,
                        ),
                        title: Text(
                          displayName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        subtitle: lastLogin != null
                            ? Text('Last login: ${DateFormat.yMMMd().format(lastLogin)}')
                            : const Text('Last login: unknown'),
                        trailing: _isAdmin
                            ? Switch(
                          value: isActive,
                          activeColor: Colors.red,
                          inactiveThumbColor: Colors.grey,
                          onChanged: (value) => _toggleTeacherActive(uid, value),
                        )
                            : null,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TeacherProfilePage(uid: uid),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
