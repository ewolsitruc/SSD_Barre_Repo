import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:cloud_firestore/cloud_firestore.dart'; // For Firestore operations
import 'package:firebase_auth/firebase_auth.dart'; // For user authentication

// Import your existing pages that manage troupes if they will be accessible from here
import '../troupes_page.dart'; // This is your TroupesPage
import '../admin/add_troupe_page.dart'; // For adding new troupes/sub-troupes
import '../admin/manage_join_requests_page.dart'; // For managing join requests

class AdminTroupeManagementPage extends StatefulWidget {
  const AdminTroupeManagementPage({super.key});

  @override
  State<AdminTroupeManagementPage> createState() => _AdminTroupeManagementPageState();
}

class _AdminTroupeManagementPageState extends State<AdminTroupeManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textOnBackground = Theme.of(context).colorScheme.onBackground;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Troupes & Requests'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Here you can manage all aspects of your troupes, sub-troupes, and join requests.',
              style: TextStyle(fontSize: 16, color: textOnBackground),
            ),
            const SizedBox(height: 20),
            // Link to view/edit all troupes (TroupesPage is currently your main management page)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 3,
              color: Theme.of(context).colorScheme.surface,
              child: ListTile(
                leading: Icon(Icons.group, color: primaryColor),
                title: Text(
                  'View/Edit All Troupes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textOnBackground),
                ),
                subtitle: Text(
                  'Rename, reorder, and manage members within parent and sub-troupes.',
                  style: TextStyle(color: textOnBackground.withOpacity(0.7)),
                ),
                trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey),
                onTap: () {
                  debugPrint('AdminTroupeManagementPage: Navigating to TroupesPage for management.');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TroupesPage()), // Use TroupesPage for management
                  );
                },
              ),
            ),
            // Link to add new troupe/sub-troupe
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 3,
              color: Theme.of(context).colorScheme.surface,
              child: ListTile(
                leading: Icon(Icons.add_circle_outline, color: primaryColor),
                title: Text(
                  'Add New Troupe/Sub-Troupe',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textOnBackground),
                ),
                subtitle: Text(
                  'Create new parent or sub-troupes for your organization.',
                  style: TextStyle(color: textOnBackground.withOpacity(0.7)),
                ),
                trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey),
                onTap: () {
                  debugPrint('AdminTroupeManagementPage: Navigating to AddTroupePage.');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddTroupePage()),
                  );
                },
              ),
            ),
            // Link to manage join requests
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 3,
              color: Theme.of(context).colorScheme.surface,
              child: ListTile(
                leading: Icon(Icons.person_add_alt_1, color: primaryColor),
                title: Text(
                  'Manage Join Requests',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textOnBackground),
                ),
                subtitle: Text(
                  'Approve or reject requests from users to join your troupes.',
                  style: TextStyle(color: textOnBackground.withOpacity(0.7)),
                ),
                trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey),
                onTap: () {
                  debugPrint('AdminTroupeManagementPage: Navigating to ManageJoinRequestsPage.');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ManageJoinRequestsPage()),
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
