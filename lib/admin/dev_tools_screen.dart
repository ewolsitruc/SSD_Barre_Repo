import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Keep if other admin functions still need it
import 'package:firebase_auth/firebase_auth.dart'; // Keep if user context is needed
import 'package:flutter/foundation.dart'; // For debugPrint
import 'add_announcement_page.dart'; // Import the new AddAnnouncementPage
import 'add_event_page.dart'; // Import AddEventPage
import 'add_troupe_page.dart'; // Import AddTroupePage

class DevToolsScreen extends StatefulWidget {
  const DevToolsScreen({super.key});

  @override
  State<DevToolsScreen> createState() => _DevToolsScreenState();
}

class _DevToolsScreenState extends State<DevToolsScreen> {
  // Removed _auth and _firestore as direct manipulation functions are removed from UI
  // No need for _isLoading state as direct Firestore writes for admin actions are removed from this UI.

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
        title: const Text('Admin Tools'), // Changed title to be more general
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Functions Overview',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            // Menu items for admin tools
            Card(
              margin: EdgeInsets.zero, // Remove default card margin
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 3,
              color: Theme.of(context).colorScheme.surface, // Use surface color for card background
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.campaign, color: primaryColor), // Speaker icon for announcements
                    title: Text('Add New Announcement', style: TextStyle(color: textOnBackground)),
                    onTap: () {
                      debugPrint('DevTools: Navigating to AddAnnouncementPage.');
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AddAnnouncementPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.event, color: primaryColor), // Calendar icon for events
                    title: Text('Add New Event', style: TextStyle(color: textOnBackground)),
                    onTap: () {
                      debugPrint('DevTools: Navigating to AddEventPage.');
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AddEventPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.group_add, color: primaryColor), // Add group icon for troupe
                    title: Text('Create Troupe', style: TextStyle(color: textOnBackground)),
                    onTap: () {
                      debugPrint('DevTools: Navigating to AddTroupePage.');
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AddTroupePage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.people, color: primaryColor), // People icon for user management
                    title: Text('Manage Users', style: TextStyle(color: textOnBackground)),
                    onTap: () {
                      debugPrint('DevTools: Manage Users (Future Feature)');
                      _showSnackBar('Future feature: Manage Users');
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.school, color: primaryColor), // School/teacher icon
                    title: Text('Manage Teachers', style: TextStyle(color: textOnBackground)),
                    onTap: () {
                      debugPrint('DevTools: Manage Teachers (Future Feature)');
                      _showSnackBar('Future feature: Manage Teachers');
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.person_add, color: primaryColor), // Person with plus icon for invite
                    title: Text('Invite To Troupe', style: TextStyle(color: textOnBackground)),
                    onTap: () {
                      debugPrint('DevTools: Invite to Troupe (Future Feature)');
                      _showSnackBar('Future feature: Invite to Troupe');
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.folder, color: primaryColor), // Folder icon for file management
                    title: Text('Manage Files', style: TextStyle(color: textOnBackground)),
                    onTap: () {
                      debugPrint('DevTools: Manage Files (Future Feature)');
                      _showSnackBar('Future feature: Manage Files');
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.bug_report, color: primaryColor), // Bug icon for logs
                    title: Text('View Logs', style: TextStyle(color: textOnBackground)),
                    onTap: () {
                      debugPrint('DevTools: View Logs (Future Feature)');
                      _showSnackBar('Future feature: View App Logs');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
