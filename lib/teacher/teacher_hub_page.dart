import 'package:flutter/material.dart';
import 'package:ssd_barre_new/teacher/payroll_hours.dart';
import 'package:ssd_barre_new/teacher/pay_rate.dart';
import 'package:ssd_barre_new/admin/teacher/teachers_profile.dart';
import 'package:ssd_barre_new/widgets/section_title.dart';
import 'package:ssd_barre_new/user/posts_view_page.dart';
import 'package:ssd_barre_new/admin/add_post_page.dart';
import 'package:ssd_barre_new/user/user_data_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class TeacherHubPage extends StatefulWidget {
  const TeacherHubPage({super.key});

  @override
  State<TeacherHubPage> createState() => _TeacherHubPageState();
}

class _TeacherHubPageState extends State<TeacherHubPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String? _userUid;
  bool _isAdmin = false;
  bool _isTeacher = false;
  List<String> _assignedGroups = [];
  List<String> _assignedSubgroups = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final data = userDoc.data();
      if (data != null) {
        setState(() {
          _userUid = user.uid;
          _isAdmin = data['isAdmin'] ?? false;
          _isTeacher = data['isTeacher'] ?? false;
          _assignedGroups = List<String>.from(data['assignedGroups'] ?? []);
          _assignedSubgroups = List<String>.from(data['assignedSubgroups'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('TeacherHubPage: Error loading user data - $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor = Theme.of(context).colorScheme.onBackground;
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Hub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.access_time),
            tooltip: 'Time Card',
            onPressed: () {
              if (_userUid != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PayrollHoursPage(teacherUid: _userUid!),
                  ),
                );
              }
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddPostPage()),
        ),
        child: const Icon(Icons.add),
        tooltip: 'Create New Post',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionTitle('Quick Access'),
          _buildTile(
            context,
            title: 'Class Portal',
            subtitle: 'View and manage your class schedule.',
            icon: Icons.link,
            onTap: () async {
              const url =
                  'https://app.gostudiopro.com/apps/manager/locked.php?id=zaqlxajd29jd25a26f3416625a09jasdklj21dx5a26f341662ff';
              // Implement launchUrl() if you plan to use it
            },
          ),
          _buildTile(
            context,
            title: 'Teacher Profile',
            subtitle: 'View and edit your teacher profile.',
            icon: Icons.person,
            onTap: () {
              if (_userUid != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeacherProfilePage(uid: _userUid!),
                  ),
                );
              }
            },
          ),
          _buildTile(
            context,
            title: 'Music Library',
            subtitle: 'Access class music and resources.',
            icon: Icons.library_music,
            onTap: () async {
              const url = 'https://drive.google.com/drive/folders/your-folder-id';
              // Implement URL launcher or file viewer
            },
          ),
          const SizedBox(height: 20),
          SectionTitle('Troupe Posts'),
          PostsViewPage(
            assignedGroups: _assignedGroups,
            assignedSubgroups: _assignedSubgroups,
            showAssignedTroupesOnly: true,
            isTeacher: _isTeacher,
          ),
        ],
      ),
    );
  }

  Widget _buildTile(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 3,
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
