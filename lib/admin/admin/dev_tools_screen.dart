// In your lib/admin/dev_tools_screen.dart file

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:ssd_barre_new/admin/admin_troupe_management.dart'; // Import your new page
import 'package:ssd_barre_new/admin/add_announcement_page.dart'; // Existing admin page
import 'package:ssd_barre_new/admin/add_event_page.dart'; // Existing admin page
import 'package:ssd_barre_new/admin/manage_join_requests_page.dart'; // Existing admin page
import '../admin/teacher/manage_teachers.dart';

class DevToolsScreen extends StatefulWidget {
  const DevToolsScreen({super.key});

  @override
  State<DevToolsScreen> createState() => _DevToolsScreenState();
}

class _DevToolsScreenState extends State<DevToolsScreen> {
  // ... (your existing state and methods)

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textOnBackground = Theme.of(context).colorScheme.onBackground;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Tools'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Here you can access various administrative functionalities.',
              style: TextStyle(fontSize: 16, color: textOnBackground),
            ),
            const SizedBox(height: 20),
            // NEW: Link to your consolidated AdminTroupeManagementPage
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 3,
              color: Theme.of(context).colorScheme.surface,
              child: ListTile(
                leading: Icon(Icons.group, color: primaryColor),
                title: Text(
                  'Manage Troupes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textOnBackground),
                ),
                onTap: () {
                  debugPrint('DevToolsScreen: Navigating to AdminTroupeManagementPage.');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminTroupeManagementPage()),
                  );
                },
              ),
            ),
            // Existing admin links (example - adjust as per your actual DevToolsScreen content)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 3,
              color: Theme.of(context).colorScheme.surface,
              child: ListTile(
                leading: Icon(Icons.announcement, color: primaryColor),
                title: Text(
                  'Add Announcement',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textOnBackground),
                ),
                onTap: () {
                  debugPrint('DevToolsScreen: Navigating to AddAnnouncementPage.');
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AddAnnouncementPage()));
                },
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 3,
              color: Theme.of(context).colorScheme.surface,
              child: ListTile(
                leading: Icon(Icons.event, color: primaryColor),
                title: Text(
                  'Add Event',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textOnBackground),
                ),
                onTap: () {
                  debugPrint('DevToolsScreen: Navigating to AddEventPage.');
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AddEventPage()));
                },
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 3,
              color: Theme.of(context).colorScheme.surface,
              child: ListTile(
                leading: Icon(Icons.school, color: primaryColor),
                title: Text(
                  'Manage Teachers',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textOnBackground),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ManageTeachersPage()),
                  );
                },
              ),
            )
            // ... (any other existing admin tools)
          ],
        ),
      ),
    );
  }
}